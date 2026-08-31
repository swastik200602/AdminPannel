# Employee Management System

A full-featured **HR and payroll platform** built with **ASP.NET Core MVC on .NET 10**, **Dapper**, and **SQL Server stored procedures**. It combines a role-based web admin panel with a token-secured Web API designed for a companion self-service mobile/SPA client.

The system manages the complete employee lifecycle — onboarding, documents, attendance, leave, tasks, announcements, and a payroll engine that computes net salary from salary structures, taxes, bonuses, and loan/advance recovery.

> This repository is the server-side application: the MVC admin panel **and** the JWT Web API that a separate React / React Native client consumes.

---

## Table of contents

- [Highlights](#highlights)
- [Tech stack](#tech-stack)
- [Feature overview](#feature-overview)
- [Architecture at a glance](#architecture-at-a-glance)
- [Roles and access model](#roles-and-access-model)
- [Quick start](#quick-start)
- [Project structure](#project-structure)
- [Documentation](#documentation)
- [Design decisions and engineering notes](#design-decisions-and-engineering-notes)
- [Known limitations and roadmap](#known-limitations-and-roadmap)

---

## Highlights

- **Two front doors, one codebase.** A cookie-authenticated Razor MVC admin panel for HR/Admin/Manager staff, plus a stateless **JWT Bearer Web API** (27 endpoints) for a self-service employee client — both served by the same ASP.NET Core app using a dual authentication-scheme setup.
- **Stored-procedure data layer.** Every database interaction goes through SQL Server stored procedures called via a thin generic Dapper wrapper (`AppData`), keeping SQL out of C# and business rules close to the data.
- **A real payroll engine.** `Procs_GeneratePayroll` is a transaction-safe procedure that resolves the effective salary structure for a period, aggregates TDS / income tax / other taxes, applies salary-master and ad-hoc bonuses, recovers loan/advance instalments, and computes net pay — all atomically.
- **Defense-in-depth authorization.** Identity is always derived from the authenticated principal (cookie claims or the JWT `CustId` claim), never from the request body. A consistent *self-service vs. oversight* model gives Employees access to their own records, Managers to their team, and HR/Admin org-wide.
- **Guided onboarding workflow.** New hires move through a tracked, multi-step checklist (profile → documents → employment setup → salary structure → tax → user account → payroll-ready) before they become eligible for payroll.

---

## Tech stack

| Layer | Technology |
|---|---|
| Runtime | .NET 10 (`net10.0`) |
| Web framework | ASP.NET Core MVC (controllers + Razor views) |
| Data access | [Dapper](https://github.com/DapperLib/Dapper) 2.1.79 over `Microsoft.Data.SqlClient` |
| Database | Microsoft SQL Server (database `EmployeeManagementDB`) |
| Persistence pattern | Stored procedures for all reads and writes |
| Auth (web) | Cookie authentication (default scheme) |
| Auth (API) | JWT Bearer (`Microsoft.AspNetCore.Authentication.JwtBearer` 10.0.0, `System.IdentityModel.Tokens.Jwt` 8.22.0) |
| Authorization | Role claims + named authorization policies (RBAC) |
| UI theme | AdminLTE (Bootstrap-based admin template) |
| Client (separate repo) | React / React Native self-service app consuming the JWT API |

> `Microsoft.EntityFrameworkCore.SqlServer` is referenced in the project file, but the application deliberately uses **Dapper + stored procedures** for data access.

---

## Feature overview

### Master data (Admin)
Department, Designation, Office Branch, Role, Shift, Leave Type, and Holiday are all managed through consistent create/update/delete screens with AJAX-friendly endpoints. India State/City reference data drives cascading location dropdowns.

### Employee lifecycle (HR / Admin)
Create and edit employees with rich server-side validation (age ≥ 18, phone/emergency-contact format, contact uniqueness, manager scope), auto-generated employee codes, profile-image upload, and soft-delete. A dedicated **onboarding workspace** tracks completion across profile, documents, employment setup, salary, tax, and user-account steps, and reports whether an employee is *ready for payroll*.

### Document management
Upload, download, verify, and delete employee documents (PDF/JPG/PNG/DOC/DOCX, 10 MB cap). Files are stored on disk under `App_Data/EmployeeDocuments/{employeeId}/` with metadata persisted in the database.

### Operations (day-to-day HR)
Attendance marking and review, leave application / approval / cancellation, task assignment and status tracking, and company announcements — each scoped by role so Managers see only their team and Employees only themselves.

### Payroll
Salary structure revisions (salary master), tax configuration (TDS / income tax / other), bonuses, and salary advances/loans. Payroll is generated per employee per month by a stored procedure, with payment-status tracking, editable pre-payment records, salary slips, per-employee payroll history, and monthly summaries.

### User accounts
Provision login accounts linked to employees, assign roles, deactivate/reactivate accounts — restricted to Admin/HR, with an extra guard that only an Admin may create another Admin.

### Self-service Web API
A JWT-secured API surface lets an employee view and edit their own profile, apply for and cancel leave, mark and view attendance, view payslips, and update their own task status — plus oversight endpoints for Managers/HR/Admin to approve leave, mark attendance for others, assign tasks, and manage announcements. See the [API reference](docs/api-reference.md).

---

## Architecture at a glance

```
                    ┌───────────────────────────────────────────────┐
                    │              ASP.NET Core (.NET 10)             │
                    │                                                 │
  Browser  ─────►   │  MVC Controllers ──► Razor Views (AdminLTE)     │
  (cookie auth)     │        │                                        │
                    │        │        ┌─────────────────────────┐     │
                    │        └──────►  │  AppData (Dapper wrapper)│ ──┐ │
  React / RN app ─► │  API Controllers │  generic SelectModel<T> │   │ │
  (JWT bearer)      │        ▲         └─────────────────────────┘   │ │
                    │        │                                        │ │
                    │  TokenService (JWT issue/validate)              │ │
                    └─────────────────────────────────────────────── ┼─┘
                                                                      │
                                                          Stored procedures
                                                                      │
                                                          ┌───────────▼──────────┐
                                                          │  SQL Server           │
                                                          │  EmployeeManagementDB │
                                                          │  21 tables · ~52 SPs  │
                                                          └───────────────────────┘
```

Controllers stay thin: they validate input, enforce authorization/scoping, and delegate persistence to stored procedures through `AppData`. A shared `Mode` convention (`1 = Insert, 2 = Update, 3 = Delete`) drives the `Procs_InsertUpdateDelete*` family, and read procedures return typed result sets mapped directly onto response models. The full write-up lives in [docs/architecture.md](docs/architecture.md).

---

## Roles and access model

| Role | Web admin panel | Typical scope |
|---|---|---|
| **Admin** | Full access, including master data and Admin-account creation | Organization-wide |
| **HR** | Employee lifecycle, payroll, user accounts, announcements | Organization-wide |
| **Manager** | Team views for attendance, leave, tasks, payroll | Own direct reports |
| **Employee** | Own profile and records (mainly via the self-service API) | Self only |

Authorization is enforced with named policies (`AdminOnly`, `HrAccess`, `ManagerAccess`, `EmployeeAccess`, `UserManagement`) plus row-level scoping in code. The authenticated user's `EmployeeID` comes from cookie claims (web) or the JWT `CustId` claim (API) and is treated as the single source of truth for "who am I".

---

## Quick start

> Full instructions, prerequisites, and troubleshooting are in **[docs/setup.md](docs/setup.md)**.

**Prerequisites:** .NET 10 SDK, SQL Server (local instance), and the `EmployeeManagementDB` database provisioned with the required tables and stored procedures.

```bash
# 1. Point the app at your SQL Server (edit the connection string)
#    appsettings.json → ConnectionStrings:DefaultConnection

# 2. Restore and run
dotnet restore
dotnet run

# 3. Open the app
#    https://localhost:7182   (HTTPS)
#    http://localhost:5144    (HTTP)
```

The default connection string uses Windows integrated security against `localhost` / `EmployeeManagementDB`. Sign in from the account login screen, or call `POST /api/AuthAPI/Login` to obtain a JWT for the API.

---

## Project structure

```
AdminPannel/
├── Controllers/
│   ├── AccountController.cs          # Cookie login, change password, logout
│   ├── HomeController.cs             # Master data (department, designation, role, …)
│   ├── EmployeeController.cs         # Employee CRUD, onboarding, documents, self-edit
│   ├── OperationsController.cs       # Attendance, leave, tasks, announcements
│   ├── PayrollController.cs          # Payroll, salary/tax master, bonus, advances
│   ├── UserController.cs             # User-account provisioning
│   ├── AuthAPIController.cs          # API: JWT login + smoke test
│   └── EmployeeAPIController.cs      # API: self-service + oversight (25 endpoints)
├── Logic/
│   ├── AppData.cs                    # Generic Dapper stored-procedure wrapper
│   ├── ConnectHelper.cs             # Connection-string holder
│   ├── TokenService.cs              # JWT creation
│   └── AuthorizationPolicies.cs     # Policy name constants
├── Models/
│   ├── AdminModel.cs                 # Domain models + request/response DTOs
│   └── ApiModels.cs                  # API-specific request/response DTOs
├── Views/                            # Razor views (Account, Home, Employee,
│                                     #   Operations, Payroll, User, Shared)
├── wwwroot/                          # AdminLTE assets, css, js, uploads
├── App_Data/EmployeeDocuments/       # Uploaded employee documents
├── Program.cs                        # Bootstrap: DI, dual auth, policies, pipeline
├── appsettings.json                  # Connection string + JWT settings
└── docs/                             # Project documentation (this folder)
```

---

## Documentation

| Document | What's inside |
|---|---|
| [docs/architecture.md](docs/architecture.md) | Layered design, request lifecycle, data-access pattern, auth model, design trade-offs |
| [docs/setup.md](docs/setup.md) | Prerequisites, configuration, running locally, and troubleshooting |
| [docs/api-reference.md](docs/api-reference.md) | Every JWT API endpoint: routes, auth, request/response shapes |
| [docs/database.md](docs/database.md) | Schema reference: tables, columns, keys, constraints, and stored procedures |

---

## Design decisions and engineering notes

- **Why stored procedures?** Business logic that touches multiple tables (payroll generation, cascading recovery of advances) is expressed atomically in T-SQL with explicit transactions, while C# stays focused on validation, authorization, and shaping responses.
- **Why a generic Dapper wrapper?** `AppData.SelectModel<T>` / `SelectModelList<T>` remove repetitive ADO.NET boilerplate and give every call site a consistent, strongly-typed way to invoke a procedure and map its result set.
- **Consistent response envelope.** Write procedures return a `StatusCode` / `Message` pair (mapped to `ResultSet`), and the API wraps payloads in `{ statusCode, message, data }`, so clients get a predictable contract across the whole surface.
- **Security by construction.** The self-service DTOs intentionally omit fields a caller shouldn't control (e.g. `EmployeeID`, `Status`, `ApprovedBy`), and the server stamps those from the token — a caller cannot file leave for someone else, self-approve, or forge a day count.

---

## Known limitations and roadmap

This project is under active development. A few things are intentionally simplified for the current development phase and are documented honestly here:

- **Password handling is development-grade.** `Procs_LoginUser` currently compares the supplied password against the stored value as plain text, and account creation issues a fixed temporary password. Production hardening (salted hashing via the existing `PasswordSalt` column, real temporary-password generation) is a planned next step.
- **Configuration secrets.** The JWT signing key lives in `appsettings.json` for local development; it should move to user secrets / environment variables / a secret store before deployment.
- **Some read paths enrich data in memory.** A few list views fetch broadly and then filter/scope in C#; these are candidates for pushing scoping into the stored procedures as data volume grows.
- **Roadmap.** Password hashing, a dedicated team/roster API endpoint for the mobile client, and server-side pagination for large lists.

---

*Built as a full-stack learning and portfolio project demonstrating layered ASP.NET Core architecture, SQL Server stored-procedure design, and secure multi-client authentication.*
