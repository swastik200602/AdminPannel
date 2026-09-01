/*****************************************************************************************
 * EMPLOYEE MANAGEMENT SYSTEM - STORED PROCEDURES SCRIPT
 * Script Type: DROP AND CREATE (OR ALTER)
 * Database:    EmployeeManagementDB
 * Total SPs:   52
 * Generated:   2026-09-01 14:54:43
 *****************************************************************************************/
USE [EmployeeManagementDB];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_ActivateUser]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_ActivateUser]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_ActivateUser];
GO

CREATE   PROCEDURE dbo.Procs_ActivateUser
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.T_Users WHERE UserID = @UserID
    )
    BEGIN
        SELECT 404 AS StatusCode, 'User not found.' AS Message;
        RETURN;
    END;

    IF EXISTS (
        SELECT 1 FROM dbo.T_Users
        WHERE UserID = @UserID AND IsActive = 1
    )
    BEGIN
        SELECT 409 AS StatusCode, 'User account is already active.' AS Message;
        RETURN;
    END;

    UPDATE dbo.T_Users
    SET IsActive = 1,
        WrongCount = 0
    WHERE UserID = @UserID;

    SELECT 200 AS StatusCode,
           'User activated successfully.' AS Message;
END;
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_ChangeUserPassword]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_ChangeUserPassword]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_ChangeUserPassword];
GO

/* New password values are stored as SHA2-256(password + random salt).
   Existing legacy rows (NULL PasswordSalt) are accepted once and upgraded. */
CREATE   PROCEDURE dbo.Procs_ChangeUserPassword
    @UserID int,
    @CurrentPassword nvarchar(200),
    @NewPassword nvarchar(200)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Stored nvarchar(100), @Salt nvarchar(128), @NewSalt nvarchar(32), @Expected nvarchar(100);
    SELECT @Stored=PasswordHash, @Salt=PasswordSalt FROM dbo.T_Users WHERE UserID=@UserID AND IsActive=1;
    IF @Stored IS NULL BEGIN SELECT 404 StatusCode, 'User not found or inactive.' Message; RETURN; END;
    SET @Expected = CASE WHEN NULLIF(@Salt,'') IS NULL THEN @CurrentPassword
        ELSE CONVERT(varchar(100), HASHBYTES('SHA2_256', CONVERT(varbinary(max), @CurrentPassword + @Salt)), 2) END;
    IF @Stored <> @Expected BEGIN SELECT 401 StatusCode, 'Current password is incorrect.' Message; RETURN; END;
    SET @NewSalt = LEFT(REPLACE(CONVERT(varchar(36), NEWID()),'-',''),32);
    UPDATE dbo.T_Users SET PasswordHash=CONVERT(varchar(100), HASHBYTES('SHA2_256', CONVERT(varbinary(max), @NewPassword + @NewSalt)), 2), PasswordSalt=@NewSalt, MustChangePassword=0, PasswordChangedAt=SYSDATETIME(), PasswordResetToken=NULL, PasswordResetExpiresAt=NULL WHERE UserID=@UserID;
    SELECT 200 StatusCode, 'Password changed successfully.' Message;
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GeneratePayroll]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GeneratePayroll]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GeneratePayroll];
GO

CREATE   PROCEDURE dbo.Procs_GeneratePayroll
    @EmployeeID INT,
    @PayrollMonth TINYINT,
    @PayrollYear SMALLINT,
    @PaymentStatus NVARCHAR(20) = 'Pending',
    @Remarks NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY

        BEGIN TRANSACTION;

        --------------------------------------------------
        -- BASIC VALIDATION
        --------------------------------------------------
        IF @PayrollMonth NOT BETWEEN 1 AND 12
        BEGIN
            SELECT
                400 AS StatusCode,
                'Payroll month must be between 1 and 12.' AS Message;
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF @PayrollYear < 2000
        BEGIN
            SELECT
                400 AS StatusCode,
                'Invalid payroll year.' AS Message;
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF @PaymentStatus NOT IN
        (
            'Pending',
            'Processing',
            'Paid',
            'Failed'
        )
        BEGIN
            SELECT
                400 AS StatusCode,
                'Invalid payment status.' AS Message;
            ROLLBACK TRANSACTION;
            RETURN;
        END;


        --------------------------------------------------
        -- EMPLOYEE VALIDATION
        --------------------------------------------------
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Employee
            WHERE EmployeeID = @EmployeeID
              AND IsActive = 1
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Employee not found or inactive.' AS Message;
            ROLLBACK TRANSACTION;
            RETURN;
        END;


        --------------------------------------------------
        -- DUPLICATE PAYROLL CHECK
        --------------------------------------------------
        IF EXISTS
        (
            SELECT 1
            FROM dbo.T_Payroll
            WHERE EmployeeID = @EmployeeID
              AND PayrollMonth = @PayrollMonth
              AND PayrollYear = @PayrollYear
        )
        BEGIN
            SELECT
                409 AS StatusCode,
                'Payroll already exists for this employee and month.'
                AS Message;
            ROLLBACK TRANSACTION;
            RETURN;
        END;


        --------------------------------------------------
        -- PAYROLL PERIOD
        --------------------------------------------------
        DECLARE @PayrollStartDate DATE =
            DATEFROMPARTS(@PayrollYear, @PayrollMonth, 1);

        DECLARE @PayrollEndDate DATE =
            EOMONTH(@PayrollStartDate);


        --------------------------------------------------
        -- SALARY MASTER
        --------------------------------------------------
        DECLARE
            @BasicSalary DECIMAL(18,2),
            @Allowance DECIMAL(18,2),
            @SalaryMasterBonus DECIMAL(18,2),
            @NormalDeduction DECIMAL(18,2);


        SELECT TOP 1
            @BasicSalary = BasicSalary,
            @Allowance = Allowance,
            @SalaryMasterBonus = Bonus,
            @NormalDeduction = Deduction
        FROM dbo.M_SalaryMaster
        WHERE EmployeeID = @EmployeeID
          AND EffectiveFrom <= @PayrollEndDate
          AND
          (
              EffectiveTo IS NULL
              OR EffectiveTo >= @PayrollStartDate
          )
        ORDER BY
            EffectiveFrom DESC,
            SalaryMasterID DESC;


        IF @BasicSalary IS NULL
        BEGIN
            SELECT
                404 AS StatusCode,
                'No applicable salary master found for this payroll period.'
                AS Message;
            ROLLBACK TRANSACTION;
            RETURN;
        END;


        --------------------------------------------------
        -- TAX MASTER
        --------------------------------------------------
        DECLARE
            @TDS DECIMAL(18,2) = 0,
            @IncomeTax DECIMAL(18,2) = 0,
            @OtherTax DECIMAL(18,2) = 0,
            @TotalTax DECIMAL(18,2) = 0;


        SELECT
            @TDS =
                ISNULL
                (
                    SUM
                    (
                        CASE
                            WHEN TaxType = 'TDS'
                                THEN TaxAmount
                            ELSE 0
                        END
                    ),
                    0
                ),

            @IncomeTax =
                ISNULL
                (
                    SUM
                    (
                        CASE
                            WHEN TaxType = 'IncomeTax'
                                THEN TaxAmount
                            ELSE 0
                        END
                    ),
                    0
                ),

            @OtherTax =
                ISNULL
                (
                    SUM
                    (
                        CASE
                            WHEN TaxType = 'Other'
                                THEN TaxAmount
                            ELSE 0
                        END
                    ),
                    0
                )
        FROM dbo.M_TaxMaster
        WHERE EmployeeID = @EmployeeID
          AND IsActive = 1
          AND EffectiveFrom <= @PayrollEndDate
          AND
          (
              EffectiveTo IS NULL
              OR EffectiveTo >= @PayrollStartDate
          );


        SET @TotalTax =
              @TDS
            + @IncomeTax
            + @OtherTax;


        --------------------------------------------------
        -- BONUS
        --------------------------------------------------
        DECLARE @TransactionBonus DECIMAL(18,2) = 0;

        SELECT
            @TransactionBonus =
                ISNULL(SUM(BonusAmount), 0)
        FROM dbo.T_Bonus
        WHERE EmployeeID = @EmployeeID
          AND BonusMonth = @PayrollMonth
          AND BonusYear = @PayrollYear
          AND Status = 'Pending';


        DECLARE @TotalBonus DECIMAL(18,2);

        SET @TotalBonus =
              ISNULL(@SalaryMasterBonus, 0)
            + ISNULL(@TransactionBonus, 0);


        --------------------------------------------------
        -- ADVANCE / LOAN RECOVERY
        --------------------------------------------------
        DECLARE
            @AdvanceRecovery DECIMAL(18,2) = 0,
            @AdvanceID INT = NULL,
            @OutstandingAmount DECIMAL(18,2),
            @MonthlyRecoveryAmount DECIMAL(18,2);


        SELECT TOP 1
            @AdvanceID = SalaryAdvanceID,
            @OutstandingAmount = OutstandingAmount,
            @MonthlyRecoveryAmount = MonthlyRecoveryAmount
        FROM dbo.T_SalaryAdvance
        WHERE EmployeeID = @EmployeeID
          AND Status = 'Active'
          AND OutstandingAmount > 0
          AND
          (
              RecoveryStartYear < @PayrollYear
              OR
              (
                  RecoveryStartYear = @PayrollYear
                  AND RecoveryStartMonth <= @PayrollMonth
              )
          )
        ORDER BY
            IssueDate ASC,
            SalaryAdvanceID ASC;


        IF @AdvanceID IS NOT NULL
        BEGIN
            SET @AdvanceRecovery =
                CASE
                    WHEN @MonthlyRecoveryAmount < @OutstandingAmount
                        THEN @MonthlyRecoveryAmount
                    ELSE @OutstandingAmount
                END;
        END;


        --------------------------------------------------
        -- NET SALARY
        --------------------------------------------------
        DECLARE @NetSalary DECIMAL(18,2);

        SET @NetSalary =
              @BasicSalary
            + @Allowance
            + @TotalBonus
            - @NormalDeduction
            - @TotalTax
            - @AdvanceRecovery;


        --------------------------------------------------
        -- INSERT PAYROLL
        --------------------------------------------------
        INSERT INTO dbo.T_Payroll
        (
            EmployeeID,
            PayrollMonth,
            PayrollYear,
            BasicSalary,
            Allowance,
            Bonus,
            Deduction,
            Tax,
            AdvanceRecovery,
            NetSalary,
            PaymentDate,
            PaymentStatus,
            Remarks,
            CreatedAt
        )
        VALUES
        (
            @EmployeeID,
            @PayrollMonth,
            @PayrollYear,
            @BasicSalary,
            @Allowance,
            @TotalBonus,
            @NormalDeduction,
            @TotalTax,
            @AdvanceRecovery,
            @NetSalary,
            NULL,
            @PaymentStatus,
            @Remarks,
            SYSDATETIME()
        );


        --------------------------------------------------
        -- APPLY BONUS
        --------------------------------------------------
        UPDATE dbo.T_Bonus
        SET
            Status = 'Applied',
            PaidDate =
                CASE
                    WHEN @PaymentStatus = 'Paid'
                        THEN CAST(GETDATE() AS DATE)
                    ELSE NULL
                END
        WHERE EmployeeID = @EmployeeID
          AND BonusMonth = @PayrollMonth
          AND BonusYear = @PayrollYear
          AND Status = 'Pending';


        --------------------------------------------------
        -- UPDATE ADVANCE
        --------------------------------------------------
        IF @AdvanceID IS NOT NULL
        BEGIN
            UPDATE dbo.T_SalaryAdvance
            SET
                RecoveredAmount =
                    RecoveredAmount + @AdvanceRecovery,

                OutstandingAmount =
                    OutstandingAmount - @AdvanceRecovery,

                Status =
                    CASE
                        WHEN OutstandingAmount - @AdvanceRecovery <= 0
                            THEN 'Completed'
                        ELSE 'Active'
                    END

            WHERE SalaryAdvanceID = @AdvanceID;
        END;


        --------------------------------------------------
        -- PAYROLL ID
        --------------------------------------------------
        DECLARE @PayrollID INT =
            CONVERT(INT, SCOPE_IDENTITY());


        COMMIT TRANSACTION;


        --------------------------------------------------
        -- SUCCESS RESPONSE
        --------------------------------------------------
        SELECT
            200 AS StatusCode,
            'Payroll generated successfully.' AS Message,

            @PayrollID AS PayrollID,
            @EmployeeID AS EmployeeID,

            @PayrollMonth AS PayrollMonth,
            @PayrollYear AS PayrollYear,

            @BasicSalary AS BasicSalary,
            @Allowance AS Allowance,

            @SalaryMasterBonus AS SalaryMasterBonus,
            @TransactionBonus AS TransactionBonus,
            @TotalBonus AS TotalBonus,

            @NormalDeduction AS Deduction,
            @TDS AS TDS,
            @IncomeTax AS IncomeTax,
            @OtherTax AS OtherTax,
            @TotalTax AS TotalTax,

            @AdvanceRecovery AS AdvanceRecovery,
            @NetSalary AS NetSalary;

    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SELECT
            500 AS StatusCode,
            ERROR_MESSAGE() AS Message;

    END CATCH
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetAnnouncements]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetAnnouncements]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetAnnouncements];
GO

CREATE   PROCEDURE dbo.Procs_GetAnnouncements
    @AnnouncementID INT = NULL,
    @IsActive BIT = NULL,
    @FromDate DATE = NULL,
    @ToDate DATE = NULL,
    @Search NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        A.AnnouncementID,
        A.Title,
        A.Description,
        A.PublishDate,
        A.ExpiryDate,
        A.CreatedBy,
        CONCAT(E.FirstName, ' ', E.LastName) AS CreatedByName,
        A.IsActive,
        A.CreatedAt
    FROM dbo.T_Announcement A
    INNER JOIN dbo.T_Employee E
        ON A.CreatedBy = E.EmployeeID
    WHERE
        (@AnnouncementID IS NULL
            OR A.AnnouncementID = @AnnouncementID)

        AND
        (@IsActive IS NULL
            OR A.IsActive = @IsActive)

        AND
        (@FromDate IS NULL
            OR A.PublishDate >= @FromDate)

        AND
        (@ToDate IS NULL
            OR A.PublishDate <= @ToDate)

        AND
        (
            @Search IS NULL
            OR A.Title LIKE '%' + @Search + '%'
            OR A.Description LIKE '%' + @Search + '%'
        )

    ORDER BY
        A.PublishDate DESC,
        A.AnnouncementID DESC;
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetAttendance]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetAttendance]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetAttendance];
GO

CREATE   PROCEDURE dbo.Procs_GetAttendance
    @AttendanceID INT = NULL,
    @EmployeeID INT = NULL,
    @FromDate DATE = NULL,
    @ToDate DATE = NULL,
    @Status NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------
    -- DATE VALIDATION
    --------------------------------------------------
    IF (@FromDate IS NOT NULL 
        AND @ToDate IS NOT NULL 
        AND @FromDate > @ToDate)
    BEGIN
        SELECT
            400 AS StatusCode,
            'FromDate cannot be greater than ToDate.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- ATTENDANCE ID
    --------------------------------------------------
    IF (@AttendanceID IS NOT NULL)
    BEGIN
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Attendance
            WHERE AttendanceID = @AttendanceID
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Attendance record not found.' AS Message;
            RETURN;
        END;
    END;


    --------------------------------------------------
    -- EMPLOYEE VALIDATION
    --------------------------------------------------
    IF (@EmployeeID IS NOT NULL)
    BEGIN
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Employee
            WHERE EmployeeID = @EmployeeID
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Employee not found.' AS Message;
            RETURN;
        END;
    END;


    --------------------------------------------------
    -- GET ATTENDANCE
    --------------------------------------------------
    SELECT
        A.AttendanceID,
        A.EmployeeID,

        E.EmployeeCode,
        E.FirstName,
        E.LastName,
        CONCAT(E.FirstName, ' ', E.LastName) AS FullName,

        A.AttendanceDate,
        A.CheckInTime,
        A.CheckOutTime,
        A.WorkingHours,
        A.OvertimeHours,
        A.Status,
        A.Remarks,
        A.CreatedAt,

        A.ShiftID,
        S.ShiftName

    FROM dbo.T_Attendance A

    INNER JOIN dbo.T_Employee E
        ON A.EmployeeID = E.EmployeeID

    LEFT JOIN dbo.M_Shift S
        ON A.ShiftID = S.ShiftID

    WHERE
        (@AttendanceID IS NULL OR A.AttendanceID = @AttendanceID)
        AND
        (@EmployeeID IS NULL OR A.EmployeeID = @EmployeeID)
        AND
        (@FromDate IS NULL OR A.AttendanceDate >= @FromDate)
        AND
        (@ToDate IS NULL OR A.AttendanceDate <= @ToDate)
        AND
        (@Status IS NULL OR A.Status = @Status)

    ORDER BY
        A.AttendanceDate DESC,
        A.AttendanceID DESC;
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetBonus]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetBonus]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetBonus];
GO

CREATE   PROCEDURE dbo.Procs_GetBonus
    @BonusID INT = NULL,
    @EmployeeID INT = NULL,
    @BonusMonth TINYINT = NULL,
    @BonusYear SMALLINT = NULL,
    @Status NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------
    -- BONUS ID VALIDATION
    --------------------------------------------------
    IF @BonusID IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.T_Bonus
           WHERE BonusID = @BonusID
       )
    BEGIN
        SELECT
            404 AS StatusCode,
            'Bonus record not found.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- EMPLOYEE VALIDATION
    --------------------------------------------------
    IF @EmployeeID IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.T_Employee
           WHERE EmployeeID = @EmployeeID
       )
    BEGIN
        SELECT
            404 AS StatusCode,
            'Employee not found.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- MONTH VALIDATION
    --------------------------------------------------
    IF @BonusMonth IS NOT NULL
       AND @BonusMonth NOT BETWEEN 1 AND 12
    BEGIN
        SELECT
            400 AS StatusCode,
            'Bonus month must be between 1 and 12.'
            AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- YEAR VALIDATION
    --------------------------------------------------
    IF @BonusYear IS NOT NULL
       AND @BonusYear < 2000
    BEGIN
        SELECT
            400 AS StatusCode,
            'Invalid bonus year.'
            AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- STATUS VALIDATION
    --------------------------------------------------
    IF @Status IS NOT NULL
       AND @Status NOT IN
       (
           'Pending',
           'Applied',
           'Cancelled'
       )
    BEGIN
        SELECT
            400 AS StatusCode,
            'Invalid bonus status.'
            AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- GET BONUS
    --------------------------------------------------
    SELECT
        B.BonusID,
        B.EmployeeID,

        E.EmployeeCode,
        E.FirstName,
        E.LastName,
        CONCAT(E.FirstName, ' ', E.LastName) AS FullName,

        B.BonusAmount,
        B.BonusMonth,
        B.BonusYear,
        B.BonusType,
        B.Reason,

        B.Status,
        B.PaidDate,

        B.CreatedAt,
        B.CreatedBy

    FROM dbo.T_Bonus B

    INNER JOIN dbo.T_Employee E
        ON B.EmployeeID = E.EmployeeID

    WHERE
        (@BonusID IS NULL
         OR B.BonusID = @BonusID)

        AND

        (@EmployeeID IS NULL
         OR B.EmployeeID = @EmployeeID)

        AND

        (@BonusMonth IS NULL
         OR B.BonusMonth = @BonusMonth)

        AND

        (@BonusYear IS NULL
         OR B.BonusYear = @BonusYear)

        AND

        (@Status IS NULL
         OR B.Status = @Status)

    ORDER BY
        B.BonusYear DESC,
        B.BonusMonth DESC,
        B.BonusID DESC;

