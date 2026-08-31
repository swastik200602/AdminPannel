# Architecture

This document explains how the Employee Management System is put together: its layers, the request lifecycle, the data-access pattern, and the authentication and authorization model. It is written for a reviewer who wants to understand the engineering decisions behind the code.

---

## Guiding principles

The application is built around a few consistent ideas:

1. **Thin controllers, rich procedures.** Controllers validate input, enforce authorization, and shape responses. Multi-table business logic lives in SQL Server stored procedures where it can run inside a transaction.
2. **One data-access path.** Every database call — read or write — goes through a single generic Dapper wrapper (`AppData`) that invokes a stored procedure and maps the result onto a typed model.
3. **Identity comes from the token, never the body.** The current user's `EmployeeID` is taken from the authenticated principal. Request DTOs deliberately exclude fields a caller should not control.
4. **A predictable contract.** Write procedures return a `StatusCode` + `Message`; the API wraps every payload in `{ statusCode, message, data }`. Clients can rely on the same shape everywhere.

---

## Component overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                        ASP.NET Core host (.NET 10)                     │
│                                                                        │
│   Presentation                Application               Data access    │
│   ─────────────               ───────────               ───────────    │
│                                                                        │
│   Razor Views  ◄────  MVC Controllers ─┐                               │
│   (AdminLTE)          (cookie auth)     │                              │
│                                         ├─►  AppData  ──►  Stored       │
│   JSON clients ◄────  API Controllers ──┘   (Dapper)      procedures   │
│                       (JWT bearer)                             │        │
│                            ▲                                   │        │
│                            │                                   ▼        │
│                       TokenService                     ┌──────────────┐ │
│                       (JWT issue)                      │  SQL Server  │ │
│                                                        │  DB (SPs)    │ │
│   Cross-cutting: Authentication · Authorization ·      └──────────────┘ │
│   Data Protection · Console logging · File storage                     │
└──────────────────────────────────────────────────────────────────────┘
```

The same process serves two audiences. Browsers hit MVC controllers and receive server-rendered Razor pages secured by an authentication cookie. Programmatic clients (a React / React Native self-service app) hit attribute-routed API controllers and authenticate with a JWT bearer token. Both converge on the same `AppData` layer and the same database.

---

## Layers

### Presentation

**MVC controllers** (`AccountController`, `HomeController`, `EmployeeController`, `OperationsController`, `PayrollController`, `UserController`) return Razor views built on the AdminLTE theme. Several actions double as AJAX endpoints: when a request carries the `X-Requested-With: XMLHttpRequest` header, the controller returns JSON instead of a view, which the front-end uses for in-place list refreshes and modal forms.

**API controllers** (`AuthAPIController`, `EmployeeAPIController`) are attribute-routed under `api/[controller]` and return JSON. They are decorated with `[Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]` so they validate bearer tokens rather than cookies.

### Application

Controllers hold the request-handling logic: model validation (data annotations plus explicit checks), authorization and row-level scoping, mapping between request DTOs and stored-procedure parameters, and translating procedure results into views or JSON responses. Cross-cutting helpers such as `TokenService` (JWT creation) live in `Logic/`.

### Data access

`Logic/AppData.cs` is the single gateway to the database. It wraps Dapper and exposes a small, consistent set of generic helpers so call sites never write raw ADO.NET:

| Method | Purpose |
|---|---|
| `SelectModel<T>(proc, params)` | Execute a procedure and map the first row to `T` |
| `SelectModelList<T>(proc, params)` | Execute a procedure and map all rows to `List<T>` |
| `SelectModelListAsync<T>(...)` | Async variant returning `Task<List<T>>` |
| `ExecuteAsync` / `Executesync` | Fire a procedure that returns no result set |
| `QueryAsync` / `QueryList<T>` | Query helpers for procedures and (rarely) inline SQL |
| `QueryMultiple<T1,T2>` | Read procedures returning multiple result sets |

Most of these methods open a connection using the string held in `ConnectHelper.Connect`, call the procedure with `CommandType.StoredProcedure`, and let Dapper map columns to properties by name. A couple of helpers (e.g. `QueryList<T>`) instead run parameterized inline SQL, kept for a few legacy tables that don't yet have a dedicated list procedure.

### Database

SQL Server hosts `EmployeeManagementDB`: 21 user tables and roughly 52 stored procedures. Procedures are the only interface the application uses; there are no ad-hoc table queries from C# apart from a couple of narrow read helpers. See [database.md](database.md) for the full schema.

---

## Request lifecycle

### Web (cookie) request

```
Browser → UseAuthentication (cookie) → UseAuthorization (policy/role)
       → MVC controller action
           → validate ModelState + custom rules
           → derive EmployeeID from cookie claims, apply scope
           → AppData.SelectModel*/Execute → stored procedure → SQL Server
           → map ResultSet / rows → Razor View (or JSON for AJAX)
       → response (HTML or JSON)
