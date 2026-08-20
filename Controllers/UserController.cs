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
        public IActionResult Index(string? search)
        {
            try
            {
                ViewBag.Employees = _app.SelectModelList<EmployeeResponse>("Procs_GetEmployees", new
                {
                    EmployeeID = (int?)null, DepartmentID = (int?)null, DesignationID = (int?)null,
                    OfficeLocationID = (int?)null, ManagerID = (int?)null, ShiftID = (int?)null,
                    RoleID = (int?)null, IsActive = (bool?)null, Search = (string?)null
                });
                ViewBag.Roles = _app.SelectModelList<RoleResponse>("Procs_GetRole", new { RoleID = (int?)null, IsActive = true, Search = (string?)null });
                var users = _app.SelectModelList<UserResponse>("Procs_GetUsers", new
                {
                    UserID = (int?)null, EmployeeID = (int?)null, RoleID = (int?)null,
                    IsActive = (bool?)null, Search = search
                });
                ViewBag.Search = search;
                return View(users ?? new List<UserResponse>());
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
    }
}
