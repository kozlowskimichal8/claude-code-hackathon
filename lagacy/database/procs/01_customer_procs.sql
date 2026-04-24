-- ============================================================
-- Customer Stored Procedures (5 procs)
-- ============================================================
USE NorthwindLogistics
GO

-- ============================================================
-- 1. usp_GetCustomer
-- Returns customer by ID. Simple but uses SELECT *.
-- ============================================================
CREATE PROCEDURE usp_GetCustomer
    @CustomerID int
AS
    -- no SET NOCOUNT ON (causes extra resultsets, client code works around it)
    SELECT * FROM Customers WHERE CustomerID = @CustomerID
GO

-- ============================================================
-- 2. usp_SearchCustomers
-- WARNING: Dynamic SQL built by string concatenation.
-- SQL injection possible if caller doesn't sanitize @SearchTerm.
-- The web UI does sanitize. The internal admin tool does not.
-- R.Kowalski 2010: "only internal users, should be fine"
-- ============================================================
CREATE PROCEDURE usp_SearchCustomers
    @SearchTerm     varchar(200) = NULL,
    @CustomerType   char(1)      = NULL,
    @IsActive       bit          = NULL,
    @SortBy         varchar(50)  = 'CompanyName',   -- user-controlled! injection vector
    @SortDir        varchar(4)   = 'ASC'
AS
SET NOCOUNT ON

DECLARE @sql nvarchar(2000)
DECLARE @where nvarchar(1000)

SET @where = ' WHERE 1=1 '

IF @SearchTerm IS NOT NULL
    SET @where = @where + ' AND (CompanyName LIKE ''%' + @SearchTerm + '%'' '
                        + ' OR ContactName LIKE ''%' + @SearchTerm + '%'' '
                        + ' OR Phone LIKE ''%' + @SearchTerm + '%'') '

