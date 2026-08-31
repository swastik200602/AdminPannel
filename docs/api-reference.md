# Web API reference

The Employee Management System exposes a **JWT-secured REST API** intended for a separate self-service client (a React / React Native employee app). It lives alongside the MVC admin panel in the same ASP.NET Core host.

There are **27 endpoints** across two controllers:

- **`AuthAPIController`** (`/api/AuthAPI`) — 2 endpoints: login and a token smoke test.
- **`EmployeeAPIController`** (`/api/EmployeeAPI`) — 25 endpoints: self-service (`me/…`) plus manager/HR/admin oversight.

---

## Table of contents

- [Conventions](#conventions)
  - [Base URL](#base-url)
  - [Authentication](#authentication)
  - [Response envelope](#response-envelope)
  - [Status codes](#status-codes)
  - [Identity and scope](#identity-and-scope)
- [Authentication API](#authentication-api)
- [Self-service endpoints (`me/…`)](#self-service-endpoints)
  - [Profile](#profile)
  - [Leave](#leave-self-service)
  - [Attendance](#attendance-self-service)
  - [Payslips](#payslips-self-service)
  - [Tasks](#tasks-self-service)
- [Oversight endpoints (manager / HR / admin)](#oversight-endpoints)
  - [Leave](#leave-oversight)
  - [Attendance](#attendance-oversight)
  - [Tasks](#tasks-oversight)
  - [Announcements](#announcements)
  - [Payroll](#payroll-oversight)
- [Request body reference](#request-body-reference)
- [Endpoint summary](#endpoint-summary)

---

## Conventions

### Base URL

In local development the API is served from the same host as the web app:

```
https://localhost:7182
```

All API routes are prefixed with `/api`. Endpoint paths below are written relative to the base URL (for example `POST /api/EmployeeAPI/me/leaves`).

### Authentication

Every endpoint **except `POST /api/AuthAPI/Login`** requires a JWT bearer token:

```
Authorization: Bearer <token>
```

Obtain a token from the login endpoint. The token carries the caller's user id, employee id (`CustId` claim), and role(s). API controllers explicitly opt into the JWT scheme (`[Authorize(AuthenticationSchemes = "Bearer")]`), so a session cookie is **not** accepted here.

Tokens are validated for issuer, audience, lifetime, and signature. An invalid, expired, or missing token yields **401 Unauthorized**.

### Response envelope

Every response uses a consistent JSON envelope:

```jsonc
{
  "statusCode": 200,       // mirrors the HTTP status
  "message": "OK",         // human-readable outcome
  "data": { }              // present on reads and some writes; omitted on pure writes
}
```

Additional fields appear in specific cases:

- **Validation errors** add an `errors` object keyed by field name:
  ```jsonc
  { "statusCode": 400, "message": "Validation failed.", "errors": { "Reason": "Reason is required." } }
  ```
- **Unhandled server errors** add a `detail` string:
  ```jsonc
  { "statusCode": 500, "message": "Server error", "detail": "…exception message…" }
  ```

### Status codes

| Code | Meaning in this API |
|---|---|
| `200 OK` | Read succeeded, or a write completed (update / cancel / decision / toggle). |
| `201 Created` | A new resource was created (leave applied, attendance marked, task assigned, announcement created). |
| `400 Bad Request` | Missing body, failed validation, or an invalid date range / status / decision. |
| `401 Unauthorized` | Missing, malformed, or expired token. |
| `403 Forbidden` | Token doesn't identify an employee, or the caller's role/scope doesn't permit the action. |
| `404 Not Found` | The target record doesn't exist or isn't visible to the caller. |
| `409 Conflict` | Surfaced from a stored procedure (e.g. duplicate) via its `StatusCode`. |
| `500 Internal Server Error` | Unhandled exception; `detail` carries the message. |

> Because controllers surface the stored procedure's own `StatusCode`/`Message`, some responses (e.g. `404`, `409`) originate from the database layer rather than an explicit branch in C#.

### Identity and scope

The caller's `EmployeeID` is always taken from the JWT **`CustId`** claim — never from a route or request body. This underpins two endpoint families:

- **Self-service (`me/…`)** — always act on the caller's own records. Any authenticated employee (including HR/Manager/Admin, who are also employees) may use these.
- **Oversight** — act on other people's records. Scope is enforced in code:
  - **HR / Admin** → organization-wide.
  - **Manager** → direct reports only (an employee whose `ManagerID` equals the caller's `CustId`).
  - **Employee** → not permitted (receives `403`, with a hint to use the `me/…` equivalent).

Server-controlled fields (`Status`, `ApprovedBy`, `AssignedBy`, `CreatedBy`, `NumberOfDays`) are always stamped from the token or computed server-side, so a caller cannot file leave for someone else, self-approve, or forge a day count.

---

## Authentication API

### `POST /api/AuthAPI/Login`

Authenticates a user and returns a JWT. **Anonymous** (the only endpoint that doesn't need a token).

**Request body** ([`ApiLoginRequest`](#apiloginrequest)):

```jsonc
{
  "userName": "jsmith",
  "password": "secret"
}
```

Credentials are checked by `Procs_LoginUser`. In the current development build this is a **plain-text** comparison against the stored value, and only active accounts (`IsActive = 1`) can log in.

**`200` response** — `data` is a [`LoginApiResponse`](#loginapiresponse):

```jsonc
{
  "statusCode": 200,
  "message": "Login Success..!",
  "data": {
    "userID": 12,
    "employeeID": 34,
    "roleID": 2,
    "roleName": "HR",
    "userName": "jsmith",
    "email": "jsmith@example.com",
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9…",
    "tokenType": "Bearer",
    "expiresIn": 3600
  }
}
```

**Failure** — invalid credentials or inactive account returns the procedure's rejection (e.g. `401` with a message). A missing username/password returns `400`.

> Note: `expiresIn` is reported as `3600`, while the token's actual lifetime is governed by `Jwt:ExpiryMinutes` in configuration.

### `GET /api/AuthAPI/private`

A protected smoke-test endpoint. Requires a valid bearer token and simply echoes the caller's identity, which is handy for confirming a token is accepted end-to-end.

**`200` response:**

```jsonc
{ "statusCode": 200, "message": "You are authenticated.", "data": { "userId": "12", "role": "HR" } }
```

---

## Self-service endpoints

All paths in this section are under `/api/EmployeeAPI/me` and act on **the caller's own** records. A token that doesn't resolve to an employee (`CustId`) returns `403` on every one of them.

### Profile

#### `GET /api/EmployeeAPI/me`

Returns the caller's own employee profile (via `Procs_GetEmployees` scoped to `CustId`, active records only).

- **`200`** — `data` is the employee record.
- **`404`** — the caller's employee record was not found.

#### `PUT /api/EmployeeAPI/me`

Updates only the caller's own self-service fields. The server loads the current row, overwrites just the eight allowed fields, and re-saves with `Mode = 2`; everything else (`EmployeeCode`, `RoleID`, `BasicSalary`, `DepartmentID`, …) is preserved and cannot be changed here.

**Request body** ([`EmployeeSelfServiceRequest`](#employeeselfservicerequest)):

```jsonc
{
  "email": "new.email@example.com",
  "phoneNumber": "+919812345678",
  "emergencyContact": "+919812300000",
  "address": "12 MG Road",
  "city": "Pune",
  "state": "Maharashtra",
  "country": "India",
  "postalCode": "411001"
}
```

- **`200`** — `data` is the updated profile.
- **`400`** — validation failed (`errors` map). All fields except `emergencyContact` are required, and `email` must be valid.
- **`404`** — the caller's employee record was not found.

### Leave (self-service)

#### `GET /api/EmployeeAPI/me/leaves`

Lists the caller's own leave requests.

**Query parameters:** `status` (string, optional), `fromDate`, `toDate` (dates, optional).

- **`200`** — `data` is an array of leave requests.
- **`400`** — `fromDate` is later than `toDate`.

#### `GET /api/EmployeeAPI/me/leave-types`

Returns the active leave types, for populating an "apply for leave" dropdown. Read-only reference data.

- **`200`** — `data` is an array of leave types.

#### `POST /api/EmployeeAPI/me/leaves`

Files a new leave request for the caller. The server sets `EmployeeID` (from the token), `Status = "Pending"`, `ApprovedBy = null`, and computes `NumberOfDays` (inclusive day count) — none of these can be supplied by the client.

**Request body** ([`LeaveApplyRequest`](#leaveapplyrequest)):

```jsonc
{
  "leaveTypeID": 3,
  "fromDate": "2026-09-10",
  "toDate": "2026-09-12",
  "reason": "Family function",
  "remarks": null
}
```

- **`201`** — leave request submitted.
- **`400`** — missing leave type, `fromDate` after `toDate`, or missing reason.

#### `POST /api/EmployeeAPI/me/leaves/{id}/cancel`

Cancels one of the caller's own **still-pending** leave requests. The row is fetched scoped to the caller and re-checked for ownership and pending status before the update (`Status = "Cancelled"`, `Mode = 2`).

- **`200`** — leave request cancelled.
- **`400`** — the request is not pending (already approved/rejected/cancelled).
- **`404`** — no such request belonging to the caller.

### Attendance (self-service)

#### `GET /api/EmployeeAPI/me/attendance`

Lists the caller's own attendance rows.

**Query parameters:** `fromDate`, `toDate` (dates, optional), `status` (string, optional).

- **`200`** — `data` is an array of attendance rows.
- **`400`** — `fromDate` is later than `toDate`.

#### `POST /api/EmployeeAPI/me/attendance`

Marks attendance for the caller (`Mode = 1`). `EmployeeID` comes from the token.

**Request body** ([`AttendanceMarkRequest`](#attendancemarkrequest)):

```jsonc
{
  "attendanceDate": "2026-08-31",
  "checkInTime": "09:05:00",
  "checkOutTime": "18:10:00",
  "workingHours": 8.5,
  "overtimeHours": 0,
  "status": "Present",
  "remarks": null,
  "shiftID": 1
}
```

- **`201`** — attendance marked.
- **`400`** — missing date, or `status` not one of `Present`, `Absent`, `Leave`, `Half Day`, `Work From Home`.

### Payslips (self-service)

Read-only. The API never generates or edits payroll (that stays in the admin panel).

#### `GET /api/EmployeeAPI/me/payslips`

The caller's own payroll history.

**Query parameters:** `fromMonth`, `toMonth` (byte 1–12), `fromYear`, `toYear` (short), `paymentStatus` (string) — all optional.

- **`200`** — `data` is an array of payroll rows.

#### `GET /api/EmployeeAPI/me/payslips/{id}`

One salary slip by id, scoped to the caller. Both `PayrollID` and the caller's `EmployeeID` are passed to `Procs_GetSalarySlip`, so a slip belonging to someone else returns nothing.

- **`200`** — `data` is the salary slip.
- **`404`** — no such payslip belonging to the caller.

### Tasks (self-service)

#### `GET /api/EmployeeAPI/me/tasks`

Lists the tasks assigned to the caller.

**Query parameters:** `status`, `priority` (strings, optional), `fromDate`, `toDate` (dates, optional).

- **`200`** — `data` is an array of tasks.
- **`400`** — `fromDate` is later than `toDate`.

#### `PUT /api/EmployeeAPI/me/tasks/{id}/status`

Moves one of the caller's own tasks through its status lifecycle. The task is fetched scoped to the caller, ownership is re-asserted, and the full row is re-sent with only `Status` changed (and `CompletedDate` stamped when the status becomes `Completed`).

**Request body** ([`TaskStatusUpdateRequest`](#taskstatusupdaterequest)):

```jsonc
{ "status": "In Progress" }
```

- **`200`** — task status updated.
- **`400`** — `status` not one of `Pending`, `In Progress`, `Completed`, `Cancelled`.
- **`404`** — no such task belonging to the caller.

---

## Oversight endpoints

These act on **other people's** records. Employees receive `403` (with a pointer to the `me/…` equivalent). Managers are limited to their direct reports; HR/Admin are organization-wide.

### Leave (oversight)

#### `GET /api/EmployeeAPI/leaves`

Lists leave requests the caller may oversee. HR/Admin may filter by `employeeId`; a Manager always sees only their team (filtered after the fetch).

**Query parameters:** `employeeId` (int, HR/Admin only), `status`, `fromDate`, `toDate`.

- **`200`** — `data` is an array of leave requests.
- **`400`** — `fromDate` after `toDate`.
- **`403`** — caller is a plain Employee (use `GET me/leaves`).

#### `POST /api/EmployeeAPI/leaves/{id}/decision`

Approves or rejects one pending leave request. Guards in order: caller is Manager/HR/Admin → request exists → Manager may only decide for their own team → request must still be pending → decision must be exactly `Approved` or `Rejected`. On success the server stamps `ApprovedBy = caller` and `ApprovedDate = now`.

**Request body** ([`LeaveDecisionRequest`](#leavedecisionrequest)):

```jsonc
{ "decision": "Approved" }
```

- **`200`** — decision recorded.
- **`400`** — invalid decision, or the request is not pending.
- **`403`** — not a manager/HR/admin, or a Manager acting outside their team.
- **`404`** — no such leave request.

### Attendance (oversight)

#### `GET /api/EmployeeAPI/attendance`

Lists attendance for the people the caller oversees. HR/Admin may filter by `employeeId`; a Manager sees only their team.

**Query parameters:** `employeeId` (HR/Admin only), `fromDate`, `toDate`, `status`.

- **`200`** — `data` is an array of attendance rows.
- **`400`** — `fromDate` after `toDate`.
- **`403`** — caller is a plain Employee (use `GET me/attendance`).

#### `POST /api/EmployeeAPI/attendance`

Marks attendance for **another** employee (`Mode = 1`). The body carries the target `EmployeeID`, validated with `CanManageEmployee` — a Manager may only mark their own team; HR/Admin anyone.

**Request body** ([`AttendanceForEmployeeRequest`](#attendanceforemployeerequest)):

```jsonc
{
  "employeeID": 34,
  "attendanceDate": "2026-08-31",
  "status": "Present",
  "checkInTime": "09:00:00",
  "checkOutTime": "18:00:00",
  "workingHours": 8,
  "overtimeHours": 0,
  "remarks": null,
  "shiftID": 1
}
```

- **`201`** — attendance marked.
- **`400`** — missing `employeeID`, missing date, or invalid status.
- **`403`** — not a manager/HR/admin, or a Manager targeting someone outside their team.

### Tasks (oversight)

#### `GET /api/EmployeeAPI/tasks`

Lists tasks the caller oversees. HR/Admin see all (optional `employeeId` filter); a Manager sees tasks they assigned, narrowed to their current team.

**Query parameters:** `employeeId` (HR/Admin only), `status`, `priority`, `fromDate`, `toDate`.

- **`200`** — `data` is an array of tasks.
- **`400`** — `fromDate` after `toDate`.
- **`403`** — caller is a plain Employee (use `GET me/tasks`).

#### `POST /api/EmployeeAPI/tasks`

Assigns a new task. The assignee (`EmployeeID`) is validated against the caller's scope. The server forces `AssignedBy = caller` and `Status = "Pending"`; a blank priority defaults to `Medium`.

**Request body** ([`TaskCreateRequest`](#taskcreaterequest)):

```jsonc
{
  "employeeID": 34,
  "taskTitle": "Prepare Q3 report",
  "taskDescription": "Compile department numbers",
  "priority": "High",
  "startDate": "2026-09-01",
  "dueDate": "2026-09-05"
}
```

- **`201`** — task assigned.
- **`400`** — missing `employeeID`, missing title, or `dueDate` before `startDate`.
- **`403`** — not a manager/HR/admin, or a Manager assigning outside their team.

#### `PUT /api/EmployeeAPI/tasks/{id}/status`

Updates the status of a team member's task. HR/Admin over any task; a Manager only over their team's. Full-row rewrite, same fetch-then-resend pattern as the self-service variant.

**Request body** ([`TaskStatusUpdateRequest`](#taskstatusupdaterequest)):

```jsonc
{ "status": "Completed" }
```

- **`200`** — task status updated.
- **`400`** — invalid status value.
- **`403`** — not a manager/HR/admin, or a Manager acting outside their team.
- **`404`** — no such task.

### Announcements

Viewing is open to any authenticated user; authoring (create / edit / toggle) is **HR/Admin only**.

#### `GET /api/EmployeeAPI/announcements`

Lists announcements. Defaults to active only.

**Query parameters:** `active` (bool, default `true`; pass `false` for inactive), `search` (string, optional).

- **`200`** — `data` is an array of announcements.

#### `POST /api/EmployeeAPI/announcements`

Creates an announcement (HR/Admin). `CreatedBy` is stamped from the token; `PublishDate` defaults to today; `ExpiryDate` (if given) must not precede `PublishDate`.

**Request body** ([`AnnouncementRequest`](#announcementrequest)):

```jsonc
{
  "title": "Office closed on Friday",
  "description": "Regional holiday.",
  "publishDate": "2026-09-01",
  "expiryDate": "2026-09-05",
  "isActive": true
}
```

- **`201`** — announcement created.
- **`400`** — missing title, or expiry before publish date.
- **`403`** — caller is not HR/Admin.

#### `PUT /api/EmployeeAPI/announcements/{id}`

Edits an announcement (HR/Admin). Full-row update (`Mode = 2`); `{id}` identifies the row. `CreatedBy` is re-stamped to the caller (doubling as "last modified by").

**Request body:** [`AnnouncementRequest`](#announcementrequest) (as above).

- **`200`** — announcement updated.
- **`400`** — missing title, or expiry before publish date.
- **`403`** — caller is not HR/Admin.

#### `POST /api/EmployeeAPI/announcements/{id}/toggle`

Activates or deactivates an announcement (HR/Admin). No value is taken from the client: the current row is fetched, its `IsActive` flipped, and every field re-sent. Deactivating is the system's stand-in for deletion.

- **`200`** — status changed.
- **`403`** — caller is not HR/Admin.
- **`404`** — no such announcement.

### Payroll (oversight)

Read-only. Generating, editing, and all salary/tax/bonus/advance configuration stay in the admin panel.

#### `GET /api/EmployeeAPI/payroll`

Lists payroll rows the caller may oversee. HR/Admin may filter by `employeeId`; a Manager sees only their current team.

**Query parameters:** `employeeId` (HR/Admin only), `month` (byte), `year` (short), `paymentStatus` (string).

- **`200`** — `data` is an array of payroll rows.
- **`400` / `404`** — surfaced from the procedure for a bad month/year or unknown employee.
- **`403`** — caller is a plain Employee (use `GET me/payslips`).

#### `GET /api/EmployeeAPI/payroll/{id}`

One salary slip by `PayrollID`, for oversight. HR/Admin may view any; a Manager only their team's.

- **`200`** — `data` is the salary slip.
- **`403`** — caller is a plain Employee, or a Manager viewing outside their team.
- **`404`** — no such payslip.

---

## Request body reference

JSON field names are shown in camelCase (the wire format); the C# properties are PascalCase.

### `ApiLoginRequest`

| Field | Type | Notes |
|---|---|---|
| `userName` | string | Login username (not email). |
| `password` | string | Compared by `Procs_LoginUser`. |

### `LoginApiResponse`

| Field | Type | Notes |
|---|---|---|
| `userID` | int | User-account id. |
| `employeeID` | int | Linked employee id (becomes the `CustId` claim). |
| `roleID` | int | Role id (`0` = Admin). |
| `roleName` | string | Role name used for authorization. |
| `userName` | string | Echoed username. |
| `email` | string | User email. |
| `token` | string | Signed JWT. |
| `tokenType` | string | Always `"Bearer"`. |
| `expiresIn` | int | Reported as `3600` (actual lifetime from `Jwt:ExpiryMinutes`). |

### `EmployeeSelfServiceRequest`

The eight fields a caller may change on their own profile. All required **except** `emergencyContact`; `email` must be a valid address.

| Field | Type |
|---|---|
| `email` | string |
| `phoneNumber` | string |
| `emergencyContact` | string (optional) |
| `address` | string |
| `city` | string |
| `state` | string |
| `country` | string |
| `postalCode` | string |

### `LeaveApplyRequest`

| Field | Type | Notes |
|---|---|---|
| `leaveTypeID` | int | Required (> 0). |
| `fromDate` | date | Must be ≤ `toDate`. |
| `toDate` | date | |
| `reason` | string | Required. |
| `remarks` | string | Optional. |

### `AttendanceMarkRequest`

| Field | Type | Notes |
|---|---|---|
| `attendanceDate` | date | Required. |
| `checkInTime` | time (`HH:mm:ss`) | Optional. |
| `checkOutTime` | time (`HH:mm:ss`) | Optional. |
| `workingHours` | decimal | Optional. |
| `overtimeHours` | decimal | Optional. |
| `status` | string | One of `Present`, `Absent`, `Leave`, `Half Day`, `Work From Home`. |
| `remarks` | string | Optional. |
| `shiftID` | int | Optional. |

### `AttendanceForEmployeeRequest`

Same as `AttendanceMarkRequest`, plus:

| Field | Type | Notes |
|---|---|---|
| `employeeID` | int | Target employee (validated against caller's scope). |

### `TaskStatusUpdateRequest`

| Field | Type | Notes |
|---|---|---|
| `status` | string | One of `Pending`, `In Progress`, `Completed`, `Cancelled`. |

### `TaskCreateRequest`

| Field | Type | Notes |
|---|---|---|
| `employeeID` | int | Assignee (validated against caller's scope). |
| `taskTitle` | string | Required. |
| `taskDescription` | string | Optional. |
| `priority` | string | Optional; defaults to `Medium` if blank. |
| `startDate` | date | Optional. |
| `dueDate` | date | Must be ≥ `startDate` (or today). |

### `LeaveDecisionRequest`

| Field | Type | Notes |
|---|---|---|
| `decision` | string | Exactly `Approved` or `Rejected`. |

### `AnnouncementRequest`

| Field | Type | Notes |
|---|---|---|
| `title` | string | Required. |
| `description` | string | Optional. |
| `publishDate` | date | Optional; defaults to today. |
| `expiryDate` | date | Optional; must be ≥ `publishDate`. |
| `isActive` | bool | Defaults to `true`. |

---

## Endpoint summary

| # | Method | Path | Auth / scope |
|---|---|---|---|
| 1 | POST | `/api/AuthAPI/Login` | Anonymous |
| 2 | GET | `/api/AuthAPI/private` | Any authenticated |
| 3 | GET | `/api/EmployeeAPI/me` | Self |
| 4 | PUT | `/api/EmployeeAPI/me` | Self |
| 5 | GET | `/api/EmployeeAPI/me/leaves` | Self |
| 6 | GET | `/api/EmployeeAPI/me/leave-types` | Self |
| 7 | POST | `/api/EmployeeAPI/me/leaves` | Self |
| 8 | POST | `/api/EmployeeAPI/me/leaves/{id}/cancel` | Self |
| 9 | GET | `/api/EmployeeAPI/me/attendance` | Self |
| 10 | POST | `/api/EmployeeAPI/me/attendance` | Self |
| 11 | GET | `/api/EmployeeAPI/me/payslips` | Self |
| 12 | GET | `/api/EmployeeAPI/me/payslips/{id}` | Self |
| 13 | GET | `/api/EmployeeAPI/me/tasks` | Self |
| 14 | PUT | `/api/EmployeeAPI/me/tasks/{id}/status` | Self |
| 15 | GET | `/api/EmployeeAPI/leaves` | Manager / HR / Admin |
| 16 | POST | `/api/EmployeeAPI/leaves/{id}/decision` | Manager / HR / Admin |
| 17 | GET | `/api/EmployeeAPI/attendance` | Manager / HR / Admin |
| 18 | POST | `/api/EmployeeAPI/attendance` | Manager / HR / Admin |
| 19 | GET | `/api/EmployeeAPI/tasks` | Manager / HR / Admin |
| 20 | POST | `/api/EmployeeAPI/tasks` | Manager / HR / Admin |
| 21 | PUT | `/api/EmployeeAPI/tasks/{id}/status` | Manager / HR / Admin |
| 22 | GET | `/api/EmployeeAPI/announcements` | Any authenticated |
| 23 | POST | `/api/EmployeeAPI/announcements` | HR / Admin |
| 24 | PUT | `/api/EmployeeAPI/announcements/{id}` | HR / Admin |
| 25 | POST | `/api/EmployeeAPI/announcements/{id}/toggle` | HR / Admin |
| 26 | GET | `/api/EmployeeAPI/payroll` | Manager / HR / Admin |
| 27 | GET | `/api/EmployeeAPI/payroll/{id}` | Manager / HR / Admin |

For how to obtain a token and call these endpoints from Postman/curl, see [setup.md](setup.md#5-test-the-web-api).
