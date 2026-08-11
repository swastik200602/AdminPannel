using System;
using System.Collections.Generic;

namespace AdminPannel.Models
{
    // Request DTO used for create/update/delete operations
    public class EmployeeRequest
    {
        public int EmployeeID { get; set; }
        public string EmployeeCode { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string Gender { get; set; }
        public DateTime? DateOfBirth { get; set; }
        public string Email { get; set; }
        public string PhoneNumber { get; set; }
        public string EmergencyContact { get; set; }
        public string Address { get; set; }
        public string City { get; set; }
        public string State { get; set; }
        public string Country { get; set; }
        public string PostalCode { get; set; }
        public int DepartmentID { get; set; }
        public int DesignationID { get; set; }
        public int OfficeLocationID { get; set; }
        public int? ManagerID { get; set; }
        public DateTime? JoiningDate { get; set; }
        public string EmploymentType { get; set; }
        public decimal BasicSalary { get; set; }
        public int? ShiftID { get; set; }
        public bool IsActive { get; set; }
        public int Mode { get; set; }
    }

    // small DTO for dropdowns
    public class IdNameDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
    }

    public class DesignationDto
    {
        public int DesignationID { get; set; }
        public string DesignationName { get; set; }
    }

    // Response DTO used to render lists/details
    public class EmployeeResponse
    {
        public int EmployeeID { get; set; }
        public string EmployeeCode { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string FullName => string.IsNullOrEmpty(FirstName) && string.IsNullOrEmpty(LastName) ? "" : (FirstName + " " + LastName).Trim();
        public string Gender { get; set; }
        public DateTime? DateOfBirth { get; set; }
        public string Email { get; set; }
        public string PhoneNumber { get; set; }
        public string EmergencyContact { get; set; }
        public string Address { get; set; }
        public string City { get; set; }
        public string State { get; set; }
        public string Country { get; set; }
        public string PostalCode { get; set; }
        public int DepartmentID { get; set; }
        public string DepartmentName { get; set; }
        public int DesignationID { get; set; }
        public string DesignationName { get; set; }
        public int OfficeLocationID { get; set; }
        public int? ManagerID { get; set; }
        public DateTime? JoiningDate { get; set; }
        public string EmploymentType { get; set; }
        public decimal BasicSalary { get; set; }
        public int? ShiftID { get; set; }
        public bool IsActive { get; set; }
        public DateTime? CreatedAt { get; set; }
    }
}
