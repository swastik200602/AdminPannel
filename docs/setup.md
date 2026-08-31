# Setup and run guide

This guide walks through configuring, building, and running the Employee Management System locally, plus how to obtain a token and exercise the Web API.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| **.NET 10 SDK** | The project targets `net10.0`. Verify with `dotnet --version`. |
| **SQL Server** | Any recent edition (Developer, Express, or LocalDB). The default configuration connects to a local instance. |
| **`EmployeeManagementDB`** | The application expects this database to already exist, populated with its tables and stored procedures (see [Database setup](#database-setup)). |
| **A SQL client** *(optional)* | SQL Server Management Studio (SSMS) or Azure Data Studio for inspecting the database. |
| **Visual Studio 2022+ or VS Code** *(optional)* | The solution uses the newer `.slnx` format (`AdminPannel.slnx`). You can also work entirely from the `dotnet` CLI. |
| **Postman / curl** *(optional)* | For testing the JWT Web API. |

---

## 1. Get the code

```bash
git clone <your-repository-url>
cd AdminPannel
```

---

## Database setup

> **Important:** this repository contains the application code, not database migration scripts. The app talks exclusively to SQL Server **stored procedures**, so the `EmployeeManagementDB` database — with its 21 tables and ~52 procedures — must be provisioned on your SQL Server instance before the app will work.

Make sure your instance has:

- A database named **`EmployeeManagementDB`**.
- The **tables** and **stored procedures** described in [database.md](database.md) (the `Procs_Get*`, `Procs_InsertUpdateDelete*`, `Procs_LoginUser`, `Procs_GeneratePayroll`, etc.).
- At least one **user account** to log in with. Because login currently compares the password as plain text (development mode), you can seed a row in `T_Users` with a known `UserName`/`PasswordHash` linked to an active `T_Employee` row whose role resolves to Admin.

If you maintain the schema separately (for example in a database project or a set of `.sql` scripts kept outside this repo), apply it to `EmployeeManagementDB` first.

---

## 2. Configure the application

All configuration lives in **`appsettings.json`**.

### Connection string

```jsonc
{
  "ConnectionStrings": {
    "DefaultConnection": "server=localhost;initial catalog=EmployeeManagementDB;integrated security=true;trust server certificate=true;connection timeout=30;"
  }
}
```

The default uses **Windows integrated security** against `localhost`. Adjust it to match your environment:

- **Named instance:** `server=localhost\\SQLEXPRESS;...`
- **SQL authentication:** replace `integrated security=true` with `user id=<user>;password=<password>;`
- **Remote server:** change `server=` to the host name or IP.

`trust server certificate=true` avoids TLS-certificate validation for local development; review it for any non-local target.

### JWT settings

```jsonc
{
  "Jwt": {
    "Key": "…a long secret signing key…",
    "Issuer": "Employee",
    "Audience": "EmployeeManage",
    "ExpiryMinutes": 10080
  }
}
```

- `Key` signs and validates every API token (HMAC-SHA256). It ships with a development value — **replace it and move it out of source control** (user secrets or environment variables) before any shared or production use.
- `Issuer` / `Audience` must match on both issue and validation (they are wired to the same config in `Program.cs`).
- `ExpiryMinutes` controls token lifetime (default here is 7 days).

---

## 3. Build and run

### Using the .NET CLI

```bash
dotnet restore
dotnet build
dotnet run
```

### Using Visual Studio

Open `AdminPannel.slnx`, then press **F5** (debug) or **Ctrl+F5** (run without debugging).

### Endpoints

Once running, the app listens on (from `Properties/launchSettings.json`):

| Profile | URL |
|---|---|
| HTTPS | `https://localhost:7182` |
| HTTP | `http://localhost:5144` |

The environment is set to `Development` by the launch profile, which enables developer-friendly error messages. The default route lands on the **Account** login page.

If the browser warns about the local HTTPS certificate, trust the ASP.NET Core development certificate once:

```bash
dotnet dev-certs https --trust
```

---

## 4. Sign in

Open `https://localhost:7182`, and log in with a `T_Users` account that exists in your database.

Because password comparison is plain text in the current development build, the stored `PasswordHash` value **is** the password you type. Seed accounts accordingly.

### Creating additional accounts

Once signed in as Admin or HR, use **User management** to provision login accounts for employees. In the current development build, newly created accounts are issued a **fixed temporary password (`123`)** rather than a randomly generated one — a deliberate simplification noted in the code and [roadmap](../README.md#known-limitations-and-roadmap). Only an Admin may create another Admin account.

---

## 5. Test the Web API

The API is served from the same host. A typical flow with Postman or curl:

### Step 1 — Log in to get a token

```bash
curl -k -X POST https://localhost:7182/api/AuthAPI/Login \
  -H "Content-Type: application/json" \
  -d '{ "userName": "your.username", "password": "your.password" }'
```

Response:

```jsonc
{
  "statusCode": 200,
  "message": "Login Success..!",
  "data": {
    "userID": 1,
    "employeeID": 1,
    "roleID": 0,
    "roleName": "Admin",
    "userName": "your.username",
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "tokenType": "Bearer",
    "expiresIn": 3600
  }
}
```

### Step 2 — Call a secured endpoint

Copy `data.token` and send it as a bearer token:

```bash
curl -k https://localhost:7182/api/EmployeeAPI/me \
  -H "Authorization: Bearer <token>"
```

A quick way to confirm the token is accepted is `GET /api/AuthAPI/private`, which simply echoes your user id and role. The full endpoint catalogue is in [api-reference.md](api-reference.md).

---

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| `A network-related or instance-specific error` on startup/login | SQL Server not reachable, or wrong `server=` value. Confirm the instance name and that it accepts your chosen authentication mode. |
| Login always returns *Invalid username or password* | The account doesn't exist, is inactive (`IsActive = 0`), or the plain-text password doesn't match the stored `PasswordHash`. |
| `Employee-code generation is not configured` when creating an employee | The `Procs_NextEmployeeCode` procedure is missing. The app's own message tells you to run `Database/EmployeeCode_Migration.sql` — apply that script (or otherwise create the procedure) against `EmployeeManagementDB`, then retry. |
| Browser HTTPS warning | Run `dotnet dev-certs https --trust`. |
| Port already in use | Another process holds `7182`/`5144`. Stop it, or change the ports in `Properties/launchSettings.json`. |
| `401 Unauthorized` from the API | Missing/expired token, or an `Issuer`/`Audience`/`Key` mismatch between `appsettings.json` and the token you're sending. Re-login to get a fresh token. |
| Uploaded documents/images not visible | Ensure the app can write to `App_Data/EmployeeDocuments/` and `wwwroot/uploads/`, and that static files are being served. |

---

## Configuration reference

| File | Purpose |
|---|---|
| `appsettings.json` | Connection string and JWT settings (base configuration). |
| `appsettings.Development.json` | Development overrides (logging levels, etc.). |
| `Properties/launchSettings.json` | Local launch profiles, URLs, and `ASPNETCORE_ENVIRONMENT`. |
| `.keys/` | Data Protection keys (auto-generated, git-ignored). |

For an explanation of what happens during startup, see [architecture.md](architecture.md#application-bootstrap-programcs).
