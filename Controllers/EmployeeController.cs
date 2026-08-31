using AdminPannel.Logic;
using AdminPannel.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.AspNetCore.Hosting;
using System.ComponentModel.DataAnnotations;
using System.Text.RegularExpressions;

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
        [Authorize(Policy = AuthorizationPolicies.HrAccess)]
        public IActionResult Managers(int departmentId, int officeLocationId, int? excludeEmployeeId = null)
        {
            if (departmentId <= 0 || officeLocationId <= 0)
                return Json(Array.Empty<object>());

            var managers = LoadEmployees(new EmployeeFilterRequest
            {
                DepartmentID = departmentId,
                OfficeLocationID = officeLocationId,
                IsActive = true
            })
            .Where(x => string.Equals(x.RoleName, "Manager", StringComparison.OrdinalIgnoreCase))
            .Where(x => !excludeEmployeeId.HasValue || x.EmployeeID != excludeEmployeeId.Value)
            .Select(x => new { id = x.EmployeeID, name = string.IsNullOrWhiteSpace(x.FullName) ? x.EmployeeCode : x.FullName, code = x.EmployeeCode })
            .ToList();
            return Json(managers);
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
            if (string.IsNullOrWhiteSpace(request.EmployeeCode))
            {
                try { request.EmployeeCode = GenerateEmployeeCode(); }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Employee-code generator is unavailable.");
                    ModelState.AddModelError(string.Empty, "Employee-code generation is not configured. Execute Database/EmployeeCode_Migration.sql, then try again.");
                }
            }
            if (!User.IsInRole("Admin") && request.RoleID == 0)
            {
                ModelState.AddModelError(nameof(request.RoleID), "Only an Admin can assign the Admin role.");
            }
            request.ProfileImage = null;
            if (!ValidateEmployeeRequest(request, isCreate: true))
            {
                PopulateFormLookups(request);
                return View("_CreateEdit", request);
            }

            try
            {
                request.EmployeeID = 0;
                request.IsActive = true;
                request.BasicSalary = 0;
                request.ProfileImage = SaveProfileImage(request.ProfileImageFile);
                var result = _objapp.SelectModel<ResultSet>(
                    "Procs_InsertUpdateDeleteEmployee",
                    ToProcedureParameters(request, 1));

                if (result?.StatusCode == 200)
                {
                    var employeeId = FindEmployeeId(request.EmployeeCode);
                    return employeeId > 0
                        ? RedirectToAction(nameof(Onboarding), new { employeeId })
                        : RedirectToAction(nameof(Index));
                }

                ModelState.AddModelError(string.Empty, result?.Message ?? "Employee could not be created.");
            }
            catch (Exception)
            {
                ModelState.AddModelError(string.Empty, "Unable to save the employee. Please try again later.");
            }

            PopulateFormLookups(request);
            return View("_CreateEdit", request);
        }

        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.HrAccess)]
        public IActionResult Edit(int id)
        {
            if (!TryGetEditableEmployee(id, out var employee))
                return NotFound();

            var model = ToRequest(employee!);
            PopulateFormLookups(model);
            return View("_CreateEdit", model);
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
            request.BasicSalary = existing.BasicSalary;
            // JoiningDate is historical employment data. It is editable during
            // onboarding/create only; preserve the persisted value on profile edits.
            request.JoiningDate = existing.JoiningDate;

            if (!ValidateEmployeeRequest(request, isCreate: false))
            {
                request.EmployeeID = id;
                PopulateFormLookups(request);
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
            PopulateFormLookups(request);
            return View("_CreateEdit", request);
        }

        [HttpGet("Employees/Onboarding/{employeeId:int}")]
        [Authorize(Policy = AuthorizationPolicies.HrAccess)]
        public IActionResult Onboarding(int employeeId)
        {
            if (!TryGetEditableEmployee(employeeId, out var employee) || employee == null)
                return NotFound();

            EnrichEmployeeNames(new List<EmployeeResponse> { employee });

            var salary = _objapp.SelectModelList<SalaryMasterModel>("Procs_GetSalaryMaster", new
            {
                EmployeeID = employeeId, SalaryMasterID = (int?)null, IsActive = (bool?)true
            }) ?? new List<SalaryMasterModel>();
            var tax = _objapp.SelectModelList<TaxMasterModel>("Procs_GetTaxMaster", new
            {
                TaxMasterID = (int?)null, EmployeeID = employeeId, TaxType = (string?)null, IsActive = (bool?)true
            }) ?? new List<TaxMasterModel>();
            var users = _objapp.SelectModelList<UserResponse>("Procs_GetUsers", new
            {
                UserID = (int?)null, EmployeeID = employeeId, RoleID = (int?)null,
                IsActive = (bool?)null, Search = (string?)null
            }) ?? new List<UserResponse>();

            var documents = LoadDocuments(employeeId);

            var employmentComplete = employee.DepartmentID > 0 && employee.DesignationID > 0 &&
                employee.OfficeLocationID > 0 && employee.JoiningDate.HasValue &&
                !string.IsNullOrWhiteSpace(employee.EmploymentType) && employee.RoleID >= 0;
            var steps = new List<OnboardingStepModel>
            {
                new() { Key = "profile", Title = "Employee Profile", Description = "Personal and contact information", Status = "Complete", ActionText = "Review profile", ActionController = "Employee", ActionName = "Details" },
                new() { Key = "documents", Title = "Documents", Description = "Store and track employee identity, qualification and compliance documents", Status = documents.Any() ? "Complete" : "Optional", ActionText = "Manage documents", ActionController = "Employee", ActionName = "Documents" },
                new() { Key = "employment", Title = "Employment Setup", Description = "Department, designation, branch, manager, role and shift", Status = employmentComplete ? "Complete" : "Missing", ActionText = "Edit employment", ActionController = "Employee", ActionName = "Edit" },
                new() { Key = "salary", Title = "Salary Structure", Description = "Create the effective salary record used by payroll", Status = salary.Any() ? "Complete" : "Missing", ActionText = salary.Any() ? "View salary" : "Set salary", ActionController = "Payroll", ActionName = salary.Any() ? "SalaryHistory" : "CreateSalaryRevision" },
                new() { Key = "tax", Title = "Tax & Statutory", Description = "Tax is optional when no tax configuration is required", Status = tax.Any() ? "Complete" : "Optional", ActionText = tax.Any() ? "View tax" : "Configure tax", ActionController = "Payroll", ActionName = tax.Any() ? "TaxHistory" : "CreateTaxRevision" },
                new() { Key = "account", Title = "User Account", Description = "Login account linked to this employee", Status = users.Any(x => x.IsActive) ? "Complete" : "Missing", ActionText = users.Any(x => x.IsActive) ? "View account" : "Create account", ActionController = "User", ActionName = "Index" },
            };
            var requiredReady = steps.Where(x => !x.IsOptional).All(x => x.IsComplete);
            steps.Add(new OnboardingStepModel { Key = "review", Title = "Final Review", Description = "Confirm the onboarding setup", Status = requiredReady ? "Complete" : "Missing", ActionText = "Review setup" });
            steps.Add(new OnboardingStepModel { Key = "ready", Title = "Ready for Payroll", Description = "Payroll can be generated after required setup is complete", Status = requiredReady ? "Complete" : "Missing", ActionText = requiredReady ? "Ready" : "Complete required steps" });

            return View(new EmployeeOnboardingModel { Employee = employee, Steps = steps, Documents = documents });
        }

        private List<EmployeeDocumentModel> LoadDocuments(int employeeId)
        {
            return _objapp.QueryList<EmployeeDocumentModel>(
                "SELECT DocumentID, EmployeeID, DocumentType, DocumentName, FilePath, FileExtension, FileSizeKB, UploadedDate, ExpiryDate, IsVerified, Remarks FROM dbo.T_EmployeeDocument WHERE EmployeeID = @EmployeeID ORDER BY UploadedDate DESC, DocumentID DESC",
                new { EmployeeID = employeeId });
        }

        [HttpGet("Employees/Onboarding/{employeeId:int}/Documents")]
        [Authorize(Policy = AuthorizationPolicies.HrAccess)]
        public IActionResult Documents(int employeeId)
        {
            if (!TryGetEditableEmployee(employeeId, out var employee) || employee == null)
                return NotFound();
            EnrichEmployeeNames(new List<EmployeeResponse> { employee });
            return View(new EmployeeDocumentsPageModel { Employee = employee, Documents = LoadDocuments(employeeId) });
        }

        [HttpPost("Employees/Onboarding/{employeeId:int}/Documents")]
        [ValidateAntiForgeryToken]
        [Authorize(Policy = AuthorizationPolicies.HrAccess)]
        public IActionResult UploadDocument(int employeeId, IFormFile? document, string? documentType, DateTime? expiryDate, string? remarks)
        {
            if (!TryGetEditableEmployee(employeeId, out _)) return NotFound();
            if (document == null || document.Length == 0)
            {
                TempData["OnboardingError"] = "Choose a document to upload.";
                return RedirectToAction(nameof(Documents), new { employeeId });
            }

            var allowed = new[] { ".pdf", ".jpg", ".jpeg", ".png", ".doc", ".docx" };
            var extension = Path.GetExtension(document.FileName).ToLowerInvariant();
            if (!allowed.Contains(extension))
            {
                TempData["OnboardingError"] = "Allowed document types are PDF, JPG, PNG, DOC and DOCX.";
                return RedirectToAction(nameof(Documents), new { employeeId });
            }
            if (document.Length > 10 * 1024 * 1024)
            {
                TempData["OnboardingError"] = "Documents must be 10 MB or smaller.";
                return RedirectToAction(nameof(Documents), new { employeeId });
            }

            var environment = HttpContext.RequestServices.GetRequiredService<IWebHostEnvironment>();
            var folder = Path.Combine(environment.ContentRootPath, "App_Data", "EmployeeDocuments", employeeId.ToString());
            Directory.CreateDirectory(folder);
            var storedName = $"{Guid.NewGuid():N}{extension}";
            var physicalPath = Path.Combine(folder, storedName);
            var relativePath = $"employee-documents/{employeeId}/{storedName}";
            var safeDocumentType = string.IsNullOrWhiteSpace(documentType) ? "Other" : documentType.Trim();
            if (safeDocumentType.Length > 100) safeDocumentType = safeDocumentType[..100];
            var originalName = Path.GetFileName(document.FileName);
            if (originalName.Length > 255) originalName = originalName[..255];
            var safeRemarks = string.IsNullOrWhiteSpace(remarks) ? null : remarks.Trim();
            if (safeRemarks?.Length > 500) safeRemarks = safeRemarks[..500];
            try
            {
                using (var stream = System.IO.File.Create(physicalPath))
                    document.CopyTo(stream);

                var result = _objapp.SelectModel<ResultSet>("Procs_InsertUpdateDeleteEmployeeDocument", new
                {
                    DocumentID = 0, EmployeeID = employeeId,
                    DocumentType = safeDocumentType,
                    DocumentName = originalName, FilePath = relativePath,
                    FileExtension = extension, FileSizeKB = Math.Round(document.Length / 1024m, 2),
                    UploadedDate = DateTime.UtcNow, ExpiryDate = expiryDate?.Date, IsVerified = false,
                    Remarks = safeRemarks, Mode = 1
                });
                if (result?.StatusCode == 200)
                    TempData["OnboardingMessage"] = "Document uploaded and saved successfully.";
                else
                {
                    System.IO.File.Delete(physicalPath);
                    TempData["OnboardingError"] = result?.Message ?? "The document could not be saved.";
                }
            }
            catch (Exception ex)
            {
                if (System.IO.File.Exists(physicalPath)) System.IO.File.Delete(physicalPath);
                _logger.LogError(ex, "Failed to upload employee document for {EmployeeId}", employeeId);
                TempData["OnboardingError"] = "Unable to save the document. Please try again.";
            }
            return RedirectToAction(nameof(Documents), new { employeeId });
        }

        [HttpGet("Employees/Onboarding/{employeeId:int}/Documents/{documentId:int}/Download")]
        [Authorize(Policy = AuthorizationPolicies.HrAccess)]
        public IActionResult DownloadDocument(int employeeId, int documentId)
        {
            if (!TryGetEditableEmployee(employeeId, out _)) return NotFound();
            var document = LoadDocuments(employeeId).FirstOrDefault(x => x.DocumentID == documentId);
            if (document == null) return NotFound();
            var environment = HttpContext.RequestServices.GetRequiredService<IWebHostEnvironment>();
            var relative = document.FilePath.TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
            var physicalPath = Path.Combine(environment.ContentRootPath, "App_Data", relative);
            if (!System.IO.File.Exists(physicalPath)) return NotFound();
            return PhysicalFile(physicalPath, GetContentType(document.FileExtension), document.DocumentName);
        }

        [HttpPost("Employees/Onboarding/{employeeId:int}/Documents/{documentId:int}/Verify")]
        [ValidateAntiForgeryToken]
        [Authorize(Policy = AuthorizationPolicies.HrAccess)]
        public IActionResult VerifyDocument(int employeeId, int documentId)
        {
            if (!TryGetEditableEmployee(employeeId, out _)) return NotFound();
            var document = LoadDocuments(employeeId).FirstOrDefault(x => x.DocumentID == documentId);
            if (document == null) return NotFound();
            try
            {
                var result = _objapp.SelectModel<ResultSet>("Procs_InsertUpdateDeleteEmployeeDocument", new
                {
                    DocumentID = documentId, EmployeeID = employeeId, DocumentType = document.DocumentType,
                    DocumentName = document.DocumentName, FilePath = document.FilePath, FileExtension = document.FileExtension,
                    FileSizeKB = document.FileSizeKB ?? 0, UploadedDate = document.UploadedDate,
                    ExpiryDate = document.ExpiryDate, IsVerified = true, Remarks = document.Remarks, Mode = 2
                });
                TempData[result?.StatusCode == 200 ? "OnboardingMessage" : "OnboardingError"] = result?.Message ?? "Document review could not be completed.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to verify employee document {DocumentId}", documentId);
                TempData["OnboardingError"] = "Unable to verify the document.";
            }
            return RedirectToAction(nameof(Documents), new { employeeId });
        }

        [HttpPost("Employees/Onboarding/{employeeId:int}/Documents/{documentId:int}/Delete")]
        [ValidateAntiForgeryToken]
        [Authorize(Policy = AuthorizationPolicies.HrAccess)]
        public IActionResult DeleteDocument(int employeeId, int documentId)
        {
            if (!TryGetEditableEmployee(employeeId, out _)) return NotFound();
            var document = LoadDocuments(employeeId).FirstOrDefault(x => x.DocumentID == documentId);
            if (document == null) return NotFound();
            try
            {
                var result = _objapp.SelectModel<ResultSet>("Procs_InsertUpdateDeleteEmployeeDocument", new
                {
                    DocumentID = documentId, EmployeeID = employeeId, DocumentType = document.DocumentType,
                    DocumentName = document.DocumentName, FilePath = document.FilePath, FileExtension = document.FileExtension,
                    FileSizeKB = document.FileSizeKB ?? 0, UploadedDate = document.UploadedDate,
                    ExpiryDate = document.ExpiryDate, IsVerified = document.IsVerified, Remarks = document.Remarks, Mode = 3
                });
                if (result?.StatusCode == 200)
                {
                    var environment = HttpContext.RequestServices.GetRequiredService<IWebHostEnvironment>();
                    var relative = document.FilePath.TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
                    var physicalPath = Path.Combine(environment.ContentRootPath, "App_Data", relative);
                    if (System.IO.File.Exists(physicalPath)) System.IO.File.Delete(physicalPath);
                    TempData["OnboardingMessage"] = "Document deleted.";
                }
                else TempData["OnboardingError"] = result?.Message ?? "Document could not be deleted.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to delete employee document {DocumentId}", documentId);
                TempData["OnboardingError"] = "Unable to delete the document.";
            }
            return RedirectToAction(nameof(Documents), new { employeeId });
        }

        private static string GetContentType(string extension) => extension.ToLowerInvariant() switch
        {
            ".pdf" => "application/pdf", ".jpg" or ".jpeg" => "image/jpeg", ".png" => "image/png",
            ".doc" => "application/msword", ".docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            _ => "application/octet-stream"
        };

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
                var allEmployees = LoadEmployees(new EmployeeFilterRequest { IsActive = null });
                model.TotalEmployees = allEmployees.Count;
                model.ActiveEmployees = allEmployees.Count(x => x.IsActive);
                ApplyOnboardingStatuses(model.Employees);
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
            else
            {
                model.TotalEmployees = model.Employees.Count;
                model.ActiveEmployees = model.Employees.Count(x => x.IsActive);
                ApplyOnboardingStatuses(model.Employees);
            }

            return model;
        }

        private void ApplyOnboardingStatuses(IEnumerable<EmployeeResponse> employees)
        {
            foreach (var employee in employees)
            {
                var salary = _objapp.SelectModelList<SalaryMasterModel>("Procs_GetSalaryMaster", new { EmployeeID = employee.EmployeeID, SalaryMasterID = (int?)null, IsActive = (bool?)true }) ?? new List<SalaryMasterModel>();
                var accounts = _objapp.SelectModelList<UserResponse>("Procs_GetUsers", new { UserID = (int?)null, EmployeeID = employee.EmployeeID, RoleID = (int?)null, IsActive = (bool?)true, Search = (string?)null }) ?? new List<UserResponse>();
                var profile = !string.IsNullOrWhiteSpace(employee.FirstName) && !string.IsNullOrWhiteSpace(employee.LastName) && !string.IsNullOrWhiteSpace(employee.Email) && !string.IsNullOrWhiteSpace(employee.PhoneNumber);
                var employment = employee.DepartmentID > 0 && employee.DesignationID > 0 && employee.OfficeLocationID > 0 && employee.JoiningDate.HasValue && !string.IsNullOrWhiteSpace(employee.EmploymentType);
                employee.OnboardingCompleted = (profile ? 1 : 0) + (employment ? 1 : 0) + (salary.Any() ? 1 : 0) + (accounts.Any() ? 1 : 0);
                employee.OnboardingStatus = employee.OnboardingCompleted == employee.OnboardingTotal ? "Ready for payroll" : employee.OnboardingCompleted == 0 ? "Not started" : "In progress";
            }
        }

        private void PopulateFormLookups(EmployeeRequest? request = null)
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
            var states = _objapp.SelectModelList<LocationLookup>("Procs_GetIndiaStates", new { }) ?? new List<LocationLookup>();
            ViewBag.IndiaStates = states;
            var selectedState = states.FirstOrDefault(x => string.Equals(x.StateName, request?.State, StringComparison.OrdinalIgnoreCase));
            ViewBag.IndiaCities = selectedState == null
                ? new List<LocationLookup>()
                : _objapp.SelectModelList<LocationLookup>("Procs_GetIndiaCities", new { StateID = selectedState.StateID }) ?? new List<LocationLookup>();
        }

        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.HrAccess)]
        public IActionResult IndiaCities(int stateId)
        {
            if (stateId <= 0) return Json(Array.Empty<object>());
            var cities = _objapp.SelectModelList<LocationLookup>("Procs_GetIndiaCities", new { StateID = stateId }) ?? new List<LocationLookup>();
            return Json(cities.Select(x => new { id = x.CityID, name = x.CityName }));
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
            var offices = _objapp.SelectModelList<OfficeBranchResponse>(
                "Procs_GetOfficeBranch", new { OfficeLocationID = (int?)null, IsActive = true, Search = (string?)null });
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
            var officeNames = (offices ?? new List<OfficeBranchResponse>())
                .Where(x => x.OfficeLocationID > 0)
                .GroupBy(x => x.OfficeLocationID)
                .ToDictionary(x => x.Key, x => x.First().OfficeName);
            var employeeNames = (allEmployees ?? new List<EmployeeResponse>())
                .ToDictionary(x => x.EmployeeID, x => x.FullName);

            foreach (var employee in employees)
            {
                employee.DepartmentName = departmentNames.GetValueOrDefault(employee.DepartmentID);
                employee.DesignationName = designationNames.GetValueOrDefault(employee.DesignationID);
                employee.OfficeName = officeNames.GetValueOrDefault(employee.OfficeLocationID);
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

        private bool ValidateEmployeeRequest(EmployeeRequest request, bool isCreate)
        {
            if (!isCreate && string.IsNullOrWhiteSpace(request.EmployeeCode)) ModelState.AddModelError("EmployeeCode", "Employee code is required.");
            if (string.IsNullOrWhiteSpace(request.FirstName)) ModelState.AddModelError("FirstName", "First name is required.");
            if (string.IsNullOrWhiteSpace(request.LastName)) ModelState.AddModelError("LastName", "Last name is required.");
            if (string.IsNullOrWhiteSpace(request.Email) || !new EmailAddressAttribute().IsValid(request.Email)) ModelState.AddModelError("Email", "A valid email is required.");
            if (string.IsNullOrWhiteSpace(request.PhoneNumber) || !Regex.IsMatch(request.PhoneNumber.Trim(), @"^\+?[0-9]{10,15}$")) ModelState.AddModelError("PhoneNumber", "Enter a valid phone number (10–15 digits).");
            if (!string.IsNullOrWhiteSpace(request.EmergencyContact) && !Regex.IsMatch(request.EmergencyContact.Trim(), @"^\+?[0-9]{10,15}$")) ModelState.AddModelError("EmergencyContact", "Enter a valid emergency contact number.");
            if (!request.DateOfBirth.HasValue) ModelState.AddModelError("DateOfBirth", "Date of birth is required.");
            else if (request.DateOfBirth.Value.Date > DateTime.Today.AddYears(-18)) ModelState.AddModelError("DateOfBirth", "Employee must be at least 18 years old.");
            if (string.IsNullOrWhiteSpace(request.Address)) ModelState.AddModelError("Address", "Address is required.");
            if (string.IsNullOrWhiteSpace(request.City)) ModelState.AddModelError("City", "City is required.");
            if (string.IsNullOrWhiteSpace(request.State)) ModelState.AddModelError("State", "State is required.");
            if (!string.Equals(request.Country?.Trim(), "India", StringComparison.OrdinalIgnoreCase)) ModelState.AddModelError("Country", "Country must be India.");
            if (string.IsNullOrWhiteSpace(request.PostalCode)) ModelState.AddModelError("PostalCode", "Postal code is required.");
            if (request.DepartmentID <= 0) ModelState.AddModelError("DepartmentID", "Department is required.");
            if (request.DesignationID <= 0) ModelState.AddModelError("DesignationID", "Designation is required.");
            if (request.OfficeLocationID <= 0) ModelState.AddModelError("OfficeLocationID", "Office branch is required.");
            if (!request.JoiningDate.HasValue) ModelState.AddModelError("JoiningDate", "Joining date is required.");
            else if (request.JoiningDate.Value.Date < DateTime.Today) ModelState.AddModelError("JoiningDate", "Joining date cannot be in the past.");
            var employmentTypes = new[] { "Full-Time", "Part-Time", "Contract", "Intern" };
            if (string.IsNullOrWhiteSpace(request.EmploymentType) || !employmentTypes.Contains(request.EmploymentType, StringComparer.OrdinalIgnoreCase)) ModelState.AddModelError("EmploymentType", "Select a valid employment type.");
            var genders = new[] { "Male", "Female", "Other" };
            if (string.IsNullOrWhiteSpace(request.Gender) || !genders.Contains(request.Gender, StringComparer.OrdinalIgnoreCase)) ModelState.AddModelError("Gender", "Select a valid gender.");
            if (User.IsInRole("Admin") && request.RoleID <= 0) ModelState.AddModelError("RoleID", "Role is required.");
            ValidateContactUniqueness(request);
            ValidateManagerScope(request);
            return ModelState.IsValid;
        }

        private void ValidateContactUniqueness(EmployeeRequest request)
        {
            try
            {
                var employees = _objapp.SelectModelList<EmployeeResponse>("Procs_GetEmployees", new
                {
                    EmployeeID = (int?)null, DepartmentID = (int?)null, DesignationID = (int?)null,
                    OfficeLocationID = (int?)null, ManagerID = (int?)null, ShiftID = (int?)null,
                    RoleID = (int?)null, IsActive = (bool?)null, Search = (string?)null
                }) ?? new List<EmployeeResponse>();
                var others = employees.Where(x => x.EmployeeID != request.EmployeeID);
                if (others.Any(x => string.Equals(x.Email?.Trim(), request.Email?.Trim(), StringComparison.OrdinalIgnoreCase))) ModelState.AddModelError("Email", "This email address is already used by another employee.");
                if (others.Any(x => string.Equals(x.PhoneNumber?.Trim(), request.PhoneNumber?.Trim(), StringComparison.OrdinalIgnoreCase))) ModelState.AddModelError("PhoneNumber", "This phone number is already used by another employee.");
            }
            catch (Exception ex) { _logger.LogWarning(ex, "Friendly duplicate validation failed; database unique indexes remain authoritative."); }
        }

        private void ValidateManagerScope(EmployeeRequest request)
        {
            if (!request.ManagerID.HasValue) return;
            try
            {
                var manager = _objapp.SelectModelList<EmployeeResponse>("Procs_GetEmployees", new
                {
                    EmployeeID = request.ManagerID, DepartmentID = (int?)null, DesignationID = (int?)null,
                    OfficeLocationID = (int?)null, ManagerID = (int?)null, ShiftID = (int?)null,
                    RoleID = (int?)null, IsActive = true, Search = (string?)null
                })?.FirstOrDefault(x => x.EmployeeID == request.ManagerID.Value);
                if (manager == null || !string.Equals(manager.RoleName, "Manager", StringComparison.OrdinalIgnoreCase)) ModelState.AddModelError("ManagerID", "Select an active employee with the Manager role.");
                else if (manager.DepartmentID != request.DepartmentID || manager.OfficeLocationID != request.OfficeLocationID) ModelState.AddModelError("ManagerID", "Manager must belong to the selected department and office branch.");
            }
            catch (Exception ex) { _logger.LogWarning(ex, "Manager scope validation failed."); }
        }

        private string GenerateEmployeeCode()
        {
            var generated = _objapp.SelectModel<EmployeeCodeResult>("Procs_NextEmployeeCode", new { });
            if (string.IsNullOrWhiteSpace(generated?.EmployeeCode)) throw new InvalidOperationException("Employee-code generator returned no code.");
            return generated.EmployeeCode.Trim();
        }

        private int FindEmployeeId(string? employeeCode)
        {
            if (string.IsNullOrWhiteSpace(employeeCode)) return 0;
            return LoadEmployees(new EmployeeFilterRequest { IsActive = true, Search = employeeCode })
                .FirstOrDefault(x => string.Equals(x.EmployeeCode, employeeCode, StringComparison.OrdinalIgnoreCase))?.EmployeeID ?? 0;
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
