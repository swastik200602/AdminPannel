namespace AdminPannel.Models
{
    public class AdminModel
    {
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
}
