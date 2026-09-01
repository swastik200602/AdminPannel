/*****************************************************************************************
 * EMPLOYEE MANAGEMENT SYSTEM - TABLES & SCHEMA DDL SCRIPT
 * Script Type: DROP AND CREATE
 * Database:    EmployeeManagementDB
 * Generated:   2026-09-01 14:54:43
 * Description: Drops existing foreign keys and tables in safe reverse-dependency order,
 *              then recreates all tables, primary keys, defaults, checks, uniques, and foreign keys.
 *****************************************************************************************/
USE [EmployeeManagementDB];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ===============================================================================
-- 1. DROP EXISTING FOREIGN KEYS (Prevents drop order lockups)
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[FK_Announcement_CreatedBy]', N'F') IS NOT NULL
    ALTER TABLE [dbo].[T_Announcement] DROP CONSTRAINT [FK_Announcement_CreatedBy];
GO
IF OBJECT_ID(N'[dbo].[FK_Attendance_Employee]', N'F') IS NOT NULL
    ALTER TABLE [dbo].[T_Attendance] DROP CONSTRAINT [FK_Attendance_Employee];
GO
IF OBJECT_ID(N'[dbo].[FK_Attendance_Shift]', N'F') IS NOT NULL
    ALTER TABLE [dbo].[T_Attendance] DROP CONSTRAINT [FK_Attendance_Shift];
GO
IF OBJECT_ID(N'[dbo].[FK_Employee_Department]', N'F') IS NOT NULL
    ALTER TABLE [dbo].[T_Employee] DROP CONSTRAINT [FK_Employee_Department];
GO
IF OBJECT_ID(N'[dbo].[FK_Employee_Designation]', N'F') IS NOT NULL
    ALTER TABLE [dbo].[T_Employee] DROP CONSTRAINT [FK_Employee_Designation];
GO
IF OBJECT_ID(N'[dbo].[FK_Employee_Manager]', N'F') IS NOT NULL
    ALTER TABLE [dbo].[T_Employee] DROP CONSTRAINT [FK_Employee_Manager];
GO
IF OBJECT_ID(N'[dbo].[FK_Employee_OfficeLocation]', N'F') IS NOT NULL
    ALTER TABLE [dbo].[T_Employee] DROP CONSTRAINT [FK_Employee_OfficeLocation];
GO
IF OBJECT_ID(N'[dbo].[FK_Employee_Role]', N'F') IS NOT NULL
    ALTER TABLE [dbo].[T_Employee] DROP CONSTRAINT [FK_Employee_Role];
GO
IF OBJECT_ID(N'[dbo].[FK_Employee_Shift]', N'F') IS NOT NULL
    ALTER TABLE [dbo].[T_Employee] DROP CONSTRAINT [FK_Employee_Shift];
GO
IF OBJECT_ID(N'[dbo].[FK_EmployeeDocument_Employee]', N'F') IS NOT NULL
    ALTER TABLE [dbo].[T_EmployeeDocument] DROP CONSTRAINT [FK_EmployeeDocument_Employee];
GO
IF OBJECT_ID(N'[dbo].[FK_IndiaCity_State]', N'F') IS NOT NULL
    ALTER TABLE [dbo].[M_IndiaCity] DROP CONSTRAINT [FK_IndiaCity_State];
GO
IF OBJECT_ID(N'[dbo].[FK_LeaveRequest_ApprovedBy]', N'F') IS NOT NULL
    ALTER TABLE [dbo].[T_LeaveRequest] DROP CONSTRAINT [FK_LeaveRequest_ApprovedBy];
GO
IF OBJECT_ID(N'[dbo].[FK_LeaveRequest_Employee]', N'F') IS NOT NULL
    ALTER TABLE [dbo].[T_LeaveRequest] DROP CONSTRAINT [FK_LeaveRequest_Employee];
GO
IF OBJECT_ID(N'[dbo].[FK_LeaveRequest_LeaveType]', N'F') IS NOT NULL
    ALTER TABLE [dbo].[T_LeaveRequest] DROP CONSTRAINT [FK_LeaveRequest_LeaveType];
GO
IF OBJECT_ID(N'[dbo].[FK_M_SalaryMaster_Employee]', N'F') IS NOT NULL
    ALTER TABLE [dbo].[M_SalaryMaster] DROP CONSTRAINT [FK_M_SalaryMaster_Employee];
GO
IF OBJECT_ID(N'[dbo].[FK_M_TaxMaster_Employee]', N'F') IS NOT NULL
    ALTER TABLE [dbo].[M_TaxMaster] DROP CONSTRAINT [FK_M_TaxMaster_Employee];
GO
IF OBJECT_ID(N'[dbo].[FK_Payroll_Employee]', N'F') IS NOT NULL
    ALTER TABLE [dbo].[T_Payroll] DROP CONSTRAINT [FK_Payroll_Employee];
GO
IF OBJECT_ID(N'[dbo].[FK_T_Bonus_Employee]', N'F') IS NOT NULL
    ALTER TABLE [dbo].[T_Bonus] DROP CONSTRAINT [FK_T_Bonus_Employee];
GO
IF OBJECT_ID(N'[dbo].[FK_T_SalaryAdvance_Employee]', N'F') IS NOT NULL
    ALTER TABLE [dbo].[T_SalaryAdvance] DROP CONSTRAINT [FK_T_SalaryAdvance_Employee];
GO
IF OBJECT_ID(N'[dbo].[FK_Task_AssignedBy]', N'F') IS NOT NULL
    ALTER TABLE [dbo].[T_Task] DROP CONSTRAINT [FK_Task_AssignedBy];
GO
IF OBJECT_ID(N'[dbo].[FK_Task_Employee]', N'F') IS NOT NULL
    ALTER TABLE [dbo].[T_Task] DROP CONSTRAINT [FK_Task_Employee];
GO

-- ===============================================================================
-- 2. DROP EXISTING TABLES
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[T_EmployeeDocument]', N'U') IS NOT NULL
    DROP TABLE [dbo].[T_EmployeeDocument];
GO
IF OBJECT_ID(N'[dbo].[T_SalaryAdvance]', N'U') IS NOT NULL
    DROP TABLE [dbo].[T_SalaryAdvance];
GO
IF OBJECT_ID(N'[dbo].[T_Bonus]', N'U') IS NOT NULL
    DROP TABLE [dbo].[T_Bonus];
GO
IF OBJECT_ID(N'[dbo].[T_Payroll]', N'U') IS NOT NULL
    DROP TABLE [dbo].[T_Payroll];
GO
IF OBJECT_ID(N'[dbo].[T_Announcement]', N'U') IS NOT NULL
    DROP TABLE [dbo].[T_Announcement];
GO
IF OBJECT_ID(N'[dbo].[T_Task]', N'U') IS NOT NULL
    DROP TABLE [dbo].[T_Task];
GO
IF OBJECT_ID(N'[dbo].[T_LeaveRequest]', N'U') IS NOT NULL
    DROP TABLE [dbo].[T_LeaveRequest];
GO
IF OBJECT_ID(N'[dbo].[T_Attendance]', N'U') IS NOT NULL
    DROP TABLE [dbo].[T_Attendance];
