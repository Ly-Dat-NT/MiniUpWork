"""Contract reads and state changes scoped to the signed-in participant."""

from .errors import ServiceError, conflict
from .service import database_errors, json_safe

_CONTRACT = """
    SELECT c.contract_id, c.contract_type, c.status, c.start_date, c.end_date,
           j.job_id, j.title, j.client_id, p.freelancer_id, cl.company_name,
           u.full_name AS freelancer_name, f.agreed_amount, h.hourly_rate, h.weekly_limit
    FROM miniupwork.contract c
    JOIN miniupwork.proposal p USING (proposal_id)
    JOIN miniupwork.job j USING (job_id)
    JOIN miniupwork.client cl ON cl.user_id = j.client_id
    JOIN miniupwork.app_user u ON u.user_id = p.freelancer_id
    LEFT JOIN miniupwork.fixed_price_contract f USING (contract_id)
    LEFT JOIN miniupwork.hourly_contract h USING (contract_id)
"""
_SCOPE = "(j.client_id = %s OR p.freelancer_id = %s)"


def get_one(conn, contract_id, user_id, *, lock=False):
    statement = _CONTRACT + f" WHERE c.contract_id = %s AND {_SCOPE}"
    if lock:
        statement += " FOR UPDATE OF c"
    row = conn.execute(statement, (contract_id, user_id, user_id)).fetchone()
    if row is None:
        raise ServiceError("Không tìm thấy hợp đồng trong tài khoản này.", 404, "not_found")
    return row


@database_errors
def list_contracts(database, user_id):
    with database.connection() as conn:
        rows = conn.execute(_CONTRACT + f" WHERE {_SCOPE} ORDER BY c.contract_id", (user_id, user_id)).fetchall()
    return json_safe(rows)


@database_errors
def contract_detail(database, contract_id, user_id):
    with database.connection() as conn:
        contract = get_one(conn, contract_id, user_id)
        if contract["contract_type"] == "FIXED_PRICE":
            contract["milestones"] = conn.execute("""
                SELECT m.milestone_id, m.sequence_no, m.title, m.amount, m.due_date, m.status,
                       COALESCE((SELECT json_agg(json_build_object('funding_id',e.funding_id,'status',e.status,'currency_code',e.currency_code,
                             'funded_at',e.funded_at,'settled_at',e.settled_at,'released_at',e.released_at) ORDER BY e.funding_id)
                         FROM miniupwork.escrow_funding e WHERE e.milestone_id=m.milestone_id), '[]'::json) AS funding_history
                FROM miniupwork.milestone m WHERE m.contract_id = %s ORDER BY m.sequence_no
            """, (contract_id,)).fetchall()
        else:
            contract["invoices"] = conn.execute("""
                SELECT i.invoice_id, i.period_start, i.period_end, i.status, i.total_hours AS hours, i.total_amount AS amount
                FROM miniupwork.weekly_invoice_summary i
                WHERE i.contract_id = %s ORDER BY i.period_start
            """, (contract_id,)).fetchall()
            contract["time_entries"] = conn.execute("""
                SELECT entry_id, invoice_id, start_at, end_at, description, eligibility_status
                FROM miniupwork.time_entry WHERE contract_id=%s ORDER BY start_at DESC, entry_id DESC
            """, (contract_id,)).fetchall()
        contract["payments"] = conn.execute("""
            SELECT p.payment_id,p.transaction_type,p.amount,p.currency_code,p.created_at,p.original_payment_id,
                   p.payer_id,p.payee_id,p.status,p.invoice_id,e.milestone_id,
                   EXISTS (SELECT 1 FROM miniupwork.payment_transaction r WHERE r.original_payment_id=p.payment_id
                           AND r.status IN ('PENDING','SUCCEEDED')) AS reversed
            FROM miniupwork.payment_transaction p LEFT JOIN miniupwork.escrow_funding e ON e.funding_id=p.escrow_funding_id
            WHERE p.contract_id = %s ORDER BY p.payment_id DESC
        """, (contract_id,)).fetchall()
        contract["reviews"] = conn.execute("""
            SELECT r.rating, r.comment, r.submitted_at, r.reviewer_id, u.full_name AS reviewer
            FROM miniupwork.review r JOIN miniupwork.app_user u ON u.user_id = r.reviewer_id
            WHERE r.contract_id = %s ORDER BY r.review_id
        """, (contract_id,)).fetchall()
    return json_safe(contract)


