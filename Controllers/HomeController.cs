using AdminPannel.Logic;
// Admin.Models was used for Employee DTOs which have been removed
using AdminPannel.Models;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;

namespace AdminPannel.Controllers
{
    [Authorize]
    public class HomeController : Controller
    {
        AppData _objapp = new AppData();

        public IActionResult Index()
        {
            return View();
        }

        public IActionResult Privacy()
        {
            return View();
        }

        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }

        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult Department()
        {
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult Department(DepartmentRequest request)
        {
            try
            {
                // server-side validation
                if (request == null || string.IsNullOrEmpty(request.DepartmentName) || string.IsNullOrEmpty(request.DepartmentCode))
                {
                    // If AJAX, return JSON so client can handle
                    if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")
                        return Json(new { success = false, message = "Department Name and Code are required." });

                    ModelState.AddModelError(string.Empty, "Department Name and Code are required.");
                    return View(request);
                }

                // Mode: 1 = Insert, 2 = Update
                request.Mode = (request.DepartmentID > 0) ? 2 : 1;
                ResultSet result = _objapp.SelectModel<ResultSet>("Procs_InsertUpdateDeleteDepartment", request);

                // If AJAX request, return JSON
                if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")
                {
                    if (result != null && result.StatusCode == 200)
                        return Json(new { success = true, message = result.Message ?? "Department saved successfully." });

                    return Json(new { success = false, message = result?.Message ?? "Operation failed." });
                }

                // Non-AJAX fallback (form post)
                if (result != null && result.StatusCode == 200)
                {
                    ViewBag.Message = result.Message ?? "Department saved successfully.";
                    return View();
                }

                ModelState.AddModelError(string.Empty, result?.Message ?? "Unknown error.");
                return View(request);
            }
            catch (Exception ex)
            {
                if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")
                    return Json(new { success = false, message = ex.Message });

                ModelState.AddModelError(string.Empty, ex.Message);
                return View(request);
            }
        }

        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult GetDepartment()
        {
            var param = new
            {
                DepartmentID = 0,
                Mode = 1
            };
            var resultList = _objapp.SelectModelList<DepartmentResponse>("Procs_GetDepartment", param);
            return  PartialView("_PartialDepartmentList", resultList);
        }

        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult GetDepartmentById(int DepartmentID)
        {
            var param = new
            {
                DepartmentID = DepartmentID,
                Mode = 2
            };
            var result = _objapp.SelectModel<DepartmentResponse>("Procs_GetDepartment", param);
            return Json(result);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult DeleteDepartment(int id)
        {
            try
            {
                // Fetch existing department details first because the stored procedure expects DepartmentName (and possibly other fields)
                var dept = _objapp.SelectModel<DepartmentResponse>("Procs_GetDepartment", new { DepartmentID = id, Mode = 2 });
                if (dept == null)
                    return Json(new { success = false, message = "Department not found." });

                var result = _objapp.SelectModel<ResultSet>("Procs_InsertUpdateDeleteDepartment", new
                {
                    DepartmentID = id,
                    DepartmentName = dept.DepartmentName,
                    DepartmentCode = dept.DepartmentCode,
                    Description = dept.Description,
                    Mode = 3
                });
                if (result != null && result.StatusCode == 200)
                    return Json(new { success = true, message = result.Message ?? "Deleted" });

                return Json(new { success = false, message = result?.Message ?? "Delete failed." });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message });
            }
        }

