"""Prepare a separate local database, then open the integrated Mini-Upwork app."""

import getpass
from hashlib import sha256
import json
import os
from pathlib import Path
import re
from secrets import token_urlsafe

from dotenv import dotenv_values
import psycopg
from psycopg import sql
from psycopg.conninfo import conninfo_to_dict, make_conninfo
import uvicorn

ROOT = Path(__file__).resolve().parent
OLD_SETTINGS = Path(r"D:\CSDL\MiniUpwork_Phase4_Dat\MiniUpwork_Phase4_Dat\.env")
SHARED_RUNTIME = Path(r"D:\CSDL\MiniUpwork_Nhom_Rum_Phase3_4\MiniUpwork_Nhom_Rum\.rum-runtime.json")
DATABASE = "miniupwork_nhom_rum"
SETUP_FILES = ("01_schema.sql", "02_proposal_phase3.sql", "03_contracts.sql", "04_seed_rum.sql")
OWNER_COMMENT = "Mini-Upwork Rum local dataset"
SCHEMA_VERSION = 5
UPGRADES = {
    1: "07_phase12_upgrade.sql", 2: "09_report_alignment.sql", 3: "10_billing_integrity.sql",
    4: "11_client_wallet_and_milestones.sql",
}


def connection_settings() -> tuple[str, str]:
    local = ROOT / ".env"
    source = local if local.is_file() else OLD_SETTINGS
    values = {**dotenv_values(source), **os.environ} if source.is_file() else dict(os.environ)
    if values.get("DATABASE_URL"):
        parsed = conninfo_to_dict(values["DATABASE_URL"])
        host = parsed.get("host") or "127.0.0.1"
        port = parsed.get("port") or "5432"
        user = parsed.get("user") or "postgres"
        password = values.get("DATABASE_PASSWORD") or parsed.get("password", "")
    else:
        host = "127.0.0.1"
        port = input("Cong PostgreSQL [5432]: ").strip() or "5432"
        user = input("Tai khoan PostgreSQL [postgres]: ").strip() or "postgres"
        password = getpass.getpass("Mat khau PostgreSQL (an khi go): ")
    if host not in {"127.0.0.1", "localhost", "::1"}:
        raise ValueError("Ung dung dung PostgreSQL cuc bo. Dat host la 127.0.0.1 trong .env.")
    return make_conninfo(host=host, port=port, user=user, dbname=DATABASE, connect_timeout=5), password


def install_database(conninfo: str, password: str, database: str = DATABASE) -> None:
    admin_dsn = make_conninfo(conninfo, dbname="postgres")
    target_dsn = make_conninfo(conninfo, dbname=database)
    with psycopg.connect(admin_dsn, password=password, autocommit=True) as admin:
        admin.execute("SELECT pg_advisory_lock(59181023)")
        existing = admin.execute("""
            SELECT shobj_description(oid, 'pg_database') FROM pg_database WHERE datname = %s
        """, (database,)).fetchone()
        if existing is None:
            admin.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(database)))
            admin.execute(sql.SQL("COMMENT ON DATABASE {} IS {}").format(sql.Identifier(database), sql.Literal(OWNER_COMMENT)))

        with psycopg.connect(target_dsn, password=password) as db:
            installed = db.execute("SELECT to_regclass('miniupwork.rum_installation') IS NOT NULL").fetchone()[0]
            if not installed and existing is not None and existing[0] != OWNER_COMMENT:
                raise ValueError(f"Database {database} da co. Kiem tra database trong pgAdmin truoc khi cai.")
            upgrade_schema(db, installed=installed)


def upgrade_schema(db, *, installed):
    if not installed:
        for name in SETUP_FILES:
            query = (ROOT / "sql" / name).read_text(encoding="utf-8-sig")
            query = re.sub(r"(?m)^BEGIN;[ \t]*$", "", query, count=1).rstrip().removesuffix("COMMIT;")
            db.execute(query)
        db.execute("CREATE TABLE miniupwork.rum_installation (installed_at TIMESTAMPTZ NOT NULL DEFAULT now())")
        db.execute("INSERT INTO miniupwork.rum_installation DEFAULT VALUES")
    db.execute("ALTER TABLE miniupwork.rum_installation ADD COLUMN IF NOT EXISTS schema_version INT NOT NULL DEFAULT 1")
    version = db.execute("SELECT schema_version FROM miniupwork.rum_installation").fetchone()[0]
    if not 1 <= version <= SCHEMA_VERSION:
        raise ValueError(f"Database dang dung luoc do phien ban {version}.")
    while version < SCHEMA_VERSION:
        db.execute((ROOT / "sql" / UPGRADES[version]).read_text(encoding="utf-8-sig"))
        version += 1
        db.execute("UPDATE miniupwork.rum_installation SET schema_version = %s", (version,))