END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetDepartment]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetDepartment]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetDepartment];
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE dbo.Procs_GetDepartment
	   @DepartmentID INT,
	   @Mode INT
AS
BEGIN
	 
	SET NOCOUNT ON;
	if(@Mode =1)
	begin
	 select [DepartmentID],[DepartmentName],[DepartmentCode],[Description],[IsActive],[CreatedAt] from [dbo].[M_Department] where IsActive=1
	end
	if(@Mode =2)
	begin
	 select [DepartmentID],[DepartmentName],[DepartmentCode],[Description],[IsActive],[CreatedAt] from [dbo].[M_Department] where IsActive=1 and [DepartmentID]=@DepartmentID
	end
	if(@Mode =3)
	begin
	 select [DepartmentID] as Id,[DepartmentName] as Name from [dbo].[M_Department] where IsActive=1 
	end
  

END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetDesignation]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetDesignation]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetDesignation];
GO

CREATE   PROCEDURE dbo.Procs_GetDesignation
    @DesignationID INT = NULL,
    @IsActive BIT = NULL,
    @Search NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        D.DesignationID,
        D.DesignationName,
        D.DesignationCode,
        D.Description,
        D.IsActive,
        D.CreatedAt
    FROM dbo.M_Designation D
    WHERE
        (@DesignationID IS NULL
            OR D.DesignationID = @DesignationID)

        AND
        (@IsActive IS NULL
            OR D.IsActive = @IsActive)

        AND
        (
            @Search IS NULL
            OR D.DesignationName LIKE '%' + @Search + '%'
            OR D.DesignationCode LIKE '%' + @Search + '%'
            OR D.Description LIKE '%' + @Search + '%'
        )

    ORDER BY
        D.DesignationName ASC,
        D.DesignationID ASC;
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetEmployeeDetails]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetEmployeeDetails]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetEmployeeDetails];
GO

CREATE   PROCEDURE dbo.Procs_GetEmployeeDetails
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------
    -- EMPLOYEE VALIDATION
    --------------------------------------------------
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.T_Employee
        WHERE EmployeeID = @EmployeeID
    )
    BEGIN
        SELECT
            404 AS StatusCode,
            'Employee not found.' AS Message;

        RETURN;
    END;


    --------------------------------------------------
    -- EMPLOYEE DETAILS
    --------------------------------------------------
    SELECT
        E.EmployeeID,
        E.EmployeeCode,

        E.FirstName,
        E.LastName,
        E.FirstName + ' ' + E.LastName AS FullName,

        E.Gender,
        E.DateOfBirth,

        E.Email,
        E.PhoneNumber,
        E.EmergencyContact,

        E.Address,
        E.City,
        E.State,
        E.Country,
        E.PostalCode,

        E.DepartmentID,
        E.DesignationID,
        E.OfficeLocationID,
        E.ManagerID,
        E.ShiftID,

        -- Manager Details
        M.EmployeeCode AS ManagerEmployeeCode,
        M.FirstName + ' ' + M.LastName AS ManagerName,

        E.JoiningDate,
        E.EmploymentType,
        E.BasicSalary,

        E.IsActive,
        E.CreatedAt,
        E.UpdatedAt

    FROM dbo.T_Employee E

    LEFT JOIN dbo.T_Employee M
        ON E.ManagerID = M.EmployeeID

    WHERE E.EmployeeID = @EmployeeID;
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetEmployeePayrollHistory]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetEmployeePayrollHistory]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetEmployeePayrollHistory];
GO

CREATE   PROCEDURE dbo.Procs_GetEmployeePayrollHistory
    @EmployeeID INT,
    @FromMonth TINYINT = NULL,
    @FromYear SMALLINT = NULL,
    @ToMonth TINYINT = NULL,
    @ToYear SMALLINT = NULL,
    @PaymentStatus NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------
    -- EMPLOYEE VALIDATION
    --------------------------------------------------
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.T_Employee
        WHERE EmployeeID = @EmployeeID
    )
    BEGIN
        SELECT
            404 AS StatusCode,
            'Employee not found.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- MONTH VALIDATION
    --------------------------------------------------
    IF @FromMonth IS NOT NULL
       AND @FromMonth NOT BETWEEN 1 AND 12
    BEGIN
        SELECT
            400 AS StatusCode,
            'FromMonth must be between 1 and 12.'
            AS Message;
        RETURN;
    END;


    IF @ToMonth IS NOT NULL
       AND @ToMonth NOT BETWEEN 1 AND 12
    BEGIN
        SELECT
            400 AS StatusCode,
            'ToMonth must be between 1 and 12.'
            AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- YEAR VALIDATION
    --------------------------------------------------
    IF @FromYear IS NOT NULL
       AND @FromYear < 2000
    BEGIN
        SELECT
            400 AS StatusCode,
            'Invalid FromYear.'
            AS Message;
        RETURN;
    END;


    IF @ToYear IS NOT NULL
       AND @ToYear < 2000
    BEGIN
        SELECT
            400 AS StatusCode,
            'Invalid ToYear.'
            AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- PAYMENT STATUS VALIDATION
    --------------------------------------------------
    IF @PaymentStatus IS NOT NULL
       AND @PaymentStatus NOT IN
       (
           'Pending',
           'Processing',
           'Paid',
           'Failed'
       )
    BEGIN
        SELECT
            400 AS StatusCode,
            'Invalid payment status.'
            AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- DATE RANGE VALIDATION
    --------------------------------------------------
    IF @FromYear IS NOT NULL
       AND @ToYear IS NOT NULL
    BEGIN
        IF
        (
            @FromYear > @ToYear
        )
        OR
        (
            @FromYear = @ToYear
            AND @FromMonth IS NOT NULL
            AND @ToMonth IS NOT NULL
            AND @FromMonth > @ToMonth
        )
        BEGIN
            SELECT
                400 AS StatusCode,
                'Invalid payroll date range.'
                AS Message;
            RETURN;
        END;
    END;


    --------------------------------------------------
    -- EMPLOYEE PAYROLL HISTORY
    --------------------------------------------------
    SELECT
        P.PayrollID,
        P.EmployeeID,

        E.EmployeeCode,
        E.FirstName,
        E.LastName,
        CONCAT(E.FirstName, ' ', E.LastName) AS FullName,

        P.PayrollMonth,
        P.PayrollYear,

        P.BasicSalary,
        P.Allowance,
        P.Bonus,

        P.Deduction,
        P.Tax,
        P.AdvanceRecovery,

        (
            P.BasicSalary
            + P.Allowance
            + P.Bonus
        ) AS GrossEarnings,

        (
            P.Deduction
            + P.Tax
            + P.AdvanceRecovery
        ) AS TotalDeductions,

        P.NetSalary,

        P.PaymentDate,
        P.PaymentStatus,

        P.Remarks,
        P.CreatedAt

    FROM dbo.T_Payroll P

    INNER JOIN dbo.T_Employee E
        ON P.EmployeeID = E.EmployeeID

    WHERE
        P.EmployeeID = @EmployeeID

        AND
        (
            @FromYear IS NULL
            OR P.PayrollYear > @FromYear
            OR
            (
                P.PayrollYear = @FromYear
                AND
                (
                    @FromMonth IS NULL
                    OR P.PayrollMonth >= @FromMonth
                )
            )
        )

        AND
        (
            @ToYear IS NULL
            OR P.PayrollYear < @ToYear
            OR
            (
                P.PayrollYear = @ToYear
                AND
                (
                    @ToMonth IS NULL
                    OR P.PayrollMonth <= @ToMonth
                )
            )
        )

        AND
        (
            @PaymentStatus IS NULL
            OR P.PaymentStatus = @PaymentStatus
        )

    ORDER BY
        P.PayrollYear DESC,
        P.PayrollMonth DESC,
        P.PayrollID DESC;

END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetEmployees]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetEmployees]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetEmployees];
GO

CREATE PROCEDURE [dbo].[Procs_GetEmployees]
    @EmployeeID INT = NULL,
    @DepartmentID INT = NULL,
    @DesignationID INT = NULL,
    @OfficeLocationID INT = NULL,
    @ManagerID INT = NULL,
    @ShiftID INT = NULL,
    @RoleID INT = NULL,
    @IsActive BIT = NULL,
    @Search NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        E.EmployeeID,
        E.EmployeeCode,
        E.FirstName,
        E.LastName,
        E.FirstName + ' ' + E.LastName AS FullName,
        E.Gender,
        E.DateOfBirth,
        E.Email,
        E.PhoneNumber,
        E.EmergencyContact,
        E.Address,
        E.City,
        E.State,
        E.Country,
        E.PostalCode,

        E.DepartmentID,
        D.DepartmentName,
        E.DesignationID,
        DG.DesignationName,
        E.OfficeLocationID,
        OB.OfficeName,
        E.ManagerID,
        MGR.EmployeeCode AS ManagerEmployeeCode,
        CASE WHEN MGR.EmployeeID IS NULL THEN NULL
             ELSE MGR.FirstName + ' ' + MGR.LastName END AS ManagerName,
        E.RoleID,

        R.RoleName,

        E.ProfileImage,

        E.JoiningDate,
        E.EmploymentType,
        E.BasicSalary,
        E.IsActive,
        E.CreatedAt,
        E.UpdatedAt,
        E.ShiftID

    FROM dbo.T_Employee E

    LEFT JOIN dbo.M_Role R
        ON E.RoleID = R.RoleID

    LEFT JOIN dbo.M_Department D
        ON E.DepartmentID = D.DepartmentID

    LEFT JOIN dbo.M_Designation DG
        ON E.DesignationID = DG.DesignationID

    LEFT JOIN dbo.M_OfficeBranch OB
        ON E.OfficeLocationID = OB.OfficeLocationID

    LEFT JOIN dbo.T_Employee MGR
        ON E.ManagerID = MGR.EmployeeID

    WHERE
        (@EmployeeID IS NULL
         OR E.EmployeeID = @EmployeeID)

        AND
        (@DepartmentID IS NULL
         OR E.DepartmentID = @DepartmentID)

        AND
        (@DesignationID IS NULL
         OR E.DesignationID = @DesignationID)

        AND
        (@OfficeLocationID IS NULL
         OR E.OfficeLocationID = @OfficeLocationID)

        AND
        (@ManagerID IS NULL
         OR E.ManagerID = @ManagerID)

        AND
        (@ShiftID IS NULL
         OR E.ShiftID = @ShiftID)

        AND
        (@RoleID IS NULL
         OR E.RoleID = @RoleID)

        AND
        (@IsActive IS NULL
         OR E.IsActive = @IsActive)

        AND
        (
            @Search IS NULL
            OR E.EmployeeCode LIKE '%' + @Search + '%'
            OR E.FirstName LIKE '%' + @Search + '%'
            OR E.LastName LIKE '%' + @Search + '%'
            OR E.Email LIKE '%' + @Search + '%'
            OR E.PhoneNumber LIKE '%' + @Search + '%'
            OR E.City LIKE '%' + @Search + '%'
            OR E.State LIKE '%' + @Search + '%'
        )

    ORDER BY
        E.EmployeeID DESC;
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetHoliday]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetHoliday]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetHoliday];
GO

CREATE   PROCEDURE [dbo].[Procs_GetHoliday]
    @HolidayID INT = NULL,
    @IsActive BIT = NULL,
    @Search NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        H.HolidayID,
        H.HolidayName,
        H.HolidayDate,
        H.HolidayType,
        H.Description,
        H.IsOptional,
        H.IsActive,
        H.CreatedAt
    FROM dbo.M_Holiday H
    WHERE
        (@HolidayID IS NULL
            OR H.HolidayID = @HolidayID)

        AND
        (@IsActive IS NULL
            OR H.IsActive = @IsActive)

        AND
        (
            @Search IS NULL
            OR H.HolidayName LIKE '%' + @Search + '%'
            OR H.HolidayType LIKE '%' + @Search + '%'
            OR H.Description LIKE '%' + @Search + '%'
        )

    ORDER BY
        H.HolidayDate ASC,
        H.HolidayName ASC,
        H.HolidayID ASC;
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetIndiaCities]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetIndiaCities]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetIndiaCities];
GO

CREATE   PROCEDURE dbo.Procs_GetIndiaCities
    @StateID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CityID, StateID, CityName FROM dbo.M_IndiaCity WHERE StateID = @StateID AND IsActive = 1 ORDER BY CityName;
END;
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetIndiaStates]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetIndiaStates]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetIndiaStates];
GO

CREATE   PROCEDURE dbo.Procs_GetIndiaStates
AS
BEGIN
    SET NOCOUNT ON;
    SELECT StateID, StateName FROM dbo.M_IndiaState WHERE IsActive = 1 ORDER BY StateName;
END;
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetLeaveRequests]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetLeaveRequests]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetLeaveRequests];
GO

CREATE   PROCEDURE dbo.Procs_GetLeaveRequests
    @EmployeeID INT = NULL,
    @Status NVARCHAR(20) = NULL,
    @FromDate DATE = NULL,
    @ToDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------
    -- DATE VALIDATION
    --------------------------------------------------
    IF (@FromDate IS NOT NULL AND @ToDate IS NOT NULL
        AND @FromDate > @ToDate)
    BEGIN
        SELECT
            400 AS StatusCode,
            'FromDate cannot be greater than ToDate.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- EMPLOYEE VALIDATION
    --------------------------------------------------
    IF (@EmployeeID IS NOT NULL
        AND NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Employee
            WHERE EmployeeID = @EmployeeID
        ))
    BEGIN
        SELECT
            404 AS StatusCode,
            'Employee not found.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- GET LEAVE REQUESTS
    --------------------------------------------------
    SELECT
        LR.LeaveRequestID,
        LR.EmployeeID,

        E.EmployeeCode,
        E.FirstName,
        E.LastName,
        CONCAT(E.FirstName, ' ', E.LastName) AS FullName,

        LR.LeaveTypeID,
        LT.LeaveTypeName,

        LR.FromDate,
        LR.ToDate,
        LR.NumberOfDays,
        LR.Reason,
        LR.Status,

        LR.ApprovedBy,

        CONCAT(
            A.FirstName,
            ' ',
            A.LastName
        ) AS ApprovedByName,

        LR.ApprovedDate,
        LR.Remarks,
        LR.CreatedAt

    FROM dbo.T_LeaveRequest LR

    INNER JOIN dbo.T_Employee E
        ON LR.EmployeeID = E.EmployeeID

    INNER JOIN dbo.M_LeaveType LT
        ON LR.LeaveTypeID = LT.LeaveTypeID

    LEFT JOIN dbo.T_Employee A
        ON LR.ApprovedBy = A.EmployeeID

    WHERE
        (@EmployeeID IS NULL OR LR.EmployeeID = @EmployeeID)

        AND
        (@Status IS NULL OR LR.Status = @Status)

        AND
        (@FromDate IS NULL OR LR.FromDate >= @FromDate)

        AND
        (@ToDate IS NULL OR LR.ToDate <= @ToDate)

    ORDER BY
        LR.CreatedAt DESC,
        LR.LeaveRequestID DESC;

END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetLeaveType]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetLeaveType]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetLeaveType];
GO

CREATE   PROCEDURE [dbo].[Procs_GetLeaveType]
    @LeaveTypeID INT = NULL,
    @IsActive BIT = NULL,
    @Search NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        L.LeaveTypeID,
        L.LeaveTypeName,
        L.LeaveCode,
        L.MaxLeavesPerYear,
        L.IsPaidLeave,
        L.IsActive,
        L.CreatedAt
    FROM dbo.M_LeaveType L
    WHERE
        (@LeaveTypeID IS NULL
            OR L.LeaveTypeID = @LeaveTypeID)

        AND
        (@IsActive IS NULL
            OR L.IsActive = @IsActive)

        AND
        (
            @Search IS NULL
            OR L.LeaveTypeName LIKE '%' + @Search + '%'
            OR L.LeaveCode LIKE '%' + @Search + '%'
        )

    ORDER BY
        L.LeaveTypeName ASC,
        L.LeaveTypeID ASC;
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetOfficeBranch]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetOfficeBranch]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetOfficeBranch];
GO

CREATE   PROCEDURE dbo.Procs_GetOfficeBranch
    @OfficeLocationID INT = NULL,
    @IsActive BIT = NULL,
    @Search NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        O.OfficeLocationID,
        O.OfficeName,
        O.OfficeCode,
        O.AddressLine1,
        O.AddressLine2,
        O.City,
        O.State,
        O.Country,
        O.PostalCode,
        O.PhoneNumber,
        O.Email,
        O.IsActive,
        O.CreatedAt
    FROM dbo.M_OfficeBranch O
    WHERE
        (@OfficeLocationID IS NULL
            OR O.OfficeLocationID = @OfficeLocationID)

        AND
        (@IsActive IS NULL
            OR O.IsActive = @IsActive)

        AND
        (
            @Search IS NULL
            OR O.OfficeName LIKE '%' + @Search + '%'
            OR O.OfficeCode LIKE '%' + @Search + '%'
            OR O.AddressLine1 LIKE '%' + @Search + '%'
            OR O.AddressLine2 LIKE '%' + @Search + '%'
            OR O.City LIKE '%' + @Search + '%'
            OR O.State LIKE '%' + @Search + '%'
            OR O.Country LIKE '%' + @Search + '%'
            OR O.PostalCode LIKE '%' + @Search + '%'
            OR O.PhoneNumber LIKE '%' + @Search + '%'
            OR O.Email LIKE '%' + @Search + '%'
        )

    ORDER BY
        O.OfficeName ASC,
        O.OfficeLocationID ASC;
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetPayroll]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetPayroll]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetPayroll];
GO

CREATE   PROCEDURE dbo.Procs_GetPayroll
    @EmployeeID INT = NULL,
    @PayrollMonth TINYINT = NULL,
    @PayrollYear SMALLINT = NULL,
    @PaymentStatus NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------
    -- MONTH VALIDATION
    --------------------------------------------------
    IF (@PayrollMonth IS NOT NULL
        AND (@PayrollMonth < 1 OR @PayrollMonth > 12))
    BEGIN
        SELECT
            400 AS StatusCode,
            'PayrollMonth must be between 1 and 12.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- YEAR VALIDATION
    --------------------------------------------------
    IF (@PayrollYear IS NOT NULL
        AND @PayrollYear < 2000)
    BEGIN
        SELECT
            400 AS StatusCode,
            'Invalid PayrollYear.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- EMPLOYEE VALIDATION
    --------------------------------------------------
    IF (@EmployeeID IS NOT NULL
        AND NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Employee
            WHERE EmployeeID = @EmployeeID
        ))
    BEGIN
        SELECT
            404 AS StatusCode,
            'Employee not found.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- GET PAYROLL
    --------------------------------------------------
    SELECT
        P.PayrollID,
        P.EmployeeID,

        E.EmployeeCode,
        E.FirstName,
        E.LastName,
        CONCAT(E.FirstName, ' ', E.LastName) AS FullName,

        P.PayrollMonth,
        P.PayrollYear,

        P.BasicSalary,
        P.Allowance,
        P.Bonus,
        P.Deduction,
        P.Tax,
        P.NetSalary,

        P.PaymentDate,
        P.PaymentStatus,
        P.Remarks,
        P.CreatedAt

    FROM dbo.T_Payroll P

    INNER JOIN dbo.T_Employee E
        ON P.EmployeeID = E.EmployeeID

    WHERE
        (@EmployeeID IS NULL
            OR P.EmployeeID = @EmployeeID)

        AND
        (@PayrollMonth IS NULL
            OR P.PayrollMonth = @PayrollMonth)

        AND
        (@PayrollYear IS NULL
            OR P.PayrollYear = @PayrollYear)

        AND
        (@PaymentStatus IS NULL
            OR P.PaymentStatus = @PaymentStatus)

    ORDER BY
        P.PayrollYear DESC,
        P.PayrollMonth DESC,
        P.PayrollID DESC;

