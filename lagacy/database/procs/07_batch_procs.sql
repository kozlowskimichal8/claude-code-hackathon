-- ============================================================
-- Batch / Maintenance Stored Procedures (5 procs)
-- ============================================================
USE NorthwindLogistics
GO

-- ============================================================
-- 38. usp_ProcessEndOfDay  *** THE GOD PROC ***
-- Runs every night at 11:30 PM via SQL Server Agent job.
-- Does: billing, driver reset, stale order detection,
--       index maintenance trigger, report email (via DB mail),
--       archival flag, stats update.
-- If this fails partway through, some steps may have run and
-- some may not. There is no idempotency. Restart = re-run risk.
-- "Has been running for 12 years without issues" - 2021
-- (It failed in 2022, nobody noticed for 3 days. Invoices were late.)
-- Runtime: ~8 minutes on a quiet night.
-- ============================================================
CREATE PROCEDURE usp_ProcessEndOfDay
    @RunDate        datetime    = NULL,     -- default to today
    @DryRun         bit         = 0,        -- 1 = log what would happen, don't commit
    @ForceRerun     bit         = 0         -- 1 = allow re-running same date
AS
SET NOCOUNT ON

DECLARE @startTime datetime = GETDATE()
DECLARE @logMsg varchar(1000)

SET @RunDate = CAST(CAST(COALESCE(@RunDate, GETDATE()) AS date) AS datetime)

-- Prevent accidental double-run (unless forced)
IF @ForceRerun = 0
BEGIN
    IF EXISTS (
        SELECT 1 FROM AuditLog
        WHERE Action = 'EOD_COMPLETE'
          AND CAST(ChangedDate AS date) = CAST(@RunDate AS date)
    )
    BEGIN
        RAISERROR('EOD already completed for %s. Use @ForceRerun=1 to override.',
                  16, 1, @RunDate)
        RETURN -1
    END
END

INSERT INTO AuditLog (TableName, RecordID, Action, NewValues, ChangedBy)
VALUES ('SYSTEM', 0, 'EOD_START', 'RunDate=' + CONVERT(varchar, @RunDate, 101), 'batch')

-- ============================================================
-- STEP 1: Auto-bill delivered orders that have no invoice
-- ============================================================
DECLARE @orderID int, @newInvID int, @billedCount int = 0

DECLARE bill_cursor CURSOR FOR
    SELECT o.OrderID
    FROM Orders o
    WHERE o.Status = 'Delivered'
      AND o.IsBilled = 0
      AND o.ShippedDate >= DATEADD(day, -7, @RunDate)  -- only last 7 days
      AND NOT EXISTS (SELECT 1 FROM Invoices WHERE OrderID = o.OrderID)

OPEN bill_cursor
FETCH NEXT FROM bill_cursor INTO @orderID

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @DryRun = 0
    BEGIN
        SET @newInvID = NULL
        EXEC usp_CreateInvoice @orderID, 'EOD_BATCH', @newInvID OUTPUT

        IF @newInvID > 0
            SET @billedCount = @billedCount + 1
        ELSE
        BEGIN
            INSERT INTO AuditLog (TableName, RecordID, Action, NewValues, ChangedBy)
            VALUES ('Orders', @orderID, 'EOD_WARN', 'Auto-billing failed', 'batch')
        END
    END
    ELSE
        SET @billedCount = @billedCount + 1  -- dry run count

    FETCH NEXT FROM bill_cursor INTO @orderID
END
CLOSE bill_cursor
DEALLOCATE bill_cursor

SET @logMsg = 'Step1_AutoBill: ' + CAST(@billedCount AS varchar) + ' invoices created'
INSERT INTO AuditLog (TableName, RecordID, Action, NewValues, ChangedBy)
VALUES ('SYSTEM', 0, 'EOD_STEP', @logMsg, 'batch')

-- ============================================================
-- STEP 2: Mark overdue invoices
-- ============================================================
DECLARE @overdueCount int = 0

IF @DryRun = 0
BEGIN
    UPDATE Invoices
    SET Status = 'Overdue'
    WHERE Status IN ('Draft', 'Sent', 'PartialPaid')
      AND DueDate < @RunDate
      AND PaidAmount < TotalAmount

    SET @overdueCount = @@ROWCOUNT