        // Designation endpoints (following Department pattern)

        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult Designation()
        {
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult Designation(DesignationRequest request)
        {
            try
            {
                // server-side validation
                if (request == null || string.IsNullOrEmpty(request.DesignationName) || string.IsNullOrEmpty(request.DesignationCode))
                {
                    // If AJAX, return JSON so client can handle
                    if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")
                        return Json(new { success = false, message = "Designation Name and Code are required." });

                    ModelState.AddModelError(string.Empty, "Designation Name and Code are required.");
                    return View(request);
                }

                // Mode: 1 = Insert, 2 = Update
                request.Mode = (request.DesignationID > 0) ? 2 : 1;
                ResultSet result = _objapp.SelectModel<ResultSet>("Procs_InsertUpdateDeleteDesignation", request);

                // If AJAX request, return JSON
                if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")
                {
                    if (result != null && result.StatusCode == 200)
                        return Json(new { success = true, message = result.Message ?? "Designation saved successfully." });

                    return Json(new { success = false, message = result?.Message ?? "Operation failed." });
                }

                // Non-AJAX fallback (form post)
                if (result != null && result.StatusCode == 200)
                {
                    ViewBag.Message = result.Message ?? "Designation saved successfully.";
                    return View();
                }

                ModelState.AddModelError(string.Empty, result?.Message ?? "Unknown error.");
                return View(request);
            }
            catch (Exception ex)
            {
                if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")
                    return Json(new { success = false, message = ex.Message });

                ModelState.AddModelError(string.Empty, ex.Message);
                return View(request);
            }
        }

        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult GetDesignation()
        {
            var param = new
            {
                DesignationID = (int?)null,
                IsActive = true,
                Search = (string)null
            };
            var resultList = _objapp.SelectModelList<DesignationResponse>("Procs_GetDesignation", param);
            return PartialView("_PartialDesignationList", resultList);
        }

        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult GetDesignationById(int DesignationID)
        {
            var param = new
            {
                DesignationID = DesignationID,
                IsActive = (bool?)null,
                Search = (string)null
            };
            var result = _objapp.SelectModel<DesignationResponse>("Procs_GetDesignation", param);
            return Json(result);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult DeleteDesignation(int id)
        {
            try
            {
                // Fetch existing designation details first because the stored procedure expects DesignationName (and possibly other fields)
                var des = _objapp.SelectModel<DesignationResponse>("Procs_GetDesignation", new { DesignationID = id, IsActive = (bool?)null, Search = (string)null });
                if (des == null)
                    return Json(new { success = false, message = "Designation not found." });

                var result = _objapp.SelectModel<ResultSet>("Procs_InsertUpdateDeleteDesignation", new
                {
                    DesignationID = id,
                    DesignationName = des.DesignationName,
                    DesignationCode = des.DesignationCode,
                    Description = des.Description,
                    Mode = 3
                });
                if (result != null && result.StatusCode == 200)
                    return Json(new { success = true, message = result.Message ?? "Deleted" });

                return Json(new { success = false, message = result?.Message ?? "Delete failed." });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message });
            }
        }