END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetPayrollDetails]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetPayrollDetails]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetPayrollDetails];
GO

CREATE   PROCEDURE dbo.Procs_GetPayrollDetails
    @PayrollID INT = NULL,
    @EmployeeID INT = NULL,
    @PayrollMonth TINYINT = NULL,
    @PayrollYear SMALLINT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------
    -- PAYROLL ID VALIDATION
    --------------------------------------------------
    IF @PayrollID IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.T_Payroll
           WHERE PayrollID = @PayrollID
       )
    BEGIN
        SELECT
            404 AS StatusCode,
            'Payroll not found.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- EMPLOYEE VALIDATION
    --------------------------------------------------
    IF @EmployeeID IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.T_Employee
           WHERE EmployeeID = @EmployeeID
       )
    BEGIN
        SELECT
            404 AS StatusCode,
            'Employee not found.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- MONTH VALIDATION
    --------------------------------------------------
    IF @PayrollMonth IS NOT NULL
       AND @PayrollMonth NOT BETWEEN 1 AND 12
    BEGIN
        SELECT
            400 AS StatusCode,
            'Payroll month must be between 1 and 12.'
            AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- YEAR VALIDATION
    --------------------------------------------------
    IF @PayrollYear IS NOT NULL
       AND @PayrollYear < 2000
    BEGIN
        SELECT
            400 AS StatusCode,
            'Invalid payroll year.'
            AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- PAYROLL DETAILS
    --------------------------------------------------
    SELECT
        P.PayrollID,
        P.EmployeeID,

        E.EmployeeCode,
        E.FirstName,
        E.LastName,
        CONCAT(E.FirstName, ' ', E.LastName) AS FullName,

        P.PayrollMonth,
        P.PayrollYear,

        P.BasicSalary,
        P.Allowance,
        P.Bonus,

        P.Deduction,
        P.Tax,
        P.AdvanceRecovery,

        P.NetSalary,

        P.PaymentDate,
        P.PaymentStatus,

        P.Remarks,
        P.CreatedAt

    FROM dbo.T_Payroll P

    INNER JOIN dbo.T_Employee E
        ON P.EmployeeID = E.EmployeeID

    WHERE
        (@PayrollID IS NULL
         OR P.PayrollID = @PayrollID)

        AND

        (@EmployeeID IS NULL
         OR P.EmployeeID = @EmployeeID)

        AND

        (@PayrollMonth IS NULL
         OR P.PayrollMonth = @PayrollMonth)

        AND

        (@PayrollYear IS NULL
         OR P.PayrollYear = @PayrollYear)

    ORDER BY
        P.PayrollYear DESC,
        P.PayrollMonth DESC,
        P.PayrollID DESC;

END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetPayrollSummary]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetPayrollSummary]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetPayrollSummary];
GO

CREATE   PROCEDURE dbo.Procs_GetPayrollSummary
    @PayrollMonth TINYINT,
    @PayrollYear SMALLINT
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------
    -- MONTH VALIDATION
    --------------------------------------------------
    IF @PayrollMonth NOT BETWEEN 1 AND 12
    BEGIN
        SELECT
            400 AS StatusCode,
            'Payroll month must be between 1 and 12.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- YEAR VALIDATION
    --------------------------------------------------
    IF @PayrollYear < 2000
    BEGIN
        SELECT
            400 AS StatusCode,
            'Invalid payroll year.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- CHECK PAYROLL EXISTS
    --------------------------------------------------
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.T_Payroll
        WHERE PayrollMonth = @PayrollMonth
          AND PayrollYear = @PayrollYear
    )
    BEGIN
        SELECT
            404 AS StatusCode,
            'No payroll records found for the selected month and year.'
            AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- PAYROLL SUMMARY
    --------------------------------------------------
    SELECT
        @PayrollMonth AS PayrollMonth,
        @PayrollYear AS PayrollYear,

        COUNT(*) AS TotalPayrollRecords,

        COUNT
        (
            CASE
                WHEN PaymentStatus = 'Paid'
                    THEN 1
            END
        ) AS PaidCount,

        COUNT
        (
            CASE
                WHEN PaymentStatus = 'Pending'
                    THEN 1
            END
        ) AS PendingCount,

        COUNT
        (
            CASE
                WHEN PaymentStatus = 'Processing'
                    THEN 1
            END
        ) AS ProcessingCount,

        COUNT
        (
            CASE
                WHEN PaymentStatus = 'Failed'
                    THEN 1
            END
        ) AS FailedCount,

        SUM(BasicSalary) AS TotalBasicSalary,

        SUM(Allowance) AS TotalAllowance,

        SUM(Bonus) AS TotalBonus,

        SUM(Deduction) AS TotalDeduction,

        SUM(Tax) AS TotalTax,

        SUM(AdvanceRecovery) AS TotalAdvanceRecovery,

        SUM(NetSalary) AS TotalNetSalary

    FROM dbo.T_Payroll

    WHERE PayrollMonth = @PayrollMonth
      AND PayrollYear = @PayrollYear;

END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetRole]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetRole]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetRole];
GO

CREATE   PROCEDURE [dbo].[Procs_GetRole]
    @RoleID INT = NULL,
    @IsActive BIT = NULL,
    @Search NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        R.RoleID,
        R.RoleName,
        R.Description,
        R.IsActive,
        R.CreatedAt
    FROM dbo.M_Role R
    WHERE
        (@RoleID IS NULL
            OR R.RoleID = @RoleID)

        AND
        (@IsActive IS NULL
            OR R.IsActive = @IsActive)

        AND
        (
            @Search IS NULL
            OR R.RoleName LIKE '%' + @Search + '%'
            OR R.Description LIKE '%' + @Search + '%'
        )

    ORDER BY
        R.RoleName ASC,
        R.RoleID ASC;
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetSalaryAdvance]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetSalaryAdvance]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetSalaryAdvance];
GO

CREATE   PROCEDURE dbo.Procs_GetSalaryAdvance
    @SalaryAdvanceID INT = NULL,
    @EmployeeID INT = NULL,
    @TransactionType NVARCHAR(20) = NULL,
    @Status NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------
    -- SALARY ADVANCE ID VALIDATION
    --------------------------------------------------
    IF @SalaryAdvanceID IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.T_SalaryAdvance
           WHERE SalaryAdvanceID = @SalaryAdvanceID
       )
    BEGIN
        SELECT
            404 AS StatusCode,
            'Salary advance record not found.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- EMPLOYEE VALIDATION
    --------------------------------------------------
    IF @EmployeeID IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.T_Employee
           WHERE EmployeeID = @EmployeeID
       )
    BEGIN
        SELECT
            404 AS StatusCode,
            'Employee not found.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- TYPE VALIDATION
    --------------------------------------------------
    IF @TransactionType IS NOT NULL
       AND @TransactionType NOT IN ('Advance', 'Loan')
    BEGIN
        SELECT
            400 AS StatusCode,
            'Invalid transaction type. Use Advance or Loan.'
            AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- STATUS VALIDATION
    --------------------------------------------------
    IF @Status IS NOT NULL
       AND @Status NOT IN ('Active', 'Completed', 'Cancelled')
    BEGIN
        SELECT
            400 AS StatusCode,
            'Invalid status. Use Active, Completed or Cancelled.'
            AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- GET SALARY ADVANCE
    --------------------------------------------------
    SELECT
        A.SalaryAdvanceID,
        A.EmployeeID,

        E.EmployeeCode,
        E.FirstName,
        E.LastName,
        CONCAT(E.FirstName, ' ', E.LastName) AS FullName,

        A.TransactionType,

        A.TotalAmount,
        A.RecoveredAmount,
        A.OutstandingAmount,
        A.MonthlyRecoveryAmount,

        A.IssueDate,
        A.RecoveryStartMonth,
        A.RecoveryStartYear,

        A.Status,
        A.Remarks,

        A.CreatedAt,
        A.CreatedBy

    FROM dbo.T_SalaryAdvance A

    INNER JOIN dbo.T_Employee E
        ON A.EmployeeID = E.EmployeeID

    WHERE
        (@SalaryAdvanceID IS NULL
         OR A.SalaryAdvanceID = @SalaryAdvanceID)

        AND

        (@EmployeeID IS NULL
         OR A.EmployeeID = @EmployeeID)

        AND

        (@TransactionType IS NULL
         OR A.TransactionType = @TransactionType)

        AND

        (@Status IS NULL
         OR A.Status = @Status)

    ORDER BY
        A.Status ASC,
        A.IssueDate DESC,
        A.SalaryAdvanceID DESC;

END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetSalaryMaster]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetSalaryMaster]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetSalaryMaster];
GO

CREATE   PROCEDURE dbo.Procs_GetSalaryMaster
    @EmployeeID INT = NULL,
    @SalaryMasterID INT = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------
    -- SALARY MASTER ID VALIDATION
    --------------------------------------------------
    IF @SalaryMasterID IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.M_SalaryMaster
           WHERE SalaryMasterID = @SalaryMasterID
       )
    BEGIN
        SELECT
            404 AS StatusCode,
            'Salary master record not found.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- EMPLOYEE VALIDATION
    --------------------------------------------------
    IF @EmployeeID IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.T_Employee
           WHERE EmployeeID = @EmployeeID
       )
    BEGIN
        SELECT
            404 AS StatusCode,
            'Employee not found.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- GET SALARY MASTER
    --------------------------------------------------
    SELECT
        S.SalaryMasterID,
        S.EmployeeID,

        E.EmployeeCode,
        E.FirstName,
        E.LastName,
        CONCAT(E.FirstName, ' ', E.LastName) AS FullName,

        S.BasicSalary,
        S.Allowance,
        S.Bonus,
        S.Deduction,
        S.Tax,

        (
            S.BasicSalary
            + S.Allowance
            + S.Bonus
            - S.Deduction
            - S.Tax
        ) AS NetSalary,

        S.EffectiveFrom,
        S.EffectiveTo,
        S.IsActive,
        S.RevisionReason,
        S.CreatedAt

    FROM dbo.M_SalaryMaster S

    INNER JOIN dbo.T_Employee E
        ON S.EmployeeID = E.EmployeeID

    WHERE
        (@EmployeeID IS NULL
         OR S.EmployeeID = @EmployeeID)

        AND

        (@SalaryMasterID IS NULL
         OR S.SalaryMasterID = @SalaryMasterID)

        AND

        (@IsActive IS NULL
         OR S.IsActive = @IsActive)

    ORDER BY
        S.EmployeeID ASC,
        S.EffectiveFrom DESC,
        S.SalaryMasterID DESC;

END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetSalarySlip]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetSalarySlip]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetSalarySlip];
GO

CREATE   PROCEDURE dbo.Procs_GetSalarySlip
    @PayrollID INT = NULL,
    @EmployeeID INT = NULL,
    @PayrollMonth TINYINT = NULL,
    @PayrollYear SMALLINT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------
    -- PAYROLL ID VALIDATION
    --------------------------------------------------
    IF @PayrollID IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.T_Payroll
           WHERE PayrollID = @PayrollID
       )
    BEGIN
        SELECT
            404 AS StatusCode,
            'Payroll not found.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- EMPLOYEE VALIDATION
    --------------------------------------------------
    IF @EmployeeID IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.T_Employee
           WHERE EmployeeID = @EmployeeID
       )
    BEGIN
        SELECT
            404 AS StatusCode,
            'Employee not found.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- MONTH VALIDATION
    --------------------------------------------------
    IF @PayrollMonth IS NOT NULL
       AND @PayrollMonth NOT BETWEEN 1 AND 12
    BEGIN
        SELECT
            400 AS StatusCode,
            'Payroll month must be between 1 and 12.'
            AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- YEAR VALIDATION
    --------------------------------------------------
    IF @PayrollYear IS NOT NULL
       AND @PayrollYear < 2000
    BEGIN
        SELECT
            400 AS StatusCode,
            'Invalid payroll year.'
            AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- SALARY SLIP
    --------------------------------------------------
    SELECT
        P.PayrollID,
        P.EmployeeID,

        E.EmployeeCode,
        E.FirstName,
        E.LastName,
        CONCAT(E.FirstName, ' ', E.LastName) AS FullName,

        P.PayrollMonth,
        P.PayrollYear,

        --------------------------------------------------
        -- EARNINGS
        --------------------------------------------------
        P.BasicSalary,
        P.Allowance,
        P.Bonus,

        (
            P.BasicSalary
            + P.Allowance
            + P.Bonus
        ) AS GrossEarnings,

        --------------------------------------------------
        -- DEDUCTIONS
        --------------------------------------------------
        P.Deduction,
        P.Tax,
        P.AdvanceRecovery,

        (
            P.Deduction
            + P.Tax
            + P.AdvanceRecovery
        ) AS TotalDeductions,

        --------------------------------------------------
        -- NET
        --------------------------------------------------
        P.NetSalary,

        --------------------------------------------------
        -- PAYMENT
        --------------------------------------------------
        P.PaymentDate,
        P.PaymentStatus,

        P.Remarks,
        P.CreatedAt

    FROM dbo.T_Payroll P

    INNER JOIN dbo.T_Employee E
        ON P.EmployeeID = E.EmployeeID

    WHERE
        (@PayrollID IS NULL
         OR P.PayrollID = @PayrollID)

        AND

        (@EmployeeID IS NULL
         OR P.EmployeeID = @EmployeeID)

        AND

        (@PayrollMonth IS NULL
         OR P.PayrollMonth = @PayrollMonth)

        AND

        (@PayrollYear IS NULL
         OR P.PayrollYear = @PayrollYear)

    ORDER BY
        P.PayrollYear DESC,
        P.PayrollMonth DESC,
        P.PayrollID DESC;

END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetShift]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetShift]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetShift];
GO

CREATE   PROCEDURE [dbo].[Procs_GetShift]
    @ShiftID INT = NULL,
    @IsActive BIT = NULL,
    @Search NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        S.ShiftID,
        S.ShiftName,
        S.ShiftCode,
        S.StartTime,
        S.EndTime,
        S.GraceMinutes,
        S.IsNightShift,
        S.IsActive,
        S.CreatedAt
    FROM dbo.M_Shift S
    WHERE
        (@ShiftID IS NULL
            OR S.ShiftID = @ShiftID)

        AND
        (@IsActive IS NULL
            OR S.IsActive = @IsActive)

        AND
        (
            @Search IS NULL
            OR S.ShiftName LIKE '%' + @Search + '%'
            OR S.ShiftCode LIKE '%' + @Search + '%'
        )

    ORDER BY
        S.ShiftName ASC,
        S.ShiftID ASC;
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetTasks]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetTasks]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetTasks];
GO

CREATE   PROCEDURE dbo.Procs_GetTasks
    @EmployeeID INT = NULL,
    @AssignedBy INT = NULL,
    @Status NVARCHAR(20) = NULL,
    @Priority NVARCHAR(20) = NULL,
    @FromDate DATE = NULL,
    @ToDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------
    -- DATE VALIDATION
    --------------------------------------------------
    IF (@FromDate IS NOT NULL
        AND @ToDate IS NOT NULL
        AND @FromDate > @ToDate)
    BEGIN
        SELECT
            400 AS StatusCode,
            'FromDate cannot be greater than ToDate.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- EMPLOYEE VALIDATION
    --------------------------------------------------
    IF (@EmployeeID IS NOT NULL
        AND NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Employee
            WHERE EmployeeID = @EmployeeID
        ))
    BEGIN
        SELECT
            404 AS StatusCode,
            'Employee not found.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- ASSIGNED BY VALIDATION
    --------------------------------------------------
    IF (@AssignedBy IS NOT NULL
        AND NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Employee
            WHERE EmployeeID = @AssignedBy
        ))
    BEGIN
        SELECT
            404 AS StatusCode,
            'Assigned By employee not found.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- GET TASKS
    --------------------------------------------------
    SELECT
        T.TaskID,

        T.EmployeeID,
        E.EmployeeCode,
        E.FirstName,
        E.LastName,
        CONCAT(E.FirstName, ' ', E.LastName) AS EmployeeName,

        T.AssignedBy,
        CONCAT(A.FirstName, ' ', A.LastName) AS AssignedByName,

        T.TaskTitle,
        T.TaskDescription,
        T.Priority,
        T.Status,

        T.StartDate,
        T.DueDate,
        T.CompletedDate,

        T.CreatedAt

    FROM dbo.T_Task T

    INNER JOIN dbo.T_Employee E
        ON T.EmployeeID = E.EmployeeID

    INNER JOIN dbo.T_Employee A
        ON T.AssignedBy = A.EmployeeID

    WHERE
        (@EmployeeID IS NULL
            OR T.EmployeeID = @EmployeeID)

        AND
        (@AssignedBy IS NULL
            OR T.AssignedBy = @AssignedBy)

        AND
        (@Status IS NULL
            OR T.Status = @Status)

        AND
        (@Priority IS NULL
            OR T.Priority = @Priority)

        AND
        (@FromDate IS NULL
            OR T.DueDate >= @FromDate)

        AND
        (@ToDate IS NULL
            OR T.DueDate <= @ToDate)

    ORDER BY
        T.DueDate ASC,
        T.TaskID DESC;

END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetTaxMaster]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetTaxMaster]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetTaxMaster];
GO

CREATE   PROCEDURE dbo.Procs_GetTaxMaster
    @TaxMasterID INT = NULL,
    @EmployeeID INT = NULL,
    @TaxType NVARCHAR(30) = NULL,
    @IsActive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------
    -- TAX MASTER ID VALIDATION
    --------------------------------------------------
    IF @TaxMasterID IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.M_TaxMaster
           WHERE TaxMasterID = @TaxMasterID
       )
    BEGIN
        SELECT
            404 AS StatusCode,
            'Tax master record not found.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- EMPLOYEE VALIDATION
    --------------------------------------------------
    IF @EmployeeID IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.T_Employee
           WHERE EmployeeID = @EmployeeID
       )
    BEGIN
        SELECT
            404 AS StatusCode,
            'Employee not found.' AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- TAX TYPE VALIDATION
    --------------------------------------------------
    IF @TaxType IS NOT NULL
       AND @TaxType NOT IN
       (
           'TDS',
           'IncomeTax',
           'Other'
       )
    BEGIN
        SELECT
            400 AS StatusCode,
            'Invalid TaxType. Use TDS, IncomeTax or Other.'
            AS Message;
        RETURN;
    END;


    --------------------------------------------------
    -- GET TAX MASTER
    --------------------------------------------------
    SELECT
        T.TaxMasterID,
        T.EmployeeID,

        E.EmployeeCode,
        E.FirstName,
        E.LastName,
        CONCAT(E.FirstName, ' ', E.LastName) AS FullName,

        T.TaxType,
        T.TaxAmount,

        T.EffectiveFrom,
        T.EffectiveTo,

        T.IsActive,
        T.Reason,

        T.CreatedAt,
        T.CreatedBy

    FROM dbo.M_TaxMaster T

    INNER JOIN dbo.T_Employee E
        ON T.EmployeeID = E.EmployeeID

    WHERE
        (@TaxMasterID IS NULL
         OR T.TaxMasterID = @TaxMasterID)

        AND

        (@EmployeeID IS NULL
         OR T.EmployeeID = @EmployeeID)

        AND

        (@TaxType IS NULL
         OR T.TaxType = @TaxType)

        AND

        (@IsActive IS NULL
         OR T.IsActive = @IsActive)

    ORDER BY
        T.EmployeeID ASC,
        T.TaxType ASC,
        T.EffectiveFrom DESC,
        T.TaxMasterID DESC;