GO
IF OBJECT_ID(N'[dbo].[M_TaxMaster]', N'U') IS NOT NULL
    DROP TABLE [dbo].[M_TaxMaster];
GO
IF OBJECT_ID(N'[dbo].[M_SalaryMaster]', N'U') IS NOT NULL
    DROP TABLE [dbo].[M_SalaryMaster];
GO
IF OBJECT_ID(N'[dbo].[T_Users]', N'U') IS NOT NULL
    DROP TABLE [dbo].[T_Users];
GO
IF OBJECT_ID(N'[dbo].[T_Employee]', N'U') IS NOT NULL
    DROP TABLE [dbo].[T_Employee];
GO
IF OBJECT_ID(N'[dbo].[M_IndiaCity]', N'U') IS NOT NULL
    DROP TABLE [dbo].[M_IndiaCity];
GO
IF OBJECT_ID(N'[dbo].[M_IndiaState]', N'U') IS NOT NULL
    DROP TABLE [dbo].[M_IndiaState];
GO
IF OBJECT_ID(N'[dbo].[M_Holiday]', N'U') IS NOT NULL
    DROP TABLE [dbo].[M_Holiday];
GO
IF OBJECT_ID(N'[dbo].[M_LeaveType]', N'U') IS NOT NULL
    DROP TABLE [dbo].[M_LeaveType];
GO
IF OBJECT_ID(N'[dbo].[M_Shift]', N'U') IS NOT NULL
    DROP TABLE [dbo].[M_Shift];
GO
IF OBJECT_ID(N'[dbo].[M_Role]', N'U') IS NOT NULL
    DROP TABLE [dbo].[M_Role];
GO
IF OBJECT_ID(N'[dbo].[M_OfficeBranch]', N'U') IS NOT NULL
    DROP TABLE [dbo].[M_OfficeBranch];
GO
IF OBJECT_ID(N'[dbo].[M_Designation]', N'U') IS NOT NULL
    DROP TABLE [dbo].[M_Designation];
GO
IF OBJECT_ID(N'[dbo].[M_Department]', N'U') IS NOT NULL
    DROP TABLE [dbo].[M_Department];
GO

-- ===============================================================================
-- 3. CREATE TABLES & PRIMARY KEYS
-- ===============================================================================
-- Table: [dbo].[M_Department]
CREATE TABLE [dbo].[M_Department] (
    [DepartmentID] int IDENTITY(1,1) NOT NULL,
    [DepartmentName] nvarchar(100) NOT NULL,
    [DepartmentCode] nvarchar(20) NOT NULL,
    [Description] nvarchar(255) NULL,
    [IsActive] bit NOT NULL CONSTRAINT [DF__Departmen__IsAct__48CFD27E] DEFAULT ((1)),
    [CreatedAt] datetime2(7) NOT NULL CONSTRAINT [DF__Departmen__Creat__49C3F6B7] DEFAULT (sysdatetime()),
    CONSTRAINT [PK_Department] PRIMARY KEY CLUSTERED ([DepartmentID] ASC)
);
GO

-- Table: [dbo].[M_Designation]
CREATE TABLE [dbo].[M_Designation] (
    [DesignationID] int IDENTITY(1,1) NOT NULL,
    [DesignationName] nvarchar(100) NOT NULL,
    [DesignationCode] nvarchar(20) NOT NULL,
    [Description] nvarchar(255) NULL,
    [IsActive] bit NOT NULL CONSTRAINT [DF__Designati__IsAct__4E88ABD4] DEFAULT ((1)),
    [CreatedAt] datetime2(7) NOT NULL CONSTRAINT [DF__Designati__Creat__4F7CD00D] DEFAULT (sysdatetime()),
    CONSTRAINT [PK_Designation] PRIMARY KEY CLUSTERED ([DesignationID] ASC)
);
GO

-- Table: [dbo].[M_OfficeBranch]
CREATE TABLE [dbo].[M_OfficeBranch] (
    [OfficeLocationID] int IDENTITY(1,1) NOT NULL,
    [OfficeName] nvarchar(100) NOT NULL,
    [OfficeCode] nvarchar(20) NOT NULL,
    [AddressLine1] nvarchar(200) NOT NULL,
    [AddressLine2] nvarchar(200) NULL,
    [City] nvarchar(100) NOT NULL,
    [State] nvarchar(100) NOT NULL,
    [Country] nvarchar(100) NOT NULL,
    [PostalCode] nvarchar(20) NULL,
    [PhoneNumber] nvarchar(20) NULL,
    [Email] nvarchar(100) NULL,
    [IsActive] bit NOT NULL CONSTRAINT [DF__OfficeLoc__IsAct__5441852A] DEFAULT ((1)),
    [CreatedAt] datetime2(7) NOT NULL CONSTRAINT [DF__OfficeLoc__Creat__5535A963] DEFAULT (sysdatetime()),
    CONSTRAINT [PK_OfficeLocation] PRIMARY KEY CLUSTERED ([OfficeLocationID] ASC)
);
GO

-- Table: [dbo].[M_Role]
CREATE TABLE [dbo].[M_Role] (
    [RoleID] int NOT NULL,
    [RoleName] nvarchar(50) NOT NULL,
    [Description] nvarchar(255) NULL,
    [IsActive] bit NOT NULL CONSTRAINT [DF__Role__IsActive__4316F928] DEFAULT ((1)),
    [CreatedAt] datetime2(7) NOT NULL CONSTRAINT [DF__Role__CreatedAt__440B1D61] DEFAULT (sysdatetime()),
    CONSTRAINT [PK_Role] PRIMARY KEY CLUSTERED ([RoleID] ASC)
);
GO

-- Table: [dbo].[M_Shift]
CREATE TABLE [dbo].[M_Shift] (
    [ShiftID] int IDENTITY(1,1) NOT NULL,
    [ShiftName] nvarchar(100) NOT NULL,
    [ShiftCode] nvarchar(20) NOT NULL,
    [StartTime] time(7) NOT NULL,
    [EndTime] time(7) NOT NULL,
    [GraceMinutes] int NOT NULL CONSTRAINT [DF__Shift__GraceMinu__787EE5A0] DEFAULT ((0)),
    [IsNightShift] bit NOT NULL CONSTRAINT [DF__Shift__IsNightSh__797309D9] DEFAULT ((0)),
    [IsActive] bit NOT NULL CONSTRAINT [DF__Shift__IsActive__7A672E12] DEFAULT ((1)),
    [CreatedAt] datetime2(7) NOT NULL CONSTRAINT [DF__Shift__CreatedAt__7B5B524B] DEFAULT (sysdatetime()),
    CONSTRAINT [PK_Shift] PRIMARY KEY CLUSTERED ([ShiftID] ASC)
);
GO

-- Table: [dbo].[M_LeaveType]
CREATE TABLE [dbo].[M_LeaveType] (
    [LeaveTypeID] int IDENTITY(1,1) NOT NULL,
    [LeaveTypeName] nvarchar(100) NOT NULL,
    [LeaveCode] nvarchar(20) NOT NULL,
    [MaxLeavesPerYear] int NOT NULL,
    [IsPaidLeave] bit NOT NULL,
    [IsActive] bit NOT NULL CONSTRAINT [DF__LeaveType__IsAct__02FC7413] DEFAULT ((1)),
    [CreatedAt] datetime2(7) NOT NULL CONSTRAINT [DF__LeaveType__Creat__03F0984C] DEFAULT (sysdatetime()),
    CONSTRAINT [PK_LeaveType] PRIMARY KEY CLUSTERED ([LeaveTypeID] ASC)
);
GO

