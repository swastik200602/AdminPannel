using AdminPannel.Logic;
using AdminPannel.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AdminPannel.Controllers;

[Authorize]
public class PayrollController : Controller
{
    private readonly AppData _app = new();

    [HttpGet]
    [Authorize]
    public IActionResult Index(PayrollFilterModel filter)
    {
        try
        {
            var availableEmployees = (User.IsInRole("Admin") || User.IsInRole("HR"))
                ? Employees()
                : new List<EmployeeResponse>();
            if (User.IsInRole("Manager") && TryGetEmployeeId(out var scopedManagerId))
                availableEmployees = Employees().Where(e => e.ManagerID == scopedManagerId).ToList();
            else if (User.IsInRole("Employee") && TryGetEmployeeId(out var scopedEmployeeId))
                availableEmployees = Employees().Where(e => e.EmployeeID == scopedEmployeeId).ToList();
            ViewBag.Employees = availableEmployees;
            var rows = _app.SelectModelList<PayrollModel>("Procs_GetPayroll", new
            {
                filter.EmployeeID, filter.PayrollMonth, filter.PayrollYear, filter.PaymentStatus
            });
            if (User.IsInRole("Manager") && TryGetEmployeeId(out var managerId))
            {
                var team = new HashSet<int>(Employees().Where(e => e.ManagerID == managerId).Select(e => e.EmployeeID));
                rows = rows.Where(x => team.Contains(x.EmployeeID)).ToList();
            }
            else if (User.IsInRole("Employee") && TryGetEmployeeId(out var employeeId))
            {
                rows = rows.Where(x => x.EmployeeID == employeeId).ToList();
            }
            return View(rows ?? new List<PayrollModel>());
        }
        catch (Exception)
        {
            ViewBag.Error = "Unable to load payroll records.";
            return View(new List<PayrollModel>());
        }
    }

