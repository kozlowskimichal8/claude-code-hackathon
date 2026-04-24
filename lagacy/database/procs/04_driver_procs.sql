-- ============================================================
-- Driver Stored Procedures (6 procs)
-- ============================================================
USE NorthwindLogistics
GO

-- ============================================================
-- 20. usp_GetAvailableDrivers
-- Returns drivers who can be assigned.
-- Full table scan on Drivers because no index on Status.
-- Also doesn't check if driver has a license that's expired.
-- Amy Schultz incident (2023): expired license, 3 deliveries made.
-- ============================================================
CREATE PROCEDURE usp_GetAvailableDrivers
    @HomeBase       varchar(100) = NULL,
    @RequiredWeight decimal(10,2) = NULL   -- to filter by vehicle capacity (never actually used)
AS
SET NOCOUNT ON

SELECT
    d.DriverID,
    d.FirstName + ' ' + d.LastName      AS DriverName,
    d.Phone,
    d.CellPhone,
    d.HomeBase,
    d.HourlyRate,
    d.TotalMilesDriven,
    d.LicenseExpiryDate,
    -- flag expiring soon but don't exclude them
    CASE WHEN d.LicenseExpiryDate < DATEADD(month, 1, GETDATE())
         THEN 1 ELSE 0 END              AS LicenseExpiringSoon,
    -- available vehicles at same home base
    (SELECT COUNT(*)
     FROM Vehicles v
     WHERE v.Status = 'Available'
       AND (@HomeBase IS NULL OR EXISTS (
               SELECT 1 FROM Drivers d2
               WHERE d2.DriverID = d.DriverID AND d2.HomeBase = @HomeBase))
    ) AS AvailableVehicleCount,
    -- orders completed this week
    (SELECT COUNT(*)
     FROM Shipments s
     WHERE s.DriverID = d.DriverID
       AND s.Status = 'Delivered'
       AND s.ActualDeliveryTime >= DATEADD(day, -7, GETDATE())
    ) AS DeliveriesThisWeek
FROM Drivers d
WHERE d.Status = 'Available'
  AND d.TerminatedDate IS NULL
  AND (@HomeBase IS NULL OR d.HomeBase = @HomeBase)
ORDER BY d.LastName, d.FirstName
GO

-- ============================================================
-- 21. usp_AssignDriver
-- Updates driver status to OnRoute and optionally assigns to a vehicle.
-- Doesn't validate that vehicle is compatible with driver's license class.
-- That validation was "planned for v2.0" in 2012.
-- ============================================================
CREATE PROCEDURE usp_AssignDriver
    @DriverID   int,
    @VehicleID  int = NULL,
    @AssignedBy varchar(50) = NULL
AS
SET NOCOUNT ON

DECLARE @currentStatus varchar(20)
SELECT @currentStatus = Status FROM Drivers WHERE DriverID = @DriverID

IF @currentStatus IS NULL
BEGIN
    RAISERROR('Driver %d not found', 16, 1, @DriverID)
    RETURN -1
END

IF @currentStatus NOT IN ('Available')
BEGIN
    RAISERROR('Driver %d is not available (status: %s)', 16, 1, @DriverID, @currentStatus)
    RETURN -1
END

UPDATE Drivers SET Status = 'OnRoute' WHERE DriverID = @DriverID

IF @VehicleID IS NOT NULL
BEGIN
    UPDATE Vehicles SET Status = 'InUse', AssignedDriverID = @DriverID
    WHERE VehicleID = @VehicleID AND Status = 'Available'

    IF @@ROWCOUNT = 0
        -- vehicle not available, but we already changed driver status. oops.
        INSERT INTO AuditLog (TableName, RecordID, Action, NewValues, ChangedBy)
        VALUES ('Drivers', @DriverID, 'WARN',
                'Vehicle ' + CAST(@VehicleID AS varchar) + ' not available when assigning driver',
                ISNULL(@AssignedBy, 'system'))
END

RETURN 0
GO

