# Mini-Upwork — Freelance Marketplace Ecosystem

Mini-Upwork is an academic database project developed by Team Rum. Inspired by Upwork, the system connects clients and freelancers and supports the freelance workflow, from job posting and proposal submission to contract management, work tracking, simulated payment settlement, and reviews.

The project focuses on relational database design, SQL programming, data integrity, and the integration of a PostgreSQL database with a web application.

## Features

| Module | Functionality |
| --- | --- |
| User management | Registration, login, logout, client and freelancer profiles, and dual-role accounts |
| Job marketplace | Job posting, categories, required skills, search, price filtering, and fixed-price or hourly jobs |
| Recruitment | Proposal submission, editing, withdrawal, resubmission, and client decisions |
| Contract management | Contract creation from accepted proposals, contract status tracking, and fixed-price or hourly contracts |
| Fixed-price work | Milestone tracking, escrow funding, work submission, approval, release, and refunds |
| Hourly work | Time entries, eligibility checks, weekly invoices, and invoice settlement |
| Payment management | Simulated USD transactions, success/failure confirmation, reversals, and payment history |
| Reviews | Two-way contract reviews and aggregated user ratings |

## Technology Stack

| Component | Technology |
| --- | --- |
| Frontend | HTML, CSS, JavaScript |
| Backend | Python, FastAPI |
| ASGI server | Uvicorn |
| Database | PostgreSQL |
| Database driver | Psycopg 3 |
| Input validation | Pydantic |
| Configuration | python-dotenv |

## System Architecture

```text
Browser (HTML / CSS / JavaScript)
              |
              | HTTP requests / JSON responses
              v
        FastAPI Backend
              |
              | Psycopg / SQL transactions
              v
          PostgreSQL
```

The browser communicates with FastAPI through HTTP endpoints. The backend validates requests, checks user sessions and roles, and executes SQL operations. PostgreSQL stores persistent data and enforces business rules through keys, constraints, triggers, and transactions. The application uses cookie-based sessions and serves the frontend and API from the same local server.

## Project Structure

```text
MiniUpWork/
├── index.html                       # Main web interface
└── MiniUpwork_Nhom_Rum/
    ├── README.md                    # Original local demo instructions
    ├── requirements.txt             # Python dependencies
    ├── run_local.py                 # Database setup, upgrades and server launch
    ├── MO_MINIUPWORK_RUM.cmd         # Windows launcher
    ├── DOI_CHIEU_PHASE1_2.md         # Conceptual/logical design comparison
    ├── DOI_CHIEU_WORD_VA_SO_DO.md     # Report and diagram alignment
    ├── miniupwork/
    │   ├── phase4.py                # FastAPI application and endpoints
    │   ├── accounts.py              # Authentication and profile management
    │   ├── recruitment.py           # Recruitment workflows
    │   ├── contracts.py             # Contracts, work and payment workflows
    │   ├── service.py               # Marketplace database operations
    │   ├── db.py                    # PostgreSQL connections and transactions
    │   ├── config.py                # Database configuration
    │   ├── models.py                # Request models
    │   ├── market_models.py         # Additional marketplace models
    │   ├── errors.py                # Application errors
    │   ├── __init__.py
    │   └── web/
    │       ├── app.js               # Main interface logic
    │       ├── manage.js            # Account and recruitment management
    │       └── style.css            # Interface styling
    └── sql/
        ├── 01_schema.sql
        ├── 02_proposal_phase3.sql
        ├── 03_contracts.sql
        ├── 04_seed_rum.sql
        ├── 05_queries.sql
        ├── 06_verify.sql
        ├── 07_phase12_upgrade.sql
        ├── 08_benchmark_fixture.sql
        └── 09_report_alignment.sql
```

## Installation and Local Setup

### Prerequisites

- Python 3 (a recent version such as Python 3.12 is recommended) and pip
- A running local PostgreSQL server
- A PostgreSQL administrator account with permission to create databases and runtime roles
- Git (if cloning the repository) and a web browser

The original project documentation reports testing with Chrome and PostgreSQL 18.7. This README does not establish a minimum supported PostgreSQL version.

### 1. Clone the repository

```bash
git clone https://github.com/Ly-Dat-NT/MiniUpWork.git
cd MiniUpWork
```

### 2. Prepare the frontend and install dependencies

> **Frontend path:** In the supplied repository snapshot, `index.html` is at the repository root, but FastAPI expects it inside `MiniUpwork_Nhom_Rum/miniupwork/web/`. Copy it to the expected location before launching the application.