def require_role(contract, user_id, role):
    if user_id != contract[role]:
        raise ServiceError("Tài khoản này không có quyền thực hiện thao tác.", 403, "forbidden")
    if contract["status"] != "ACTIVE":
        raise conflict("Hợp đồng hiện không ở trạng thái thực hiện.")


@database_errors
def milestone_action(database, contract_id, source_id, user_id, action):
    required = {
        "fund": {"PLANNED", "REFUNDED"}, "prepare-funding": {"PLANNED", "REFUNDED"},
        "cancel-funding": {"PLANNED", "REFUNDED"}, "submit": {"FUNDED"}, "approve": {"SUBMITTED"},
        "release": {"APPROVED"}, "prepare-release": {"APPROVED"},
        "request-changes": {"SUBMITTED"}, "cancel": {"PLANNED"}, "refund": {"FUNDED"},
    }
    next_state = {"submit": "SUBMITTED", "approve": "APPROVED", "request-changes": "FUNDED", "cancel": "CANCELLED"}
    with database.connection() as conn:
        contract = get_one(conn, contract_id, user_id, lock=True)
        require_role(contract, user_id, "freelancer_id" if action == "submit" else "client_id")
        milestone = conn.execute("""
            SELECT amount, status FROM miniupwork.milestone WHERE contract_id = %s AND milestone_id = %s
        """, (contract_id, source_id)).fetchone()
        if milestone is None:
            raise ServiceError("Không tìm thấy mốc bàn giao.", 404, "not_found")
        if milestone["status"] not in required[action]:
            raise conflict("Mốc bàn giao đã đổi trạng thái. Tải lại hợp đồng để tiếp tục.")

        if action in {"release", "prepare-release"}:
            row = conn.execute("""
                INSERT INTO miniupwork.payment_transaction
                    (contract_id, payer_id, payee_id, escrow_funding_id, transaction_type, amount)
                SELECT %s, %s, %s, e.funding_id, 'ESCROW_RELEASE', e.funded_amount FROM miniupwork.escrow_funding e
                WHERE e.milestone_id = %s AND e.status = 'FUNDED' RETURNING payment_id
            """, (contract_id, contract["client_id"], contract["freelancer_id"], source_id)).fetchone()
            if row is None:
                raise conflict("Mốc này không còn khoản ký quỹ để giải ngân.")
            if action == "release":
                set_payment_result(conn, contract_id, row["payment_id"], user_id, "SUCCEEDED")
            return {"status": "RELEASED" if action == "release" else "PENDING", "payment_id": row["payment_id"]}

        if action in {"fund", "prepare-funding", "cancel-funding"}:
            pending = conn.execute("SELECT funding_id FROM miniupwork.escrow_funding WHERE milestone_id=%s AND status='PENDING'",
                                   (source_id,)).fetchone()
            if action == "cancel-funding":
                if pending is None:
                    raise conflict("Mốc này không có khoản ký quỹ đang chờ.")
                conn.execute("UPDATE miniupwork.escrow_funding SET status='CANCELLED' WHERE funding_id=%s",
                             (pending["funding_id"],))
                return {"status": "CANCELLED"}
            if pending is None:
                pending = conn.execute("INSERT INTO miniupwork.escrow_funding (milestone_id,funded_amount) VALUES (%s,%s) RETURNING funding_id",
                                       (source_id, milestone["amount"])).fetchone()
            if action == "prepare-funding":
                return {"status": "PENDING", "funding_id": pending["funding_id"]}
            conn.execute("UPDATE miniupwork.escrow_funding SET status='FUNDED' WHERE funding_id=%s", (pending["funding_id"],))
            return {"status": "FUNDED"}
        if action == "refund":
            changed = conn.execute("UPDATE miniupwork.escrow_funding SET status='REFUNDED' WHERE milestone_id=%s AND status='FUNDED' RETURNING funding_id",
                                   (source_id,)).fetchone()
            if changed is None:
                raise conflict("Mốc này không có khoản ký quỹ đang giữ.")
            return {"status": "REFUNDED"}
        status = next_state[action]
        conn.execute("UPDATE miniupwork.milestone SET status = %s WHERE milestone_id = %s", (status, source_id))
        return {"status": status}


