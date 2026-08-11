using AdminPannel.Logic;
using AdminPannel.Models;
using Microsoft.AspNetCore.Mvc;
using System;
using System.Collections.Generic;

namespace AdminPannel.Controllers
{
    public class EmployeeController : Controller
    {
        private readonly AppData _objapp = new AppData();

        // GET: /Employee
        public IActionResult Index()
        {
            // Load list of employees via stored proc
            var list = _objapp.SelectModelList<EmployeeResponse>("Procs_GetEmployees", null);

            // Load departments (Mode=3 returns Id,Name)
            var depts = _objapp.SelectModelList<IdNameDto>("Procs_GetDepartment", new { DepartmentID = 0, Mode = 3 });
            var desigs = _objapp.SelectModelList<DesignationDto>("Procs_GetDesignation", new { DesignationID = (int?)null, IsActive = (bool?)true, Search = (string)null });

            var deptDict = new Dictionary<int, string>();
            if (depts != null)
            {
                foreach (var d in depts)
                    deptDict[d.Id] = d.Name;
            }

            var desigDict = new Dictionary<int, string>();
            if (desigs != null)
            {
                foreach (var d in desigs)
                    desigDict[d.DesignationID] = d.DesignationName;
            }

            if (list != null)
            {
                foreach (var e in list)
                {
                    if (e != null)
                    {
                        e.DepartmentName = e.DepartmentID != 0 && deptDict.ContainsKey(e.DepartmentID) ? deptDict[e.DepartmentID] : null;
                        e.DesignationName = e.DesignationID != 0 && desigDict.ContainsKey(e.DesignationID) ? desigDict[e.DesignationID] : null;
                    }
                }
            }

            return View(list);
        }

        // GET: /Employee/Rows - returns tbody rows partial for AJAX refresh
        public IActionResult Rows()
        {
            var list = _objapp.SelectModelList<EmployeeResponse>("Procs_GetEmployees", null);

            var depts = _objapp.SelectModelList<IdNameDto>("Procs_GetDepartment", new { DepartmentID = 0, Mode = 3 });
            var desigs = _objapp.SelectModelList<DesignationDto>("Procs_GetDesignation", new { DesignationID = (int?)null, IsActive = (bool?)true, Search = (string)null });

            var deptDict = new Dictionary<int, string>();
            if (depts != null)
            {
                foreach (var d in depts)
                    deptDict[d.Id] = d.Name;
            }

            var desigDict = new Dictionary<int, string>();
            if (desigs != null)
            {
                foreach (var d in desigs)
                    desigDict[d.DesignationID] = d.DesignationName;
            }

            if (list != null)
            {
                foreach (var e in list)
                {
                    if (e != null)
                    {
                        e.DepartmentName = e.DepartmentID != 0 && deptDict.ContainsKey(e.DepartmentID) ? deptDict[e.DepartmentID] : null;
                        e.DesignationName = e.DesignationID != 0 && desigDict.ContainsKey(e.DesignationID) ? desigDict[e.DesignationID] : null;
                    }
                }
            }

            return PartialView("_EmployeeRows", list);
        }

        // GET: /Employee/Create (returns partial view)
        public IActionResult Create()
        {
            var model = new EmployeeRequest();

            var depts = _objapp.SelectModelList<IdNameDto>("Procs_GetDepartment", new { DepartmentID = 0, Mode = 3 });
            var desigs = _objapp.SelectModelList<DesignationDto>("Procs_GetDesignation", new { DesignationID = (int?)null, IsActive = (bool?)true, Search = (string)null });

            ViewBag.Departments = depts;
            ViewBag.Designations = desigs;

            return PartialView("_CreateEdit", model);
        }

        // GET: /Employee/Edit/5
        public IActionResult Edit(int id)
        {
            var emp = _objapp.SelectModel<EmployeeResponse>("Procs_GetEmployeeDetails", new { EmployeeID = id });
            if (emp == null)
                return NotFound();

            var req = new EmployeeRequest
            {
                EmployeeID = emp.EmployeeID,
                EmployeeCode = emp.EmployeeCode,
                FirstName = emp.FirstName,
                LastName = emp.LastName,
                Gender = emp.Gender,
                DateOfBirth = emp.DateOfBirth,
                Email = emp.Email,
                PhoneNumber = emp.PhoneNumber,
                EmergencyContact = emp.EmergencyContact,
                Address = emp.Address,
                City = emp.City,
                State = emp.State,
                Country = emp.Country,
                PostalCode = emp.PostalCode,
                DepartmentID = emp.DepartmentID,
                DesignationID = emp.DesignationID,
                OfficeLocationID = emp.OfficeLocationID,
                ManagerID = emp.ManagerID,
                JoiningDate = emp.JoiningDate,
                EmploymentType = emp.EmploymentType,
                BasicSalary = emp.BasicSalary,
                ShiftID = emp.ShiftID,
                IsActive = emp.IsActive,
                Mode = 2
            };
            var depts = _objapp.SelectModelList<IdNameDto>("Procs_GetDepartment", new { DepartmentID = 0, Mode = 3 });
            var desigs = _objapp.SelectModelList<DesignationDto>("Procs_GetDesignation", new { DesignationID = (int?)null, IsActive = (bool?)true, Search = (string)null });

            ViewBag.Departments = depts;
            ViewBag.Designations = desigs;

            return PartialView("_CreateEdit", req);
        }

        // POST: /Employee/Create or /Employee/Edit via AJAX
        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Save(EmployeeRequest request)
        {
            try
            {
                if (request == null)
                    return Json(new { success = false, message = "Invalid request." });

                // Basic validation
                if (string.IsNullOrWhiteSpace(request.FirstName))
                    return Json(new { success = false, message = "First name is required." });

                // Mode should be set by client: 1=Insert, 2=Update, 3=Delete (follow your stored proc convention)
                var result = _objapp.SelectModel<ResultSet>("Procs_InsertUpdateDeleteEmployee", request);
                if (result != null && result.StatusCode == 200)
                    return Json(new { success = true, message = result.Message ?? "Saved" });

                return Json(new { success = false, message = result?.Message ?? "Operation failed." });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message });
            }
        }

        // POST: /Employee/Delete/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Delete(int id)
        {
            try
            {
                var req = new EmployeeRequest { EmployeeID = id, Mode = 3 };
                var result = _objapp.SelectModel<ResultSet>("Procs_InsertUpdateDeleteEmployee", req);
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
