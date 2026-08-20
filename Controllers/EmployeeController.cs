using AdminPannel.Logic;
using AdminPannel.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.AspNetCore.Hosting;
using System.ComponentModel.DataAnnotations;

namespace AdminPannel.Controllers
{
    [Authorize]
    public class EmployeeController : Controller
    {
        private readonly AppData _objapp = new();
        private readonly ILogger<EmployeeController> _logger;
        private bool IsAdminOrHr => User.IsInRole("Admin") || User.IsInRole("HR");

        public EmployeeController(ILogger<EmployeeController> logger)
        {
            _logger = logger;
        }

        [HttpGet]
        public IActionResult Index(EmployeeFilterRequest filter)
        {
            try
            {
                ApplyScope(filter);
                var model = BuildPageModel(filter);
                return View(model);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to load employee page.");
                ViewBag.Error = HttpContext.RequestServices.GetRequiredService<IWebHostEnvironment>().IsDevelopment()
                    ? $"Unable to load employees: {ex.Message}"
                    : "Unable to load employees. Please try again later.";
                return View(new EmployeePageModel { Filter = filter });
            }
        }

        [HttpGet]
        public IActionResult Rows(EmployeeFilterRequest filter)
        {
            try
            {
                ApplyScope(filter);
                return PartialView("_EmployeeRows", LoadEmployees(filter));
            }
            catch (Exception)
            {
                return BadRequest("Unable to load employees.");
            }
        }