END
ELSE
BEGIN
    SELECT @overdueCount = COUNT(*) FROM Invoices
    WHERE Status IN ('Draft', 'Sent', 'PartialPaid')
      AND DueDate < @RunDate AND PaidAmount < TotalAmount
END

SET @logMsg = 'Step2_Overdue: ' + CAST(@overdueCount AS varchar) + ' invoices marked overdue'
INSERT INTO AuditLog (TableName, RecordID, Action, NewValues, ChangedBy)
VALUES ('SYSTEM', 0, 'EOD_STEP', @logMsg, 'batch')

-- ============================================================
-- STEP 3: Reset OffDuty drivers back to Available
-- (Drivers manually set to OffDuty for end of shift;
--  they should be Available next morning. This is the reset.)
-- "Should be a scheduled status, not a batch reset" - tech debt note 2018
-- ============================================================
IF @DryRun = 0
BEGIN
    UPDATE Drivers SET Status = 'Available'
    WHERE Status = 'OffDuty'
      AND TerminatedDate IS NULL
    -- Also reset any drivers stuck "OnRoute" for >16 hours (something went wrong)
    UPDATE Drivers SET Status = 'Available'
    WHERE Status = 'OnRoute'
      AND NOT EXISTS (
          SELECT 1 FROM Shipments s
          WHERE s.DriverID = Drivers.DriverID
            AND s.Status IN ('Assigned', 'PickedUp', 'InTransit')
      )
END

INSERT INTO AuditLog (TableName, RecordID, Action, NewValues, ChangedBy)
VALUES ('SYSTEM', 0, 'EOD_STEP', 'Step3_DriverReset: complete', 'batch')

-- ============================================================
-- STEP 4: Flag stale Pending orders (>48 hours)
-- Doesn't actually do anything - just logs them.
-- "We'll add email notification once the mail relay is fixed" - 2019
-- (Mail relay was fixed in 2020. Nobody added the notification.)
-- ============================================================
DECLARE @staleCount int
SELECT @staleCount = COUNT(*) FROM Orders
WHERE Status = 'Pending'
  AND DATEDIFF(hour, OrderDate, @RunDate) > 48

SET @logMsg = 'Step4_StaleOrders: ' + CAST(@staleCount AS varchar) + ' orders pending >48h'
INSERT INTO AuditLog (TableName, RecordID, Action, NewValues, ChangedBy)
VALUES ('SYSTEM', 0, 'EOD_STEP', @logMsg, 'batch')

-- ============================================================
-- STEP 5: Send daily report email via Database Mail
-- SMTP server is hardcoded. If it changes, update here AND in SystemSettings.
-- ============================================================
IF @DryRun = 0
BEGIN
    DECLARE @emailBody nvarchar(4000)
    DECLARE @emailTo varchar(500)
    SELECT @emailTo = SettingValue FROM SystemSettings WHERE SettingKey = 'EODReportEmail'

    SET @emailBody =
        '<h2>Northwind Logistics - End of Day Report</h2>' +
        '<p>Date: ' + CONVERT(varchar, @RunDate, 101) + '</p>' +
        '<ul>' +
        '<li>Auto-billed orders: ' + CAST(@billedCount AS varchar) + '</li>' +
        '<li>Invoices marked overdue: ' + CAST(@overdueCount AS varchar) + '</li>' +
        '<li>Stale pending orders: ' + CAST(@staleCount AS varchar) + '</li>' +
        '</ul>' +
        '<p>Generated at: ' + CONVERT(varchar, GETDATE(), 120) + '</p>'

    BEGIN TRY
        EXEC msdb.dbo.sp_send_dbmail
            @profile_name = 'NWLMailProfile',  -- created manually, not scripted
            @recipients   = @emailTo,
            @subject      = 'NWL EOD Report - ' + CONVERT(varchar, @RunDate, 101),
            @body         = @emailBody,
            @body_format  = 'HTML'
    END TRY
    BEGIN CATCH
        -- Email failure should not fail the whole EOD
        INSERT INTO AuditLog (TableName, RecordID, Action, NewValues, ChangedBy)
        VALUES ('SYSTEM', 0, 'EOD_WARN', 'Email send failed: ' + ERROR_MESSAGE(), 'batch')
    END CATCH