def runtime_connection(conninfo: str, password: str, state_path: Path) -> tuple[str, str]:
    details = conninfo_to_dict(conninfo)
    database = details["dbname"]
    role = "rum_app_" + sha256(database.encode()).hexdigest()[:12]
    binding = {"host": details.get("host"), "port": details.get("port"), "role": role}
    comment = f"Runtime of {database}"
    role_password = token_urlsafe(32)
    with psycopg.connect(conninfo, password=password) as owner:
        owner.execute("SELECT pg_advisory_lock(59181024)")
        state = json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {}
        role_exists = owner.execute("SELECT shobj_description(oid, 'pg_authid') FROM pg_roles WHERE rolname = %s", (role,)).fetchone()
        if role_exists is None:
            owner.execute(sql.SQL("CREATE ROLE {} LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD {}").format(
                sql.Identifier(role), sql.Literal(role_password)))
            owner.execute(sql.SQL("COMMENT ON ROLE {} IS {}").format(sql.Identifier(role), sql.Literal(comment)))
        elif role_exists[0] != comment:
            raise ValueError("Tai khoan PostgreSQL cua ung dung dang bi trung ten.")
        elif state.get("binding") == binding and state.get("password"):
            role_password = state["password"]
        else:
            owner.execute(sql.SQL("ALTER ROLE {} PASSWORD {}").format(sql.Identifier(role), sql.Literal(role_password)))

        def grant(text):
            owner.execute(sql.SQL(text).format(role=sql.Identifier(role), db=sql.Identifier(database)))

        grant("GRANT CONNECT ON DATABASE {db} TO {role}")
        grant("GRANT USAGE ON SCHEMA miniupwork TO {role}")
        grant("GRANT SELECT ON ALL TABLES IN SCHEMA miniupwork TO {role}")
        grant("GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA miniupwork TO {role}")
        grant("""
            GRANT INSERT ON miniupwork.app_user, miniupwork.client, miniupwork.freelancer,
                miniupwork.freelancer_skill, miniupwork.app_session, miniupwork.job, miniupwork.job_skill,
                miniupwork.fixed_price_job, miniupwork.hourly_job, miniupwork.proposal, miniupwork.contract,
                miniupwork.fixed_price_contract, miniupwork.hourly_contract, miniupwork.milestone,
                miniupwork.escrow_funding, miniupwork.weekly_invoice, miniupwork.time_entry,
                miniupwork.payment_transaction, miniupwork.review, miniupwork.fixed_cancellation,
                miniupwork.fixed_cancellation_payout, miniupwork.fixed_cancellation_fee_payment TO {role}
        """)
        grant("GRANT EXECUTE ON FUNCTION miniupwork.bank_top_up(BIGINT, NUMERIC, UUID) TO {role}")
        grant("GRANT UPDATE(status) ON miniupwork.job, miniupwork.milestone, miniupwork.weekly_invoice TO {role}")
        grant("GRANT UPDATE(status, end_date) ON miniupwork.contract TO {role}")
        grant("GRANT UPDATE(status, submitted_at, cover_letter, offered_amount) ON miniupwork.proposal TO {role}")
        grant("GRANT UPDATE(status) ON miniupwork.escrow_funding, miniupwork.payment_transaction TO {role}")
        grant("GRANT UPDATE(company_name, description, billing_address) ON miniupwork.client TO {role}")
        grant("""GRANT UPDATE(headline, overview, experience_level, default_hourly_rate, availability)
                  ON miniupwork.freelancer TO {role}""")
        grant("GRANT UPDATE(invoice_id, eligibility_status) ON miniupwork.time_entry TO {role}")
        grant("GRANT DELETE ON miniupwork.app_session, miniupwork.freelancer_skill TO {role}")
        owner.commit()
        if state.get("binding") == binding and state.get("password") == role_password:
            return make_conninfo(conninfo, user=role), role_password
        temporary = state_path.with_name(f"{state_path.name}.{token_urlsafe(8)}.tmp")
        try:
            temporary.write_text(json.dumps({"binding": binding, "password": role_password}), encoding="utf-8")
            temporary.replace(state_path)
        finally:
            temporary.unlink(missing_ok=True)
    return make_conninfo(conninfo, user=role), role_password


def main() -> int:
    try:
        conninfo, password = connection_settings()
        install_database(conninfo, password)
        local_runtime = ROOT / ".rum-runtime.json"
        state = local_runtime if local_runtime.exists() or not SHARED_RUNTIME.exists() else SHARED_RUNTIME
        conninfo, password = runtime_connection(conninfo, password, state)
    except (psycopg.Error, OSError, ValueError) as error:
        print(f"Chua mo duoc CSDL Mini-Upwork ({type(error).__name__}).")
        if isinstance(error, ValueError):
            print(str(error))
        else:
            print("Kiem tra dich vu PostgreSQL va tai khoan trong .env. Xem README.md de cai thu cong.")
        return 1
    os.environ["DATABASE_URL"] = conninfo
    os.environ["DATABASE_PASSWORD"] = password
    print("Mini-Upwork Nhom Rum - http://127.0.0.1:8016/", flush=True)
    uvicorn.run("miniupwork.phase4:app", host="127.0.0.1", port=8016)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
