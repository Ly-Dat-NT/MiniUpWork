"""Initialize the shared online demo in a dedicated PostgreSQL database."""

from contextlib import contextmanager
from datetime import timedelta
from getpass import getpass
from secrets import token_urlsafe

from dotenv import dotenv_values
import psycopg
from psycopg.conninfo import conninfo_to_dict, make_conninfo
from psycopg.rows import dict_row

from miniupwork import accounts, contracts, recruitment
from miniupwork.market_models import Decision
from miniupwork.service import MiniUpworkService
from run_local import ROOT, runtime_connection, upgrade_schema


def prepare_demo(conn, user1_password, user2_password):
    @contextmanager
    def demo_connection():
        yield conn

    class DemoDatabase:
        connection = staticmethod(demo_connection)

    db = DemoDatabase()
    buyer, seller = [
        conn.execute("SELECT user_id FROM miniupwork.app_user WHERE username=%s", (name,)).fetchone()["user_id"]
        for name in ("user01", "user02")
    ]
    # Only the intended demo operators receive passwords for the seeded accounts.
    conn.execute("UPDATE miniupwork.app_user SET password_hash=%s", (accounts.password_hash(token_urlsafe(32)),))
    with conn.cursor() as cursor:
        cursor.executemany("UPDATE miniupwork.app_user SET password_hash=%s WHERE user_id=%s", [
            (accounts.password_hash(user1_password), buyer), (accounts.password_hash(user2_password), seller),
        ])
    conn.execute("""
        INSERT INTO miniupwork.client (user_id, company_name, description)
        VALUES (%s, 'Xưởng Cà phê Mộc Bản', 'Đặt hàng thiết kế và phát triển website giới thiệu sản phẩm.')
    """, (buyer,))
    refs = conn.execute("""
        SELECT c.category_id, s.skill_id FROM miniupwork.category c CROSS JOIN miniupwork.skill s
        WHERE c.category_name='Phát triển web' AND s.skill_name='Figma'
    """).fetchone()
    service = MiniUpworkService(db)
    job = service.create_job({
        "client_id": buyer, "category_id": refs["category_id"], "job_type": "FIXED_PRICE",
        "title": "Thiết kế giao diện website đặt cà phê Mộc Bản", "budget_amount": 480,
        "description": "Thiết kế trải nghiệm xem sản phẩm và đặt cà phê trên cả máy tính và điện thoại.",
        "skills": [{"skill_id": refs["skill_id"], "required_level": 3}],
    })
    service.open_job(job["job_id"], buyer)
    proposal = service.submit_proposal(job["job_id"], {
        "freelancer_id": seller, "offered_amount": 480,
        "cover_letter": "Mình sẽ gửi wireframe, giao diện đặt hàng và prototype để nhóm duyệt theo từng mốc.",
    })
    today = conn.execute("SELECT CURRENT_DATE AS today").fetchone()["today"]
    decision = Decision(status="ACCEPTED", milestones=[
        {"title": "Wireframe trang chủ và trang sản phẩm", "amount": 140, "due_date": today + timedelta(days=7)},
        {"title": "Giao diện giỏ hàng và đặt cà phê", "amount": 200, "due_date": today + timedelta(days=14)},
        {"title": "Bàn giao prototype và thư viện thành phần", "amount": 140, "due_date": today + timedelta(days=21)},
    ])
    item = recruitment.decide(db, proposal["proposal_id"], buyer, decision)
    contracts.change_status(db, item["contract_id"], buyer, "ACTIVE")


def install_online_demo(dsn, password, user1_password=None, user2_password=None):
    with psycopg.connect(dsn, password=password) as db:
        db.execute("SELECT pg_advisory_xact_lock(59181025)")
        state = db.execute("""
            SELECT to_regnamespace('miniupwork'), to_regclass('miniupwork.online_demo')
        """).fetchone()
        if state[0] is not None and state[1] is None:
            raise ValueError("Use a new dedicated database for the online demo.")
        upgrade_schema(db, installed=state[1] is not None)
        if state[1] is None:
            passwords = [
                value or getpass(f"Mật khẩu online riêng cho user{number:02}: ")
                for number, value in enumerate((user1_password, user2_password), 1)
            ]
            if len(set(passwords)) != 2 or any(not 12 <= len(value) <= 128 or value == "0123456789" for value in passwords):
                raise ValueError("Choose two different passwords of 12–128 characters.")
            # The seed validates its own constraints before returning. Restore
            # deferred checks for application writes in this transaction.
            db.execute("SET CONSTRAINTS ALL DEFERRED")
            db.row_factory = dict_row
            prepare_demo(db, *passwords)
            db.execute("CREATE TABLE miniupwork.online_demo (installed_at TIMESTAMPTZ NOT NULL DEFAULT now())")
            db.execute("INSERT INTO miniupwork.online_demo DEFAULT VALUES")


def main():
    config = dotenv_values(ROOT / ".env.hosted")
    owner_url = config.get("MINIUPWORK_OWNER_DATABASE_URL") or getpass("Connection string direct của PostgreSQL online: ")
    settings = conninfo_to_dict(owner_url, connect_timeout=10)
    host = settings.get("host", "")
    if (not host or host in {"localhost", "127.0.0.1", "::1"} or "pooler" in host
            or not settings.get("dbname") or not settings.get("user")):
        raise ValueError("Use the direct connection string of the dedicated cloud database.")
    password = settings.pop("password", None)
    if not password:
        raise ValueError("The owner connection string must include its password.")
    settings["sslmode"] = "verify-full"
    settings["sslrootcert"] = "system"
    dsn = make_conninfo(**settings)
    install_online_demo(dsn, password, config.get("USER01_PASSWORD"), config.get("USER02_PASSWORD"))
    runtime, login_password = runtime_connection(dsn, password, ROOT / ".rum-hosted-runtime.json")
    with psycopg.connect(runtime, password=login_password) as db:
        db.execute("SELECT 1 FROM miniupwork.online_demo")
    (ROOT / ".env.render").write_text(f"DATABASE_URL={runtime}\nDATABASE_PASSWORD={login_password}\n", encoding="utf-8")
    print("Đã tạo CSDL online và hai tài khoản demo. Cấu hình riêng cho Render nằm trong .env.render.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, psycopg.Error) as error:
        reason = str(error) if isinstance(error, ValueError) and not isinstance(error, psycopg.Error) else type(error).__name__
        raise SystemExit(f"Chưa tạo được CSDL online ({reason}).") from None