END

-- ============================================================
-- STEP 6: Update statistics on hot tables
-- ============================================================
IF @DryRun = 0
BEGIN
    UPDATE STATISTICS Orders     WITH FULLSCAN
    UPDATE STATISTICS Shipments  WITH FULLSCAN
    UPDATE STATISTICS Invoices   WITH FULLSCAN
    -- Note: this can take 3-4 minutes on large tables
    -- DBA asked us to move to SAMPLE 30 PERCENT but "no time to test"
END

INSERT INTO AuditLog (TableName, RecordID, Action, NewValues, ChangedBy)
VALUES ('SYSTEM', 0, 'EOD_STEP', 'Step6_UpdateStats: complete', 'batch')

-- ============================================================
-- Final: mark EOD complete
-- ============================================================
DECLARE @elapsed int = DATEDIFF(second, @startTime, GETDATE())
SET @logMsg = 'EOD_COMPLETE for ' + CONVERT(varchar, @RunDate, 101) +
              ' in ' + CAST(@elapsed AS varchar) + ' seconds. DryRun=' + CAST(@DryRun AS varchar)

INSERT INTO AuditLog (TableName, RecordID, Action, NewValues, ChangedBy)
VALUES ('SYSTEM', 0, 'EOD_COMPLETE', @logMsg, 'batch')

-- Return summary as result set (for SQL Agent job history)
SELECT
    @RunDate        AS RunDate,
    @billedCount    AS OrdersAutoBilled,
    @overdueCount   AS InvoicesMarkedOverdue,
    @staleCount     AS StaleOrdersFound,
    @elapsed        AS ElapsedSeconds,
    @DryRun         AS WasDryRun

RETURN 0
GO

-- ============================================================
-- 39. usp_ArchiveOldOrders
-- Moves completed orders older than N days to Orders_Archive.
-- Deletes from Orders WITHOUT deleting OrderItems first
-- if FK is present... FK was removed "for speed" in 2015.
-- Archive table has no FKs so it accepts anything.
-- ============================================================
CREATE PROCEDURE usp_ArchiveOldOrders
    @DaysOld    int     = NULL,     -- default from SystemSettings
    @DryRun     bit     = 0,
    @BatchSize  int     = 1000      -- process in batches to avoid log growth
AS
SET NOCOUNT ON

IF @DaysOld IS NULL
BEGIN
    DECLARE @settingVal varchar(500)
    SELECT @settingVal = SettingValue FROM SystemSettings WHERE SettingKey = 'ArchiveDaysOld'
    SET @DaysOld = ISNULL(CAST(@settingVal AS int), 365)
END

DECLARE @cutoffDate datetime = DATEADD(day, -@DaysOld, GETDATE())
DECLARE @archivedTotal int = 0
DECLARE @batch int = @BatchSize

