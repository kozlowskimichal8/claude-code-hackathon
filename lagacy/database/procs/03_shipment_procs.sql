-- ============================================================
-- Shipment Stored Procedures (6 procs)
-- ============================================================
USE NorthwindLogistics
GO

-- ============================================================
-- 14. usp_CreateShipment
-- Low-level shipment creation. Usually called via
-- usp_AssignOrderToDriver, not directly.
-- Has nested transaction issue: if outer transaction exists,
-- the ROLLBACK here rolls back the outer too.
-- ============================================================
CREATE PROCEDURE usp_CreateShipment
    @OrderID    int,
    @DriverID   int,
    @VehicleID  int,
    @ShipmentID int OUTPUT
AS
SET NOCOUNT ON

BEGIN TRANSACTION  -- dangerous if called from within another transaction

IF NOT EXISTS (SELECT 1 FROM Orders WHERE OrderID = @OrderID)
BEGIN
    ROLLBACK  -- rolls back outer transaction if one exists!
    RAISERROR('Order %d does not exist', 16, 1, @OrderID)
    SET @ShipmentID = -1
    RETURN -1
END

IF EXISTS (SELECT 1 FROM Shipments WHERE OrderID = @OrderID AND Status NOT IN ('Cancelled', 'Failed'))
BEGIN
    ROLLBACK
    RAISERROR('Active shipment already exists for order %d', 16, 1, @OrderID)
    SET @ShipmentID = -1
    RETURN -1
END

INSERT INTO Shipments (OrderID, DriverID, VehicleID, AssignedDate, Status)
VALUES (@OrderID, @DriverID, @VehicleID, GETDATE(), 'Assigned')

IF @@ERROR <> 0
BEGIN
    ROLLBACK
    SET @ShipmentID = -1
    RETURN -1
END

SET @ShipmentID = SCOPE_IDENTITY()
COMMIT
RETURN 0
GO

-- ============================================================
-- 15. usp_UpdateShipmentStatus
-- Called by driver mobile app (when it worked) and dispatch UI.
-- Mobile app was decommissioned in 2020 but the proc stays.
-- Status codes are magic strings - documented only here:
--   Assigned -> PickedUp -> InTransit -> Delivered
--                       -> Failed
--                       -> Cancelled (dispatch only)
-- ============================================================
CREATE PROCEDURE usp_UpdateShipmentStatus
    @ShipmentID     int,
    @NewStatus      varchar(20),
    @Notes          varchar(500)    = NULL,
    @GPSLat         decimal(9,6)    = NULL,  -- from mobile app, usually NULL now
    @GPSLng         decimal(9,6)    = NULL,
    @MilesLogged    int             = NULL
AS
SET NOCOUNT ON
BEGIN TRY
    BEGIN TRANSACTION

    DECLARE @currentStatus varchar(20), @driverID int, @vehicleID int, @orderID int
    SELECT @currentStatus = Status, @driverID = DriverID,
           @vehicleID = VehicleID, @orderID = OrderID
    FROM Shipments WHERE ShipmentID = @ShipmentID

    IF @currentStatus IS NULL
    BEGIN
        RAISERROR('Shipment %d not found', 16, 1, @ShipmentID)
        ROLLBACK; RETURN -1
    END

    -- Update shipment
    UPDATE Shipments SET
        Status          = @NewStatus,
        DriverNotes     = CASE WHEN @Notes IS NOT NULL
                               THEN ISNULL(DriverNotes + ' | ', '') + @Notes
                               ELSE DriverNotes END,
        MilesLogged     = COALESCE(@MilesLogged, MilesLogged),
        ActualPickupTime  = CASE WHEN @NewStatus = 'PickedUp'  THEN GETDATE() ELSE ActualPickupTime END,
        ActualDeliveryTime= CASE WHEN @NewStatus = 'Delivered' THEN GETDATE() ELSE ActualDeliveryTime END,
        StartTime         = CASE WHEN @NewStatus = 'InTransit' AND StartTime IS NULL THEN GETDATE() ELSE StartTime END,
        EndTime           = CASE WHEN @NewStatus IN ('Delivered','Failed','Cancelled') THEN GETDATE() ELSE EndTime END,
        FailureReason     = CASE WHEN @NewStatus = 'Failed' THEN @Notes ELSE FailureReason END
    WHERE ShipmentID = @ShipmentID

    -- Update driver GPS if provided
    IF @GPSLat IS NOT NULL AND @GPSLng IS NOT NULL
    BEGIN
        UPDATE Drivers SET
            LastKnownLat = @GPSLat,
            LastKnownLng = @GPSLng,
            LastLocationUpdate = GETDATE()
        WHERE DriverID = @driverID
    END

    -- Accumulate driver miles
    IF @MilesLogged IS NOT NULL AND @MilesLogged > 0
    BEGIN
        UPDATE Drivers SET TotalMilesDriven = TotalMilesDriven + @MilesLogged
        WHERE DriverID = @driverID

        UPDATE Vehicles SET CurrentMileage = CurrentMileage + @MilesLogged
        WHERE VehicleID = @vehicleID
    END

    -- Status-specific: release resources on terminal states
    IF @NewStatus IN ('Delivered', 'Failed', 'Cancelled')
    BEGIN
        UPDATE Drivers  SET Status = 'Available' WHERE DriverID  = @driverID
        UPDATE Vehicles SET Status = 'Available' WHERE VehicleID = @vehicleID
    END

    -- TR_Shipments_AutoUpdateOrderStatus fires here and updates Order status.
    -- So we don't explicitly update Orders from this proc.

    COMMIT
    RETURN 0

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK
    RAISERROR('usp_UpdateShipmentStatus failed: %s', 16, 1, ERROR_MESSAGE())
    RETURN -1
