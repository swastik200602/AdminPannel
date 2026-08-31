using AdminPannel.Logic;
using AdminPannel.Models;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AdminPannel.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthAPIController : ControllerBase
    {
        private readonly ITokenService _tokenService;
        private readonly AppData _appData;

        public AuthAPIController(ITokenService tokenService, AppData appData)
        {
            _tokenService = tokenService;
            _appData = appData;
        }

        // POST api/AuthAPI/Login
        [HttpPost("Login")]
        [AllowAnonymous]
        public IActionResult Login([FromBody] ApiLoginRequest req)
        {
            if (req is null ||
                string.IsNullOrWhiteSpace(req.UserName) ||
                string.IsNullOrWhiteSpace(req.Password))
            {
                return BadRequest(new { statusCode = 400, message = "Username and password are required." });
            }

            try
            {
                // Same call the working MVC login uses (AccountController.Login).
                // The parameter names MUST match the stored-procedure parameters
                // @UserName and @PasswordHash. Password is compared as plain text
                // by the procedure in the current development setup.
                var parameter = new
                {
                    UserName = req.UserName.Trim(),
                    PasswordHash = req.Password
                };

                var result = _appData.SelectModel<LoginResponse>("Procs_LoginUser", parameter);

                if (result is null || result.StatusCode != 200)
                {
                    return Unauthorized(new
                    {
                        statusCode = 401,
                        message = result?.Message ?? "Invalid username or password."
                    });
                }

                // The role claim carries the ROLE NAME ("Admin"/"HR"/...), not the
                // numeric RoleID, so that [Authorize(Roles = "Admin")] and the role
                // policies match — exactly like the cookie login's ClaimTypes.Role.
                var token = _tokenService.CreateToken(
                    userId: result.UserID.ToString(),
                    custId: result.EmployeeID.ToString(),
                    roles: new[] { result.RoleName ?? string.Empty });

                var data = new LoginApiResponse
                {
                    UserID = result.UserID,
                    EmployeeID = result.EmployeeID,
                    RoleID = result.RoleID,
                    RoleName = result.RoleName,
                    UserName = result.UserName,
                    Email = result.Email,
                    Token = token,
                    TokenType = "Bearer",
                    ExpiresIn = 3600
                };

                return Ok(new { statusCode = 200, message = "Login Success..!", data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { statusCode = 500, message = "Server error", detail = ex.Message });
            }
        }

        // GET api/AuthAPI/private
        // Quick smoke test that a valid Bearer token is accepted by the JWT scheme.
        [HttpGet("private")]
        [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
        public IActionResult Private()
        {
            return Ok(new
            {
                statusCode = 200,
                message = "You are authorized.",
                userId = User.FindFirst("UserId")?.Value,
                role = User.FindFirst(ClaimTypes.Role)?.Value
            });
        }
    }
}
