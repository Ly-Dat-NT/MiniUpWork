"""Contract reads and state changes scoped to the signed-in participant."""

from decimal import Decimal, ROUND_HALF_UP
from hashlib import sha256

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
def list_contracts(database, user_id, *, role=None):
    conditions = {"client": "j.client_id = %s", "freelancer": "p.freelancer_id = %s"}
    scope = conditions.get(role)
    params = (user_id,) if scope else (user_id, user_id)
    scope = scope or _SCOPE
    with database.connection() as conn:
        rows = conn.execute(_CONTRACT + f" WHERE {scope} ORDER BY c.contract_id", params).fetchall()
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
            contract["cancellation"] = conn.execute("""
                SELECT s.*, fee.paid_at AS penalty_paid_at
                FROM miniupwork.fixed_cancellation s LEFT JOIN miniupwork.fixed_cancellation_fee_payment fee USING (contract_id)
                WHERE s.contract_id = %s
            """, (contract_id,)).fetchone()
        else:
            contract["invoices"] = conn.execute("""
                SELECT i.invoice_id, i.period_start, i.period_end, i.status, i.total_hours AS hours, i.total_amount AS amount
                FROM miniupwork.weekly_invoice_summary i
                WHERE i.contract_id = %s ORDER BY i.period_start
            """, (contract_id,)).fetchall()
            contract["time_entries"] = conn.execute("""
                SELECT e.entry_id, e.invoice_id, e.start_at, e.end_at, e.description, e.eligibility_status,
                       e.billing_week, e.carryover_week, duration.seconds / 3600 AS hours,
                       ROUND(duration.seconds * h.hourly_rate / 3600, 2) AS amount
                FROM miniupwork.time_entry e JOIN miniupwork.hourly_contract h USING (contract_id)
                CROSS JOIN LATERAL (SELECT EXTRACT(epoch FROM e.end_at - e.start_at) AS seconds) duration
                WHERE e.contract_id=%s ORDER BY e.start_at DESC, e.entry_id DESC
            """, (contract_id,)).fetchall()
            contract["unbilled_weeks"] = conn.execute("""
                SELECT e.billing_week,
                       ROUND(SUM(EXTRACT(epoch FROM (e.end_at - e.start_at))) / 3600, 2) AS hours,
                       ROUND(SUM(EXTRACT(epoch FROM (e.end_at - e.start_at))) * h.hourly_rate / 3600, 2) AS amount
                FROM miniupwork.time_entry e JOIN miniupwork.hourly_contract h USING (contract_id)
                WHERE e.contract_id=%s AND e.invoice_id IS NULL AND e.eligibility_status='ELIGIBLE'
                GROUP BY e.billing_week, h.hourly_rate ORDER BY e.billing_week DESC
            """, (contract_id,)).fetchall()
        contract["payments"] = conn.execute("""
            SELECT p.payment_id,p.transaction_type,p.amount,p.currency_code,p.created_at,p.original_payment_id,
                   p.payer_id,p.payee_id,p.status,p.invoice_id,e.milestone_id,
                   EXISTS (SELECT 1 FROM miniupwork.fixed_cancellation_payout cp
                           WHERE cp.payment_id=p.payment_id) AS net_cancellation_payout,
                   EXISTS (SELECT 1 FROM miniupwork.payment_transaction r WHERE r.original_payment_id=p.payment_id
                           AND r.status IN ('PENDING','SUCCEEDED')) AS reversed
            FROM miniupwork.payment_transaction p LEFT JOIN miniupwork.escrow_funding e ON e.funding_id=p.escrow_funding_id
            WHERE p.contract_id = %s ORDER BY p.created_at DESC, p.payment_id DESC
        """, (contract_id,)).fetchall()
        contract["reviews"] = conn.execute("""
            SELECT r.milestone_id, r.rating, r.comment, r.submitted_at, r.reviewer_id, r.reviewee_id, u.full_name AS reviewer
            FROM miniupwork.review r JOIN miniupwork.app_user u ON u.user_id = r.reviewer_id
            WHERE r.contract_id = %s ORDER BY r.review_id
        """, (contract_id,)).fetchall()
    return json_safe(contract)


def require_role(contract, user_id, role):
    if user_id != contract[role]:
        raise ServiceError("Tài khoản này không có quyền thực hiện thao tác.", 403, "forbidden")
    if contract["status"] != "ACTIVE":
        raise conflict("Hợp đồng hiện không ở trạng thái thực hiện.")