-- Table: [dbo].[M_Holiday]
CREATE TABLE [dbo].[M_Holiday] (
    [HolidayID] int IDENTITY(1,1) NOT NULL,
    [HolidayName] nvarchar(200) NOT NULL,
    [HolidayDate] date NOT NULL,
    [HolidayType] nvarchar(50) NOT NULL,
    [Description] nvarchar(500) NULL,
    [IsOptional] bit NOT NULL CONSTRAINT [DF__Holiday__IsOptio__31B762FC] DEFAULT ((0)),
    [IsActive] bit NOT NULL CONSTRAINT [DF__Holiday__IsActiv__32AB8735] DEFAULT ((1)),
    [CreatedAt] datetime2(7) NOT NULL CONSTRAINT [DF__Holiday__Created__339FAB6E] DEFAULT (sysdatetime()),
    CONSTRAINT [PK_Holiday] PRIMARY KEY CLUSTERED ([HolidayID] ASC)
);
GO

-- Table: [dbo].[M_IndiaState]
CREATE TABLE [dbo].[M_IndiaState] (
    [StateID] int IDENTITY(1,1) NOT NULL,
    [StateName] nvarchar(100) NOT NULL,
    [IsActive] bit NOT NULL CONSTRAINT [DF_IndiaState_IsActive] DEFAULT ((1)),
    CONSTRAINT [PK_IndiaState] PRIMARY KEY CLUSTERED ([StateID] ASC)
);
GO

-- Table: [dbo].[M_IndiaCity]
CREATE TABLE [dbo].[M_IndiaCity] (
    [CityID] int IDENTITY(1,1) NOT NULL,
    [StateID] int NOT NULL,
    [CityName] nvarchar(100) NOT NULL,
    [IsActive] bit NOT NULL CONSTRAINT [DF_IndiaCity_IsActive] DEFAULT ((1)),
    CONSTRAINT [PK_IndiaCity] PRIMARY KEY CLUSTERED ([CityID] ASC)
);
GO

-- Table: [dbo].[T_Employee]
CREATE TABLE [dbo].[T_Employee] (
    [EmployeeID] int IDENTITY(1,1) NOT NULL,
    [EmployeeCode] nvarchar(20) NOT NULL,
    [FirstName] nvarchar(100) NOT NULL,
    [LastName] nvarchar(100) NOT NULL,
    [Gender] nvarchar(20) NOT NULL,
    [DateOfBirth] date NOT NULL,
    [Email] nvarchar(150) NOT NULL,
    [PhoneNumber] nvarchar(20) NOT NULL,
    [EmergencyContact] nvarchar(20) NULL,
    [Address] nvarchar(255) NOT NULL,
    [City] nvarchar(100) NOT NULL,
    [State] nvarchar(100) NOT NULL,
    [Country] nvarchar(100) NOT NULL,
    [PostalCode] nvarchar(20) NOT NULL,
    [DepartmentID] int NOT NULL,
    [DesignationID] int NOT NULL,
    [OfficeLocationID] int NOT NULL,
    [ManagerID] int NULL,
    [JoiningDate] date NOT NULL,
    [EmploymentType] nvarchar(30) NOT NULL,
    [BasicSalary] decimal(18, 2) NOT NULL,
    [IsActive] bit NOT NULL CONSTRAINT [DF__Employee__IsActi__5AEE82B9] DEFAULT ((1)),
    [CreatedAt] datetime2(7) NOT NULL CONSTRAINT [DF__Employee__Create__5BE2A6F2] DEFAULT (sysdatetime()),
    [UpdatedAt] datetime2(7) NULL,
    [ShiftID] int NULL,
    [RoleID] int NOT NULL,
    [ProfileImage] nvarchar(500) NULL,
    CONSTRAINT [PK_Employee] PRIMARY KEY CLUSTERED ([EmployeeID] ASC)
);
GO

-- Table: [dbo].[T_Users]
CREATE TABLE [dbo].[T_Users] (
    [UserID] int IDENTITY(1,1) NOT NULL,
    [EmployeeID] int NOT NULL,
    [RoleID] int NOT NULL,
    [UserName] nvarchar(100) NULL,
    [PasswordHash] nvarchar(100) NOT NULL,
    [PasswordSalt] nvarchar(128) NULL,
    [MobileNo] nvarchar(10) NULL,
    [Email] nvarchar(200) NULL,
    [LastLogin] datetime2(7) NULL,
    [WrongCount] int NULL,
    [IsActive] bit NOT NULL CONSTRAINT [DF__T_Users__IsActiv__74794A92] DEFAULT ((1)),
    [CreatedAt] datetime2(7) NOT NULL CONSTRAINT [DF__T_Users__Created__756D6ECB] DEFAULT (sysdatetime()),
    [MustChangePassword] bit NOT NULL CONSTRAINT [DF_T_Users_MustChangePassword] DEFAULT ((0)),
    [PasswordChangedAt] datetime2(7) NULL,
    [PasswordResetToken] nvarchar(200) NULL,
    [PasswordResetExpiresAt] datetime2(7) NULL
);
GO

-- Table: [dbo].[M_SalaryMaster]
CREATE TABLE [dbo].[M_SalaryMaster] (
    [SalaryMasterID] int IDENTITY(1,1) NOT NULL,
    [EmployeeID] int NOT NULL,
    [BasicSalary] decimal(18, 2) NOT NULL CONSTRAINT [DF_M_SalaryMaster_BasicSalary] DEFAULT ((0)),
    [Allowance] decimal(18, 2) NOT NULL CONSTRAINT [DF_M_SalaryMaster_Allowance] DEFAULT ((0)),
    [Bonus] decimal(18, 2) NOT NULL CONSTRAINT [DF_M_SalaryMaster_Bonus] DEFAULT ((0)),
    [Deduction] decimal(18, 2) NOT NULL CONSTRAINT [DF_M_SalaryMaster_Deduction] DEFAULT ((0)),
    [Tax] decimal(18, 2) NOT NULL CONSTRAINT [DF_M_SalaryMaster_Tax] DEFAULT ((0)),
    [EffectiveFrom] date NOT NULL,
    [EffectiveTo] date NULL,
    [IsActive] bit NOT NULL CONSTRAINT [DF_M_SalaryMaster_IsActive] DEFAULT ((1)),
    [RevisionReason] nvarchar(200) NULL,
    [CreatedAt] datetime2(7) NOT NULL CONSTRAINT [DF_M_SalaryMaster_CreatedAt] DEFAULT (sysdatetime()),
    CONSTRAINT [PK_M_SalaryMaster] PRIMARY KEY CLUSTERED ([SalaryMasterID] ASC)
);
GO

