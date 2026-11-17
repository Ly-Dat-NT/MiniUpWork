"""Hiring and proposal actions. Each write takes the job lock first."""

from .errors import ServiceError, conflict
from .service import MiniUpworkService, database_errors, json_safe


def check_owner(job, user_id):
    if job["client_id"] != user_id:
        raise ServiceError("Không tìm thấy tin tuyển dụng của bạn.", 404, "not_found")


@database_errors
def own_jobs(database, client_id):
    with database.connection() as conn:
        return json_safe(conn.execute("""
            SELECT j.job_id,j.title,j.job_type,j.status,COUNT(p.proposal_id) AS proposal_count
            FROM miniupwork.job j LEFT JOIN miniupwork.proposal p USING (job_id)
            WHERE j.client_id=%s GROUP BY j.job_id ORDER BY j.job_id DESC
        """, (client_id,)).fetchall())


@database_errors
def owner_proposals(database, client_id, job_id):
    with database.connection() as conn:
        check_owner(MiniUpworkService._job(conn, job_id), client_id)
        rows = conn.execute("""
            SELECT p.proposal_id,p.freelancer_id,p.offered_amount,p.cover_letter,p.status,p.submitted_at,u.full_name
            FROM miniupwork.proposal p JOIN miniupwork.app_user u ON u.user_id=p.freelancer_id
            WHERE p.job_id=%s ORDER BY p.proposal_id
        """, (job_id,)).fetchall()
    return json_safe(rows)


@database_errors
def my_proposals(database, freelancer_id):
    with database.connection() as conn:
        return json_safe(conn.execute("""
            SELECT p.proposal_id,p.job_id,j.title,j.status AS job_status,p.status,p.offered_amount,p.cover_letter
            FROM miniupwork.proposal p JOIN miniupwork.job j USING (job_id)
            WHERE p.freelancer_id=%s ORDER BY p.proposal_id DESC
        """, (freelancer_id,)).fetchall())


@database_errors
def close_job(database, job_id, client_id, target):
    with database.connection() as conn:
        job = MiniUpworkService._job(conn, job_id, lock=True)
        check_owner(job, client_id)
        if job["status"] not in {"DRAFT", "OPEN"} or (target == "CLOSED" and job["status"] != "OPEN"):
            raise conflict("Trạng thái hiện tại không cho phép thao tác này.")
        conn.execute("UPDATE miniupwork.job SET status=%s WHERE job_id=%s", (target, job_id))
    return {"status": target}


@database_errors
def repost_job(database, job_id, client_id):
    service = MiniUpworkService(database)
    with database.connection() as conn:
        source = service._job(conn, job_id, lock=True)
        check_owner(source, client_id)
        service._active_profile(conn, "client", client_id)
        if source["status"] != "CLOSED":
            raise conflict("Chỉ tin đã đóng mới có thể đăng lại.")

        new_id = conn.execute("""
            INSERT INTO miniupwork.job (client_id, category_id, title, description, job_type)
            SELECT client_id, category_id, title, description, job_type
            FROM miniupwork.job WHERE job_id=%s RETURNING job_id
        """, (job_id,)).fetchone()["job_id"]
        if source["job_type"] == "FIXED_PRICE":
            conn.execute("""
                INSERT INTO miniupwork.fixed_price_job (job_id, budget_amount)
                SELECT %s, budget_amount FROM miniupwork.fixed_price_job WHERE job_id=%s
            """, (new_id, job_id))
        else:
            conn.execute("""
                INSERT INTO miniupwork.hourly_job (job_id, rate_min, rate_max)
                SELECT %s, rate_min, rate_max FROM miniupwork.hourly_job WHERE job_id=%s
            """, (new_id, job_id))
        conn.execute("""
            INSERT INTO miniupwork.job_skill (job_id, skill_id, required_level)
            SELECT %s, skill_id, required_level FROM miniupwork.job_skill WHERE job_id=%s
        """, (new_id, job_id))
        service._publish_draft(conn, new_id)
        result = service._job_document(conn, new_id)
    return result


@database_errors
def decide(database, proposal_id, client_id, body):
    service = MiniUpworkService(database)
    with database.connection() as conn:
        job, proposal = service._locked_proposal(conn, proposal_id)
        check_owner(job, client_id)
        if job["status"] != "OPEN" or proposal["status"] not in {"SUBMITTED", "SHORTLISTED"} or proposal["status"] == body.status:
            raise conflict("Tin hoặc đề xuất đã chuyển trạng thái.")
        if (body.status == "ACCEPTED" and body.expected_offered_amount is not None
                and body.expected_offered_amount != proposal["offered_amount"]):
            raise conflict("Freelancer đã sửa giá. Đóng biểu mẫu và tải lại đề xuất trước khi chấp nhận.")
        conn.execute("UPDATE miniupwork.proposal SET status=%s WHERE proposal_id=%s", (body.status, proposal_id))
        if body.status != "ACCEPTED":
            return {"status": body.status}

        contract_id = conn.execute("""
            INSERT INTO miniupwork.contract (proposal_id,contract_type,start_date)
            VALUES (%s,%s,CURRENT_DATE) RETURNING contract_id
        """, (proposal_id, job["job_type"])).fetchone()["contract_id"]
        amount = proposal["offered_amount"]
        if job["job_type"] == "FIXED_PRICE":
            milestones = body.milestones
            if not milestones or sum(row.amount for row in milestones) != amount:
                raise conflict("Tổng các mốc bàn giao phải bằng giá đã chấp nhận.")
            conn.execute("INSERT INTO miniupwork.fixed_price_contract VALUES (%s,%s)", (contract_id, amount))
            with conn.cursor() as cursor:
                cursor.executemany("""
                    INSERT INTO miniupwork.milestone (contract_id,sequence_no,title,amount,due_date)
                    VALUES (%s,%s,%s,%s,%s)
                """, [(contract_id, i, row.title, row.amount, row.due_date) for i, row in enumerate(milestones, 1)])
        else:
            conn.execute("INSERT INTO miniupwork.hourly_contract VALUES (%s,%s,%s)", (contract_id, amount, body.weekly_limit))
        conn.execute("UPDATE miniupwork.proposal SET status='REJECTED' WHERE job_id=%s AND status IN ('SUBMITTED','SHORTLISTED')",
                     (job["job_id"],))
        conn.execute("UPDATE miniupwork.job SET status='CLOSED' WHERE job_id=%s", (job["job_id"],))
    return {"status": "ACCEPTED", "contract_id": contract_id}