def prepare_release(conn, contract, source_id):
    row = conn.execute("""
        INSERT INTO miniupwork.payment_transaction
            (contract_id, payer_id, payee_id, escrow_funding_id, transaction_type, amount)
        SELECT %s, %s, %s, e.funding_id, 'ESCROW_RELEASE', e.funded_amount FROM miniupwork.escrow_funding e
        WHERE e.milestone_id = %s AND e.status = 'FUNDED' RETURNING payment_id
    """, (contract["contract_id"], contract["client_id"], contract["freelancer_id"], source_id)).fetchone()
    if row is None:
        raise conflict("Mốc này không còn khoản ký quỹ để giải ngân.")
    return row["payment_id"]


@database_errors
def milestone_action(database, contract_id, source_id, user_id, action):
    required = {
        "fund": {"PLANNED", "REFUNDED"}, "prepare-funding": {"PLANNED", "REFUNDED"},
        "cancel-funding": {"PLANNED", "REFUNDED"}, "submit": {"FUNDED"}, "approve": {"SUBMITTED"},
        "release": {"APPROVED"}, "prepare-release": {"APPROVED"}, "approve-release": {"SUBMITTED"},
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

        if action in {"release", "prepare-release", "approve-release"}:
            if action == "approve-release":
                conn.execute("UPDATE miniupwork.milestone SET status='APPROVED' WHERE milestone_id=%s", (source_id,))
            payment_id = prepare_release(conn, contract, source_id)
            if action == "prepare-release":
                return {"status": "PENDING", "payment_id": payment_id}
            set_payment_result(conn, contract_id, payment_id, user_id, "SUCCEEDED")
            return {"status": "RELEASED", "payment_id": payment_id}

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
        if status == "TERMINATED" and conn.execute("""
            SELECT EXISTS (
                SELECT 1 FROM miniupwork.escrow_funding e JOIN miniupwork.milestone m USING (milestone_id)
                WHERE m.contract_id=%s AND e.status IN ('PENDING','FUNDED')
                UNION ALL
                SELECT 1 FROM miniupwork.weekly_invoice WHERE contract_id=%s AND status='APPROVED'
                UNION ALL
                SELECT 1 FROM miniupwork.payment_transaction WHERE contract_id=%s AND status='PENDING'
            ) AS unsettled
        """, (contract_id, contract_id, contract_id)).fetchone()["unsettled"]:
            raise conflict("Hãy xử lý ký quỹ và giao dịch hoặc hóa đơn đang chờ trước khi kết thúc hợp đồng.")
        conn.execute("""
            UPDATE miniupwork.contract SET status=%s,
                end_date=CASE WHEN %s IN ('COMPLETED','TERMINATED') THEN CURRENT_DATE ELSE NULL END
            WHERE contract_id=%s
        """, (status, status, contract_id))
    return {"status": status}


def fixed_cancellation_quote(conn, item):
    if item["contract_type"] != "FIXED_PRICE" or item["status"] not in {"ACTIVE", "PAUSED"}:
        raise conflict("Chỉ có thể hủy sớm hợp đồng trọn gói đang thực hiện hoặc đang tạm dừng.")
    contract_id = item["contract_id"]
    milestones = conn.execute("""
        SELECT milestone_id, status, amount FROM miniupwork.milestone
        WHERE contract_id=%s ORDER BY sequence_no
    """, (contract_id,)).fetchall()
    count = len(milestones)
    completed = sum(row["status"] in {"APPROVED", "RELEASED"} for row in milestones)
    if completed == count:
        raise conflict("Mọi mốc đã được nghiệm thu. Hãy hoàn tất quy trình thanh toán và kết thúc hợp đồng.")
    zero = Decimal("0.00")
    payout = sum((row["amount"] for row in milestones if row["status"] == "APPROVED"), zero)
    refund = sum((row["amount"] for row in milestones if row["status"] in {"FUNDED", "SUBMITTED"}), zero)
    paid = conn.execute("""
        SELECT COALESCE(SUM(CASE WHEN transaction_type='ESCROW_RELEASE' THEN amount ELSE -amount END), 0) AS net
        FROM miniupwork.payment_transaction
        WHERE contract_id=%s AND status='SUCCEEDED' AND transaction_type IN ('ESCROW_RELEASE','REVERSAL')
    """, (contract_id,)).fetchone()["net"]
    rate = Decimal("0.20") * (count - completed) / count
    penalty = (item["agreed_amount"] * rate).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    withheld = min(payout, penalty)
    amounts = {
        "completed_count": completed, "milestone_count": count,
        "rate_percent": (rate * 100).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP),
        "already_paid": paid, "gross_payout": payout, "refunded_escrow": refund,
        "assessed_penalty": penalty, "withheld_penalty": withheld,
    }
    quote = sha256(repr((contract_id, item["status"], milestones, amounts)).encode()).hexdigest()
    return {
        **amounts, "quote": quote, "outstanding_penalty": penalty - withheld,
        "net_payout": payout - withheld,
    }, milestones