-- ============================================================
-- 22. usp_UpdateDriverLocation
-- Called by mobile app every 5 minutes when driver is on route.
-- App was decommissioned. This is now called by nothing.
-- Left in because "might bring back GPS tracking someday".
-- ============================================================
CREATE PROCEDURE usp_UpdateDriverLocation
    @DriverID   int,
    @Latitude   decimal(9,6),
    @Longitude  decimal(9,6),
    @Speed      int = NULL,     -- mph, from app accelerometer
    @Heading    int = NULL      -- degrees 0-360
AS
SET NOCOUNT ON

UPDATE Drivers SET
    LastKnownLat = @Latitude,
    LastKnownLng = @Longitude,
    LastLocationUpdate = GETDATE()
WHERE DriverID = @DriverID

-- We used to log every location update to a DriverLocationHistory table.
-- That table grew to 500M rows in 18 months and was dropped without archiving.
-- Now we just keep the last known position.

IF @@ROWCOUNT = 0
BEGIN
    RAISERROR('Driver %d not found', 11, 1, @DriverID)  -- severity 11 = just a warning
    RETURN -1
END

RETURN 0
GO

-- ============================================================
-- 23. usp_GetDriverSchedule
-- Returns driver availability/schedule for a date range.
-- Generates a row per day using a cursor (instead of a numbers table).
-- Slow for date ranges > 2 weeks.
-- ============================================================
CREATE PROCEDURE usp_GetDriverSchedule
    @DriverID   int,
    @DateFrom   datetime,
    @DateTo     datetime
AS
SET NOCOUNT ON

-- Validate date range
IF DATEDIFF(day, @DateFrom, @DateTo) > 90
BEGIN
    RAISERROR('Date range cannot exceed 90 days', 16, 1)
    RETURN -1
END

CREATE TABLE #Schedule (
    ScheduleDate    date,
    DayOfWeek       varchar(10),
    Status          varchar(20),
    OrderCount      int,
    ShipmentIDs     varchar(500)
)

DECLARE @currentDate datetime = @DateFrom
DECLARE @orderCount int
DECLARE @shipIDs varchar(500)
DECLARE @dayStatus varchar(20)

WHILE @currentDate <= @DateTo
BEGIN
    SET @orderCount = 0
    SET @shipIDs = NULL

    SELECT
        @orderCount = COUNT(*),
        @shipIDs = STUFF((
            SELECT ', ' + CAST(ShipmentID AS varchar)
            FROM Shipments s2
            WHERE s2.DriverID = @DriverID
              AND CAST(s2.AssignedDate AS date) = CAST(@currentDate AS date)
            FOR XML PATH('')
        ), 1, 2, '')
    FROM Shipments s
    WHERE s.DriverID = @DriverID
      AND CAST(s.AssignedDate AS date) = CAST(@currentDate AS date)
      AND s.Status NOT IN ('Cancelled')

    -- Determine day status
    IF DATEPART(dw, @currentDate) IN (1, 7)  -- Sunday=1, Saturday=7
        SET @dayStatus = 'Weekend'
    ELSE IF @orderCount > 0
        SET @dayStatus = 'Scheduled'
    ELSE
        SET @dayStatus = 'Available'

    INSERT INTO #Schedule VALUES (
        CAST(@currentDate AS date),
        DATENAME(dw, @currentDate),
        @dayStatus,
        @orderCount,
        @shipIDs
    )

    SET @currentDate = DATEADD(day, 1, @currentDate)
END

SELECT * FROM #Schedule ORDER BY ScheduleDate
DROP TABLE #Schedule
GO

-- ============================================================
-- 24. usp_CreateDriver
-- Adds new driver. Validation is mostly in the app layer.
-- No validation for duplicate license numbers.
-- ============================================================
CREATE PROCEDURE usp_CreateDriver
    @FirstName          varchar(50),
    @LastName           varchar(50),
    @LicenseNumber      varchar(30) = NULL,
    @LicenseExpiryDate  datetime    = NULL,
    @Phone              varchar(20) = NULL,
    @CellPhone          varchar(20) = NULL,
    @Email              varchar(100) = NULL,
    @HourlyRate         money       = 17.00,
    @HomeBase           varchar(100) = NULL,
    @EmergencyContact   varchar(100) = NULL,
    @EmergencyPhone     varchar(20) = NULL,
    @NewDriverID        int         OUTPUT
