/*****************************************************************************************
 * EMPLOYEE MANAGEMENT SYSTEM - MASTER & INITIAL SEED DATA
 * Database:    EmployeeManagementDB
 * Generated:   2026-09-01 14:54:43
 * Description: Inserts foundational master lookup records, tax/salary brackets,
 *              office locations, departments, roles, and initial seed users/employees.
 *****************************************************************************************/
USE [EmployeeManagementDB];
GO

SET NOCOUNT ON;
GO

-- -------------------------------------------------------------------------------
-- Data for: [dbo].[M_Role] (4 rows)
-- -------------------------------------------------------------------------------
INSERT INTO [dbo].[M_Role] ([RoleID], [RoleName], [Description], [IsActive], [CreatedAt]) VALUES (0, N'Admin', N'Full system access', NULL, '2026-08-07 10:49:55.9076782');
INSERT INTO [dbo].[M_Role] ([RoleID], [RoleName], [Description], [IsActive], [CreatedAt]) VALUES (1, N'HR', N'Human Resource Management', NULL, '2026-08-07 10:49:55.9076782');
INSERT INTO [dbo].[M_Role] ([RoleID], [RoleName], [Description], [IsActive], [CreatedAt]) VALUES (2, N'Manager', N'Department Management', NULL, '2026-08-07 10:49:55.9076782');
INSERT INTO [dbo].[M_Role] ([RoleID], [RoleName], [Description], [IsActive], [CreatedAt]) VALUES (3, N'Employee', N'Standard Employee Access', NULL, '2026-08-07 10:49:55.9076782');
GO

-- -------------------------------------------------------------------------------
-- Data for: [dbo].[M_Department] (6 rows)
-- -------------------------------------------------------------------------------
SET IDENTITY_INSERT [dbo].[M_Department] ON;
INSERT INTO [dbo].[M_Department] ([DepartmentID], [DepartmentName], [DepartmentCode], [Description], [IsActive], [CreatedAt]) VALUES (1, N'Information Technology', N'IT', N'Handles software development and IT infrastructure', NULL, '2026-08-07 10:59:17.7443214');
INSERT INTO [dbo].[M_Department] ([DepartmentID], [DepartmentName], [DepartmentCode], [Description], [IsActive], [CreatedAt]) VALUES (2, N'Human Resources', N'HR', N'Handles recruitment and employee management', NULL, '2026-08-07 10:59:17.7443214');
INSERT INTO [dbo].[M_Department] ([DepartmentID], [DepartmentName], [DepartmentCode], [Description], [IsActive], [CreatedAt]) VALUES (3, N'Finance', N'FIN', N'Handles company finances and payroll', NULL, '2026-08-07 10:59:17.7443214');
INSERT INTO [dbo].[M_Department] ([DepartmentID], [DepartmentName], [DepartmentCode], [Description], [IsActive], [CreatedAt]) VALUES (4, N'Sales', N'SAL', N'Responsible for sales and customer acquisition', NULL, '2026-08-07 10:59:17.7443214');
INSERT INTO [dbo].[M_Department] ([DepartmentID], [DepartmentName], [DepartmentCode], [Description], [IsActive], [CreatedAt]) VALUES (5, N'Marketing', N'MKT', N'Handles branding and marketing campaigns', NULL, '2026-08-07 10:59:17.7443214');
INSERT INTO [dbo].[M_Department] ([DepartmentID], [DepartmentName], [DepartmentCode], [Description], [IsActive], [CreatedAt]) VALUES (6, N'Operations', N'OPS', N'Handles day-to-day business operations', NULL, '2026-08-07 10:59:17.7443214');
SET IDENTITY_INSERT [dbo].[M_Department] OFF;
GO

-- -------------------------------------------------------------------------------
-- Data for: [dbo].[M_Designation] (10 rows)
-- -------------------------------------------------------------------------------
SET IDENTITY_INSERT [dbo].[M_Designation] ON;
INSERT INTO [dbo].[M_Designation] ([DesignationID], [DesignationName], [DesignationCode], [Description], [IsActive], [CreatedAt]) VALUES (1, N'Software Engineer', N'SE', N'Software Development', NULL, '2026-08-07 11:01:36.0128763');
INSERT INTO [dbo].[M_Designation] ([DesignationID], [DesignationName], [DesignationCode], [Description], [IsActive], [CreatedAt]) VALUES (2, N'Senior Software Engineer', N'SSE', N'Senior Developer', NULL, '2026-08-07 11:01:36.0128763');
INSERT INTO [dbo].[M_Designation] ([DesignationID], [DesignationName], [DesignationCode], [Description], [IsActive], [CreatedAt]) VALUES (3, N'Team Lead', N'TL', N'Team Management', NULL, '2026-08-07 11:01:36.0128763');
INSERT INTO [dbo].[M_Designation] ([DesignationID], [DesignationName], [DesignationCode], [Description], [IsActive], [CreatedAt]) VALUES (4, N'Project Manager', N'PM', N'Project Management', NULL, '2026-08-07 11:01:36.0128763');
INSERT INTO [dbo].[M_Designation] ([DesignationID], [DesignationName], [DesignationCode], [Description], [IsActive], [CreatedAt]) VALUES (5, N'HR Executive', N'HRE', N'Human Resource', NULL, '2026-08-07 11:01:36.0128763');
INSERT INTO [dbo].[M_Designation] ([DesignationID], [DesignationName], [DesignationCode], [Description], [IsActive], [CreatedAt]) VALUES (6, N'Accountant', N'ACC', N'Finance', NULL, '2026-08-07 11:01:36.0128763');
INSERT INTO [dbo].[M_Designation] ([DesignationID], [DesignationName], [DesignationCode], [Description], [IsActive], [CreatedAt]) VALUES (7, N'Marketing Executive', N'ME', N'Marketing', NULL, '2026-08-07 11:01:36.0128763');
INSERT INTO [dbo].[M_Designation] ([DesignationID], [DesignationName], [DesignationCode], [Description], [IsActive], [CreatedAt]) VALUES (8, N'Sales Executive', N'SALE', N'Sales', NULL, '2026-08-07 11:01:36.0128763');
INSERT INTO [dbo].[M_Designation] ([DesignationID], [DesignationName], [DesignationCode], [Description], [IsActive], [CreatedAt]) VALUES (9, N'nhn', N'jjgfjkugjk', N'kjytgyuhkj', 0, '2026-08-13 15:21:36.1238218');
INSERT INTO [dbo].[M_Designation] ([DesignationID], [DesignationName], [DesignationCode], [Description], [IsActive], [CreatedAt]) VALUES (10, N'uikluigoiu', N'uiouitotuoui', N'uioouiouy', 0, '2026-08-13 15:23:22.4907136');
SET IDENTITY_INSERT [dbo].[M_Designation] OFF;
GO

