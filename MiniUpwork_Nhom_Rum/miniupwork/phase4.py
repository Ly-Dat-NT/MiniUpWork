"""Authenticated Mini-Upwork local application."""

from pathlib import Path as FilePath
from decimal import Decimal
from typing import Annotated, Literal

from fastapi import Depends, FastAPI, Path, Query, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, ConfigDict, Field, SecretStr
from starlette.middleware.trustedhost import TrustedHostMiddleware

from . import accounts, contracts, recruitment
from .db import Database
from .errors import ServiceError
from .market_models import BillingWeek, ClientProfile, Decision, FreelancerProfile, Registration, Review, Skills, TimeEntry
from .models import InputModel, JobCreate, Money, ProposalInput
from .service import MiniUpworkService, database_errors

WEB = FilePath(__file__).resolve().parent / "web"
ResourceId = Annotated[int, Path(gt=0, le=9223372036854775807)]
FilterId = Annotated[int | None, Query(gt=0, le=9223372036854775807)]
Price = Annotated[Decimal | None, Query(ge=0, le=Decimal("9999999999.99"), decimal_places=2)]


class Credentials(BaseModel):
    model_config = ConfigDict(extra="forbid")
    username: str = Field(pattern=r"^[A-Za-z][A-Za-z0-9_]{2,31}$")
    password: SecretStr = Field(min_length=1, max_length=128)


class Offer(InputModel):
    cover_letter: str = Field(min_length=1, max_length=10000)
    offered_amount: Money


def using_database(request: Request) -> Database:
    return request.app.state.database or Database.from_env()


Db = Annotated[Database, Depends(using_database)]


def signed_in(request: Request, db: Db) -> dict:
    return accounts.current_user(db, request.cookies.get(accounts.COOKIE))


User = Annotated[dict, Depends(signed_in)]


def require(user, role):
    if not user[role]:
        raise ServiceError("Tài khoản này không có vai trò phù hợp.", 403, "forbidden")