-- Table: [dbo].[M_TaxMaster]
CREATE TABLE [dbo].[M_TaxMaster] (
    [TaxMasterID] int IDENTITY(1,1) NOT NULL,
    [EmployeeID] int NOT NULL,
    [TaxType] nvarchar(30) NOT NULL,
    [TaxAmount] decimal(18, 2) NOT NULL CONSTRAINT [DF_M_TaxMaster_TaxAmount] DEFAULT ((0)),
    [EffectiveFrom] date NOT NULL,
    [EffectiveTo] date NULL,
    [IsActive] bit NOT NULL CONSTRAINT [DF_M_TaxMaster_IsActive] DEFAULT ((1)),
    [Reason] nvarchar(250) NULL,
    [CreatedAt] datetime2(7) NOT NULL CONSTRAINT [DF_M_TaxMaster_CreatedAt] DEFAULT (sysdatetime()),
    [CreatedBy] int NULL,
    CONSTRAINT [PK_M_TaxMaster] PRIMARY KEY CLUSTERED ([TaxMasterID] ASC)
);
GO

-- Table: [dbo].[T_Attendance]
CREATE TABLE [dbo].[T_Attendance] (
    [AttendanceID] int IDENTITY(1,1) NOT NULL,
    [EmployeeID] int NOT NULL,
    [AttendanceDate] date NOT NULL,
    [CheckInTime] time(7) NULL,
    [CheckOutTime] time(7) NULL,
    [WorkingHours] decimal(5, 2) NULL,
    [OvertimeHours] decimal(5, 2) NULL CONSTRAINT [DF__Attendanc__Overt__70DDC3D8] DEFAULT ((0)),
    [Status] nvarchar(20) NOT NULL,
    [Remarks] nvarchar(255) NULL,
    [CreatedAt] datetime2(7) NOT NULL CONSTRAINT [DF__Attendanc__Creat__71D1E811] DEFAULT (sysdatetime()),
    [ShiftID] int NULL,
    CONSTRAINT [PK_Attendance] PRIMARY KEY CLUSTERED ([AttendanceID] ASC)
);
GO

-- Table: [dbo].[T_LeaveRequest]
CREATE TABLE [dbo].[T_LeaveRequest] (
    [LeaveRequestID] int IDENTITY(1,1) NOT NULL,
    [EmployeeID] int NOT NULL,
    [LeaveTypeID] int NOT NULL,
    [FromDate] date NOT NULL,
    [ToDate] date NOT NULL,
    [NumberOfDays] decimal(5, 2) NOT NULL,
    [Reason] nvarchar(500) NOT NULL,
    [Status] nvarchar(20) NOT NULL CONSTRAINT [DF__LeaveRequ__Statu__07C12930] DEFAULT ('Pending'),
    [ApprovedBy] int NULL,
    [ApprovedDate] datetime2(7) NULL,
    [Remarks] nvarchar(500) NULL,
    [CreatedAt] datetime2(7) NOT NULL CONSTRAINT [DF__LeaveRequ__Creat__08B54D69] DEFAULT (sysdatetime()),
    CONSTRAINT [PK_LeaveRequest] PRIMARY KEY CLUSTERED ([LeaveRequestID] ASC)
);
GO

-- Table: [dbo].[T_Task]
CREATE TABLE [dbo].[T_Task] (
    [TaskID] int IDENTITY(1,1) NOT NULL,
    [EmployeeID] int NOT NULL,
    [AssignedBy] int NOT NULL,
    [TaskTitle] nvarchar(200) NOT NULL,
    [TaskDescription] nvarchar(max) NULL,
    [Priority] nvarchar(20) NOT NULL CONSTRAINT [DF__Task__Priority__1CBC4616] DEFAULT ('Medium'),
    [Status] nvarchar(20) NOT NULL CONSTRAINT [DF__Task__Status__1DB06A4F] DEFAULT ('Pending'),
    [StartDate] date NOT NULL,
    [DueDate] date NOT NULL,
    [CompletedDate] date NULL,
    [CreatedAt] datetime2(7) NOT NULL CONSTRAINT [DF__Task__CreatedAt__1EA48E88] DEFAULT (sysdatetime()),
    CONSTRAINT [PK_Task] PRIMARY KEY CLUSTERED ([TaskID] ASC)
);
GO

-- Table: [dbo].[T_Announcement]
CREATE TABLE [dbo].[T_Announcement] (
    [AnnouncementID] int IDENTITY(1,1) NOT NULL,
    [Title] nvarchar(200) NOT NULL,
    [Description] nvarchar(max) NOT NULL,
    [PublishDate] date NOT NULL,
    [ExpiryDate] date NULL,
    [CreatedBy] int NOT NULL,
    [IsActive] bit NOT NULL CONSTRAINT [DF__Announcem__IsAct__2B0A656D] DEFAULT ((1)),
    [CreatedAt] datetime2(7) NOT NULL CONSTRAINT [DF__Announcem__Creat__2BFE89A6] DEFAULT (sysdatetime()),
    CONSTRAINT [PK_Announcement] PRIMARY KEY CLUSTERED ([AnnouncementID] ASC)
);
GO

-- Table: [dbo].[T_Payroll]
CREATE TABLE [dbo].[T_Payroll] (
    [PayrollID] int IDENTITY(1,1) NOT NULL,
    [EmployeeID] int NOT NULL,
    [PayrollMonth] tinyint NOT NULL,
    [PayrollYear] smallint NOT NULL,
    [BasicSalary] decimal(18, 2) NOT NULL,
    [Allowance] decimal(18, 2) NOT NULL CONSTRAINT [DF__Payroll__Allowan__123EB7A3] DEFAULT ((0)),
    [Bonus] decimal(18, 2) NOT NULL CONSTRAINT [DF__Payroll__Bonus__1332DBDC] DEFAULT ((0)),
    [Deduction] decimal(18, 2) NOT NULL CONSTRAINT [DF__Payroll__Deducti__14270015] DEFAULT ((0)),
    [Tax] decimal(18, 2) NOT NULL CONSTRAINT [DF__Payroll__Tax__151B244E] DEFAULT ((0)),
    [NetSalary] decimal(18, 2) NOT NULL,
    [PaymentDate] date NULL,
    [PaymentStatus] nvarchar(20) NOT NULL CONSTRAINT [DF__Payroll__Payment__160F4887] DEFAULT ('Pending'),
    [Remarks] nvarchar(500) NULL,
    [CreatedAt] datetime2(7) NOT NULL CONSTRAINT [DF__Payroll__Created__17036CC0] DEFAULT (sysdatetime()),
    [AdvanceRecovery] decimal(18, 2) NOT NULL CONSTRAINT [DF_T_Payroll_AdvanceRecovery] DEFAULT ((0)),
    CONSTRAINT [PK_Payroll] PRIMARY KEY CLUSTERED ([PayrollID] ASC)
);
GO

-- Table: [dbo].[T_Bonus]
CREATE TABLE [dbo].[T_Bonus] (
    [BonusID] int IDENTITY(1,1) NOT NULL,
    [EmployeeID] int NOT NULL,
    [BonusAmount] decimal(18, 2) NOT NULL,
    [BonusMonth] tinyint NOT NULL,
    [BonusYear] smallint NOT NULL,
    [BonusType] nvarchar(50) NULL,
    [Reason] nvarchar(250) NULL,
    [Status] nvarchar(20) NOT NULL CONSTRAINT [DF_T_Bonus_Status] DEFAULT ('Pending'),
    [PaidDate] date NULL,
    [CreatedAt] datetime2(7) NOT NULL CONSTRAINT [DF_T_Bonus_CreatedAt] DEFAULT (sysdatetime()),
    [CreatedBy] int NULL,
    CONSTRAINT [PK_T_Bonus] PRIMARY KEY CLUSTERED ([BonusID] ASC)
);
GO

