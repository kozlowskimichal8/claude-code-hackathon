-- ============================================================
-- Order Stored Procedures (8 procs)
-- ============================================================
USE NorthwindLogistics
GO

-- ============================================================
-- 6. usp_CreateOrder
-- Creates a new order and calculates initial cost estimate.
-- BUG: No transaction around the insert + cost calculation.
--      If usp_CalculateOrderCost fails, order exists but TotalCost=NULL.
--      This has happened. Finance finds orphan orders monthly.
-- ============================================================
CREATE PROCEDURE usp_CreateOrder
    @CustomerID         int,
    @RequiredDate       datetime        = NULL,
    @PickupAddress      varchar(200)    = NULL,
    @PickupCity         varchar(50)     = NULL,
    @PickupState        char(2)         = NULL,
    @PickupZip          varchar(10)     = NULL,
    @DeliveryAddress    varchar(200)    = NULL,
    @DeliveryCity       varchar(50)     = NULL,
    @DeliveryState      char(2)         = NULL,
    @DeliveryZip        varchar(10)     = NULL,
    @TotalWeight        decimal(10,2)   = NULL,
    @SpecialInstructions varchar(500)   = NULL,
    @Priority           char(1)         = 'N',
    @EstimatedMiles     int             = NULL,
    @IsHazmat           bit             = 0,
    @CreatedBy          varchar(50)     = NULL,
    @NewOrderID         int             OUTPUT
AS
SET NOCOUNT ON

-- Credit check
DECLARE @creditLimit money, @currentBalance money, @customerType char(1)
SELECT @creditLimit = CreditLimit, @currentBalance = CurrentBalance,
       @customerType = CustomerType
FROM Customers
WHERE CustomerID = @CustomerID AND IsActive = 1

IF @creditLimit IS NULL
BEGIN
    RAISERROR('Customer %d not found or inactive', 16, 1, @CustomerID)
    SET @NewOrderID = -1
    RETURN -1
END

-- Rough cost estimate for credit check (re-calculated properly after insert)
DECLARE @estimatedCost money
SET @estimatedCost = ISNULL(@TotalWeight, 0) * 0.5 + ISNULL(@EstimatedMiles, 50) * 0.75

IF (@currentBalance + @estimatedCost) > @creditLimit
    AND @customerType NOT IN ('C', 'G')  -- contract/govt exempt from check
BEGIN
    RAISERROR('Credit limit would be exceeded. Current balance: $%.2f, Limit: $%.2f',
              16, 1, @currentBalance, @creditLimit)
    SET @NewOrderID = -1
    RETURN -1
END

-- Insert order
INSERT INTO Orders (
    CustomerID, OrderDate, RequiredDate, Status,
    PickupAddress, PickupCity, PickupState, PickupZip,
    DeliveryAddress, DeliveryCity, DeliveryState, DeliveryZip,
    TotalWeight, SpecialInstructions, Priority, EstimatedMiles,
    IsHazmat, IsBilled, DiscountPct, CreatedBy
)
VALUES (
    @CustomerID, GETDATE(), @RequiredDate, 'Pending',
    @PickupAddress, @PickupCity, @PickupState, @PickupZip,
    @DeliveryAddress, @DeliveryCity, @DeliveryState, @DeliveryZip,
    @TotalWeight, @SpecialInstructions, @Priority, @EstimatedMiles,
    @IsHazmat, 0, 0.00, @CreatedBy
)

SET @NewOrderID = SCOPE_IDENTITY()

-- Calculate and update cost (separate call, not in transaction)
DECLARE @calcResult int
EXEC @calcResult = usp_CalculateOrderCost @NewOrderID

IF @calcResult <> 0
BEGIN
    -- Order is created but cost is NULL. Log it and continue.
    -- Don't fail the whole order creation.
    INSERT INTO AuditLog (TableName, RecordID, Action, NewValues, ChangedBy, ChangedDate)
    VALUES ('Orders', @NewOrderID, 'WARN',
            'Cost calculation failed after order creation',
            ISNULL(@CreatedBy, 'system'), GETDATE())
END

RETURN 0
GO

-- ============================================================
-- 7. usp_GetOrder
-- Returns full order detail including items and shipment.
-- Returns 3 result sets: order header, items, shipment(s).
-- App code depends on result set ORDER. Don't reorder queries.
-- ============================================================
CREATE PROCEDURE usp_GetOrder
    @OrderID int