    [HttpGet]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult Generate()
    {
        ViewBag.Employees = Employees();
        return View(new PayrollGenerateRequest { PayrollMonth = (byte)DateTime.Today.Month, PayrollYear = (short)DateTime.Today.Year });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult Generate(PayrollGenerateRequest request)
    {
        if (request.EmployeeID <= 0 || request.PayrollMonth is < 1 or > 12 || request.PayrollYear < 2000)
            ModelState.AddModelError(string.Empty, "Employee, month, and year are required.");
        if (!ModelState.IsValid)
        {
            ViewBag.Employees = Employees();
            return View(request);
        }
        if (!IsEmployeeReadyForPayroll(request.EmployeeID))
        {
            ModelState.AddModelError(string.Empty, "This employee is not ready for payroll. Complete the onboarding workspace first.");
            ViewBag.Employees = Employees();
            return View(request);
        }
        try
        {
            var result = _app.SelectModel<PayrollModel>("Procs_GeneratePayroll", request);
            if (result?.StatusCode == 200 || result?.PayrollID > 0)
                return RedirectToAction(nameof(Details), new { id = result.PayrollID });
            ModelState.AddModelError(string.Empty, result?.Message ?? "Payroll could not be generated.");
        }
        catch (Exception) { ModelState.AddModelError(string.Empty, "Unable to generate payroll."); }
        ViewBag.Employees = Employees();
        return View(request);
    }

    private bool IsEmployeeReadyForPayroll(int employeeId)
    {
        var employee = Employees().FirstOrDefault(x => x.EmployeeID == employeeId);
        if (employee == null || !employee.IsActive || employee.DepartmentID <= 0 || employee.DesignationID <= 0 || employee.OfficeLocationID <= 0 || !employee.JoiningDate.HasValue || string.IsNullOrWhiteSpace(employee.EmploymentType)) return false;
        var salary = _app.SelectModelList<SalaryMasterModel>("Procs_GetSalaryMaster", new { EmployeeID = employeeId, SalaryMasterID = (int?)null, IsActive = (bool?)true });
        var account = _app.SelectModelList<UserResponse>("Procs_GetUsers", new { UserID = (int?)null, EmployeeID = employeeId, RoleID = (int?)null, IsActive = (bool?)true, Search = (string?)null });
        return salary.Any() && account.Any();
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult UpdatePaymentStatus(PayrollPaymentStatusRequest request)
    {
        try
        {
            var result = _app.SelectModel<ResultSet>("Procs_UpdatePayrollPaymentStatus", request);
            TempData[result?.StatusCode == 200 ? "PayrollMessage" : "PayrollError"] = result?.Message ?? "Operation failed.";
        }
        catch (Exception) { TempData["PayrollError"] = "Unable to update payment status."; }
        return RedirectToAction(nameof(Index));
    }

    [HttpGet("Payroll/Edit/{id:int}")]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult Edit(int id)
    {
        var payroll = _app.SelectModel<PayrollModel>("Procs_GetPayrollDetails", new { PayrollID = id, EmployeeID = (int?)null, PayrollMonth = (byte?)null, PayrollYear = (short?)null });
        if (payroll == null) return NotFound();
        if (string.Equals(payroll.PaymentStatus, "Paid", StringComparison.OrdinalIgnoreCase))
        {
            TempData["PayrollError"] = "Paid payroll cannot be modified.";
            return RedirectToAction(nameof(Details), new { id });
        }
        return View("Edit", payroll);
    }

    [HttpPost("Payroll/Edit/{id:int}")]
    [ValidateAntiForgeryToken]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult Edit(int id, PayrollModel request)
    {
        var existing = _app.SelectModel<PayrollModel>("Procs_GetPayrollDetails", new { PayrollID = id, EmployeeID = (int?)null, PayrollMonth = (byte?)null, PayrollYear = (short?)null });
        if (existing == null) return NotFound();
        if (string.Equals(existing.PaymentStatus, "Paid", StringComparison.OrdinalIgnoreCase))
        {
            TempData["PayrollError"] = "Paid payroll cannot be modified.";
            return RedirectToAction(nameof(Details), new { id });
        }
        try
        {
            var result = _app.SelectModel<ResultSet>("Procs_InsertUpdateDeletePayroll", new
            {
                PayrollID = id, EmployeeID = existing.EmployeeID, PayrollMonth = existing.PayrollMonth,
                PayrollYear = existing.PayrollYear, BasicSalary = request.BasicSalary, Allowance = request.Allowance,
                Bonus = request.Bonus, Deduction = request.Deduction, Tax = request.Tax, NetSalary = (decimal?)null,
                PaymentDate = request.PaymentDate, PaymentStatus = request.PaymentStatus, request.Remarks, Mode = 2
            });
            TempData[result?.StatusCode == 200 ? "PayrollMessage" : "PayrollError"] = result?.Message ?? "Operation failed.";
        }
        catch (Exception) { TempData["PayrollError"] = "Unable to update payroll."; }
        return RedirectToAction(nameof(Index));
    }

    [HttpPost("Payroll/Delete")]
    [ValidateAntiForgeryToken]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult Delete(int id)
    {
        try
        {
            var result = _app.SelectModel<ResultSet>("Procs_InsertUpdateDeletePayroll", new
            {
                PayrollID = id, EmployeeID = (int?)null, PayrollMonth = (byte?)null, PayrollYear = (short?)null,
                BasicSalary = (decimal?)null, Allowance = (decimal?)null, Bonus = (decimal?)null, Deduction = (decimal?)null,
                Tax = (decimal?)null, NetSalary = (decimal?)null, PaymentDate = (DateTime?)null,
                PaymentStatus = (string?)null, Remarks = (string?)null, Mode = 3
            });
            TempData[result?.StatusCode == 200 ? "PayrollMessage" : "PayrollError"] = result?.Message ?? "Operation failed.";
        }
        catch (Exception) { TempData["PayrollError"] = "Unable to delete payroll."; }
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    [Authorize]
    public IActionResult Details(int id)
    {
        var row = _app.SelectModel<PayrollModel>("Procs_GetPayrollDetails", new { PayrollID = id, EmployeeID = (int?)null, PayrollMonth = (byte?)null, PayrollYear = (short?)null });
        if (row == null) return NotFound();
        ViewBag.EmployeeContext = GetEmployeeContext(row.EmployeeID);
        if (User.IsInRole("Admin") || User.IsInRole("HR")) return View(row);
        if (User.IsInRole("Manager") && !IsManagerTeamMember(row.EmployeeID)) return Forbid();
        if (User.IsInRole("Employee") && (!TryGetEmployeeId(out var ownId) || row.EmployeeID != ownId)) return Forbid();
        return View(row);
    }

    [HttpGet]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult Summary(byte? month, short? year)
    {
        var m = month ?? (byte)DateTime.Today.Month;
        var y = year ?? (short)DateTime.Today.Year;
        var summary = _app.SelectModel<PayrollSummaryModel>("Procs_GetPayrollSummary", new { PayrollMonth = m, PayrollYear = y });
        ViewBag.Month = m; ViewBag.Year = y;
        return View(summary ?? new PayrollSummaryModel());
    }

    [HttpGet]
    [Authorize(Roles = "Admin,HR,Manager,Employee")]
    public IActionResult SalarySlip(int id)
    {
        var slip = _app.SelectModel<SalarySlipModel>("Procs_GetSalarySlip", new { PayrollID = id, EmployeeID = (int?)null, PayrollMonth = (byte?)null, PayrollYear = (short?)null });
        if (slip == null) return NotFound();
        ViewBag.EmployeeContext = GetEmployeeContext(slip.EmployeeID);
        if (User.IsInRole("Admin") || User.IsInRole("HR")) return View(slip);
        if (User.IsInRole("Employee") && (!TryGetEmployeeId(out var employeeId) || slip.EmployeeID != employeeId)) return Forbid();
        if (User.IsInRole("Manager") && !IsManagerTeamMember(slip.EmployeeID)) return Forbid();
        return View(slip);
    }

    [HttpGet]
    [Authorize(Roles = "Admin,HR,Manager,Employee")]
    public IActionResult History(PayrollHistoryFilterModel filter)
    {
        ViewBag.Filter = filter;
        if ((User.IsInRole("Admin") || User.IsInRole("HR")) && !filter.EmployeeID.HasValue)
        {
            var allPayroll = _app.SelectModelList<PayrollModel>("Procs_GetPayroll", new
            {
                EmployeeID = (int?)null,
                PayrollMonth = (byte?)null,
                PayrollYear = (short?)null,
                filter.PaymentStatus
            }) ?? new List<PayrollModel>();
            ViewBag.Employees = Employees();
            return View(FilterHistoryRows(allPayroll, filter));
        }

        if (User.IsInRole("Manager") && !filter.EmployeeID.HasValue)
        {
            if (!TryGetEmployeeId(out var managerId)) return Forbid();
            var teamPayroll = _app.SelectModelList<PayrollModel>("Procs_GetPayroll", new
            {
                EmployeeID = (int?)null, PayrollMonth = (byte?)null, PayrollYear = (short?)null,
                PaymentStatus = (string?)null
            }) ?? new List<PayrollModel>();
            var teamEmployees = Employees().Where(e => e.ManagerID == managerId).ToList();
            var teamIds = teamEmployees.Select(e => e.EmployeeID).ToHashSet();
            ViewBag.Employees = teamEmployees;
            ViewBag.Filter = filter;
            return View(FilterHistoryRows(teamPayroll.Where(p => teamIds.Contains(p.EmployeeID)).ToList(), filter));
        }

        if (!TryGetEmployeeId(out var ownId)) return Forbid();
        var id = User.IsInRole("Employee") ? ownId : (filter.EmployeeID ?? ownId);
        if (User.IsInRole("Manager") && id != ownId && !IsManagerTeamMember(id)) return Forbid();
        ViewBag.EmployeeContext = GetEmployeeContext(id);
        ViewBag.Employees = Employees().Where(e => e.EmployeeID == id).ToList();
        var rows = _app.SelectModelList<PayrollModel>("Procs_GetEmployeePayrollHistory", new { EmployeeID = id, filter.FromMonth, filter.FromYear, filter.ToMonth, filter.ToYear, filter.PaymentStatus });
        return View(rows ?? new List<PayrollModel>());
    }

    private static List<PayrollModel> FilterHistoryRows(IEnumerable<PayrollModel> rows, PayrollHistoryFilterModel filter)
    {
        return rows.Where(p => (string.IsNullOrWhiteSpace(filter.PaymentStatus) || string.Equals(p.PaymentStatus, filter.PaymentStatus, StringComparison.OrdinalIgnoreCase)) && (!filter.FromYear.HasValue || p.PayrollYear > filter.FromYear.Value || (p.PayrollYear == filter.FromYear.Value && (!filter.FromMonth.HasValue || p.PayrollMonth >= filter.FromMonth.Value))) && (!filter.ToYear.HasValue || p.PayrollYear < filter.ToYear.Value || (p.PayrollYear == filter.ToYear.Value && (!filter.ToMonth.HasValue || p.PayrollMonth <= filter.ToMonth.Value)))).ToList();
    }

    [HttpGet("Payroll/SalaryMaster")]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult SalaryMaster(SalaryMasterFilterModel filter)
    {
        try
        {
            ViewBag.Employees = Employees();
            var rows = _app.SelectModelList<SalaryMasterModel>("Procs_GetSalaryMaster", new
            {
                filter.EmployeeID, SalaryMasterID = (int?)null, filter.IsActive
            });
            ViewBag.Filter = filter;
            return View(rows ?? new List<SalaryMasterModel>());
        }
        catch (Exception)
        {
            ViewBag.Error = "Unable to load Salary Master records.";
            return View(new List<SalaryMasterModel>());
        }
    }

    [HttpGet("Payroll/SalaryMaster/History/{employeeId:int}")]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult SalaryHistory(int employeeId)
    {
        try
        {
            var rows = _app.SelectModelList<SalaryMasterModel>("Procs_GetSalaryMaster", new
            {
                EmployeeID = employeeId, SalaryMasterID = (int?)null, IsActive = (bool?)null
            });
            ViewBag.EmployeeID = employeeId;
            ViewBag.EmployeeContext = GetEmployeeContext(employeeId);
            return View(rows?.OrderByDescending(x => x.EffectiveFrom).ToList() ?? new List<SalaryMasterModel>());
        }
        catch (Exception)
        {
            ViewBag.Error = "Unable to load salary history.";
            return View(new List<SalaryMasterModel>());
        }
    }

    [HttpGet("Payroll/SalaryMaster/Create")]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
 public IActionResult CreateSalaryRevision(int? employeeId)    {
           var employees = Employees();
           ViewBag.Employees = employees;
           var request = new SalaryRevisionModel { EffectiveFrom = DateTime.Today };
           if (employeeId.HasValue && employeeId.Value > 0)
           {
               var employee = employees.FirstOrDefault(x => x.EmployeeID == employeeId.Value);
               if (employee != null)
               {
                   request.EmployeeID = employee.EmployeeID;
                   var existing = _app.SelectModelList<SalaryMasterModel>("Procs_GetSalaryMaster", new { EmployeeID = employee.EmployeeID, SalaryMasterID = (int?)null, IsActive = (bool?)true });
                   if (!existing.Any()) request.BasicSalary = employee.BasicSalary;
                   ViewBag.EmployeeContext = GetEmployeeContext(employee.EmployeeID);
               }
           }
        return View("SalaryRevision", request);
    }

    [HttpPost("Payroll/SalaryMaster/Create")]
    [ValidateAntiForgeryToken]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult CreateSalaryRevision(SalaryRevisionModel request)
    {
       
        if (request.EmployeeID <= 0) ModelState.AddModelError(nameof(request.EmployeeID), "Employee is required.");
        if (request.BasicSalary < 0 || request.Allowance < 0 || request.Bonus < 0 || request.Deduction < 0 || request.Tax < 0)
            ModelState.AddModelError(string.Empty, "Salary amounts cannot be negative.");
        if (request.EffectiveFrom == default) ModelState.AddModelError(nameof(request.EffectiveFrom), "Effective date is required.");
        if (!ModelState.IsValid)
        {
            ViewBag.Employees = Employees();
            return View("SalaryRevision", request);
        }

        try
        {
            var result = _app.SelectModel<ResultSet>("Procs_InsertSalaryRevision", new
            {
                request.EmployeeID, request.BasicSalary, request.Allowance, request.Bonus,
                request.Deduction, request.Tax, EffectiveFrom = request.EffectiveFrom.Date,
                request.RevisionReason, CreatedBy = CurrentUserId()
            });
            if (result?.StatusCode == 200)
            {
                TempData["PayrollMessage"] = result.Message ?? "Salary revision saved successfully.";
                return RedirectToAction(nameof(SalaryMaster));
            }
            ModelState.AddModelError(string.Empty, result?.Message ?? "Salary revision could not be saved.");
        }
        catch (Exception) { ModelState.AddModelError(string.Empty, "Unable to save salary revision."); }
        ViewBag.Employees = Employees();
        return View("SalaryRevision", request);
    }

    [HttpGet("Payroll/TaxMaster")]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult TaxMaster(TaxMasterFilterModel filter)
    {
        try
        {
            ViewBag.Employees = Employees();
            var rows = _app.SelectModelList<TaxMasterModel>("Procs_GetTaxMaster", new
            {
                TaxMasterID = (int?)null, filter.EmployeeID, filter.TaxType, filter.IsActive
            });
            ViewBag.Filter = filter;
            return View(rows ?? new List<TaxMasterModel>());
        }
        catch (Exception)
        {
            ViewBag.Error = "Unable to load tax records.";
            return View(new List<TaxMasterModel>());
        }
    }

    [HttpGet("Payroll/TaxMaster/History/{employeeId:int}")]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult TaxHistory(int employeeId)
    {
        try
        {
            var rows = _app.SelectModelList<TaxMasterModel>("Procs_GetTaxMaster", new
            {
                TaxMasterID = (int?)null, EmployeeID = employeeId, TaxType = (string?)null, IsActive = (bool?)null
            });
            ViewBag.EmployeeContext = GetEmployeeContext(employeeId);
            return View(rows?.OrderByDescending(x => x.EffectiveFrom).ThenBy(x => x.TaxType).ToList() ?? new List<TaxMasterModel>());
        }
        catch (Exception)
        {
            ViewBag.Error = "Unable to load tax history.";
            return View(new List<TaxMasterModel>());
        }
    }

    [HttpGet("Payroll/TaxMaster/Create")]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult CreateTaxRevision(int? employeeId)
    {
        ViewBag.Employees = Employees();
        var model = new TaxRevisionModel { EmployeeID = employeeId.GetValueOrDefault() };
        if (model.EmployeeID > 0)
            ViewBag.EmployeeContext = GetEmployeeContext(model.EmployeeID);
        return View("TaxRevision", model);
    }

    [HttpPost("Payroll/TaxMaster/Create")]
    [ValidateAntiForgeryToken]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult CreateTaxRevision(TaxRevisionModel request)
    {
        var validTypes = new[] { "TDS", "IncomeTax", "Other" };
        if (request.EmployeeID <= 0) ModelState.AddModelError(nameof(request.EmployeeID), "Employee is required.");
        if (!validTypes.Contains(request.TaxType, StringComparer.OrdinalIgnoreCase)) ModelState.AddModelError(nameof(request.TaxType), "Invalid tax type.");
        if (request.TaxAmount < 0) ModelState.AddModelError(nameof(request.TaxAmount), "Tax amount cannot be negative.");        if (request.EffectiveFrom == default) ModelState.AddModelError(nameof(request.EffectiveFrom), "Effective date is required.");
        if (!ModelState.IsValid)
        {
            ViewBag.Employees = Employees();
            return View("TaxRevision", request);
        }
        try
        {
            var result = _app.SelectModel<ResultSet>("Procs_InsertTaxRevision", new
            {
                request.EmployeeID, request.TaxType, request.TaxAmount,
                EffectiveFrom = request.EffectiveFrom.Date, request.Reason, CreatedBy = CurrentUserId()
            });
            if (result?.StatusCode == 200)
            {
                TempData["PayrollMessage"] = result.Message ?? "Tax revision saved successfully.";
                return RedirectToAction(nameof(TaxMaster));
            }
            ModelState.AddModelError(string.Empty, result?.Message ?? "Tax revision could not be saved.");
        }
        catch (Exception) { ModelState.AddModelError(string.Empty, "Unable to save tax revision."); }
        ViewBag.Employees = Employees();
        return View("TaxRevision", request);
    }

    [HttpGet("Payroll/Bonus")]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult Bonus(BonusFilterModel filter)
    {
        try
        {
            ViewBag.Employees = Employees();
            var rows = _app.SelectModelList<BonusModel>("Procs_GetBonus", new
            {
                BonusID = (int?)null, filter.EmployeeID, filter.BonusMonth, filter.BonusYear, filter.Status
            });
            ViewBag.Filter = filter;
            return View(rows ?? new List<BonusModel>());
        }
        catch (Exception)
        {
            ViewBag.Error = "Unable to load bonus records.";
            return View(new List<BonusModel>());
        }
    }

    [HttpGet("Payroll/Bonus/Create")]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult CreateBonus()
    {
        ViewBag.Employees = Employees();
        return View("BonusCreate", new BonusRequestModel { BonusMonth = (byte)DateTime.Today.Month, BonusYear = (short)DateTime.Today.Year });
    }

    [HttpPost("Payroll/Bonus/Create")]
    [ValidateAntiForgeryToken]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult CreateBonus(BonusRequestModel request)
    {
        ValidateBonusRequest(request);
        if (!ModelState.IsValid)
        {
            ViewBag.Employees = Employees();
            return View("BonusCreate", request);
        }
        try
        {
            var result = _app.SelectModel<ResultSet>("Procs_InsertUpdateCancelBonus", new
            {
                BonusID = (int?)null, request.EmployeeID, request.BonusAmount, request.BonusMonth, request.BonusYear,
                request.BonusType, request.Reason, PaidDate = (DateTime?)null, Mode = 1
            });
            if (result?.StatusCode == 200)
            {
                TempData["PayrollMessage"] = result.Message ?? "Bonus created successfully.";
                return RedirectToAction(nameof(Bonus));
            }
            ModelState.AddModelError(string.Empty, result?.Message ?? "Bonus could not be created.");
        }
        catch (Exception) { ModelState.AddModelError(string.Empty, "Unable to create bonus."); }
        ViewBag.Employees = Employees();
        return View("BonusCreate", request);
    }

    [HttpGet("Payroll/Bonus/Edit/{id:int}")]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult EditBonus(int id)
    {
        var bonus = FindBonus(id);
        if (bonus == null) return NotFound();
        if (!string.Equals(bonus.Status, "Pending", StringComparison.OrdinalIgnoreCase))
        {
            TempData["PayrollError"] = "Only Pending bonuses can be edited.";
            return RedirectToAction(nameof(Bonus));
        }
        ViewBag.Employees = Employees();
        ViewBag.BonusID = id;
        return View("BonusEdit", new BonusRequestModel { EmployeeID = bonus.EmployeeID, BonusAmount = bonus.BonusAmount, BonusMonth = bonus.BonusMonth, BonusYear = bonus.BonusYear, BonusType = bonus.BonusType, Reason = bonus.Reason });
    }

    [HttpPost("Payroll/Bonus/Edit/{id:int}")]
    [ValidateAntiForgeryToken]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult EditBonus(int id, BonusRequestModel request)
    {
        ValidateBonusRequest(request);
        var existing = FindBonus(id);
        if (existing == null) return NotFound();
        if (!string.Equals(existing.Status, "Pending", StringComparison.OrdinalIgnoreCase)) ModelState.AddModelError(string.Empty, "Only Pending bonuses can be edited.");
        if (!ModelState.IsValid)
        {
            ViewBag.Employees = Employees(); ViewBag.BonusID = id;
            return View("BonusEdit", request);
        }
        try
        {
            var result = _app.SelectModel<ResultSet>("Procs_InsertUpdateCancelBonus", new
            {
                BonusID = id, request.EmployeeID, request.BonusAmount, request.BonusMonth, request.BonusYear,
                request.BonusType, request.Reason, PaidDate = (DateTime?)null, Mode = 2
            });
            TempData[result?.StatusCode == 200 ? "PayrollMessage" : "PayrollError"] = result?.Message ?? "Operation failed.";
        }
        catch (Exception) { TempData["PayrollError"] = "Unable to update bonus."; }
        return RedirectToAction(nameof(Bonus));
    }

    [HttpPost("Payroll/Bonus/Cancel")]
    [ValidateAntiForgeryToken]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult CancelBonus(int id)
    {
        var existing = FindBonus(id);
        if (existing == null) return NotFound();
        if (!string.Equals(existing.Status, "Pending", StringComparison.OrdinalIgnoreCase))
        {
            TempData["PayrollError"] = "Only Pending bonuses can be cancelled.";
            return RedirectToAction(nameof(Bonus));
        }
        try
        {
            var result = _app.SelectModel<ResultSet>("Procs_InsertUpdateCancelBonus", new
            {
                BonusID = id, EmployeeID = (int?)null, BonusAmount = (decimal?)null, BonusMonth = (byte?)null,
                BonusYear = (short?)null, BonusType = (string?)null, Reason = (string?)null, PaidDate = (DateTime?)null, Mode = 3
            });
            TempData[result?.StatusCode == 200 ? "PayrollMessage" : "PayrollError"] = result?.Message ?? "Operation failed.";
        }
        catch (Exception) { TempData["PayrollError"] = "Unable to cancel bonus."; }
        return RedirectToAction(nameof(Bonus));
    }

    [HttpGet("Payroll/Advance")]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult Advance(SalaryAdvanceFilterModel filter)
    {
        try
        {
            ViewBag.Employees = Employees(); ViewBag.Filter = filter;
            var rows = _app.SelectModelList<SalaryAdvanceModel>("Procs_GetSalaryAdvance", new
            {
                SalaryAdvanceID = (int?)null, filter.EmployeeID, filter.TransactionType, filter.Status
            });
            return View(rows ?? new List<SalaryAdvanceModel>());
        }
        catch (Exception) { ViewBag.Error = "Unable to load advances and loans."; return View(new List<SalaryAdvanceModel>()); }
    }

    [HttpGet("Payroll/Advance/Create")]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult CreateAdvance()
    {
        ViewBag.Employees = Employees();
        return View("AdvanceCreate", new SalaryAdvanceRequestModel());
    }

    [HttpPost("Payroll/Advance/Create")]
    [ValidateAntiForgeryToken]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult CreateAdvance(SalaryAdvanceRequestModel request)
    {
        ValidateAdvanceRequest(request);
        if (!ModelState.IsValid) { ViewBag.Employees = Employees(); return View("AdvanceCreate", request); }
        try
        {
            var result = _app.SelectModel<ResultSet>("Procs_InsertUpdateCancelSalaryAdvance", new
            {
                SalaryAdvanceID = (int?)null, request.EmployeeID, request.TransactionType, request.TotalAmount,
                request.MonthlyRecoveryAmount, IssueDate = request.IssueDate.Date, request.RecoveryStartMonth,
                request.RecoveryStartYear, request.Remarks, Mode = 1
            });
            TempData[result?.StatusCode == 200 ? "PayrollMessage" : "PayrollError"] = result?.Message ?? "Operation failed.";
        }
        catch (Exception) { TempData["PayrollError"] = "Unable to create advance or loan."; }
        return RedirectToAction(nameof(Advance));
    }

    [HttpGet("Payroll/Advance/Edit/{id:int}")]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult EditAdvance(int id)
    {
        var row = FindAdvance(id);
        if (row == null) return NotFound();
        if (!string.Equals(row.Status, "Active", StringComparison.OrdinalIgnoreCase)) { TempData["PayrollError"] = "Only active advance/loan can be updated."; return RedirectToAction(nameof(Advance)); }
        ViewBag.Employees = Employees(); ViewBag.AdvanceID = id;
        return View("AdvanceEdit", new SalaryAdvanceRequestModel { EmployeeID = row.EmployeeID, TransactionType = row.TransactionType ?? "Advance", TotalAmount = row.TotalAmount, MonthlyRecoveryAmount = row.MonthlyRecoveryAmount, IssueDate = row.IssueDate, RecoveryStartMonth = row.RecoveryStartMonth, RecoveryStartYear = row.RecoveryStartYear, Remarks = row.Remarks });
    }

    [HttpPost("Payroll/Advance/Edit/{id:int}")]
    [ValidateAntiForgeryToken]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult EditAdvance(int id, SalaryAdvanceRequestModel request)
    {
        ValidateAdvanceRequest(request); var existing = FindAdvance(id);
        if (existing == null) return NotFound();
        if (!string.Equals(existing.Status, "Active", StringComparison.OrdinalIgnoreCase)) ModelState.AddModelError(string.Empty, "Only active advance/loan can be updated.");
        if (!ModelState.IsValid) { ViewBag.Employees = Employees(); ViewBag.AdvanceID = id; return View("AdvanceEdit", request); }
        try
        {
            var result = _app.SelectModel<ResultSet>("Procs_InsertUpdateCancelSalaryAdvance", new
            {
                SalaryAdvanceID = id, request.EmployeeID, request.TransactionType, request.TotalAmount,
                request.MonthlyRecoveryAmount, IssueDate = request.IssueDate.Date, request.RecoveryStartMonth,
                request.RecoveryStartYear, request.Remarks, Mode = 2
            });
            TempData[result?.StatusCode == 200 ? "PayrollMessage" : "PayrollError"] = result?.Message ?? "Operation failed.";
        }
        catch (Exception) { TempData["PayrollError"] = "Unable to update advance or loan."; }
        return RedirectToAction(nameof(Advance));
    }

    [HttpPost("Payroll/Advance/Cancel")]
    [ValidateAntiForgeryToken]
    [Authorize(Policy = AuthorizationPolicies.HrAccess)]
    public IActionResult CancelAdvance(int id)
    {
        var existing = FindAdvance(id);
        if (existing == null) return NotFound();
        if (!string.Equals(existing.Status, "Active", StringComparison.OrdinalIgnoreCase)) { TempData["PayrollError"] = "Only active advance/loan can be cancelled."; return RedirectToAction(nameof(Advance)); }
        try
        {
            var result = _app.SelectModel<ResultSet>("Procs_InsertUpdateCancelSalaryAdvance", new
            {
                SalaryAdvanceID = id, EmployeeID = (int?)null, TransactionType = (string?)null, TotalAmount = (decimal?)null,
                MonthlyRecoveryAmount = (decimal?)null, IssueDate = (DateTime?)null, RecoveryStartMonth = (byte?)null,
                RecoveryStartYear = (short?)null, Remarks = (string?)null, Mode = 3
            });
            TempData[result?.StatusCode == 200 ? "PayrollMessage" : "PayrollError"] = result?.Message ?? "Operation failed.";
        }
        catch (Exception) { TempData["PayrollError"] = "Unable to cancel advance or loan."; }
        return RedirectToAction(nameof(Advance));
    }

    private List<EmployeeResponse> Employees()
    {
        var employees = _app.SelectModelList<EmployeeResponse>("Procs_GetEmployees", new
        {
            EmployeeID = (int?)null, DepartmentID = (int?)null, DesignationID = (int?)null, OfficeLocationID = (int?)null,
            ManagerID = (int?)null, ShiftID = (int?)null, RoleID = (int?)null, IsActive = true, Search = (string?)null
        }) ?? new List<EmployeeResponse>();
        var departments = _app.SelectModelList<DepartmentResponse>("Procs_GetDepartment", new { DepartmentID = 0, Mode = 1 });
        var designations = _app.SelectModelList<DesignationResponse>("Procs_GetDesignation", new { DesignationID = (int?)null, IsActive = true, Search = (string?)null });
        var offices = _app.SelectModelList<OfficeBranchResponse>("Procs_GetOfficeBranch", new { OfficeLocationID = (int?)null, IsActive = true, Search = (string?)null });
        foreach (var employee in employees)
        {
            employee.DepartmentName ??= departments.FirstOrDefault(x => x.DepartmentID == employee.DepartmentID)?.DepartmentName;
            employee.DesignationName ??= designations.FirstOrDefault(x => x.DesignationID == employee.DesignationID)?.DesignationName;
            employee.OfficeName ??= offices.FirstOrDefault(x => x.OfficeLocationID == employee.OfficeLocationID)?.OfficeName;
        }
        return employees;
    }

    private EmployeeContextModel? GetEmployeeContext(int employeeId)
    {
        var employee = _app.SelectModelList<EmployeeResponse>("Procs_GetEmployees", new
        {
            EmployeeID = employeeId, DepartmentID = (int?)null, DesignationID = (int?)null,
            OfficeLocationID = (int?)null, ManagerID = (int?)null, ShiftID = (int?)null,
            RoleID = (int?)null, IsActive = (bool?)null, Search = (string?)null
        }).FirstOrDefault();
        if (employee == null) return null;
        var departments = _app.SelectModelList<DepartmentResponse>("Procs_GetDepartment", new { DepartmentID = 0, Mode = 1 });
        var designations = _app.SelectModelList<DesignationResponse>("Procs_GetDesignation", new { DesignationID = (int?)null, IsActive = true, Search = (string?)null });
        var offices = _app.SelectModelList<OfficeBranchResponse>("Procs_GetOfficeBranch", new { OfficeLocationID = (int?)null, IsActive = true, Search = (string?)null });
        return new EmployeeContextModel
        {
            EmployeeID = employee.EmployeeID,
            FullName = employee.FullName,
            EmployeeCode = employee.EmployeeCode,
            ProfileImage = employee.ProfileImage,
            DesignationName = employee.DesignationName ?? designations.FirstOrDefault(x => x.DesignationID == employee.DesignationID)?.DesignationName,
            DepartmentName = employee.DepartmentName ?? departments.FirstOrDefault(x => x.DepartmentID == employee.DepartmentID)?.DepartmentName,
            OfficeName = offices.FirstOrDefault(x => x.OfficeLocationID == employee.OfficeLocationID)?.OfficeName,
            JoiningDate = employee.JoiningDate,
            IsActive = employee.IsActive
        };
    }

    private bool TryGetEmployeeId(out int id) => int.TryParse(User.FindFirst("EmployeeID")?.Value, out id) && id > 0;

    private int? CurrentUserId() => int.TryParse(User.FindFirst("UserID")?.Value, out var id) ? id : null;

    private BonusModel? FindBonus(int id) => _app.SelectModel<BonusModel>("Procs_GetBonus", new
    {
        BonusID = id, EmployeeID = (int?)null, BonusMonth = (byte?)null, BonusYear = (short?)null, Status = (string?)null
    });

    private void ValidateBonusRequest(BonusRequestModel request)
    {
        if (request.EmployeeID <= 0) ModelState.AddModelError(nameof(request.EmployeeID), "Employee is required.");
        if (request.BonusAmount <= 0) ModelState.AddModelError(nameof(request.BonusAmount), "Bonus amount must be greater than zero.");
        if (request.BonusMonth is < 1 or > 12) ModelState.AddModelError(nameof(request.BonusMonth), "Bonus month must be between 1 and 12.");
        if (request.BonusYear < 2000) ModelState.AddModelError(nameof(request.BonusYear), "Bonus year is invalid.");
        if (string.IsNullOrWhiteSpace(request.BonusType)) ModelState.AddModelError(nameof(request.BonusType), "Bonus type is required.");
    }

    private SalaryAdvanceModel? FindAdvance(int id) => _app.SelectModel<SalaryAdvanceModel>("Procs_GetSalaryAdvance", new
    {
        SalaryAdvanceID = id, EmployeeID = (int?)null, TransactionType = (string?)null, Status = (string?)null
    });

    private void ValidateAdvanceRequest(SalaryAdvanceRequestModel request)
    {
        if (request.EmployeeID <= 0) ModelState.AddModelError(nameof(request.EmployeeID), "Employee is required.");
        if (request.TransactionType is not ("Advance" or "Loan")) ModelState.AddModelError(nameof(request.TransactionType), "Invalid transaction type.");
        if (request.TotalAmount <= 0) ModelState.AddModelError(nameof(request.TotalAmount), "Total amount must be greater than zero.");
        if (request.MonthlyRecoveryAmount <= 0) ModelState.AddModelError(nameof(request.MonthlyRecoveryAmount), "Monthly recovery must be greater than zero.");
        if (request.RecoveryStartMonth is < 1 or > 12) ModelState.AddModelError(nameof(request.RecoveryStartMonth), "Recovery month must be between 1 and 12.");
        if (request.RecoveryStartYear < 2000) ModelState.AddModelError(nameof(request.RecoveryStartYear), "Recovery year is invalid.");
    }

    private bool IsManagerTeamMember(int employeeId)
    {
        return TryGetEmployeeId(out var managerId) && Employees().Any(e => e.EmployeeID == employeeId && e.ManagerID == managerId);
    }
}
