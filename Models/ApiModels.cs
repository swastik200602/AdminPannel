namespace AdminPannel.Models
{
    // Request body for POST api/AuthAPI/Login.
    // UserName + Password map directly to what dbo.Procs_LoginUser expects
    // (@UserName, @PasswordHash). We use this dedicated DTO instead of
    // Microsoft.AspNetCore.Identity.Data.LoginRequest because that type forces
    // an "Email" field, but this system authenticates by USERNAME (not email) —
    // which would confuse the React client and anyone testing in Postman.
    public class ApiLoginRequest
    {
        public string? UserName { get; set; }
        public string? Password { get; set; }
    }

    // Response body returned on a successful API login. Carries the JWT plus the
    // minimum user identity the React app needs. Kept separate from LoginResponse
    // (which is the typed row-mapper for the stored procedure's result set) so the
    // database model and the public API contract can evolve independently.
    public class LoginApiResponse
    {
        public int UserID { get; set; }
        public int EmployeeID { get; set; }
        public int RoleID { get; set; }
        public string? RoleName { get; set; }
        public string? UserName { get; set; }
        public string? Email { get; set; }

        public string Token { get; set; } = string.Empty;
        public string TokenType { get; set; } = "Bearer";
        public int ExpiresIn { get; set; }
    }

    // Request body for POST api/EmployeeAPI/me/leaves (employee applies for leave).
    // Deliberately a SMALL, self-service-only DTO: the caller supplies just the four
    // things a requester legitimately controls. EmployeeID is taken from the JWT
    // "CustId" claim, Status is forced to "Pending", and ApprovedBy/ApprovedDate/
    // NumberOfDays are set by the server — so a caller can never file leave for
    // someone else, self-approve, or forge the day count. This mirrors the safe
    // fields used by OperationsController.LeaveCreate.
    public class LeaveApplyRequest
    {
        public int LeaveTypeID { get; set; }
        public DateTime FromDate { get; set; }
        public DateTime ToDate { get; set; }
        public string? Reason { get; set; }
        public string? Remarks { get; set; }
    }

    // Request body for POST api/EmployeeAPI/me/attendance (employee marks own attendance).
    // Same self-service principle: EmployeeID comes from the token, never the body.
    // CheckInTime/CheckOutTime are TimeSpan? to match AttendanceModel exactly (JSON
    // sends them as "HH:mm:ss"). Mode is always Insert on the server side.
    public class AttendanceMarkRequest
    {
        public DateTime AttendanceDate { get; set; }
        public TimeSpan? CheckInTime { get; set; }
        public TimeSpan? CheckOutTime { get; set; }
        public decimal? WorkingHours { get; set; }
        public decimal? OvertimeHours { get; set; }
        public string? Status { get; set; }
        public string? Remarks { get; set; }
        public int? ShiftID { get; set; }
    }

    // Request body for PUT api/EmployeeAPI/me/tasks/{id}/status (employee updates the
    // status of their OWN task). Only the status is accepted — the caller cannot retitle,
    // reassign, or re-prioritise the task. The server fetches the existing row (scoped to
    // the caller's CustId), keeps every other field unchanged, and rewrites only Status
    // (and CompletedDate when the status becomes "Completed"). The task itself is chosen
    // by the {id} in the route but is validated to belong to the caller before any update.
    public class TaskStatusUpdateRequest
    {
        public string? Status { get; set; }
    }

    // Request body for POST api/EmployeeAPI/leaves/{id}/decision (a manager / HR / admin
    // approves or rejects someone's pending leave). Only the decision is accepted —
    // "Approved" or "Rejected". The target request is chosen by the {id} in the route and
    // is validated (must be Pending, and for a Manager must belong to their team) before
    // any update. ApprovedBy/ApprovedDate are stamped by the server from the caller's token.
    public class LeaveDecisionRequest
    {
        public string? Decision { get; set; }
    }

    // Request body for POST api/EmployeeAPI/attendance (a manager / HR / admin marks
    // attendance FOR ANOTHER employee). Same shape as AttendanceMarkRequest but with an
    // explicit EmployeeID — the target. That EmployeeID is NOT trusted blindly: the server
    // checks the caller may manage that employee (HR/Admin over anyone, Manager over their
    // own team) before inserting. Employees mark their own via POST me/attendance instead.
    public class AttendanceForEmployeeRequest
    {
        public int EmployeeID { get; set; }
        public DateTime AttendanceDate { get; set; }
        public TimeSpan? CheckInTime { get; set; }
        public TimeSpan? CheckOutTime { get; set; }
        public decimal? WorkingHours { get; set; }
        public decimal? OvertimeHours { get; set; }
        public string? Status { get; set; }
        public string? Remarks { get; set; }
        public int? ShiftID { get; set; }
    }

    // Request body for POST api/EmployeeAPI/tasks (a manager / HR / admin assigns a task).
    // EmployeeID is the assignee and is validated against the caller's scope (a Manager may
    // only assign to their team). The server sets AssignedBy = caller's CustId and
    // Status = "Pending"; the caller cannot spoof either. Mirrors the safe fields used by
    // OperationsController.TaskCreate.
    public class TaskCreateRequest
    {
        public int EmployeeID { get; set; }
        public string? TaskTitle { get; set; }
        public string? TaskDescription { get; set; }
        public string? Priority { get; set; }
        public DateTime? StartDate { get; set; }
        public DateTime DueDate { get; set; }
    }

    // Request body for creating (POST) or editing (PUT) an announcement — HR/Admin only.
    // PublishDate defaults to today when omitted; ExpiryDate is optional. CreatedBy is NOT
    // in the body — the server stamps it from the caller's token (and, matching the existing
    // MVC behaviour, it doubles as "last modified by" on edit/toggle).
    public class AnnouncementRequest
    {
        public string? Title { get; set; }
        public string? Description { get; set; }
        public DateTime? PublishDate { get; set; }
        public DateTime? ExpiryDate { get; set; }
        public bool IsActive { get; set; } = true;
    }
}