END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetUserDetails]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetUserDetails]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetUserDetails];
GO

CREATE   PROCEDURE [dbo].[Procs_GetUserDetails]
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------
    -- USER VALIDATION
    --------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.T_Users
        WHERE UserID = @UserID
    )
    BEGIN
        SELECT
            404 AS StatusCode,
            'User not found.' AS Message;

        RETURN;
    END;


    --------------------------------------------------
    -- USER DETAILS
    --------------------------------------------------

    SELECT
        200 AS StatusCode,
        'User details fetched successfully.' AS Message,

        -- User information
        U.UserID,
        U.EmployeeID,
        U.UserName,

        U.Email AS UserEmail,
        U.MobileNo,

        U.RoleID,
        R.RoleName,
        R.Description AS RoleDescription,

        U.IsActive,
        U.LastLogin,
        U.CreatedAt,

        -- Employee information
        E.EmployeeCode,
        E.FirstName,
        E.LastName,
        E.FirstName + ' ' + E.LastName AS FullName,

        E.Gender,
        E.DateOfBirth,

        E.Email AS EmployeeEmail,
        E.PhoneNumber,
        E.EmergencyContact,

        E.Address,
        E.City,
        E.State,
        E.Country,
        E.PostalCode,

        E.DepartmentID,
        E.DesignationID,
        E.OfficeLocationID,
        E.ManagerID,
        E.ShiftID,

        -- Manager information
        M.EmployeeCode AS ManagerEmployeeCode,
        M.FirstName + ' ' + M.LastName AS ManagerName,

        E.JoiningDate,
        E.EmploymentType,
        E.BasicSalary,

        E.IsActive AS EmployeeIsActive,
        E.CreatedAt AS EmployeeCreatedAt,
        E.UpdatedAt AS EmployeeUpdatedAt

    FROM dbo.T_Users U

    LEFT JOIN dbo.M_Role R
        ON R.RoleID = U.RoleID

    LEFT JOIN dbo.T_Employee E
        ON E.EmployeeID = U.EmployeeID

    LEFT JOIN dbo.T_Employee M
        ON E.ManagerID = M.EmployeeID

    WHERE
        U.UserID = @UserID;

END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_GetUsers]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_GetUsers]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_GetUsers];
GO

CREATE   PROCEDURE [dbo].[Procs_GetUsers]
    @UserID INT = NULL,
    @EmployeeID INT = NULL,
    @RoleID INT = NULL,
    @IsActive BIT = NULL,
    @Search NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        U.UserID,
        U.EmployeeID,

        E.EmployeeCode,
        E.FirstName,
        E.LastName,
        E.FirstName + ' ' + E.LastName AS FullName,

        U.UserName,
        U.Email AS UserEmail,
        U.MobileNo,
        U.RoleID,
        R.RoleName,
        R.Description AS RoleDescription,

        U.IsActive,
        U.LastLogin,
        U.CreatedAt

    FROM dbo.T_Users U

    LEFT JOIN dbo.T_Employee E
        ON E.EmployeeID = U.EmployeeID

    LEFT JOIN dbo.M_Role R
        ON R.RoleID = U.RoleID

    WHERE
        (@UserID IS NULL OR U.UserID = @UserID)

        AND
        (@EmployeeID IS NULL OR U.EmployeeID = @EmployeeID)

        AND
        (@RoleID IS NULL OR U.RoleID = @RoleID)

        AND
        (@IsActive IS NULL OR U.IsActive = @IsActive)

        AND
        (
            @Search IS NULL
            OR LTRIM(RTRIM(@Search)) = ''
            OR U.UserName LIKE '%' + LTRIM(RTRIM(@Search)) + '%'
            OR U.Email LIKE '%' + LTRIM(RTRIM(@Search)) + '%'
            OR U.MobileNo LIKE '%' + LTRIM(RTRIM(@Search)) + '%'
            OR E.EmployeeCode LIKE '%' + LTRIM(RTRIM(@Search)) + '%'
            OR E.FirstName LIKE '%' + LTRIM(RTRIM(@Search)) + '%'
            OR E.LastName LIKE '%' + LTRIM(RTRIM(@Search)) + '%'
            OR (E.FirstName + ' ' + E.LastName) LIKE '%' + LTRIM(RTRIM(@Search)) + '%'
        )

    ORDER BY
        U.UserID DESC;

END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_InsertSalaryRevision]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_InsertSalaryRevision]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_InsertSalaryRevision];
GO

CREATE   PROCEDURE [dbo].[Procs_InsertSalaryRevision]
    @EmployeeID INT,
    @BasicSalary DECIMAL(18,2) = NULL,
    @Allowance DECIMAL(18,2) = 0,
    @Bonus DECIMAL(18,2) = 0,
    @Deduction DECIMAL(18,2) = 0,
    @Tax DECIMAL(18,2) = 0,
    @EffectiveFrom DATE,
    @RevisionReason NVARCHAR(200) = NULL,
    @CreatedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.T_Employee WHERE EmployeeID = @EmployeeID AND IsActive = 1)
        BEGIN
            SELECT 404 AS StatusCode, 'Employee not found or inactive.' AS Message;
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF @EffectiveFrom IS NULL
        BEGIN
            SELECT 400 AS StatusCode, 'EffectiveFrom is required.' AS Message;
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        DECLARE @CurrentSalaryMasterID INT = NULL;
        DECLARE @CurrentEffectiveFrom DATE = NULL;

        SELECT TOP (1)
            @CurrentSalaryMasterID = SalaryMasterID,
            @CurrentEffectiveFrom = EffectiveFrom
        FROM dbo.M_SalaryMaster
        WHERE EmployeeID = @EmployeeID AND IsActive = 1;

        /* Initial setup uses the value entered in Salary Structure. For
           backwards compatibility, NULL still falls back to employee salary. */
        IF @CurrentSalaryMasterID IS NULL AND @BasicSalary IS NULL
            SELECT @BasicSalary = BasicSalary FROM dbo.T_Employee WHERE EmployeeID = @EmployeeID;

        IF @BasicSalary IS NULL OR @BasicSalary < 0 OR @Allowance < 0 OR @Bonus < 0 OR @Deduction < 0 OR @Tax < 0
        BEGIN
            SELECT 400 AS StatusCode, 'Salary amounts cannot be negative or null.' AS Message;
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF EXISTS (SELECT 1 FROM dbo.M_SalaryMaster WHERE EmployeeID = @EmployeeID AND EffectiveFrom = @EffectiveFrom)
        BEGIN
            SELECT 409 AS StatusCode, 'Salary master already exists for this effective date.' AS Message;
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF @CurrentEffectiveFrom IS NOT NULL AND @EffectiveFrom <= @CurrentEffectiveFrom
        BEGIN
            SELECT 400 AS StatusCode, 'New EffectiveFrom must be greater than the current salary EffectiveFrom.' AS Message;
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF @CurrentSalaryMasterID IS NOT NULL
        BEGIN
            UPDATE dbo.M_SalaryMaster
            SET IsActive = 0, EffectiveTo = DATEADD(DAY, -1, @EffectiveFrom)
            WHERE SalaryMasterID = @CurrentSalaryMasterID;
        END;

        INSERT INTO dbo.M_SalaryMaster
        (
            EmployeeID, BasicSalary, Allowance, Bonus, Deduction, Tax,
            EffectiveFrom, EffectiveTo, IsActive, RevisionReason, CreatedAt
        )
        VALUES
        (
            @EmployeeID, @BasicSalary, @Allowance, @Bonus, @Deduction, @Tax,
            @EffectiveFrom, NULL, 1, @RevisionReason, SYSDATETIME()
        );

        COMMIT TRANSACTION;
        SELECT 200 AS StatusCode, 'Salary revision saved successfully.' AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT 500 AS StatusCode, ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_InsertTaxRevision]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_InsertTaxRevision]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_InsertTaxRevision];
GO

CREATE   PROCEDURE dbo.Procs_InsertTaxRevision
    @EmployeeID INT,
    @TaxType NVARCHAR(30),
    @TaxAmount DECIMAL(18,2),
    @EffectiveFrom DATE,
    @Reason NVARCHAR(250) = NULL,
    @CreatedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY

        BEGIN TRANSACTION;

        --------------------------------------------------
        -- EMPLOYEE VALIDATION
        --------------------------------------------------
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Employee
            WHERE EmployeeID = @EmployeeID
              AND IsActive = 1
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Employee not found or inactive.' AS Message;

            ROLLBACK TRANSACTION;
            RETURN;
        END;


        --------------------------------------------------
        -- TAX TYPE VALIDATION
        --------------------------------------------------
        IF @TaxType NOT IN
        (
            'TDS',
            'IncomeTax',
            'Other'
        )
        BEGIN
            SELECT
                400 AS StatusCode,
                'Invalid TaxType. Use TDS, IncomeTax or Other.'
                AS Message;

            ROLLBACK TRANSACTION;
            RETURN;
        END;


        --------------------------------------------------
        -- TAX AMOUNT VALIDATION
        --------------------------------------------------
        IF @TaxAmount < 0
        BEGIN
            SELECT
                400 AS StatusCode,
                'Tax amount cannot be negative.'
                AS Message;

            ROLLBACK TRANSACTION;
            RETURN;
        END;


        --------------------------------------------------
        -- EFFECTIVE DATE VALIDATION
        --------------------------------------------------
        IF @EffectiveFrom IS NULL
        BEGIN
            SELECT
                400 AS StatusCode,
                'EffectiveFrom is required.' AS Message;

            ROLLBACK TRANSACTION;
            RETURN;
        END;


        --------------------------------------------------
        -- CHECK SAME EFFECTIVE DATE
        --------------------------------------------------
        IF EXISTS
        (
            SELECT 1
            FROM dbo.M_TaxMaster
            WHERE EmployeeID = @EmployeeID
              AND TaxType = @TaxType
              AND EffectiveFrom = @EffectiveFrom
        )
        BEGIN
            SELECT
                409 AS StatusCode,
                'Tax master already exists for this effective date.'
                AS Message;

            ROLLBACK TRANSACTION;
            RETURN;
        END;


        --------------------------------------------------
        -- CURRENT ACTIVE TAX
        --------------------------------------------------
        DECLARE @CurrentTaxMasterID INT = NULL;
        DECLARE @CurrentEffectiveFrom DATE = NULL;

        SELECT
            @CurrentTaxMasterID = TaxMasterID,
            @CurrentEffectiveFrom = EffectiveFrom
        FROM dbo.M_TaxMaster
        WHERE EmployeeID = @EmployeeID
          AND TaxType = @TaxType
          AND IsActive = 1;


        --------------------------------------------------
        -- EFFECTIVE DATE ORDER
        --------------------------------------------------
        IF @CurrentEffectiveFrom IS NOT NULL
           AND @EffectiveFrom <= @CurrentEffectiveFrom
        BEGIN
            SELECT
                400 AS StatusCode,
                'New EffectiveFrom must be greater than the current tax EffectiveFrom.'
                AS Message;

            ROLLBACK TRANSACTION;
            RETURN;
        END;


        --------------------------------------------------
        -- CLOSE CURRENT TAX
        --------------------------------------------------
        IF @CurrentTaxMasterID IS NOT NULL
        BEGIN
            UPDATE dbo.M_TaxMaster
            SET
                IsActive = 0,
                EffectiveTo = DATEADD(DAY, -1, @EffectiveFrom)
            WHERE TaxMasterID = @CurrentTaxMasterID;
        END;


        --------------------------------------------------
        -- INSERT NEW TAX MASTER
        --------------------------------------------------
        INSERT INTO dbo.M_TaxMaster
        (
            EmployeeID,
            TaxType,
            TaxAmount,
            EffectiveFrom,
            EffectiveTo,
            IsActive,
            Reason,
            CreatedAt,
            CreatedBy
        )
        VALUES
        (
            @EmployeeID,
            @TaxType,
            @TaxAmount,
            @EffectiveFrom,
            NULL,
            1,
            @Reason,
            SYSDATETIME(),
            @CreatedBy
        );


        DECLARE @NewTaxMasterID INT =
            CONVERT(INT, SCOPE_IDENTITY());


        COMMIT TRANSACTION;


        --------------------------------------------------
        -- SUCCESS
        --------------------------------------------------
        SELECT
            200 AS StatusCode,
            'Tax master created successfully.' AS Message,
            @NewTaxMasterID AS TaxMasterID;

    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SELECT
            500 AS StatusCode,
            ERROR_MESSAGE() AS Message;

    END CATCH
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_InsertUpdateCancelBonus]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_InsertUpdateCancelBonus]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_InsertUpdateCancelBonus];
GO

CREATE   PROCEDURE dbo.Procs_InsertUpdateCancelBonus
    @BonusID INT = NULL,
    @EmployeeID INT = NULL,
    @BonusAmount DECIMAL(18,2) = NULL,
    @BonusMonth TINYINT = NULL,
    @BonusYear SMALLINT = NULL,
    @BonusType NVARCHAR(50) = NULL,
    @Reason NVARCHAR(250) = NULL,
    @PaidDate DATE = NULL,
    @Mode INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY

        --------------------------------------------------
        -- INVALID MODE
        --------------------------------------------------
        IF @Mode NOT IN (1, 2, 3)
        BEGIN
            SELECT
                400 AS StatusCode,
                'Invalid Mode. Use 1 for Insert, 2 for Update, 3 for Cancel.'
                AS Message;
            RETURN;
        END;


        --------------------------------------------------
        -- INSERT
        --------------------------------------------------
        IF @Mode = 1
        BEGIN

            --------------------------------------------------
            -- REQUIRED FIELD VALIDATION
            --------------------------------------------------
            IF @EmployeeID IS NULL
               OR @BonusAmount IS NULL
               OR @BonusMonth IS NULL
               OR @BonusYear IS NULL
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'EmployeeID, BonusAmount, BonusMonth and BonusYear are required.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- EMPLOYEE VALIDATION
            --------------------------------------------------
            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.T_Employee
                WHERE EmployeeID = @EmployeeID
                  AND IsActive = 1
            )
            BEGIN
                SELECT
                    404 AS StatusCode,
                    'Employee not found or inactive.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- BONUS AMOUNT VALIDATION
            --------------------------------------------------
            IF @BonusAmount <= 0
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Bonus amount must be greater than zero.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- MONTH VALIDATION
            --------------------------------------------------
            IF @BonusMonth NOT BETWEEN 1 AND 12
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Bonus month must be between 1 and 12.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- YEAR VALIDATION
            --------------------------------------------------
            IF @BonusYear < 2000
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Invalid bonus year.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- DUPLICATE CHECK
            -- Same employee + same month/year + same type
            --------------------------------------------------
            IF EXISTS
            (
                SELECT 1
                FROM dbo.T_Bonus
                WHERE EmployeeID = @EmployeeID
                  AND BonusMonth = @BonusMonth
                  AND BonusYear = @BonusYear
                  AND ISNULL(BonusType, '') = ISNULL(@BonusType, '')
                  AND Status <> 'Cancelled'
            )
            BEGIN
                SELECT
                    409 AS StatusCode,
                    'A bonus already exists for this employee, month and bonus type.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- INSERT BONUS
            --------------------------------------------------
            INSERT INTO dbo.T_Bonus
            (
                EmployeeID,
                BonusAmount,
                BonusMonth,
                BonusYear,
                BonusType,
                Reason,
                Status,
                PaidDate,
                CreatedAt
            )
            VALUES
            (
                @EmployeeID,
                @BonusAmount,
                @BonusMonth,
                @BonusYear,
                @BonusType,
                @Reason,
                'Pending',
                NULL,
                SYSDATETIME()
            );


            SELECT
                200 AS StatusCode,
                'Bonus created successfully.' AS Message,
                CONVERT(INT, SCOPE_IDENTITY()) AS BonusID;

            RETURN;
        END;


        --------------------------------------------------
        -- UPDATE
        --------------------------------------------------
        IF @Mode = 2
        BEGIN

            --------------------------------------------------
            -- ID VALIDATION
            --------------------------------------------------
            IF @BonusID IS NULL
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'BonusID is required for update.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- GET CURRENT STATUS
            --------------------------------------------------
            DECLARE @CurrentStatus NVARCHAR(20);

            SELECT
                @CurrentStatus = Status
            FROM dbo.T_Bonus
            WHERE BonusID = @BonusID;


            IF @CurrentStatus IS NULL
            BEGIN
                SELECT
                    404 AS StatusCode,
                    'Bonus record not found.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- APPLIED BONUS CANNOT BE MODIFIED
            --------------------------------------------------
            IF @CurrentStatus = 'Applied'
            BEGIN
                SELECT
                    409 AS StatusCode,
                    'Applied bonus cannot be modified.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- CANCELLED BONUS CANNOT BE MODIFIED
            --------------------------------------------------
            IF @CurrentStatus = 'Cancelled'
            BEGIN
                SELECT
                    409 AS StatusCode,
                    'Cancelled bonus cannot be modified.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- REQUIRED VALIDATION
            --------------------------------------------------
            IF @EmployeeID IS NULL
               OR @BonusAmount IS NULL
               OR @BonusMonth IS NULL
               OR @BonusYear IS NULL
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'EmployeeID, BonusAmount, BonusMonth and BonusYear are required.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- EMPLOYEE VALIDATION
            --------------------------------------------------
            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.T_Employee
                WHERE EmployeeID = @EmployeeID
                  AND IsActive = 1
            )
            BEGIN
                SELECT
                    404 AS StatusCode,
                    'Employee not found or inactive.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- BONUS VALIDATION
            --------------------------------------------------
            IF @BonusAmount <= 0
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Bonus amount must be greater than zero.'
                    AS Message;
                RETURN;
            END;


            IF @BonusMonth NOT BETWEEN 1 AND 12
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Bonus month must be between 1 and 12.'
                    AS Message;
                RETURN;
            END;


            IF @BonusYear < 2000
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Invalid bonus year.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- DUPLICATE CHECK
            --------------------------------------------------
            IF EXISTS
            (
                SELECT 1
                FROM dbo.T_Bonus
                WHERE EmployeeID = @EmployeeID
                  AND BonusMonth = @BonusMonth
                  AND BonusYear = @BonusYear
                  AND ISNULL(BonusType, '') = ISNULL(@BonusType, '')
                  AND BonusID <> @BonusID
                  AND Status <> 'Cancelled'
            )
            BEGIN
                SELECT
                    409 AS StatusCode,
                    'Another bonus already exists for this employee, month and bonus type.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- UPDATE
            --------------------------------------------------
            UPDATE dbo.T_Bonus
            SET
                EmployeeID = @EmployeeID,
                BonusAmount = @BonusAmount,
                BonusMonth = @BonusMonth,
                BonusYear = @BonusYear,
                BonusType = @BonusType,
                Reason = @Reason
            WHERE BonusID = @BonusID;


            SELECT
                200 AS StatusCode,
                'Bonus updated successfully.' AS Message,
                @BonusID AS BonusID;

            RETURN;
        END;


        --------------------------------------------------
        -- CANCEL
        --------------------------------------------------
        IF @Mode = 3
        BEGIN

            --------------------------------------------------
            -- ID VALIDATION
            --------------------------------------------------
            IF @BonusID IS NULL
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'BonusID is required for cancellation.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- GET CURRENT STATUS
            --------------------------------------------------
            SELECT
                @CurrentStatus = Status
            FROM dbo.T_Bonus
            WHERE BonusID = @BonusID;


            IF @CurrentStatus IS NULL
            BEGIN
                SELECT
                    404 AS StatusCode,
                    'Bonus record not found.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- APPLIED BONUS CANNOT BE CANCELLED
            --------------------------------------------------
            IF @CurrentStatus = 'Applied'
            BEGIN
                SELECT
                    409 AS StatusCode,
                    'Applied bonus cannot be cancelled.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- ALREADY CANCELLED
            --------------------------------------------------
            IF @CurrentStatus = 'Cancelled'
            BEGIN
                SELECT
                    409 AS StatusCode,
                    'Bonus is already cancelled.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- CANCEL BONUS
            --------------------------------------------------
            UPDATE dbo.T_Bonus
            SET
                Status = 'Cancelled',
                PaidDate = NULL,
                Reason =
                    CASE
                        WHEN @Reason IS NULL THEN Reason
                        ELSE @Reason
                    END
            WHERE BonusID = @BonusID;


            SELECT
                200 AS StatusCode,
                'Bonus cancelled successfully.' AS Message,
                @BonusID AS BonusID;

            RETURN;
        END;

    END TRY

    BEGIN CATCH

        SELECT
            500 AS StatusCode,
            ERROR_MESSAGE() AS Message;

    END CATCH
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_InsertUpdateCancelSalaryAdvance]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_InsertUpdateCancelSalaryAdvance]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_InsertUpdateCancelSalaryAdvance];
GO