WHILE @batch = @BatchSize
BEGIN
    -- Get next batch
    SELECT TOP (@BatchSize) OrderID
    INTO #ArchiveBatch
    FROM Orders
    WHERE Status IN ('Delivered', 'Cancelled')
      AND OrderDate < @cutoffDate
      AND OrderID NOT IN (SELECT OrderID FROM Orders_Archive)

    SET @batch = @@ROWCOUNT

    IF @batch = 0 BREAK

    IF @DryRun = 0
    BEGIN
        -- Copy to archive
        INSERT INTO Orders_Archive (
            OrderID, CustomerID, OrderDate, RequiredDate, ShippedDate,
            Status, PickupAddress, PickupCity, PickupState, PickupZip,
            DeliveryAddress, DeliveryCity, DeliveryState, DeliveryZip,
            TotalWeight, TotalCost, DiscountPct, SpecialInstructions,
            Priority, ArchivedDate
        )
        SELECT
            o.OrderID, o.CustomerID, o.OrderDate, o.RequiredDate, o.ShippedDate,
            o.Status, o.PickupAddress, o.PickupCity, o.PickupState, o.PickupZip,
            o.DeliveryAddress, o.DeliveryCity, o.DeliveryState, o.DeliveryZip,
            o.TotalWeight, o.TotalCost, o.DiscountPct, o.SpecialInstructions,
            o.Priority, GETDATE()
        FROM Orders o
        INNER JOIN #ArchiveBatch ab ON o.OrderID = ab.OrderID

        -- Delete from live tables
        -- OrderItems delete: should be here but FK was removed so this is implicit
        -- Actually OrderItems ARE still there after this delete - orphaned rows accumulate
        -- See: cleanup proc usp_CleanupTempData which tries to fix this
        DELETE FROM Orders
        WHERE OrderID IN (SELECT OrderID FROM #ArchiveBatch)
    END

    SET @archivedTotal = @archivedTotal + @batch
    DROP TABLE #ArchiveBatch
END

SELECT @archivedTotal AS OrdersArchived, @DryRun AS WasDryRun
RETURN 0
GO

-- ============================================================
-- 40. usp_RecalculateAllPricing
-- Re-runs cost calculation for all orders that are Pending or Assigned.
-- Called when pricing rules change.
-- DANGEROUS: Runs over potentially thousands of orders.
-- No way to preview impact. No rollback if you don't like results.
-- Has been accidentally run on delivered/billed orders once (2019).
-- Added status check after that incident.
-- ============================================================
CREATE PROCEDURE usp_RecalculateAllPricing
    @StatusFilter   varchar(20)     = 'Pending',    -- only recalc these
    @DryRun         bit             = 1,            -- default to dry run for safety
    @CustomerType   char(1)         = NULL          -- optional: only for this customer type
AS
SET NOCOUNT ON

IF @StatusFilter NOT IN ('Pending', 'Assigned')
BEGIN
    RAISERROR('RecalculateAllPricing: @StatusFilter must be Pending or Assigned. Got: %s', 16, 1, @StatusFilter)
    RETURN -1
END

DECLARE @orderID int, @oldCost money, @newCost money
DECLARE @updatedCount int = 0
DECLARE @totalDiff money = 0

CREATE TABLE #PricingChanges (
    OrderID         int,
    OldCost         money,
    CustomerType    char(1),
    Status          varchar(20)
)

INSERT INTO #PricingChanges (OrderID, OldCost, CustomerType, Status)
SELECT o.OrderID, o.TotalCost, c.CustomerType, o.Status
FROM Orders o
INNER JOIN Customers c ON o.CustomerID = c.CustomerID
WHERE o.Status = @StatusFilter
  AND (@CustomerType IS NULL OR c.CustomerType = @CustomerType)

DECLARE recalc_cursor CURSOR FOR
    SELECT OrderID, OldCost FROM #PricingChanges

OPEN recalc_cursor
FETCH NEXT FROM recalc_cursor INTO @orderID, @oldCost

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @DryRun = 0
        EXEC usp_CalculateOrderCost @orderID, 1  -- force recalculate

    -- Read new cost
    SELECT @newCost = TotalCost FROM Orders WHERE OrderID = @orderID

    SET @totalDiff = @totalDiff + (ISNULL(@newCost, 0) - ISNULL(@oldCost, 0))
    SET @updatedCount = @updatedCount + 1

    FETCH NEXT FROM recalc_cursor INTO @orderID, @oldCost
END

CLOSE recalc_cursor
DEALLOCATE recalc_cursor

SELECT
    @updatedCount   AS OrdersProcessed,
    @totalDiff      AS TotalPriceChange,
    @DryRun         AS WasDryRun

DROP TABLE #PricingChanges
RETURN 0
GO

-- ============================================================
-- 41. usp_CleanupTempData
-- Cleans up various mess that accumulates over time:
-- - Orphaned OrderItems (from archival not cleaning up items)
-- - Terminated drivers who are still 'OnRoute' somehow
-- - Vehicles stuck 'InUse' with no active shipment
-- Run manually when "things seem off". Not scheduled.
-- ============================================================
CREATE PROCEDURE usp_CleanupTempData
    @DryRun bit = 1
AS
SET NOCOUNT ON