-- -------------------------------------------------------------------------------
-- Data for: [dbo].[M_OfficeBranch] (4 rows)
-- -------------------------------------------------------------------------------
SET IDENTITY_INSERT [dbo].[M_OfficeBranch] ON;
INSERT INTO [dbo].[M_OfficeBranch] ([OfficeLocationID], [OfficeName], [OfficeCode], [AddressLine1], [AddressLine2], [City], [State], [Country], [PostalCode], [PhoneNumber], [Email], [IsActive], [CreatedAt]) VALUES (1, N'Head Office', N'HO', N'Sector 62', NULL, N'Noida', N'Uttar Pradesh', N'India', N'201309', N'0120-4000000', N'headoffice@company.com', NULL, '2026-08-07 11:04:53.2102585');
INSERT INTO [dbo].[M_OfficeBranch] ([OfficeLocationID], [OfficeName], [OfficeCode], [AddressLine1], [AddressLine2], [City], [State], [Country], [PostalCode], [PhoneNumber], [Email], [IsActive], [CreatedAt]) VALUES (2, N'Delhi Branch', N'DEL', N'Nehru Place', NULL, N'New Delhi', N'Delhi', N'India', N'110019', N'011-45000000', N'delhi@company.com', NULL, '2026-08-07 11:04:53.2102585');
INSERT INTO [dbo].[M_OfficeBranch] ([OfficeLocationID], [OfficeName], [OfficeCode], [AddressLine1], [AddressLine2], [City], [State], [Country], [PostalCode], [PhoneNumber], [Email], [IsActive], [CreatedAt]) VALUES (3, N'Bangalore Branch', N'BLR', N'Electronic City', NULL, N'Bengaluru', N'Karnataka', N'India', N'560100', N'080-42000000', N'bangalore@company.com', NULL, '2026-08-07 11:04:53.2102585');
INSERT INTO [dbo].[M_OfficeBranch] ([OfficeLocationID], [OfficeName], [OfficeCode], [AddressLine1], [AddressLine2], [City], [State], [Country], [PostalCode], [PhoneNumber], [Email], [IsActive], [CreatedAt]) VALUES (4, N'jgcjgcghj', N'nvcbvcngcn ', N'vbcbg nb ', N'fcfhfchgfcfc', N'nchgcghytch', N'nbvchfchfd', N'jgdtfhdhfcf ', N'1515151', N'15151511', N'vdsgrstrstrysrg', 0, '2026-08-13 17:05:25.8880701');
SET IDENTITY_INSERT [dbo].[M_OfficeBranch] OFF;
GO

-- -------------------------------------------------------------------------------
-- Data for: [dbo].[M_Shift] (4 rows)
-- -------------------------------------------------------------------------------
SET IDENTITY_INSERT [dbo].[M_Shift] ON;
INSERT INTO [dbo].[M_Shift] ([ShiftID], [ShiftName], [ShiftCode], [StartTime], [EndTime], [GraceMinutes], [IsNightShift], [IsActive], [CreatedAt]) VALUES (1, N'Morning Shift', N'MS', '09:00:00', '18:00:00', 15, 0, NULL, '2026-08-08 10:11:31.7793802');
INSERT INTO [dbo].[M_Shift] ([ShiftID], [ShiftName], [ShiftCode], [StartTime], [EndTime], [GraceMinutes], [IsNightShift], [IsActive], [CreatedAt]) VALUES (2, N'General Shift', N'GS', '10:00:00', '19:00:00', 10, 0, NULL, '2026-08-08 10:11:31.7793802');
INSERT INTO [dbo].[M_Shift] ([ShiftID], [ShiftName], [ShiftCode], [StartTime], [EndTime], [GraceMinutes], [IsNightShift], [IsActive], [CreatedAt]) VALUES (3, N'Night Shift', N'NS', '21:00:00', '06:00:00', 20, NULL, NULL, '2026-08-08 10:11:31.7793802');
INSERT INTO [dbo].[M_Shift] ([ShiftID], [ShiftName], [ShiftCode], [StartTime], [EndTime], [GraceMinutes], [IsNightShift], [IsActive], [CreatedAt]) VALUES (4, N'n mb', N'fdvsd', '10:20:00', '20:52:00', 59496, 0, 0, '2026-08-13 17:56:51.4200679');
SET IDENTITY_INSERT [dbo].[M_Shift] OFF;
GO

-- -------------------------------------------------------------------------------
-- Data for: [dbo].[M_LeaveType] (7 rows)
-- -------------------------------------------------------------------------------
SET IDENTITY_INSERT [dbo].[M_LeaveType] ON;
INSERT INTO [dbo].[M_LeaveType] ([LeaveTypeID], [LeaveTypeName], [LeaveCode], [MaxLeavesPerYear], [IsPaidLeave], [IsActive], [CreatedAt]) VALUES (1, N'Casual Leave', N'CL', 12, NULL, NULL, '2026-08-08 10:16:14.911673');
INSERT INTO [dbo].[M_LeaveType] ([LeaveTypeID], [LeaveTypeName], [LeaveCode], [MaxLeavesPerYear], [IsPaidLeave], [IsActive], [CreatedAt]) VALUES (2, N'Sick Leave', N'SL', 10, NULL, NULL, '2026-08-08 10:16:14.911673');
INSERT INTO [dbo].[M_LeaveType] ([LeaveTypeID], [LeaveTypeName], [LeaveCode], [MaxLeavesPerYear], [IsPaidLeave], [IsActive], [CreatedAt]) VALUES (3, N'Earned Leave', N'EL', 18, NULL, NULL, '2026-08-08 10:16:14.911673');
INSERT INTO [dbo].[M_LeaveType] ([LeaveTypeID], [LeaveTypeName], [LeaveCode], [MaxLeavesPerYear], [IsPaidLeave], [IsActive], [CreatedAt]) VALUES (4, N'Maternity Leave', N'ML', 180, NULL, NULL, '2026-08-08 10:16:14.911673');
INSERT INTO [dbo].[M_LeaveType] ([LeaveTypeID], [LeaveTypeName], [LeaveCode], [MaxLeavesPerYear], [IsPaidLeave], [IsActive], [CreatedAt]) VALUES (5, N'Paternity Leave', N'PL', 15, NULL, NULL, '2026-08-08 10:16:14.911673');
INSERT INTO [dbo].[M_LeaveType] ([LeaveTypeID], [LeaveTypeName], [LeaveCode], [MaxLeavesPerYear], [IsPaidLeave], [IsActive], [CreatedAt]) VALUES (6, N'Loss Of Pay', N'LOP', 365, 0, NULL, '2026-08-08 10:16:14.911673');
INSERT INTO [dbo].[M_LeaveType] ([LeaveTypeID], [LeaveTypeName], [LeaveCode], [MaxLeavesPerYear], [IsPaidLeave], [IsActive], [CreatedAt]) VALUES (7, N'Work From Home', N'WFH', 365, NULL, NULL, '2026-08-08 10:16:14.911673');
SET IDENTITY_INSERT [dbo].[M_LeaveType] OFF;
GO

