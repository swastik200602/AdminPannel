using AdminPannel.Logic;
using AdminPannel.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Cryptography;

namespace AdminPannel.Controllers
{
    [Authorize(Policy = AuthorizationPolicies.UserManagement)]
    public class UserController : Controller
    {
        private readonly AppData _app = new();

        [HttpGet]
        public IActionResult Index(string? search, int? employeeId, int? roleId, bool? isActive)
        {
            try
            {
                var employees = _app.SelectModelList<EmployeeResponse>("Procs_GetEmployees", new
                {
                    EmployeeID = (int?)null, DepartmentID = (int?)null, DesignationID = (int?)null,
                    OfficeLocationID = (int?)null, ManagerID = (int?)null, ShiftID = (int?)null,
                    RoleID = (int?)null, IsActive = (bool?)null, Search = (string?)null
                }) ?? new List<EmployeeResponse>();
                var departmentRows = _app.SelectModelList<DepartmentLookup>("Procs_GetDepartment", new { DepartmentID = 0, Mode = 3 }) ?? new List<DepartmentLookup>();
                var designations = _app.SelectModelList<DesignationResponse>("Procs_GetDesignation", new { DesignationID = (int?)null, IsActive = true, Search = (string?)null }) ?? new List<DesignationResponse>();
                var offices = _app.SelectModelList<OfficeBranchResponse>("Procs_GetOfficeBranch", new { OfficeLocationID = (int?)null, IsActive = true, Search = (string?)null }) ?? new List<OfficeBranchResponse>();
                var departmentNames = departmentRows.Where(x => x.Id > 0 && !string.IsNullOrWhiteSpace(x.Name)).GroupBy(x => x.Id).ToDictionary(x => x.Key, x => x.First().Name!);
                var designationNames = designations.ToDictionary(x => x.DesignationID, x => x.DesignationName);
                var officeNames = offices.ToDictionary(x => x.OfficeLocationID, x => x.OfficeName);
                foreach (var employee in employees)
                {
                    employee.DepartmentName = departmentNames.GetValueOrDefault(employee.DepartmentID);
                    employee.DesignationName = designationNames.GetValueOrDefault(employee.DesignationID);
                    employee.OfficeName = officeNames.GetValueOrDefault(employee.OfficeLocationID);
                }
                ViewBag.Employees = employees;
                ViewBag.Roles = _app.SelectModelList<RoleResponse>("Procs_GetRole", new { RoleID = (int?)null, IsActive = true, Search = (string?)null });
                var users = _app.SelectModelList<UserResponse>("Procs_GetUsers", new
                {
                    UserID = (int?)null, EmployeeID = employeeId, RoleID = roleId,
                    IsActive = isActive, Search = search
                }) ?? new List<UserResponse>();
                // KPI cards describe the whole account directory, not the
                // currently filtered result set.
                var allUsers = _app.SelectModelList<UserResponse>("Procs_GetUsers", new
                {
                    UserID = (int?)null, EmployeeID = (int?)null, RoleID = (int?)null,
                    IsActive = (bool?)null, Search = (string?)null
                }) ?? new List<UserResponse>();
                var employeeMap = employees.ToDictionary(x => x.EmployeeID);
                foreach (var user in users)
                {
                    if (employeeMap.TryGetValue(user.EmployeeID, out var employee))
                    {
                        user.ProfileImage = employee.ProfileImage;
                        user.DepartmentName = employee.DepartmentName;
                        user.DesignationName = employee.DesignationName;
                        user.OfficeName = employee.OfficeName;
                    }
                }
                ViewBag.Search = search;
                ViewBag.EmployeeId = employeeId;
                ViewBag.RoleId = roleId;
                ViewBag.IsActive = isActive;
                ViewBag.TotalAccounts = allUsers.Count;
                ViewBag.ActiveAccounts = allUsers.Count(x => x.IsActive);
                ViewBag.InactiveAccounts = allUsers.Count(x => !x.IsActive);
                return View(users);
            }
            catch (Exception)
            {
                ViewBag.Error = "Unable to load user accounts.";
                return View(new List<UserResponse>());
            }
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Create(UserRequest request)
        {
            if (request.EmployeeID <= 0 || request.RoleID < 0 || string.IsNullOrWhiteSpace(request.UserName))
            {
                TempData["UserError"] = "Employee, role, and username are required.";
                return RedirectToAction(nameof(Index));
            }

            // HR may provision HR, Manager, and Employee accounts, but cannot
            // create another Admin account. Admin retains full account access.
            if (!User.IsInRole("Admin") && request.RoleID == 0)
            {
                TempData["UserError"] = "Only an Admin can create an Admin account.";
                return RedirectToAction(nameof(Index));
            }

            var temporaryPassword = GenerateTemporaryPassword();
            try
            {
                var result = _app.SelectModel<ResultSet>("Procs_InsertUpdateDeleteUsers", new
                {
                    UserID = (int?)null,
                    EmployeeID = request.EmployeeID,
                    RoleID = request.RoleID,
                    PasswordHash = temporaryPassword,
                    PasswordSalt = (string?)null,
                    LastLogin = (DateTime?)null,
                    UserName = request.UserName.Trim(),
                    MobileNo = request.MobileNo,
                    Email = request.Email,
                    Mode = 1
                });

                if (result?.StatusCode == 200)
                {
                    // Development mode currently uses a plain temporary password.
                    // Do not call Procs_SetInitialPassword here: that procedure hashes
                    // the value and would make it incompatible with the current
                    // Procs_LoginUser plain-text comparison.
                    ViewBag.CreatedUsername = request.UserName.Trim();
                    ViewBag.TemporaryPassword = temporaryPassword;
                    return View("Created");
                }
                else
                {
                    TempData["UserError"] = result?.Message ?? "User account could not be created.";
                }
            }
            catch (Exception)
            {
                TempData["UserError"] = "Unable to create the user account.";
            }

            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Delete(int id)
        {
            try
            {
                var result = _app.SelectModel<ResultSet>("Procs_InsertUpdateDeleteUsers", new
                {
                    UserID = id, EmployeeID = (int?)null, RoleID = (int?)null,
                    PasswordHash = (string?)null, PasswordSalt = (string?)null,
                    LastLogin = (DateTime?)null, UserName = (string?)null,
                    MobileNo = (string?)null, Email = (string?)null, Mode = 3
                });
                TempData[result?.StatusCode == 200 ? "UserMessage" : "UserError"] = result?.Message ?? "Operation failed.";
            }
            catch (Exception)
            {
                TempData["UserError"] = "Unable to deactivate the user account.";
            }
            return RedirectToAction(nameof(Index));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Activate(int id)
        {
            try
            {
                var result = _app.SelectModel<ResultSet>("Procs_ActivateUser", new
                {
                    UserID = id
                });
                TempData[result?.StatusCode == 200 ? "UserMessage" : "UserError"] = result?.Message ?? "Operation failed.";
            }
            catch (Exception)
            {
                TempData["UserError"] = "Unable to activate the user account.";
            }
            return RedirectToAction(nameof(Index));
        }

        private static string GenerateTemporaryPassword()
        {
            const string chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#";
            Span<byte> bytes = stackalloc byte[16];
            RandomNumberGenerator.Fill(bytes);
            return "123";
        }

        private sealed class DepartmentLookup
        {
            public int Id { get; set; }
            public string? Name { get; set; }
        }
    }
}