```

A signed-in user carries a rich claims set in the cookie (name identifier, role, `UserID`, `EmployeeID`, `RoleID`, `RoleName`, employee code, name, email). Controllers read `EmployeeID` from these claims to scope data to the current user.

### API (JWT) request

```
Client → POST /api/AuthAPI/Login (AllowAnonymous)
           → Procs_LoginUser validates credentials
           → TokenService.CreateToken(userId, custId=EmployeeID, roles)
           → returns { statusCode, message, data:{ token, … } }

Client → GET/POST/PUT /api/EmployeeAPI/... with  Authorization: Bearer <token>
           → JWT scheme validates issuer/audience/lifetime/signature
           → controller reads CustId claim → current EmployeeID
           → authorization + scope check
           → AppData → stored procedure → SQL Server
           → { statusCode, message, data }
```

The JWT carries the employee identity in a `CustId` claim (equal to `EmployeeID`) and one role claim per role. Because the API controller resolves identity from `CustId`, self-service endpoints never trust an `EmployeeID` supplied in the body.

---

## Data-access conventions

### The `Mode` convention

Create, update, and delete for a given entity are consolidated into a single `Procs_InsertUpdateDelete<Entity>` procedure. Controllers select the operation with a `Mode` parameter:

| Mode | Operation |
|---|---|
| `1` | Insert |
| `2` | Update |
| `3` | Delete (typically a soft delete via `IsActive`) |

For example, `EmployeeController.Create` calls `Procs_InsertUpdateDeleteEmployee` with `Mode = 1`, `Edit` with `Mode = 2`, and `Delete` with `Mode = 3`, passing the same parameter object shape each time.

### Read procedures

Read procedures follow a `Procs_Get<Entity>` naming pattern and generally accept nullable filters (e.g. `EmployeeID`, `IsActive`, `Search`) so one procedure serves both "get one" and "get many / search" scenarios. Results map onto `*Response` / `*Model` types.

### The result envelope

Write procedures return a single row with `StatusCode` and `Message`, mapped onto the `ResultSet` model (`Id`, `StatusCode`, `Message`). Controllers branch on `StatusCode == 200` to decide success, and surface `Message` to the user. The API layer re-wraps this into `{ statusCode, message, data }` for a uniform client contract.

---

## Authentication

Authentication uses **two schemes registered side by side**, configured in `Program.cs`:

- **Cookie authentication is the default scheme**, so the entire MVC site behaves exactly as a traditional server-rendered app. Login path `/Account/Login`, access-denied path `/Account/AccessDenied`, 30-minute sliding expiration, `HttpOnly` cookie, and `SecurePolicy = SameAsRequest`.
- **JWT Bearer is a second, opt-in scheme.** API controllers request it explicitly via `[Authorize(AuthenticationSchemes = "Bearer")]`. Incoming tokens are validated for issuer, audience, lifetime, and signing key against the same values `TokenService` uses to sign them, with `RoleClaimType = ClaimTypes.Role` so role-based checks work identically to the cookie world.

`Logic/TokenService.cs` issues tokens containing `sub`, `UserId`, `CustId` (= `EmployeeID`), `jti`, and a role claim per role, signed with HMAC-SHA256. Issuer, audience, key, and expiry are read from the `Jwt` configuration section.

This split means the web and API layers can evolve their auth independently while sharing one identity model: a role claim carries the role **name** ("Admin", "HR", …) in both worlds, so the same policies and `[Authorize(Roles = …)]` checks apply everywhere.

---

## Authorization

Authorization combines coarse-grained policies with fine-grained, in-code scoping.

### Named policies

Registered in `Program.cs` and referenced through the `AuthorizationPolicies` constants:

| Policy | Roles allowed |
|---|---|
| `AdminOnly` | Admin |
| `HrAccess` | Admin, HR |
| `ManagerAccess` | Admin, Manager |
| `EmployeeAccess` | Admin, Employee |
| `UserManagement` | Admin, HR |

Master-data management (`HomeController`) is `AdminOnly`; employee lifecycle and payroll operations are gated by `HrAccess`; user provisioning is `UserManagement`.

### Row-level scoping

On top of policies, controllers narrow data to what the caller may see:

- **HR / Admin** — organization-wide.
- **Manager** — restricted to direct reports, determined by matching each record's employee to `ManagerID == currentEmployeeId` (helpers like `IsTeamMember` / `IsManagerTeamMember`).
- **Employee** — restricted to their own `EmployeeID`.

The current `EmployeeID` is read from the `EmployeeID` cookie claim (web) or the `CustId` JWT claim (API). Because scoping is applied server-side after identity is established, a client cannot widen its own scope by manipulating query parameters or request bodies.

### Self-service vs. oversight (API)

`EmployeeAPIController` cleanly separates two kinds of endpoint:

- **Self-service** (`me/...`): act on the caller's own records. Identity is the `CustId` claim; the body carries only the few fields the caller legitimately controls.
- **Oversight** (`leaves`, `attendance`, `tasks`, `announcements`, `payroll`): act on others. The server validates the caller may manage the target (HR/Admin over anyone; Manager over their team) before proceeding, and stamps server-controlled fields (`ApprovedBy`, `AssignedBy`, `CreatedBy`, `Status`) from the token.

---

## Domain model and DTOs

`Models/AdminModel.cs` holds the domain models and the request/response DTO pairs for every entity (employee, attendance, leave, task, announcement, payroll, salary master, tax master, bonus, salary advance, plus the master-data lookups). Response types often include computed conveniences such as `FullName` and `OnboardingStatus`.

`Models/ApiModels.cs` holds DTOs specific to the API contract — notably the deliberately minimal self-service request bodies (`LeaveApplyRequest`, `AttendanceMarkRequest`, `TaskStatusUpdateRequest`) and the oversight request bodies (`LeaveDecisionRequest`, `AttendanceForEmployeeRequest`, `TaskCreateRequest`, `AnnouncementRequest`), along with `ApiLoginRequest` and `LoginApiResponse`. Keeping the public API contract separate from the database row-mapping types lets each evolve without breaking the other.

---

## Application bootstrap (`Program.cs`)

The startup sequence:

1. Reset logging providers and add console logging (portable across environments where the Windows EventLog is not writable).
2. Configure **Data Protection** to persist keys to a `.keys` folder under the content root, so cookie/antiforgery keys survive restarts and don't depend on a user's DPAPI key ring.
3. Register MVC (`AddControllersWithViews`) and DI services: `AppData` and `ITokenService` as scoped services.
4. Read the connection string into `ConnectHelper.Connect`.
5. Register the dual authentication schemes (cookie default + JWT bearer) and the authorization policies.
6. Build the pipeline: exception handler + HSTS (non-development) → HTTPS redirection → static files → routing → **authentication → authorization** → static assets → attribute-routed controllers → default MVC route `{controller=Account}/{action=Index}/{id?}`.

The default landing controller is `Account`, so an unauthenticated visitor is guided to log in first.

---

## Cross-cutting concerns

- **Logging.** Console logging is configured centrally; controllers log warnings/errors around database and file operations.
- **File storage.** Uploaded employee documents are written to `App_Data/EmployeeDocuments/{employeeId}/` with GUID file names; profile images go to `wwwroot/uploads/employees/`. Metadata (path, type, size, verification flag) is stored in `T_EmployeeDocument`.
- **Data protection keys.** Persisted to `.keys` (git-ignored) for stable cookie/antiforgery protection.
- **Anti-forgery.** State-changing MVC form posts are protected with `[ValidateAntiForgeryToken]`.

---

## Design trade-offs (honest notes)

No architecture is free of compromise; these are the ones worth calling out:

- **Dependency injection is used inconsistently.** API controllers receive `AppData` via constructor injection (it is registered as a scoped service), while MVC controllers instantiate `new AppData()` directly. Standardizing on injection everywhere would improve testability.
- **Exception rethrows lose stack context.** The data layer's `catch` blocks use `throw ex;` rather than `throw;`, which resets the stack trace. This is a small, well-known refactor.
- **Some scoping happens in memory.** A few list endpoints fetch broadly and then filter to a team/self in C#. This is simple and correct, but pushing the scope into the stored procedure would reduce data movement at scale.
- **Development-grade credentials.** Password comparison is currently plain-text in `Procs_LoginUser`, and the JWT signing key sits in `appsettings.json`. Both are flagged for hardening (hashing with the existing `PasswordSalt` column; moving secrets to a secret store) before any production use.

These are deliberately documented rather than hidden — they reflect a project that is honest about its current development phase and clear about the path to production.