**Windows (PowerShell)**

```powershell
Copy-Item .\index.html .\MiniUpwork_Nhom_Rum\miniupwork\web\index.html
cd MiniUpwork_Nhom_Rum
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

**Linux / macOS (shell)**

```bash
cp index.html MiniUpwork_Nhom_Rum/miniupwork/web/index.html
cd MiniUpwork_Nhom_Rum
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
```

### 3. Configure PostgreSQL

The launcher prompts for the PostgreSQL port, username, and password if no connection configuration is available. The default host is `127.0.0.1`, and the default port is `5432`.

Optionally, create a `.env` file in `MiniUpwork_Nhom_Rum/` using your own local settings:

```dotenv
DATABASE_URL=postgresql://postgres@127.0.0.1:5432/postgres
DATABASE_PASSWORD=YOUR_LOCAL_POSTGRES_PASSWORD
```

Replace the placeholder with your own password. Keep `.env` and the generated `.rum-runtime.json` private; do not commit them to GitHub.

### 4. Run the application

From the `MiniUpwork_Nhom_Rum/` directory:

**Windows (PowerShell)**

```powershell
.\.venv\Scripts\python.exe run_local.py
```

**Linux / macOS**

```bash
.venv/bin/python run_local.py
```

On Windows, `MO_MINIUPWORK_RUM.cmd` is also available after creating the virtual environment.

The launcher creates or reuses the `miniupwork_nhom_rum` database, installs the initial schema and sample data, applies versioned upgrades, and configures a restricted PostgreSQL runtime role. It then starts the local Uvicorn server. Existing installed data is reused on subsequent launches.

### 5. Open the application

| Resource | Address |
| --- | --- |
| Web application | http://127.0.0.1:8016/ |
| Interactive API documentation | http://127.0.0.1:8016/docs |
| OpenAPI schema | http://127.0.0.1:8016/openapi.json |
| Database health endpoint | http://127.0.0.1:8016/health |

Keep the terminal running while using the application. Register a new account or use the seeded demo accounts described in the [original team README](MiniUpwork_Nhom_Rum/README.md). Application account passwords are separate from PostgreSQL credentials.

## Database Implementation

The application uses the `miniupwork` PostgreSQL schema. The database design includes user and role tables, job and contract subtypes, associative skill tables, proposals, milestones, escrow funding, time entries, weekly invoices, payment transactions, and reviews.

Database integrity is maintained using primary keys, foreign keys, unique constraints, check constraints, indexes, triggers, and transaction-level validation. Examples include prevention of duplicate proposals, subtype consistency, validation of billing sources, time-entry overlap checks, and protection of successful financial records.

Two derived views support reporting:

- `miniupwork.rating_summary` — aggregates received reviews into user rating statistics.
- `miniupwork.weekly_invoice_summary` — summarizes weekly invoice totals from the underlying work data.

### SQL Scripts

| File | Purpose |
| --- | --- |
| `01_schema.sql` | Core user, role, skill, category, job and proposal schema and constraints |
| `02_proposal_phase3.sql` | Proposal workflow extensions |
| `03_contracts.sql` | Sessions, contracts, milestones, escrow, invoices, payments, reviews and triggers |
| `04_seed_rum.sql` | Initial fictional sample dataset |
| `05_queries.sql` | Eleven complex analytical queries |
| `06_verify.sql` | Initial dataset and integrity checks with rollback |
| `07_phase12_upgrade.sql` | Schema upgrade and Phase 1–2 business-rule alignment |
| `08_benchmark_fixture.sql` | Additional synthetic data for performance testing |
| `09_report_alignment.sql` | Further report alignment, financial lifecycle changes and derived views |

Use `run_local.py` for initialization and upgrades; do not execute all SQL files indiscriminately in filename order. The launcher installs scripts 01–04 and then applies 07 and 09 according to the schema version. Scripts 05, 06, and 08 are intended for analysis, verification, or testing rather than normal installation. Do not reload the seed script into an existing working database.

### Initial Sample Dataset

| Record type | Count |
| --- | ---: |
| User accounts | 50 |
| Clients | 15 |
| Freelancers | 35 |
| Categories | 10 |
| Jobs | 50 |
| Open jobs | 10 |
| Proposals | 112 |
| Contracts | 12 |
| Reviews | 12 |

These counts describe the initial seeded dataset, not the current state of a database after user activity. All sample marketplace data is fictional.

### Complex SQL Queries

The [query script](MiniUpwork_Nhom_Rum/sql/05_queries.sql) contains eleven queries using joins, subqueries, aggregations and other SQL features.

| ID | Query purpose |
| --- | --- |
| Q1 | Find open jobs matching skills and price range |
| Q2 | Identify freelancers satisfying all requirements of a sample job |
| Q3 | Count proposals and rank job interest within categories |
| Q4 | Calculate proposal acceptance rates among decided proposals |
| Q5 | Find jobs without proposals, including company and skill counts |
| Q6 | Summarize contract counts and status proportions by type |
| Q7 | Identify freelancers with above-average received ratings |
| Q8 | Identify overdue milestones requiring action |
| Q9 | Calculate unbilled hours by contract and UTC week |
| Q10 | Reconcile escrow and invoices with payment transactions, including compensation |
| Q11 | Calculate monthly freelancer earnings after compensating transactions |

## API Overview

The following are representative endpoints. The running application's `/docs` page contains the complete API definition and request models.

| Method | Endpoint | Purpose |
| --- | --- | --- |
| POST | `/register` | Register a marketplace account |
| POST | `/login` | Authenticate and create a session |
| GET | `/session` | Retrieve the current user session |
| POST | `/logout` | End the session |
| GET | `/me/profile` | Retrieve the current user's profiles |
| GET | `/jobs` | Search and filter open jobs |
| POST | `/me/jobs` | Create a job as a client |
| POST | `/jobs/{job_id}/proposals` | Submit a proposal |
| GET | `/me/jobs/{job_id}/proposals` | View proposals received for a client's job |
| POST | `/me/proposals/{proposal_id}/decision` | Make a recruitment decision |
| GET | `/contracts` | List the current user's contracts |
| GET | `/contracts/{contract_id}` | Retrieve contract details |
| POST | `/contracts/{contract_id}/milestones/{source_id}/{action}` | Perform a milestone action |
| POST | `/contracts/{contract_id}/time` | Record a time entry |
| POST | `/contracts/{contract_id}/invoices` | Generate a weekly invoice |
| POST | `/contracts/{contract_id}/payments/{payment_id}/result/{status}` | Record a simulated payment outcome |
| POST | `/contracts/{contract_id}/reviews` | Submit a contract review |

Most marketplace operations require an authenticated session and appropriate account roles or contract membership.

## Testing and Demonstration

Use a fresh or disposable copy of the seeded database to demonstrate recruitment and settlement workflows. Open the SQL scripts in pgAdmin Query Tool or another PostgreSQL client connected to the target database:

- `05_queries.sql`: execute the eleven analytical queries and inspect their results.
- `06_verify.sql`: check seed counts and rejection of invalid operations, including overlapping time entries, cross-contract payment sources, premature reviews and modification of recorded payments. The script rolls back its test transaction.
- `08_benchmark_fixture.sql`: populate a **separate fresh test database** with 10,000 jobs and 50,000 proposals in total. This script commits its added data; do not use it on the main demo database.

The original team README records previous integration testing, including authentication, duplicate proposal rejection, unauthorized contract access rejection, milestone releases, and hourly invoice payment. A new end-to-end run is recommended after installation or changes to the package.

## Project Phases

| Phase | Scope |
| --- | --- |
| 1 — Conceptual Design | Problem statement, business rules, ER/EER modeling |
| 2 — Logical Design and Normalization | Relational schema mapping, key definitions, functional dependencies, 3NF/BCNF analysis |
| 3 — Implementation and Queries | PostgreSQL DDL, DML, complex queries, triggers, views and verification scripts |
| 4 — Integration and Defense | FastAPI integration, web interface, demonstration and evaluation |

## Team Rum

| Member | Planned demonstration focus |
| --- | --- |
| Lý Nguyễn Thành Đạt | Job search, proposals, Q1–Q4 |
| Hồ Nguyên Sâm | Frontend–backend–database integration, shared keys, Q5–Q7 and rating summary |
| Trần Quang Huy | Contracts, milestones, invoices, simulated settlement and Q8–Q11 |

## Scope and Limitations

Mini-Upwork is designed for academic use and local demonstration. Payments are simulated in PostgreSQL; the application does not connect to a real payment gateway or transfer real money. Real banking, tax, messaging, identity verification and full dispute arbitration are outside the project scope. The local launcher and trusted-host configuration are intended for localhost, not public production deployment.

For troubleshooting, check the PostgreSQL service, connection credentials, database/role creation permissions, installed Python dependencies, and the location of `miniupwork/web/index.html`.

**Repository:** [Ly-Dat-NT/MiniUpWork](https://github.com/Ly-Dat-NT/MiniUpWork)
