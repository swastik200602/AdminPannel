namespace AdminPannel.Models
{
    public class AdminModel
    {
        public string? UserName { get; set; }

        // This property name matches dbo.Procs_LoginUser's parameter.  The
        // procedure currently performs the password comparison itself.
        public string? PasswordHash { get; set; }

        public bool RememberMe { get; set; }
    }

    public class EmployeeFilterRequest
    {
        public int? EmployeeID { get; set; }
        public int? DepartmentID { get; set; }
        public int? DesignationID { get; set; }
        public int? OfficeLocationID { get; set; }
        public int? ManagerID { get; set; }
        public int? ShiftID { get; set; }
        public int? RoleID { get; set; }
        public bool? IsActive { get; set; } = true;
        public string? Search { get; set; }
    }

    public class EmployeePageModel
    {
        public List<EmployeeResponse> Employees { get; set; } = new();
        public EmployeeFilterRequest Filter { get; set; } = new();
        public List<DepartmentResponse> Departments { get; set; } = new();
        public List<DesignationResponse> Designations { get; set; } = new();
        public List<OfficeBranchResponse> OfficeBranches { get; set; } = new();
        public List<ShiftResponse> Shifts { get; set; } = new();
        public List<EmployeeResponse> Managers { get; set; } = new();
        public List<RoleResponse> Roles { get; set; } = new();
    }

    // Matches the parameters supported by Procs_InsertUpdateDeleteEmployee.
    public class EmployeeRequest
    {
        public int EmployeeID { get; set; }
        public string? EmployeeCode { get; set; }
        public string? FirstName { get; set; }
        public string? LastName { get; set; }
        public string? Gender { get; set; }
        public DateTime? DateOfBirth { get; set; }
        public string? Email { get; set; }
        public string? PhoneNumber { get; set; }
        public string? EmergencyContact { get; set; }
        public string? Address { get; set; }
        public string? City { get; set; }
        public string? State { get; set; }
        public string? Country { get; set; }
        public string? PostalCode { get; set; }
        public int DepartmentID { get; set; }
        public int DesignationID { get; set; }
        public int OfficeLocationID { get; set; }
        public int? ManagerID { get; set; }
        public DateTime? JoiningDate { get; set; }
        public string? EmploymentType { get; set; }
        public decimal BasicSalary { get; set; }
        public int? ShiftID { get; set; }
        public int RoleID { get; set; }
        public string? ProfileImage { get; set; }
        public IFormFile? ProfileImageFile { get; set; }
        public bool IsActive { get; set; } = true;
    }

    public class EmployeeSelfServiceRequest
    {
        public string? Email { get; set; }
        public string? PhoneNumber { get; set; }
        public string? EmergencyContact { get; set; }
        public string? Address { get; set; }
        public string? City { get; set; }
        public string? State { get; set; }
        public string? Country { get; set; }
        public string? PostalCode { get; set; }
    }

    public class UserRequest
    {
        public int UserID { get; set; }
        public int EmployeeID { get; set; }
        public int RoleID { get; set; }
        public string? UserName { get; set; }
        public string? MobileNo { get; set; }
        public string? Email { get; set; }
        public string? PasswordHash { get; set; }
    }

    public class UserResponse
    {
        public int StatusCode { get; set; }
        public string? Message { get; set; }
        public int UserID { get; set; }
        public int EmployeeID { get; set; }
        public string? EmployeeCode { get; set; }
        public string? FirstName { get; set; }
        public string? LastName { get; set; }
        public string? FullName { get; set; }
        public string? UserName { get; set; }
        public string? UserEmail { get; set; }
        public string? MobileNo { get; set; }
        public int RoleID { get; set; }
        public string? RoleName { get; set; }
        public bool IsActive { get; set; }
        public DateTime? LastLogin { get; set; }
        public DateTime? CreatedAt { get; set; }
    }

    public class ChangePasswordRequest
    {
        public string? CurrentPassword { get; set; }
        public string? NewPassword { get; set; }
        public string? ConfirmPassword { get; set; }
    }

    public class EmployeeResponse
    {
        public int StatusCode { get; set; }
        public string? Message { get; set; }
        public int EmployeeID { get; set; }
        public string? EmployeeCode { get; set; }
        public string? FirstName { get; set; }
        public string? LastName { get; set; }
        public string FullName => string.Join(" ", new[] { FirstName, LastName }.Where(x => !string.IsNullOrWhiteSpace(x))).Trim();
        public string? Gender { get; set; }
        public DateTime? DateOfBirth { get; set; }
        public string? Email { get; set; }
        public string? PhoneNumber { get; set; }
        public string? EmergencyContact { get; set; }
        public string? Address { get; set; }
        public string? City { get; set; }
        public string? State { get; set; }
        public string? Country { get; set; }
        public string? PostalCode { get; set; }
        public int DepartmentID { get; set; }
        public string? DepartmentName { get; set; }
        public int DesignationID { get; set; }
        public string? DesignationName { get; set; }
        public int OfficeLocationID { get; set; }
        public int? ManagerID { get; set; }
        public string? ManagerEmployeeCode { get; set; }
        public string? ManagerName { get; set; }
        public DateTime? JoiningDate { get; set; }
        public string? EmploymentType { get; set; }
        public decimal BasicSalary { get; set; }
        public int? ShiftID { get; set; }
        public int RoleID { get; set; }
        public string? RoleName { get; set; }
        public string? ProfileImage { get; set; }
        public bool IsActive { get; set; }
        public DateTime? CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
    }


    public class DepartmentRequest
    {
        public int DepartmentID { get; set; }

        public string DepartmentName { get; set; }

        public string DepartmentCode { get; set; }

        public string? Description { get; set; }
        public int Mode { get; set; }

    }
    public class DepartmentResponse
    {
        public int DepartmentID { get; set; }

        public string DepartmentName { get; set; }

        public string DepartmentCode { get; set; }

        public string? Description { get; set; }

        public bool IsActive { get; set; }

        public DateTime CreatedAt { get; set; }
    }

    public class ResultSet
    {
        public int Id { get; set; }
        public int StatusCode { get; set; }
        public string Message { get; set; }
    }

    public class DesignationRequest
    {
        public int DesignationID { get; set; }

        public string DesignationName { get; set; }

        public string DesignationCode { get; set; }

        public string? Description { get; set; }

        public int Mode { get; set; }
    }

    public class DesignationResponse
    {
        public int DesignationID { get; set; }

        public string DesignationName { get; set; }

        public string DesignationCode { get; set; }

        public string? Description { get; set; }

        public bool IsActive { get; set; }

        public DateTime CreatedAt { get; set; }
    }

    public class OfficeBranchRequest
    {
        public int OfficeLocationID { get; set; }

        public string OfficeName { get; set; }

        public string OfficeCode { get; set; }

        public string AddressLine1 { get; set; }

        public string? AddressLine2 { get; set; }

        public string City { get; set; }

        public string State { get; set; }

        public string Country { get; set; }

        public string? PostalCode { get; set; }

        public string? PhoneNumber { get; set; }

        public string? Email { get; set; }

        public int Mode { get; set; }
    }

    public class OfficeBranchResponse
    {
        public int OfficeLocationID { get; set; }

        public string OfficeName { get; set; }

        public string OfficeCode { get; set; }

        public string AddressLine1 { get; set; }

        public string? AddressLine2 { get; set; }

        public string City { get; set; }

        public string State { get; set; }

        public string Country { get; set; }

        public string? PostalCode { get; set; }

        public string? PhoneNumber { get; set; }

        public string? Email { get; set; }

        public bool IsActive { get; set; }

        public DateTime CreatedAt { get; set; }
    }

    public class RoleRequest
    {
        public int RoleID { get; set; }

        public string RoleName { get; set; }

        public string? Description { get; set; }

        public int Mode { get; set; }
    }

    public class RoleResponse
    {
        public int RoleID { get; set; }

        public string RoleName { get; set; }

        public string? Description { get; set; }

        public bool IsActive { get; set; }

        public DateTime CreatedAt { get; set; }
    }

    public class ShiftRequest
    {
        public int ShiftID { get; set; }

        public string ShiftName { get; set; }

        public string ShiftCode { get; set; }

        public TimeSpan StartTime { get; set; }

        public TimeSpan EndTime { get; set; }

        public int GraceMinutes { get; set; }

        public bool IsNightShift { get; set; }

        public int Mode { get; set; }
    }

    public class ShiftResponse
    {
        public int ShiftID { get; set; }

        public string ShiftName { get; set; }

        public string ShiftCode { get; set; }

        public TimeSpan StartTime { get; set; }

        public TimeSpan EndTime { get; set; }

        public int GraceMinutes { get; set; }

        public bool IsNightShift { get; set; }

        public bool IsActive { get; set; }

        public DateTime CreatedAt { get; set; }
    }

    public class LeaveTypeRequest
    {
        public int LeaveTypeID { get; set; }

        public string LeaveTypeName { get; set; }

        public string LeaveCode { get; set; }

        public int MaxLeavesPerYear { get; set; }

        public bool IsPaidLeave { get; set; }

        public int Mode { get; set; }
    }

    public class LeaveTypeResponse
    {
        public int LeaveTypeID { get; set; }

        public string LeaveTypeName { get; set; }

        public string LeaveCode { get; set; }

        public int MaxLeavesPerYear { get; set; }

        public bool IsPaidLeave { get; set; }

        public bool IsActive { get; set; }

        public DateTime CreatedAt { get; set; }
    }

    public class HolidayRequest
    {
        public int HolidayID { get; set; }

        public string HolidayName { get; set; }

        public DateTime HolidayDate { get; set; }

        public string HolidayType { get; set; }

        public string? Description { get; set; }

        public bool IsOptional { get; set; }

        public int Mode { get; set; }
    }

    public class HolidayResponse
    {
        public int HolidayID { get; set; }

        public string HolidayName { get; set; }

        public DateTime HolidayDate { get; set; }

        public string HolidayType { get; set; }

        public string? Description { get; set; }

        public bool IsOptional { get; set; }

        public bool IsActive { get; set; }

        public DateTime CreatedAt { get; set; }
    }

    public class LoginResponse
    {
        public int StatusCode { get; set; }
        public string Message { get; set; }

        public int UserID { get; set; }
        public int EmployeeID { get; set; }
        public int RoleID { get; set; }

        public string UserName { get; set; }
        public string? Email { get; set; }
        public string? MobileNo { get; set; }
        public DateTime? LastLogin { get; set; }

        public string? RoleName { get; set; }

        public string? EmployeeCode { get; set; }
        public string? FirstName { get; set; }
        public string? LastName { get; set; }
        public string? EmployeeEmail { get; set; }
        public string? PhoneNumber { get; set; }

        public int DepartmentID { get; set; }
        public int DesignationID { get; set; }
        public int OfficeLocationID { get; set; }
        public int? ManagerID { get; set; }
        public int? ShiftID { get; set; }
        public bool MustChangePassword { get; set; }
    }
}