def create_app(database: Database | None = None) -> FastAPI:
    app = FastAPI(title="Mini-Upwork · Nhóm Rum", version="1.0.0")
    app.state.database = database
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=["127.0.0.1", "localhost"])
    app.mount("/ui", StaticFiles(directory=WEB), name="ui")

    @app.middleware("http")
    async def private_responses(request: Request, call_next):
        response = await call_next(request)
        response.headers["Cache-Control"] = "no-store"
        return response

    @app.exception_handler(ServiceError)
    async def public_error(request: Request, error: ServiceError):
        return JSONResponse(status_code=error.status_code,
                            content={"detail": {"code": error.code, "message": error.message}})

    @app.exception_handler(RequestValidationError)
    async def invalid_input(request: Request, error: RequestValidationError):
        return JSONResponse(status_code=422, content={"detail": {"code": "invalid_input"}})

    @app.get("/", include_in_schema=False)
    def ui():
        return FileResponse(WEB / "index.html")

    @app.get("/health", tags=["Setup"])
    def health(db: Db):
        return MiniUpworkService(db).health()

    @app.post("/login", tags=["Tài khoản"])
    def login(body: Credentials, request: Request, response: Response, db: Db):
        token = accounts.login(db, body.username, body.password.get_secret_value(), request.cookies.get(accounts.COOKIE))
        response.set_cookie(accounts.COOKIE, token, max_age=accounts.SESSION_SECONDS, httponly=True,
                            secure=request.url.scheme == "https", samesite="strict")
        return {"status": "ok"}

    @app.get("/session", tags=["Tài khoản"])
    def session(user: User):
        return user

    @app.post("/register", status_code=201, tags=["Tài khoản"])
    def register(body: Registration, db: Db):
        return accounts.register(db, body)

    @app.get("/freelancers/{user_id}", tags=["Tài khoản"])
    def profile(user_id: ResourceId, db: Db):
        return accounts.freelancer_profile(db, user_id)

    @app.get("/me/profile", tags=["Tài khoản"])
    def own_profile(user: User, db: Db):
        return accounts.profiles(db, user["user_id"])

    @app.put("/me/profile/client", tags=["Tài khoản"])
    def update_client(body: ClientProfile, user: User, db: Db):
        require(user, "is_client")
        return accounts.update_client(db, user["user_id"], body)

    @app.put("/me/profile/freelancer", tags=["Tài khoản"])
    def update_freelancer(body: FreelancerProfile, user: User, db: Db):
        require(user, "is_freelancer")
        return accounts.update_freelancer(db, user["user_id"], body)

    @app.put("/me/skills", tags=["Tài khoản"])
    def skills(body: Skills, user: User, db: Db):
        require(user, "is_freelancer")
        return accounts.replace_skills(db, user["user_id"], body.skills)

    @app.post("/logout", tags=["Tài khoản"])
    def logout(request: Request, response: Response, db: Db):
        accounts.logout(db, request.cookies.get(accounts.COOKIE))
        response.delete_cookie(accounts.COOKIE)
        return {"status": "ok"}

    @app.get("/reference-data", tags=["Công việc"])
    @database_errors
    def reference_data(user: User, db: Db):
        with db.connection() as conn:
            return {
                "categories": conn.execute("SELECT category_id, category_name, parent_category_id FROM miniupwork.category ORDER BY category_id").fetchall(),
                "skills": conn.execute("SELECT skill_id, skill_name FROM miniupwork.skill ORDER BY skill_id").fetchall(),
            }

    @app.get("/jobs", tags=["Công việc"])
    def jobs(user: User, db: Db, q: Annotated[str | None, Query(max_length=200)] = None,
             category_id: FilterId = None, skill_id: FilterId = None, job_type: Literal["FIXED_PRICE", "HOURLY"] | None = None,
             price_min: Price = None, price_max: Price = None,
             limit: Annotated[int, Query(ge=1, le=100)] = 10,
             offset: Annotated[int, Query(ge=0, le=2147483647)] = 0):
        return MiniUpworkService(db).list_jobs(q=q, category_id=category_id, skill_id=skill_id,
                                              job_type=job_type, price_min=price_min, price_max=price_max, limit=limit, offset=offset)

    @app.get("/jobs/{job_id}", tags=["Công việc"])
    def job(job_id: ResourceId, user: User, db: Db):
        item = MiniUpworkService(db).get_job(job_id)
        if item["status"] != "OPEN" and item["client_id"] != user["user_id"]:
            raise ServiceError("Không tìm thấy công việc đang mở.", 404, "not_found")
        return item

    @app.post("/jobs/{job_id}/proposals", tags=["Công việc"], status_code=201)
    def submit(job_id: ResourceId, body: Offer, user: User, db: Db):
        if not user["is_freelancer"]:
            raise ServiceError("Chỉ tài khoản freelancer có thể gửi đề xuất.", 403, "forbidden")
        return MiniUpworkService(db).submit_proposal(job_id, ProposalInput(freelancer_id=user["user_id"], **body.model_dump()))

    @app.get("/me/jobs", tags=["Tuyển dụng"])
    def own_jobs(user: User, db: Db):
        require(user, "is_client")
        return recruitment.own_jobs(db, user["user_id"])

    @app.post("/me/jobs", status_code=201, tags=["Tuyển dụng"])
    def create_job(body: JobCreate, user: User, db: Db):
        require(user, "is_client")
        if body.client_id != user["user_id"]:
            raise ServiceError("Tin phải do chính tài khoản đăng.", 403, "forbidden")
        return MiniUpworkService(db).create_job(body)

    @app.post("/me/jobs/{job_id}/{action}", tags=["Tuyển dụng"])
    def job_state(job_id: ResourceId, action: Literal["open", "close", "cancel"], user: User, db: Db):
        require(user, "is_client")
        if action == "open":
            return MiniUpworkService(db).open_job(job_id, user["user_id"])
        return recruitment.close_job(db, job_id, user["user_id"], "CLOSED" if action == "close" else "CANCELLED")

    @app.get("/me/jobs/{job_id}/proposals", tags=["Tuyển dụng"])
    def applicants(job_id: ResourceId, user: User, db: Db):
        require(user, "is_client")
        return recruitment.owner_proposals(db, user["user_id"], job_id)

    @app.post("/me/proposals/{proposal_id}/decision", tags=["Tuyển dụng"])
    def decide(proposal_id: ResourceId, body: Decision, user: User, db: Db):
        require(user, "is_client")
        return recruitment.decide(db, proposal_id, user["user_id"], body)

    @app.get("/me/proposals", tags=["Đề xuất"])
    def my_proposals(user: User, db: Db):
        require(user, "is_freelancer")
        return recruitment.my_proposals(db, user["user_id"])

    @app.post("/me/proposals/{proposal_id}/withdraw", tags=["Đề xuất"])
    def withdraw(proposal_id: ResourceId, user: User, db: Db):
        require(user, "is_freelancer")
        return MiniUpworkService(db).withdraw_proposal(proposal_id, user["user_id"])

    @app.put("/me/proposals/{proposal_id}", tags=["Đề xuất"])
    def update_proposal(proposal_id: ResourceId, body: Offer, user: User, db: Db):
        require(user, "is_freelancer")
        return MiniUpworkService(db).update_offer(
            proposal_id, ProposalInput(freelancer_id=user["user_id"], **body.model_dump()), previous_status="SUBMITTED"
        )

    @app.post("/me/proposals/{proposal_id}/resubmit", tags=["Đề xuất"])
    def resubmit(proposal_id: ResourceId, body: Offer, user: User, db: Db):
        require(user, "is_freelancer")
        return MiniUpworkService(db).resubmit_proposal(proposal_id, ProposalInput(freelancer_id=user["user_id"], **body.model_dump()))

    @app.get("/contracts", tags=["Hợp đồng"])
    def list_contracts(user: User, db: Db):
        return contracts.list_contracts(db, user["user_id"])

    @app.get("/contracts/{contract_id}", tags=["Hợp đồng"])
    def get_contract(contract_id: ResourceId, user: User, db: Db):
        return contracts.contract_detail(db, contract_id, user["user_id"])

    @app.post("/contracts/{contract_id}/milestones/{source_id}/{action}", tags=["Hợp đồng"])
    def change_milestone(contract_id: ResourceId, source_id: ResourceId,
                         action: Literal["fund", "prepare-funding", "cancel-funding", "submit", "approve", "release",
                                         "prepare-release", "request-changes", "refund", "cancel"],
                         user: User, db: Db):
        return contracts.milestone_action(db, contract_id, source_id, user["user_id"], action)

    @app.post("/contracts/{contract_id}/invoices/{invoice_id}/pay", tags=["Hợp đồng"])
    def pay_invoice(contract_id: ResourceId, invoice_id: ResourceId, user: User, db: Db):
        return contracts.pay_invoice(db, contract_id, invoice_id, user["user_id"])

    @app.post("/contracts/{contract_id}/invoices/{invoice_id}/prepare-payment", tags=["Theo giờ"])
    def prepare_payment(contract_id: ResourceId, invoice_id: ResourceId, user: User, db: Db):
        return contracts.pay_invoice(db, contract_id, invoice_id, user["user_id"], confirm=False)

    @app.post("/contracts/{contract_id}/payments/{payment_id}/result/{status}", tags=["Hợp đồng"])
    def payment_result(contract_id: ResourceId, payment_id: ResourceId,
                       status: Literal["SUCCEEDED", "FAILED"], user: User, db: Db):
        return contracts.record_payment_result(db, contract_id, payment_id, user["user_id"], status)

    @app.post("/contracts/{contract_id}/status/{status}", tags=["Hợp đồng"])
    def contract_status(contract_id: ResourceId, status: Literal["ACTIVE", "PAUSED", "COMPLETED", "TERMINATED"], user: User, db: Db):
        return contracts.change_status(db, contract_id, user["user_id"], status)

    @app.post("/contracts/{contract_id}/time", status_code=201, tags=["Theo giờ"])
    def log_time(contract_id: ResourceId, body: TimeEntry, user: User, db: Db):
        return contracts.log_time(db, contract_id, user["user_id"], body)

    @app.post("/contracts/{contract_id}/time/{entry_id}/{status}", tags=["Theo giờ"])
    def eligibility(contract_id: ResourceId, entry_id: ResourceId, status: Literal["ELIGIBLE", "INELIGIBLE"], user: User, db: Db):
        return contracts.mark_time(db, contract_id, entry_id, user["user_id"], status)

    @app.post("/contracts/{contract_id}/invoices", tags=["Theo giờ"])
    def generate_invoice(contract_id: ResourceId, body: BillingWeek, user: User, db: Db):
        return contracts.generate_invoice(db, contract_id, user["user_id"], body.period_start)

    @app.post("/contracts/{contract_id}/invoices/{invoice_id}/{action}", tags=["Theo giờ"])
    def invoice_state(contract_id: ResourceId, invoice_id: ResourceId, action: Literal["issue", "approve", "dispute", "reopen"], user: User, db: Db):
        return contracts.invoice_action(db, contract_id, invoice_id, user["user_id"], action)

    @app.post("/contracts/{contract_id}/payments/{payment_id}/reverse", status_code=201, tags=["Hợp đồng"])
    def reverse_payment(contract_id: ResourceId, payment_id: ResourceId, user: User, db: Db):
        return contracts.reverse_payment(db, contract_id, payment_id, user["user_id"])

    @app.post("/contracts/{contract_id}/reviews", status_code=201, tags=["Hợp đồng"])
    def review(contract_id: ResourceId, body: Review, user: User, db: Db):
        return contracts.add_review(db, contract_id, user["user_id"], body)

    return app


app = create_app()