AS
-- Result set 1: order header (+ customer info joined in)
SELECT
    o.*,
    c.CompanyName,
    c.ContactName,
    c.Phone        AS CustomerPhone,
    c.CustomerType
FROM Orders o
INNER JOIN Customers c ON o.CustomerID = c.CustomerID
WHERE o.OrderID = @OrderID

-- Result set 2: order items
SELECT * FROM OrderItems WHERE OrderID = @OrderID ORDER BY ItemID

-- Result set 3: shipment and driver info
SELECT
    s.*,
    d.FirstName + ' ' + d.LastName  AS DriverName,
    d.CellPhone                     AS DriverPhone,
    v.LicensePlate,
    v.Make + ' ' + v.Model          AS VehicleDesc
FROM Shipments s
INNER JOIN Drivers d  ON s.DriverID  = d.DriverID
INNER JOIN Vehicles v ON s.VehicleID = v.VehicleID
WHERE s.OrderID = @OrderID
ORDER BY s.ShipmentID DESC
GO

-- ============================================================
-- 8. usp_UpdateOrderStatus
-- God proc. Handles every status transition, each with its own
-- logic. Was supposed to be split into separate procs in 2016.
-- Still here. 280 lines of CASE statements.
-- ============================================================
CREATE PROCEDURE usp_UpdateOrderStatus
    @OrderID        int,
    @NewStatus      varchar(20),
    @ChangedBy      varchar(50) = NULL,
    @Notes          varchar(500) = NULL
AS
SET NOCOUNT ON
BEGIN TRY
    BEGIN TRANSACTION

    DECLARE @currentStatus varchar(20), @customerID int
    SELECT @currentStatus = Status, @customerID = CustomerID
    FROM Orders
    WHERE OrderID = @OrderID

    IF @currentStatus IS NULL
    BEGIN
        RAISERROR('Order %d not found', 16, 1, @OrderID)
        ROLLBACK
        RETURN -1
    END

    -- Validate state transitions (incomplete - missing some edges)
    DECLARE @valid bit = 0

    IF @currentStatus = 'Pending'   AND @NewStatus IN ('Assigned', 'Cancelled', 'OnHold') SET @valid = 1
    IF @currentStatus = 'Assigned'  AND @NewStatus IN ('PickedUp', 'Cancelled', 'OnHold') SET @valid = 1
    IF @currentStatus = 'PickedUp'  AND @NewStatus IN ('InTransit', 'Failed')              SET @valid = 1
    IF @currentStatus = 'InTransit' AND @NewStatus IN ('Delivered', 'Failed')              SET @valid = 1
    IF @currentStatus = 'Failed'    AND @NewStatus IN ('Pending', 'Cancelled')             SET @valid = 1
    IF @currentStatus = 'OnHold'    AND @NewStatus IN ('Pending', 'Cancelled')             SET @valid = 1
    -- Missing: can't go from Delivered to anything (but app sometimes tries)

    IF @valid = 0
    BEGIN
        RAISERROR('Invalid status transition from %s to %s for order %d',
                  16, 1, @currentStatus, @NewStatus, @OrderID)
        ROLLBACK
        RETURN -1
    END

    UPDATE Orders SET Status = @NewStatus WHERE OrderID = @OrderID

    -- Status-specific actions
    IF @NewStatus = 'Cancelled'
    BEGIN
        UPDATE Orders SET ShippedDate = NULL WHERE OrderID = @OrderID

        -- Cancel any active shipment
        UPDATE Shipments SET Status = 'Cancelled'
        WHERE OrderID = @OrderID AND Status IN ('Assigned', 'PickedUp')

        -- NOTE: This triggers TR_Shipments_AutoUpdateOrderStatus which will
        --       try to set Order status to 'Cancelled' again. Idempotent but wasteful.

        -- Release driver/vehicle
        UPDATE Drivers SET Status = 'Available'
        WHERE DriverID IN (
            SELECT DriverID FROM Shipments WHERE OrderID = @OrderID
        )
        UPDATE Vehicles SET Status = 'Available'
        WHERE VehicleID IN (
            SELECT VehicleID FROM Shipments WHERE OrderID = @OrderID
        )
    END

    IF @NewStatus = 'Delivered'
    BEGIN
        UPDATE Orders SET ShippedDate = GETDATE() WHERE OrderID = @OrderID

        -- Auto-create invoice if not already billed
        -- (calling billing proc from here - tight coupling)
        IF NOT EXISTS (SELECT 1 FROM Invoices WHERE OrderID = @OrderID)
        BEGIN
            DECLARE @newInvoiceID int
            EXEC usp_CreateInvoice @OrderID, @ChangedBy, @newInvoiceID OUTPUT
        END

        -- Release driver and vehicle
        UPDATE Drivers SET Status = 'Available'
        WHERE DriverID IN (
            SELECT DriverID FROM Shipments
            WHERE OrderID = @OrderID AND Status = 'InTransit'
        )
        UPDATE Vehicles SET Status = 'Available'
        WHERE VehicleID IN (
            SELECT VehicleID FROM Shipments
            WHERE OrderID = @OrderID AND Status = 'InTransit'
        )

        UPDATE Shipments
        SET Status = 'Delivered', ActualDeliveryTime = GETDATE(), EndTime = GETDATE()
        WHERE OrderID = @OrderID AND Status IN ('InTransit', 'PickedUp')
    END

    IF @NewStatus = 'Failed'
    BEGIN
        UPDATE Shipments
        SET Status = 'Failed', FailureReason = @Notes, EndTime = GETDATE()
        WHERE OrderID = @OrderID AND Status IN ('InTransit', 'PickedUp')

        -- Release driver/vehicle even on failure
        UPDATE Drivers SET Status = 'Available'
        WHERE DriverID IN (SELECT DriverID FROM Shipments WHERE OrderID = @OrderID)
        UPDATE Vehicles SET Status = 'Available'
        WHERE VehicleID IN (SELECT VehicleID FROM Shipments WHERE OrderID = @OrderID)
    END

    IF @NewStatus = 'PickedUp'
    BEGIN
        UPDATE Shipments
        SET Status = 'PickedUp', ActualPickupTime = GETDATE()
        WHERE OrderID = @OrderID AND Status = 'Assigned'
    END

    IF @NewStatus = 'InTransit'
    BEGIN
        UPDATE Shipments
        SET Status = 'InTransit', StartTime = COALESCE(StartTime, GETDATE())
        WHERE OrderID = @OrderID AND Status = 'PickedUp'
    END

    IF @Notes IS NOT NULL
        UPDATE Orders SET SpecialInstructions =
            ISNULL(SpecialInstructions, '') + ' | ' + CONVERT(varchar, GETDATE(), 120) + ': ' + @Notes
        WHERE OrderID = @OrderID

    COMMIT
    RETURN 0

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK
    DECLARE @msg varchar(500)
    SET @msg = ERROR_MESSAGE()
    RAISERROR('usp_UpdateOrderStatus failed: %s', 16, 1, @msg)
    RETURN -1