AS
SET NOCOUNT ON
BEGIN TRY

    IF @FirstName IS NULL OR @LastName IS NULL
    BEGIN
        RAISERROR('FirstName and LastName are required', 16, 1)
        SET @NewDriverID = -1; RETURN -1
    END

    -- Warn if license already in use (won't block - just warns)
    IF @LicenseNumber IS NOT NULL
       AND EXISTS (SELECT 1 FROM Drivers WHERE LicenseNumber = @LicenseNumber)
    BEGIN
        INSERT INTO AuditLog (TableName, RecordID, Action, NewValues, ChangedBy)
        VALUES ('Drivers', 0, 'WARN',
                'Duplicate license number: ' + @LicenseNumber,
                'system')
    END

    INSERT INTO Drivers (
        FirstName, LastName, LicenseNumber, LicenseExpiryDate,
        Phone, CellPhone, Email, Status,
        HiredDate, HourlyRate, HomeBase,
        EmergencyContact, EmergencyPhone
    )
    VALUES (
        @FirstName, @LastName, @LicenseNumber, @LicenseExpiryDate,
        @Phone, @CellPhone, @Email, 'Available',
        GETDATE(), @HourlyRate, @HomeBase,
        @EmergencyContact, @EmergencyPhone
    )

    SET @NewDriverID = SCOPE_IDENTITY()
    RETURN 0

END TRY
BEGIN CATCH
    RAISERROR('usp_CreateDriver failed: %s', 16, 1, ERROR_MESSAGE())
    SET @NewDriverID = -1
    RETURN -1
END CATCH
GO

-- ============================================================
-- 25. usp_GetDriverPerformance
-- Calculates driver KPIs. Used in manager dashboard.
-- No index on Shipments.Status or Shipments.DriverID for dates -
-- does full scan of Shipments for each driver (called in a loop
-- from the reporting page).
-- ============================================================
CREATE PROCEDURE usp_GetDriverPerformance
    @DriverID   int     = NULL,     -- NULL = all drivers
    @DateFrom   datetime = NULL,
    @DateTo     datetime = NULL
AS
SET NOCOUNT ON

SET @DateFrom = COALESCE(@DateFrom, DATEADD(month, -1, GETDATE()))
SET @DateTo   = COALESCE(@DateTo,   GETDATE())

SELECT
    d.DriverID,
    d.FirstName + ' ' + d.LastName      AS DriverName,
    d.HomeBase,
    d.Status                            AS CurrentStatus,
    COUNT(s.ShipmentID)                 AS TotalAssigned,
    SUM(CASE WHEN s.Status = 'Delivered' THEN 1 ELSE 0 END) AS Delivered,
    SUM(CASE WHEN s.Status = 'Failed'    THEN 1 ELSE 0 END) AS Failed,
    SUM(CASE WHEN s.Status = 'Delivered' THEN 1.0 ELSE 0 END)
        / NULLIF(COUNT(s.ShipmentID), 0) * 100              AS DeliveryRate,
    AVG(CASE WHEN s.Status = 'Delivered'
        THEN DATEDIFF(minute, s.ActualPickupTime, s.ActualDeliveryTime)
        ELSE NULL END)                  AS AvgDeliveryMinutes,
    SUM(ISNULL(s.MilesLogged, 0))       AS TotalMiles,
    -- on-time rate: delivered before RequiredDate
    SUM(CASE WHEN s.Status = 'Delivered'
              AND s.ActualDeliveryTime <= o.RequiredDate
             THEN 1.0 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN s.Status='Delivered' THEN 1 ELSE 0 END), 0) * 100
                                        AS OnTimeRate
FROM Drivers d
LEFT JOIN Shipments s ON d.DriverID = s.DriverID
                      AND s.AssignedDate BETWEEN @DateFrom AND @DateTo
LEFT JOIN Orders o    ON s.OrderID = o.OrderID
WHERE (@DriverID IS NULL OR d.DriverID = @DriverID)
  AND d.Status <> 'Terminated'  -- excludes terminated, but they still show in reports sometimes
GROUP BY d.DriverID, d.FirstName, d.LastName, d.HomeBase, d.Status
ORDER BY DeliveryRate DESC
GO
