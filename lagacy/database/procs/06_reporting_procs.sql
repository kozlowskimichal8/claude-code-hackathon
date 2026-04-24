-- ============================================================
-- Reporting Stored Procedures (5 procs)
-- ============================================================
USE NorthwindLogistics
GO

-- ============================================================
-- 33. usp_GetDailyShipmentReport
-- Called by the EOD job to generate the ops summary email.
-- Uses ##global temp table (see risk note in usp_GetActiveShipments).
-- ============================================================
CREATE PROCEDURE usp_GetDailyShipmentReport
    @ReportDate datetime = NULL
AS
SET NOCOUNT ON

SET @ReportDate = COALESCE(@ReportDate, GETDATE())
DECLARE @dateStart datetime = CAST(CAST(@ReportDate AS date) AS datetime)
DECLARE @dateEnd   datetime = DATEADD(day, 1, @dateStart)

IF OBJECT_ID('tempdb..##DailyReport') IS NOT NULL
    DROP TABLE ##DailyReport

-- Delivery summary
SELECT
    COUNT(*)                                                    AS TotalShipments,
    SUM(CASE WHEN s.Status = 'Delivered' THEN 1 ELSE 0 END)    AS Delivered,
    SUM(CASE WHEN s.Status = 'Failed'    THEN 1 ELSE 0 END)    AS Failed,
    SUM(CASE WHEN s.Status IN ('Assigned','PickedUp','InTransit') THEN 1 ELSE 0 END) AS StillActive,
    SUM(CASE WHEN s.Status = 'Cancelled' THEN 1 ELSE 0 END)    AS Cancelled,
    -- on-time: delivered before required date
    SUM(CASE WHEN s.Status = 'Delivered'
              AND s.ActualDeliveryTime <= o.RequiredDate
             THEN 1 ELSE 0 END)                                AS OnTime,
    -- late
    SUM(CASE WHEN s.Status = 'Delivered'
              AND s.ActualDeliveryTime > o.RequiredDate
             THEN 1 ELSE 0 END)                                AS Late,
    -- revenue (only delivered)
    SUM(CASE WHEN s.Status = 'Delivered' THEN o.TotalCost ELSE 0 END) AS DailyRevenue,
    -- avg delivery time in minutes
    AVG(CASE WHEN s.Status = 'Delivered'
        THEN DATEDIFF(minute, s.ActualPickupTime, s.ActualDeliveryTime)
        ELSE NULL END)                                         AS AvgDeliveryMinutes
INTO ##DailyReport
FROM Shipments s
INNER JOIN Orders o ON s.OrderID = o.OrderID
WHERE s.AssignedDate >= @dateStart AND s.AssignedDate < @dateEnd

SELECT * FROM ##DailyReport

-- Detail of failed shipments
SELECT
    s.ShipmentID,
    o.OrderID,
    c.CompanyName,
    d.FirstName + ' ' + d.LastName AS DriverName,
    s.FailureReason,
    o.DeliveryCity + ', ' + o.DeliveryState AS Destination
FROM Shipments s
INNER JOIN Orders   o ON s.OrderID   = o.OrderID
INNER JOIN Customers c ON o.CustomerID = c.CustomerID
INNER JOIN Drivers  d ON s.DriverID  = d.DriverID
WHERE s.Status = 'Failed'
  AND s.AssignedDate >= @dateStart AND s.AssignedDate < @dateEnd

DROP TABLE ##DailyReport
GO

-- ============================================================
-- 34. usp_GetDriverPerformanceReport
-- Monthly driver scorecard. Called from manager dashboard.
-- Calls usp_GetDriverPerformance for each driver in a loop.
-- Runtime: ~2 minutes for 8 drivers. "Acceptable" per management.
-- ============================================================
CREATE PROCEDURE usp_GetDriverPerformanceReport
    @Year   int = NULL,
    @Month  int = NULL
AS
SET NOCOUNT ON

DECLARE @dateFrom datetime, @dateTo datetime

IF @Year IS NULL  SET @Year  = YEAR(GETDATE())
IF @Month IS NULL SET @Month = MONTH(GETDATE())

SET @dateFrom = CAST(CAST(@Year AS varchar) + '-' + RIGHT('0' + CAST(@Month AS varchar), 2) + '-01' AS datetime)
SET @dateTo   = DATEADD(month, 1, @dateFrom)