        [HttpGet]
        public IActionResult Details(int id)
        {
            if (!TryGetEditableEmployee(id, out var employee))
                return NotFound();

            EnrichEmployeeNames(new List<EmployeeResponse> { employee! });

            if (!CanAccess(employee!))
                return Forbid();

            return View("_Details", employee);
        }

        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.HrAccess)]
        public IActionResult Create()
        {
            PopulateFormLookups();
            return View("_CreateEdit", new EmployeeRequest());
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Policy = AuthorizationPolicies.HrAccess)]
        public IActionResult Create(EmployeeRequest request)
        {
            if (!User.IsInRole("Admin") && request.RoleID == 0)
            {
                ModelState.AddModelError(nameof(request.RoleID), "Only an Admin can assign the Admin role.");
            }
            request.ProfileImage = null;
            if (!ValidateEmployeeRequest(request))
            {
                PopulateFormLookups();
                return View("_CreateEdit", request);
            }

            try
            {
                request.EmployeeID = 0;
                request.IsActive = true;
                request.ProfileImage = SaveProfileImage(request.ProfileImageFile);
                var result = _objapp.SelectModel<ResultSet>(
                    "Procs_InsertUpdateDeleteEmployee",
                    ToProcedureParameters(request, 1));

                if (result?.StatusCode == 200)
                    return RedirectToAction(nameof(Index));

                ModelState.AddModelError(string.Empty, result?.Message ?? "Employee could not be created.");
            }
            catch (Exception)
            {
                ModelState.AddModelError(string.Empty, "Unable to save the employee. Please try again later.");
            }

            PopulateFormLookups();
            return View("_CreateEdit", request);
        }

        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.HrAccess)]
        public IActionResult Edit(int id)
        {
            if (!TryGetEditableEmployee(id, out var employee))
                return NotFound();

            PopulateFormLookups();
            return View("_CreateEdit", ToRequest(employee!));
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Policy = AuthorizationPolicies.HrAccess)]
        public IActionResult Edit(int id, EmployeeRequest request)
        {
            if (!TryGetEditableEmployee(id, out var existing))
                return NotFound();

            request.RoleID = User.IsInRole("Admin") ? request.RoleID : existing!.RoleID;
            request.ProfileImage = existing!.ProfileImage;

            if (!ValidateEmployeeRequest(request))
            {
                request.EmployeeID = id;
                PopulateFormLookups();
                return View("_CreateEdit", request);
            }

            try
            {
                request.EmployeeID = id;
                request.IsActive = existing!.IsActive;
                request.ProfileImage = SaveProfileImage(request.ProfileImageFile) ?? existing.ProfileImage;
                var result = _objapp.SelectModel<ResultSet>(
                    "Procs_InsertUpdateDeleteEmployee",
                    ToProcedureParameters(request, 2));

                if (result?.StatusCode == 200)
                    return RedirectToAction(nameof(Index));

                ModelState.AddModelError(string.Empty, result?.Message ?? "Employee could not be updated.");
            }
            catch (Exception)
            {
                ModelState.AddModelError(string.Empty, "Unable to save the employee. Please try again later.");
            }

            request.EmployeeID = id;
            PopulateFormLookups();
            return View("_CreateEdit", request);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [Authorize(Policy = AuthorizationPolicies.HrAccess)]
        public IActionResult Delete(int id)
        {
            if (!TryGetEditableEmployee(id, out var employee))
                return NotFound();

            try
            {
                var result = _objapp.SelectModel<ResultSet>(
                    "Procs_InsertUpdateDeleteEmployee",
                    ToProcedureParameters(ToRequest(employee!), 3));

                if (result?.StatusCode == 200)
                    return RedirectToAction(nameof(Index));

                TempData["EmployeeError"] = result?.Message ?? "Employee could not be deleted.";
            }
            catch (Exception)
            {
                TempData["EmployeeError"] = "Unable to delete the employee. Please try again later.";
            }

            return RedirectToAction(nameof(Index));
        }

        [HttpGet]
        public IActionResult EditSelf()
        {
            if (!TryGetCurrentEmployeeId(out var employeeId))
                return Forbid();

            if (!TryGetEditableEmployee(employeeId, out var employee))
                return NotFound();

            if (!User.IsInRole("Employee"))
                return Forbid();

            return View(new EmployeeSelfServiceRequest
            {
                Email = employee!.Email,
                PhoneNumber = employee.PhoneNumber,
                EmergencyContact = employee.EmergencyContact,
                Address = employee.Address,
                City = employee.City,
                State = employee.State,
                Country = employee.Country,
                PostalCode = employee.PostalCode
            });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult EditSelf(EmployeeSelfServiceRequest request)
        {
            if (!User.IsInRole("Employee") || !TryGetCurrentEmployeeId(out var employeeId))
                return Forbid();

            if (!ValidateSelfServiceRequest(request))
                return View(request);

            if (!TryGetEditableEmployee(employeeId, out var existing))
                return NotFound();

            try
            {
                var merged = ToRequest(existing!);
                merged.Email = request.Email;
                merged.PhoneNumber = request.PhoneNumber;
                merged.EmergencyContact = request.EmergencyContact;
                merged.Address = request.Address;
                merged.City = request.City;
                merged.State = request.State;
                merged.Country = request.Country;
                merged.PostalCode = request.PostalCode;

                var result = _objapp.SelectModel<ResultSet>(
                    "Procs_InsertUpdateDeleteEmployee",
                    ToProcedureParameters(merged, 2));

                if (result?.StatusCode == 200)
                    return RedirectToAction(nameof(Details), new { id = employeeId });

                ModelState.AddModelError(string.Empty, result?.Message ?? "Profile could not be updated.");
            }
            catch (Exception)
            {
                ModelState.AddModelError(string.Empty, "Unable to update your profile. Please try again later.");
            }

            return View(request);
        }

        private EmployeePageModel BuildPageModel(EmployeeFilterRequest filter)
        {
            var model = new EmployeePageModel
            {
                Filter = filter,
                Employees = LoadEmployees(filter)
            };

            if (IsAdminOrHr)
            {
                model.Departments = LoadDepartmentLookups();
                model.Designations = _objapp.SelectModelList<DesignationResponse>(
                    "Procs_GetDesignation", new { DesignationID = (int?)null, IsActive = true, Search = (string?)null });
                model.OfficeBranches = _objapp.SelectModelList<OfficeBranchResponse>(
                    "Procs_GetOfficeBranch", new { OfficeLocationID = (int?)null, IsActive = true, Search = (string?)null });
                model.Shifts = _objapp.SelectModelList<ShiftResponse>(
                    "Procs_GetShift", new { ShiftID = (int?)null, IsActive = true, Search = (string?)null });
                model.Roles = _objapp.SelectModelList<RoleResponse>(
                    "Procs_GetRole", new { RoleID = (int?)null, IsActive = true, Search = (string?)null });
                model.Managers = LoadEmployees(new EmployeeFilterRequest { IsActive = true });
            }

            return model;
        }

        private void PopulateFormLookups()
        {
            ViewBag.Departments = LoadDepartmentLookups();
            ViewBag.Designations = _objapp.SelectModelList<DesignationResponse>(
                "Procs_GetDesignation", new { DesignationID = (int?)null, IsActive = true, Search = (string?)null });
            ViewBag.OfficeBranches = _objapp.SelectModelList<OfficeBranchResponse>(
                "Procs_GetOfficeBranch", new { OfficeLocationID = (int?)null, IsActive = true, Search = (string?)null });
            ViewBag.Shifts = _objapp.SelectModelList<ShiftResponse>(
                "Procs_GetShift", new { ShiftID = (int?)null, IsActive = true, Search = (string?)null });
            ViewBag.Roles = _objapp.SelectModelList<RoleResponse>(
                "Procs_GetRole", new { RoleID = (int?)null, IsActive = true, Search = (string?)null });
            ViewBag.Managers = LoadEmployees(new EmployeeFilterRequest { IsActive = true });
        }

        private List<EmployeeResponse> LoadEmployees(EmployeeFilterRequest filter)
        {
            var result = _objapp.SelectModelList<EmployeeResponse>(
                "Procs_GetEmployees",
                new
                {
                    EmployeeID = filter.EmployeeID,
                    DepartmentID = filter.DepartmentID,
                    DesignationID = filter.DesignationID,
                    OfficeLocationID = filter.OfficeLocationID,
                    ManagerID = filter.ManagerID,
                    ShiftID = filter.ShiftID,
                    IsActive = filter.IsActive,
                    Search = filter.Search
                });

            var employees = result ?? new List<EmployeeResponse>();
            if (filter.RoleID.HasValue)
                employees = employees.Where(x => x.RoleID == filter.RoleID.Value).ToList();
            EnrichEmployeeNames(employees);
            return employees;
        }

        private void EnrichEmployeeNames(List<EmployeeResponse> employees)
        {
            if (employees.Count == 0)
                return;

            var departments = LoadDepartmentLookups();
            var designations = _objapp.SelectModelList<DesignationResponse>(
                "Procs_GetDesignation", new { DesignationID = (int?)null, IsActive = true, Search = (string?)null });
            var allEmployees = _objapp.SelectModelList<EmployeeResponse>(
                "Procs_GetEmployees",
                new
                {
                    EmployeeID = (int?)null,
                    DepartmentID = (int?)null,
                    DesignationID = (int?)null,
                    OfficeLocationID = (int?)null,
                    ManagerID = (int?)null,
                    ShiftID = (int?)null,
                    IsActive = (bool?)null,
                    Search = (string?)null
                });

            var departmentNames = departments
                .Where(x => x.DepartmentID > 0)
                .GroupBy(x => x.DepartmentID)
                .ToDictionary(x => x.Key, x => x.First().DepartmentName);
            var designationNames = (designations ?? new List<DesignationResponse>())
                .Where(x => x.DesignationID > 0)
                .GroupBy(x => x.DesignationID)
                .ToDictionary(x => x.Key, x => x.First().DesignationName);
            var employeeNames = (allEmployees ?? new List<EmployeeResponse>())
                .ToDictionary(x => x.EmployeeID, x => x.FullName);

            foreach (var employee in employees)
            {
                employee.DepartmentName = departmentNames.GetValueOrDefault(employee.DepartmentID);
                employee.DesignationName = designationNames.GetValueOrDefault(employee.DesignationID);
                if (employee.ManagerID.HasValue)
                    employee.ManagerName = employeeNames.GetValueOrDefault(employee.ManagerID.Value);
            }
        }

        private void ApplyScope(EmployeeFilterRequest filter)
        {
            if (User.IsInRole("Manager"))
            {
                if (!TryGetCurrentEmployeeId(out var employeeId))
                    throw new InvalidOperationException("The current manager has no employee identity.");

                filter.EmployeeID = null;
                filter.ManagerID = employeeId;
            }
            else if (User.IsInRole("Employee"))
            {
                if (!TryGetCurrentEmployeeId(out var employeeId))
                    throw new InvalidOperationException("The current employee has no employee identity.");

                filter.EmployeeID = employeeId;
                filter.ManagerID = null;
                filter.DepartmentID = null;
                filter.DesignationID = null;
                filter.OfficeLocationID = null;
                filter.ShiftID = null;
            }
        }

        private bool CanAccess(EmployeeResponse employee)
        {
            if (IsAdminOrHr)
                return true;

            if (User.IsInRole("Manager") && TryGetCurrentEmployeeId(out var managerId))
                return employee.ManagerID == managerId;

            if (User.IsInRole("Employee") && TryGetCurrentEmployeeId(out var employeeId))
                return employee.EmployeeID == employeeId;

            return false;
        }

        private bool TryGetDetails(int id, out EmployeeResponse? employee)
        {
            employee = _objapp.SelectModel<EmployeeResponse>(
                "Procs_GetEmployeeDetails", new { EmployeeID = id });

            return employee != null && employee.StatusCode != 404 && employee.EmployeeID == id;
        }

        private List<DepartmentResponse> LoadDepartmentLookups()
        {
            var rows = _objapp.SelectModelList<DepartmentLookup>(
                "Procs_GetDepartment", new { DepartmentID = 0, Mode = 3 });

            return (rows ?? new List<DepartmentLookup>())
                .Where(x => x.Id > 0)
                .GroupBy(x => x.Id)
                .Select(x => new DepartmentResponse
                {
                    DepartmentID = x.Key,
                    DepartmentName = x.First().Name
                })
                .ToList();
        }

        private sealed class DepartmentLookup
        {
            public int Id { get; set; }
            public string? Name { get; set; }
        }

        private bool TryGetEditableEmployee(int id, out EmployeeResponse? employee)
        {
            var employees = _objapp.SelectModelList<EmployeeResponse>(
                "Procs_GetEmployees",
                new
                {
                    EmployeeID = id,
                    DepartmentID = (int?)null,
                    DesignationID = (int?)null,
                    OfficeLocationID = (int?)null,
                    ManagerID = (int?)null,
                    ShiftID = (int?)null,
                    IsActive = (bool?)null,
                    Search = (string?)null
                });
            employee = employees?.FirstOrDefault(x => x.EmployeeID == id);
            return employee != null;
        }

        private bool TryGetCurrentEmployeeId(out int employeeId)
        {
            return int.TryParse(User.FindFirst("EmployeeID")?.Value, out employeeId) && employeeId > 0;
        }

        private static EmployeeRequest ToRequest(EmployeeResponse employee)
        {
            return new EmployeeRequest
            {
                EmployeeID = employee.EmployeeID,
                EmployeeCode = employee.EmployeeCode,
                FirstName = employee.FirstName,
                LastName = employee.LastName,
                Gender = employee.Gender,
                DateOfBirth = employee.DateOfBirth,
                Email = employee.Email,
                PhoneNumber = employee.PhoneNumber,
                EmergencyContact = employee.EmergencyContact,
                Address = employee.Address,
                City = employee.City,
                State = employee.State,
                Country = employee.Country,
                PostalCode = employee.PostalCode,
                DepartmentID = employee.DepartmentID,
                DesignationID = employee.DesignationID,
                OfficeLocationID = employee.OfficeLocationID,
                ManagerID = employee.ManagerID,
                JoiningDate = employee.JoiningDate,
                EmploymentType = employee.EmploymentType,
                BasicSalary = employee.BasicSalary,
                ShiftID = employee.ShiftID,
                RoleID = employee.RoleID,
                ProfileImage = employee.ProfileImage,
                IsActive = employee.IsActive
            };
        }

        private static object ToProcedureParameters(EmployeeRequest request, int mode)
        {
            return new
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
        }

        private string? SaveProfileImage(IFormFile? file)
        {
            if (file == null || file.Length == 0)
                return null;

            var allowed = new[] { ".jpg", ".jpeg", ".png", ".webp" };
            var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
            if (!allowed.Contains(extension) || file.Length > 5 * 1024 * 1024)
                throw new InvalidOperationException("Profile image must be JPG, PNG, or WEBP and smaller than 5 MB.");

            var folder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "employees");
            Directory.CreateDirectory(folder);
            var fileName = $"{Guid.NewGuid():N}{extension}";
            using var stream = System.IO.File.Create(Path.Combine(folder, fileName));
            file.CopyTo(stream);
            return $"/uploads/employees/{fileName}";
        }

        private bool ValidateEmployeeRequest(EmployeeRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.EmployeeCode)) ModelState.AddModelError("EmployeeCode", "Employee code is required.");
            if (string.IsNullOrWhiteSpace(request.FirstName)) ModelState.AddModelError("FirstName", "First name is required.");
            if (string.IsNullOrWhiteSpace(request.LastName)) ModelState.AddModelError("LastName", "Last name is required.");
            if (string.IsNullOrWhiteSpace(request.Email) || !new EmailAddressAttribute().IsValid(request.Email)) ModelState.AddModelError("Email", "A valid email is required.");
            if (string.IsNullOrWhiteSpace(request.PhoneNumber)) ModelState.AddModelError("PhoneNumber", "Phone number is required.");
            if (string.IsNullOrWhiteSpace(request.Address)) ModelState.AddModelError("Address", "Address is required.");
            if (string.IsNullOrWhiteSpace(request.City)) ModelState.AddModelError("City", "City is required.");
            if (string.IsNullOrWhiteSpace(request.State)) ModelState.AddModelError("State", "State is required.");
            if (string.IsNullOrWhiteSpace(request.Country)) ModelState.AddModelError("Country", "Country is required.");
            if (string.IsNullOrWhiteSpace(request.PostalCode)) ModelState.AddModelError("PostalCode", "Postal code is required.");
            if (request.DepartmentID <= 0) ModelState.AddModelError("DepartmentID", "Department is required.");
            if (request.DesignationID <= 0) ModelState.AddModelError("DesignationID", "Designation is required.");
            if (request.OfficeLocationID <= 0) ModelState.AddModelError("OfficeLocationID", "Office branch is required.");
            if (!request.JoiningDate.HasValue) ModelState.AddModelError("JoiningDate", "Joining date is required.");
            if (string.IsNullOrWhiteSpace(request.EmploymentType)) ModelState.AddModelError("EmploymentType", "Employment type is required.");
            if (request.BasicSalary < 0) ModelState.AddModelError("BasicSalary", "Salary cannot be negative.");
            if (User.IsInRole("Admin") && request.RoleID <= 0) ModelState.AddModelError("RoleID", "Role is required.");
            return ModelState.IsValid;
        }

        private bool ValidateSelfServiceRequest(EmployeeSelfServiceRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Email) || !new EmailAddressAttribute().IsValid(request.Email))
                ModelState.AddModelError("Email", "A valid email is required.");
            if (string.IsNullOrWhiteSpace(request.PhoneNumber)) ModelState.AddModelError("PhoneNumber", "Phone number is required.");
            if (string.IsNullOrWhiteSpace(request.Address)) ModelState.AddModelError("Address", "Address is required.");
            if (string.IsNullOrWhiteSpace(request.City)) ModelState.AddModelError("City", "City is required.");
            if (string.IsNullOrWhiteSpace(request.State)) ModelState.AddModelError("State", "State is required.");
            if (string.IsNullOrWhiteSpace(request.Country)) ModelState.AddModelError("Country", "Country is required.");
            if (string.IsNullOrWhiteSpace(request.PostalCode)) ModelState.AddModelError("PostalCode", "Postal code is required.");
            return ModelState.IsValid;
        }
    }
}