-- Table: [dbo].[T_SalaryAdvance]
CREATE TABLE [dbo].[T_SalaryAdvance] (
    [SalaryAdvanceID] int IDENTITY(1,1) NOT NULL,
    [EmployeeID] int NOT NULL,
    [TransactionType] nvarchar(20) NOT NULL,
    [TotalAmount] decimal(18, 2) NOT NULL,
    [RecoveredAmount] decimal(18, 2) NOT NULL CONSTRAINT [DF_T_SalaryAdvance_RecoveredAmount] DEFAULT ((0)),
    [OutstandingAmount] decimal(18, 2) NOT NULL,
    [MonthlyRecoveryAmount] decimal(18, 2) NOT NULL CONSTRAINT [DF_T_SalaryAdvance_MonthlyRecoveryAmount] DEFAULT ((0)),
    [IssueDate] date NOT NULL,
    [RecoveryStartMonth] tinyint NOT NULL,
    [RecoveryStartYear] smallint NOT NULL,
    [Status] nvarchar(20) NOT NULL CONSTRAINT [DF_T_SalaryAdvance_Status] DEFAULT ('Active'),
    [Remarks] nvarchar(500) NULL,
    [CreatedAt] datetime2(7) NOT NULL CONSTRAINT [DF_T_SalaryAdvance_CreatedAt] DEFAULT (sysdatetime()),
    [CreatedBy] int NULL,
    CONSTRAINT [PK_T_SalaryAdvance] PRIMARY KEY CLUSTERED ([SalaryAdvanceID] ASC)
);
GO

-- Table: [dbo].[T_EmployeeDocument]
CREATE TABLE [dbo].[T_EmployeeDocument] (
    [DocumentID] int IDENTITY(1,1) NOT NULL,
    [EmployeeID] int NOT NULL,
    [DocumentType] nvarchar(100) NOT NULL,
    [DocumentName] nvarchar(255) NOT NULL,
    [FilePath] nvarchar(500) NOT NULL,
    [FileExtension] nvarchar(20) NOT NULL,
    [FileSizeKB] decimal(10, 2) NULL,
    [UploadedDate] datetime2(7) NOT NULL CONSTRAINT [DF__EmployeeD__Uploa__2645B050] DEFAULT (sysdatetime()),
    [ExpiryDate] date NULL,
    [IsVerified] bit NOT NULL CONSTRAINT [DF__EmployeeD__IsVer__2739D489] DEFAULT ((0)),
    [Remarks] nvarchar(500) NULL,
    CONSTRAINT [PK_EmployeeDocument] PRIMARY KEY CLUSTERED ([DocumentID] ASC)
);
GO

-- ===============================================================================
-- 4. ADD UNIQUE CONSTRAINTS / INDEXES
-- ===============================================================================
ALTER TABLE [dbo].[T_Employee] ADD CONSTRAINT [UQ_Employee_Email] UNIQUE NONCLUSTERED ([Email] ASC);
GO
ALTER TABLE [dbo].[M_Designation] ADD CONSTRAINT [UQ_Designation_Code] UNIQUE NONCLUSTERED ([DesignationCode] ASC);
GO
ALTER TABLE [dbo].[M_Department] ADD CONSTRAINT [UQ_Department_Name] UNIQUE NONCLUSTERED ([DepartmentName] ASC);
GO
ALTER TABLE [dbo].[M_Shift] ADD CONSTRAINT [UQ_Shift_Code] UNIQUE NONCLUSTERED ([ShiftCode] ASC);
GO
ALTER TABLE [dbo].[M_LeaveType] ADD CONSTRAINT [UQ_LeaveType_Code] UNIQUE NONCLUSTERED ([LeaveCode] ASC);
GO
ALTER TABLE [dbo].[M_LeaveType] ADD CONSTRAINT [UQ_LeaveType_Name] UNIQUE NONCLUSTERED ([LeaveTypeName] ASC);
GO
ALTER TABLE [dbo].[M_Holiday] ADD CONSTRAINT [UQ_Holiday_Date] UNIQUE NONCLUSTERED ([HolidayDate] ASC);
GO
ALTER TABLE [dbo].[M_OfficeBranch] ADD CONSTRAINT [UQ_OfficeLocation_Name] UNIQUE NONCLUSTERED ([OfficeName] ASC);
GO
ALTER TABLE [dbo].[T_Employee] ADD CONSTRAINT [UQ_Employee_Code] UNIQUE NONCLUSTERED ([EmployeeCode] ASC);
GO
ALTER TABLE [dbo].[M_Role] ADD CONSTRAINT [UQ_Role_RoleName] UNIQUE NONCLUSTERED ([RoleName] ASC);
GO
ALTER TABLE [dbo].[T_Payroll] ADD CONSTRAINT [UQ_Payroll] UNIQUE NONCLUSTERED ([EmployeeID] ASC, [PayrollMonth] ASC, [PayrollYear] ASC);
GO
ALTER TABLE [dbo].[M_Department] ADD CONSTRAINT [UQ_Department_Code] UNIQUE NONCLUSTERED ([DepartmentCode] ASC);
GO
ALTER TABLE [dbo].[M_Shift] ADD CONSTRAINT [UQ_Shift_Name] UNIQUE NONCLUSTERED ([ShiftName] ASC);
GO
ALTER TABLE [dbo].[M_IndiaCity] ADD CONSTRAINT [UQ_IndiaCity_State_Name] UNIQUE NONCLUSTERED ([StateID] ASC, [CityName] ASC);
GO
ALTER TABLE [dbo].[T_Employee] ADD CONSTRAINT [UQ_Employee_Phone] UNIQUE NONCLUSTERED ([PhoneNumber] ASC);
GO
ALTER TABLE [dbo].[T_Attendance] ADD CONSTRAINT [UQ_Attendance] UNIQUE NONCLUSTERED ([EmployeeID] ASC, [AttendanceDate] ASC);
GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_M_SalaryMaster_ActiveEmployee] ON [dbo].[M_SalaryMaster] ([EmployeeID] ASC);
GO
ALTER TABLE [dbo].[M_Designation] ADD CONSTRAINT [UQ_Designation_Name] UNIQUE NONCLUSTERED ([DesignationName] ASC);
GO
ALTER TABLE [dbo].[M_OfficeBranch] ADD CONSTRAINT [UQ_OfficeLocation_Code] UNIQUE NONCLUSTERED ([OfficeCode] ASC);
GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_M_TaxMaster_ActiveEmployeeType] ON [dbo].[M_TaxMaster] ([EmployeeID] ASC, [TaxType] ASC);
GO
ALTER TABLE [dbo].[M_IndiaState] ADD CONSTRAINT [UQ_IndiaState_Name] UNIQUE NONCLUSTERED ([StateName] ASC);
GO