-- Rather than call the other proc (which returns a resultset we can't insert directly),
-- duplicate the query here. Yes, it's duplicated. "Easier to maintain separately" (2018)
SELECT
    d.DriverID,
    d.FirstName + ' ' + d.LastName  AS DriverName,
    d.HomeBase,
    COUNT(s.ShipmentID)             AS TotalRuns,
    SUM(CASE WHEN s.Status='Delivered' THEN 1 ELSE 0 END)   AS Completed,
    SUM(CASE WHEN s.Status='Failed'    THEN 1 ELSE 0 END)   AS Failed,
    CAST(
        CAST(SUM(CASE WHEN s.Status='Delivered' THEN 1.0 ELSE 0 END) AS decimal(10,2))
        / NULLIF(COUNT(s.ShipmentID), 0) * 100
    AS decimal(5,1))                AS CompletionPct,
    CAST(
        CAST(SUM(CASE WHEN s.Status='Delivered' AND s.ActualDeliveryTime <= o.RequiredDate
                      THEN 1.0 ELSE 0 END) AS decimal(10,2))
        / NULLIF(SUM(CASE WHEN s.Status='Delivered' THEN 1 ELSE 0 END), 0) * 100
    AS decimal(5,1))                AS OnTimePct,
    SUM(ISNULL(s.MilesLogged, 0))   AS TotalMiles,
    -- star rating: 0-5 based on on-time %, invented by someone who left
    CASE
        WHEN SUM(CASE WHEN s.Status='Delivered' THEN 1 ELSE 0 END) = 0 THEN NULL
        WHEN (CAST(SUM(CASE WHEN s.Status='Delivered' AND s.ActualDeliveryTime<=o.RequiredDate
                            THEN 1.0 ELSE 0 END)
               / NULLIF(SUM(CASE WHEN s.Status='Delivered' THEN 1 ELSE 0 END),0)*100) AS int) >= 95 THEN 5
        WHEN (CAST(SUM(CASE WHEN s.Status='Delivered' AND s.ActualDeliveryTime<=o.RequiredDate
                            THEN 1.0 ELSE 0 END)
               / NULLIF(SUM(CASE WHEN s.Status='Delivered' THEN 1 ELSE 0 END),0)*100) AS int) >= 85 THEN 4
        WHEN (CAST(SUM(CASE WHEN s.Status='Delivered' AND s.ActualDeliveryTime<=o.RequiredDate
                            THEN 1.0 ELSE 0 END)
               / NULLIF(SUM(CASE WHEN s.Status='Delivered' THEN 1 ELSE 0 END),0)*100) AS int) >= 75 THEN 3
        WHEN (CAST(SUM(CASE WHEN s.Status='Delivered' AND s.ActualDeliveryTime<=o.RequiredDate
                            THEN 1.0 ELSE 0 END)
               / NULLIF(SUM(CASE WHEN s.Status='Delivered' THEN 1 ELSE 0 END),0)*100) AS int) >= 60 THEN 2
        ELSE 1
    END                             AS StarRating
FROM Drivers d
LEFT JOIN Shipments s ON d.DriverID = s.DriverID
    AND s.AssignedDate >= @dateFrom AND s.AssignedDate < @dateTo
LEFT JOIN Orders o ON s.OrderID = o.OrderID
WHERE d.Status <> 'Terminated'
GROUP BY d.DriverID, d.FirstName, d.LastName, d.HomeBase
ORDER BY OnTimePct DESC
GO

-- ============================================================
-- 35. usp_GetRevenueReport
-- Revenue by period. Dynamic SQL for flexible date grouping.
-- @GroupBy accepts 'Day', 'Week', 'Month' directly - not sanitized.
-- ============================================================
CREATE PROCEDURE usp_GetRevenueReport
    @DateFrom   datetime    = NULL,
    @DateTo     datetime    = NULL,
    @GroupBy    varchar(10) = 'Month',  -- Day, Week, Month - goes into SQL unsanitized
    @CustomerID int         = NULL
AS
SET NOCOUNT ON

SET @DateFrom = COALESCE(@DateFrom, DATEADD(month, -6, GETDATE()))
SET @DateTo   = COALESCE(@DateTo, GETDATE())

DECLARE @sql nvarchar(2000)

-- @GroupBy inserted directly into SQL - no validation
SET @sql = '
SELECT
    DATEPART(' + @GroupBy + ', i.InvoiceDate) AS Period,
    YEAR(i.InvoiceDate) AS [Year],
    COUNT(i.InvoiceID) AS InvoiceCount,
    SUM(i.TotalAmount) AS TotalBilled,
    SUM(i.PaidAmount) AS TotalCollected,
    SUM(i.TotalAmount - i.PaidAmount) AS Outstanding,
    COUNT(DISTINCT i.CustomerID) AS UniqueCustomers
FROM Invoices i
WHERE i.InvoiceDate BETWEEN ''' + CONVERT(varchar, @DateFrom, 120) + '''
                        AND ''' + CONVERT(varchar, @DateTo, 120) + '''
  AND i.Status NOT IN (''Void'')
'

IF @CustomerID IS NOT NULL
    SET @sql = @sql + ' AND i.CustomerID = ' + CAST(@CustomerID AS varchar) + ' '

SET @sql = @sql + '
GROUP BY DATEPART(' + @GroupBy + ', i.InvoiceDate), YEAR(i.InvoiceDate)
ORDER BY [Year], Period
'

EXEC(@sql)
GO

-- ============================================================
-- 36. usp_GetCustomerActivityReport
-- Customer leaderboard by volume. Nested subqueries instead
-- of JOINs because "it was clearer at the time".
-- ============================================================
CREATE PROCEDURE usp_GetCustomerActivityReport
    @DateFrom       datetime = NULL,
    @DateTo         datetime = NULL,
    @TopN           int      = 20,
    @CustomerType   char(1)  = NULL
AS
SET NOCOUNT ON

SET @DateFrom = COALESCE(@DateFrom, DATEADD(month, -3, GETDATE()))
SET @DateTo   = COALESCE(@DateTo, GETDATE())

SELECT TOP (@TopN)
    c.CustomerID,
    c.CompanyName,
    c.CustomerType,
    c.SalesRepName,
    -- subquery for order count (instead of JOIN + GROUP BY)
    (SELECT COUNT(*) FROM Orders o
     WHERE o.CustomerID = c.CustomerID
       AND o.OrderDate BETWEEN @DateFrom AND @DateTo) AS OrderCount,
    -- subquery for revenue
    (SELECT ISNULL(SUM(TotalCost), 0) FROM Orders o
     WHERE o.CustomerID = c.CustomerID
       AND o.OrderDate BETWEEN @DateFrom AND @DateTo
       AND o.Status = 'Delivered') AS TotalRevenue,
    -- subquery for avg order value
    (SELECT ISNULL(AVG(TotalCost), 0) FROM Orders o
     WHERE o.CustomerID = c.CustomerID
       AND o.OrderDate BETWEEN @DateFrom AND @DateTo
       AND o.Status = 'Delivered') AS AvgOrderValue,
    -- subquery for outstanding balance
    (SELECT ISNULL(SUM(TotalAmount - PaidAmount), 0) FROM Invoices i
     WHERE i.CustomerID = c.CustomerID
       AND i.Status NOT IN ('Paid', 'Void')) AS OutstandingBalance,
    c.CreditLimit,
    c.CurrentBalance
FROM Customers c
WHERE c.IsActive = 1
  AND (@CustomerType IS NULL OR c.CustomerType = @CustomerType)
  AND EXISTS (
      SELECT 1 FROM Orders o
      WHERE o.CustomerID = c.CustomerID
        AND o.OrderDate BETWEEN @DateFrom AND @DateTo
  )
ORDER BY
    (SELECT ISNULL(SUM(TotalCost), 0) FROM Orders o
     WHERE o.CustomerID = c.CustomerID
       AND o.OrderDate BETWEEN @DateFrom AND @DateTo
       AND o.Status = 'Delivered') DESC
-- Yes, the same subquery is in SELECT and ORDER BY. Query optimizer "handles it".
GO

-- ============================================================
-- 37. usp_GetDelayedShipmentsReport
-- Finds shipments that are running late.
-- "Late" = AssignedDate was >4 hours ago and not yet PickedUp,
--       OR PickedUp >8 hours ago and not Delivered.
-- The 4 and 8 are hardcoded. There was a ticket to make them
-- configurable. Ticket was closed as "won't fix" in 2017.
-- Also: DATEDIFF comparison could be replaced with index-friendly
-- expression but nobody has gotten around to it.
-- ============================================================
CREATE PROCEDURE usp_GetDelayedShipmentsReport
AS
SET NOCOUNT ON

SELECT
    s.ShipmentID,
    s.OrderID,
    o.Priority,
    o.RequiredDate,
    c.CompanyName,
    c.Phone,
    d.FirstName + ' ' + d.LastName      AS DriverName,
    d.CellPhone,
    o.PickupCity + ', ' + o.PickupState AS PickupLocation,
    o.DeliveryCity + ', ' + o.DeliveryState AS DeliveryLocation,
    s.Status,
    s.AssignedDate,
    s.ActualPickupTime,
    DATEDIFF(hour, s.AssignedDate, GETDATE())       AS HoursSinceAssigned,
    DATEDIFF(hour, s.ActualPickupTime, GETDATE())   AS HoursSincePickup,
    CASE
        WHEN s.Status = 'Assigned'  AND DATEDIFF(hour, s.AssignedDate, GETDATE()) > 4
            THEN 'Not picked up (>' + CAST(DATEDIFF(hour, s.AssignedDate, GETDATE()) AS varchar) + 'h)'
        WHEN s.Status = 'PickedUp'  AND DATEDIFF(hour, s.ActualPickupTime, GETDATE()) > 8
            THEN 'Not delivered (>' + CAST(DATEDIFF(hour, s.ActualPickupTime, GETDATE()) AS varchar) + 'h)'
        WHEN s.Status = 'InTransit' AND o.RequiredDate < GETDATE()
            THEN 'Past required date'
        ELSE 'Unknown delay'
    END AS DelayReason
FROM Shipments s
INNER JOIN Orders   o  ON s.OrderID   = o.OrderID
INNER JOIN Customers c ON o.CustomerID = c.CustomerID
INNER JOIN Drivers  d  ON s.DriverID   = d.DriverID
WHERE s.Status IN ('Assigned', 'PickedUp', 'InTransit')
  AND (
       (s.Status = 'Assigned'  AND DATEDIFF(hour, s.AssignedDate, GETDATE()) > 4)
    OR (s.Status = 'PickedUp'  AND DATEDIFF(hour, s.ActualPickupTime, GETDATE()) > 8)
    OR (s.Status = 'InTransit' AND o.RequiredDate < GETDATE())
  )
ORDER BY o.Priority ASC, o.RequiredDate ASC
GO
