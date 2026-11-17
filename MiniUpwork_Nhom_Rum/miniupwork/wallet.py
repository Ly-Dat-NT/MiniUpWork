"""A single wallet per account with a shared payment history."""

from .service import database_errors, json_safe


@database_errors
def detail(database, user_id):
    with database.connection() as conn:
        row = conn.execute("""
            SELECT w.balance, COALESCE(history.entries, '[]'::json) AS entries
            FROM miniupwork.user_wallet w
            LEFT JOIN LATERAL (
                SELECT json_agg(entry ORDER BY entry.created_at DESC, entry.entry_id DESC) AS entries
                FROM (
                    SELECT e.entry_id, e.kind, e.amount, e.bank_reference, e.created_at,
                           COALESCE(p.contract_id, e.cancellation_id) AS contract_id
                    FROM miniupwork.user_wallet_entry e
                    LEFT JOIN miniupwork.payment_transaction p ON p.payment_id = e.payment_id
                    WHERE e.user_id = w.user_id
                    ORDER BY e.created_at DESC, e.entry_id DESC LIMIT 20
                ) entry
            ) history ON TRUE
            WHERE w.user_id = %s
        """, (user_id,)).fetchone()
    return json_safe(row)


@database_errors
def bank_top_up(database, client_id, body):
    with database.connection() as conn:
        return conn.execute("SELECT miniupwork.bank_top_up(%s, %s, %s) AS entry_id",
                            (client_id, body.amount, body.reference)).fetchone()