@database_errors
def pay_invoice(database, contract_id, invoice_id, user_id, *, confirm=True):
    with database.connection() as conn:
        contract = get_one(conn, contract_id, user_id, lock=True)
        require_role(contract, user_id, "client_id")
        row = conn.execute("""
            INSERT INTO miniupwork.payment_transaction
                (contract_id, payer_id, payee_id, invoice_id, transaction_type, amount)
            SELECT %s, %s, %s, i.invoice_id, 'HOURLY_CHARGE', totals.amount
            FROM miniupwork.weekly_invoice i CROSS JOIN LATERAL miniupwork.invoice_total(i.invoice_id) totals
            WHERE i.invoice_id = %s AND i.contract_id = %s AND i.status = 'APPROVED'
            RETURNING payment_id
        """, (contract_id, contract["client_id"], contract["freelancer_id"], invoice_id, contract_id)).fetchone()
        if row is None:
            raise conflict("Hóa đơn chưa được duyệt hoặc đã được thanh toán.")
        if confirm:
            set_payment_result(conn, contract_id, row["payment_id"], user_id, "SUCCEEDED")
        return {"status": "PAID" if confirm else "PENDING", "payment_id": row["payment_id"]}


@database_errors
def change_status(database, contract_id, user_id, status):
    with database.connection() as conn:
        item = get_one(conn, contract_id, user_id, lock=True)
        if item["client_id"] != user_id:
            raise ServiceError("Chỉ khách hàng của hợp đồng có thể đổi trạng thái.", 403, "forbidden")
        conn.execute("""
            UPDATE miniupwork.contract SET status=%s,
                end_date=CASE WHEN %s IN ('COMPLETED','TERMINATED') THEN CURRENT_DATE ELSE NULL END
            WHERE contract_id=%s
        """, (status, status, contract_id))
    return {"status": status}


@database_errors
def log_time(database, contract_id, user_id, body):
    with database.connection() as conn:
        item = get_one(conn, contract_id, user_id, lock=True)
        require_role(item, user_id, "freelancer_id")
        if item["contract_type"] != "HOURLY":
            raise conflict("Chỉ hợp đồng theo giờ có thể ghi giờ làm.")
        return conn.execute("""
            INSERT INTO miniupwork.time_entry (contract_id,start_at,end_at,description)
            VALUES (%s,%s,%s,%s) RETURNING entry_id
        """, (contract_id, body.start_at, body.end_at, body.description)).fetchone()


@database_errors
def mark_time(database, contract_id, entry_id, user_id, status):
    with database.connection() as conn:
        item = get_one(conn, contract_id, user_id, lock=True)
        require_role(item, user_id, "client_id")
        row = conn.execute("""
            UPDATE miniupwork.time_entry e
            SET eligibility_status=%s, invoice_id=CASE WHEN %s='INELIGIBLE' THEN NULL ELSE e.invoice_id END
            WHERE e.contract_id=%s AND e.entry_id=%s AND (
                e.invoice_id IS NULL OR EXISTS (
                    SELECT 1 FROM miniupwork.weekly_invoice i WHERE i.invoice_id=e.invoice_id AND i.status='DRAFT'
                )
            ) RETURNING entry_id
        """, (status, status, contract_id, entry_id)).fetchone()
        if not row:
            raise conflict("Chỉ có thể đánh dấu mục giờ chưa lập hóa đơn hoặc thuộc hóa đơn nháp.")
    return {"status": status}


@database_errors
def generate_invoice(database, contract_id, user_id, period_start):
    with database.connection() as conn:
        item = get_one(conn, contract_id, user_id, lock=True)
        require_role(item, user_id, "freelancer_id")
        if item["contract_type"] != "HOURLY" or period_start.weekday() != 0:
            raise conflict("Hóa đơn theo giờ bắt đầu vào thứ Hai theo UTC.")
        invoice = conn.execute("""
            INSERT INTO miniupwork.weekly_invoice (contract_id,period_start) VALUES (%s,%s)
            ON CONFLICT (contract_id,period_start) DO NOTHING RETURNING invoice_id,status
        """, (contract_id, period_start)).fetchone()
        if invoice is None:
            invoice = conn.execute("""
                SELECT invoice_id,status FROM miniupwork.weekly_invoice WHERE contract_id=%s AND period_start=%s
            """, (contract_id, period_start)).fetchone()
        if invoice["status"] != "DRAFT":
            raise conflict("Kỳ này đã có hóa đơn đang xử lý hoặc đã thanh toán.")
        invoice_id = invoice["invoice_id"]
        conn.execute("""
            UPDATE miniupwork.time_entry SET invoice_id=%s WHERE contract_id=%s AND invoice_id IS NULL
              AND eligibility_status='ELIGIBLE' AND start_at >= (%s::date::timestamp AT TIME ZONE 'UTC')
              AND start_at < ((%s::date + 7)::timestamp AT TIME ZONE 'UTC')
        """, (invoice_id, contract_id, period_start, period_start))
        if conn.execute("SELECT amount FROM miniupwork.invoice_total(%s)", (invoice_id,)).fetchone() is None:
            raise conflict("Tuần này chưa có mục giờ đủ điều kiện để lập hóa đơn.")
    return {"invoice_id": invoice_id}