CREATE   PROCEDURE dbo.Procs_InsertUpdateCancelSalaryAdvance
    @SalaryAdvanceID INT = NULL,
    @EmployeeID INT = NULL,
    @TransactionType NVARCHAR(20) = NULL,
    @TotalAmount DECIMAL(18,2) = NULL,
    @MonthlyRecoveryAmount DECIMAL(18,2) = NULL,
    @IssueDate DATE = NULL,
    @RecoveryStartMonth TINYINT = NULL,
    @RecoveryStartYear SMALLINT = NULL,
    @Remarks NVARCHAR(500) = NULL,
    @Mode INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY

        --------------------------------------------------
        -- INVALID MODE
        --------------------------------------------------
        IF @Mode NOT IN (1, 2, 3)
        BEGIN
            SELECT
                400 AS StatusCode,
                'Invalid Mode. Use 1 for Insert, 2 for Update, 3 for Cancel.'
                AS Message;
            RETURN;
        END;


        --------------------------------------------------
        -- INSERT
        --------------------------------------------------
        IF @Mode = 1
        BEGIN

            --------------------------------------------------
            -- REQUIRED FIELD VALIDATION
            --------------------------------------------------
            IF @EmployeeID IS NULL
               OR @TransactionType IS NULL
               OR @TotalAmount IS NULL
               OR @MonthlyRecoveryAmount IS NULL
               OR @IssueDate IS NULL
               OR @RecoveryStartMonth IS NULL
               OR @RecoveryStartYear IS NULL
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'All required fields must be provided.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- EMPLOYEE VALIDATION
            --------------------------------------------------
            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.T_Employee
                WHERE EmployeeID = @EmployeeID
                  AND IsActive = 1
            )
            BEGIN
                SELECT
                    404 AS StatusCode,
                    'Employee not found or inactive.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- TYPE VALIDATION
            --------------------------------------------------
            IF @TransactionType NOT IN ('Advance', 'Loan')
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Invalid transaction type. Use Advance or Loan.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- AMOUNT VALIDATION
            --------------------------------------------------
            IF @TotalAmount <= 0
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Total amount must be greater than zero.'
                    AS Message;
                RETURN;
            END;


            IF @MonthlyRecoveryAmount <= 0
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Monthly recovery amount must be greater than zero.'
                    AS Message;
                RETURN;
            END;


            IF @MonthlyRecoveryAmount > @TotalAmount
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Monthly recovery amount cannot exceed total amount.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- MONTH / YEAR VALIDATION
            --------------------------------------------------
            IF @RecoveryStartMonth NOT BETWEEN 1 AND 12
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Recovery start month must be between 1 and 12.'
                    AS Message;
                RETURN;
            END;


            IF @RecoveryStartYear < 2000
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Invalid recovery start year.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- ISSUE DATE VALIDATION
            --------------------------------------------------
            IF @IssueDate > DATEFROMPARTS(
                                @RecoveryStartYear,
                                @RecoveryStartMonth,
                                1
                            )
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Issue date cannot be after recovery start month.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- INSERT
            --------------------------------------------------
            INSERT INTO dbo.T_SalaryAdvance
            (
                EmployeeID,
                TransactionType,
                TotalAmount,
                RecoveredAmount,
                OutstandingAmount,
                MonthlyRecoveryAmount,
                IssueDate,
                RecoveryStartMonth,
                RecoveryStartYear,
                Status,
                Remarks,
                CreatedAt
            )
            VALUES
            (
                @EmployeeID,
                @TransactionType,
                @TotalAmount,
                0,
                @TotalAmount,
                @MonthlyRecoveryAmount,
                @IssueDate,
                @RecoveryStartMonth,
                @RecoveryStartYear,
                'Active',
                @Remarks,
                SYSDATETIME()
            );


            SELECT
                200 AS StatusCode,
                'Salary advance/loan created successfully.'
                AS Message,
                CONVERT(INT, SCOPE_IDENTITY()) AS SalaryAdvanceID;

            RETURN;
        END;


        --------------------------------------------------
        -- UPDATE
        --------------------------------------------------
        IF @Mode = 2
        BEGIN

            --------------------------------------------------
            -- ID VALIDATION
            --------------------------------------------------
            IF @SalaryAdvanceID IS NULL
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'SalaryAdvanceID is required for update.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- EXISTENCE + STATUS
            --------------------------------------------------
            DECLARE @CurrentStatus NVARCHAR(20);
            DECLARE @CurrentRecoveredAmount DECIMAL(18,2);

            SELECT
                @CurrentStatus = Status,
                @CurrentRecoveredAmount = RecoveredAmount
            FROM dbo.T_SalaryAdvance
            WHERE SalaryAdvanceID = @SalaryAdvanceID;


            IF @CurrentStatus IS NULL
            BEGIN
                SELECT
                    404 AS StatusCode,
                    'Salary advance/loan record not found.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- ONLY ACTIVE RECORD CAN BE UPDATED
            --------------------------------------------------
            IF @CurrentStatus <> 'Active'
            BEGIN
                SELECT
                    409 AS StatusCode,
                    'Only active salary advance/loan can be updated.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- REQUIRED FIELD VALIDATION
            --------------------------------------------------
            IF @EmployeeID IS NULL
               OR @TransactionType IS NULL
               OR @TotalAmount IS NULL
               OR @MonthlyRecoveryAmount IS NULL
               OR @IssueDate IS NULL
               OR @RecoveryStartMonth IS NULL
               OR @RecoveryStartYear IS NULL
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'All required fields must be provided.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- EMPLOYEE VALIDATION
            --------------------------------------------------
            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.T_Employee
                WHERE EmployeeID = @EmployeeID
                  AND IsActive = 1
            )
            BEGIN
                SELECT
                    404 AS StatusCode,
                    'Employee not found or inactive.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- TYPE VALIDATION
            --------------------------------------------------
            IF @TransactionType NOT IN ('Advance', 'Loan')
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Invalid transaction type. Use Advance or Loan.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- AMOUNT VALIDATION
            --------------------------------------------------
            IF @TotalAmount <= 0
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Total amount must be greater than zero.'
                    AS Message;
                RETURN;
            END;


            IF @MonthlyRecoveryAmount <= 0
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Monthly recovery amount must be greater than zero.'
                    AS Message;
                RETURN;
            END;


            IF @MonthlyRecoveryAmount > @TotalAmount
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Monthly recovery amount cannot exceed total amount.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- CANNOT REDUCE TOTAL BELOW ALREADY RECOVERED
            --------------------------------------------------
            IF @TotalAmount < @CurrentRecoveredAmount
            BEGIN
                SELECT
                    409 AS StatusCode,
                    'Total amount cannot be less than already recovered amount.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- MONTH / YEAR VALIDATION
            --------------------------------------------------
            IF @RecoveryStartMonth NOT BETWEEN 1 AND 12
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Recovery start month must be between 1 and 12.'
                    AS Message;
                RETURN;
            END;


            IF @RecoveryStartYear < 2000
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Invalid recovery start year.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- ISSUE DATE VALIDATION
            --------------------------------------------------
            IF @IssueDate > DATEFROMPARTS(
                                @RecoveryStartYear,
                                @RecoveryStartMonth,
                                1
                            )
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Issue date cannot be after recovery start month.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- UPDATE
            --------------------------------------------------
            UPDATE dbo.T_SalaryAdvance
            SET
                EmployeeID = @EmployeeID,
                TransactionType = @TransactionType,
                TotalAmount = @TotalAmount,
                OutstandingAmount =
                    @TotalAmount - @CurrentRecoveredAmount,
                MonthlyRecoveryAmount = @MonthlyRecoveryAmount,
                IssueDate = @IssueDate,
                RecoveryStartMonth = @RecoveryStartMonth,
                RecoveryStartYear = @RecoveryStartYear,
                Remarks = @Remarks
            WHERE SalaryAdvanceID = @SalaryAdvanceID;


            SELECT
                200 AS StatusCode,
                'Salary advance/loan updated successfully.'
                AS Message,
                @SalaryAdvanceID AS SalaryAdvanceID;

            RETURN;
        END;


        --------------------------------------------------
        -- CANCEL
        --------------------------------------------------
        IF @Mode = 3
        BEGIN

            --------------------------------------------------
            -- ID VALIDATION
            --------------------------------------------------
            IF @SalaryAdvanceID IS NULL
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'SalaryAdvanceID is required for cancellation.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- STATUS CHECK
            --------------------------------------------------
            SELECT
                @CurrentStatus = Status
            FROM dbo.T_SalaryAdvance
            WHERE SalaryAdvanceID = @SalaryAdvanceID;


            IF @CurrentStatus IS NULL
            BEGIN
                SELECT
                    404 AS StatusCode,
                    'Salary advance/loan record not found.'
                    AS Message;
                RETURN;
            END;


            IF @CurrentStatus <> 'Active'
            BEGIN
                SELECT
                    409 AS StatusCode,
                    'Only active salary advance/loan can be cancelled.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- CANCEL
            --------------------------------------------------
            UPDATE dbo.T_SalaryAdvance
            SET
                Status = 'Cancelled',
                Remarks =
                    CASE
                        WHEN @Remarks IS NULL
                            THEN Remarks
                        ELSE @Remarks
                    END
            WHERE SalaryAdvanceID = @SalaryAdvanceID;


            SELECT
                200 AS StatusCode,
                'Salary advance/loan cancelled successfully.'
                AS Message,
                @SalaryAdvanceID AS SalaryAdvanceID;

            RETURN;
        END;

    END TRY

    BEGIN CATCH

        SELECT
            500 AS StatusCode,
            ERROR_MESSAGE() AS Message;

    END CATCH
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_InsertUpdateDeleteAnnouncement]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_InsertUpdateDeleteAnnouncement]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_InsertUpdateDeleteAnnouncement];
GO

CREATE   PROCEDURE dbo.Procs_InsertUpdateDeleteAnnouncement
    @AnnouncementID INT,
    @Title NVARCHAR(200),
    @Description NVARCHAR(MAX),
    @PublishDate DATE,
    @ExpiryDate DATE = NULL,
    @CreatedBy INT,
    @IsActive BIT,
    @Mode INT
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------
    -- INSERT
    --------------------------------------------------
    IF (@Mode = 1)
    BEGIN

        -- Created By validation
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Employee
            WHERE EmployeeID = @CreatedBy
              AND IsActive = 1
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Created By employee not found or inactive.' AS Message;
            RETURN;
        END;


        -- Date validation
        IF (@ExpiryDate IS NOT NULL AND @ExpiryDate < @PublishDate)
        BEGIN
            SELECT
                400 AS StatusCode,
                'ExpiryDate cannot be before PublishDate.' AS Message;
            RETURN;
        END;


        INSERT INTO dbo.T_Announcement
        (
            Title,
            Description,
            PublishDate,
            ExpiryDate,
            CreatedBy,
            IsActive,
            CreatedAt
        )
        VALUES
        (
            @Title,
            @Description,
            @PublishDate,
            @ExpiryDate,
            @CreatedBy,
            @IsActive,
            SYSDATETIME()
        );


        SELECT
            200 AS StatusCode,
            'Announcement inserted successfully.' AS Message,
            SCOPE_IDENTITY() AS AnnouncementID;

        RETURN;
    END;


    --------------------------------------------------
    -- UPDATE
    --------------------------------------------------
    IF (@Mode = 2)
    BEGIN

        -- Announcement validation
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Announcement
            WHERE AnnouncementID = @AnnouncementID
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Announcement not found.' AS Message;
            RETURN;
        END;


        -- Created By validation
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Employee
            WHERE EmployeeID = @CreatedBy
              AND IsActive = 1
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Created By employee not found or inactive.' AS Message;
            RETURN;
        END;


        -- Date validation
        IF (@ExpiryDate IS NOT NULL AND @ExpiryDate < @PublishDate)
        BEGIN
            SELECT
                400 AS StatusCode,
                'ExpiryDate cannot be before PublishDate.' AS Message;
            RETURN;
        END;


        UPDATE dbo.T_Announcement
        SET
            Title = @Title,
            Description = @Description,
            PublishDate = @PublishDate,
            ExpiryDate = @ExpiryDate,
            CreatedBy = @CreatedBy,
            IsActive = @IsActive
        WHERE AnnouncementID = @AnnouncementID;


        SELECT
            200 AS StatusCode,
            'Announcement updated successfully.' AS Message;

        RETURN;
    END;


    --------------------------------------------------
    -- DELETE
    --------------------------------------------------
    IF (@Mode = 3)
    BEGIN

        -- Announcement validation
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Announcement
            WHERE AnnouncementID = @AnnouncementID
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Announcement not found.' AS Message;
            RETURN;
        END;


        DELETE FROM dbo.T_Announcement
        WHERE AnnouncementID = @AnnouncementID;


        SELECT
            200 AS StatusCode,
            'Announcement deleted successfully.' AS Message;

        RETURN;
    END;


    --------------------------------------------------
    -- INVALID MODE
    --------------------------------------------------
    SELECT
        400 AS StatusCode,
        'Invalid Mode. Use 1 for Insert, 2 for Update, 3 for Delete.'
        AS Message;
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_InsertUpdateDeleteAttendance]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_InsertUpdateDeleteAttendance]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_InsertUpdateDeleteAttendance];
GO

CREATE   PROCEDURE dbo.Procs_InsertUpdateDeleteAttendance
    @AttendanceID INT,
    @EmployeeID INT,
    @AttendanceDate DATE,
    @CheckInTime TIME(7) = NULL,
    @CheckOutTime TIME(7) = NULL,
    @WorkingHours DECIMAL(5,2) = NULL,
    @OvertimeHours DECIMAL(5,2) = NULL,
    @Status NVARCHAR(20),
    @Remarks NVARCHAR(255) = NULL,
    @ShiftID INT = NULL,
    @Mode INT
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT
    IF (@Mode = 1)
    BEGIN
        INSERT INTO dbo.T_Attendance
        (
            EmployeeID,
            AttendanceDate,
            CheckInTime,
            CheckOutTime,
            WorkingHours,
            OvertimeHours,
            Status,
            Remarks,
            CreatedAt,
            ShiftID
        )
        VALUES
        (
            @EmployeeID,
            @AttendanceDate,
            @CheckInTime,
            @CheckOutTime,
            @WorkingHours,
            @OvertimeHours,
            @Status,
            @Remarks,
            SYSDATETIME(),
            @ShiftID
        );

        SELECT
            200 AS StatusCode,
            'Attendance inserted successfully.' AS Message;
    END

    -- UPDATE
    ELSE IF (@Mode = 2)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM dbo.T_Attendance
            WHERE AttendanceID = @AttendanceID
        )
        BEGIN
            UPDATE dbo.T_Attendance
            SET
                EmployeeID = @EmployeeID,
                AttendanceDate = @AttendanceDate,
                CheckInTime = @CheckInTime,
                CheckOutTime = @CheckOutTime,
                WorkingHours = @WorkingHours,
                OvertimeHours = @OvertimeHours,
                Status = @Status,
                Remarks = @Remarks,
                ShiftID = @ShiftID
            WHERE AttendanceID = @AttendanceID;

            SELECT
                200 AS StatusCode,
                'Attendance updated successfully.' AS Message;
        END
        ELSE
        BEGIN
            SELECT
                404 AS StatusCode,
                'Attendance not found.' AS Message;
        END
    END

    -- DELETE
    ELSE IF (@Mode = 3)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM dbo.T_Attendance
            WHERE AttendanceID = @AttendanceID
        )
        BEGIN
            DELETE FROM dbo.T_Attendance
            WHERE AttendanceID = @AttendanceID;

            SELECT
                200 AS StatusCode,
                'Attendance deleted successfully.' AS Message;
        END
        ELSE
        BEGIN
            SELECT
                404 AS StatusCode,
                'Attendance not found.' AS Message;
        END
    END

    -- INVALID MODE
    ELSE
    BEGIN
        SELECT
            400 AS StatusCode,
            'Invalid Mode. Use 1 for Insert, 2 for Update, 3 for Delete.'
            AS Message;
    END
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_InsertUpdateDeleteDepartment]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_InsertUpdateDeleteDepartment]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_InsertUpdateDeleteDepartment];
GO