-- -------------------------------------------------------------------------------
-- Data for: [dbo].[M_Holiday] (7 rows)
-- -------------------------------------------------------------------------------
SET IDENTITY_INSERT [dbo].[M_Holiday] ON;
INSERT INTO [dbo].[M_Holiday] ([HolidayID], [HolidayName], [HolidayDate], [HolidayType], [Description], [IsOptional], [IsActive], [CreatedAt]) VALUES (1, N'Republic Day', '2026-01-26', N'National', N'National Holiday', 0, NULL, '2026-08-08 10:31:18.1234973');
INSERT INTO [dbo].[M_Holiday] ([HolidayID], [HolidayName], [HolidayDate], [HolidayType], [Description], [IsOptional], [IsActive], [CreatedAt]) VALUES (2, N'Holi', '2026-03-04', N'Festival', N'Festival of Colors', 0, NULL, '2026-08-08 10:31:18.1234973');
INSERT INTO [dbo].[M_Holiday] ([HolidayID], [HolidayName], [HolidayDate], [HolidayType], [Description], [IsOptional], [IsActive], [CreatedAt]) VALUES (3, N'Good Friday', '2026-04-03', N'Festival', N'Good Friday Holiday', 0, NULL, '2026-08-08 10:31:18.1234973');
INSERT INTO [dbo].[M_Holiday] ([HolidayID], [HolidayName], [HolidayDate], [HolidayType], [Description], [IsOptional], [IsActive], [CreatedAt]) VALUES (4, N'Independence Day', '2026-08-15', N'National', N'National Holiday', 0, NULL, '2026-08-08 10:31:18.1234973');
INSERT INTO [dbo].[M_Holiday] ([HolidayID], [HolidayName], [HolidayDate], [HolidayType], [Description], [IsOptional], [IsActive], [CreatedAt]) VALUES (5, N'Diwali', '2026-11-08', N'Festival', N'Festival of Lights', 0, NULL, '2026-08-08 10:31:18.1234973');
INSERT INTO [dbo].[M_Holiday] ([HolidayID], [HolidayName], [HolidayDate], [HolidayType], [Description], [IsOptional], [IsActive], [CreatedAt]) VALUES (6, N'Christmas', '2026-12-25', N'Festival', N'Christmas Celebration', 0, NULL, '2026-08-08 10:31:18.1234973');
INSERT INTO [dbo].[M_Holiday] ([HolidayID], [HolidayName], [HolidayDate], [HolidayType], [Description], [IsOptional], [IsActive], [CreatedAt]) VALUES (7, N'Company Annual Day', '2026-10-10', N'Company', N'Annual Celebration', NULL, NULL, '2026-08-08 10:31:18.1234973');
SET IDENTITY_INSERT [dbo].[M_Holiday] OFF;
GO

