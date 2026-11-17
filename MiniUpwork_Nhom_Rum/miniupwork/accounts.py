"""Local marketplace accounts. Keep raw passwords and session tokens out of SQL storage."""

from hashlib import pbkdf2_hmac, sha256
from hmac import compare_digest
from secrets import token_bytes, token_urlsafe

from .errors import ServiceError
from .service import database_errors

COOKIE = "rum_session"
SESSION_SECONDS = 8 * 60 * 60
_DUMMY_HASH = "pbkdf2_sha256$600000$" + "0" * 32 + "$" + "0" * 64
_IDENTITY = """
    SELECT u.user_id, u.username, u.full_name,
           cl.user_id IS NOT NULL AS is_client, f.user_id IS NOT NULL AS is_freelancer
    FROM miniupwork.app_user u
    LEFT JOIN miniupwork.client cl USING (user_id)
    LEFT JOIN miniupwork.freelancer f USING (user_id)
"""


def verify_password(value: str, encoded: str) -> bool:
    try:
        algorithm, cost, salt, stored = encoded.split("$")
        rounds = int(cost)
        if algorithm != "pbkdf2_sha256" or rounds != 600_000:
            return False
        candidate = pbkdf2_hmac("sha256", value.encode("utf-8"), bytes.fromhex(salt), rounds)
        return compare_digest(candidate, bytes.fromhex(stored))
    except (ValueError, OverflowError):
        return False


def password_hash(value: str) -> str:
    salt = token_bytes(16)
    digest = pbkdf2_hmac("sha256", value.encode("utf-8"), salt, 600_000)
    return f"pbkdf2_sha256$600000${salt.hex()}${digest.hex()}"


@database_errors
def register(database, profile):
    encoded = password_hash(profile.password.get_secret_value())
    with database.connection() as conn:
        identity = conn.execute("""
            INSERT INTO miniupwork.app_user (username,email,full_name,password_hash)
            VALUES (%s,%s,%s,%s) RETURNING user_id
        """, (profile.username.lower(), profile.email, profile.full_name, encoded)).fetchone()["user_id"]
        if profile.role in {"CLIENT", "BOTH"}:
            conn.execute("INSERT INTO miniupwork.client (user_id,company_name) VALUES (%s,%s)", (identity, profile.company_name))
        if profile.role in {"FREELANCER", "BOTH"}:
            conn.execute("INSERT INTO miniupwork.freelancer (user_id,headline,default_hourly_rate) VALUES (%s,%s,%s)",
                         (identity, profile.headline, profile.hourly_rate))
    return {"user_id": identity, "username": profile.username.lower()}


@database_errors
def freelancer_profile(database, user_id):
    with database.connection() as conn:
        person = conn.execute("""
            SELECT u.user_id,u.username,u.full_name,f.headline,f.overview,f.default_hourly_rate,f.availability,
                   f.experience_level,r.avg_rating,COALESCE(r.review_count,0) AS review_count,r.updated_at
            FROM miniupwork.app_user u JOIN miniupwork.freelancer f USING (user_id)
            LEFT JOIN miniupwork.rating_summary r USING (user_id)
            WHERE u.user_id=%s AND u.status='ACTIVE'
        """, (user_id,)).fetchone()
        if not person:
            raise ServiceError("Không tìm thấy hồ sơ freelancer.", 404, "not_found")
        person["skills"] = conn.execute("""
            SELECT fs.skill_id,s.skill_name,fs.proficiency_level
            FROM miniupwork.freelancer_skill fs JOIN miniupwork.skill s USING (skill_id)
            WHERE fs.freelancer_id=%s ORDER BY s.skill_name
        """, (user_id,)).fetchall()
    return person


@database_errors
def profiles(database, user_id):
    with database.connection() as conn:
        return {
            "client": conn.execute("""
                SELECT company_name,description,billing_address FROM miniupwork.client WHERE user_id=%s
            """, (user_id,)).fetchone(),
            "freelancer": conn.execute("""
                SELECT headline,overview,experience_level,default_hourly_rate,availability
                FROM miniupwork.freelancer WHERE user_id=%s
            """, (user_id,)).fetchone(),
        }


@database_errors
def update_client(database, user_id, body):
    with database.connection() as conn:
        conn.execute("""
            UPDATE miniupwork.client SET company_name=%s,description=%s,billing_address=%s WHERE user_id=%s
        """, (body.company_name, body.description, body.billing_address, user_id))
    return {"status": "ok"}


@database_errors
def update_freelancer(database, user_id, body):
    with database.connection() as conn:
        conn.execute("""
            UPDATE miniupwork.freelancer SET headline=%s,overview=%s,experience_level=%s,
                   default_hourly_rate=%s,availability=%s WHERE user_id=%s
        """, (body.headline, body.overview, body.experience_level, body.default_hourly_rate, body.availability, user_id))
    return {"status": "ok"}


@database_errors
def replace_skills(database, user_id, skills):
    with database.connection() as conn:
        conn.execute("SELECT pg_advisory_xact_lock(-%s::bigint)", (user_id,))
        conn.execute("DELETE FROM miniupwork.freelancer_skill WHERE freelancer_id=%s", (user_id,))
        with conn.cursor() as cursor:
            cursor.executemany("INSERT INTO miniupwork.freelancer_skill VALUES (%s,%s,%s)",
                               [(user_id, row.skill_id, row.proficiency_level) for row in skills])
    return {"count": len(skills)}


def token_digest(token: str) -> bytes:
    return sha256(token.encode("ascii")).digest()


def valid_token(token: str | None) -> bool:
    return bool(token and len(token) == 43 and token.isascii())


@database_errors
def login(database, username: str, password: str, previous: str | None) -> str:
    with database.connection() as conn:
        row = conn.execute(
            "SELECT user_id, status, password_hash FROM miniupwork.app_user WHERE username = %s",
            (username.lower(),),
        ).fetchone()
        approved = verify_password(password, row["password_hash"] if row else _DUMMY_HASH)
        if not approved or row is None or row["status"] != "ACTIVE":
            raise ServiceError("Tên đăng nhập hoặc mật khẩu không đúng.", 401, "bad_credentials")

        conn.execute("DELETE FROM miniupwork.app_session WHERE expires_at <= now()")
        if valid_token(previous):
            conn.execute("DELETE FROM miniupwork.app_session WHERE token_digest = %s", (token_digest(previous),))
        token = token_urlsafe(32)
        conn.execute(
            "INSERT INTO miniupwork.app_session VALUES (%s, %s, now() + make_interval(secs => %s))",
            (token_digest(token), row["user_id"], SESSION_SECONDS),
        )
    return token


@database_errors
def current_user(database, token: str | None) -> dict:
    user = None
    if valid_token(token):
        with database.connection() as conn:
            user = conn.execute(
                _IDENTITY + """
                  JOIN miniupwork.app_session s ON s.user_id = u.user_id
                  WHERE s.token_digest = %s AND s.expires_at > now() AND u.status = 'ACTIVE'
                """,
                (token_digest(token),),
            ).fetchone()
    if user is None:
        raise ServiceError("Bạn cần đăng nhập.", 401, "login_required")
    return user


@database_errors
def logout(database, token: str | None) -> None:
    if valid_token(token):
        with database.connection() as conn:
            conn.execute("DELETE FROM miniupwork.app_session WHERE token_digest = %s", (token_digest(token),))