CREATE PROCEDURE dbo.Procs_InsertUpdateDeleteDepartment
    @DepartmentID INT,
    @DepartmentName NVARCHAR(100),
    @DepartmentCode NVARCHAR(20),
    @Description NVARCHAR(255),
    @Mode INT
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT
    IF (@Mode = 1)
    BEGIN
        INSERT INTO dbo.M_Department
        (
            DepartmentName,
            DepartmentCode,
            Description
        )
        VALUES
        (
            @DepartmentName,
            @DepartmentCode,
            @Description
        );

        SELECT
            200 AS StatusCode,
            'Department inserted successfully.' AS Message;
    END

    -- UPDATE
    ELSE IF (@Mode = 2)
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.M_Department WHERE DepartmentID = @DepartmentID AND IsActive = 1)
        BEGIN
            UPDATE dbo.M_Department
            SET
                DepartmentName = @DepartmentName,
                DepartmentCode = @DepartmentCode,
                Description = @Description
            WHERE DepartmentID = @DepartmentID;

            SELECT
                200 AS StatusCode,
                'Department updated successfully.' AS Message;
        END
        ELSE
        BEGIN
            SELECT
                404 AS StatusCode,
                'Department not found.' AS Message;
        END
    END

    -- DELETE (Soft Delete)
    ELSE IF (@Mode = 3)
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.M_Department WHERE DepartmentID = @DepartmentID AND IsActive = 1)
        BEGIN
            UPDATE dbo.M_Department
            SET IsActive = 0
            WHERE DepartmentID = @DepartmentID;

            SELECT
                200 AS StatusCode,
                'Department deleted successfully.' AS Message;
        END
        ELSE
        BEGIN
            SELECT
                404 AS StatusCode,
                'Department not found.' AS Message;
        END
    END

    -- Invalid Mode
    ELSE
    BEGIN
        SELECT
            400 AS StatusCode,
            'Invalid Mode.' AS Message;
    END
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_InsertUpdateDeleteDesignation]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_InsertUpdateDeleteDesignation]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_InsertUpdateDeleteDesignation];
GO

CREATE   PROCEDURE dbo.Procs_InsertUpdateDeleteDesignation
    @DesignationID INT,
    @DesignationName NVARCHAR(100),
    @DesignationCode NVARCHAR(20),
    @Description NVARCHAR(255),
    @Mode INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        -- INSERT
        IF @Mode = 1
        BEGIN
            INSERT INTO dbo.M_Designation
            (
                DesignationName,
                DesignationCode,
                Description
            )
            VALUES
            (
                @DesignationName,
                @DesignationCode,
                @Description
            );

            SELECT
                200 AS StatusCode,
                'Designation inserted successfully.' AS Message;

            RETURN;
        END

        -- UPDATE
        ELSE IF @Mode = 2
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM dbo.M_Designation
                WHERE DesignationID = @DesignationID
                  AND IsActive = 1
            )
            BEGIN
                UPDATE dbo.M_Designation
                SET
                    DesignationName = @DesignationName,
                    DesignationCode = @DesignationCode,
                    Description = @Description
                WHERE DesignationID = @DesignationID;

                SELECT
                    200 AS StatusCode,
                    'Designation updated successfully.' AS Message;
            END
            ELSE
            BEGIN
                SELECT
                    404 AS StatusCode,
                    'Designation not found.' AS Message;
            END

            RETURN;
        END

        -- SOFT DELETE
        ELSE IF @Mode = 3
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM dbo.M_Designation
                WHERE DesignationID = @DesignationID
                  AND IsActive = 1
            )
            BEGIN
                UPDATE dbo.M_Designation
                SET IsActive = 0
                WHERE DesignationID = @DesignationID;

                SELECT
                    200 AS StatusCode,
                    'Designation deleted successfully.' AS Message;
            END
            ELSE
            BEGIN
                SELECT
                    404 AS StatusCode,
                    'Designation not found.' AS Message;
            END

            RETURN;
        END

        -- INVALID MODE
        ELSE
        BEGIN
            SELECT
                400 AS StatusCode,
                'Invalid Mode.' AS Message;
        END

    END TRY

    BEGIN CATCH
        SELECT
            500 AS StatusCode,
            ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_InsertUpdateDeleteEmployee]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_InsertUpdateDeleteEmployee]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_InsertUpdateDeleteEmployee];
GO

CREATE PROCEDURE [dbo].[Procs_InsertUpdateDeleteEmployee]
    @EmployeeID INT,
    @EmployeeCode NVARCHAR(20),
    @FirstName NVARCHAR(100),
    @LastName NVARCHAR(100),
    @Gender NVARCHAR(20),
    @DateOfBirth DATE,
    @Email NVARCHAR(150),
    @PhoneNumber NVARCHAR(20),
    @EmergencyContact NVARCHAR(20) = NULL,
    @Address NVARCHAR(255),
    @City NVARCHAR(100),
    @State NVARCHAR(100),
    @Country NVARCHAR(100),
    @PostalCode NVARCHAR(20),
    @DepartmentID INT,
    @DesignationID INT,
    @OfficeLocationID INT,
    @ManagerID INT = NULL,
    @JoiningDate DATE,
    @EmploymentType NVARCHAR(30),
    @BasicSalary DECIMAL(18,2),
    @ShiftID INT = NULL,

    -- NEW
    @RoleID INT,
    @ProfileImage NVARCHAR(500) = NULL,

    @Mode INT
AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------------
    -- VALIDATE ROLE
    ------------------------------------------------------------
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.M_Role
        WHERE RoleID = @RoleID
          AND IsActive = 1
    )
    BEGIN
        SELECT
            400 AS StatusCode,
            'Invalid or inactive RoleID.' AS Message;
        RETURN;
    END;


    ------------------------------------------------------------
    -- INSERT
    ------------------------------------------------------------
    IF (@Mode = 1)
    BEGIN

        -- Duplicate EmployeeCode check
        IF EXISTS
        (
            SELECT 1
            FROM dbo.T_Employee
            WHERE EmployeeCode = @EmployeeCode
        )
        BEGIN
            SELECT
                409 AS StatusCode,
                'Employee code already exists.' AS Message;
            RETURN;
        END;


        INSERT INTO dbo.T_Employee
        (
            EmployeeCode,
            FirstName,
            LastName,
            Gender,
            DateOfBirth,
            Email,
            PhoneNumber,
            EmergencyContact,
            Address,
            City,
            State,
            Country,
            PostalCode,
            DepartmentID,
            DesignationID,
            OfficeLocationID,
            ManagerID,
            JoiningDate,
            EmploymentType,
            BasicSalary,
            IsActive,
            CreatedAt,
            UpdatedAt,
            ShiftID,
            RoleID,
            ProfileImage
        )
        VALUES
        (
            @EmployeeCode,
            @FirstName,
            @LastName,
            @Gender,
            @DateOfBirth,
            @Email,
            @PhoneNumber,
            @EmergencyContact,
            @Address,
            @City,
            @State,
            @Country,
            @PostalCode,
            @DepartmentID,
            @DesignationID,
            @OfficeLocationID,
            @ManagerID,
            @JoiningDate,
            @EmploymentType,
            @BasicSalary,
            1,
            SYSDATETIME(),
            SYSDATETIME(),
            @ShiftID,
            @RoleID,
            @ProfileImage
        );

        SELECT
            200 AS StatusCode,
            'Employee inserted successfully.' AS Message;

        RETURN;
    END;


    ------------------------------------------------------------
    -- UPDATE
    ------------------------------------------------------------
    ELSE IF (@Mode = 2)
    BEGIN

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Employee
            WHERE EmployeeID = @EmployeeID
              AND IsActive = 1
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Employee not found.' AS Message;
            RETURN;
        END;


        -- Duplicate EmployeeCode check
        IF EXISTS
        (
            SELECT 1
            FROM dbo.T_Employee
            WHERE EmployeeCode = @EmployeeCode
              AND EmployeeID <> @EmployeeID
        )
        BEGIN
            SELECT
                409 AS StatusCode,
                'Employee code already exists.' AS Message;
            RETURN;
        END;


        UPDATE dbo.T_Employee
        SET
            EmployeeCode = @EmployeeCode,
            FirstName = @FirstName,
            LastName = @LastName,
            Gender = @Gender,
            DateOfBirth = @DateOfBirth,
            Email = @Email,
            PhoneNumber = @PhoneNumber,
            EmergencyContact = @EmergencyContact,
            Address = @Address,
            City = @City,
            State = @State,
            Country = @Country,
            PostalCode = @PostalCode,
            DepartmentID = @DepartmentID,
            DesignationID = @DesignationID,
            OfficeLocationID = @OfficeLocationID,
            ManagerID = @ManagerID,
            JoiningDate = @JoiningDate,
            EmploymentType = @EmploymentType,
            BasicSalary = @BasicSalary,
            ShiftID = @ShiftID,

            -- NEW
            RoleID = @RoleID,
            ProfileImage = @ProfileImage,

            UpdatedAt = SYSDATETIME()

        WHERE EmployeeID = @EmployeeID;


        SELECT
            200 AS StatusCode,
            'Employee updated successfully.' AS Message;

        RETURN;
    END;


    ------------------------------------------------------------
    -- SOFT DELETE
    ------------------------------------------------------------
    ELSE IF (@Mode = 3)
    BEGIN

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Employee
            WHERE EmployeeID = @EmployeeID
              AND IsActive = 1
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Employee not found or already deleted.' AS Message;
            RETURN;
        END;


        UPDATE dbo.T_Employee
        SET
            IsActive = 0,
            UpdatedAt = SYSDATETIME()
        WHERE EmployeeID = @EmployeeID;


        SELECT
            200 AS StatusCode,
            'Employee deleted successfully.' AS Message;

        RETURN;
    END;


    ------------------------------------------------------------
    -- INVALID MODE
    ------------------------------------------------------------
    ELSE
    BEGIN
        SELECT
            400 AS StatusCode,
            'Invalid Mode. Use 1 for Insert, 2 for Update, 3 for Delete.'
            AS Message;

        RETURN;
    END;

END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_InsertUpdateDeleteEmployeeDocument]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_InsertUpdateDeleteEmployeeDocument]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_InsertUpdateDeleteEmployeeDocument];
GO

CREATE   PROCEDURE dbo.Procs_InsertUpdateDeleteEmployeeDocument
    @DocumentID INT,
    @EmployeeID INT,
    @DocumentType NVARCHAR(100),
    @DocumentName NVARCHAR(255),
    @FilePath NVARCHAR(500),
    @FileExtension NVARCHAR(20),
    @FileSizeKB DECIMAL(10,2),
    @UploadedDate DATETIME2(7),
    @ExpiryDate DATE = NULL,
    @IsVerified BIT,
    @Remarks NVARCHAR(500) = NULL,
    @Mode INT
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT
    IF (@Mode = 1)
    BEGIN
        INSERT INTO dbo.T_EmployeeDocument
        (
            EmployeeID,
            DocumentType,
            DocumentName,
            FilePath,
            FileExtension,
            FileSizeKB,
            UploadedDate,
            ExpiryDate,
            IsVerified,
            Remarks
        )
        VALUES
        (
            @EmployeeID,
            @DocumentType,
            @DocumentName,
            @FilePath,
            @FileExtension,
            @FileSizeKB,
            @UploadedDate,
            @ExpiryDate,
            @IsVerified,
            @Remarks
        );

        SELECT
            200 AS StatusCode,
            'Employee document inserted successfully.' AS Message;
    END

    -- UPDATE
    ELSE IF (@Mode = 2)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM dbo.T_EmployeeDocument
            WHERE DocumentID = @DocumentID
        )
        BEGIN
            UPDATE dbo.T_EmployeeDocument
            SET
                EmployeeID = @EmployeeID,
                DocumentType = @DocumentType,
                DocumentName = @DocumentName,
                FilePath = @FilePath,
                FileExtension = @FileExtension,
                FileSizeKB = @FileSizeKB,
                UploadedDate = @UploadedDate,
                ExpiryDate = @ExpiryDate,
                IsVerified = @IsVerified,
                Remarks = @Remarks
            WHERE DocumentID = @DocumentID;

            SELECT
                200 AS StatusCode,
                'Employee document updated successfully.' AS Message;
        END
        ELSE
        BEGIN
            SELECT
                404 AS StatusCode,
                'Employee document not found.' AS Message;
        END
    END

    -- DELETE
    ELSE IF (@Mode = 3)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM dbo.T_EmployeeDocument
            WHERE DocumentID = @DocumentID
        )
        BEGIN
            DELETE FROM dbo.T_EmployeeDocument
            WHERE DocumentID = @DocumentID;

            SELECT
                200 AS StatusCode,
                'Employee document deleted successfully.' AS Message;
        END
        ELSE
        BEGIN
            SELECT
                404 AS StatusCode,
                'Employee document not found.' AS Message;
        END
    END

    -- INVALID MODE
    ELSE
    BEGIN
        SELECT
            400 AS StatusCode,
            'Invalid Mode. Use 1 for Insert, 2 for Update, 3 for Delete.'
            AS Message;
    END
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_InsertUpdateDeleteHoliday]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_InsertUpdateDeleteHoliday]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_InsertUpdateDeleteHoliday];
GO

CREATE PROCEDURE dbo.Procs_InsertUpdateDeleteHoliday
    @HolidayID INT,
    @HolidayName NVARCHAR(200),
    @HolidayDate DATE,
    @HolidayType NVARCHAR(50),
    @Description NVARCHAR(500),
    @IsOptional BIT,
    @Mode INT
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT
    IF (@Mode = 1)
    BEGIN
        INSERT INTO dbo.M_Holiday
        (
            HolidayName,
            HolidayDate,
            HolidayType,
            Description,
            IsOptional,
            IsActive
        )
        VALUES
        (
            @HolidayName,
            @HolidayDate,
            @HolidayType,
            @Description,
            @IsOptional,
            1
        );

        SELECT
            200 AS StatusCode,
            'Holiday inserted successfully.' AS Message;
    END

    -- UPDATE
    ELSE IF (@Mode = 2)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM dbo.M_Holiday
            WHERE HolidayID = @HolidayID
              AND IsActive = 1
        )
        BEGIN
            UPDATE dbo.M_Holiday
            SET
                HolidayName = @HolidayName,
                HolidayDate = @HolidayDate,
                HolidayType = @HolidayType,
                Description = @Description,
                IsOptional = @IsOptional
            WHERE HolidayID = @HolidayID;

            SELECT
                200 AS StatusCode,
                'Holiday updated successfully.' AS Message;
        END
        ELSE
        BEGIN
            SELECT
                404 AS StatusCode,
                'Holiday not found.' AS Message;
        END
    END

    -- SOFT DELETE
    ELSE IF (@Mode = 3)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM dbo.M_Holiday
            WHERE HolidayID = @HolidayID
              AND IsActive = 1
        )
        BEGIN
            UPDATE dbo.M_Holiday
            SET IsActive = 0
            WHERE HolidayID = @HolidayID;

            SELECT
                200 AS StatusCode,
                'Holiday deleted successfully.' AS Message;
        END
        ELSE
        BEGIN
            SELECT
                404 AS StatusCode,
                'Holiday not found.' AS Message;
        END
    END

    -- INVALID MODE
    ELSE
    BEGIN
        SELECT
            400 AS StatusCode,
            'Invalid Mode.' AS Message;
    END
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_InsertUpdateDeleteLeaveRequest]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_InsertUpdateDeleteLeaveRequest]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_InsertUpdateDeleteLeaveRequest];
GO

CREATE   PROCEDURE dbo.Procs_InsertUpdateDeleteLeaveRequest
    @LeaveRequestID INT,
    @EmployeeID INT,
    @LeaveTypeID INT,
    @FromDate DATE,
    @ToDate DATE,
    @NumberOfDays DECIMAL(5,2),
    @Reason NVARCHAR(500),
    @Status NVARCHAR(20),
    @ApprovedBy INT = NULL,
    @ApprovedDate DATETIME2(7) = NULL,
    @Remarks NVARCHAR(500) = NULL,
    @Mode INT
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------
    -- INSERT
    --------------------------------------------------
    IF (@Mode = 1)
    BEGIN

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Employee
            WHERE EmployeeID = @EmployeeID
              AND IsActive = 1
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Employee not found or inactive.' AS Message;
            RETURN;
        END

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.M_LeaveType
            WHERE LeaveTypeID = @LeaveTypeID
              AND IsActive = 1
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Leave type not found or inactive.' AS Message;
            RETURN;
        END

        IF (@ApprovedBy IS NOT NULL)
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.T_Employee
                WHERE EmployeeID = @ApprovedBy
                  AND IsActive = 1
            )
            BEGIN
                SELECT
                    404 AS StatusCode,
                    'Approving employee not found or inactive.' AS Message;
                RETURN;
            END
        END

        IF (@FromDate > @ToDate)
        BEGIN
            SELECT
                400 AS StatusCode,
                'FromDate cannot be greater than ToDate.' AS Message;
            RETURN;
        END

        INSERT INTO dbo.T_LeaveRequest
        (
            EmployeeID,
            LeaveTypeID,
            FromDate,
            ToDate,
            NumberOfDays,
            Reason,
            Status,
            ApprovedBy,
            ApprovedDate,
            Remarks,
            CreatedAt
        )
        VALUES
        (
            @EmployeeID,
            @LeaveTypeID,
            @FromDate,
            @ToDate,
            @NumberOfDays,
            @Reason,
            @Status,
            @ApprovedBy,
            @ApprovedDate,
            @Remarks,
            SYSDATETIME()
        );

        SELECT
            200 AS StatusCode,
            'Leave request inserted successfully.' AS Message,
            SCOPE_IDENTITY() AS LeaveRequestID;

        RETURN;
    END


    --------------------------------------------------
    -- UPDATE
    --------------------------------------------------
    IF (@Mode = 2)
    BEGIN

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_LeaveRequest
            WHERE LeaveRequestID = @LeaveRequestID
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Leave request not found.' AS Message;
            RETURN;
        END

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Employee
            WHERE EmployeeID = @EmployeeID
              AND IsActive = 1
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Employee not found or inactive.' AS Message;
            RETURN;
        END

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.M_LeaveType
            WHERE LeaveTypeID = @LeaveTypeID
              AND IsActive = 1
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Leave type not found or inactive.' AS Message;
            RETURN;
        END

        IF (@ApprovedBy IS NOT NULL)
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.T_Employee
                WHERE EmployeeID = @ApprovedBy
                  AND IsActive = 1
            )
            BEGIN
                SELECT
                    404 AS StatusCode,
                    'Approving employee not found or inactive.' AS Message;
                RETURN;
            END
        END

        IF (@FromDate > @ToDate)
        BEGIN
            SELECT
                400 AS StatusCode,
                'FromDate cannot be greater than ToDate.' AS Message;
            RETURN;
        END

        UPDATE dbo.T_LeaveRequest
        SET
            EmployeeID = @EmployeeID,
            LeaveTypeID = @LeaveTypeID,
            FromDate = @FromDate,
            ToDate = @ToDate,
            NumberOfDays = @NumberOfDays,
            Reason = @Reason,
            Status = @Status,
            ApprovedBy = @ApprovedBy,
            ApprovedDate = @ApprovedDate,
            Remarks = @Remarks
        WHERE LeaveRequestID = @LeaveRequestID;

        SELECT
            200 AS StatusCode,
            'Leave request updated successfully.' AS Message;

        RETURN;
    END


    --------------------------------------------------
    -- DELETE
    --------------------------------------------------
    IF (@Mode = 3)
    BEGIN

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_LeaveRequest
            WHERE LeaveRequestID = @LeaveRequestID
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Leave request not found.' AS Message;
            RETURN;
        END

        DELETE FROM dbo.T_LeaveRequest
        WHERE LeaveRequestID = @LeaveRequestID;

        SELECT
            200 AS StatusCode,
            'Leave request deleted successfully.' AS Message;

        RETURN;
    END


    --------------------------------------------------
    -- INVALID MODE
    --------------------------------------------------
    SELECT
        400 AS StatusCode,
        'Invalid Mode. Use 1 for Insert, 2 for Update, 3 for Delete.'
        AS Message;