END CATCH
GO

-- ============================================================
-- 9. usp_CancelOrder
-- Thin wrapper around usp_UpdateOrderStatus.
-- Exists because the UI has a "Cancel" button that was wired
-- directly to this proc before UpdateOrderStatus was generic.
-- Now just calls it. Left for backwards compatibility.
-- ============================================================
CREATE PROCEDURE usp_CancelOrder
    @OrderID    int,
    @Reason     varchar(500) = NULL,
    @CancelledBy varchar(50) = NULL
AS
    EXEC usp_UpdateOrderStatus @OrderID, 'Cancelled', @CancelledBy, @Reason
GO

-- ============================================================
-- 10. usp_SearchOrders
-- Dynamic SQL search. Same injection risk as usp_SearchCustomers.
-- @SortBy accepts column names directly from the UI.
-- ============================================================
CREATE PROCEDURE usp_SearchOrders
    @CustomerID     int         = NULL,
    @Status         varchar(20) = NULL,
    @DateFrom       datetime    = NULL,
    @DateTo         datetime    = NULL,
    @DriverID       int         = NULL,
    @SortBy         varchar(50) = 'OrderDate',
    @SortDir        varchar(4)  = 'DESC',
    @MaxRows        int         = 500   -- nobody ever changed this default
AS
SET NOCOUNT ON

DECLARE @sql nvarchar(4000)
DECLARE @params nvarchar(500)

SET @sql = '
SELECT TOP ' + CAST(@MaxRows AS varchar) + '
    o.OrderID, o.CustomerID, c.CompanyName, o.OrderDate, o.RequiredDate,
    o.Status, o.TotalWeight, o.TotalCost, o.IsBilled, o.Priority,
    o.DeliveryCity, o.DeliveryState,
    d.FirstName + '' '' + d.LastName AS DriverName
