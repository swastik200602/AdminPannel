using AdminPannel.Logic;
using AdminPannel.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AdminPannel.Controllers;

[Authorize]
public class OperationsController : Controller
{
    private readonly AppData _app = new();

    private bool IsAdminOrHr => User.IsInRole("Admin") || User.IsInRole("HR");
    private int CurrentEmployeeId => int.TryParse(User.FindFirst("EmployeeID")?.Value, out var id) ? id : 0;
    private List<EmployeeResponse> Employees() => _app.SelectModelList<EmployeeResponse>("Procs_GetEmployees", new { EmployeeID = (int?)null, DepartmentID = (int?)null, DesignationID = (int?)null, OfficeLocationID = (int?)null, ManagerID = (int?)null, ShiftID = (int?)null, RoleID = (int?)null, IsActive = true, Search = (string?)null }) ?? new();
    private bool IsTeamMember(int employeeId) => CurrentEmployeeId > 0 && Employees().Any(e => e.EmployeeID == employeeId && e.ManagerID == CurrentEmployeeId);
    private bool CanViewEmployee(int employeeId) => IsAdminOrHr || (User.IsInRole("Employee") && employeeId == CurrentEmployeeId) || (User.IsInRole("Manager") && IsTeamMember(employeeId));

    [HttpGet]
    public IActionResult Attendance(int? employeeId, DateTime? fromDate, DateTime? toDate, string? status)
    {
        var requested = IsAdminOrHr ? employeeId : User.IsInRole("Employee") ? CurrentEmployeeId : null;
        var rows = _app.SelectModelList<AttendanceModel>("Procs_GetAttendance", new { AttendanceID = (int?)null, EmployeeID = requested, FromDate = fromDate, ToDate = toDate, Status = status }) ?? new();
        if (User.IsInRole("Manager")) rows = rows.Where(x => IsTeamMember(x.EmployeeID)).ToList();
        ViewBag.Employees = IsAdminOrHr ? Employees() : new List<EmployeeResponse>();
        ViewBag.Error = null;
        return View(rows);
    }

    [HttpGet]
    public IActionResult AttendanceCreate(int? employeeId)
    {
        if (User.IsInRole("Employee"))
        {
            if (CurrentEmployeeId <= 0) return Forbid();
            ViewBag.Employees = new List<EmployeeResponse>();
            return View("AttendanceCreate", new AttendanceModel { EmployeeID = CurrentEmployeeId, AttendanceDate = DateTime.Today, Status = "Present" });
        }

        var selectableEmployees = IsAdminOrHr
            ? Employees()
            : User.IsInRole("Manager")
                ? Employees().Where(x => x.ManagerID == CurrentEmployeeId).ToList()
                : new List<EmployeeResponse>();

        if (!selectableEmployees.Any()) return Forbid();
        if (employeeId.HasValue && !selectableEmployees.Any(x => x.EmployeeID == employeeId.Value)) return Forbid();

        ViewBag.Employees = selectableEmployees;
        return View("AttendanceCreate", new AttendanceModel { EmployeeID = employeeId ?? 0, AttendanceDate = DateTime.Today, Status = "Present" });
    }

    [HttpPost, ValidateAntiForgeryToken]
    public IActionResult AttendanceCreate(AttendanceModel request)
    {
        var employeeId = User.IsInRole("Employee") ? CurrentEmployeeId : request.EmployeeID;
        if (employeeId <= 0 || !CanViewEmployee(employeeId)) return Forbid();
        var valid = new[] { "Present", "Absent", "Leave", "Half Day", "Work From Home" };
        if (request.AttendanceDate == default) ModelState.AddModelError(nameof(request.AttendanceDate), "Attendance date is required.");
        if (!valid.Contains(request.Status ?? "", StringComparer.OrdinalIgnoreCase)) ModelState.AddModelError(nameof(request.Status), "Select a valid attendance status.");
        if (!ModelState.IsValid)
        {
            ViewBag.Employees = IsAdminOrHr
                ? Employees()
                : User.IsInRole("Manager")
                    ? Employees().Where(x => x.ManagerID == CurrentEmployeeId).ToList()
                    : new List<EmployeeResponse>();
            return View("AttendanceCreate", request);
        }
        var result = _app.SelectModel<ResultSet>("Procs_InsertUpdateDeleteAttendance", new { AttendanceID = 0, EmployeeID = employeeId, request.AttendanceDate, request.CheckInTime, request.CheckOutTime, request.WorkingHours, request.OvertimeHours, request.Status, request.Remarks, request.ShiftID, Mode = 1 });
        TempData[result?.StatusCode == 200 ? "Success" : "Error"] = result?.Message ?? "Attendance could not be saved.";
        return RedirectToAction(nameof(Attendance));
    }