@database_errors
def cancel_fixed_contract(database, contract_id, user_id, *, expected_quote=None):
    with database.connection() as conn:
        item = get_one(conn, contract_id, user_id, lock=True)
        if item["freelancer_id"] != user_id:
            raise ServiceError("Chỉ freelancer của hợp đồng có thể dùng chức năng hủy sớm.", 403, "forbidden")
        quote, milestones = fixed_cancellation_quote(conn, item)
        if expected_quote is None:
            return json_safe(quote)
        if quote["quote"] != expected_quote:
            raise conflict("Tiến độ hoặc số tiền vừa thay đổi. Mở lại bản tính phí trước khi xác nhận.", "cancellation_quote_changed")
        conn.execute("SELECT miniupwork.lock_contract_wallets(%s)", (contract_id,))
        if item["status"] == "PAUSED":
            # Existing settlement triggers require ACTIVE. The temporary change stays in this transaction.
            conn.execute("UPDATE miniupwork.contract SET status='ACTIVE' WHERE contract_id=%s", (contract_id,))
        payouts = []
        for row in milestones:
            source_id = row["milestone_id"]
            status = row["status"]
            if status == "APPROVED":
                pending = conn.execute("""
                    SELECT p.payment_id FROM miniupwork.payment_transaction p
                    JOIN miniupwork.escrow_funding e ON e.funding_id=p.escrow_funding_id
                    WHERE e.milestone_id=%s AND p.transaction_type='ESCROW_RELEASE' AND p.status='PENDING'
                """, (source_id,)).fetchone()
                payment_id = pending["payment_id"] if pending else prepare_release(conn, item, source_id)
                set_payment_result(conn, contract_id, payment_id, item["client_id"], "SUCCEEDED")
                payouts.append((contract_id, payment_id))
            elif status in {"SUBMITTED", "FUNDED"}:
                if status == "SUBMITTED":
                    conn.execute("UPDATE miniupwork.milestone SET status='FUNDED' WHERE milestone_id=%s", (source_id,))
                refunded = conn.execute("""
                    UPDATE miniupwork.escrow_funding SET status='REFUNDED'
                    WHERE milestone_id=%s AND status='FUNDED' RETURNING funding_id
                """, (source_id,)).fetchone()
                if refunded is None:
                    raise conflict("Không tìm thấy khoản ký quỹ cần hoàn. Hợp đồng chưa được hủy.")
            elif status in {"PLANNED", "REFUNDED"}:
                conn.execute("UPDATE miniupwork.escrow_funding SET status='CANCELLED' WHERE milestone_id=%s AND status='PENDING'",
                             (source_id,))
                if status == "PLANNED":
                    conn.execute("UPDATE miniupwork.milestone SET status='CANCELLED' WHERE milestone_id=%s", (source_id,))
        conn.execute("""
            INSERT INTO miniupwork.fixed_cancellation (contract_id, completed_count, milestone_count, rate_percent,
                already_paid, gross_payout, refunded_escrow, assessed_penalty, withheld_penalty)
            VALUES (%(contract_id)s, %(completed_count)s, %(milestone_count)s, %(rate_percent)s,
                %(already_paid)s, %(gross_payout)s, %(refunded_escrow)s, %(assessed_penalty)s, %(withheld_penalty)s)
        """, {**quote, "contract_id": contract_id})
        if quote["withheld_penalty"]:
            with conn.cursor() as cursor:
                cursor.executemany("INSERT INTO miniupwork.fixed_cancellation_payout VALUES (%s,%s)", payouts)
        conn.execute("UPDATE miniupwork.contract SET status='TERMINATED', end_date=CURRENT_DATE WHERE contract_id=%s",
                     (contract_id,))
    return {"status": "TERMINATED"}