-- ===============================================================================
-- 5. ADD CHECK CONSTRAINTS
-- ===============================================================================
ALTER TABLE [dbo].[M_Shift] WITH CHECK ADD CONSTRAINT [CK_Shift_GraceMinutes] CHECK (([GraceMinutes]>=(0)));
ALTER TABLE [dbo].[M_Shift] CHECK CONSTRAINT [CK_Shift_GraceMinutes];
GO
ALTER TABLE [dbo].[M_LeaveType] WITH CHECK ADD CONSTRAINT [CK_LeaveType_MaxLeaves] CHECK (([MaxLeavesPerYear]>=(0)));
ALTER TABLE [dbo].[M_LeaveType] CHECK CONSTRAINT [CK_LeaveType_MaxLeaves];
GO
ALTER TABLE [dbo].[M_Holiday] WITH CHECK ADD CONSTRAINT [CK_Holiday_Type] CHECK (([HolidayType]='Company' OR [HolidayType]='Festival' OR [HolidayType]='National'));
ALTER TABLE [dbo].[M_Holiday] CHECK CONSTRAINT [CK_Holiday_Type];
GO
ALTER TABLE [dbo].[T_Employee] WITH CHECK ADD CONSTRAINT [CK_Employee_BasicSalary] CHECK (([BasicSalary]>=(0)));
ALTER TABLE [dbo].[T_Employee] CHECK CONSTRAINT [CK_Employee_BasicSalary];
GO
ALTER TABLE [dbo].[T_Employee] WITH CHECK ADD CONSTRAINT [CK_Employee_EmploymentType] CHECK (([EmploymentType]='Intern' OR [EmploymentType]='Contract' OR [EmploymentType]='Part-Time' OR [EmploymentType]='Full-Time'));
ALTER TABLE [dbo].[T_Employee] CHECK CONSTRAINT [CK_Employee_EmploymentType];
GO
ALTER TABLE [dbo].[T_Employee] WITH CHECK ADD CONSTRAINT [CK_Employee_Gender] CHECK (([Gender]='Other' OR [Gender]='Female' OR [Gender]='Male'));
ALTER TABLE [dbo].[T_Employee] CHECK CONSTRAINT [CK_Employee_Gender];
GO
ALTER TABLE [dbo].[M_SalaryMaster] WITH CHECK ADD CONSTRAINT [CK_M_SalaryMaster_Allowance] CHECK (([Allowance]>=(0)));
ALTER TABLE [dbo].[M_SalaryMaster] CHECK CONSTRAINT [CK_M_SalaryMaster_Allowance];
GO
ALTER TABLE [dbo].[M_SalaryMaster] WITH CHECK ADD CONSTRAINT [CK_M_SalaryMaster_BasicSalary] CHECK (([BasicSalary]>=(0)));
ALTER TABLE [dbo].[M_SalaryMaster] CHECK CONSTRAINT [CK_M_SalaryMaster_BasicSalary];
GO
ALTER TABLE [dbo].[M_SalaryMaster] WITH CHECK ADD CONSTRAINT [CK_M_SalaryMaster_Bonus] CHECK (([Bonus]>=(0)));
ALTER TABLE [dbo].[M_SalaryMaster] CHECK CONSTRAINT [CK_M_SalaryMaster_Bonus];
GO
ALTER TABLE [dbo].[M_SalaryMaster] WITH CHECK ADD CONSTRAINT [CK_M_SalaryMaster_Deduction] CHECK (([Deduction]>=(0)));
ALTER TABLE [dbo].[M_SalaryMaster] CHECK CONSTRAINT [CK_M_SalaryMaster_Deduction];
GO
ALTER TABLE [dbo].[M_SalaryMaster] WITH CHECK ADD CONSTRAINT [CK_M_SalaryMaster_EffectiveDate] CHECK (([EffectiveTo] IS NULL OR [EffectiveTo]>=[EffectiveFrom]));
ALTER TABLE [dbo].[M_SalaryMaster] CHECK CONSTRAINT [CK_M_SalaryMaster_EffectiveDate];
GO
ALTER TABLE [dbo].[M_SalaryMaster] WITH CHECK ADD CONSTRAINT [CK_M_SalaryMaster_Tax] CHECK (([Tax]>=(0)));
ALTER TABLE [dbo].[M_SalaryMaster] CHECK CONSTRAINT [CK_M_SalaryMaster_Tax];
GO
ALTER TABLE [dbo].[M_TaxMaster] WITH CHECK ADD CONSTRAINT [CK_M_TaxMaster_Amount] CHECK (([TaxAmount]>=(0)));
ALTER TABLE [dbo].[M_TaxMaster] CHECK CONSTRAINT [CK_M_TaxMaster_Amount];
GO
ALTER TABLE [dbo].[M_TaxMaster] WITH CHECK ADD CONSTRAINT [CK_M_TaxMaster_Date] CHECK (([EffectiveTo] IS NULL OR [EffectiveTo]>=[EffectiveFrom]));
ALTER TABLE [dbo].[M_TaxMaster] CHECK CONSTRAINT [CK_M_TaxMaster_Date];
GO
ALTER TABLE [dbo].[M_TaxMaster] WITH CHECK ADD CONSTRAINT [CK_M_TaxMaster_Type] CHECK (([TaxType]='Other' OR [TaxType]='IncomeTax' OR [TaxType]='TDS'));
ALTER TABLE [dbo].[M_TaxMaster] CHECK CONSTRAINT [CK_M_TaxMaster_Type];
GO
ALTER TABLE [dbo].[T_Attendance] WITH CHECK ADD CONSTRAINT [CK_Attendance_Status] CHECK (([Status]='Work From Home' OR [Status]='Half Day' OR [Status]='Leave' OR [Status]='Absent' OR [Status]='Present'));
ALTER TABLE [dbo].[T_Attendance] CHECK CONSTRAINT [CK_Attendance_Status];
GO
ALTER TABLE [dbo].[T_LeaveRequest] WITH CHECK ADD CONSTRAINT [CK_LeaveRequest_Dates] CHECK (([FromDate]<=[ToDate]));
ALTER TABLE [dbo].[T_LeaveRequest] CHECK CONSTRAINT [CK_LeaveRequest_Dates];
GO
ALTER TABLE [dbo].[T_LeaveRequest] WITH CHECK ADD CONSTRAINT [CK_LeaveRequest_NumberOfDays] CHECK (([NumberOfDays]>(0)));
ALTER TABLE [dbo].[T_LeaveRequest] CHECK CONSTRAINT [CK_LeaveRequest_NumberOfDays];
GO
ALTER TABLE [dbo].[T_LeaveRequest] WITH CHECK ADD CONSTRAINT [CK_LeaveRequest_Status] CHECK (([Status]='Cancelled' OR [Status]='Rejected' OR [Status]='Approved' OR [Status]='Pending'));
ALTER TABLE [dbo].[T_LeaveRequest] CHECK CONSTRAINT [CK_LeaveRequest_Status];
GO
ALTER TABLE [dbo].[T_Task] WITH CHECK ADD CONSTRAINT [CK_Task_Dates] CHECK (([StartDate]<=[DueDate]));
ALTER TABLE [dbo].[T_Task] CHECK CONSTRAINT [CK_Task_Dates];
GO
ALTER TABLE [dbo].[T_Task] WITH CHECK ADD CONSTRAINT [CK_Task_Priority] CHECK (([Priority]='Critical' OR [Priority]='High' OR [Priority]='Medium' OR [Priority]='Low'));
ALTER TABLE [dbo].[T_Task] CHECK CONSTRAINT [CK_Task_Priority];
GO
ALTER TABLE [dbo].[T_Task] WITH CHECK ADD CONSTRAINT [CK_Task_Status] CHECK (([Status]='Cancelled' OR [Status]='Completed' OR [Status]='In Progress' OR [Status]='Pending'));
ALTER TABLE [dbo].[T_Task] CHECK CONSTRAINT [CK_Task_Status];
GO
ALTER TABLE [dbo].[T_Announcement] WITH CHECK ADD CONSTRAINT [CK_Announcement_Dates] CHECK (([ExpiryDate] IS NULL OR [PublishDate]<=[ExpiryDate]));
ALTER TABLE [dbo].[T_Announcement] CHECK CONSTRAINT [CK_Announcement_Dates];
GO
ALTER TABLE [dbo].[T_Payroll] WITH CHECK ADD CONSTRAINT [CK_Payroll_Month] CHECK (([PayrollMonth]>=(1) AND [PayrollMonth]<=(12)));
ALTER TABLE [dbo].[T_Payroll] CHECK CONSTRAINT [CK_Payroll_Month];
GO
ALTER TABLE [dbo].[T_Payroll] WITH CHECK ADD CONSTRAINT [CK_Payroll_Status] CHECK (([PaymentStatus]='Paid' OR [PaymentStatus]='Processing' OR [PaymentStatus]='Pending'));
ALTER TABLE [dbo].[T_Payroll] CHECK CONSTRAINT [CK_Payroll_Status];
GO
ALTER TABLE [dbo].[T_Bonus] WITH CHECK ADD CONSTRAINT [CK_T_Bonus_Amount] CHECK (([BonusAmount]>(0)));
ALTER TABLE [dbo].[T_Bonus] CHECK CONSTRAINT [CK_T_Bonus_Amount];
GO
ALTER TABLE [dbo].[T_Bonus] WITH CHECK ADD CONSTRAINT [CK_T_Bonus_Month] CHECK (([BonusMonth]>=(1) AND [BonusMonth]<=(12)));
ALTER TABLE [dbo].[T_Bonus] CHECK CONSTRAINT [CK_T_Bonus_Month];
GO
ALTER TABLE [dbo].[T_Bonus] WITH CHECK ADD CONSTRAINT [CK_T_Bonus_Status] CHECK (([Status]='Cancelled' OR [Status]='Applied' OR [Status]='Pending'));
ALTER TABLE [dbo].[T_Bonus] CHECK CONSTRAINT [CK_T_Bonus_Status];
GO
ALTER TABLE [dbo].[T_Bonus] WITH CHECK ADD CONSTRAINT [CK_T_Bonus_Year] CHECK (([BonusYear]>=(2000)));
ALTER TABLE [dbo].[T_Bonus] CHECK CONSTRAINT [CK_T_Bonus_Year];
GO
ALTER TABLE [dbo].[T_SalaryAdvance] WITH CHECK ADD CONSTRAINT [CK_T_SalaryAdvance_MonthlyRecovery] CHECK (([MonthlyRecoveryAmount]>=(0)));
ALTER TABLE [dbo].[T_SalaryAdvance] CHECK CONSTRAINT [CK_T_SalaryAdvance_MonthlyRecovery];
GO
ALTER TABLE [dbo].[T_SalaryAdvance] WITH CHECK ADD CONSTRAINT [CK_T_SalaryAdvance_OutstandingAmount] CHECK (([OutstandingAmount]>=(0) AND [OutstandingAmount]<=[TotalAmount]));
ALTER TABLE [dbo].[T_SalaryAdvance] CHECK CONSTRAINT [CK_T_SalaryAdvance_OutstandingAmount];
GO
ALTER TABLE [dbo].[T_SalaryAdvance] WITH CHECK ADD CONSTRAINT [CK_T_SalaryAdvance_RecoveredAmount] CHECK (([RecoveredAmount]>=(0) AND [RecoveredAmount]<=[TotalAmount]));
ALTER TABLE [dbo].[T_SalaryAdvance] CHECK CONSTRAINT [CK_T_SalaryAdvance_RecoveredAmount];
GO
ALTER TABLE [dbo].[T_SalaryAdvance] WITH CHECK ADD CONSTRAINT [CK_T_SalaryAdvance_RecoveryMonth] CHECK (([RecoveryStartMonth]>=(1) AND [RecoveryStartMonth]<=(12)));
ALTER TABLE [dbo].[T_SalaryAdvance] CHECK CONSTRAINT [CK_T_SalaryAdvance_RecoveryMonth];
GO
ALTER TABLE [dbo].[T_SalaryAdvance] WITH CHECK ADD CONSTRAINT [CK_T_SalaryAdvance_RecoveryYear] CHECK (([RecoveryStartYear]>=(2000)));
ALTER TABLE [dbo].[T_SalaryAdvance] CHECK CONSTRAINT [CK_T_SalaryAdvance_RecoveryYear];
GO
ALTER TABLE [dbo].[T_SalaryAdvance] WITH CHECK ADD CONSTRAINT [CK_T_SalaryAdvance_Status] CHECK (([Status]='Cancelled' OR [Status]='Completed' OR [Status]='Active'));
ALTER TABLE [dbo].[T_SalaryAdvance] CHECK CONSTRAINT [CK_T_SalaryAdvance_Status];
GO
ALTER TABLE [dbo].[T_SalaryAdvance] WITH CHECK ADD CONSTRAINT [CK_T_SalaryAdvance_TotalAmount] CHECK (([TotalAmount]>(0)));
ALTER TABLE [dbo].[T_SalaryAdvance] CHECK CONSTRAINT [CK_T_SalaryAdvance_TotalAmount];
GO
ALTER TABLE [dbo].[T_SalaryAdvance] WITH CHECK ADD CONSTRAINT [CK_T_SalaryAdvance_Type] CHECK (([TransactionType]='Loan' OR [TransactionType]='Advance'));
ALTER TABLE [dbo].[T_SalaryAdvance] CHECK CONSTRAINT [CK_T_SalaryAdvance_Type];
GO