@database_errors
def invoice_action(database, contract_id, invoice_id, user_id, action):
    transitions = {"issue": ("DRAFT", "ISSUED"), "approve": ("ISSUED", "APPROVED"),
                   "dispute": ("ISSUED", "DISPUTED"), "reopen": ("DISPUTED", "DRAFT")}
    with database.connection() as conn:
        item = get_one(conn, contract_id, user_id, lock=True)
        require_role(item, user_id, "freelancer_id" if action == "issue" else "client_id")
        before, after = transitions[action]
        changed = conn.execute("""
            UPDATE miniupwork.weekly_invoice SET status=%s WHERE invoice_id=%s AND contract_id=%s AND status=%s
            RETURNING invoice_id
        """, (after, invoice_id, contract_id, before)).fetchone()
        if not changed:
            raise conflict("Hóa đơn không ở trạng thái phù hợp.")
    return {"status": after}


@database_errors
def reverse_payment(database, contract_id, payment_id, user_id):
    with database.connection() as conn:
        get_one(conn, contract_id, user_id, lock=True)
        payment = conn.execute("""
            SELECT payee_id, transaction_type, status FROM miniupwork.payment_transaction
            WHERE contract_id=%s AND payment_id=%s
        """, (contract_id, payment_id)).fetchone()
        if not payment or payment["transaction_type"] == "REVERSAL" or payment["payee_id"] != user_id:
            raise ServiceError("Chỉ người nhận giao dịch gốc mới có thể ghi giao dịch bù.", 403, "forbidden")
        if payment["status"] != "SUCCEEDED":
            raise conflict("Chỉ có thể bù một giao dịch đã thành công.")
        row = conn.execute("""
            INSERT INTO miniupwork.payment_transaction
                (contract_id,payer_id,payee_id,escrow_funding_id,invoice_id,original_payment_id,transaction_type,amount)
            SELECT contract_id,payee_id,payer_id,escrow_funding_id,invoice_id,payment_id,'REVERSAL',amount
            FROM miniupwork.payment_transaction WHERE payment_id=%s RETURNING payment_id
        """, (payment_id,)).fetchone()
        set_payment_result(conn, contract_id, row["payment_id"], user_id, "SUCCEEDED")
        return row


def set_payment_result(conn, contract_id, payment_id, user_id, status):
    row = conn.execute("""
        UPDATE miniupwork.payment_transaction SET status=%s
        WHERE contract_id=%s AND payment_id=%s AND payer_id=%s AND status='PENDING'
        RETURNING payment_id
    """, (status, contract_id, payment_id, user_id)).fetchone()
    if not row:
        raise conflict("Giao dịch đã đổi trạng thái hoặc bạn không phải người trả.")
    return {"status": status, "payment_id": row["payment_id"]}


@database_errors
def record_payment_result(database, contract_id, payment_id, user_id, status):
    with database.connection() as conn:
        get_one(conn, contract_id, user_id, lock=True)
        return set_payment_result(conn, contract_id, payment_id, user_id, status)


@database_errors
def add_review(database, contract_id, user_id, body):
    with database.connection() as conn:
        item = get_one(conn, contract_id, user_id, lock=True)
        if item["status"] != "COMPLETED":
            raise conflict("Hai bên có thể đánh giá sau khi hợp đồng hoàn thành.")
        other = item["freelancer_id"] if item["client_id"] == user_id else item["client_id"]
        return conn.execute("""
            INSERT INTO miniupwork.review (contract_id,reviewer_id,reviewee_id,rating,comment)
            VALUES (%s,%s,%s,%s,%s) RETURNING review_id
        """, (contract_id, user_id, other, body.rating, body.comment)).fetchone()