END CATCH
GO

-- ============================================================
-- 16. usp_GetShipmentTracking
-- Public-facing tracking query (used by customer portal).
-- Returns sanitized info - no driver personal details.
-- ============================================================
CREATE PROCEDURE usp_GetShipmentTracking
    @OrderID    int     = NULL,
    @ShipmentID int     = NULL
AS
SET NOCOUNT ON

-- Must provide at least one
IF @OrderID IS NULL AND @ShipmentID IS NULL
BEGIN
    RAISERROR('Provide either @OrderID or @ShipmentID', 16, 1)
    RETURN -1
END

SELECT
    s.ShipmentID,
    s.OrderID,
    o.OrderDate,
    o.RequiredDate,
    o.PickupAddress  + ', ' + o.PickupCity + ' ' + o.PickupState   AS PickupLocation,
    o.DeliveryAddress + ', ' + o.DeliveryCity + ' ' + o.DeliveryState AS DeliveryLocation,
    o.TotalWeight,
    o.Priority,
    s.Status                    AS ShipmentStatus,
    o.Status                    AS OrderStatus,
    s.AssignedDate,
    s.ActualPickupTime,
    s.ActualDeliveryTime,
    d.FirstName + ' ' + LEFT(d.LastName, 1) + '.'  AS DriverInitials, -- privacy
    v.VehicleType,
    s.DriverNotes,
    s.FailureReason,
    -- estimated ETA: very rough, no real routing
    CASE
        WHEN s.Status = 'Delivered' THEN s.ActualDeliveryTime
        WHEN s.Status IN ('InTransit', 'PickedUp') THEN
            DATEADD(hour, ISNULL(o.EstimatedMiles / 50, 2), s.StartTime)  -- assumes 50mph average
        ELSE NULL
    END AS EstimatedArrival
FROM Shipments s
INNER JOIN Orders  o ON s.OrderID  = o.OrderID
INNER JOIN Drivers d ON s.DriverID = d.DriverID
INNER JOIN Vehicles v ON s.VehicleID = v.VehicleID
WHERE (@ShipmentID IS NOT NULL AND s.ShipmentID = @ShipmentID)
   OR (@OrderID    IS NOT NULL AND s.OrderID    = @OrderID)
ORDER BY s.ShipmentID DESC
GO

-- ============================================================
-- 17. usp_CompleteShipment
-- Marks shipment delivered, handles proof of delivery.
-- Calls usp_UpdateOrderStatus -> creates invoice chain.
-- If invoice creation fails, shipment is still marked delivered.
-- ============================================================
CREATE PROCEDURE usp_CompleteShipment
    @ShipmentID     int,
    @PODFilePath    varchar(500) = NULL,  -- proof of delivery scan path
    @DriverNotes    varchar(500) = NULL,
    @MilesLogged    int         = NULL,
    @CompletedBy    varchar(50) = NULL
AS
SET NOCOUNT ON

DECLARE @orderID int
SELECT @orderID = OrderID FROM Shipments WHERE ShipmentID = @ShipmentID

IF @orderID IS NULL
BEGIN
    RAISERROR('Shipment %d not found', 16, 1, @ShipmentID)
    RETURN -1
END

-- Update POD path if provided
IF @PODFilePath IS NOT NULL
    UPDATE Shipments SET ProofOfDeliveryPath = @PODFilePath WHERE ShipmentID = @ShipmentID