        // Office Branch endpoints (following Department and Designation pattern)

        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult OfficeBranch()
        {
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult OfficeBranch(OfficeBranchRequest request)
        {
            try
            {
                // server-side validation
                if (request == null || string.IsNullOrEmpty(request.OfficeName) || string.IsNullOrEmpty(request.OfficeCode) ||
                    string.IsNullOrEmpty(request.AddressLine1) || string.IsNullOrEmpty(request.City) ||
                    string.IsNullOrEmpty(request.State) || string.IsNullOrEmpty(request.Country))
                {
                    // If AJAX, return JSON so client can handle
                    if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")
                        return Json(new { success = false, message = "Office Name, Office Code, Address Line 1, City, State, and Country are required." });

                    ModelState.AddModelError(string.Empty, "Office Name, Office Code, Address Line 1, City, State, and Country are required.");
                    return View(request);
                }

                // Mode: 1 = Insert, 2 = Update
                request.Mode = (request.OfficeLocationID > 0) ? 2 : 1;
                ResultSet result = _objapp.SelectModel<ResultSet>("Procs_InsertUpdateDeleteOfficeBranch", request);

                // If AJAX request, return JSON
                if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")
                {
                    if (result != null && result.StatusCode == 200)
                        return Json(new { success = true, message = result.Message ?? "Office Branch saved successfully." });

                    return Json(new { success = false, message = result?.Message ?? "Operation failed." });
                }

                // Non-AJAX fallback (form post)
                if (result != null && result.StatusCode == 200)
                {
                    ViewBag.Message = result.Message ?? "Office Branch saved successfully.";
                    return View();
                }

                ModelState.AddModelError(string.Empty, result?.Message ?? "Unknown error.");
                return View(request);
            }
            catch (Exception ex)
            {
                if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")
                    return Json(new { success = false, message = ex.Message });

                ModelState.AddModelError(string.Empty, ex.Message);
                return View(request);
            }
        }

        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult GetOfficeBranch()
        {
            var param = new
            {
                OfficeLocationID = (int?)null,
                IsActive = true,
                Search = (string)null
            };
            var resultList = _objapp.SelectModelList<OfficeBranchResponse>("Procs_GetOfficeBranch", param);
            return PartialView("_PartialOfficeBranchList", resultList);
        }

        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult GetOfficeBranchById(int OfficeLocationID)
        {
            var param = new
            {
                OfficeLocationID = OfficeLocationID,
                IsActive = (bool?)null,
                Search = (string)null
            };
            var result = _objapp.SelectModel<OfficeBranchResponse>("Procs_GetOfficeBranch", param);
            return Json(result);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult DeleteOfficeBranch(int id)
        {
            try
            {
                // Fetch existing office branch details first because the stored procedure expects all fields
                var office = _objapp.SelectModel<OfficeBranchResponse>("Procs_GetOfficeBranch", new { OfficeLocationID = id, IsActive = (bool?)null, Search = (string)null });
                if (office == null)
                    return Json(new { success = false, message = "Office Branch not found." });

                var result = _objapp.SelectModel<ResultSet>("Procs_InsertUpdateDeleteOfficeBranch", new
                {
                    OfficeLocationID = id,
                    OfficeName = office.OfficeName,
                    OfficeCode = office.OfficeCode,
                    AddressLine1 = office.AddressLine1,
                    AddressLine2 = office.AddressLine2,
                    City = office.City,
                    State = office.State,
                    Country = office.Country,
                    PostalCode = office.PostalCode,
                    PhoneNumber = office.PhoneNumber,
                    Email = office.Email,
                    Mode = 3
                });
                if (result != null && result.StatusCode == 200)
                    return Json(new { success = true, message = result.Message ?? "Deleted" });

                return Json(new { success = false, message = result?.Message ?? "Delete failed." });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message });
            }
        }

