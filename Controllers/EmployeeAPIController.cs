using AdminPannel.Logic;
using AdminPannel.Models;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace AdminPannel.Controllers
{
    // Web API for the EMPLOYEE self-service app (the separate React app people log into).
    // Everyone in the company is an employee, so ANY logged-in user — including HR,
    // Manager and Admin — uses this app to view/edit THEIR OWN profile. The admin-only
    // work (managing OTHER employees: list/create/update/delete) stays in the MVC admin
    // panel and is deliberately NOT exposed here.
    //   * GET  api/EmployeeAPI/me  -> read the caller's OWN profile
    //   * PUT  api/EmployeeAPI/me  -> update the caller's OWN limited fields
    //
    // The caller's identity is taken from the JWT "CustId" claim (= EmployeeID, set by
    // TokenService at login) — NEVER from a route or request-body value — so a caller can
    // only ever read or edit their own record, whatever their role.
    //
    // Data access mirrors the tested EmployeeController: Dapper via AppData, the same
    // stored procedures, and the same parameter shapes (see ToProcParams / ToRequest).
    [Route("api/[controller]")]
    [ApiController]
    // Any authenticated user (valid JWT) may use these self-service endpoints — HR,
    // Manager and Admin are employees too, so they view/edit their OWN profile here just
    // like anyone else. This intentionally differs from EmployeeController.EditSelf (which
    // is Employee-only) because that lives in the admin panel; this separate app is a
    // shared self-service portal. Security still holds: the record is chosen by the token's
    // CustId claim, so every caller only ever touches their own data.
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    public class EmployeeAPIController : ControllerBase
    {
        private readonly AppData _appData;

        // AppData is injected (registered Scoped in Program.cs), same as AuthAPIController.
        public EmployeeAPIController(AppData appData)
        {
            _appData = appData;
        }

        #region Profile (self-service)

        // GET api/EmployeeAPI/me
        // Returns the logged-in employee's own profile. The id comes from the token,
        // so there is no way to request someone else's record.
        [HttpGet("me")]
        public IActionResult GetMe()
        {
            if (!TryGetCurrentEmployeeId(out var employeeId))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            try
            {
                var employee = GetOwnEmployee(employeeId);
                if (employee is null)
                    return NotFound(new { statusCode = 404, message = "Your employee record was not found." });

                return Ok(new { statusCode = 200, message = "OK", data = employee });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        // PUT api/EmployeeAPI/me
        // Employee updates ONLY their own self-service fields. Mirrors
        // EmployeeController.EditSelf: fetch the current row, overwrite only the 8 allowed
        // fields, then send Mode = 2. Everything else (EmployeeCode, RoleID, BasicSalary,
        // DepartmentID, ...) is preserved exactly and cannot be changed from here.
        [HttpPut("me")]
        public IActionResult UpdateMe([FromBody] EmployeeSelfServiceRequest request)
        {
            if (request is null)
                return BadRequest(new { statusCode = 400, message = "Request body is required." });

            if (!TryGetCurrentEmployeeId(out var employeeId))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            // Same validation rules as EmployeeController.ValidateSelfServiceRequest,
            // returned as data (API style) instead of MVC ModelState.
            var errors = ValidateSelfService(request);
            if (errors.Count > 0)
                return BadRequest(new { statusCode = 400, message = "Validation failed.", errors });

            try
            {
                var existing = GetOwnEmployee(employeeId);
                if (existing is null)
                    return NotFound(new { statusCode = 404, message = "Your employee record was not found." });

                // Start from the existing row so nothing else is touched, then overwrite
                // ONLY the self-service fields — identical to EditSelf's "merged" object.
                var merged = ToRequest(existing);
                merged.Email = request.Email;
                merged.PhoneNumber = request.PhoneNumber;
                merged.EmergencyContact = request.EmergencyContact;
                merged.Address = request.Address;
                merged.City = request.City;
                merged.State = request.State;
                merged.Country = request.Country;
                merged.PostalCode = request.PostalCode;

                var result = _appData.SelectModel<EmployeeResponse>(
                    "Procs_InsertUpdateDeleteEmployee",
                    ToProcParams(merged, mode: 2));

                if (result is null)
                    return StatusCode(500, new { statusCode = 500, message = "No response from database." });

                if (result.StatusCode != 200)
                    return StatusCode(result.StatusCode, new { statusCode = result.StatusCode, message = result.Message });

                var updated = GetOwnEmployee(employeeId);
                return Ok(new { statusCode = 200, message = result.Message ?? "Profile updated.", data = updated });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        #endregion

        #region Leave (self-service)

        // The caller can list their OWN leave requests, read the leave types available
        // when applying, file a new request, and cancel a still-Pending one. Every read
        // and write is scoped to the token's CustId, so a caller can never see or touch
        // another employee's leave. Mirrors OperationsController's leave actions, but the
        // employee id comes from the JWT (CustId) instead of the cookie's EmployeeID claim.

        // GET api/EmployeeAPI/me/leaves?status=&fromDate=&toDate=
        // Lists the caller's own leave requests (optional status / date-range filters).
        // EmployeeID is the token's CustId — never a query value — so only the caller's
        // rows are returned.
        [HttpGet("me/leaves")]
        public IActionResult GetMyLeaves(string? status, DateTime? fromDate, DateTime? toDate)
        {
            if (!TryGetCurrentEmployeeId(out var employeeId))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            // Surface the proc's own date rule as a proper 400 instead of a junk row.
            if (fromDate.HasValue && toDate.HasValue && fromDate.Value.Date > toDate.Value.Date)
                return BadRequest(new { statusCode = 400, message = "FromDate cannot be greater than ToDate." });

            try
            {
                var rows = _appData.SelectModelList<LeaveRequestModel>(
                    "Procs_GetLeaveRequests",
                    new
                    {
                        EmployeeID = (int?)employeeId,
                        Status = status,
                        FromDate = fromDate,
                        ToDate = toDate
                    }) ?? new List<LeaveRequestModel>();

                return Ok(new { statusCode = 200, message = "OK", data = rows });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        // GET api/EmployeeAPI/me/leave-types
        // Active leave types, so the client can populate the "apply for leave" dropdown.
        // Read-only reference data (the same list OperationsController.LeaveCreate loads).
        [HttpGet("me/leave-types")]
        public IActionResult GetLeaveTypes()
        {
            if (!TryGetCurrentEmployeeId(out _))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            try
            {
                var types = _appData.SelectModelList<LeaveTypeResponse>(
                    "Procs_GetLeaveType",
                    new { LeaveTypeID = (int?)null, IsActive = true, Search = (string?)null })
                    ?? new List<LeaveTypeResponse>();

                return Ok(new { statusCode = 200, message = "OK", data = types });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        // POST api/EmployeeAPI/me/leaves
        // Files a new leave request FOR THE CALLER. The server sets EmployeeID (from the
        // token), Status = "Pending", ApprovedBy = null and NumberOfDays (inclusive day
        // count) — the body cannot set any of those. Same validation + proc call as
        // OperationsController.LeaveCreate.
        [HttpPost("me/leaves")]
        public IActionResult ApplyLeave([FromBody] LeaveApplyRequest request)
        {
            if (request is null)
                return BadRequest(new { statusCode = 400, message = "Request body is required." });

            if (!TryGetCurrentEmployeeId(out var employeeId))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            var errors = new Dictionary<string, string>();
            if (request.LeaveTypeID <= 0) errors["LeaveTypeID"] = "Leave type is required.";
            if (request.FromDate.Date > request.ToDate.Date) errors["ToDate"] = "To date cannot be before from date.";
            if (string.IsNullOrWhiteSpace(request.Reason)) errors["Reason"] = "Reason is required.";
            if (errors.Count > 0)
                return BadRequest(new { statusCode = 400, message = "Validation failed.", errors });

            try
            {
                // Inclusive day count, identical to the MVC calculation.
                var numberOfDays = (decimal)(request.ToDate.Date - request.FromDate.Date).TotalDays + 1;

                var result = _appData.SelectModel<ResultSet>(
                    "Procs_InsertUpdateDeleteLeaveRequest",
                    new
                    {
                        LeaveRequestID = 0,
                        EmployeeID = employeeId,
                        request.LeaveTypeID,
                        request.FromDate,
                        request.ToDate,
                        NumberOfDays = numberOfDays,
                        request.Reason,
                        Status = "Pending",
                        ApprovedBy = (int?)null,
                        ApprovedDate = (DateTime?)null,
                        request.Remarks,
                        Mode = 1
                    });

                if (result is null)
                    return StatusCode(500, new { statusCode = 500, message = "No response from database." });
                if (result.StatusCode != 200)
                    return StatusCode(result.StatusCode, new { statusCode = result.StatusCode, message = result.Message });

                return StatusCode(201, new { statusCode = 201, message = result.Message ?? "Leave request submitted." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        // POST api/EmployeeAPI/me/leaves/{id}/cancel
        // Cancels one of the caller's OWN still-Pending leave requests. The row is fetched
        // scoped to the caller's EmployeeID and re-checked for ownership + Pending status
        // before the update (Mode = 2, Status = "Cancelled") — the same guard as
        // OperationsController.LeaveCancel. A caller cannot cancel anyone else's leave, nor
        // one already Approved / Rejected / Cancelled.
        [HttpPost("me/leaves/{id:int}/cancel")]
        public IActionResult CancelLeave(int id)
        {
            if (!TryGetCurrentEmployeeId(out var employeeId))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            try
            {
                var row = (_appData.SelectModelList<LeaveRequestModel>(
                    "Procs_GetLeaveRequests",
                    new
                    {
                        EmployeeID = (int?)employeeId,
                        Status = (string?)null,
                        FromDate = (DateTime?)null,
                        ToDate = (DateTime?)null
                    }) ?? new List<LeaveRequestModel>())
                    .FirstOrDefault(x => x.LeaveRequestID == id);

                // Ownership double-check: the fetch was already scoped to the caller, but we
                // re-assert EmployeeID == caller so this can never touch someone else's row.
                if (row is null || row.EmployeeID != employeeId)
                    return NotFound(new { statusCode = 404, message = "Leave request not found." });
                if (row.Status != "Pending")
                    return BadRequest(new { statusCode = 400, message = "Only a pending leave request can be cancelled." });

                var result = _appData.SelectModel<ResultSet>(
                    "Procs_InsertUpdateDeleteLeaveRequest",
                    new
                    {
                        row.LeaveRequestID,
                        row.EmployeeID,
                        row.LeaveTypeID,
                        row.FromDate,
                        row.ToDate,
                        row.NumberOfDays,
                        row.Reason,
                        Status = "Cancelled",
                        row.ApprovedBy,
                        row.ApprovedDate,
                        row.Remarks,
                        Mode = 2
                    });

                if (result is null)
                    return StatusCode(500, new { statusCode = 500, message = "No response from database." });
                if (result.StatusCode != 200)
                    return StatusCode(result.StatusCode, new { statusCode = result.StatusCode, message = result.Message });

                return Ok(new { statusCode = 200, message = result.Message ?? "Leave request cancelled." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        #endregion

        #region Attendance (self-service)

        // GET api/EmployeeAPI/me/attendance?fromDate=&toDate=&status=
        // Lists the caller's OWN attendance rows (optional date-range / status filters).
        // EmployeeID is the token's CustId, so only the caller's records are returned.
        [HttpGet("me/attendance")]
        public IActionResult GetMyAttendance(DateTime? fromDate, DateTime? toDate, string? status)
        {
            if (!TryGetCurrentEmployeeId(out var employeeId))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            if (fromDate.HasValue && toDate.HasValue && fromDate.Value.Date > toDate.Value.Date)
                return BadRequest(new { statusCode = 400, message = "FromDate cannot be greater than ToDate." });

            try
            {
                var rows = _appData.SelectModelList<AttendanceModel>(
                    "Procs_GetAttendance",
                    new
                    {
                        AttendanceID = (int?)null,
                        EmployeeID = (int?)employeeId,
                        FromDate = fromDate,
                        ToDate = toDate,
                        Status = status
                    }) ?? new List<AttendanceModel>();

                return Ok(new { statusCode = 200, message = "OK", data = rows });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        // POST api/EmployeeAPI/me/attendance
        // Marks attendance FOR THE CALLER (Mode = 1 / Insert). EmployeeID comes from the
        // token, never the body. Status is validated against the same allowed set used by
        // OperationsController.AttendanceCreate.
        [HttpPost("me/attendance")]
        public IActionResult MarkAttendance([FromBody] AttendanceMarkRequest request)
        {
            if (request is null)
                return BadRequest(new { statusCode = 400, message = "Request body is required." });

            if (!TryGetCurrentEmployeeId(out var employeeId))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            var validStatuses = new[] { "Present", "Absent", "Leave", "Half Day", "Work From Home" };
            var errors = new Dictionary<string, string>();
            if (request.AttendanceDate == default)
                errors["AttendanceDate"] = "Attendance date is required.";
            if (string.IsNullOrWhiteSpace(request.Status) ||
                !validStatuses.Contains(request.Status, StringComparer.OrdinalIgnoreCase))
                errors["Status"] = "Select a valid attendance status.";
            if (errors.Count > 0)
                return BadRequest(new { statusCode = 400, message = "Validation failed.", errors });

            try
            {
                var result = _appData.SelectModel<ResultSet>(
                    "Procs_InsertUpdateDeleteAttendance",
                    new
                    {
                        AttendanceID = 0,
                        EmployeeID = employeeId,
                        request.AttendanceDate,
                        request.CheckInTime,
                        request.CheckOutTime,
                        request.WorkingHours,
                        request.OvertimeHours,
                        request.Status,
                        request.Remarks,
                        request.ShiftID,
                        Mode = 1
                    });

                if (result is null)
                    return StatusCode(500, new { statusCode = 500, message = "No response from database." });
                if (result.StatusCode != 200)
                    return StatusCode(result.StatusCode, new { statusCode = result.StatusCode, message = result.Message });

                return StatusCode(201, new { statusCode = 201, message = result.Message ?? "Attendance marked." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        #endregion

        #region Payslips (self-service, read-only)

        // GET api/EmployeeAPI/me/payslips?fromMonth=&fromYear=&toMonth=&toYear=&paymentStatus=
        // The caller's OWN payroll history. EmployeeID is the token's CustId, so a caller
        // can only ever see their own payslips. Read-only — the API never generates or edits
        // payroll (that stays in the admin panel).
        [HttpGet("me/payslips")]
        public IActionResult GetMyPayslips(byte? fromMonth, short? fromYear, byte? toMonth, short? toYear, string? paymentStatus)
        {
            if (!TryGetCurrentEmployeeId(out var employeeId))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            try
            {
                var rows = _appData.SelectModelList<PayrollModel>(
                    "Procs_GetEmployeePayrollHistory",
                    new
                    {
                        EmployeeID = employeeId,
                        FromMonth = fromMonth,
                        FromYear = fromYear,
                        ToMonth = toMonth,
                        ToYear = toYear,
                        PaymentStatus = paymentStatus
                    }) ?? new List<PayrollModel>();

                return Ok(new { statusCode = 200, message = "OK", data = rows });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        // GET api/EmployeeAPI/me/payslips/{id}
        // One salary slip by id — scoped to the caller. We pass BOTH PayrollID and the
        // token's EmployeeID to Procs_GetSalarySlip, so a payroll belonging to someone else
        // returns no row: ownership is enforced in the query itself, then re-checked here.
        [HttpGet("me/payslips/{id:int}")]
        public IActionResult GetMyPayslip(int id)
        {
            if (!TryGetCurrentEmployeeId(out var employeeId))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            try
            {
                var slip = _appData.SelectModel<SalarySlipModel>(
                    "Procs_GetSalarySlip",
                    new
                    {
                        PayrollID = (int?)id,
                        EmployeeID = (int?)employeeId,
                        PayrollMonth = (byte?)null,
                        PayrollYear = (short?)null
                    });

                // Null = no such payroll; EmployeeID mismatch = the id belongs to someone
                // else (proc returned a validation row). Either way, it's not the caller's.
                if (slip is null || slip.EmployeeID != employeeId)
                    return NotFound(new { statusCode = 404, message = "Payslip not found." });

                return Ok(new { statusCode = 200, message = "OK", data = slip });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        #endregion

        #region Tasks (self-service)

        // The caller can list the tasks assigned to them and move a task through its
        // status lifecycle (Pending -> In Progress -> Completed / Cancelled). Both actions
        // are scoped to the token's CustId, so a caller can never see or update a task that
        // belongs to someone else. Assigning/creating tasks is a manager/HR action and is
        // NOT here — this region is purely the employee's own to-do list.

        // GET api/EmployeeAPI/me/tasks?status=&priority=&fromDate=&toDate=
        // Lists the tasks assigned TO THE CALLER (optional status / priority / due-date
        // range filters). EmployeeID is the token's CustId, so only the caller's own tasks
        // come back — never a teammate's. Mirrors the employee view of
        // OperationsController.Tasks.
        [HttpGet("me/tasks")]
        public IActionResult GetMyTasks(string? status, string? priority, DateTime? fromDate, DateTime? toDate)
        {
            if (!TryGetCurrentEmployeeId(out var employeeId))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            // Surface the proc's own date rule as a proper 400 instead of a junk row.
            if (fromDate.HasValue && toDate.HasValue && fromDate.Value.Date > toDate.Value.Date)
                return BadRequest(new { statusCode = 400, message = "FromDate cannot be greater than ToDate." });

            try
            {
                var rows = _appData.SelectModelList<TaskModel>(
                    "Procs_GetTasks",
                    new
                    {
                        EmployeeID = (int?)employeeId,
                        AssignedBy = (int?)null,
                        Status = status,
                        Priority = priority,
                        FromDate = fromDate,
                        ToDate = toDate
                    }) ?? new List<TaskModel>();

                return Ok(new { statusCode = 200, message = "OK", data = rows });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        // PUT api/EmployeeAPI/me/tasks/{id}/status
        // Updates the status of ONE of the caller's OWN tasks. Procs_InsertUpdateDeleteTask
        // has no partial update — Mode = 2 rewrites the whole row — so we first fetch the
        // task scoped to the caller (EmployeeID = CustId), re-assert ownership, then resend
        // every existing field unchanged with only Status (and CompletedDate) updated.
        // Mirrors OperationsController.TaskStatus, but locked to the caller's own row: an
        // employee can move their task's status but cannot reassign, retitle, or edit a
        // teammate's task.
        [HttpPut("me/tasks/{id:int}/status")]
        public IActionResult UpdateMyTaskStatus(int id, [FromBody] TaskStatusUpdateRequest request)
        {
            if (request is null)
                return BadRequest(new { statusCode = 400, message = "Request body is required." });

            if (!TryGetCurrentEmployeeId(out var employeeId))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            var validStatuses = new[] { "Pending", "In Progress", "Completed", "Cancelled" };
            if (string.IsNullOrWhiteSpace(request.Status) ||
                !validStatuses.Contains(request.Status, StringComparer.OrdinalIgnoreCase))
                return BadRequest(new { statusCode = 400, message = "Select a valid task status (Pending, In Progress, Completed, Cancelled)." });

            try
            {
                // Fetch scoped to the caller so only the caller's own tasks are ever visible.
                var row = (_appData.SelectModelList<TaskModel>(
                    "Procs_GetTasks",
                    new
                    {
                        EmployeeID = (int?)employeeId,
                        AssignedBy = (int?)null,
                        Status = (string?)null,
                        Priority = (string?)null,
                        FromDate = (DateTime?)null,
                        ToDate = (DateTime?)null
                    }) ?? new List<TaskModel>())
                    .FirstOrDefault(x => x.TaskID == id);

                // Ownership double-check: the fetch was already scoped to the caller, but we
                // re-assert EmployeeID == caller so this can never touch someone else's task.
                if (row is null || row.EmployeeID != employeeId)
                    return NotFound(new { statusCode = 404, message = "Task not found." });

                // Normalise to the canonical casing from the allowed set before saving.
                var newStatus = validStatuses.First(s => s.Equals(request.Status, StringComparison.OrdinalIgnoreCase));

                var result = _appData.SelectModel<ResultSet>(
                    "Procs_InsertUpdateDeleteTask",
                    new
                    {
                        row.TaskID,
                        row.EmployeeID,
                        row.AssignedBy,
                        row.TaskTitle,
                        row.TaskDescription,
                        row.Priority,
                        Status = newStatus,
                        row.StartDate,
                        row.DueDate,
                        // Stamp the completion date when moving to Completed; otherwise keep
                        // whatever was already there (mirrors OperationsController.TaskStatus).
                        CompletedDate = newStatus == "Completed" ? DateTime.Today : row.CompletedDate,
                        Mode = 2
                    });

                if (result is null)
                    return StatusCode(500, new { statusCode = 500, message = "No response from database." });
                if (result.StatusCode != 200)
                    return StatusCode(result.StatusCode, new { statusCode = result.StatusCode, message = result.Message });

                return Ok(new { statusCode = 200, message = result.Message ?? "Task status updated." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        #endregion

        #region Leave (team / all — approval & oversight)

        // Manager / HR / Admin oversight of leave. These are the "someone else's leave"
        // counterparts to the self-service me/leaves endpoints above. Scope:
        //   Manager  -> direct reports only (IsTeamMember)
        //   HR/Admin -> the whole organization
        //   Employee -> not applicable here (they use GET me/leaves) -> 403
        // The employee id is never taken from the caller; it comes from each leave row, and
        // a Manager is checked against their team before they can view or decide it.

        // GET api/EmployeeAPI/leaves?employeeId=&status=&fromDate=&toDate=
        // Lists leave requests the caller is allowed to oversee. HR/Admin may optionally
        // filter by employeeId; a Manager always sees only their team (the filter is applied
        // in memory after the fetch, exactly like OperationsController.Leave).
        [HttpGet("leaves")]
        public IActionResult GetLeaves(int? employeeId, string? status, DateTime? fromDate, DateTime? toDate)
        {
            if (!TryGetCurrentEmployeeId(out _))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            // Employees have no team to oversee — self-service lives at GET me/leaves.
            if (!IsAdminOrHr && !User.IsInRole("Manager"))
                return StatusCode(403, new { statusCode = 403, message = "Only a manager, HR or admin can view team leave requests. Use me/leaves for your own." });

            if (fromDate.HasValue && toDate.HasValue && fromDate.Value.Date > toDate.Value.Date)
                return BadRequest(new { statusCode = 400, message = "FromDate cannot be greater than ToDate." });

            try
            {
                // HR/Admin: optional employeeId filter. Manager: fetch all, then narrow to team.
                var requested = IsAdminOrHr ? employeeId : (int?)null;

                var rows = _appData.SelectModelList<LeaveRequestModel>(
                    "Procs_GetLeaveRequests",
                    new
                    {
                        EmployeeID = requested,
                        Status = status,
                        FromDate = fromDate,
                        ToDate = toDate
                    }) ?? new List<LeaveRequestModel>();

                if (!IsAdminOrHr && User.IsInRole("Manager"))
                    rows = rows.Where(x => IsTeamMember(x.EmployeeID)).ToList();

                return Ok(new { statusCode = 200, message = "OK", data = rows });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        // POST api/EmployeeAPI/leaves/{id}/decision   body: { "decision": "Approved" | "Rejected" }
        // Approves or rejects ONE pending leave request. Guards, in order: caller must be
        // Manager/HR/Admin; the request must exist; a Manager may only decide for their own
        // team (HR/Admin for anyone); the request must still be Pending; the decision must be
        // exactly Approved or Rejected. On success the server stamps ApprovedBy = caller's
        // CustId and ApprovedDate = now (Mode = 2, full-row rewrite like the cancel path).
        // Same rule set as OperationsController.LeaveDecision, but with granular API codes
        // (404 / 403 / 400) instead of a single Forbid.
        [HttpPost("leaves/{id:int}/decision")]
        public IActionResult DecideLeave(int id, [FromBody] LeaveDecisionRequest request)
        {
            if (request is null)
                return BadRequest(new { statusCode = 400, message = "Request body is required." });

            if (!TryGetCurrentEmployeeId(out var callerId))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            if (!IsAdminOrHr && !User.IsInRole("Manager"))
                return StatusCode(403, new { statusCode = 403, message = "Only a manager, HR or admin can decide leave requests." });

            var validDecisions = new[] { "Approved", "Rejected" };
            if (string.IsNullOrWhiteSpace(request.Decision) ||
                !validDecisions.Contains(request.Decision, StringComparer.OrdinalIgnoreCase))
                return BadRequest(new { statusCode = 400, message = "Decision must be either 'Approved' or 'Rejected'." });

            try
            {
                // Fetch org-wide, then locate the row; team/ownership is enforced next.
                var row = (_appData.SelectModelList<LeaveRequestModel>(
                    "Procs_GetLeaveRequests",
                    new
                    {
                        EmployeeID = (int?)null,
                        Status = (string?)null,
                        FromDate = (DateTime?)null,
                        ToDate = (DateTime?)null
                    }) ?? new List<LeaveRequestModel>())
                    .FirstOrDefault(x => x.LeaveRequestID == id);

                if (row is null)
                    return NotFound(new { statusCode = 404, message = "Leave request not found." });

                // A Manager may only act on their own team; HR/Admin may act on anyone.
                if (!IsAdminOrHr && !IsTeamMember(row.EmployeeID))
                    return StatusCode(403, new { statusCode = 403, message = "You can only decide leave requests for your own team." });

                if (row.Status != "Pending")
                    return BadRequest(new { statusCode = 400, message = "Only a pending leave request can be decided." });

                var decision = validDecisions.First(d => d.Equals(request.Decision, StringComparison.OrdinalIgnoreCase));

                var result = _appData.SelectModel<ResultSet>(
                    "Procs_InsertUpdateDeleteLeaveRequest",
                    new
                    {
                        row.LeaveRequestID,
                        row.EmployeeID,
                        row.LeaveTypeID,
                        row.FromDate,
                        row.ToDate,
                        row.NumberOfDays,
                        row.Reason,
                        Status = decision,
                        ApprovedBy = callerId,
                        ApprovedDate = DateTime.Now,
                        row.Remarks,
                        Mode = 2
                    });

                if (result is null)
                    return StatusCode(500, new { statusCode = 500, message = "No response from database." });
                if (result.StatusCode != 200)
                    return StatusCode(result.StatusCode, new { statusCode = result.StatusCode, message = result.Message });

                return Ok(new { statusCode = 200, message = result.Message ?? $"Leave request {decision.ToLower()}." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        #endregion

        #region Attendance (team / all — oversight)

        // Manager / HR / Admin counterparts to the self-service me/attendance endpoints.
        // Scope: Manager -> team, HR/Admin -> organization, Employee -> 403 (use me/*).

        // GET api/EmployeeAPI/attendance?employeeId=&fromDate=&toDate=&status=
        // Lists attendance for the people the caller oversees. HR/Admin may filter by
        // employeeId; a Manager always sees only their team. Mirrors OperationsController.Attendance.
        [HttpGet("attendance")]
        public IActionResult GetAttendance(int? employeeId, DateTime? fromDate, DateTime? toDate, string? status)
        {
            if (!TryGetCurrentEmployeeId(out _))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            if (!IsAdminOrHr && !User.IsInRole("Manager"))
                return StatusCode(403, new { statusCode = 403, message = "Only a manager, HR or admin can view team attendance. Use me/attendance for your own." });

            if (fromDate.HasValue && toDate.HasValue && fromDate.Value.Date > toDate.Value.Date)
                return BadRequest(new { statusCode = 400, message = "FromDate cannot be greater than ToDate." });

            try
            {
                var requested = IsAdminOrHr ? employeeId : (int?)null;

                var rows = _appData.SelectModelList<AttendanceModel>(
                    "Procs_GetAttendance",
                    new
                    {
                        AttendanceID = (int?)null,
                        EmployeeID = requested,
                        FromDate = fromDate,
                        ToDate = toDate,
                        Status = status
                    }) ?? new List<AttendanceModel>();

                if (!IsAdminOrHr && User.IsInRole("Manager"))
                    rows = rows.Where(x => IsTeamMember(x.EmployeeID)).ToList();

                return Ok(new { statusCode = 200, message = "OK", data = rows });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        // POST api/EmployeeAPI/attendance
        // Marks attendance FOR ANOTHER employee (Mode = 1). The body carries the target
        // EmployeeID, which is validated with CanManageEmployee — a Manager may only mark
        // their own team, HR/Admin anyone. Employees use POST me/attendance for themselves.
        [HttpPost("attendance")]
        public IActionResult MarkAttendanceFor([FromBody] AttendanceForEmployeeRequest request)
        {
            if (request is null)
                return BadRequest(new { statusCode = 400, message = "Request body is required." });

            if (!TryGetCurrentEmployeeId(out _))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            if (!IsAdminOrHr && !User.IsInRole("Manager"))
                return StatusCode(403, new { statusCode = 403, message = "Only a manager, HR or admin can mark attendance for others. Use me/attendance for yourself." });

            if (request.EmployeeID <= 0)
                return BadRequest(new { statusCode = 400, message = "EmployeeID is required." });

            // The body-supplied target is never trusted on its own.
            if (!CanManageEmployee(request.EmployeeID))
                return StatusCode(403, new { statusCode = 403, message = "You can only mark attendance for your own team." });

            var validStatuses = new[] { "Present", "Absent", "Leave", "Half Day", "Work From Home" };
            var errors = new Dictionary<string, string>();
            if (request.AttendanceDate == default)
                errors["AttendanceDate"] = "Attendance date is required.";
            if (string.IsNullOrWhiteSpace(request.Status) ||
                !validStatuses.Contains(request.Status, StringComparer.OrdinalIgnoreCase))
                errors["Status"] = "Select a valid attendance status.";
            if (errors.Count > 0)
                return BadRequest(new { statusCode = 400, message = "Validation failed.", errors });

            try
            {
                var result = _appData.SelectModel<ResultSet>(
                    "Procs_InsertUpdateDeleteAttendance",
                    new
                    {
                        AttendanceID = 0,
                        EmployeeID = request.EmployeeID,
                        request.AttendanceDate,
                        request.CheckInTime,
                        request.CheckOutTime,
                        request.WorkingHours,
                        request.OvertimeHours,
                        request.Status,
                        request.Remarks,
                        request.ShiftID,
                        Mode = 1
                    });

                if (result is null)
                    return StatusCode(500, new { statusCode = 500, message = "No response from database." });
                if (result.StatusCode != 200)
                    return StatusCode(result.StatusCode, new { statusCode = result.StatusCode, message = result.Message });

                return StatusCode(201, new { statusCode = 201, message = result.Message ?? "Attendance marked." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        #endregion

        #region Tasks (team / all — assignment & oversight)

        // Manager / HR / Admin counterparts to the self-service me/tasks endpoints. Scope:
        // Manager -> team, HR/Admin -> organization, Employee -> 403 (use me/tasks).

        // GET api/EmployeeAPI/tasks?employeeId=&status=&priority=&fromDate=&toDate=
        // Lists tasks the caller oversees. HR/Admin see all (optional employeeId filter);
        // a Manager sees tasks THEY assigned, narrowed to their current team. Mirrors
        // OperationsController.Tasks (minus the employee-self branch, which is me/tasks).
        [HttpGet("tasks")]
        public IActionResult GetTasks(int? employeeId, string? status, string? priority, DateTime? fromDate, DateTime? toDate)
        {
            if (!TryGetCurrentEmployeeId(out var callerId))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            if (!IsAdminOrHr && !User.IsInRole("Manager"))
                return StatusCode(403, new { statusCode = 403, message = "Only a manager, HR or admin can view team tasks. Use me/tasks for your own." });

            if (fromDate.HasValue && toDate.HasValue && fromDate.Value.Date > toDate.Value.Date)
                return BadRequest(new { statusCode = 400, message = "FromDate cannot be greater than ToDate." });

            try
            {
                var requestedEmployee = IsAdminOrHr ? employeeId : (int?)null;
                var assignedBy = (!IsAdminOrHr && User.IsInRole("Manager")) ? (int?)callerId : (int?)null;

                var rows = _appData.SelectModelList<TaskModel>(
                    "Procs_GetTasks",
                    new
                    {
                        EmployeeID = requestedEmployee,
                        AssignedBy = assignedBy,
                        Status = status,
                        Priority = priority,
                        FromDate = fromDate,
                        ToDate = toDate
                    }) ?? new List<TaskModel>();

                if (!IsAdminOrHr && User.IsInRole("Manager"))
                    rows = rows.Where(x => IsTeamMember(x.EmployeeID)).ToList();

                return Ok(new { statusCode = 200, message = "OK", data = rows });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        // POST api/EmployeeAPI/tasks
        // Assigns a new task. The assignee (request.EmployeeID) is validated with
        // CanManageEmployee (a Manager may only assign to their team). The server forces
        // AssignedBy = caller's CustId and Status = "Pending". Mirrors OperationsController.TaskCreate.
        [HttpPost("tasks")]
        public IActionResult AssignTask([FromBody] TaskCreateRequest request)
        {
            if (request is null)
                return BadRequest(new { statusCode = 400, message = "Request body is required." });

            if (!TryGetCurrentEmployeeId(out var callerId))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            if (!IsAdminOrHr && !User.IsInRole("Manager"))
                return StatusCode(403, new { statusCode = 403, message = "Only a manager, HR or admin can assign tasks." });

            if (request.EmployeeID <= 0)
                return BadRequest(new { statusCode = 400, message = "EmployeeID (assignee) is required." });

            if (!CanManageEmployee(request.EmployeeID))
                return StatusCode(403, new { statusCode = 403, message = "You can only assign tasks to your own team." });

            var errors = new Dictionary<string, string>();
            if (string.IsNullOrWhiteSpace(request.TaskTitle))
                errors["TaskTitle"] = "Task title is required.";
            if (request.DueDate.Date < (request.StartDate?.Date ?? DateTime.Today))
                errors["DueDate"] = "Due date cannot be before the start date.";
            if (errors.Count > 0)
                return BadRequest(new { statusCode = 400, message = "Validation failed.", errors });

            try
            {
                var result = _appData.SelectModel<ResultSet>(
                    "Procs_InsertUpdateDeleteTask",
                    new
                    {
                        TaskID = 0,
                        request.EmployeeID,
                        AssignedBy = callerId,
                        request.TaskTitle,
                        request.TaskDescription,
                        // @Priority is NOT NULL in the proc; default to "Medium" when blank
                        // (the MVC create form defaults the same way).
                        Priority = string.IsNullOrWhiteSpace(request.Priority) ? "Medium" : request.Priority,
                        Status = "Pending",
                        request.StartDate,
                        request.DueDate,
                        CompletedDate = (DateTime?)null,
                        Mode = 1
                    });

                if (result is null)
                    return StatusCode(500, new { statusCode = 500, message = "No response from database." });
                if (result.StatusCode != 200)
                    return StatusCode(result.StatusCode, new { statusCode = result.StatusCode, message = result.Message });

                return StatusCode(201, new { statusCode = 201, message = result.Message ?? "Task assigned." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        // PUT api/EmployeeAPI/tasks/{id}/status
        // Manager / HR / Admin updates the status of a team member's task. HR/Admin over any
        // task; a Manager only over their team's. (An employee changing their OWN task uses
        // PUT me/tasks/{id}/status.) Full-row rewrite, same fetch-then-resend pattern.
        [HttpPut("tasks/{id:int}/status")]
        public IActionResult UpdateTaskStatus(int id, [FromBody] TaskStatusUpdateRequest request)
        {
            if (request is null)
                return BadRequest(new { statusCode = 400, message = "Request body is required." });

            if (!TryGetCurrentEmployeeId(out _))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            if (!IsAdminOrHr && !User.IsInRole("Manager"))
                return StatusCode(403, new { statusCode = 403, message = "Only a manager, HR or admin can update a team member's task. Use me/tasks/{id}/status for your own." });

            var validStatuses = new[] { "Pending", "In Progress", "Completed", "Cancelled" };
            if (string.IsNullOrWhiteSpace(request.Status) ||
                !validStatuses.Contains(request.Status, StringComparer.OrdinalIgnoreCase))
                return BadRequest(new { statusCode = 400, message = "Select a valid task status (Pending, In Progress, Completed, Cancelled)." });

            try
            {
                var row = (_appData.SelectModelList<TaskModel>(
                    "Procs_GetTasks",
                    new
                    {
                        EmployeeID = (int?)null,
                        AssignedBy = (int?)null,
                        Status = (string?)null,
                        Priority = (string?)null,
                        FromDate = (DateTime?)null,
                        ToDate = (DateTime?)null
                    }) ?? new List<TaskModel>())
                    .FirstOrDefault(x => x.TaskID == id);

                if (row is null)
                    return NotFound(new { statusCode = 404, message = "Task not found." });

                // A Manager may only touch their team's tasks; HR/Admin may touch any.
                if (!IsAdminOrHr && !IsTeamMember(row.EmployeeID))
                    return StatusCode(403, new { statusCode = 403, message = "You can only update tasks for your own team." });

                var newStatus = validStatuses.First(s => s.Equals(request.Status, StringComparison.OrdinalIgnoreCase));

                var result = _appData.SelectModel<ResultSet>(
                    "Procs_InsertUpdateDeleteTask",
                    new
                    {
                        row.TaskID,
                        row.EmployeeID,
                        row.AssignedBy,
                        row.TaskTitle,
                        row.TaskDescription,
                        row.Priority,
                        Status = newStatus,
                        row.StartDate,
                        row.DueDate,
                        CompletedDate = newStatus == "Completed" ? DateTime.Today : row.CompletedDate,
                        Mode = 2
                    });

                if (result is null)
                    return StatusCode(500, new { statusCode = 500, message = "No response from database." });
                if (result.StatusCode != 200)
                    return StatusCode(result.StatusCode, new { statusCode = result.StatusCode, message = result.Message });

                return Ok(new { statusCode = 200, message = result.Message ?? "Task status updated." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        #endregion

        #region Announcements

        // Company announcements. Viewing is open to ANY authenticated user (everyone needs to
        // read notices); authoring — create, edit, activate/deactivate — is restricted to
        // HR/Admin. That is the same split as OperationsController (open GET, HrAccess policy on
        // writes); here the HR/Admin gate is an inline IsAdminOrHr check to stay consistent with
        // the rest of this controller. CreatedBy is always the caller's CustId and, exactly as
        // in the MVC panel, it doubles as "last modified by" on edit/toggle.

        // GET api/EmployeeAPI/announcements?active=&search=
        // Lists announcements. By default only active ones are returned (active=true, same as
        // the MVC default); pass active=false to see inactive. Open to any authenticated user.
        [HttpGet("announcements")]
        public IActionResult GetAnnouncements(bool? active = true, string? search = null)
        {
            if (!TryGetCurrentEmployeeId(out _))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            try
            {
                var rows = _appData.SelectModelList<AnnouncementModel>(
                    "Procs_GetAnnouncements",
                    new
                    {
                        AnnouncementID = (int?)null,
                        IsActive = active,
                        FromDate = (DateTime?)null,
                        ToDate = (DateTime?)null,
                        Search = search
                    }) ?? new List<AnnouncementModel>();

                return Ok(new { statusCode = 200, message = "OK", data = rows });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        // POST api/EmployeeAPI/announcements
        // Creates a new announcement (HR/Admin only). CreatedBy is stamped from the caller's
        // token; PublishDate defaults to today when omitted; ExpiryDate is optional but, when
        // given, must not precede PublishDate (the proc enforces this too). Mode = 1 (Insert).
        [HttpPost("announcements")]
        public IActionResult CreateAnnouncement([FromBody] AnnouncementRequest request)
        {
            if (request is null)
                return BadRequest(new { statusCode = 400, message = "Request body is required." });

            if (!TryGetCurrentEmployeeId(out var callerId))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            if (!IsAdminOrHr)
                return StatusCode(403, new { statusCode = 403, message = "Only HR or admin can create announcements." });

            if (string.IsNullOrWhiteSpace(request.Title))
                return BadRequest(new { statusCode = 400, message = "Title is required." });

            var publishDate = (request.PublishDate ?? DateTime.Today).Date;
            if (request.ExpiryDate.HasValue && request.ExpiryDate.Value.Date < publishDate)
                return BadRequest(new { statusCode = 400, message = "Expiry date cannot be before the publish date." });

            try
            {
                var result = _appData.SelectModel<ResultSet>(
                    "Procs_InsertUpdateDeleteAnnouncement",
                    new
                    {
                        AnnouncementID = 0,
                        request.Title,
                        request.Description,
                        PublishDate = publishDate,
                        request.ExpiryDate,
                        CreatedBy = callerId,
                        request.IsActive,
                        Mode = 1
                    });

                if (result is null)
                    return StatusCode(500, new { statusCode = 500, message = "No response from database." });
                if (result.StatusCode != 200)
                    return StatusCode(result.StatusCode, new { statusCode = result.StatusCode, message = result.Message });

                return StatusCode(201, new { statusCode = 201, message = result.Message ?? "Announcement created." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        // PUT api/EmployeeAPI/announcements/{id}
        // Edits an existing announcement (HR/Admin only). Full-row update (Mode = 2): the body
        // supplies the editable fields and {id} identifies the row; a missing id is reported by
        // the proc as a non-200 result (surfaced here). CreatedBy is re-stamped to the caller —
        // matching the MVC edit, where it records who last touched the announcement.
        [HttpPut("announcements/{id:int}")]
        public IActionResult UpdateAnnouncement(int id, [FromBody] AnnouncementRequest request)
        {
            if (request is null)
                return BadRequest(new { statusCode = 400, message = "Request body is required." });

            if (!TryGetCurrentEmployeeId(out var callerId))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            if (!IsAdminOrHr)
                return StatusCode(403, new { statusCode = 403, message = "Only HR or admin can edit announcements." });

            if (string.IsNullOrWhiteSpace(request.Title))
                return BadRequest(new { statusCode = 400, message = "Title is required." });

            var publishDate = (request.PublishDate ?? DateTime.Today).Date;
            if (request.ExpiryDate.HasValue && request.ExpiryDate.Value.Date < publishDate)
                return BadRequest(new { statusCode = 400, message = "Expiry date cannot be before the publish date." });

            try
            {
                var result = _appData.SelectModel<ResultSet>(
                    "Procs_InsertUpdateDeleteAnnouncement",
                    new
                    {
                        AnnouncementID = id,
                        request.Title,
                        request.Description,
                        PublishDate = publishDate,
                        request.ExpiryDate,
                        CreatedBy = callerId,
                        request.IsActive,
                        Mode = 2
                    });

                if (result is null)
                    return StatusCode(500, new { statusCode = 500, message = "No response from database." });
                if (result.StatusCode != 200)
                    return StatusCode(result.StatusCode, new { statusCode = result.StatusCode, message = result.Message });

                return Ok(new { statusCode = 200, message = result.Message ?? "Announcement updated." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        // POST api/EmployeeAPI/announcements/{id}/toggle
        // Activates or deactivates an announcement (HR/Admin only). No IsActive is taken from
        // the client: we fetch the current row, flip its IsActive, and resend every field
        // unchanged (Mode = 2) — the same fetch-then-flip pattern as OperationsController.
        // AnnouncementToggle. Deactivating is the system's stand-in for deletion.
        [HttpPost("announcements/{id:int}/toggle")]
        public IActionResult ToggleAnnouncement(int id)
        {
            if (!TryGetCurrentEmployeeId(out var callerId))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            if (!IsAdminOrHr)
                return StatusCode(403, new { statusCode = 403, message = "Only HR or admin can change an announcement's status." });

            try
            {
                var row = (_appData.SelectModelList<AnnouncementModel>(
                    "Procs_GetAnnouncements",
                    new
                    {
                        AnnouncementID = (int?)id,
                        IsActive = (bool?)null,
                        FromDate = (DateTime?)null,
                        ToDate = (DateTime?)null,
                        Search = (string?)null
                    }) ?? new List<AnnouncementModel>())
                    .FirstOrDefault();

                if (row is null)
                    return NotFound(new { statusCode = 404, message = "Announcement not found." });

                var result = _appData.SelectModel<ResultSet>(
                    "Procs_InsertUpdateDeleteAnnouncement",
                    new
                    {
                        AnnouncementID = row.AnnouncementID,
                        row.Title,
                        row.Description,
                        row.PublishDate,
                        row.ExpiryDate,
                        CreatedBy = callerId,
                        IsActive = !row.IsActive,
                        Mode = 2
                    });

                if (result is null)
                    return StatusCode(500, new { statusCode = 500, message = "No response from database." });
                if (result.StatusCode != 200)
                    return StatusCode(result.StatusCode, new { statusCode = result.StatusCode, message = result.Message });

                return Ok(new { statusCode = 200, message = result.Message ?? (row.IsActive ? "Announcement deactivated." : "Announcement activated.") });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        #endregion

        #region Payroll (team / all — read-only oversight)

        // Manager / HR / Admin READ-ONLY view of payroll. Generating, editing, deleting payroll
        // and all salary / tax / bonus / advance configuration stay in the MVC admin panel —
        // this app only ever READS. Scope mirrors PayrollController: Manager -> their team,
        // HR/Admin -> the whole organization, Employee -> 403 (own payslips are at me/payslips).

        // GET api/EmployeeAPI/payroll?employeeId=&month=&year=&paymentStatus=
        // Lists payroll rows the caller may oversee. HR/Admin may filter by employeeId; a
        // Manager always sees only their current team (filtered in memory after the fetch,
        // exactly like PayrollController.Index).
        [HttpGet("payroll")]
        public IActionResult GetPayroll(int? employeeId, byte? month, short? year, string? paymentStatus)
        {
            if (!TryGetCurrentEmployeeId(out var callerId))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            if (!IsAdminOrHr && !User.IsInRole("Manager"))
                return StatusCode(403, new { statusCode = 403, message = "Only a manager, HR or admin can view team payroll. Use me/payslips for your own." });

            try
            {
                // HR/Admin: optional employeeId filter. Manager: fetch all, then narrow to team.
                var requested = IsAdminOrHr ? employeeId : (int?)null;

                var rows = _appData.SelectModelList<PayrollModel>(
                    "Procs_GetPayroll",
                    new
                    {
                        EmployeeID = requested,
                        PayrollMonth = month,
                        PayrollYear = year,
                        PaymentStatus = paymentStatus
                    }) ?? new List<PayrollModel>();

                // Procs_GetPayroll returns a single {StatusCode, Message} sentinel row for a bad
                // month/year or an unknown employeeId (real payroll rows have no StatusCode column,
                // so Dapper leaves it 0). Surface that as the proper status rather than leaking a
                // junk row as data.
                var sentinel = rows.FirstOrDefault(r => r.StatusCode != 0);
                if (sentinel is not null)
                    return StatusCode(sentinel.StatusCode, new { statusCode = sentinel.StatusCode, message = sentinel.Message });

                if (!IsAdminOrHr && User.IsInRole("Manager"))
                {
                    var teamIds = AllActiveEmployees()
                        .Where(e => e.ManagerID == callerId)
                        .Select(e => e.EmployeeID)
                        .ToHashSet();
                    rows = rows.Where(x => teamIds.Contains(x.EmployeeID)).ToList();
                }

                return Ok(new { statusCode = 200, message = "OK", data = rows });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        // GET api/EmployeeAPI/payroll/{id}
        // One salary slip by PayrollID, for oversight. We fetch the slip (unscoped) and then
        // enforce scope: HR/Admin may view any; a Manager only their team's. An employee viewing
        // their OWN slip uses me/payslips/{id}. Mirrors PayrollController.SalarySlip.
        [HttpGet("payroll/{id:int}")]
        public IActionResult GetPayrollSlip(int id)
        {
            if (!TryGetCurrentEmployeeId(out _))
                return StatusCode(403, new { statusCode = 403, message = "Your token does not identify an employee." });

            if (!IsAdminOrHr && !User.IsInRole("Manager"))
                return StatusCode(403, new { statusCode = 403, message = "Only a manager, HR or admin can view a team member's payslip. Use me/payslips/{id} for your own." });

            try
            {
                var slip = _appData.SelectModel<SalarySlipModel>(
                    "Procs_GetSalarySlip",
                    new
                    {
                        PayrollID = (int?)id,
                        EmployeeID = (int?)null,
                        PayrollMonth = (byte?)null,
                        PayrollYear = (short?)null
                    });

                // Not found = null, OR the proc's sentinel row (StatusCode 404 and no real
                // PayrollID). A genuine slip echoes back the requested PayrollID and, having no
                // StatusCode column in its SELECT, carries StatusCode 0.
                if (slip is null || slip.StatusCode == 404 || slip.PayrollID != id)
                    return NotFound(new { statusCode = 404, message = "Payslip not found." });

                // Team scope for a Manager; HR/Admin already cleared the role gate above.
                if (!IsAdminOrHr && !IsTeamMember(slip.EmployeeID))
                    return StatusCode(403, new { statusCode = 403, message = "You can only view payslips for your own team." });

                return Ok(new { statusCode = 200, message = "OK", data = slip });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        #endregion

        #region Helpers

        // ----- helpers -------------------------------------------------------------

        // Reads the caller's own EmployeeID from the JWT "CustId" claim (set at login by
        // TokenService). This is the ONLY source of the id — the client cannot override it.
        private bool TryGetCurrentEmployeeId(out int employeeId)
        {
            employeeId = 0;
            var raw = User.FindFirst("CustId")?.Value;
            return int.TryParse(raw, out employeeId) && employeeId > 0;
        }

        // ----- team-scope helpers (for manager / HR / admin oversight endpoints) ----

        // True when the caller is HR or Admin, i.e. has organization-wide scope. Mirrors
        // OperationsController.IsAdminOrHr.
        private bool IsAdminOrHr => User.IsInRole("Admin") || User.IsInRole("HR");

        // Every active employee — same proc and parameter shape as GetOwnEmployee, just
        // unfiltered. Used only to answer "is employee X a direct report of the caller?".
        // Mirrors OperationsController.Employees().
        private List<EmployeeResponse> AllActiveEmployees() =>
            _appData.SelectModelList<EmployeeResponse>(
                "Procs_GetEmployees",
                new
                {
                    EmployeeID = (int?)null,
                    DepartmentID = (int?)null,
                    DesignationID = (int?)null,
                    OfficeLocationID = (int?)null,
                    ManagerID = (int?)null,
                    ShiftID = (int?)null,
                    IsActive = (bool?)true,
                    Search = (string?)null
                }) ?? new List<EmployeeResponse>();

        // True when 'employeeId' is a direct report of the caller — the caller's CustId is
        // that employee's ManagerID. Mirrors OperationsController.IsTeamMember, but the
        // manager id is the JWT CustId, never the cookie "EmployeeID" claim.
        private bool IsTeamMember(int employeeId)
        {
            if (!TryGetCurrentEmployeeId(out var callerId)) return false;
            return AllActiveEmployees().Any(e => e.EmployeeID == employeeId && e.ManagerID == callerId);
        }

        // True when the caller may ACT ON this employee for a management operation (mark
        // attendance for them, assign them a task): HR/Admin over anyone, Manager over their
        // own team only. Deliberately does NOT include "the employee acting on themselves" —
        // that path has its own me/* self-service endpoints. Used to validate a target
        // EmployeeID supplied in a request body, which must never be trusted on its own.
        private bool CanManageEmployee(int employeeId) =>
            IsAdminOrHr || (User.IsInRole("Manager") && IsTeamMember(employeeId));

        // Fetches the caller's OWN active record via Procs_GetEmployees (@EmployeeID),
        // exactly like EmployeeController.TryGetEditableEmployee (IsActive = true).
        private EmployeeResponse? GetOwnEmployee(int employeeId) =>
            _appData.SelectModelList<EmployeeResponse>(
                "Procs_GetEmployees",
                new
                {
                    EmployeeID = (int?)employeeId,
                    DepartmentID = (int?)null,
                    DesignationID = (int?)null,
                    OfficeLocationID = (int?)null,
                    ManagerID = (int?)null,
                    ShiftID = (int?)null,
                    IsActive = (bool?)true,
                    Search = (string?)null
                })?.FirstOrDefault();

        // Same rules as EmployeeController.ValidateSelfServiceRequest. EmergencyContact is
        // optional; the other seven fields are required and Email must be a valid address.
        private static Dictionary<string, string> ValidateSelfService(EmployeeSelfServiceRequest r)
        {
            var errors = new Dictionary<string, string>();
            if (string.IsNullOrWhiteSpace(r.Email) || !new EmailAddressAttribute().IsValid(r.Email))
                errors["Email"] = "A valid email is required.";
            if (string.IsNullOrWhiteSpace(r.PhoneNumber)) errors["PhoneNumber"] = "Phone number is required.";
            if (string.IsNullOrWhiteSpace(r.Address)) errors["Address"] = "Address is required.";
            if (string.IsNullOrWhiteSpace(r.City)) errors["City"] = "City is required.";
            if (string.IsNullOrWhiteSpace(r.State)) errors["State"] = "State is required.";
            if (string.IsNullOrWhiteSpace(r.Country)) errors["Country"] = "Country is required.";
            if (string.IsNullOrWhiteSpace(r.PostalCode)) errors["PostalCode"] = "Postal code is required.";
            return errors;
        }

        // 1:1 copy of EmployeeController.ToProcedureParameters. Here it is always called
        // with mode = 2 (Update), because self-service can only ever update.
        private static object ToProcParams(EmployeeRequest request, int mode) => new
        {
            EmployeeID = request.EmployeeID,
            EmployeeCode = request.EmployeeCode,
            FirstName = request.FirstName,
            LastName = request.LastName,
            Gender = request.Gender,
            DateOfBirth = request.DateOfBirth,
            Email = request.Email,
            PhoneNumber = request.PhoneNumber,
            EmergencyContact = request.EmergencyContact,
            Address = request.Address,
            City = request.City,
            State = request.State,
            Country = request.Country,
            PostalCode = request.PostalCode,
            DepartmentID = request.DepartmentID,
            DesignationID = request.DesignationID,
            OfficeLocationID = request.OfficeLocationID,
            ManagerID = request.ManagerID,
            JoiningDate = request.JoiningDate,
            EmploymentType = request.EmploymentType,
            BasicSalary = request.BasicSalary,
            ShiftID = request.ShiftID,
            RoleID = request.RoleID,
            ProfileImage = request.ProfileImage,
            Mode = mode
        };

        // Mirrors EmployeeController.ToRequest: copies a fetched row into a request so the
        // update resends the full, non-optional parameter set unchanged (only the eight
        // self-service fields are overwritten by the caller afterwards).
        private static EmployeeRequest ToRequest(EmployeeResponse e) => new()
        {
            EmployeeID = e.EmployeeID,
            EmployeeCode = e.EmployeeCode,
            FirstName = e.FirstName,
            LastName = e.LastName,
            Gender = e.Gender,
            DateOfBirth = e.DateOfBirth,
            Email = e.Email,
            PhoneNumber = e.PhoneNumber,
            EmergencyContact = e.EmergencyContact,
            Address = e.Address,
            City = e.City,
            State = e.State,
            Country = e.Country,
            PostalCode = e.PostalCode,
            DepartmentID = e.DepartmentID,
            DesignationID = e.DesignationID,
            OfficeLocationID = e.OfficeLocationID,
            ManagerID = e.ManagerID,
            JoiningDate = e.JoiningDate,
            EmploymentType = e.EmploymentType,
            BasicSalary = e.BasicSalary,
            ShiftID = e.ShiftID,
            RoleID = e.RoleID,
            ProfileImage = e.ProfileImage,
            IsActive = e.IsActive
        };

        #endregion
    }
}