FROM Orders o
INNER JOIN Customers c ON o.CustomerID = c.CustomerID
LEFT JOIN Shipments s ON o.OrderID = s.OrderID
LEFT JOIN Drivers d ON s.DriverID = d.DriverID
WHERE 1=1 '

IF @CustomerID IS NOT NULL
    SET @sql = @sql + ' AND o.CustomerID = ' + CAST(@CustomerID AS varchar) + ' '
IF @Status IS NOT NULL
    SET @sql = @sql + ' AND o.Status = ''' + @Status + ''' '
IF @DateFrom IS NOT NULL
    SET @sql = @sql + ' AND o.OrderDate >= ''' + CONVERT(varchar, @DateFrom, 120) + ''' '
IF @DateTo IS NOT NULL
    SET @sql = @sql + ' AND o.OrderDate <= ''' + CONVERT(varchar, @DateTo, 120) + ''' '
IF @DriverID IS NOT NULL
    SET @sql = @sql + ' AND s.DriverID = ' + CAST(@DriverID AS varchar) + ' '

SET @sql = @sql + ' ORDER BY ' + @SortBy + ' ' + @SortDir

EXEC(@sql)
GO

-- ============================================================
-- 11. usp_GetPendingOrders
-- Returns unassigned orders sorted by priority then date.
-- Non-sargable WHERE: CONVERT on OrderDate prevents index use.
-- "Worked fine until we had >10k orders" - helpdesk ticket 2019
-- ============================================================
CREATE PROCEDURE usp_GetPendingOrders
    @HoursOld int = 48   -- orders pending for longer than this are flagged
AS
SET NOCOUNT ON

SELECT
    o.OrderID,
    o.OrderDate,
    c.CompanyName,
    c.Phone         AS CustomerPhone,
    o.PickupCity,
    o.PickupState,
    o.DeliveryCity,
    o.DeliveryState,
    o.TotalWeight,
    o.Priority,
    o.TotalCost,
    DATEDIFF(hour, o.OrderDate, GETDATE()) AS HoursPending,
    CASE WHEN DATEDIFF(hour, o.OrderDate, GETDATE()) > @HoursOld
         THEN 1 ELSE 0 END                 AS IsOverdue
FROM Orders o
INNER JOIN Customers c ON o.CustomerID = c.CustomerID
-- Non-sargable: CONVERT prevents IX_Orders_Status from being used
WHERE CONVERT(varchar(20), o.Status) = 'Pending'
ORDER BY
    CASE o.Priority WHEN 'U' THEN 1 WHEN 'H' THEN 2 ELSE 3 END,
    o.OrderDate ASC
GO

-- ============================================================
-- 12. usp_AssignOrderToDriver
-- Assigns a driver and vehicle to an order, creates shipment.
-- Calls usp_UpdateOrderStatus which also touches Shipments.
-- Then the trigger on Shipments fires back to Orders.
-- Circular? Yes. It converges, but add logging and it's chaos.
-- ============================================================
CREATE PROCEDURE usp_AssignOrderToDriver
    @OrderID    int,
    @DriverID   int,
    @VehicleID  int,
    @AssignedBy varchar(50) = NULL
AS
SET NOCOUNT ON
BEGIN TRY
    BEGIN TRANSACTION

    -- Validate order is Pending
    DECLARE @status varchar(20)
    SELECT @status = Status FROM Orders WHERE OrderID = @OrderID
    IF @status <> 'Pending'
    BEGIN
        RAISERROR('Order %d is not in Pending status (current: %s)', 16, 1, @OrderID, @status)
        ROLLBACK; RETURN -1
    END

    -- Validate driver is available
    DECLARE @driverStatus varchar(20)
    SELECT @driverStatus = Status FROM Drivers WHERE DriverID = @DriverID
    IF @driverStatus NOT IN ('Available')
    -- NOTE: 'LOA' is not handled. Driver on LOA can be assigned. Known issue.
    BEGIN
        RAISERROR('Driver %d is not available (status: %s)', 16, 1, @DriverID, @driverStatus)
        ROLLBACK; RETURN -1
    END

    -- Validate vehicle is available
    DECLARE @vehicleStatus varchar(20), @vehicleMaxWeight decimal(10,2)
    SELECT @vehicleStatus = Status, @vehicleMaxWeight = MaxWeightLbs
    FROM Vehicles WHERE VehicleID = @VehicleID
    IF @vehicleStatus <> 'Available'
    BEGIN
        RAISERROR('Vehicle %d is not available (status: %s)', 16, 1, @VehicleID, @vehicleStatus)
        ROLLBACK; RETURN -1
    END

    -- Weight check (informational only - no hard block because
    -- "sometimes we overload a little" - ops manager 2015)
    DECLARE @orderWeight decimal(10,2)
    SELECT @orderWeight = TotalWeight FROM Orders WHERE OrderID = @OrderID
    IF ISNULL(@orderWeight, 0) > ISNULL(@vehicleMaxWeight, 99999)
    BEGIN
        -- Just log it, don't block
        INSERT INTO AuditLog (TableName, RecordID, Action, NewValues, ChangedBy)
        VALUES ('Orders', @OrderID, 'WARN',
                'Weight ' + CAST(@orderWeight AS varchar) + ' exceeds vehicle max ' +
                CAST(@vehicleMaxWeight AS varchar), ISNULL(@AssignedBy, 'system'))
    END

    -- Create shipment record
    INSERT INTO Shipments (OrderID, DriverID, VehicleID, AssignedDate, Status)
    VALUES (@OrderID, @DriverID, @VehicleID, GETDATE(), 'Assigned')

    -- Update driver and vehicle status
    UPDATE Drivers  SET Status = 'OnRoute'  WHERE DriverID  = @DriverID
    UPDATE Vehicles SET Status = 'InUse'    WHERE VehicleID = @VehicleID

    -- Update order status to Assigned
    -- Note: this calls usp_UpdateOrderStatus which may also touch Shipments again
    EXEC usp_UpdateOrderStatus @OrderID, 'Assigned', @AssignedBy

    COMMIT
    RETURN 0

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK
    DECLARE @msg varchar(500)
    SET @msg = ERROR_MESSAGE()
    RAISERROR('usp_AssignOrderToDriver failed: %s', 16, 1, @msg)
    RETURN -1
END CATCH
GO

-- ============================================================
-- 13. usp_GetOrdersByCustomer
-- Returns order summary list for customer portal page.
-- Cursor-based with per-row invoice lookup (N+1).
-- "Rewrote this in 2017 to use a CTE but it was slower on
--  SQL 2008 so we rolled back" - code comment that got deleted
-- ============================================================
CREATE PROCEDURE usp_GetOrdersByCustomer
    @CustomerID int,
    @StatusFilter varchar(20) = NULL,
    @PageSize   int = 50,
    @PageNum    int = 1
AS
SET NOCOUNT ON

-- Pagination done in a temp table (no ROW_NUMBER because
-- the developer didn't know about it in 2010)
CREATE TABLE #PagedOrders (
    RowNum      int IDENTITY(1,1),
    OrderID     int,
    OrderDate   datetime,
    Status      varchar(20),
    TotalCost   money,
    DeliveryCity varchar(50),
    InvoiceID   int,
    InvoiceStatus varchar(20)
)

DECLARE @oid int, @odate datetime, @ostatus varchar(20),
        @ocost money, @dcity varchar(50)
DECLARE @invID int, @invStatus varchar(20)

DECLARE paged_cursor CURSOR FOR
    SELECT OrderID, OrderDate, Status, TotalCost, DeliveryCity
    FROM Orders
    WHERE CustomerID = @CustomerID
      AND (@StatusFilter IS NULL OR Status = @StatusFilter)
    ORDER BY OrderDate DESC

OPEN paged_cursor
FETCH NEXT FROM paged_cursor INTO @oid, @odate, @ostatus, @ocost, @dcity

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Lookup invoice per order
    SELECT TOP 1 @invID = InvoiceID, @invStatus = Status
    FROM Invoices WHERE OrderID = @oid ORDER BY InvoiceID DESC

    INSERT INTO #PagedOrders (OrderID, OrderDate, Status, TotalCost,
                               DeliveryCity, InvoiceID, InvoiceStatus)
    VALUES (@oid, @odate, @ostatus, @ocost, @dcity, @invID, @invStatus)

    SET @invID = NULL; SET @invStatus = NULL  -- reset for next iter

    FETCH NEXT FROM paged_cursor INTO @oid, @odate, @ostatus, @ocost, @dcity
END

CLOSE paged_cursor
DEALLOCATE paged_cursor

DECLARE @startRow int = (@PageNum - 1) * @PageSize + 1
DECLARE @endRow int   = @PageNum * @PageSize

SELECT * FROM #PagedOrders
WHERE RowNum BETWEEN @startRow AND @endRow
ORDER BY RowNum

SELECT COUNT(*) AS TotalRows FROM #PagedOrders

DROP TABLE #PagedOrders
GO
