# Database Scripts & Setup Guide

This directory contains the complete database scripts for **EmployeeManagementDB**, designed for Microsoft SQL Server (2019 / 2022 / Azure SQL).

---

## 📁 Directory Structure

| File | Description | When to Use |
|---|---|---|
| **[`00_EmployeeManagementDB_Full_DropAndCreate.sql`](./00_EmployeeManagementDB_Full_DropAndCreate.sql)** | **Complete all-in-one script** that terminates existing connections, drops and recreates `EmployeeManagementDB`, generates all 21 tables, constraints, 52 stored procedures, and seeds initial data. | **Recommended for complete database setup or fresh reset.** |
| **[`01_Schema_Tables_DropAndCreate.sql`](./01_Schema_Tables_DropAndCreate.sql)** | Drop and Create script for all 21 user tables with Primary Keys, Foreign Keys, Unique Keys, Check Constraints, and Defaults. | Use when you only want to rebuild tables without altering stored procedures. |
| **[`02_StoredProcedures_DropAndCreate.sql`](./02_StoredProcedures_DropAndCreate.sql)** | Drop and Create script for all 52 Stored Procedures used across the application. | Use to update, deploy, or rebuild all stored procedures. |
| **[`03_SeedData.sql`](./03_SeedData.sql)** | Master reference data (Departments, Designations, Roles, Branches, Shifts, Leave Types, Holidays, States/Cities, Salary/Tax Masters) and initial seed data. | Use to populate empty tables with baseline system data. |

---

## 🚀 Quick Setup Instructions

### Option 1: Using SQL Server Management Studio (SSMS) / Azure Data Studio

1. Open **SQL Server Management Studio** (SSMS) or **Azure Data Studio**.
2. Connect to your SQL Server instance (e.g., `localhost` or `.\SQLEXPRESS`).
3. Open [`00_EmployeeManagementDB_Full_DropAndCreate.sql`](./00_EmployeeManagementDB_Full_DropAndCreate.sql) in SSMS (`File` -> `Open` -> `File...`).
4. Click **Execute** (or press `F5`).
5. Verify in the Results pane that all tables and rows are reported successfully.

---

### Option 2: Using Command Line (`sqlcmd`)

Run the following command in PowerShell or Command Prompt from the project root:

```powershell
# Execute the full drop & create script
sqlcmd -S localhost -E -i "Database\00_EmployeeManagementDB_Full_DropAndCreate.sql"
```

Or execute individual modular scripts in order:

```powershell
# 1. Create tables & schema
sqlcmd -S localhost -d EmployeeManagementDB -E -i "Database\01_Schema_Tables_DropAndCreate.sql"

# 2. Deploy stored procedures
sqlcmd -S localhost -d EmployeeManagementDB -E -i "Database\02_StoredProcedures_DropAndCreate.sql"

# 3. Insert master & seed data
sqlcmd -S localhost -d EmployeeManagementDB -E -i "Database\03_SeedData.sql"
```

---

## ⚙️ Application Connection String

Ensure your [`appsettings.json`](../appsettings.json) has the corresponding connection string configured:

```json
"ConnectionStrings": {
  "DefaultConnection": "server=localhost;initial catalog=EmployeeManagementDB;integrated security=true;trust server certificate=true;connection timeout=30;"
}
```

---

## 📊 Database Schema Overview

### User Tables (21 Tables)

- **Master / Reference Tables (`M_*`)**:
  - `M_Department` — Department definitions
  - `M_Designation` — Job roles and designations
  - `M_OfficeBranch` — Office locations and branch contacts
  - `M_Role` — Application user roles (`0 = Admin`, `1 = HR`, `2 = Manager`, `3 = Employee`)
  - `M_Shift` — Shift timing rules and break configurations
  - `M_LeaveType` — Leave policies (Annual, Sick, Casual, Maternity, etc.)
  - `M_Holiday` — Company calendar holidays
  - `M_IndiaState` — State master reference
  - `M_IndiaCity` — City master reference
  - `M_SalaryMaster` — Base salary component slabs
  - `M_TaxMaster` — Tax brackets and deduction slabs

- **Transactional Tables (`T_*`)**:
  - `T_Employee` — Core employee records and reporting hierarchy (`ManagerID`)
  - `T_Users` — Login credentials, password hashes, salt, and activation status
  - `T_Attendance` — Daily check-in/out logs, working hours, and status
  - `T_LeaveRequest` — Leave applications and approval workflow
  - `T_Task` — Task assignments, priority, and progress tracking
  - `T_Announcement` — Company-wide and department notices
  - `T_Payroll` — Monthly salary generation, deductions, and payment status
  - `T_Bonus` — Performance bonuses and incentives
  - `T_SalaryAdvance` — Salary advance requests and repayment tracking
  - `T_EmployeeDocument` — Uploaded employee documents (ID proofs, certificates, resumes)

### Stored Procedures (52 Procedures)

All CRUD and business operations in the application are executed via dedicated stored procedures adhering to the `Procs_InsertUpdateDelete<Entity>` (using `@Mode = 1 (Insert), 2 (Update), 3 (Delete)`) and `Procs_Get<Entity>` conventions.