@database_errors
def pay_cancellation_fee(database, contract_id, user_id):
    with database.connection() as conn:
        item = get_one(conn, contract_id, user_id, lock=True)
        if item["freelancer_id"] != user_id:
            raise ServiceError("Chỉ freelancer của hợp đồng có thể thanh toán phí hủy.", 403, "forbidden")
        charge = conn.execute("""
            SELECT outstanding_penalty FROM miniupwork.fixed_cancellation WHERE contract_id=%s
        """, (contract_id,)).fetchone()
        if not charge or not charge["outstanding_penalty"]:
            raise conflict("Hợp đồng này không có phí hủy cần thanh toán.")
        conn.execute("""
            INSERT INTO miniupwork.fixed_cancellation_fee_payment (contract_id) VALUES (%s)
            ON CONFLICT (contract_id) DO NOTHING
        """, (contract_id,))
    return {"status": "PAID"}


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
        if invoice["status"] not in {"DRAFT", "VOID"}:
            raise conflict("Kỳ này đã có hóa đơn đang xử lý hoặc đã thanh toán.")
        invoice_id = invoice["invoice_id"]
        if invoice["status"] == "VOID":
            conn.execute("UPDATE miniupwork.weekly_invoice SET status='DRAFT' WHERE invoice_id=%s", (invoice_id,))
        attach_billable_time(conn, contract_id, invoice_id, period_start)
        if conn.execute("SELECT amount FROM miniupwork.invoice_total(%s)", (invoice_id,)).fetchone() is None:
            raise conflict("Tuần này chưa có mục giờ đủ điều kiện để lập hóa đơn.")
    return {"invoice_id": invoice_id}


def attach_billable_time(conn, contract_id, invoice_id, period_start):
    conn.execute("""
        UPDATE miniupwork.time_entry SET invoice_id=%s
        WHERE contract_id=%s AND billing_week=%s AND invoice_id IS NULL AND eligibility_status='ELIGIBLE'
    """, (invoice_id, contract_id, period_start))


@database_errors
def invoice_action(database, contract_id, invoice_id, user_id, action):
    transitions = {"issue": ("DRAFT", "ISSUED"), "approve": ("ISSUED", "APPROVED"),
                   "dispute": ("ISSUED", "DISPUTED"), "reopen": ("DISPUTED", "DRAFT")}
    with database.connection() as conn:
        item = get_one(conn, contract_id, user_id, lock=True)
        require_role(item, user_id, "freelancer_id" if action == "issue" else "client_id")
        before, after = transitions[action]
        invoice = conn.execute("""
            SELECT period_start, status, total_amount FROM miniupwork.weekly_invoice_summary
            WHERE invoice_id=%s AND contract_id=%s
        """, (invoice_id, contract_id)).fetchone()
        if not invoice or invoice["status"] != before:
            raise conflict("Hóa đơn không ở trạng thái phù hợp.")
        if action == "issue":
            attach_billable_time(conn, contract_id, invoice_id, invoice["period_start"])
        if action == "approve" and invoice["total_amount"] == 0:
            after = "NO_CHARGE"
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
        if (not payment or payment["transaction_type"] not in {"ESCROW_RELEASE", "HOURLY_CHARGE"}
                or payment["payee_id"] != user_id):
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
def add_review(database, contract_id, user_id, body, *, milestone_id=None):
    with database.connection() as conn:
        item = get_one(conn, contract_id, user_id, lock=True)
        if milestone_id is not None:
            milestone = conn.execute("SELECT status FROM miniupwork.milestone WHERE contract_id=%s AND milestone_id=%s",
                                     (contract_id, milestone_id)).fetchone()
            if not milestone:
                raise ServiceError("Không tìm thấy mốc bàn giao.", 404, "not_found")
            if milestone["status"] != "RELEASED":
                raise conflict("Hai bên có thể đánh giá sau khi mốc đã được giải ngân.")
        elif item["contract_type"] == "FIXED_PRICE":
            raise conflict("Hãy chọn mốc đã giải ngân để gửi đánh giá.")
        elif item["status"] != "COMPLETED":
            raise conflict("Hai bên có thể đánh giá sau khi hợp đồng hoàn thành.")
        other = item["freelancer_id"] if item["client_id"] == user_id else item["client_id"]
        review = conn.execute("""
            INSERT INTO miniupwork.review (contract_id,milestone_id,reviewer_id,reviewee_id,rating,comment)
            VALUES (%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING RETURNING review_id
        """, (contract_id, milestone_id, user_id, other, body.rating, body.comment)).fetchone()
        if not review:
            raise conflict("Bạn đã gửi đánh giá cho mục này.")
        return review