        // Role endpoints (following Department, Designation and Office Branch pattern)

        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult Role()
        {
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult Role(RoleRequest request)
        {
            try
            {
                // server-side validation
                if (request == null || string.IsNullOrEmpty(request.RoleName))
                {
                    // If AJAX, return JSON so client can handle
                    if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")
                        return Json(new { success = false, message = "Role Name is required." });

                    ModelState.AddModelError(string.Empty, "Role Name is required.");
                    return View(request);
                }

                // Mode: 1 = Insert, 2 = Update
                request.Mode = (request.RoleID > 0) ? 2 : 1;
                ResultSet result = _objapp.SelectModel<ResultSet>("Procs_InsertUpdateDeleteRole", request);

                // If AJAX request, return JSON
                if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")
                {
                    if (result != null && result.StatusCode == 200)
                        return Json(new { success = true, message = result.Message ?? "Role saved successfully." });

                    return Json(new { success = false, message = result?.Message ?? "Operation failed." });
                }

                // Non-AJAX fallback (form post)
                if (result != null && result.StatusCode == 200)
                {
                    ViewBag.Message = result.Message ?? "Role saved successfully.";
                    return View();
                }

                ModelState.AddModelError(string.Empty, result?.Message ?? "Unknown error.");
                return View(request);
            }
            catch (Exception ex)
            {
                if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")
                    return Json(new { success = false, message = ex.Message });

                ModelState.AddModelError(string.Empty, ex.Message);
                return View(request);
            }
        }

        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult GetRole()
        {
            var param = new
            {
                RoleID = (int?)null,
                IsActive = true,
                Search = (string)null
            };
            var resultList = _objapp.SelectModelList<RoleResponse>("Procs_GetRole", param);
            return PartialView("_PartialRoleList", resultList);
        }

        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult GetRoleById(int RoleID)
        {
            var param = new
            {
                RoleID = RoleID,
                IsActive = (bool?)null,
                Search = (string)null
            };
            var result = _objapp.SelectModel<RoleResponse>("Procs_GetRole", param);
            return Json(result);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult DeleteRole(int id)
        {
            try
            {
                // Fetch existing role details first because the stored procedure expects all fields
                var role = _objapp.SelectModel<RoleResponse>("Procs_GetRole", new { RoleID = id, IsActive = (bool?)null, Search = (string)null });
                if (role == null)
                    return Json(new { success = false, message = "Role not found." });

                var result = _objapp.SelectModel<ResultSet>("Procs_InsertUpdateDeleteRole", new
                {
                    RoleID = id,
                    RoleName = role.RoleName,
                    Description = role.Description,
                    Mode = 3
                });
                if (result != null && result.StatusCode == 200)
                    return Json(new { success = true, message = result.Message ?? "Deleted" });

                return Json(new { success = false, message = result?.Message ?? "Delete failed." });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message });
            }
        }

        // Shift endpoints (following Department, Designation, Office Branch and Role pattern)

        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult Shift()
        {
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult Shift(ShiftRequest request)
        {
            try
            {
                // server-side validation
                if (request == null || string.IsNullOrEmpty(request.ShiftName) || string.IsNullOrEmpty(request.ShiftCode))
                {
                    // If AJAX, return JSON so client can handle
                    if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")
                        return Json(new { success = false, message = "Shift Name and Shift Code are required." });

                    ModelState.AddModelError(string.Empty, "Shift Name and Shift Code are required.");
                    return View(request);
                }

                // Mode: 1 = Insert, 2 = Update
                request.Mode = (request.ShiftID > 0) ? 2 : 1;
                ResultSet result = _objapp.SelectModel<ResultSet>("Procs_InsertUpdateDeleteShift", request);

                // If AJAX request, return JSON
                if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")
                {
                    if (result != null && result.StatusCode == 200)
                        return Json(new { success = true, message = result.Message ?? "Shift saved successfully." });

                    return Json(new { success = false, message = result?.Message ?? "Operation failed." });
                }

                // Non-AJAX fallback (form post)
                if (result != null && result.StatusCode == 200)
                {
                    ViewBag.Message = result.Message ?? "Shift saved successfully.";
                    return View();
                }

                ModelState.AddModelError(string.Empty, result?.Message ?? "Unknown error.");
                return View(request);
            }
            catch (Exception ex)
            {
                if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")
                    return Json(new { success = false, message = ex.Message });

                ModelState.AddModelError(string.Empty, ex.Message);
                return View(request);
            }
        }

        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult GetShift()
        {
            var param = new
            {
                ShiftID = (int?)null,
                IsActive = true,
                Search = (string)null
            };
            var resultList = _objapp.SelectModelList<ShiftResponse>("Procs_GetShift", param);
            return PartialView("_PartialShiftList", resultList);
        }

        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult GetShiftById(int ShiftID)
        {
            var param = new
            {
                ShiftID = ShiftID,
                IsActive = (bool?)null,
                Search = (string)null
            };
            var result = _objapp.SelectModel<ShiftResponse>("Procs_GetShift", param);
            return Json(result);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult DeleteShift(int id)
        {
            try
            {
                // Fetch existing shift details first because the stored procedure expects all fields
                var shift = _objapp.SelectModel<ShiftResponse>("Procs_GetShift", new { ShiftID = id, IsActive = (bool?)null, Search = (string)null });
                if (shift == null)
                    return Json(new { success = false, message = "Shift not found." });

                var result = _objapp.SelectModel<ResultSet>("Procs_InsertUpdateDeleteShift", new
                {
                    ShiftID = id,
                    ShiftName = shift.ShiftName,
                    ShiftCode = shift.ShiftCode,
                    StartTime = shift.StartTime,
                    EndTime = shift.EndTime,
                    GraceMinutes = shift.GraceMinutes,
                    IsNightShift = shift.IsNightShift,
                    Mode = 3
                });
                if (result != null && result.StatusCode == 200)
                    return Json(new { success = true, message = result.Message ?? "Deleted" });

                return Json(new { success = false, message = result?.Message ?? "Delete failed." });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message });
            }
        }