-- ===============================================================================
-- 6. ADD FOREIGN KEY CONSTRAINTS
-- ===============================================================================
ALTER TABLE [dbo].[T_Announcement] WITH CHECK ADD CONSTRAINT [FK_Announcement_CreatedBy] FOREIGN KEY ([CreatedBy])
    REFERENCES [dbo].[T_Employee] ([EmployeeID]);
ALTER TABLE [dbo].[T_Announcement] CHECK CONSTRAINT [FK_Announcement_CreatedBy];
GO
ALTER TABLE [dbo].[T_Attendance] WITH CHECK ADD CONSTRAINT [FK_Attendance_Employee] FOREIGN KEY ([EmployeeID])
    REFERENCES [dbo].[T_Employee] ([EmployeeID]);
ALTER TABLE [dbo].[T_Attendance] CHECK CONSTRAINT [FK_Attendance_Employee];
GO
ALTER TABLE [dbo].[T_Attendance] WITH CHECK ADD CONSTRAINT [FK_Attendance_Shift] FOREIGN KEY ([ShiftID])
    REFERENCES [dbo].[M_Shift] ([ShiftID]);
ALTER TABLE [dbo].[T_Attendance] CHECK CONSTRAINT [FK_Attendance_Shift];
GO
ALTER TABLE [dbo].[T_Employee] WITH CHECK ADD CONSTRAINT [FK_Employee_Department] FOREIGN KEY ([DepartmentID])
    REFERENCES [dbo].[M_Department] ([DepartmentID]);
