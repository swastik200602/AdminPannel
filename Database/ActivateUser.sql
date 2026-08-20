USE [EmployeeManagementDB]
GO

/* Keeps the existing user CRUD procedure unchanged and adds activation separately. */
CREATE OR ALTER PROCEDURE [dbo].[Procs_ActivateUser]
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @UserID IS NULL
    BEGIN
        SELECT 400 AS StatusCode, 'UserID is required for activation.' AS Message;
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.T_Users WHERE UserID = @UserID)
    BEGIN
        SELECT 404 AS StatusCode, 'User not found.' AS Message;
        RETURN;
    END;

    IF EXISTS (SELECT 1 FROM dbo.T_Users WHERE UserID = @UserID AND IsActive = 1)
    BEGIN
        SELECT 409 AS StatusCode, 'User account is already active.' AS Message;
        RETURN;
    END;

    UPDATE dbo.T_Users
    SET IsActive = 1, WrongCount = 0
    WHERE UserID = @UserID;

    SELECT 200 AS StatusCode, 'User activated successfully.' AS Message;
END
GO