        // Leave Type endpoints (following Department, Designation, Office Branch, Role and Shift pattern)

        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult LeaveType()
        {
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult LeaveType(LeaveTypeRequest request)
        {
            try
            {
                // server-side validation
                if (request == null || string.IsNullOrEmpty(request.LeaveTypeName) || string.IsNullOrEmpty(request.LeaveCode))
                {
                    // If AJAX, return JSON so client can handle
                    if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")
                        return Json(new { success = false, message = "Leave Type Name and Leave Code are required." });

                    ModelState.AddModelError(string.Empty, "Leave Type Name and Leave Code are required.");
                    return View(request);
                }

                // Mode: 1 = Insert, 2 = Update
                request.Mode = (request.LeaveTypeID > 0) ? 2 : 1;
                ResultSet result = _objapp.SelectModel<ResultSet>("Procs_InsertUpdateDeleteLeaveType", request);

                // If AJAX request, return JSON
                if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")
                {
                    if (result != null && result.StatusCode == 200)
                        return Json(new { success = true, message = result.Message ?? "Leave Type saved successfully." });

                    return Json(new { success = false, message = result?.Message ?? "Operation failed." });
                }

                // Non-AJAX fallback (form post)
                if (result != null && result.StatusCode == 200)
                {
                    ViewBag.Message = result.Message ?? "Leave Type saved successfully.";
                    return View();
                }

                ModelState.AddModelError(string.Empty, result?.Message ?? "Unknown error.");
                return View(request);
            }
            catch (Exception ex)
            {
                if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")
                    return Json(new { success = false, message = ex.Message });

                ModelState.AddModelError(string.Empty, ex.Message);
                return View(request);
            }
        }

        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult GetLeaveType()
        {
            var param = new
            {
                LeaveTypeID = (int?)null,
                IsActive = true,
                Search = (string)null
            };
            var resultList = _objapp.SelectModelList<LeaveTypeResponse>("Procs_GetLeaveType", param);
            return PartialView("_PartialLeaveTypeList", resultList);
        }

        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult GetLeaveTypeById(int LeaveTypeID)
        {
            var param = new
            {
                LeaveTypeID = LeaveTypeID,
                IsActive = (bool?)null,
                Search = (string)null
            };
            var result = _objapp.SelectModel<LeaveTypeResponse>("Procs_GetLeaveType", param);
            return Json(result);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult DeleteLeaveType(int id)
        {
            try
            {
                // Fetch existing leave type details first because the stored procedure expects all fields
                var leaveType = _objapp.SelectModel<LeaveTypeResponse>("Procs_GetLeaveType", new { LeaveTypeID = id, IsActive = (bool?)null, Search = (string)null });
                if (leaveType == null)
                    return Json(new { success = false, message = "Leave Type not found." });

                var result = _objapp.SelectModel<ResultSet>("Procs_InsertUpdateDeleteLeaveType", new
                {
                    LeaveTypeID = id,
                    LeaveTypeName = leaveType.LeaveTypeName,
                    LeaveCode = leaveType.LeaveCode,
                    MaxLeavesPerYear = leaveType.MaxLeavesPerYear,
                    IsPaidLeave = leaveType.IsPaidLeave,
                    Mode = 3
                });
                if (result != null && result.StatusCode == 200)
                    return Json(new { success = true, message = result.Message ?? "Deleted" });

                return Json(new { success = false, message = result?.Message ?? "Delete failed." });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message });
            }
        }