IF @CustomerType IS NOT NULL
    SET @where = @where + ' AND CustomerType = ''' + @CustomerType + ''' '

IF @IsActive IS NOT NULL
    SET @where = @where + ' AND IsActive = ' + CAST(@IsActive AS varchar(1)) + ' '

-- @SortBy and @SortDir go straight in - no validation
SET @sql = 'SELECT CustomerID, AccountNum, CompanyName, ContactName, City, State, '
         + '       Phone, Email, CustomerType, CurrentBalance, IsActive '
         + 'FROM Customers '
         + @where
         + 'ORDER BY ' + @SortBy + ' ' + @SortDir

EXEC sp_executesql @sql
GO

-- ============================================================
-- 3. usp_CreateCustomer
-- Inserts new customer. Error handling via @@ERROR (pre-2005 style).
-- Does NOT validate duplicate company names.
-- ============================================================
CREATE PROCEDURE usp_CreateCustomer
    @CompanyName    varchar(100),
    @ContactName    varchar(100)    = NULL,
    @Address        varchar(200)    = NULL,
    @City           varchar(50)     = NULL,
    @State          char(2)         = NULL,
    @ZipCode        varchar(10)     = NULL,
    @Phone          varchar(20)     = NULL,
    @Email          varchar(100)    = NULL,
    @CustomerType   char(1)         = 'R',
    @CreditLimit    money           = 5000.00,
    @SalesRepName   varchar(100)    = NULL,
    @NewCustomerID  int             OUTPUT
AS
    SET NOCOUNT ON

    -- Basic validation (minimal)
    IF @CompanyName IS NULL OR LEN(LTRIM(RTRIM(@CompanyName))) = 0
    BEGIN
        RAISERROR('CompanyName is required', 16, 1)
        SET @NewCustomerID = -1
        RETURN -1
    END

    IF @CustomerType NOT IN ('R', 'P', 'C', 'G')
    BEGIN
        -- silently default to R instead of erroring
        -- original comment: "don't break the UI for typos"
        SET @CustomerType = 'R'
    END

    INSERT INTO Customers (
        CompanyName, ContactName, Address, City, State, ZipCode,
        Phone, Email, CustomerType, CreditLimit, SalesRepName,
        CreatedDate, IsActive
    )
    VALUES (
        @CompanyName, @ContactName, @Address, @City, @State, @ZipCode,
        @Phone, @Email, @CustomerType, @CreditLimit, @SalesRepName,
        GETDATE(), 1
    )

    IF @@ERROR <> 0
    BEGIN
        SET @NewCustomerID = -1
        RETURN -1
    END

    SET @NewCustomerID = SCOPE_IDENTITY()
    RETURN 0
GO

-- ============================================================
-- 4. usp_UpdateCustomer
-- Updates customer fields. Only updates non-null parameters
-- (the "sparse update" pattern - means you can never set a
--  field TO null via this proc, which caused a support ticket
--  in 2019 that took 3 days to debug).
-- ============================================================
CREATE PROCEDURE usp_UpdateCustomer
    @CustomerID     int,
    @CompanyName    varchar(100)    = NULL,
    @ContactName    varchar(100)    = NULL,
    @Address        varchar(200)    = NULL,
    @City           varchar(50)     = NULL,
    @State          char(2)         = NULL,
    @ZipCode        varchar(10)     = NULL,
    @Phone          varchar(20)     = NULL,
    @Email          varchar(100)    = NULL,
    @CustomerType   char(1)         = NULL,
    @CreditLimit    money           = NULL,
    @IsActive       bit             = NULL,
    @Notes          text            = NULL
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM Customers WHERE CustomerID = @CustomerID)
BEGIN
    RAISERROR('Customer not found: %d', 16, 1, @CustomerID)
    RETURN -1
END

UPDATE Customers SET
    CompanyName     = COALESCE(@CompanyName,    CompanyName),
    ContactName     = COALESCE(@ContactName,    ContactName),
    Address         = COALESCE(@Address,        Address),
    City            = COALESCE(@City,           City),
    State           = COALESCE(@State,          State),
    ZipCode         = COALESCE(@ZipCode,        ZipCode),
    Phone           = COALESCE(@Phone,          Phone),
    Email           = COALESCE(@Email,          Email),
    CustomerType    = COALESCE(@CustomerType,   CustomerType),
    CreditLimit     = COALESCE(@CreditLimit,    CreditLimit),
    IsActive        = COALESCE(@IsActive,       IsActive),
    Notes           = COALESCE(@Notes,          Notes)
WHERE CustomerID = @CustomerID

-- No audit logging here. Intentional? Unknown. Maybe was added to trigger later.
RETURN 0
GO

-- ============================================================
-- 5. usp_GetCustomerOrders
-- Returns all orders for a customer with summary info.
-- Uses cursor instead of set-based aggregation because
-- "the cursor version was easier to debug" - 2012 comment
-- ============================================================
CREATE PROCEDURE usp_GetCustomerOrders
    @CustomerID         int,
    @IncludeCancelled   bit = 0,
    @DaysBack           int = 365
AS
SET NOCOUNT ON

-- Temp table to accumulate results
CREATE TABLE #CustomerOrders (
    OrderID         int,
    OrderDate       datetime,
    Status          varchar(20),
    TotalWeight     decimal(10,2),
    TotalCost       money,
    IsBilled        bit,
    ItemCount       int,
    DeliveryCity    varchar(50),
    DeliveryState   char(2),
    DriverName      varchar(100),
    ShipmentStatus  varchar(20)
)

DECLARE @orderID int, @orderDate datetime, @status varchar(20),
        @weight decimal(10,2), @cost money, @isBilled bit,
        @itemCount int, @delCity varchar(50), @delState char(2)

DECLARE ord_cursor CURSOR FOR
    SELECT OrderID, OrderDate, Status, TotalWeight, TotalCost, IsBilled,
           DeliveryCity, DeliveryState
    FROM Orders
    WHERE CustomerID = @CustomerID
      AND OrderDate >= DATEADD(day, -@DaysBack, GETDATE())
      AND (@IncludeCancelled = 1 OR Status <> 'Cancelled')
    ORDER BY OrderDate DESC

OPEN ord_cursor
FETCH NEXT FROM ord_cursor INTO @orderID, @orderDate, @status, @weight,
                                @cost, @isBilled, @delCity, @delState

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Count items (separate query per order - N+1)
    SELECT @itemCount = COUNT(*) FROM OrderItems WHERE OrderID = @orderID

    -- Get driver name from shipment (another query per order)
    DECLARE @driverName varchar(100), @shipStatus varchar(20)
    SELECT TOP 1
        @driverName = d.FirstName + ' ' + d.LastName,
        @shipStatus = s.Status
    FROM Shipments s
    INNER JOIN Drivers d ON s.DriverID = d.DriverID
    WHERE s.OrderID = @orderID

    INSERT INTO #CustomerOrders
    VALUES (@orderID, @orderDate, @status, @weight, @cost, @isBilled,
            @itemCount, @delCity, @delState, @driverName, @shipStatus)

    FETCH NEXT FROM ord_cursor INTO @orderID, @orderDate, @status, @weight,
                                    @cost, @isBilled, @delCity, @delState
END

CLOSE ord_cursor
DEALLOCATE ord_cursor

SELECT * FROM #CustomerOrders ORDER BY OrderDate DESC
DROP TABLE #CustomerOrders
GO