ALTER TABLE [dbo].[T_Employee] CHECK CONSTRAINT [FK_Employee_Department];
GO
ALTER TABLE [dbo].[T_Employee] WITH CHECK ADD CONSTRAINT [FK_Employee_Designation] FOREIGN KEY ([DesignationID])
    REFERENCES [dbo].[M_Designation] ([DesignationID]);
ALTER TABLE [dbo].[T_Employee] CHECK CONSTRAINT [FK_Employee_Designation];
GO
ALTER TABLE [dbo].[T_Employee] WITH CHECK ADD CONSTRAINT [FK_Employee_Manager] FOREIGN KEY ([ManagerID])
    REFERENCES [dbo].[T_Employee] ([EmployeeID]);
ALTER TABLE [dbo].[T_Employee] CHECK CONSTRAINT [FK_Employee_Manager];
GO
ALTER TABLE [dbo].[T_Employee] WITH CHECK ADD CONSTRAINT [FK_Employee_OfficeLocation] FOREIGN KEY ([OfficeLocationID])
    REFERENCES [dbo].[M_OfficeBranch] ([OfficeLocationID]);
ALTER TABLE [dbo].[T_Employee] CHECK CONSTRAINT [FK_Employee_OfficeLocation];
GO
ALTER TABLE [dbo].[T_Employee] WITH CHECK ADD CONSTRAINT [FK_Employee_Role] FOREIGN KEY ([RoleID])
    REFERENCES [dbo].[M_Role] ([RoleID]);
ALTER TABLE [dbo].[T_Employee] CHECK CONSTRAINT [FK_Employee_Role];
GO
ALTER TABLE [dbo].[T_Employee] WITH CHECK ADD CONSTRAINT [FK_Employee_Shift] FOREIGN KEY ([ShiftID])
    REFERENCES [dbo].[M_Shift] ([ShiftID]);
ALTER TABLE [dbo].[T_Employee] CHECK CONSTRAINT [FK_Employee_Shift];
GO
ALTER TABLE [dbo].[T_EmployeeDocument] WITH CHECK ADD CONSTRAINT [FK_EmployeeDocument_Employee] FOREIGN KEY ([EmployeeID])
    REFERENCES [dbo].[T_Employee] ([EmployeeID]);
ALTER TABLE [dbo].[T_EmployeeDocument] CHECK CONSTRAINT [FK_EmployeeDocument_Employee];
GO
ALTER TABLE [dbo].[M_IndiaCity] WITH CHECK ADD CONSTRAINT [FK_IndiaCity_State] FOREIGN KEY ([StateID])
    REFERENCES [dbo].[M_IndiaState] ([StateID]);
ALTER TABLE [dbo].[M_IndiaCity] CHECK CONSTRAINT [FK_IndiaCity_State];
GO
ALTER TABLE [dbo].[T_LeaveRequest] WITH CHECK ADD CONSTRAINT [FK_LeaveRequest_ApprovedBy] FOREIGN KEY ([ApprovedBy])
    REFERENCES [dbo].[T_Employee] ([EmployeeID]);
ALTER TABLE [dbo].[T_LeaveRequest] CHECK CONSTRAINT [FK_LeaveRequest_ApprovedBy];
GO
ALTER TABLE [dbo].[T_LeaveRequest] WITH CHECK ADD CONSTRAINT [FK_LeaveRequest_Employee] FOREIGN KEY ([EmployeeID])
    REFERENCES [dbo].[T_Employee] ([EmployeeID]);
ALTER TABLE [dbo].[T_LeaveRequest] CHECK CONSTRAINT [FK_LeaveRequest_Employee];
GO
ALTER TABLE [dbo].[T_LeaveRequest] WITH CHECK ADD CONSTRAINT [FK_LeaveRequest_LeaveType] FOREIGN KEY ([LeaveTypeID])
    REFERENCES [dbo].[M_LeaveType] ([LeaveTypeID]);
ALTER TABLE [dbo].[T_LeaveRequest] CHECK CONSTRAINT [FK_LeaveRequest_LeaveType];
GO
ALTER TABLE [dbo].[M_SalaryMaster] WITH CHECK ADD CONSTRAINT [FK_M_SalaryMaster_Employee] FOREIGN KEY ([EmployeeID])
    REFERENCES [dbo].[T_Employee] ([EmployeeID]);
ALTER TABLE [dbo].[M_SalaryMaster] CHECK CONSTRAINT [FK_M_SalaryMaster_Employee];
GO
ALTER TABLE [dbo].[M_TaxMaster] WITH CHECK ADD CONSTRAINT [FK_M_TaxMaster_Employee] FOREIGN KEY ([EmployeeID])
    REFERENCES [dbo].[T_Employee] ([EmployeeID]);
ALTER TABLE [dbo].[M_TaxMaster] CHECK CONSTRAINT [FK_M_TaxMaster_Employee];
GO
ALTER TABLE [dbo].[T_Payroll] WITH CHECK ADD CONSTRAINT [FK_Payroll_Employee] FOREIGN KEY ([EmployeeID])
    REFERENCES [dbo].[T_Employee] ([EmployeeID]);
ALTER TABLE [dbo].[T_Payroll] CHECK CONSTRAINT [FK_Payroll_Employee];
GO
ALTER TABLE [dbo].[T_Bonus] WITH CHECK ADD CONSTRAINT [FK_T_Bonus_Employee] FOREIGN KEY ([EmployeeID])
    REFERENCES [dbo].[T_Employee] ([EmployeeID]);
ALTER TABLE [dbo].[T_Bonus] CHECK CONSTRAINT [FK_T_Bonus_Employee];
GO
ALTER TABLE [dbo].[T_SalaryAdvance] WITH CHECK ADD CONSTRAINT [FK_T_SalaryAdvance_Employee] FOREIGN KEY ([EmployeeID])
    REFERENCES [dbo].[T_Employee] ([EmployeeID]);
ALTER TABLE [dbo].[T_SalaryAdvance] CHECK CONSTRAINT [FK_T_SalaryAdvance_Employee];
GO
ALTER TABLE [dbo].[T_Task] WITH CHECK ADD CONSTRAINT [FK_Task_AssignedBy] FOREIGN KEY ([AssignedBy])
    REFERENCES [dbo].[T_Employee] ([EmployeeID]);
ALTER TABLE [dbo].[T_Task] CHECK CONSTRAINT [FK_Task_AssignedBy];
GO
ALTER TABLE [dbo].[T_Task] WITH CHECK ADD CONSTRAINT [FK_Task_Employee] FOREIGN KEY ([EmployeeID])
    REFERENCES [dbo].[T_Employee] ([EmployeeID]);
ALTER TABLE [dbo].[T_Task] CHECK CONSTRAINT [FK_Task_Employee];
GO