-- -------------------------------------------------------------------------------
-- Data for: [dbo].[M_IndiaState] (36 rows)
-- -------------------------------------------------------------------------------
SET IDENTITY_INSERT [dbo].[M_IndiaState] ON;
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (1, N'Andhra Pradesh', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (2, N'Arunachal Pradesh', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (3, N'Assam', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (4, N'Bihar', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (5, N'Chhattisgarh', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (6, N'Goa', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (7, N'Gujarat', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (8, N'Haryana', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (9, N'Himachal Pradesh', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (10, N'Jharkhand', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (11, N'Karnataka', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (12, N'Kerala', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (13, N'Madhya Pradesh', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (14, N'Maharashtra', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (15, N'Manipur', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (16, N'Meghalaya', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (17, N'Mizoram', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (18, N'Nagaland', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (19, N'Odisha', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (20, N'Punjab', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (21, N'Rajasthan', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (22, N'Sikkim', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (23, N'Tamil Nadu', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (24, N'Telangana', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (25, N'Tripura', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (26, N'Uttar Pradesh', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (27, N'Uttarakhand', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (28, N'West Bengal', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (29, N'Andaman and Nicobar Islands', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (30, N'Chandigarh', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (31, N'Dadra and Nagar Haveli and Daman and Diu', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (32, N'Delhi', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (33, N'Jammu and Kashmir', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (34, N'Ladakh', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (35, N'Lakshadweep', NULL);
INSERT INTO [dbo].[M_IndiaState] ([StateID], [StateName], [IsActive]) VALUES (36, N'Puducherry', NULL);
SET IDENTITY_INSERT [dbo].[M_IndiaState] OFF;
GO

-- -------------------------------------------------------------------------------
-- Data for: [dbo].[M_IndiaCity] (3 rows)
-- -------------------------------------------------------------------------------
SET IDENTITY_INSERT [dbo].[M_IndiaCity] ON;
INSERT INTO [dbo].[M_IndiaCity] ([CityID], [StateID], [CityName], [IsActive]) VALUES (1, 26, N'Noida', NULL);
INSERT INTO [dbo].[M_IndiaCity] ([CityID], [StateID], [CityName], [IsActive]) VALUES (2, 32, N'New Delhi', NULL);
INSERT INTO [dbo].[M_IndiaCity] ([CityID], [StateID], [CityName], [IsActive]) VALUES (3, 11, N'Bengaluru', NULL);
SET IDENTITY_INSERT [dbo].[M_IndiaCity] OFF;
GO

-- -------------------------------------------------------------------------------
-- Data for: [dbo].[M_SalaryMaster] (4 rows)
-- -------------------------------------------------------------------------------
SET IDENTITY_INSERT [dbo].[M_SalaryMaster] ON;
INSERT INTO [dbo].[M_SalaryMaster] ([SalaryMasterID], [EmployeeID], [BasicSalary], [Allowance], [Bonus], [Deduction], [Tax], [EffectiveFrom], [EffectiveTo], [IsActive], [RevisionReason], [CreatedAt]) VALUES (1, 1, 30000.00, 2000.00, 1000.00, 500.00, 1500.00, '2026-08-01', '2026-08-31', 0, N'Joining Salary', '2026-08-20 10:24:09.814003');
INSERT INTO [dbo].[M_SalaryMaster] ([SalaryMasterID], [EmployeeID], [BasicSalary], [Allowance], [Bonus], [Deduction], [Tax], [EffectiveFrom], [EffectiveTo], [IsActive], [RevisionReason], [CreatedAt]) VALUES (2, 1, 40000.00, 3000.00, 2000.00, 500.00, 2000.00, '2026-09-01', NULL, NULL, N'Promotion - Salary Increment', '2026-08-20 10:24:42.7377286');
INSERT INTO [dbo].[M_SalaryMaster] ([SalaryMasterID], [EmployeeID], [BasicSalary], [Allowance], [Bonus], [Deduction], [Tax], [EffectiveFrom], [EffectiveTo], [IsActive], [RevisionReason], [CreatedAt]) VALUES (3, 9, 450000.00, 0.00, 0.00, 0.00, 0.00, '2026-08-20', '2026-08-20', 0, NULL, '2026-08-20 19:52:08.3380499');
INSERT INTO [dbo].[M_SalaryMaster] ([SalaryMasterID], [EmployeeID], [BasicSalary], [Allowance], [Bonus], [Deduction], [Tax], [EffectiveFrom], [EffectiveTo], [IsActive], [RevisionReason], [CreatedAt]) VALUES (4, 9, 45000000.00, 0.00, 0.00, 0.00, 0.00, '2026-08-21', NULL, NULL, NULL, '2026-08-21 11:47:57.2674864');
SET IDENTITY_INSERT [dbo].[M_SalaryMaster] OFF;
GO

-- -------------------------------------------------------------------------------
-- Data for: [dbo].[M_TaxMaster] (2 rows)
-- -------------------------------------------------------------------------------
SET IDENTITY_INSERT [dbo].[M_TaxMaster] ON;
INSERT INTO [dbo].[M_TaxMaster] ([TaxMasterID], [EmployeeID], [TaxType], [TaxAmount], [EffectiveFrom], [EffectiveTo], [IsActive], [Reason], [CreatedAt], [CreatedBy]) VALUES (1, 1, N'TDS', 2000.00, '2026-08-01', '2026-08-31', 0, N'Initial TDS configuration', '2026-08-20 11:04:24.1200345', NULL);
INSERT INTO [dbo].[M_TaxMaster] ([TaxMasterID], [EmployeeID], [TaxType], [TaxAmount], [EffectiveFrom], [EffectiveTo], [IsActive], [Reason], [CreatedAt], [CreatedBy]) VALUES (2, 1, N'TDS', 2500.00, '2026-09-01', NULL, NULL, N'TDS revision', '2026-08-20 11:04:40.7550919', NULL);
SET IDENTITY_INSERT [dbo].[M_TaxMaster] OFF;
GO

-- -------------------------------------------------------------------------------
-- Data for: [dbo].[T_Employee] (6 rows)
-- -------------------------------------------------------------------------------
SET IDENTITY_INSERT [dbo].[T_Employee] ON;
INSERT INTO [dbo].[T_Employee] ([EmployeeID], [EmployeeCode], [FirstName], [LastName], [Gender], [DateOfBirth], [Email], [PhoneNumber], [EmergencyContact], [Address], [City], [State], [Country], [PostalCode], [DepartmentID], [DesignationID], [OfficeLocationID], [ManagerID], [JoiningDate], [EmploymentType], [BasicSalary], [IsActive], [CreatedAt], [UpdatedAt], [ShiftID], [RoleID], [ProfileImage]) VALUES (1, N'EMP001', N'Rahul', N'Sharma', N'Male', '1990-05-12', N'myname@corp.com', N'9876543210', N'9998887776', N'New Address Line', N'Indore', N'MP', N'India', N'452001', 1, 4, 1, NULL, '2020-01-15', N'Full-Time', 85000.00, NULL, '2026-08-07 12:04:03.3223346', '2026-08-23 21:59:20.7089141', 1, 2, NULL);
INSERT INTO [dbo].[T_Employee] ([EmployeeID], [EmployeeCode], [FirstName], [LastName], [Gender], [DateOfBirth], [Email], [PhoneNumber], [EmergencyContact], [Address], [City], [State], [Country], [PostalCode], [DepartmentID], [DesignationID], [OfficeLocationID], [ManagerID], [JoiningDate], [EmploymentType], [BasicSalary], [IsActive], [CreatedAt], [UpdatedAt], [ShiftID], [RoleID], [ProfileImage]) VALUES (2, N'EMP002', N'Swastik', N'Singh', N'Male', '2005-03-16', N'swastik.singh@company.com', N'9876543212', N'9876543213', N'Civil Lines', N'Raebareli', N'Uttar Pradesh', N'India', N'229001', 1, 1, 1, 1, '2026-08-01', N'Intern', 25000.00, NULL, '2026-08-07 12:04:03.3223346', NULL, 1, 3, NULL);
INSERT INTO [dbo].[T_Employee] ([EmployeeID], [EmployeeCode], [FirstName], [LastName], [Gender], [DateOfBirth], [Email], [PhoneNumber], [EmergencyContact], [Address], [City], [State], [Country], [PostalCode], [DepartmentID], [DesignationID], [OfficeLocationID], [ManagerID], [JoiningDate], [EmploymentType], [BasicSalary], [IsActive], [CreatedAt], [UpdatedAt], [ShiftID], [RoleID], [ProfileImage]) VALUES (3, N'EMP003', N'Aman', N'Verma', N'Male', '1998-09-20', N'aman.verma@company.com', N'9876543214', N'9876543215', N'MG Road', N'Bengaluru', N'Karnataka', N'India', N'560001', 2, 5, 3, 1, '2023-06-10', N'Full-Time', 50000.00, NULL, '2026-08-07 12:04:03.3223346', NULL, 2, 3, NULL);
INSERT INTO [dbo].[T_Employee] ([EmployeeID], [EmployeeCode], [FirstName], [LastName], [Gender], [DateOfBirth], [Email], [PhoneNumber], [EmergencyContact], [Address], [City], [State], [Country], [PostalCode], [DepartmentID], [DesignationID], [OfficeLocationID], [ManagerID], [JoiningDate], [EmploymentType], [BasicSalary], [IsActive], [CreatedAt], [UpdatedAt], [ShiftID], [RoleID], [ProfileImage]) VALUES (4, N'EMP004', N'Priya', N'Gupta', N'Female', '1997-12-05', N'priya.gupta@company.com', N'9876543216', N'9876543217', N'Laxmi Nagar', N'New Delhi', N'Delhi', N'India', N'110092', 3, 6, 2, 1, '2022-04-20', N'Full-Time', 60.00, NULL, '2026-08-07 12:04:03.3223346', '2026-08-18 13:44:04.4029665', 3, 3, NULL);
INSERT INTO [dbo].[T_Employee] ([EmployeeID], [EmployeeCode], [FirstName], [LastName], [Gender], [DateOfBirth], [Email], [PhoneNumber], [EmergencyContact], [Address], [City], [State], [Country], [PostalCode], [DepartmentID], [DesignationID], [OfficeLocationID], [ManagerID], [JoiningDate], [EmploymentType], [BasicSalary], [IsActive], [CreatedAt], [UpdatedAt], [ShiftID], [RoleID], [ProfileImage]) VALUES (5, N'EMP005', N'Alok', N'Chauhan', N'male', '2006-10-02', N'veenusingh828@gmail.com', N'9369559468', N'6392032485', N'Pragatipuram, Raebareli', N'Raebareli', N'Uttarpradesh', N'India', N'229001', 2, 5, 1, 1, '2026-08-19', N'Full-Time', 10000000000.00, NULL, '2026-08-19 16:24:25.6428047', '2026-08-19 16:24:25.6428047', NULL, 1, N'/uploads/employees/e234081e3dcc4e91bf1e38cf74005609.png');
INSERT INTO [dbo].[T_Employee] ([EmployeeID], [EmployeeCode], [FirstName], [LastName], [Gender], [DateOfBirth], [Email], [PhoneNumber], [EmergencyContact], [Address], [City], [State], [Country], [PostalCode], [DepartmentID], [DesignationID], [OfficeLocationID], [ManagerID], [JoiningDate], [EmploymentType], [BasicSalary], [IsActive], [CreatedAt], [UpdatedAt], [ShiftID], [RoleID], [ProfileImage]) VALUES (9, N'EMP006', N'Harshit', N'Singh', N'Male', '2005-02-01', N'Swastikiit2023@gmail.com', N'06392032485', N'8957443189', N'JB Institute of technology NH-07, Chakrata Rd, Shankarpur, Uttarakhand 248197', N'Dheradun', N'Uttarakhand', N'India', N'248197', 1, 1, 2, 1, '2026-08-20', N'Intern', 450000.00, NULL, '2026-08-20 19:47:50.3220529', '2026-08-21 01:05:12.7997451', 2, 3, N'/uploads/employees/b39fd60cd05244a7b8ab20d756d68753.png');
SET IDENTITY_INSERT [dbo].[T_Employee] OFF;
GO

-- -------------------------------------------------------------------------------
-- Data for: [dbo].[T_Users] (6 rows)
-- -------------------------------------------------------------------------------
SET IDENTITY_INSERT [dbo].[T_Users] ON;
INSERT INTO [dbo].[T_Users] ([UserID], [EmployeeID], [RoleID], [UserName], [PasswordHash], [PasswordSalt], [MobileNo], [Email], [LastLogin], [WrongCount], [IsActive], [CreatedAt], [MustChangePassword], [PasswordChangedAt], [PasswordResetToken], [PasswordResetExpiresAt]) VALUES (1, 0, 0, N'Admin', N'123', N'123', N'888888888', N'test@gmail.comm', '2026-08-31 10:43:23.8691125', 4, NULL, '2026-08-14 12:11:45.3158742', 0, NULL, NULL, NULL);
INSERT INTO [dbo].[T_Users] ([UserID], [EmployeeID], [RoleID], [UserName], [PasswordHash], [PasswordSalt], [MobileNo], [Email], [LastLogin], [WrongCount], [IsActive], [CreatedAt], [MustChangePassword], [PasswordChangedAt], [PasswordResetToken], [PasswordResetExpiresAt]) VALUES (2, 3, 3, N'xyzzzz', N'D95812C68AB2A963C52796B3C8E34F49CD6BB27471E2E84769290D71105A0070', N'AB70A6C1852B4EF2BDB2F48D539505BA', NULL, NULL, '2026-08-18 14:54:46.404917', 0, NULL, '2026-08-18 14:48:36.7603004', 0, '2026-08-18 14:50:22.6021166', NULL, NULL);
INSERT INTO [dbo].[T_Users] ([UserID], [EmployeeID], [RoleID], [UserName], [PasswordHash], [PasswordSalt], [MobileNo], [Email], [LastLogin], [WrongCount], [IsActive], [CreatedAt], [MustChangePassword], [PasswordChangedAt], [PasswordResetToken], [PasswordResetExpiresAt]) VALUES (3, 2, 2, N'swas', N'123', NULL, NULL, NULL, '2026-08-27 18:04:31.871982', 0, NULL, '2026-08-19 15:24:07.6550856', NULL, NULL, NULL, NULL);
INSERT INTO [dbo].[T_Users] ([UserID], [EmployeeID], [RoleID], [UserName], [PasswordHash], [PasswordSalt], [MobileNo], [Email], [LastLogin], [WrongCount], [IsActive], [CreatedAt], [MustChangePassword], [PasswordChangedAt], [PasswordResetToken], [PasswordResetExpiresAt]) VALUES (4, 1, 2, N'rahul', N'123', NULL, NULL, NULL, '2026-08-31 10:43:47.1205534', 0, NULL, '2026-08-19 16:05:50.1366424', 0, NULL, NULL, NULL);
INSERT INTO [dbo].[T_Users] ([UserID], [EmployeeID], [RoleID], [UserName], [PasswordHash], [PasswordSalt], [MobileNo], [Email], [LastLogin], [WrongCount], [IsActive], [CreatedAt], [MustChangePassword], [PasswordChangedAt], [PasswordResetToken], [PasswordResetExpiresAt]) VALUES (5, 5, 1, N'dada', N'123', NULL, NULL, NULL, '2026-08-31 11:40:01.0278522', 0, NULL, '2026-08-19 16:34:25.3135375', 0, NULL, NULL, NULL);
INSERT INTO [dbo].[T_Users] ([UserID], [EmployeeID], [RoleID], [UserName], [PasswordHash], [PasswordSalt], [MobileNo], [Email], [LastLogin], [WrongCount], [IsActive], [CreatedAt], [MustChangePassword], [PasswordChangedAt], [PasswordResetToken], [PasswordResetExpiresAt]) VALUES (6, 9, 3, N'Harshit', N'123', NULL, NULL, NULL, '2026-08-27 12:53:42.0801218', 0, NULL, '2026-08-21 01:07:01.7780016', 0, NULL, NULL, NULL);
SET IDENTITY_INSERT [dbo].[T_Users] OFF;
GO

-- -------------------------------------------------------------------------------
-- Data for: [dbo].[T_Attendance] (9 rows)
-- -------------------------------------------------------------------------------
SET IDENTITY_INSERT [dbo].[T_Attendance] ON;
INSERT INTO [dbo].[T_Attendance] ([AttendanceID], [EmployeeID], [AttendanceDate], [CheckInTime], [CheckOutTime], [WorkingHours], [OvertimeHours], [Status], [Remarks], [CreatedAt], [ShiftID]) VALUES (1, 1, '2026-08-07', '09:00:00', '18:00:00', 9.00, 1.00, N'Present', NULL, '2026-08-08 10:03:15.4500064', NULL);
INSERT INTO [dbo].[T_Attendance] ([AttendanceID], [EmployeeID], [AttendanceDate], [CheckInTime], [CheckOutTime], [WorkingHours], [OvertimeHours], [Status], [Remarks], [CreatedAt], [ShiftID]) VALUES (2, 2, '2026-08-07', '09:15:00', '18:10:00', 8.92, 0.00, N'Present', N'Intern', '2026-08-08 10:03:15.4500064', NULL);
INSERT INTO [dbo].[T_Attendance] ([AttendanceID], [EmployeeID], [AttendanceDate], [CheckInTime], [CheckOutTime], [WorkingHours], [OvertimeHours], [Status], [Remarks], [CreatedAt], [ShiftID]) VALUES (3, 3, '2026-08-07', '09:05:00', '17:50:00', 8.75, 0.00, N'Present', NULL, '2026-08-08 10:03:15.4500064', NULL);
INSERT INTO [dbo].[T_Attendance] ([AttendanceID], [EmployeeID], [AttendanceDate], [CheckInTime], [CheckOutTime], [WorkingHours], [OvertimeHours], [Status], [Remarks], [CreatedAt], [ShiftID]) VALUES (4, 4, '2026-08-07', NULL, NULL, NULL, NULL, N'Leave', N'Approved Leave', '2026-08-08 10:03:15.4500064', NULL);
INSERT INTO [dbo].[T_Attendance] ([AttendanceID], [EmployeeID], [AttendanceDate], [CheckInTime], [CheckOutTime], [WorkingHours], [OvertimeHours], [Status], [Remarks], [CreatedAt], [ShiftID]) VALUES (5, 1, '2026-08-25', '16:38:00', '16:38:00', NULL, NULL, N'Present', NULL, '2026-08-25 16:38:27.4657699', NULL);
INSERT INTO [dbo].[T_Attendance] ([AttendanceID], [EmployeeID], [AttendanceDate], [CheckInTime], [CheckOutTime], [WorkingHours], [OvertimeHours], [Status], [Remarks], [CreatedAt], [ShiftID]) VALUES (6, 5, '2026-08-27', NULL, NULL, NULL, NULL, N'Present', NULL, '2026-08-27 11:34:34.515147', NULL);
INSERT INTO [dbo].[T_Attendance] ([AttendanceID], [EmployeeID], [AttendanceDate], [CheckInTime], [CheckOutTime], [WorkingHours], [OvertimeHours], [Status], [Remarks], [CreatedAt], [ShiftID]) VALUES (9, 5, '2026-08-26', NULL, NULL, NULL, NULL, N'Present', NULL, '2026-08-27 16:02:46.9455322', NULL);
INSERT INTO [dbo].[T_Attendance] ([AttendanceID], [EmployeeID], [AttendanceDate], [CheckInTime], [CheckOutTime], [WorkingHours], [OvertimeHours], [Status], [Remarks], [CreatedAt], [ShiftID]) VALUES (10, 5, '2026-08-12', NULL, NULL, NULL, NULL, N'Present', NULL, '2026-08-27 16:02:56.6776722', NULL);
INSERT INTO [dbo].[T_Attendance] ([AttendanceID], [EmployeeID], [AttendanceDate], [CheckInTime], [CheckOutTime], [WorkingHours], [OvertimeHours], [Status], [Remarks], [CreatedAt], [ShiftID]) VALUES (11, 2, '2026-08-29', NULL, NULL, NULL, NULL, N'Present', NULL, '2026-08-29 14:25:58.0062435', NULL);
SET IDENTITY_INSERT [dbo].[T_Attendance] OFF;
GO

-- -------------------------------------------------------------------------------
-- Data for: [dbo].[T_LeaveRequest] (8 rows)
-- -------------------------------------------------------------------------------
SET IDENTITY_INSERT [dbo].[T_LeaveRequest] ON;
INSERT INTO [dbo].[T_LeaveRequest] ([LeaveRequestID], [EmployeeID], [LeaveTypeID], [FromDate], [ToDate], [NumberOfDays], [Reason], [Status], [ApprovedBy], [ApprovedDate], [Remarks], [CreatedAt]) VALUES (1, 2, 2, '2026-08-10', '2026-08-11', 2.00, N'Fever and medical rest', N'Approved', 1, '2026-08-08 10:18:31.0842274', N'Approved by Manager', '2026-08-08 10:18:31.0842274');
INSERT INTO [dbo].[T_LeaveRequest] ([LeaveRequestID], [EmployeeID], [LeaveTypeID], [FromDate], [ToDate], [NumberOfDays], [Reason], [Status], [ApprovedBy], [ApprovedDate], [Remarks], [CreatedAt]) VALUES (2, 3, 1, '2026-08-15', '2026-08-16', 2.00, N'Family Function', N'Approved', NULL, '2026-08-21 14:49:11.5033333', NULL, '2026-08-08 10:18:31.0842274');
INSERT INTO [dbo].[T_LeaveRequest] ([LeaveRequestID], [EmployeeID], [LeaveTypeID], [FromDate], [ToDate], [NumberOfDays], [Reason], [Status], [ApprovedBy], [ApprovedDate], [Remarks], [CreatedAt]) VALUES (3, 4, 3, '2026-09-01', '2026-09-05', 5.00, N'Annual Vacation', N'Rejected', 1, '2026-08-08 10:18:31.0842274', N'Project Deadline', '2026-08-08 10:18:31.0842274');
INSERT INTO [dbo].[T_LeaveRequest] ([LeaveRequestID], [EmployeeID], [LeaveTypeID], [FromDate], [ToDate], [NumberOfDays], [Reason], [Status], [ApprovedBy], [ApprovedDate], [Remarks], [CreatedAt]) VALUES (4, 5, 2, '2026-08-26', '2026-08-28', 3.00, N'Dddfggg', N'Cancelled', NULL, NULL, N'Yyyyyh', '2026-08-27 11:39:58.9580033');
INSERT INTO [dbo].[T_LeaveRequest] ([LeaveRequestID], [EmployeeID], [LeaveTypeID], [FromDate], [ToDate], [NumberOfDays], [Reason], [Status], [ApprovedBy], [ApprovedDate], [Remarks], [CreatedAt]) VALUES (5, 2, 1, '2026-09-01', '2026-09-02', 2.00, N'Family function out of town', N'Cancelled', NULL, NULL, NULL, '2026-08-27 07:54:40.1381487');
INSERT INTO [dbo].[T_LeaveRequest] ([LeaveRequestID], [EmployeeID], [LeaveTypeID], [FromDate], [ToDate], [NumberOfDays], [Reason], [Status], [ApprovedBy], [ApprovedDate], [Remarks], [CreatedAt]) VALUES (6, 3, 2, '2026-08-28', '2026-08-28', 1.00, N'Down with fever, need rest', N'Pending', NULL, NULL, NULL, '2026-08-27 07:54:40.1381487');
INSERT INTO [dbo].[T_LeaveRequest] ([LeaveRequestID], [EmployeeID], [LeaveTypeID], [FromDate], [ToDate], [NumberOfDays], [Reason], [Status], [ApprovedBy], [ApprovedDate], [Remarks], [CreatedAt]) VALUES (7, 5, 6, '2026-08-31', '2026-09-25', 26.00, N'I5si6si5s', N'Cancelled', NULL, NULL, NULL, '2026-08-29 14:44:33.2661123');
INSERT INTO [dbo].[T_LeaveRequest] ([LeaveRequestID], [EmployeeID], [LeaveTypeID], [FromDate], [ToDate], [NumberOfDays], [Reason], [Status], [ApprovedBy], [ApprovedDate], [Remarks], [CreatedAt]) VALUES (8, 5, 4, '2026-08-31', '2026-08-31', 1.00, N'Testtttttr5', N'Pending', NULL, NULL, N'Okok', '2026-08-31 10:43:02.7080354');
SET IDENTITY_INSERT [dbo].[T_LeaveRequest] OFF;
GO

-- -------------------------------------------------------------------------------
-- Data for: [dbo].[T_Task] (4 rows)
-- -------------------------------------------------------------------------------
SET IDENTITY_INSERT [dbo].[T_Task] ON;
INSERT INTO [dbo].[T_Task] ([TaskID], [EmployeeID], [AssignedBy], [TaskTitle], [TaskDescription], [Priority], [Status], [StartDate], [DueDate], [CompletedDate], [CreatedAt]) VALUES (1, 2, 1, N'Develop Login Module', N'Create authentication module using ASP.NET Core.', N'High', N'In Progress', '2026-08-08', '2026-08-15', NULL, '2026-08-08 10:24:01.8904804');
INSERT INTO [dbo].[T_Task] ([TaskID], [EmployeeID], [AssignedBy], [TaskTitle], [TaskDescription], [Priority], [Status], [StartDate], [DueDate], [CompletedDate], [CreatedAt]) VALUES (2, 3, 1, N'Prepare HR Dashboard', N'Develop HR analytics dashboard.', N'Medium', N'In Progress', '2026-08-09', '2026-08-18', NULL, '2026-08-08 10:24:01.8904804');
INSERT INTO [dbo].[T_Task] ([TaskID], [EmployeeID], [AssignedBy], [TaskTitle], [TaskDescription], [Priority], [Status], [StartDate], [DueDate], [CompletedDate], [CreatedAt]) VALUES (3, 4, 1, N'Prepare Monthly Sales Report', N'Generate sales report for August.', N'High', N'Completed', '2026-08-01', '2026-08-07', '2026-08-07', '2026-08-08 10:24:01.8904804');
INSERT INTO [dbo].[T_Task] ([TaskID], [EmployeeID], [AssignedBy], [TaskTitle], [TaskDescription], [Priority], [Status], [StartDate], [DueDate], [CompletedDate], [CreatedAt]) VALUES (4, 2, 5, N'Test task', NULL, N'High', N'Completed', '2026-08-27', '2026-08-31', '2026-08-27', '2026-08-27 18:03:59.2445458');
SET IDENTITY_INSERT [dbo].[T_Task] OFF;
GO

-- -------------------------------------------------------------------------------
-- Data for: [dbo].[T_Announcement] (3 rows)
-- -------------------------------------------------------------------------------
SET IDENTITY_INSERT [dbo].[T_Announcement] ON;
INSERT INTO [dbo].[T_Announcement] ([AnnouncementID], [Title], [Description], [PublishDate], [ExpiryDate], [CreatedBy], [IsActive], [CreatedAt]) VALUES (1, N'Independence Day Celebration', N'All employees are invited to attend the Independence Day celebration.', '2026-08-10', '2026-08-15', 1, NULL, '2026-08-08 10:28:31.4349967');
INSERT INTO [dbo].[T_Announcement] ([AnnouncementID], [Title], [Description], [PublishDate], [ExpiryDate], [CreatedBy], [IsActive], [CreatedAt]) VALUES (2, N'Payroll Released', N'Salary for August has been processed.', '2026-08-31', NULL, 1, NULL, '2026-08-08 10:28:31.4349967');
INSERT INTO [dbo].[T_Announcement] ([AnnouncementID], [Title], [Description], [PublishDate], [ExpiryDate], [CreatedBy], [IsActive], [CreatedAt]) VALUES (3, N'Office Maintenance', N'Server maintenance on Saturday from 9 PM to 11 PM.', '2026-08-20', '2026-08-21', 1, NULL, '2026-08-08 10:28:31.4349967');
SET IDENTITY_INSERT [dbo].[T_Announcement] OFF;
GO

-- -------------------------------------------------------------------------------
-- Data for: [dbo].[T_SalaryAdvance] (1 rows)
-- -------------------------------------------------------------------------------
SET IDENTITY_INSERT [dbo].[T_SalaryAdvance] ON;
INSERT INTO [dbo].[T_SalaryAdvance] ([SalaryAdvanceID], [EmployeeID], [TransactionType], [TotalAmount], [RecoveredAmount], [OutstandingAmount], [MonthlyRecoveryAmount], [IssueDate], [RecoveryStartMonth], [RecoveryStartYear], [Status], [Remarks], [CreatedAt], [CreatedBy]) VALUES (1, 1, N'Advance', 20000.00, 20000.00, 0.00, 4000.00, '2026-08-20', 9, 2026, N'Completed', N'Recovery revised to 4000 per month', '2026-08-20 10:43:17.3802782', NULL);
SET IDENTITY_INSERT [dbo].[T_SalaryAdvance] OFF;
GO

-- -------------------------------------------------------------------------------
-- Data for: [dbo].[T_Bonus] (1 rows)
-- -------------------------------------------------------------------------------
SET IDENTITY_INSERT [dbo].[T_Bonus] ON;
INSERT INTO [dbo].[T_Bonus] ([BonusID], [EmployeeID], [BonusAmount], [BonusMonth], [BonusYear], [BonusType], [Reason], [Status], [PaidDate], [CreatedAt], [CreatedBy]) VALUES (1, 1, 5000.00, 11, 2026, N'Performance', N'Performance bonus', N'Applied', NULL, '2026-08-20 10:55:28.4194101', NULL);
SET IDENTITY_INSERT [dbo].[T_Bonus] OFF;
GO

-- -------------------------------------------------------------------------------
-- Data for: [dbo].[T_Payroll] (5 rows)
-- -------------------------------------------------------------------------------
SET IDENTITY_INSERT [dbo].[T_Payroll] ON;
INSERT INTO [dbo].[T_Payroll] ([PayrollID], [EmployeeID], [PayrollMonth], [PayrollYear], [BasicSalary], [Allowance], [Bonus], [Deduction], [Tax], [NetSalary], [PaymentDate], [PaymentStatus], [Remarks], [CreatedAt], [AdvanceRecovery]) VALUES (1, 1, 8, 2026, 85000.00, 5000.00, 3000.00, 1000.00, 5000.00, 87000.00, '2026-08-20', N'Paid', N'Salary successfully paid.', '2026-08-08 10:20:36.5832996', 0.00);
INSERT INTO [dbo].[T_Payroll] ([PayrollID], [EmployeeID], [PayrollMonth], [PayrollYear], [BasicSalary], [Allowance], [Bonus], [Deduction], [Tax], [NetSalary], [PaymentDate], [PaymentStatus], [Remarks], [CreatedAt], [AdvanceRecovery]) VALUES (2, 2, 8, 2026, 25000.00, 2000.00, 1000.00, 0.00, 500.00, 27500.00, '2026-08-31', N'Paid', N'Intern Salary', '2026-08-08 10:20:36.5832996', 0.00);
INSERT INTO [dbo].[T_Payroll] ([PayrollID], [EmployeeID], [PayrollMonth], [PayrollYear], [BasicSalary], [Allowance], [Bonus], [Deduction], [Tax], [NetSalary], [PaymentDate], [PaymentStatus], [Remarks], [CreatedAt], [AdvanceRecovery]) VALUES (3, 3, 8, 2026, 50000.00, 3000.00, 1500.00, 500.00, 2500.00, 51500.00, NULL, N'Processing', NULL, '2026-08-08 10:20:36.5832996', 0.00);
INSERT INTO [dbo].[T_Payroll] ([PayrollID], [EmployeeID], [PayrollMonth], [PayrollYear], [BasicSalary], [Allowance], [Bonus], [Deduction], [Tax], [NetSalary], [PaymentDate], [PaymentStatus], [Remarks], [CreatedAt], [AdvanceRecovery]) VALUES (4, 4, 8, 2026, 60000.00, 4000.00, 2500.00, 1000.00, 3500.00, 62000.00, NULL, N'Pending', NULL, '2026-08-08 10:20:36.5832996', 0.00);
INSERT INTO [dbo].[T_Payroll] ([PayrollID], [EmployeeID], [PayrollMonth], [PayrollYear], [BasicSalary], [Allowance], [Bonus], [Deduction], [Tax], [NetSalary], [PaymentDate], [PaymentStatus], [Remarks], [CreatedAt], [AdvanceRecovery]) VALUES (9, 1, 2, 2027, 40000.00, 3000.00, 2000.00, 500.00, 2500.00, 38000.00, NULL, N'Pending', N'February 2027 Salary', '2026-08-20 13:06:30.786109', 4000.00);
SET IDENTITY_INSERT [dbo].[T_Payroll] OFF;
GO

-- -------------------------------------------------------------------------------
-- Data for: [dbo].[T_EmployeeDocument] (5 rows)
-- -------------------------------------------------------------------------------
SET IDENTITY_INSERT [dbo].[T_EmployeeDocument] ON;
INSERT INTO [dbo].[T_EmployeeDocument] ([DocumentID], [EmployeeID], [DocumentType], [DocumentName], [FilePath], [FileExtension], [FileSizeKB], [UploadedDate], [ExpiryDate], [IsVerified], [Remarks]) VALUES (1, 2, N'Aadhaar', N'Aadhaar Card', N'/Documents/Aadhaar/EMP002_Aadhaar.pdf', N'pdf', 512.00, '2026-08-08 10:26:28.397429', NULL, NULL, N'Verified');
INSERT INTO [dbo].[T_EmployeeDocument] ([DocumentID], [EmployeeID], [DocumentType], [DocumentName], [FilePath], [FileExtension], [FileSizeKB], [UploadedDate], [ExpiryDate], [IsVerified], [Remarks]) VALUES (2, 2, N'Resume', N'Latest Resume', N'/Documents/Resume/EMP002_Resume.pdf', N'pdf', 850.00, '2026-08-08 10:26:28.397429', NULL, NULL, N'Uploaded during joining');
INSERT INTO [dbo].[T_EmployeeDocument] ([DocumentID], [EmployeeID], [DocumentType], [DocumentName], [FilePath], [FileExtension], [FileSizeKB], [UploadedDate], [ExpiryDate], [IsVerified], [Remarks]) VALUES (3, 3, N'PAN', N'PAN Card', N'/Documents/PAN/EMP003_PAN.pdf', N'pdf', 430.00, '2026-08-08 10:26:28.397429', NULL, 0, N'Pending Verification');
INSERT INTO [dbo].[T_EmployeeDocument] ([DocumentID], [EmployeeID], [DocumentType], [DocumentName], [FilePath], [FileExtension], [FileSizeKB], [UploadedDate], [ExpiryDate], [IsVerified], [Remarks]) VALUES (4, 4, N'Offer Letter', N'Offer Letter', N'/Documents/OfferLetters/EMP004_Offer.pdf', N'pdf', 1024.00, '2026-08-08 10:26:28.397429', NULL, NULL, N'HR Verified');
INSERT INTO [dbo].[T_EmployeeDocument] ([DocumentID], [EmployeeID], [DocumentType], [DocumentName], [FilePath], [FileExtension], [FileSizeKB], [UploadedDate], [ExpiryDate], [IsVerified], [Remarks]) VALUES (5, 9, N'Address proof', N'ChatGPT Image Aug 20, 2026, 12_46_12 PM.png', N'employee-documents/9/ac886adcd58c4119bb2bddf4530a13c3.png', N'.png', 2009.27, '2026-08-21 05:02:54.32', NULL, NULL, NULL);
SET IDENTITY_INSERT [dbo].[T_EmployeeDocument] OFF;
GO