END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_InsertUpdateDeleteLeaveType]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_InsertUpdateDeleteLeaveType]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_InsertUpdateDeleteLeaveType];
GO

CREATE PROCEDURE dbo.Procs_InsertUpdateDeleteLeaveType
    @LeaveTypeID INT,
    @LeaveTypeName NVARCHAR(100),
    @LeaveCode NVARCHAR(20),
    @MaxLeavesPerYear INT,
    @IsPaidLeave BIT,
    @Mode INT
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT
    IF (@Mode = 1)
    BEGIN
        INSERT INTO dbo.M_LeaveType
        (
            LeaveTypeName,
            LeaveCode,
            MaxLeavesPerYear,
            IsPaidLeave,
            IsActive
        )
        VALUES
        (
            @LeaveTypeName,
            @LeaveCode,
            @MaxLeavesPerYear,
            @IsPaidLeave,
            1
        );

        SELECT
            200 AS StatusCode,
            'Leave type inserted successfully.' AS Message;
    END

    -- UPDATE
    ELSE IF (@Mode = 2)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM dbo.M_LeaveType
            WHERE LeaveTypeID = @LeaveTypeID
              AND IsActive = 1
        )
        BEGIN
            UPDATE dbo.M_LeaveType
            SET
                LeaveTypeName = @LeaveTypeName,
                LeaveCode = @LeaveCode,
                MaxLeavesPerYear = @MaxLeavesPerYear,
                IsPaidLeave = @IsPaidLeave
            WHERE LeaveTypeID = @LeaveTypeID;

            SELECT
                200 AS StatusCode,
                'Leave type updated successfully.' AS Message;
        END
        ELSE
        BEGIN
            SELECT
                404 AS StatusCode,
                'Leave type not found.' AS Message;
        END
    END

    -- SOFT DELETE
    ELSE IF (@Mode = 3)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM dbo.M_LeaveType
            WHERE LeaveTypeID = @LeaveTypeID
              AND IsActive = 1
        )
        BEGIN
            UPDATE dbo.M_LeaveType
            SET IsActive = 0
            WHERE LeaveTypeID = @LeaveTypeID;

            SELECT
                200 AS StatusCode,
                'Leave type deleted successfully.' AS Message;
        END
        ELSE
        BEGIN
            SELECT
                404 AS StatusCode,
                'Leave type not found.' AS Message;
        END
    END

    -- INVALID MODE
    ELSE
    BEGIN
        SELECT
            400 AS StatusCode,
            'Invalid Mode.' AS Message;
    END
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_InsertUpdateDeleteOfficeBranch]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_InsertUpdateDeleteOfficeBranch]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_InsertUpdateDeleteOfficeBranch];
GO

CREATE   PROCEDURE dbo.Procs_InsertUpdateDeleteOfficeBranch
    @OfficeLocationID INT,
    @OfficeName NVARCHAR(100),
    @OfficeCode NVARCHAR(20),
    @AddressLine1 NVARCHAR(200),
    @AddressLine2 NVARCHAR(200),
    @City NVARCHAR(100),
    @State NVARCHAR(100),
    @Country NVARCHAR(100),
    @PostalCode NVARCHAR(20),
    @PhoneNumber NVARCHAR(20),
    @Email NVARCHAR(100),
    @Mode INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        -- =========================
        -- INSERT
        -- =========================
        IF @Mode = 1
        BEGIN
            INSERT INTO dbo.M_OfficeBranch
            (
                OfficeName,
                OfficeCode,
                AddressLine1,
                AddressLine2,
                City,
                State,
                Country,
                PostalCode,
                PhoneNumber,
                Email
            )
            VALUES
            (
                @OfficeName,
                @OfficeCode,
                @AddressLine1,
                @AddressLine2,
                @City,
                @State,
                @Country,
                @PostalCode,
                @PhoneNumber,
                @Email
            );

            SELECT
                200 AS StatusCode,
                'Office branch inserted successfully.' AS Message;

            RETURN;
        END


        -- =========================
        -- UPDATE
        -- =========================
        ELSE IF @Mode = 2
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM dbo.M_OfficeBranch
                WHERE OfficeLocationID = @OfficeLocationID
                  AND IsActive = 1
            )
            BEGIN
                UPDATE dbo.M_OfficeBranch
                SET
                    OfficeName = @OfficeName,
                    OfficeCode = @OfficeCode,
                    AddressLine1 = @AddressLine1,
                    AddressLine2 = @AddressLine2,
                    City = @City,
                    State = @State,
                    Country = @Country,
                    PostalCode = @PostalCode,
                    PhoneNumber = @PhoneNumber,
                    Email = @Email
                WHERE OfficeLocationID = @OfficeLocationID;

                SELECT
                    200 AS StatusCode,
                    'Office branch updated successfully.' AS Message;
            END
            ELSE
            BEGIN
                SELECT
                    404 AS StatusCode,
                    'Office branch not found.' AS Message;
            END

            RETURN;
        END


        -- =========================
        -- SOFT DELETE
        -- =========================
        ELSE IF @Mode = 3
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM dbo.M_OfficeBranch
                WHERE OfficeLocationID = @OfficeLocationID
                  AND IsActive = 1
            )
            BEGIN
                UPDATE dbo.M_OfficeBranch
                SET
                    IsActive = 0
                WHERE OfficeLocationID = @OfficeLocationID;

                SELECT
                    200 AS StatusCode,
                    'Office branch deleted successfully.' AS Message;
            END
            ELSE
            BEGIN
                SELECT
                    404 AS StatusCode,
                    'Office branch not found.' AS Message;
            END

            RETURN;
        END


        -- =========================
        -- INVALID MODE
        -- =========================
        ELSE
        BEGIN
            SELECT
                400 AS StatusCode,
                'Invalid Mode. Use 1 = Insert, 2 = Update, 3 = Delete.'
                    AS Message;

            RETURN;
        END

    END TRY

    BEGIN CATCH

        SELECT
            500 AS StatusCode,
            ERROR_MESSAGE() AS Message;

    END CATCH
END;
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_InsertUpdateDeletePayroll]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_InsertUpdateDeletePayroll]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_InsertUpdateDeletePayroll];
GO

CREATE   PROCEDURE dbo.Procs_InsertUpdateDeletePayroll
    @PayrollID INT = NULL,
    @EmployeeID INT = NULL,
    @PayrollMonth TINYINT = NULL,
    @PayrollYear SMALLINT = NULL,
    @BasicSalary DECIMAL(18,2) = NULL,
    @Allowance DECIMAL(18,2) = NULL,
    @Bonus DECIMAL(18,2) = NULL,
    @Deduction DECIMAL(18,2) = NULL,
    @Tax DECIMAL(18,2) = NULL,
    @NetSalary DECIMAL(18,2) = NULL, -- ignored for calculation
    @PaymentDate DATE = NULL,
    @PaymentStatus NVARCHAR(20) = NULL,
    @Remarks NVARCHAR(500) = NULL,
    @Mode INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY

        --------------------------------------------------
        -- COMMON VALIDATION
        --------------------------------------------------
        IF @Mode NOT IN (1, 2, 3)
        BEGIN
            SELECT
                400 AS StatusCode,
                'Invalid Mode. Use 1 for Insert, 2 for Update, 3 for Delete.'
                AS Message;
            RETURN;
        END;


        --------------------------------------------------
        -- INSERT
        --------------------------------------------------
        IF @Mode = 1
        BEGIN

            IF @EmployeeID IS NULL
            BEGIN
                SELECT 400 AS StatusCode,
                       'EmployeeID is required.' AS Message;
                RETURN;
            END;

            IF @PayrollMonth IS NULL
               OR @PayrollMonth NOT BETWEEN 1 AND 12
            BEGIN
                SELECT 400 AS StatusCode,
                       'Payroll month must be between 1 and 12.'
                       AS Message;
                RETURN;
            END;

            IF @PayrollYear IS NULL
               OR @PayrollYear < 2000
            BEGIN
                SELECT 400 AS StatusCode,
                       'Invalid Payroll year.'
                       AS Message;
                RETURN;
            END;

            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.T_Employee
                WHERE EmployeeID = @EmployeeID
                  AND IsActive = 1
            )
            BEGIN
                SELECT 404 AS StatusCode,
                       'Employee not found or inactive.'
                       AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- SALARY VALIDATION
            --------------------------------------------------
            IF @BasicSalary IS NULL
               OR @Allowance IS NULL
               OR @Bonus IS NULL
               OR @Deduction IS NULL
               OR @Tax IS NULL
            BEGIN
                SELECT 400 AS StatusCode,
                       'All salary components are required.'
                       AS Message;
                RETURN;
            END;

            IF @BasicSalary < 0
               OR @Allowance < 0
               OR @Bonus < 0
               OR @Deduction < 0
               OR @Tax < 0
            BEGIN
                SELECT 400 AS StatusCode,
                       'Salary amounts cannot be negative.'
                       AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- PAYMENT STATUS VALIDATION
            --------------------------------------------------
            IF @PaymentStatus IS NULL
            BEGIN
                SET @PaymentStatus = 'Pending';
            END;

            IF @PaymentStatus NOT IN
            (
                'Pending',
                'Processing',
                'Paid',
                'Failed'
            )
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Invalid payment status.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- PAYMENT DATE RULE
            --------------------------------------------------
            IF @PaymentStatus = 'Paid'
               AND @PaymentDate IS NULL
            BEGIN
                SET @PaymentDate = CAST(GETDATE() AS DATE);
            END;

            IF @PaymentStatus <> 'Paid'
            BEGIN
                SET @PaymentDate = NULL;
            END;


            --------------------------------------------------
            -- DUPLICATE PAYROLL CHECK
            --------------------------------------------------
            IF EXISTS
            (
                SELECT 1
                FROM dbo.T_Payroll
                WHERE EmployeeID = @EmployeeID
                  AND PayrollMonth = @PayrollMonth
                  AND PayrollYear = @PayrollYear
            )
            BEGIN
                SELECT
                    409 AS StatusCode,
                    'Payroll already exists for this employee and month.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- CALCULATE NET SALARY SERVER SIDE
            --------------------------------------------------
            SET @NetSalary =
                  @BasicSalary
                + @Allowance
                + @Bonus
                - @Deduction
                - @Tax;


            --------------------------------------------------
            -- INSERT
            --------------------------------------------------
            INSERT INTO dbo.T_Payroll
            (
                EmployeeID,
                PayrollMonth,
                PayrollYear,
                BasicSalary,
                Allowance,
                Bonus,
                Deduction,
                Tax,
                NetSalary,
                PaymentDate,
                PaymentStatus,
                Remarks,
                CreatedAt
            )
            VALUES
            (
                @EmployeeID,
                @PayrollMonth,
                @PayrollYear,
                @BasicSalary,
                @Allowance,
                @Bonus,
                @Deduction,
                @Tax,
                @NetSalary,
                @PaymentDate,
                @PaymentStatus,
                @Remarks,
                SYSDATETIME()
            );


            SELECT
                200 AS StatusCode,
                'Payroll inserted successfully.' AS Message,
                CONVERT(INT, SCOPE_IDENTITY()) AS PayrollID,
                @NetSalary AS NetSalary;

            RETURN;
        END;


        --------------------------------------------------
        -- UPDATE
        --------------------------------------------------
        IF @Mode = 2
        BEGIN

            IF @PayrollID IS NULL
            BEGIN
                SELECT 400 AS StatusCode,
                       'PayrollID is required for update.'
                       AS Message;
                RETURN;
            END;


            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.T_Payroll
                WHERE PayrollID = @PayrollID
            )
            BEGIN
                SELECT 404 AS StatusCode,
                       'Payroll not found.'
                       AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- EXISTING PAYROLL STATUS
            --------------------------------------------------
            DECLARE @CurrentStatus NVARCHAR(20);

            SELECT
                @CurrentStatus = PaymentStatus
            FROM dbo.T_Payroll
            WHERE PayrollID = @PayrollID;


            --------------------------------------------------
            -- PREVENT EDITING PAID PAYROLL AMOUNTS
            --------------------------------------------------
            IF @CurrentStatus = 'Paid'
            BEGIN
                IF EXISTS
                (
                    SELECT 1
                    FROM dbo.T_Payroll
                    WHERE PayrollID = @PayrollID
                      AND
                      (
                          (EmployeeID <> @EmployeeID)
                          OR
                          (PayrollMonth <> @PayrollMonth)
                          OR
                          (PayrollYear <> @PayrollYear)
                          OR
                          (BasicSalary <> @BasicSalary)
                          OR
                          (Allowance <> @Allowance)
                          OR
                          (Bonus <> @Bonus)
                          OR
                          (Deduction <> @Deduction)
                          OR
                          (Tax <> @Tax)
                      )
                )
                BEGIN
                    SELECT
                        409 AS StatusCode,
                        'Paid payroll cannot be modified.'
                        AS Message;
                    RETURN;
                END;
            END;


            --------------------------------------------------
            -- VALIDATION
            --------------------------------------------------
            IF @PayrollMonth IS NULL
               OR @PayrollMonth NOT BETWEEN 1 AND 12
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Payroll month must be between 1 and 12.'
                    AS Message;
                RETURN;
            END;


            IF @PayrollYear IS NULL
               OR @PayrollYear < 2000
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Invalid Payroll year.'
                    AS Message;
                RETURN;
            END;


            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.T_Employee
                WHERE EmployeeID = @EmployeeID
                  AND IsActive = 1
            )
            BEGIN
                SELECT
                    404 AS StatusCode,
                    'Employee not found or inactive.'
                    AS Message;
                RETURN;
            END;


            IF @BasicSalary < 0
               OR @Allowance < 0
               OR @Bonus < 0
               OR @Deduction < 0
               OR @Tax < 0
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Salary amounts cannot be negative.'
                    AS Message;
                RETURN;
            END;


            IF @PaymentStatus NOT IN
            (
                'Pending',
                'Processing',
                'Paid',
                'Failed'
            )
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'Invalid payment status.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- DUPLICATE CHECK
            --------------------------------------------------
            IF EXISTS
            (
                SELECT 1
                FROM dbo.T_Payroll
                WHERE EmployeeID = @EmployeeID
                  AND PayrollMonth = @PayrollMonth
                  AND PayrollYear = @PayrollYear
                  AND PayrollID <> @PayrollID
            )
            BEGIN
                SELECT
                    409 AS StatusCode,
                    'Another payroll already exists for this employee and month.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- PAYMENT DATE
            --------------------------------------------------
            IF @PaymentStatus = 'Paid'
               AND @PaymentDate IS NULL
            BEGIN
                SET @PaymentDate = CAST(GETDATE() AS DATE);
            END;

            IF @PaymentStatus <> 'Paid'
            BEGIN
                SET @PaymentDate = NULL;
            END;


            --------------------------------------------------
            -- SERVER SIDE NET SALARY
            --------------------------------------------------
            SET @NetSalary =
                  @BasicSalary
                + @Allowance
                + @Bonus
                - @Deduction
                - @Tax;


            --------------------------------------------------
            -- UPDATE
            --------------------------------------------------
            UPDATE dbo.T_Payroll
            SET
                EmployeeID = @EmployeeID,
                PayrollMonth = @PayrollMonth,
                PayrollYear = @PayrollYear,
                BasicSalary = @BasicSalary,
                Allowance = @Allowance,
                Bonus = @Bonus,
                Deduction = @Deduction,
                Tax = @Tax,
                NetSalary = @NetSalary,
                PaymentDate = @PaymentDate,
                PaymentStatus = @PaymentStatus,
                Remarks = @Remarks
            WHERE PayrollID = @PayrollID;


            SELECT
                200 AS StatusCode,
                'Payroll updated successfully.' AS Message,
                @PayrollID AS PayrollID,
                @NetSalary AS NetSalary;

            RETURN;
        END;


        --------------------------------------------------
        -- DELETE
        --------------------------------------------------
        IF @Mode = 3
        BEGIN

            IF @PayrollID IS NULL
            BEGIN
                SELECT
                    400 AS StatusCode,
                    'PayrollID is required for delete.'
                    AS Message;
                RETURN;
            END;


            DECLARE @DeleteStatus NVARCHAR(20);

            SELECT
                @DeleteStatus = PaymentStatus
            FROM dbo.T_Payroll
            WHERE PayrollID = @PayrollID;


            IF @DeleteStatus IS NULL
            BEGIN
                SELECT
                    404 AS StatusCode,
                    'Payroll not found.'
                    AS Message;
                RETURN;
            END;


            --------------------------------------------------
            -- PAID PAYROLL CANNOT BE DELETED
            --------------------------------------------------
            IF @DeleteStatus = 'Paid'
            BEGIN
                SELECT
                    409 AS StatusCode,
                    'Paid payroll cannot be deleted.'
                    AS Message;
                RETURN;
            END;


            DELETE FROM dbo.T_Payroll
            WHERE PayrollID = @PayrollID;


            SELECT
                200 AS StatusCode,
                'Payroll deleted successfully.' AS Message;

            RETURN;
        END;

    END TRY

    BEGIN CATCH

        SELECT
            500 AS StatusCode,
            ERROR_MESSAGE() AS Message;

    END CATCH
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_InsertUpdateDeleteRole]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_InsertUpdateDeleteRole]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_InsertUpdateDeleteRole];
GO

CREATE PROCEDURE dbo.Procs_InsertUpdateDeleteRole
    @RoleID INT,
    @RoleName NVARCHAR(50),
    @Description NVARCHAR(255),
    @Mode INT
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT
    IF (@Mode = 1)
    BEGIN
        INSERT INTO dbo.M_Role
        (
            RoleName,
            Description,
            IsActive
        )
        VALUES
        (
            @RoleName,
            @Description,
            1
        );

        SELECT 200 AS StatusCode,
               'Role inserted successfully.' AS Message;
    END

    -- UPDATE
    ELSE IF (@Mode = 2)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM dbo.M_Role
            WHERE RoleID = @RoleID
              AND IsActive = 1
        )
        BEGIN
            UPDATE dbo.M_Role
            SET
                RoleName = @RoleName,
                Description = @Description
            WHERE RoleID = @RoleID;

            SELECT 200 AS StatusCode,
                   'Role updated successfully.' AS Message;
        END
        ELSE
        BEGIN
            SELECT 404 AS StatusCode,
                   'Role not found.' AS Message;
        END
    END

    -- SOFT DELETE
    ELSE IF (@Mode = 3)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM dbo.M_Role
            WHERE RoleID = @RoleID
              AND IsActive = 1
        )
        BEGIN
            UPDATE dbo.M_Role
            SET IsActive = 0
            WHERE RoleID = @RoleID;

            SELECT 200 AS StatusCode,
                   'Role deleted successfully.' AS Message;
        END
        ELSE
        BEGIN
            SELECT 404 AS StatusCode,
                   'Role not found.' AS Message;
        END
    END

    -- INVALID MODE
    ELSE
    BEGIN
        SELECT 400 AS StatusCode,
               'Invalid Mode.' AS Message;
    END
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_InsertUpdateDeleteShift]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_InsertUpdateDeleteShift]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_InsertUpdateDeleteShift];
GO