    [HttpGet]
    public IActionResult Leave(int? employeeId, string? status)
    {
        var requested = IsAdminOrHr ? employeeId : User.IsInRole("Employee") ? CurrentEmployeeId : null;
        var rows = _app.SelectModelList<LeaveRequestModel>("Procs_GetLeaveRequests", new { EmployeeID = requested, Status = status, FromDate = (DateTime?)null, ToDate = (DateTime?)null }) ?? new();
        if (User.IsInRole("Manager")) rows = rows.Where(x => IsTeamMember(x.EmployeeID)).ToList();
        ViewBag.Employees = IsAdminOrHr ? Employees() : new List<EmployeeResponse>();
        return View(rows);
    }

    [HttpGet]
    public IActionResult LeaveCreate() { ViewBag.LeaveTypes = _app.SelectModelList<LeaveTypeResponse>("Procs_GetLeaveType", new { LeaveTypeID = (int?)null, IsActive = true, Search = (string?)null }) ?? new(); return View(new LeaveRequestModel { FromDate = DateTime.Today, ToDate = DateTime.Today }); }

    [HttpPost, ValidateAntiForgeryToken]
    public IActionResult LeaveCreate(LeaveRequestModel request)
    {
        if (CurrentEmployeeId <= 0) return Forbid();
        if (request.LeaveTypeID <= 0) ModelState.AddModelError(nameof(request.LeaveTypeID), "Leave type is required.");
        if (request.FromDate > request.ToDate) ModelState.AddModelError(nameof(request.ToDate), "To date cannot be before from date.");
        if (string.IsNullOrWhiteSpace(request.Reason)) ModelState.AddModelError(nameof(request.Reason), "Reason is required.");
        if (!ModelState.IsValid) { ViewBag.LeaveTypes = _app.SelectModelList<LeaveTypeResponse>("Procs_GetLeaveType", new { LeaveTypeID = (int?)null, IsActive = true, Search = (string?)null }) ?? new(); return View(request); }
        var result = _app.SelectModel<ResultSet>("Procs_InsertUpdateDeleteLeaveRequest", new { LeaveRequestID = 0, EmployeeID = CurrentEmployeeId, request.LeaveTypeID, request.FromDate, request.ToDate, NumberOfDays = (decimal)(request.ToDate.Date - request.FromDate.Date).TotalDays + 1, request.Reason, Status = "Pending", ApprovedBy = (int?)null, ApprovedDate = (DateTime?)null, request.Remarks, Mode = 1 });
        TempData[result?.StatusCode == 200 ? "Success" : "Error"] = result?.Message ?? "Leave request could not be saved."; return RedirectToAction(nameof(Leave));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public IActionResult LeaveDecision(int id, string decision)
    {
        if (!IsAdminOrHr && !User.IsInRole("Manager")) return Forbid();
        var row = (_app.SelectModelList<LeaveRequestModel>("Procs_GetLeaveRequests", new { EmployeeID = (int?)null, Status = (string?)null, FromDate = (DateTime?)null, ToDate = (DateTime?)null }) ?? new()).FirstOrDefault(x => x.LeaveRequestID == id);
        if (row == null || row.Status != "Pending" || !CanViewEmployee(row.EmployeeID) || !new[] { "Approved", "Rejected" }.Contains(decision)) return Forbid();
        var result = _app.SelectModel<ResultSet>("Procs_InsertUpdateDeleteLeaveRequest", new { row.LeaveRequestID, row.EmployeeID, row.LeaveTypeID, row.FromDate, row.ToDate, row.NumberOfDays, row.Reason, Status = decision, ApprovedBy = CurrentEmployeeId > 0 ? CurrentEmployeeId : (int?)null, ApprovedDate = DateTime.Now, row.Remarks, Mode = 2 });
        TempData[result?.StatusCode == 200 ? "Success" : "Error"] = result?.Message ?? "Leave decision failed."; return RedirectToAction(nameof(Leave));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public IActionResult LeaveCancel(int id)
    {
        var row = (_app.SelectModelList<LeaveRequestModel>("Procs_GetLeaveRequests", new { EmployeeID = CurrentEmployeeId, Status = (string?)null, FromDate = (DateTime?)null, ToDate = (DateTime?)null }) ?? new()).FirstOrDefault(x => x.LeaveRequestID == id);
        if (row == null || row.Status != "Pending" || row.EmployeeID != CurrentEmployeeId) return Forbid();
        var result = _app.SelectModel<ResultSet>("Procs_InsertUpdateDeleteLeaveRequest", new { row.LeaveRequestID, row.EmployeeID, row.LeaveTypeID, row.FromDate, row.ToDate, row.NumberOfDays, row.Reason, Status = "Cancelled", row.ApprovedBy, row.ApprovedDate, row.Remarks, Mode = 2 });
        TempData[result?.StatusCode == 200 ? "Success" : "Error"] = result?.Message ?? "Leave request could not be cancelled.";
        return RedirectToAction(nameof(Leave));
    }

    [HttpGet]
    public IActionResult Tasks(string? status, string? priority)
    {
        var employee = User.IsInRole("Employee") ? CurrentEmployeeId : (int?)null;
        var assignedBy = User.IsInRole("Manager") ? CurrentEmployeeId : (int?)null;
        var rows = _app.SelectModelList<TaskModel>("Procs_GetTasks", new { EmployeeID = employee, AssignedBy = assignedBy, Status = status, Priority = priority, FromDate = (DateTime?)null, ToDate = (DateTime?)null }) ?? new();
        if (User.IsInRole("Manager")) rows = rows.Where(x => IsTeamMember(x.EmployeeID)).ToList();
        return View(rows);
    }

    [HttpGet]
    public IActionResult TaskCreate() { if (!IsAdminOrHr && !User.IsInRole("Manager")) return Forbid(); ViewBag.Employees = Employees(); return View(new TaskModel { StartDate = DateTime.Today, DueDate = DateTime.Today, Priority = "Medium", Status = "Pending" }); }

    [HttpPost, ValidateAntiForgeryToken]
    public IActionResult TaskCreate(TaskModel request)
    {
        if (!IsAdminOrHr && !User.IsInRole("Manager")) return Forbid();
        if (CurrentEmployeeId <= 0) return Forbid();
        if (User.IsInRole("Manager") && !IsTeamMember(request.EmployeeID)) return Forbid();
        if (string.IsNullOrWhiteSpace(request.TaskTitle)) ModelState.AddModelError(nameof(request.TaskTitle), "Task title is required.");
        if (request.DueDate < (request.StartDate ?? DateTime.Today)) ModelState.AddModelError(nameof(request.DueDate), "Due date cannot be before start date.");
        if (!ModelState.IsValid) { ViewBag.Employees = Employees(); return View(request); }
        var result = _app.SelectModel<ResultSet>("Procs_InsertUpdateDeleteTask", new { TaskID = 0, request.EmployeeID, AssignedBy = CurrentEmployeeId, request.TaskTitle, request.TaskDescription, request.Priority, Status = "Pending", request.StartDate, request.DueDate, request.CompletedDate, Mode = 1 });
        TempData[result?.StatusCode == 200 ? "Success" : "Error"] = result?.Message ?? "Task could not be saved."; return RedirectToAction(nameof(Tasks));
    }

    [HttpPost, ValidateAntiForgeryToken]
    public IActionResult TaskStatus(int id, string status)
    {
        if (!new[] { "Pending", "In Progress", "Completed", "Cancelled" }.Contains(status)) return BadRequest();
        var row = (_app.SelectModelList<TaskModel>("Procs_GetTasks", new { EmployeeID = (int?)null, AssignedBy = (int?)null, Status = (string?)null, Priority = (string?)null, FromDate = (DateTime?)null, ToDate = (DateTime?)null }) ?? new()).FirstOrDefault(x => x.TaskID == id);
        if (row == null || (!IsAdminOrHr && row.EmployeeID != CurrentEmployeeId && !(User.IsInRole("Manager") && IsTeamMember(row.EmployeeID)))) return Forbid();
        var result = _app.SelectModel<ResultSet>("Procs_InsertUpdateDeleteTask", new { row.TaskID, row.EmployeeID, AssignedBy = row.AssignedBy, row.TaskTitle, row.TaskDescription, row.Priority, Status = status, row.StartDate, row.DueDate, CompletedDate = status == "Completed" ? DateTime.Today : row.CompletedDate, Mode = 2 });
        TempData[result?.StatusCode == 200 ? "Success" : "Error"] = result?.Message ?? "Task status could not be updated."; return RedirectToAction(nameof(Tasks));
    }

    [HttpGet]
    public IActionResult Announcements(bool? active = true, string? search = null)
    {
        var rows = _app.SelectModelList<AnnouncementModel>("Procs_GetAnnouncements", new { AnnouncementID = (int?)null, IsActive = active, FromDate = (DateTime?)null, ToDate = (DateTime?)null, Search = search }) ?? new();
        ViewBag.CanManage = IsAdminOrHr; return View(rows);
    }

    [HttpGet, Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult AnnouncementCreate() => View(new AnnouncementModel { PublishDate = DateTime.Today, IsActive = true });

    [HttpPost, ValidateAntiForgeryToken, Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult AnnouncementCreate(AnnouncementModel request)
    {
        if (CurrentEmployeeId <= 0) { ModelState.AddModelError(string.Empty, "Your account is not linked to an employee profile."); }
        if (string.IsNullOrWhiteSpace(request.Title)) ModelState.AddModelError(nameof(request.Title), "Title is required.");
        if (!ModelState.IsValid) return View(request);
        var result = _app.SelectModel<ResultSet>("Procs_InsertUpdateDeleteAnnouncement", new { AnnouncementID = 0, request.Title, request.Description, request.PublishDate, request.ExpiryDate, CreatedBy = CurrentEmployeeId, request.IsActive, Mode = 1 });
        TempData[result?.StatusCode == 200 ? "Success" : "Error"] = result?.Message ?? "Announcement could not be saved."; return RedirectToAction(nameof(Announcements));
    }

    [HttpPost, ValidateAntiForgeryToken, Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult AnnouncementToggle(int id)
    {
        if (CurrentEmployeeId <= 0)
        {
            TempData["Error"] = "Your account must be linked to an employee profile to manage announcements.";
            return RedirectToAction(nameof(Announcements));
        }
        var row = (_app.SelectModelList<AnnouncementModel>("Procs_GetAnnouncements", new { AnnouncementID = id, IsActive = (bool?)null, FromDate = (DateTime?)null, ToDate = (DateTime?)null, Search = (string?)null }) ?? new()).FirstOrDefault();
        if (row == null) { TempData["Error"] = "Announcement not found."; return RedirectToAction(nameof(Announcements)); }
        var result = _app.SelectModel<ResultSet>("Procs_InsertUpdateDeleteAnnouncement", new { AnnouncementID = row.AnnouncementID, row.Title, row.Description, row.PublishDate, row.ExpiryDate, CreatedBy = CurrentEmployeeId, IsActive = !row.IsActive, Mode = 2 });
        TempData[result?.StatusCode == 200 ? "Success" : "Error"] = result?.Message ?? "Announcement status could not be changed.";
        return RedirectToAction(nameof(Announcements));
    }

    [HttpGet, Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult AnnouncementEdit(int id)
    {
        var row = (_app.SelectModelList<AnnouncementModel>("Procs_GetAnnouncements", new { AnnouncementID = id, IsActive = (bool?)null, FromDate = (DateTime?)null, ToDate = (DateTime?)null, Search = (string?)null }) ?? new()).FirstOrDefault();
        return row == null ? NotFound() : View(row);
    }

    [HttpPost, ValidateAntiForgeryToken, Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult AnnouncementEdit(AnnouncementModel request)
    {
        if (CurrentEmployeeId <= 0) ModelState.AddModelError(string.Empty, "Your account must be linked to an employee profile.");
        if (string.IsNullOrWhiteSpace(request.Title)) ModelState.AddModelError(nameof(request.Title), "Title is required.");
        if (!ModelState.IsValid) return View(request);
        var result = _app.SelectModel<ResultSet>("Procs_InsertUpdateDeleteAnnouncement", new { request.AnnouncementID, request.Title, request.Description, request.PublishDate, request.ExpiryDate, CreatedBy = CurrentEmployeeId, request.IsActive, Mode = 2 });
        TempData[result?.StatusCode == 200 ? "Success" : "Error"] = result?.Message ?? "Announcement could not be updated.";
        return RedirectToAction(nameof(Announcements));
    }
}
