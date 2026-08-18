using AdminPannel.Logic;
using AdminPannel.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AdminPannel.Controllers
{
    public class AccountController : Controller
    {
        private readonly AppData _objapp;
        private readonly ILogger<AccountController> _logger;

        public AccountController(ILogger<AccountController> logger)
        {
            _objapp = new AppData();
            _logger = logger;
        }

        // Login Page
        [HttpGet]
        public IActionResult Index()
        {
            // Already logged in
            if (User.Identity?.IsAuthenticated == true)
            {
                return RedirectToAction("Index", "Home");
            }

            return View(new AdminModel());
        }

        [HttpGet]
        public IActionResult Login()
        {
            if (User.Identity?.IsAuthenticated == true)
            {
                return RedirectToAction("Index", "Home");
            }

            return View("Index", new AdminModel());
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Login(AdminModel model)
        {
            if (string.IsNullOrWhiteSpace(model.UserName) ||
                string.IsNullOrWhiteSpace(model.PasswordHash))
            {
                ViewBag.Error = "Username and password are required.";
                model.PasswordHash = null;
                return View("Index", model);
            }

            try
            {
                var parameter = new
                {
                    UserName = model.UserName.Trim(),
                    PasswordHash = model.PasswordHash
                };

                var result = _objapp.SelectModel<LoginResponse>(
                    "Procs_LoginUser",
                    parameter
                );

                if (result == null)
                {
                    ViewBag.Error = "Unable to process login.";
                    model.PasswordHash = null;
                    return View("Index", model);
                }

                if (result.StatusCode != 200)
                {
                    ViewBag.Error = result.Message;
                    model.PasswordHash = null;
                    return View("Index", model);
                }

                // Claims
                var claims = new List<Claim>
                {
                    new Claim(ClaimTypes.NameIdentifier, result.UserID.ToString()),
                    new Claim(ClaimTypes.Name, result.UserName ?? ""),
                    new Claim(ClaimTypes.Role, result.RoleName ?? ""),

                    new Claim("UserID", result.UserID.ToString()),
                    new Claim("EmployeeID", result.EmployeeID.ToString()),
                    new Claim("RoleID", result.RoleID.ToString()),
                    new Claim("UserName", result.UserName ?? ""),
                    new Claim("RoleName", result.RoleName ?? ""),

                    new Claim("EmployeeCode", result.EmployeeCode ?? ""),
                    new Claim("FirstName", result.FirstName ?? ""),
                    new Claim("LastName", result.LastName ?? ""),
                    new Claim(ClaimTypes.Email, result.Email ?? ""),
                    new Claim("Email", result.Email ?? "")
                };

                var identity = new ClaimsIdentity(
                    claims,
                    CookieAuthenticationDefaults.AuthenticationScheme
                );

                var principal = new ClaimsPrincipal(identity);

                var authenticationProperties = new AuthenticationProperties
                {
                    IsPersistent = model.RememberMe
                };

                if (model.RememberMe)
                {
                    authenticationProperties.ExpiresUtc = DateTimeOffset.UtcNow.AddMinutes(30);
                }

                await HttpContext.SignInAsync(
                    CookieAuthenticationDefaults.AuthenticationScheme,
                    principal,
                    authenticationProperties
                );

                if (result.MustChangePassword)
                    return RedirectToAction(nameof(ChangePassword));

                return RedirectToAction("Index", "Home");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unable to complete login for {UserName}", model.UserName);
                ViewBag.Error = "Unable to connect to the database. Please try again later.";
                model.PasswordHash = null;
                return View("Index", model);
            }
        }

        [HttpGet]
        public IActionResult AccessDenied()
        {
            return View();
        }

        [HttpGet]
        [Authorize]
        public IActionResult ChangePassword() => View(new ChangePasswordRequest());

        [HttpPost]
        [Authorize]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ChangePassword(ChangePasswordRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.CurrentPassword) ||
                string.IsNullOrWhiteSpace(request.NewPassword) ||
                request.NewPassword != request.ConfirmPassword ||
                request.NewPassword.Length < 8)
            {
                ModelState.AddModelError(string.Empty, "Enter the current password, and a new password of at least 8 characters that matches confirmation.");
                return View(request);
            }

            if (!int.TryParse(User.FindFirst("UserID")?.Value, out var userId))
                return Forbid();

            try
            {
                var result = _objapp.SelectModel<ResultSet>("Procs_ChangeUserPassword", new
                {
                    UserID = userId,
                    CurrentPassword = request.CurrentPassword,
                    NewPassword = request.NewPassword
                });
                if (result?.StatusCode != 200)
                {
                    ModelState.AddModelError(string.Empty, result?.Message ?? "Password could not be changed.");
                    return View(request);
                }

                await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
                TempData["Message"] = "Password changed successfully. Please sign in again.";
                return RedirectToAction(nameof(Index));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Password change failed for user {UserID}", userId);
                ModelState.AddModelError(string.Empty, "Unable to change the password right now.");
                return View(request);
            }
        }

        // Logout
        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize]
        public async Task<IActionResult> Logout()
        {
            await HttpContext.SignOutAsync(
                CookieAuthenticationDefaults.AuthenticationScheme
            );

            return RedirectToAction("Index", "Account");
        }
    }
}