        // Holiday endpoints (following Department, Designation, Office Branch, Role, Shift and Leave Type pattern)

        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult Holiday()
        {
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult Holiday(HolidayRequest request)
        {
            try
            {
                // server-side validation
                if (request == null || string.IsNullOrEmpty(request.HolidayName) || string.IsNullOrEmpty(request.HolidayType))
                {
                    // If AJAX, return JSON so client can handle
                    if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")
                        return Json(new { success = false, message = "Holiday Name and Holiday Type are required." });

                    ModelState.AddModelError(string.Empty, "Holiday Name and Holiday Type are required.");
                    return View(request);
                }

                // Mode: 1 = Insert, 2 = Update
                request.Mode = (request.HolidayID > 0) ? 2 : 1;
                ResultSet result = _objapp.SelectModel<ResultSet>("Procs_InsertUpdateDeleteHoliday", request);

                // If AJAX request, return JSON
                if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")
                {
                    if (result != null && result.StatusCode == 200)
                        return Json(new { success = true, message = result.Message ?? "Holiday saved successfully." });

                    return Json(new { success = false, message = result?.Message ?? "Operation failed." });
                }

                // Non-AJAX fallback (form post)
                if (result != null && result.StatusCode == 200)
                {
                    ViewBag.Message = result.Message ?? "Holiday saved successfully.";
                    return View();
                }

                ModelState.AddModelError(string.Empty, result?.Message ?? "Unknown error.");
                return View(request);
            }
            catch (Exception ex)
            {
                if (Request.Headers["X-Requested-With"] == "XMLHttpRequest")
                    return Json(new { success = false, message = ex.Message });

                ModelState.AddModelError(string.Empty, ex.Message);
                return View(request);
            }
        }

        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult GetHoliday()
        {
            var param = new
            {
                HolidayID = (int?)null,
                IsActive = true,
                Search = (string)null
            };
            var resultList = _objapp.SelectModelList<HolidayResponse>("Procs_GetHoliday", param);
            return PartialView("_PartialHolidayList", resultList);
        }

        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult GetHolidayById(int HolidayID)
        {
            var param = new
            {
                HolidayID = HolidayID,
                IsActive = (bool?)null,
                Search = (string)null
            };
            var result = _objapp.SelectModel<HolidayResponse>("Procs_GetHoliday", param);
            return Json(result);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public IActionResult DeleteHoliday(int id)
        {
            try
            {
                // Fetch existing holiday details first because the stored procedure expects all fields
                var holiday = _objapp.SelectModel<HolidayResponse>("Procs_GetHoliday", new { HolidayID = id, IsActive = (bool?)null, Search = (string)null });
                if (holiday == null)
                    return Json(new { success = false, message = "Holiday not found." });

                var result = _objapp.SelectModel<ResultSet>("Procs_InsertUpdateDeleteHoliday", new
                {
                    HolidayID = id,
                    HolidayName = holiday.HolidayName,
                    HolidayDate = holiday.HolidayDate,
                    HolidayType = holiday.HolidayType,
                    Description = holiday.Description,
                    IsOptional = holiday.IsOptional,
                    Mode = 3
                });
                if (result != null && result.StatusCode == 200)
                    return Json(new { success = true, message = result.Message ?? "Deleted" });

                return Json(new { success = false, message = result?.Message ?? "Delete failed." });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message });
            }
        }

    }
}
