"""Client wallet funded by the local bank simulator."""

from .service import database_errors, json_safe


@database_errors
def detail(database, client_id):
    with database.connection() as conn:
        row = conn.execute("""
            SELECT w.balance, COALESCE(history.entries, '[]'::json) AS entries
            FROM miniupwork.client_wallet w
            LEFT JOIN LATERAL (
                SELECT json_agg(entry ORDER BY entry.entry_id DESC) AS entries
                FROM (
                    SELECT e.entry_id, e.kind, e.amount, e.bank_reference, e.created_at,
                           COALESCE(p.contract_id, e.cancellation_id) AS contract_id
                    FROM miniupwork.client_wallet_entry e
                    LEFT JOIN miniupwork.payment_transaction p ON p.payment_id = e.payment_id
                    WHERE e.client_id = w.client_id
                    ORDER BY e.entry_id DESC LIMIT 20
                ) entry
            ) history ON TRUE
            WHERE w.client_id = %s
        """, (client_id,)).fetchone()
    return json_safe(row)


@database_errors
def bank_top_up(database, client_id, body):
    with database.connection() as conn:
        return conn.execute("SELECT miniupwork.bank_top_up(%s, %s, %s) AS entry_id",
                            (client_id, body.amount, body.reference)).fetchone()
