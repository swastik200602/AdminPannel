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
        public int TotalEmployees { get; set; }
        public int ActiveEmployees { get; set; }
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
        public string? OfficeName { get; set; }
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
        public string? ProfileImage { get; set; }
        public string? DepartmentName { get; set; }
        public string? DesignationName { get; set; }
        public string? OfficeName { get; set; }
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

    public class PayrollFilterModel
    {
        public int? EmployeeID { get; set; }
        public byte? PayrollMonth { get; set; }
        public short? PayrollYear { get; set; }
        public string? PaymentStatus { get; set; }
    }

    public class PayrollHistoryFilterModel
    {
        public int? EmployeeID { get; set; }
        public byte? FromMonth { get; set; }
        public short? FromYear { get; set; }
        public byte? ToMonth { get; set; }
        public short? ToYear { get; set; }
        public string? PaymentStatus { get; set; }
    }

    public class PayrollModel
    {
        public int PayrollID { get; set; }
        public int EmployeeID { get; set; }
        public string? EmployeeCode { get; set; }
        public string? EmployeeName { get; set; }
        public byte PayrollMonth { get; set; }
        public short PayrollYear { get; set; }
        public decimal BasicSalary { get; set; }
        public decimal Allowance { get; set; }
        public decimal Bonus { get; set; }
        public decimal Deduction { get; set; }
        public decimal Tax { get; set; }
        public decimal AdvanceRecovery { get; set; }
        public decimal NetSalary { get; set; }
        public DateTime? PaymentDate { get; set; }
        public string? PaymentStatus { get; set; }
        public string? Remarks { get; set; }
        public DateTime? CreatedAt { get; set; }
        public int StatusCode { get; set; }
        public string? Message { get; set; }
    }

    public class PayrollGenerateRequest
    {
        public int EmployeeID { get; set; }
        public byte PayrollMonth { get; set; }
        public short PayrollYear { get; set; }
        public string PaymentStatus { get; set; } = "Pending";
        public string? Remarks { get; set; }
    }

    public class PayrollPaymentStatusRequest
    {
        public int PayrollID { get; set; }
        public string PaymentStatus { get; set; } = "Pending";
        public DateTime? PaymentDate { get; set; }
        public string? Remarks { get; set; }
    }

    public class PayrollSummaryModel
    {
        public int TotalPayrollRecords { get; set; }
        public int PaidCount { get; set; }
        public int PendingCount { get; set; }
        public int ProcessingCount { get; set; }
        public int FailedCount { get; set; }
        public decimal TotalBasicSalary { get; set; }
        public decimal TotalAllowance { get; set; }
        public decimal TotalBonus { get; set; }
        public decimal TotalDeduction { get; set; }
        public decimal TotalTax { get; set; }
        public decimal TotalAdvanceRecovery { get; set; }
        public decimal TotalNetSalary { get; set; }
    }

    public class SalarySlipModel : PayrollModel
    {
        public string? DepartmentName { get; set; }
        public string? DesignationName { get; set; }
        public decimal GrossEarnings { get; set; }
        public decimal TotalDeductions { get; set; }
    }

    public class SalaryMasterFilterModel
    {
        public int? EmployeeID { get; set; }
        public bool? IsActive { get; set; } = true;
    }

    public class SalaryMasterModel
    {
        public int SalaryMasterID { get; set; }
        public int EmployeeID { get; set; }
        public string? EmployeeCode { get; set; }
        public string? EmployeeName { get; set; }
        public decimal BasicSalary { get; set; }
        public decimal Allowance { get; set; }
        public decimal Bonus { get; set; }
        public decimal Deduction { get; set; }
        public decimal Tax { get; set; }
        public DateTime EffectiveFrom { get; set; }
        public DateTime? EffectiveTo { get; set; }
        public bool IsActive { get; set; }
        public string? RevisionReason { get; set; }
        public DateTime? CreatedAt { get; set; }
        public int StatusCode { get; set; }
        public string? Message { get; set; }
    }

    public class SalaryRevisionModel
    {
        public int EmployeeID { get; set; }
        public decimal BasicSalary { get; set; }
        public decimal Allowance { get; set; }
        public decimal Bonus { get; set; }
        public decimal Deduction { get; set; }
        public decimal Tax { get; set; }
        public DateTime EffectiveFrom { get; set; } = DateTime.Today;
        public string? RevisionReason { get; set; }
    }

    public class TaxMasterFilterModel
    {
        public int? EmployeeID { get; set; }
        public string? TaxType { get; set; }
        public bool? IsActive { get; set; } = true;
    }

    public class TaxMasterModel
    {
        public int TaxMasterID { get; set; }
        public int EmployeeID { get; set; }
        public string? EmployeeCode { get; set; }
        public string? EmployeeName { get; set; }
        public string? TaxType { get; set; }
        public decimal TaxAmount { get; set; }
        public DateTime EffectiveFrom { get; set; }
        public DateTime? EffectiveTo { get; set; }
        public bool IsActive { get; set; }
        public string? Reason { get; set; }
        public DateTime? CreatedAt { get; set; }
        public int StatusCode { get; set; }
        public string? Message { get; set; }
    }

    public class TaxRevisionModel
    {
        public int EmployeeID { get; set; }
        public string TaxType { get; set; } = "TDS";
        public decimal TaxAmount { get; set; }
        public DateTime EffectiveFrom { get; set; } = DateTime.Today;
        public string? Reason { get; set; }
    }

    public class BonusFilterModel
    {
        public int? EmployeeID { get; set; }
        public byte? BonusMonth { get; set; }
        public short? BonusYear { get; set; }
        public string? Status { get; set; }
    }

    public class BonusModel
    {
        public int BonusID { get; set; }
        public int EmployeeID { get; set; }
        public string? EmployeeCode { get; set; }
        public string? EmployeeName { get; set; }
        public decimal BonusAmount { get; set; }
        public byte BonusMonth { get; set; }
        public short BonusYear { get; set; }
        public string? BonusType { get; set; }
        public string? Reason { get; set; }
        public string? Status { get; set; }
        public DateTime? PaidDate { get; set; }
        public DateTime? CreatedAt { get; set; }
        public int StatusCode { get; set; }
        public string? Message { get; set; }
    }

    public class BonusRequestModel
    {
        public int EmployeeID { get; set; }
        public decimal BonusAmount { get; set; }
        public byte BonusMonth { get; set; }
        public short BonusYear { get; set; }
        public string? BonusType { get; set; }
        public string? Reason { get; set; }
    }

    public class SalaryAdvanceFilterModel
    {
        public int? EmployeeID { get; set; }
        public string? TransactionType { get; set; }
        public string? Status { get; set; }
    }

    public class SalaryAdvanceModel
    {
        public int SalaryAdvanceID { get; set; }
        public int EmployeeID { get; set; }
        public string? EmployeeCode { get; set; }
        public string? EmployeeName { get; set; }
        public string? TransactionType { get; set; }
        public decimal TotalAmount { get; set; }
        public decimal RecoveredAmount { get; set; }
        public decimal OutstandingAmount { get; set; }
        public decimal MonthlyRecoveryAmount { get; set; }
        public DateTime IssueDate { get; set; }
        public byte RecoveryStartMonth { get; set; }
        public short RecoveryStartYear { get; set; }
        public string? Status { get; set; }
        public string? Remarks { get; set; }
        public DateTime? CreatedAt { get; set; }
    }

    public class SalaryAdvanceRequestModel
    {
        public int EmployeeID { get; set; }
        public string TransactionType { get; set; } = "Advance";
        public decimal TotalAmount { get; set; }
        public decimal MonthlyRecoveryAmount { get; set; }
        public DateTime IssueDate { get; set; } = DateTime.Today;
        public byte RecoveryStartMonth { get; set; } = (byte)DateTime.Today.Month;
        public short RecoveryStartYear { get; set; } = (short)DateTime.Today.Year;
        public string? Remarks { get; set; }
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
        public string? OfficeName { get; set; }
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
        public string OnboardingStatus { get; set; } = "Not started";
        public int OnboardingCompleted { get; set; }
        public int OnboardingTotal { get; set; } = 4;
        public bool IsActive { get; set; }
        public DateTime? CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
    }

    public class EmployeeContextModel
    {
        public int EmployeeID { get; set; }
        public string? FullName { get; set; }
        public string? EmployeeCode { get; set; }
        public string? ProfileImage { get; set; }
        public string? DesignationName { get; set; }
        public string? DepartmentName { get; set; }
        public string? OfficeName { get; set; }
        public DateTime? JoiningDate { get; set; }
        public bool? IsActive { get; set; }
    }

    public class LocationLookup
    {
        public int StateID { get; set; }
        public int CityID { get; set; }
        public string? StateName { get; set; }
        public string? CityName { get; set; }
    }

    public class EmployeeCodeResult
    {
        public string? EmployeeCode { get; set; }
    }

    public class OnboardingStepModel
    {
        public string Key { get; set; } = string.Empty;
        public string Title { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string Status { get; set; } = "Missing";
        public string ActionText { get; set; } = string.Empty;
        public string? ActionController { get; set; }
        public string? ActionName { get; set; }
        public bool IsComplete => Status == "Complete";
        public bool IsOptional => Status == "Optional";
    }

    public class EmployeeOnboardingModel
    {
        public EmployeeResponse Employee { get; set; } = new();
        public List<OnboardingStepModel> Steps { get; set; } = new();
        public List<EmployeeDocumentModel> Documents { get; set; } = new();
        public int CompletedCount => Steps.Count(x => x.IsComplete);
        public int RequiredCount => Steps.Count(x => !x.IsOptional && x.Key != "review");
        public bool ReadyForPayroll => Steps.Where(x => !x.IsOptional && x.Key != "review").All(x => x.IsComplete);
    }

    public class EmployeeDocumentModel
    {
        public int DocumentID { get; set; }
        public int EmployeeID { get; set; }
        public string DocumentType { get; set; } = string.Empty;
        public string DocumentName { get; set; } = string.Empty;
        public string FilePath { get; set; } = string.Empty;
        public string FileExtension { get; set; } = string.Empty;
        public decimal? FileSizeKB { get; set; }
        public DateTime UploadedDate { get; set; }
        public DateTime? ExpiryDate { get; set; }
        public bool IsVerified { get; set; }
        public string? Remarks { get; set; }
    }

    public class EmployeeDocumentsPageModel
    {
        public EmployeeResponse Employee { get; set; } = new();
        public List<EmployeeDocumentModel> Documents { get; set; } = new();
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

    public class AttendanceModel
    {
        public int AttendanceID { get; set; }
        public int EmployeeID { get; set; }
        public string? EmployeeCode { get; set; }
        public string? FullName { get; set; }
        public DateTime AttendanceDate { get; set; }
        public TimeSpan? CheckInTime { get; set; }
        public TimeSpan? CheckOutTime { get; set; }
        public decimal? WorkingHours { get; set; }
        public decimal? OvertimeHours { get; set; }
        public string? Status { get; set; }
        public string? Remarks { get; set; }
        public DateTime CreatedAt { get; set; }
        public int? ShiftID { get; set; }
        public string? ShiftName { get; set; }
    }

    public class LeaveRequestModel
    {
        public int LeaveRequestID { get; set; }
        public int EmployeeID { get; set; }
        public string? EmployeeCode { get; set; }
        public string? FullName { get; set; }
        public int LeaveTypeID { get; set; }
        public string? LeaveTypeName { get; set; }
        public DateTime FromDate { get; set; }
        public DateTime ToDate { get; set; }
        public decimal NumberOfDays { get; set; }
        public string? Reason { get; set; }
        public string? Status { get; set; }
        public int? ApprovedBy { get; set; }
        public string? ApprovedByName { get; set; }
        public DateTime? ApprovedDate { get; set; }
        public string? Remarks { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    public class TaskModel
    {
        public int TaskID { get; set; }
        public int EmployeeID { get; set; }
        public string? EmployeeCode { get; set; }
        public string? EmployeeName { get; set; }
        public int AssignedBy { get; set; }
        public string? AssignedByName { get; set; }
        public string? TaskTitle { get; set; }
        public string? TaskDescription { get; set; }
        public string? Priority { get; set; }
        public string? Status { get; set; }
        public DateTime? StartDate { get; set; }
        public DateTime DueDate { get; set; }
        public DateTime? CompletedDate { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    public class AnnouncementModel
    {
        public int AnnouncementID { get; set; }
        public string? Title { get; set; }
        public string? Description { get; set; }
        public DateTime PublishDate { get; set; }
        public DateTime? ExpiryDate { get; set; }
        public int CreatedBy { get; set; }
        public string? CreatedByName { get; set; }
        public bool IsActive { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
