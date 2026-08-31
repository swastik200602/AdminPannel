using AdminPannel.Logic;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.IdentityModel.Tokens;
using System.IO;
using System.Security.Claims;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// Keep application diagnostics available in environments where the Windows
// EventLog provider is not writable (for example local development or a
// restricted service account). Console logging is portable and prevents a
// logging failure from taking down an otherwise healthy request pipeline.
builder.Logging.ClearProviders();
builder.Logging.AddConsole();

// Keep authentication/antiforgery keys in the application data directory so
// local service identities do not depend on another user's DPAPI key ring.
// In production this directory should be mapped to protected persistent
// storage shared by all application instances.
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo(Path.Combine(builder.Environment.ContentRootPath, ".keys")));

// Add services to the container.
builder.Services.AddControllersWithViews();

// DI registrations required by the Web API layer. AuthAPIController (and the
// upcoming EmployeeAPIController) receive these through their constructors,
// so the container must know how to build them. The MVC controllers create
// `new AppData()` directly, so they are unaffected by this addition.
builder.Services.AddScoped<AppData>();
builder.Services.AddScoped<ITokenService, TokenService>();

var jwtSettings = builder.Configuration.GetSection("Jwt");
var key = Encoding.UTF8.GetBytes(jwtSettings["Key"]);
// Database connection
ConnectHelper.Connect =
    builder.Configuration.GetConnectionString("DefaultConnection");

// Authentication. Cookies stay the DEFAULT scheme so the MVC website keeps
// working exactly as before. JWT bearer is added as a SECOND scheme that the
// API controllers opt into via [Authorize(AuthenticationSchemes = "Bearer")].
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/Account/Login";
        options.AccessDeniedPath = "/Account/AccessDenied";

        options.ExpireTimeSpan = TimeSpan.FromMinutes(30);
        options.SlidingExpiration = true;
        options.Cookie.HttpOnly = true;
        options.Cookie.SecurePolicy = CookieSecurePolicy.SameAsRequest;
    })
    .AddJwtBearer(JwtBearerDefaults.AuthenticationScheme, options =>
    {
        // Validate every incoming Bearer token against the SAME values that
        // Logic/TokenService.cs uses to sign it. If any of these disagree
        // (issuer, audience, signature, expiry) the token is rejected with 401.
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtSettings["Issuer"],
            ValidAudience = jwtSettings["Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(key),
            RoleClaimType = ClaimTypes.Role
        };
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy(AuthorizationPolicies.AdminOnly,
        policy => policy.RequireRole("Admin"));

    options.AddPolicy(AuthorizationPolicies.HrAccess,
        policy => policy.RequireRole("Admin", "HR"));

    options.AddPolicy(AuthorizationPolicies.ManagerAccess,
        policy => policy.RequireRole("Admin", "Manager"));

    options.AddPolicy(AuthorizationPolicies.EmployeeAccess,
        policy => policy.RequireRole("Admin", "Employee"));

    options.AddPolicy(AuthorizationPolicies.UserManagement,
        policy => policy.RequireRole("Admin", "HR"));
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();

// Serve runtime-uploaded files under wwwroot (e.g. /uploads/employees/*.png).
// MapStaticAssets() below only serves build-time known assets from its manifest,
// so uploaded profile images are not reachable without this.
app.UseStaticFiles();

app.UseRouting();

// IMPORTANT: Authentication must come before Authorization
app.UseAuthentication();
app.UseAuthorization();

app.MapStaticAssets();

// Attribute-routed controllers (the API lives here, e.g. POST api/AuthAPI/Login).
app.MapControllers();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Account}/{action=Index}/{id?}")
    .WithStaticAssets();

app.Run();
