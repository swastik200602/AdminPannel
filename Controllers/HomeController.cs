using AdminPannel.Logic;
using AdminPannel.Models;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;

namespace AdminPannel.Controllers
{
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

        public IActionResult Department()
        {
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
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

                request.Mode = 1; // keep existing behavior
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
    }
}