CREATE PROCEDURE dbo.Procs_InsertUpdateDeleteShift
    @ShiftID INT,
    @ShiftName NVARCHAR(100),
    @ShiftCode NVARCHAR(20),
    @StartTime TIME(7),
    @EndTime TIME(7),
    @GraceMinutes INT,
    @IsNightShift BIT,
    @Mode INT
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT
    IF (@Mode = 1)
    BEGIN
        INSERT INTO dbo.M_Shift
        (
            ShiftName,
            ShiftCode,
            StartTime,
            EndTime,
            GraceMinutes,
            IsNightShift,
            IsActive
        )
        VALUES
        (
            @ShiftName,
            @ShiftCode,
            @StartTime,
            @EndTime,
            @GraceMinutes,
            @IsNightShift,
            1
        );

        SELECT 200 AS StatusCode,
               'Shift inserted successfully.' AS Message;
    END

    -- UPDATE
    ELSE IF (@Mode = 2)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM dbo.M_Shift
            WHERE ShiftID = @ShiftID
              AND IsActive = 1
        )
        BEGIN
            UPDATE dbo.M_Shift
            SET
                ShiftName = @ShiftName,
                ShiftCode = @ShiftCode,
                StartTime = @StartTime,
                EndTime = @EndTime,
                GraceMinutes = @GraceMinutes,
                IsNightShift = @IsNightShift
            WHERE ShiftID = @ShiftID;

            SELECT 200 AS StatusCode,
                   'Shift updated successfully.' AS Message;
        END
        ELSE
        BEGIN
            SELECT 404 AS StatusCode,
                   'Shift not found.' AS Message;
        END
    END

    -- SOFT DELETE
    ELSE IF (@Mode = 3)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM dbo.M_Shift
            WHERE ShiftID = @ShiftID
              AND IsActive = 1
        )
        BEGIN
            UPDATE dbo.M_Shift
            SET IsActive = 0
            WHERE ShiftID = @ShiftID;

            SELECT 200 AS StatusCode,
                   'Shift deleted successfully.' AS Message;
        END
        ELSE
        BEGIN
            SELECT 404 AS StatusCode,
                   'Shift not found.' AS Message;
        END
    END

    -- INVALID MODE
    ELSE
    BEGIN
        SELECT 400 AS StatusCode,
               'Invalid Mode.' AS Message;
    END
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_InsertUpdateDeleteTask]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_InsertUpdateDeleteTask]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_InsertUpdateDeleteTask];
GO

CREATE   PROCEDURE dbo.Procs_InsertUpdateDeleteTask
    @TaskID INT,
    @EmployeeID INT,
    @AssignedBy INT,
    @TaskTitle NVARCHAR(200),
    @TaskDescription NVARCHAR(MAX) = NULL,
    @Priority NVARCHAR(20),
    @Status NVARCHAR(20),
    @StartDate DATE = NULL,
    @DueDate DATE,
    @CompletedDate DATE = NULL,
    @Mode INT
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------
    -- INSERT
    --------------------------------------------------
    IF (@Mode = 1)
    BEGIN

        -- Employee validation
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Employee
            WHERE EmployeeID = @EmployeeID
              AND IsActive = 1
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Employee not found or inactive.' AS Message;
            RETURN;
        END;


        -- Assigned By validation
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Employee
            WHERE EmployeeID = @AssignedBy
              AND IsActive = 1
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Assigned By employee not found or inactive.' AS Message;
            RETURN;
        END;


        -- Date validation
        IF (@StartDate IS NOT NULL AND @StartDate > @DueDate)
        BEGIN
            SELECT
                400 AS StatusCode,
                'StartDate cannot be greater than DueDate.' AS Message;
            RETURN;
        END;


        INSERT INTO dbo.T_Task
        (
            EmployeeID,
            AssignedBy,
            TaskTitle,
            TaskDescription,
            Priority,
            Status,
            StartDate,
            DueDate,
            CompletedDate,
            CreatedAt
        )
        VALUES
        (
            @EmployeeID,
            @AssignedBy,
            @TaskTitle,
            @TaskDescription,
            @Priority,
            @Status,
            @StartDate,
            @DueDate,
            @CompletedDate,
            SYSDATETIME()
        );


        SELECT
            200 AS StatusCode,
            'Task inserted successfully.' AS Message,
            SCOPE_IDENTITY() AS TaskID;

        RETURN;
    END;


    --------------------------------------------------
    -- UPDATE
    --------------------------------------------------
    IF (@Mode = 2)
    BEGIN

        -- Task validation
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Task
            WHERE TaskID = @TaskID
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Task not found.' AS Message;
            RETURN;
        END;


        -- Employee validation
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Employee
            WHERE EmployeeID = @EmployeeID
              AND IsActive = 1
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Employee not found or inactive.' AS Message;
            RETURN;
        END;


        -- Assigned By validation
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Employee
            WHERE EmployeeID = @AssignedBy
              AND IsActive = 1
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Assigned By employee not found or inactive.' AS Message;
            RETURN;
        END;


        -- Date validation
        IF (@StartDate IS NOT NULL AND @StartDate > @DueDate)
        BEGIN
            SELECT
                400 AS StatusCode,
                'StartDate cannot be greater than DueDate.' AS Message;
            RETURN;
        END;


        UPDATE dbo.T_Task
        SET
            EmployeeID = @EmployeeID,
            AssignedBy = @AssignedBy,
            TaskTitle = @TaskTitle,
            TaskDescription = @TaskDescription,
            Priority = @Priority,
            Status = @Status,
            StartDate = @StartDate,
            DueDate = @DueDate,
            CompletedDate = @CompletedDate
        WHERE TaskID = @TaskID;


        SELECT
            200 AS StatusCode,
            'Task updated successfully.' AS Message;

        RETURN;
    END;


    --------------------------------------------------
    -- DELETE
    --------------------------------------------------
    IF (@Mode = 3)
    BEGIN

        -- Task validation
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Task
            WHERE TaskID = @TaskID
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Task not found.' AS Message;
            RETURN;
        END;


        DELETE FROM dbo.T_Task
        WHERE TaskID = @TaskID;


        SELECT
            200 AS StatusCode,
            'Task deleted successfully.' AS Message;

        RETURN;
    END;


    --------------------------------------------------
    -- INVALID MODE
    --------------------------------------------------
    SELECT
        400 AS StatusCode,
        'Invalid Mode. Use 1 for Insert, 2 for Update, 3 for Delete.'
        AS Message;

END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_InsertUpdateDeleteUsers]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_InsertUpdateDeleteUsers]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_InsertUpdateDeleteUsers];
GO

CREATE   PROCEDURE [dbo].[Procs_InsertUpdateDeleteUsers]
    @UserID INT = NULL,
    @EmployeeID INT = NULL,
    @RoleID INT = NULL,
    @PasswordHash NVARCHAR(100) = NULL,
    @PasswordSalt NVARCHAR(128) = NULL,
    @LastLogin DATETIME2(7) = NULL,
    @UserName NVARCHAR(100) = NULL,
    @MobileNo NVARCHAR(20) = NULL,
    @Email NVARCHAR(200) = NULL,
    @Mode INT
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------
    -- INSERT
    --------------------------------------------------
    IF (@Mode = 1)
    BEGIN

        -- Required fields
        IF @EmployeeID IS NULL OR @RoleID IS NULL
        BEGIN
            SELECT
                400 AS StatusCode,
                'Employee and Role are required.' AS Message;

            RETURN;
        END;


        -- Username required
        IF NULLIF(LTRIM(RTRIM(@UserName)), '') IS NULL
        BEGIN
            SELECT
                400 AS StatusCode,
                'Username is required.' AS Message;

            RETURN;
        END;


        -- Password required
        IF NULLIF(LTRIM(RTRIM(@PasswordHash)), '') IS NULL
        BEGIN
            SELECT
                400 AS StatusCode,
                'Password is required.' AS Message;

            RETURN;
        END;


        -- Employee validation
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Employee
            WHERE EmployeeID = @EmployeeID
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Employee not found.' AS Message;

            RETURN;
        END;


        -- Role validation
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.M_Role
            WHERE RoleID = @RoleID
              AND IsActive = 1
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Role not found or inactive.' AS Message;

            RETURN;
        END;


        -- Prevent duplicate username
        IF EXISTS
        (
            SELECT 1
            FROM dbo.T_Users
            WHERE UserName = @UserName
        )
        BEGIN
            SELECT
                409 AS StatusCode,
                'Username already exists.' AS Message;

            RETURN;
        END;


        -- Prevent multiple active accounts for same employee
        IF EXISTS
        (
            SELECT 1
            FROM dbo.T_Users
            WHERE EmployeeID = @EmployeeID
              AND IsActive = 1
        )
        BEGIN
            SELECT
                409 AS StatusCode,
                'An active user account already exists for this employee.' AS Message;

            RETURN;
        END;


        INSERT INTO dbo.T_Users
        (
            EmployeeID,
            RoleID,
            UserName,
            PasswordHash,
            PasswordSalt,
            MobileNo,
            Email,
            LastLogin,
            WrongCount,
            IsActive,
            CreatedAt
        )
        VALUES
        (
            @EmployeeID,
            @RoleID,
            LTRIM(RTRIM(@UserName)),
            @PasswordHash,
            @PasswordSalt,
            NULLIF(LTRIM(RTRIM(@MobileNo)), ''),
            NULLIF(LTRIM(RTRIM(@Email)), ''),
            @LastLogin,
            0,
            1,
            SYSDATETIME()
        );


        SELECT
            200 AS StatusCode,
            'User inserted successfully.' AS Message;

        RETURN;
    END


    --------------------------------------------------
    -- UPDATE
    --------------------------------------------------
    ELSE IF (@Mode = 2)
    BEGIN

        IF @UserID IS NULL
        BEGIN
            SELECT
                400 AS StatusCode,
                'UserID is required for update.' AS Message;

            RETURN;
        END;


        -- User validation
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Users
            WHERE UserID = @UserID
              AND IsActive = 1
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'User not found or inactive.' AS Message;

            RETURN;
        END;


        -- Required fields
        IF @EmployeeID IS NULL OR @RoleID IS NULL
        BEGIN
            SELECT
                400 AS StatusCode,
                'Employee and Role are required.' AS Message;

            RETURN;
        END;


        IF NULLIF(LTRIM(RTRIM(@UserName)), '') IS NULL
        BEGIN
            SELECT
                400 AS StatusCode,
                'Username is required.' AS Message;

            RETURN;
        END;


        -- Employee validation
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Employee
            WHERE EmployeeID = @EmployeeID
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Employee not found.' AS Message;

            RETURN;
        END;


        -- Role validation
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.M_Role
            WHERE RoleID = @RoleID
              AND IsActive = 1
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Role not found or inactive.' AS Message;

            RETURN;
        END;


        -- Username already used by another user
        IF EXISTS
        (
            SELECT 1
            FROM dbo.T_Users
            WHERE UserName = @UserName
              AND UserID <> @UserID
        )
        BEGIN
            SELECT
                409 AS StatusCode,
                'Username already exists.' AS Message;

            RETURN;
        END;


        -- Prevent another active account for same employee
        IF EXISTS
        (
            SELECT 1
            FROM dbo.T_Users
            WHERE EmployeeID = @EmployeeID
              AND UserID <> @UserID
              AND IsActive = 1
        )
        BEGIN
            SELECT
                409 AS StatusCode,
                'Another active user account already exists for this employee.' AS Message;

            RETURN;
        END;


        --------------------------------------------------
        -- UPDATE
        -- Password is updated only when supplied.
        -- Existing password remains unchanged when NULL/empty.
        --------------------------------------------------

        UPDATE dbo.T_Users
        SET
            EmployeeID = @EmployeeID,
            RoleID = @RoleID,
            UserName = LTRIM(RTRIM(@UserName)),
            MobileNo = NULLIF(LTRIM(RTRIM(@MobileNo)), ''),
            Email = NULLIF(LTRIM(RTRIM(@Email)), ''),
            LastLogin = @LastLogin,

            PasswordHash =
                CASE
                    WHEN NULLIF(LTRIM(RTRIM(@PasswordHash)), '') IS NULL
                        THEN PasswordHash
                    ELSE @PasswordHash
                END,

            PasswordSalt =
                CASE
                    WHEN NULLIF(LTRIM(RTRIM(@PasswordHash)), '') IS NULL
                        THEN PasswordSalt
                    ELSE @PasswordSalt
                END

        WHERE UserID = @UserID;


        SELECT
            200 AS StatusCode,
            'User updated successfully.' AS Message;

        RETURN;
    END


    --------------------------------------------------
    -- DELETE / SOFT DELETE
    --------------------------------------------------
    ELSE IF (@Mode = 3)
    BEGIN

        IF @UserID IS NULL
        BEGIN
            SELECT
                400 AS StatusCode,
                'UserID is required for delete.' AS Message;

            RETURN;
        END;


        IF EXISTS
        (
            SELECT 1
            FROM dbo.T_Users
            WHERE UserID = @UserID
              AND IsActive = 1
        )
        BEGIN

            UPDATE dbo.T_Users
            SET
                IsActive = 0
            WHERE UserID = @UserID;


            SELECT
                200 AS StatusCode,
                'User deleted successfully.' AS Message;

            RETURN;
        END
        ELSE
        BEGIN

            SELECT
                404 AS StatusCode,
                'User not found or already inactive.' AS Message;

            RETURN;
        END

    END


    --------------------------------------------------
    -- INVALID MODE
    --------------------------------------------------
    ELSE
    BEGIN

        SELECT
            400 AS StatusCode,
            'Invalid Mode. Use 1 for Insert, 2 for Update, 3 for Delete.'
            AS Message;

        RETURN;

    END

END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_LoginUser]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_LoginUser]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_LoginUser];
GO

CREATE PROCEDURE [dbo].[Procs_LoginUser]
    @UserName NVARCHAR(100),
    @PasswordHash NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserID INT;

    SELECT @UserID = UserID
    FROM dbo.T_Users
    WHERE UserName = @UserName
      AND PasswordHash = @PasswordHash
      AND IsActive = 1;

    IF @UserID IS NULL
    BEGIN
        SELECT
            401 AS StatusCode,
            'Invalid username or password.' AS Message;
        RETURN;
    END;

    UPDATE dbo.T_Users
    SET LastLogin = SYSDATETIME()
    WHERE UserID = @UserID;

    SELECT
        200 AS StatusCode,
        'Login successful.' AS Message,
        U.UserID,
        U.EmployeeID,
        U.RoleID,
        U.UserName,
        U.Email,
        U.MobileNo,
        U.LastLogin,
        R.RoleName,
        E.EmployeeCode,
        E.FirstName,
        E.LastName,
        E.Email AS EmployeeEmail,
        E.PhoneNumber,
        E.DepartmentID,
        E.DesignationID,
        E.OfficeLocationID,
        E.ManagerID,
        E.ShiftID,
        U.MustChangePassword
    FROM dbo.T_Users U
    LEFT JOIN dbo.M_Role R
        ON R.RoleID = U.RoleID
    LEFT JOIN dbo.T_Employee E
        ON E.EmployeeID = U.EmployeeID
    WHERE U.UserID = @UserID;
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_NextEmployeeCode]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_NextEmployeeCode]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_NextEmployeeCode];
GO

CREATE   PROCEDURE dbo.Procs_NextEmployeeCode
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CONCAT('EMP', RIGHT(CONCAT('000000', CONVERT(varchar(12), NEXT VALUE FOR dbo.EmployeeCodeSequence)), 6)) AS EmployeeCode;
END;
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_SetInitialPassword]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_SetInitialPassword]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_SetInitialPassword];
GO

CREATE   PROCEDURE dbo.Procs_SetInitialPassword
    @UserID int,
    @Password nvarchar(200)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Salt nvarchar(32) = LEFT(REPLACE(CONVERT(varchar(36), NEWID()),'-',''),32);
    IF NOT EXISTS (SELECT 1 FROM dbo.T_Users WHERE UserID=@UserID AND IsActive=1)
    BEGIN SELECT 404 StatusCode, 'User not found or inactive.' Message; RETURN; END;
    UPDATE dbo.T_Users SET PasswordHash=CONVERT(varchar(100), HASHBYTES('SHA2_256', CONVERT(varbinary(max), @Password + @Salt)), 2), PasswordSalt=@Salt, MustChangePassword=1, PasswordChangedAt=NULL WHERE UserID=@UserID;
    SELECT 200 StatusCode, 'Initial password set successfully.' Message;
END
GO

-- ===============================================================================
-- Stored Procedure: [dbo].[Procs_UpdatePayrollPaymentStatus]
-- ===============================================================================
IF OBJECT_ID(N'[dbo].[Procs_UpdatePayrollPaymentStatus]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Procs_UpdatePayrollPaymentStatus];
GO

CREATE   PROCEDURE dbo.Procs_UpdatePayrollPaymentStatus
    @PayrollID INT,
    @PaymentStatus NVARCHAR(20),
    @PaymentDate DATE = NULL,
    @Remarks NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY

        --------------------------------------------------
        -- PAYROLL VALIDATION
        --------------------------------------------------
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.T_Payroll
            WHERE PayrollID = @PayrollID
        )
        BEGIN
            SELECT
                404 AS StatusCode,
                'Payroll not found.' AS Message;
            RETURN;
        END;


        --------------------------------------------------
        -- STATUS VALIDATION
        --------------------------------------------------
        IF @PaymentStatus NOT IN
        (
            'Pending',
            'Processing',
            'Paid',
            'Failed'
        )
        BEGIN
            SELECT
                400 AS StatusCode,
                'Invalid payment status. Allowed values: Pending, Processing, Paid, Failed.'
                AS Message;
            RETURN;
        END;


        --------------------------------------------------
        -- PAID DATE VALIDATION
        --------------------------------------------------
        IF @PaymentStatus = 'Paid'
           AND @PaymentDate IS NULL
        BEGIN
            SET @PaymentDate = CAST(GETDATE() AS DATE);
        END;


        --------------------------------------------------
        -- NON-PAID STATUS
        --------------------------------------------------
        IF @PaymentStatus <> 'Paid'
        BEGIN
            SET @PaymentDate = NULL;
        END;


        --------------------------------------------------
        -- UPDATE PAYROLL PAYMENT STATUS
        --------------------------------------------------
        UPDATE dbo.T_Payroll
        SET
            PaymentStatus = @PaymentStatus,
            PaymentDate = @PaymentDate,
            Remarks =
                CASE
                    WHEN @Remarks IS NULL THEN Remarks
                    ELSE @Remarks
                END
        WHERE PayrollID = @PayrollID;


        --------------------------------------------------
        -- SUCCESS RESPONSE
        --------------------------------------------------
        SELECT
            200 AS StatusCode,
            'Payroll payment status updated successfully.' AS Message,
            PayrollID,
            EmployeeID,
            PayrollMonth,
            PayrollYear,
            NetSalary,
            PaymentStatus,
            PaymentDate,
            Remarks
        FROM dbo.T_Payroll
        WHERE PayrollID = @PayrollID;

    END TRY

    BEGIN CATCH

        SELECT
            500 AS StatusCode,
            ERROR_MESSAGE() AS Message;

    END CATCH
END
GO

