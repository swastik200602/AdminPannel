# Database reference

The application runs against a SQL Server database named **`EmployeeManagementDB`**, comprising **21 user tables** and roughly **52 stored procedures**. Every read and write from the application goes through a stored procedure — there is virtually no ad-hoc SQL in the C# code.

This document is a reference for the schema: tables, columns, keys, and constraints (pulled live from the database), followed by the stored-procedure conventions and the two procedures that carry the most business logic.

---

## Table of contents

- [Conventions](#conventions)
- [Entity relationships](#entity-relationships)
- [Identity and people](#identity-and-people)
- [Master / reference data](#master--reference-data)
- [Operations](#operations)
- [Payroll](#payroll)
- [Stored procedures](#stored-procedures)
- [Schema notes](#schema-notes)

---

## Conventions

**Naming.** Tables are prefixed by role:

- `M_*` — **master / reference data**: relatively static lookups (departments, roles, shifts, leave types, holidays, office branches, India states/cities) plus the effective-dated salary and tax masters.
- `T_*` — **transactional / operational data**: employees, users, attendance, leave, tasks, announcements, documents, payroll, bonuses, advances.

**Keys and audit columns.** Most tables use an `int IDENTITY` surrogate primary key and carry a `CreatedAt datetime2 DEFAULT sysdatetime()` audit column; some also have `UpdatedAt`. Referential integrity to `T_Employee` is enforced with foreign keys throughout.

**Soft delete.** Records are generally deactivated (`IsActive = 0`) rather than physically deleted. The `Mode = 3` branch of the `Procs_InsertUpdateDelete*` procedures performs this soft delete.

**The `Mode` convention.** Create/update/delete for an entity are consolidated into one `Procs_InsertUpdateDelete<Entity>` procedure, selected by a `@Mode` parameter: `1 = Insert`, `2 = Update`, `3 = Delete`.

**Data types.** Money uses `decimal(18,2)`; hours use `decimal(5,2)`; dates use `date`; timestamps use `datetime2`; times use `time`.

---

## Entity relationships

`T_Employee` is the hub: nearly every operational and payroll table references it, and it is self-referential (`ManagerID → EmployeeID`) to model the reporting hierarchy.

```
                    M_Department  M_Designation  M_OfficeBranch  M_Shift  M_Role
                          │            │              │            │        │
                          └────────────┴──────┬───────┴────────────┴────────┘
                                              ▼
                                        ┌───────────┐
                     ManagerID (self) ◄─┤ T_Employee ├─► T_Users (login accounts)
                                        └─────┬─────┘
        ┌──────────────┬───────────────┬──────┼───────────┬──────────────┬───────────────┐
        ▼              ▼               ▼      ▼           ▼              ▼               ▼
  T_Attendance   T_LeaveRequest     T_Task  T_Payroll  M_SalaryMaster  M_TaxMaster   T_EmployeeDocument
                     │                                   T_Bonus        T_SalaryAdvance
                     ▼                                                  T_Announcement (CreatedBy)
                 M_LeaveType
```

Full foreign-key list is at the end under [Schema notes](#foreign-keys).

---

## Identity and people

### `T_Employee`

The central record for every person in the organization. Referenced by all operational and payroll tables.

| Column | Type | Null | Notes |
|---|---|---|---|
| `EmployeeID` | int | no | **PK**, identity |
| `EmployeeCode` | nvarchar(20) | no | **Unique** (`UQ_Employee_Code`) |
| `FirstName` | nvarchar(100) | no | |
| `LastName` | nvarchar(100) | no | |
| `Gender` | nvarchar(20) | no | Check: `Male` / `Female` / `Other` |
| `DateOfBirth` | date | no | |
| `Email` | nvarchar(150) | no | **Unique** (`UQ_Employee_Email`) |
| `PhoneNumber` | nvarchar(20) | no | **Unique** (`UQ_Employee_Phone`) |
| `EmergencyContact` | nvarchar(20) | yes | |
| `Address` | nvarchar(255) | no | |
| `City` | nvarchar(100) | no | |
| `State` | nvarchar(100) | no | |
| `Country` | nvarchar(100) | no | |
| `PostalCode` | nvarchar(20) | no | |
| `DepartmentID` | int | no | FK → `M_Department` |
| `DesignationID` | int | no | FK → `M_Designation` |
| `OfficeLocationID` | int | no | FK → `M_OfficeBranch` |
| `ManagerID` | int | yes | FK → `T_Employee` (self) |
| `JoiningDate` | date | no | |
| `EmploymentType` | nvarchar(30) | no | Check: `Full-Time` / `Part-Time` / `Contract` / `Intern` |
| `BasicSalary` | decimal(18,2) | no | Check: `>= 0` |
| `IsActive` | bit | no | Default `1` |
| `CreatedAt` | datetime2 | no | Default `sysdatetime()` |
| `UpdatedAt` | datetime2 | yes | |
| `ShiftID` | int | yes | FK → `M_Shift` |
| `RoleID` | int | no | FK → `M_Role` (`0` = Admin) |
| `ProfileImage` | nvarchar(500) | yes | Path under `wwwroot/uploads/employees/` |

### `T_Users`

Login accounts, linked to an employee. One employee may have a user account for authentication.

| Column | Type | Null | Notes |
|---|---|---|---|
| `UserID` | int | no | Identity |
| `EmployeeID` | int | no | The employee this account belongs to |
| `RoleID` | int | no | Role for authorization (`0` = Admin) |
| `UserName` | nvarchar(100) | yes | Login name |
| `PasswordHash` | nvarchar(100) | no | Compared by `Procs_LoginUser` (plain text in the current dev build) |
| `PasswordSalt` | nvarchar(128) | yes | Present for future salted hashing |
| `MobileNo` | nvarchar(10) | yes | |
| `Email` | nvarchar(200) | yes | |
| `LastLogin` | datetime2 | yes | Stamped on successful login |
| `WrongCount` | int | yes | For future lockout logic |
| `IsActive` | bit | no | Default `1`; deactivation is the "delete" |
| `CreatedAt` | datetime2 | no | Default `sysdatetime()` |
| `MustChangePassword` | bit | no | Default `0` |
| `PasswordChangedAt` | datetime2 | yes | |
| `PasswordResetToken` | nvarchar(200) | yes | Password-reset infrastructure |
| `PasswordResetExpiresAt` | datetime2 | yes | |

> The `PasswordSalt`, `MustChangePassword`, and `PasswordReset*` columns show the schema is already provisioned for salted password hashing and reset flows — the roadmap items noted in the README build directly on these.

---

## Master / reference data

### `M_Department`

| Column | Type | Null | Notes |
|---|---|---|---|
| `DepartmentID` | int | no | PK, identity |
| `DepartmentName` | nvarchar(100) | no | |
| `DepartmentCode` | nvarchar(20) | no | |
| `Description` | nvarchar(255) | yes | |
| `IsActive` | bit | no | |
| `CreatedAt` | datetime2 | no | |

### `M_Designation`

| Column | Type | Null | Notes |
|---|---|---|---|
| `DesignationID` | int | no | PK, identity |
| `DesignationName` | nvarchar(100) | no | |
| `DesignationCode` | nvarchar(20) | no | |
| `Description` | nvarchar(255) | yes | |
| `IsActive` | bit | no | |
| `CreatedAt` | datetime2 | no | |

### `M_Role`

| Column | Type | Null | Notes |
|---|---|---|---|
| `RoleID` | int | no | PK (**not** identity — assigned explicitly; `0` = Admin) |
| `RoleName` | nvarchar(50) | no | Used as the role claim (`Admin`, `HR`, `Manager`, `Employee`) |
| `Description` | nvarchar(255) | yes | |
| `IsActive` | bit | no | |
| `CreatedAt` | datetime2 | no | |

### `M_Shift`

| Column | Type | Null | Notes |
|---|---|---|---|
| `ShiftID` | int | no | PK, identity |
| `ShiftName` | nvarchar(100) | no | |
| `ShiftCode` | nvarchar(20) | no | |
| `StartTime` | time | no | |
| `EndTime` | time | no | |
| `GraceMinutes` | int | no | Default `0` |
| `IsNightShift` | bit | no | Default `0` |
| `IsActive` | bit | no | |
| `CreatedAt` | datetime2 | no | |

### `M_LeaveType`

| Column | Type | Null | Notes |
|---|---|---|---|
| `LeaveTypeID` | int | no | PK, identity |
| `LeaveTypeName` | nvarchar(100) | no | |
| `LeaveCode` | nvarchar(20) | no | |
| `MaxLeavesPerYear` | int | no | |
| `IsPaidLeave` | bit | no | |
| `IsActive` | bit | no | |
| `CreatedAt` | datetime2 | no | |

### `M_Holiday`

| Column | Type | Null | Notes |
|---|---|---|---|
| `HolidayID` | int | no | PK, identity |
| `HolidayName` | nvarchar(200) | no | |
| `HolidayDate` | date | no | |
| `HolidayType` | nvarchar(50) | no | |
| `Description` | nvarchar(500) | yes | |
| `IsOptional` | bit | no | Default `0` |
| `IsActive` | bit | no | |
| `CreatedAt` | datetime2 | no | |

### `M_OfficeBranch`

| Column | Type | Null | Notes |
|---|---|---|---|
| `OfficeLocationID` | int | no | PK, identity |
| `OfficeName` | nvarchar(100) | no | |
| `OfficeCode` | nvarchar(20) | no | |
| `AddressLine1` | nvarchar(200) | no | |
| `AddressLine2` | nvarchar(200) | yes | |
| `City` | nvarchar(100) | no | |
| `State` | nvarchar(100) | no | |
| `Country` | nvarchar(100) | no | |
| `PostalCode` | nvarchar(20) | yes | |
| `PhoneNumber` | nvarchar(20) | yes | |
| `Email` | nvarchar(100) | yes | |
| `IsActive` | bit | no | |
| `CreatedAt` | datetime2 | no | |

### `M_IndiaState` and `M_IndiaCity`

Reference data driving cascading location dropdowns.

**`M_IndiaState`** — `StateID` (PK, identity), `StateName` nvarchar(100), `IsActive` bit.

**`M_IndiaCity`** — `CityID` (PK, identity), `StateID` (→ state), `CityName` nvarchar(100), `IsActive` bit.

---

## Operations

### `T_Attendance`

One row per employee per day (enforced by a unique constraint).

| Column | Type | Null | Notes |
|---|---|---|---|
| `AttendanceID` | int | no | PK, identity |
| `EmployeeID` | int | no | FK → `T_Employee` |
| `AttendanceDate` | date | no | |
| `CheckInTime` | time | yes | |
| `CheckOutTime` | time | yes | |
| `WorkingHours` | decimal(5,2) | yes | |
| `OvertimeHours` | decimal(5,2) | yes | Default `0` |
| `Status` | nvarchar(20) | no | Check: `Present` / `Absent` / `Leave` / `Half Day` / `Work From Home` |
| `Remarks` | nvarchar(255) | yes | |
| `CreatedAt` | datetime2 | no | Default `sysdatetime()` |
| `ShiftID` | int | yes | FK → `M_Shift` |

Unique: `UQ_Attendance (EmployeeID, AttendanceDate)`.

### `T_LeaveRequest`

| Column | Type | Null | Notes |
|---|---|---|---|
| `LeaveRequestID` | int | no | PK, identity |
| `EmployeeID` | int | no | FK → `T_Employee` |
| `LeaveTypeID` | int | no | FK → `M_LeaveType` |
| `FromDate` | date | no | Check: `FromDate <= ToDate` |
| `ToDate` | date | no | |
| `NumberOfDays` | decimal(5,2) | no | Check: `> 0` (server-computed) |
| `Reason` | nvarchar(500) | no | |
| `Status` | nvarchar(20) | no | Default `Pending`; check: `Pending` / `Approved` / `Rejected` / `Cancelled` |
| `ApprovedBy` | int | yes | FK → `T_Employee` |
| `ApprovedDate` | datetime2 | yes | |
| `Remarks` | nvarchar(500) | yes | |
| `CreatedAt` | datetime2 | no | Default `sysdatetime()` |

### `T_Task`

| Column | Type | Null | Notes |
|---|---|---|---|
| `TaskID` | int | no | PK, identity |
| `EmployeeID` | int | no | Assignee; FK → `T_Employee` |
| `AssignedBy` | int | no | FK → `T_Employee` |
| `TaskTitle` | nvarchar(200) | no | |
| `TaskDescription` | nvarchar(MAX) | yes | |
| `Priority` | nvarchar(20) | no | Default `Medium`; check: `Low` / `Medium` / `High` / `Critical` |
| `Status` | nvarchar(20) | no | Default `Pending`; check: `Pending` / `In Progress` / `Completed` / `Cancelled` |
| `StartDate` | date | no | Check: `StartDate <= DueDate` |
| `DueDate` | date | no | |
| `CompletedDate` | date | yes | Stamped when status → `Completed` |
| `CreatedAt` | datetime2 | no | Default `sysdatetime()` |

### `T_Announcement`

| Column | Type | Null | Notes |
|---|---|---|---|
| `AnnouncementID` | int | no | PK, identity |
| `Title` | nvarchar(200) | no | |
| `Description` | nvarchar(MAX) | yes | |
| `PublishDate` | date | no | |
| `ExpiryDate` | date | yes | Check: null OR `PublishDate <= ExpiryDate` |
| `CreatedBy` | int | no | FK → `T_Employee` (doubles as last-modified-by) |
| `IsActive` | bit | no | Default `1` |
| `CreatedAt` | datetime2 | no | Default `sysdatetime()` |

### `T_EmployeeDocument`

| Column | Type | Null | Notes |
|---|---|---|---|
| `DocumentID` | int | no | PK, identity |
| `EmployeeID` | int | no | FK → `T_Employee` |
| `DocumentType` | nvarchar(100) | no | |
| `DocumentName` | nvarchar(255) | no | |
| `FilePath` | nvarchar(500) | no | Under `App_Data/EmployeeDocuments/{employeeId}/` |
| `FileExtension` | nvarchar(20) | no | |
| `FileSizeKB` | decimal(10,2) | yes | |
| `UploadedDate` | datetime2 | no | |
| `ExpiryDate` | date | yes | |
| `IsVerified` | bit | no | Default `0` |
| `Remarks` | nvarchar(500) | yes | |

---

## Payroll

### `M_SalaryMaster`

The effective-dated salary structure. At most one **active** row per employee.

| Column | Type | Null | Notes |
|---|---|---|---|
| `SalaryMasterID` | int | no | PK, identity |
| `EmployeeID` | int | no | FK → `T_Employee` |
| `BasicSalary` | decimal(18,2) | no | Default `0`, check `>= 0` |
| `Allowance` | decimal(18,2) | no | Default `0`, check `>= 0` |
| `Bonus` | decimal(18,2) | no | Default `0`, check `>= 0` |
| `Deduction` | decimal(18,2) | no | Default `0`, check `>= 0` |
| `Tax` | decimal(18,2) | no | Default `0`, check `>= 0` |
| `EffectiveFrom` | date | no | |
| `EffectiveTo` | date | yes | Null while current |
| `IsActive` | bit | no | Default `1` |
| `RevisionReason` | nvarchar(200) | yes | |
| `CreatedAt` | datetime2 | no | |

Unique: `UX_M_SalaryMaster_ActiveEmployee (EmployeeID)` — one active structure per employee.

### `M_TaxMaster`

Effective-dated tax configuration, at most one active row per employee per tax type.

| Column | Type | Null | Notes |
|---|---|---|---|
| `TaxMasterID` | int | no | PK, identity |
| `EmployeeID` | int | no | FK → `T_Employee` |
| `TaxType` | nvarchar(30) | no | Check: `TDS` / `IncomeTax` / `Other` |
| `TaxAmount` | decimal(18,2) | no | Default `0` |
| `EffectiveFrom` | date | no | |
| `EffectiveTo` | date | yes | |
| `IsActive` | bit | no | Default `1` |
| `Reason` | nvarchar(250) | yes | |
| `CreatedAt` | datetime2 | no | |
| `CreatedBy` | int | yes | |

Unique: `UX_M_TaxMaster_ActiveEmployeeType (EmployeeID, TaxType)`.

### `T_Bonus`

| Column | Type | Null | Notes |
|---|---|---|---|
| `BonusID` | int | no | PK, identity |
| `EmployeeID` | int | no | FK → `T_Employee` |
| `BonusAmount` | decimal(18,2) | no | Check: `> 0` |
| `BonusMonth` | tinyint | no | Check: `1–12` |
| `BonusYear` | smallint | no | Check: `>= 2000` |
| `BonusType` | nvarchar(50) | yes | |
| `Reason` | nvarchar(250) | yes | |
| `Status` | nvarchar(20) | no | Default `Pending`; check: `Pending` / `Applied` / `Cancelled` |
| `PaidDate` | date | yes | |
| `CreatedAt` | datetime2 | no | |
| `CreatedBy` | int | yes | |

Index: `IX_T_Bonus_EmployeeMonthYear`. Pending bonuses are picked up and marked `Applied` when payroll is generated.

### `T_SalaryAdvance`

Advances and loans, recovered from payroll in monthly instalments.

| Column | Type | Null | Notes |
|---|---|---|---|
| `SalaryAdvanceID` | int | no | PK, identity |
| `EmployeeID` | int | no | FK → `T_Employee` |
| `TransactionType` | nvarchar(20) | no | Check: `Advance` / `Loan` |
| `TotalAmount` | decimal(18,2) | no | |
| `RecoveredAmount` | decimal(18,2) | no | Default `0` |
| `OutstandingAmount` | decimal(18,2) | no | |
| `MonthlyRecoveryAmount` | decimal(18,2) | no | Default `0` |
| `IssueDate` | date | no | |
| `RecoveryStartMonth` | tinyint | no | |
| `RecoveryStartYear` | smallint | no | |
| `Status` | nvarchar(20) | no | Default `Active`; check: `Active` / `Completed` / `Cancelled` |
| `Remarks` | nvarchar(500) | yes | |
| `CreatedAt` | datetime2 | no | |
| `CreatedBy` | int | yes | |

### `T_Payroll`

The generated payroll record. One row per employee per month (unique constraint).

| Column | Type | Null | Notes |
|---|---|---|---|
| `PayrollID` | int | no | PK, identity |
| `EmployeeID` | int | no | FK → `T_Employee` |
| `PayrollMonth` | tinyint | no | Check: `1–12` |
| `PayrollYear` | smallint | no | |
| `BasicSalary` | decimal(18,2) | no | |
| `Allowance` | decimal(18,2) | no | Default `0` |
| `Bonus` | decimal(18,2) | no | Default `0` |
| `Deduction` | decimal(18,2) | no | Default `0` |
| `Tax` | decimal(18,2) | no | Default `0` |
| `NetSalary` | decimal(18,2) | no | Computed by the generation procedure |
| `PaymentDate` | date | yes | |
| `PaymentStatus` | nvarchar(20) | no | Default `Pending`; check: `Pending` / `Processing` / `Paid` |
| `Remarks` | nvarchar(500) | yes | |
| `CreatedAt` | datetime2 | no | Default `sysdatetime()` |
| `AdvanceRecovery` | decimal(18,2) | no | Default `0` — instalment recovered this run |

Unique: `UQ_Payroll (EmployeeID, PayrollMonth, PayrollYear)`.

Net pay is `BasicSalary + Allowance + Bonus − Deduction − Tax − AdvanceRecovery`.

---

## Stored procedures

The application uses roughly 52 procedures. They fall into a few consistent families:

**Read — `Procs_Get<Entity>`.** Accept nullable filter parameters (id, active flag, search text, date ranges) so a single procedure serves both "get one" and "list / search". Examples: `Procs_GetEmployees`, `Procs_GetLeaveRequests`, `Procs_GetAttendance`, `Procs_GetTasks`, `Procs_GetAnnouncements`, `Procs_GetPayroll`, `Procs_GetSalarySlip`, `Procs_GetEmployeePayrollHistory`, and the master-data readers (`Procs_GetDepartment`, `Procs_GetLeaveType`, …).

**Write — `Procs_InsertUpdateDelete<Entity>`.** A single procedure per entity handling all three writes via `@Mode` (`1`/`2`/`3`). They return a one-row result set with `StatusCode` and `Message`, which the app maps onto its `ResultSet` model and (for the API) re-wraps as `{ statusCode, message, data }`.

Two procedures carry materially more logic and are worth calling out:

### `Procs_LoginUser`

Parameters `@UserName nvarchar(100)`, `@PasswordHash nvarchar(200)`.

Validates the account (`PasswordHash = @PasswordHash AND IsActive = 1`), updates `LastLogin`, and returns either a rejection (e.g. `401`) or a rich success row joining user, role, and employee data (`UserID`, `EmployeeID`, `RoleID`, `RoleName`, `UserName`, `Email`, `EmployeeCode`, `FirstName`, `LastName`, department/designation/office/manager/shift ids, `MustChangePassword`, …). This row is what `TokenService` turns into JWT claims.

> The comparison is plain text in the current development build; the `PasswordSalt` column exists to support salted hashing later.

### `Procs_GeneratePayroll`

Parameters `@EmployeeID`, `@PayrollMonth tinyint`, `@PayrollYear smallint`, `@PaymentStatus nvarchar(20) = 'Pending'`, `@Remarks nvarchar(500) = NULL`.

This is the payroll engine — wrapped in a transaction with `XACT_ABORT` so the whole run is atomic. In order it:

1. Validates month (`1–12`), year (`>= 2000`), and payment status; checks the employee is active (`404` if not) and that no payroll already exists for the period (`409` if it does).
2. Resolves the **effective** salary structure from `M_SalaryMaster` for the period.
3. Aggregates taxes (`TDS`, `IncomeTax`, `Other`) from `M_TaxMaster`.
4. Computes total bonus = salary-master `Bonus` + any `Pending` rows in `T_Bonus`.
5. Computes advance recovery = `min(MonthlyRecoveryAmount, OutstandingAmount)` across active `T_SalaryAdvance` rows.
6. Computes `NetSalary = Basic + Allowance + TotalBonus − Deduction − TotalTax − AdvanceRecovery`.
7. Inserts the `T_Payroll` row, marks the applied bonuses `Applied`, updates each advance's recovered/outstanding/status, and returns `200` with the full breakdown.

Because this happens inside one transaction, a failure at any step rolls the whole payroll run back — no partially-applied bonuses or advance recoveries.

---

## Schema notes

A few observations worth recording for a reviewer or a future maintainer:

- **`T_Users` has no declared primary key, foreign keys, or indexes.** `UserID` is an identity column but is not constrained as a PK, and the link to `T_Employee`/`M_Role` is by convention rather than a foreign key. Adding a primary key, an FK to `T_Employee`, and a unique index on `UserName` would tighten integrity.
- **`T_Payroll.PaymentStatus` allows `Pending` / `Processing` / `Paid`.** The generation procedure also recognizes a `Failed` status in its parameter validation, so if `Failed` is ever intended to be persisted the check constraint would need to include it.
- **Uniqueness guards the important invariants.** One attendance row per employee per day, one payroll per employee per month, one active salary master per employee, and one active tax master per employee per tax type are all enforced at the database level rather than only in code.
- **Effective-dating** on `M_SalaryMaster` and `M_TaxMaster` (via `EffectiveFrom` / `EffectiveTo` + `IsActive`) is what lets payroll be recomputed correctly for a historical period.

### Foreign keys

All operational and payroll tables reference `T_Employee`:

| Source table | Column(s) | → Target |
|---|---|---|
| `T_Employee` | `DepartmentID` | `M_Department` |
| `T_Employee` | `DesignationID` | `M_Designation` |
| `T_Employee` | `OfficeLocationID` | `M_OfficeBranch` |
| `T_Employee` | `ShiftID` | `M_Shift` |
| `T_Employee` | `RoleID` | `M_Role` |
| `T_Employee` | `ManagerID` | `T_Employee` (self) |
| `T_Attendance` | `EmployeeID`, `ShiftID` | `T_Employee`, `M_Shift` |
| `T_LeaveRequest` | `EmployeeID`, `ApprovedBy`, `LeaveTypeID` | `T_Employee`, `T_Employee`, `M_LeaveType` |
| `T_Task` | `EmployeeID`, `AssignedBy` | `T_Employee`, `T_Employee` |
| `T_Announcement` | `CreatedBy` | `T_Employee` |
| `T_EmployeeDocument` | `EmployeeID` | `T_Employee` |
| `T_Payroll` | `EmployeeID` | `T_Employee` |
| `M_SalaryMaster` | `EmployeeID` | `T_Employee` |
| `M_TaxMaster` | `EmployeeID` | `T_Employee` |
| `T_Bonus` | `EmployeeID` | `T_Employee` |
| `T_SalaryAdvance` | `EmployeeID` | `T_Employee` |

For how these tables are accessed from code, see [architecture.md](architecture.md#data-access-conventions).