-- 1. Orphaned OrderItems (order was archived/deleted but items remain)
DECLARE @orphanItems int
SELECT @orphanItems = COUNT(*) FROM OrderItems oi
WHERE NOT EXISTS (SELECT 1 FROM Orders o WHERE o.OrderID = oi.OrderID)

IF @DryRun = 0
    DELETE FROM OrderItems
    WHERE NOT EXISTS (SELECT 1 FROM Orders o WHERE o.OrderID = OrderItems.OrderID)

-- 2. Terminated drivers stuck in wrong status
DECLARE @stuckDrivers int
SELECT @stuckDrivers = COUNT(*) FROM Drivers
WHERE TerminatedDate IS NOT NULL AND Status <> 'Terminated'

IF @DryRun = 0
    UPDATE Drivers SET Status = 'Terminated'
    WHERE TerminatedDate IS NOT NULL AND Status <> 'Terminated'

-- 3. Vehicles InUse with no active shipment
DECLARE @stuckVehicles int
SELECT @stuckVehicles = COUNT(*) FROM Vehicles v
WHERE v.Status = 'InUse'
  AND NOT EXISTS (
      SELECT 1 FROM Shipments s
      WHERE s.VehicleID = v.VehicleID
        AND s.Status IN ('Assigned', 'PickedUp', 'InTransit')
  )

IF @DryRun = 0
BEGIN
    UPDATE Vehicles SET Status = 'Available', AssignedDriverID = NULL
    WHERE Status = 'InUse'
      AND NOT EXISTS (
          SELECT 1 FROM Shipments s
          WHERE s.VehicleID = Vehicles.VehicleID
            AND s.Status IN ('Assigned', 'PickedUp', 'InTransit')
      )
END

-- 4. Drop any orphaned global temp tables from crashed sessions
-- (Can't really clean these up programmatically without knowing session IDs)

SELECT
    @orphanItems    AS OrphanedOrderItems,
    @stuckDrivers   AS StuckDriversFixed,
    @stuckVehicles  AS StuckVehiclesFixed,
    @DryRun         AS WasDryRun

RETURN 0
GO

-- ============================================================
-- 42. usp_RebuildIndexes
-- Called from SQL Agent job weekly (Sunday 2 AM).
-- Rebuilds all indexes regardless of fragmentation level.
-- "Smarter rebuild based on fragmentation was planned" - 2016
-- Causes table locks, which caused the 2020 Monday morning incident.
-- DBA added ONLINE=ON for large tables but forgot OrderItems.
-- ============================================================
CREATE PROCEDURE usp_RebuildIndexes
AS
SET NOCOUNT ON

DECLARE @table varchar(100), @index varchar(100)
DECLARE @sql nvarchar(500)

DECLARE idx_cursor CURSOR FOR
    SELECT t.name, i.name
    FROM sys.indexes i
    INNER JOIN sys.tables t ON i.object_id = t.object_id
    WHERE i.index_id > 0    -- skip heap
      AND t.is_ms_shipped = 0
    ORDER BY t.name, i.name

OPEN idx_cursor
FETCH NEXT FROM idx_cursor INTO @table, @index

WHILE @@FETCH_STATUS = 0
BEGIN
    -- ONLINE=ON for "big" tables (hardcoded list, maintained manually)
    IF @table IN ('Orders', 'Shipments', 'AuditLog', 'Invoices', 'Payments')
        SET @sql = 'ALTER INDEX [' + @index + '] ON [' + @table + '] REBUILD WITH (ONLINE=ON)'
    ELSE
        SET @sql = 'ALTER INDEX [' + @index + '] ON [' + @table + '] REBUILD'
        -- OrderItems, OrderItems are NOT in the ONLINE list

    BEGIN TRY
        EXEC(@sql)
    END TRY
    BEGIN CATCH
        -- Log failures but continue
        INSERT INTO AuditLog (TableName, RecordID, Action, NewValues, ChangedBy)
        VALUES (@table, 0, 'IDXREBUILD_ERR', ERROR_MESSAGE(), 'maintenance')
    END CATCH

    FETCH NEXT FROM idx_cursor INTO @table, @index
END

CLOSE idx_cursor
DEALLOCATE idx_cursor

RETURN 0
GO