-- This calls UpdateShipmentStatus which fires the trigger which updates Order
EXEC usp_UpdateShipmentStatus @ShipmentID, 'Delivered', @DriverNotes, NULL, NULL, @MilesLogged

-- usp_UpdateOrderStatus is called by the trigger path, which auto-creates invoice
-- But call it explicitly too just in case trigger didn't fire
-- (This has caused duplicate invoices twice. FIX NEEDED.)
-- EXEC usp_UpdateOrderStatus @orderID, 'Delivered', @CompletedBy
-- ^^^ COMMENTED OUT 2021-03 after duplicate invoice incident. Leave it.

RETURN 0
GO

-- ============================================================
-- 18. usp_FailShipment
-- Records a failed delivery attempt.
-- Does NOT automatically re-queue the order. Dispatcher does that manually.
-- ============================================================
CREATE PROCEDURE usp_FailShipment
    @ShipmentID     int,
    @FailureReason  varchar(500),
    @ReportedBy     varchar(50) = NULL
AS
SET NOCOUNT ON
BEGIN TRY
    BEGIN TRANSACTION

    DECLARE @orderID int, @driverID int, @vehicleID int
    SELECT @orderID = OrderID, @driverID = DriverID, @vehicleID = VehicleID
    FROM Shipments WHERE ShipmentID = @ShipmentID

    IF @orderID IS NULL
    BEGIN
        RAISERROR('Shipment %d not found', 16, 1, @ShipmentID)
        ROLLBACK; RETURN -1
    END

    UPDATE Shipments SET
        Status = 'Failed',
        FailureReason = @FailureReason,
        EndTime = GETDATE()
    WHERE ShipmentID = @ShipmentID

    UPDATE Orders SET Status = 'Failed' WHERE OrderID = @orderID

    UPDATE Drivers  SET Status = 'Available' WHERE DriverID  = @driverID
    UPDATE Vehicles SET Status = 'Available' WHERE VehicleID = @vehicleID

    -- Audit
    INSERT INTO AuditLog (TableName, RecordID, Action, NewValues, ChangedBy)
    VALUES ('Shipments', @ShipmentID, 'FAIL',
            'Reason: ' + @FailureReason,
            ISNULL(@ReportedBy, 'system'))

    COMMIT
    RETURN 0

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK
    RAISERROR('usp_FailShipment failed: %s', 16, 1, ERROR_MESSAGE())
    RETURN -1
END CATCH
GO

-- ============================================================
-- 19. usp_GetActiveShipments
-- Returns all in-progress shipments for dispatch board.
-- Uses ##global temp table - causes problems if two dispatchers
-- run this simultaneously (second one gets first one's data or errors).
-- "Works fine, only one dispatcher at a time" - 2012
-- (There are now 4 dispatchers - 2023)
-- ============================================================
CREATE PROCEDURE usp_GetActiveShipments
    @HomeBase varchar(100) = NULL
AS
SET NOCOUNT ON

IF OBJECT_ID('tempdb..##ActiveShipments') IS NOT NULL
    DROP TABLE ##ActiveShipments

SELECT
    s.ShipmentID,
    s.OrderID,
    o.Priority,
    o.RequiredDate,
    c.CompanyName       AS CustomerName,
    c.Phone             AS CustomerPhone,
    o.PickupAddress + ', ' + o.PickupCity AS PickupLocation,
    o.DeliveryAddress + ', ' + o.DeliveryCity AS DeliveryLocation,
    o.TotalWeight,
    s.Status,
    s.ActualPickupTime,
    d.FirstName + ' ' + d.LastName AS DriverName,
    d.CellPhone,
    d.HomeBase,
    v.LicensePlate,
    v.VehicleType,
    DATEDIFF(minute, s.AssignedDate, GETDATE()) AS MinutesElapsed,
    -- flag overdue shipments (RequiredDate < NOW and not delivered)
    CASE WHEN o.RequiredDate < GETDATE() THEN 1 ELSE 0 END AS IsOverdue
INTO ##ActiveShipments
FROM Shipments s
INNER JOIN Orders o   ON s.OrderID  = o.OrderID
INNER JOIN Customers c ON o.CustomerID = c.CustomerID
INNER JOIN Drivers d  ON s.DriverID  = d.DriverID
INNER JOIN Vehicles v ON s.VehicleID = v.VehicleID
WHERE s.Status IN ('Assigned', 'PickedUp', 'InTransit')
  AND (@HomeBase IS NULL OR d.HomeBase = @HomeBase)

SELECT * FROM ##ActiveShipments
ORDER BY IsOverdue DESC, Priority ASC, RequiredDate ASC

DROP TABLE ##ActiveShipments
GO
