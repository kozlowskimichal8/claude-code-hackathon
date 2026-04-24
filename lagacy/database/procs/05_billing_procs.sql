-- ============================================================
-- Billing Stored Procedures (7 procs)
-- ============================================================
USE NorthwindLogistics
GO

-- ============================================================
-- 26. usp_CalculateOrderCost
-- THE PRICING FUNCTION. All business pricing logic is here.
-- Called from usp_CreateOrder and usp_ProcessEndOfDay.
-- Hardcoded fuel surcharge, hazmat fee, and urgency premium.
-- "Should be driven by PricingRules table" - TODO since 2013.
-- ============================================================
CREATE PROCEDURE usp_CalculateOrderCost
    @OrderID    int,
    @Recalculate bit = 0   -- 0 = skip if already calculated, 1 = force recalc
AS
SET NOCOUNT ON

DECLARE @customerType char(1), @weight decimal(10,2), @miles int
DECLARE @priority char(1), @isHazmat bit, @discountPct decimal(5,2)

SELECT
    @customerType   = c.CustomerType,
    @weight         = ISNULL(o.TotalWeight, 0),
    @miles          = ISNULL(o.EstimatedMiles, 50),   -- default 50 miles if not set
    @priority       = o.Priority,
    @isHazmat       = o.IsHazmat,
    @discountPct    = ISNULL(o.DiscountPct, 0)
FROM Orders o
INNER JOIN Customers c ON o.CustomerID = c.CustomerID
WHERE o.OrderID = @OrderID

IF @customerType IS NULL
BEGIN
    RAISERROR('Order %d not found', 16, 1, @OrderID)
    RETURN -1
END

-- Skip if already calculated (unless forced)
IF @Recalculate = 0
BEGIN
    DECLARE @existingCost money
    SELECT @existingCost = TotalCost FROM Orders WHERE OrderID = @OrderID
    IF @existingCost IS NOT NULL AND @existingCost > 0
        RETURN 0
END

-- Look up base rate from PricingRules
-- Government customers fall through to 'R' pricing (known issue, Finance aware)
DECLARE @baseRate money, @perMileRate money
DECLARE @lookupType char(1) = @customerType
IF @lookupType = 'G' SET @lookupType = 'R'

SELECT TOP 1 @baseRate = BaseRate, @perMileRate = PerMileRate
FROM PricingRules
WHERE CustomerType = @lookupType
  AND @weight >= WeightFrom
  AND @weight < WeightTo
  AND IsActive = 1
  AND EffectiveDate <= GETDATE()
  AND (ExpiryDate IS NULL OR ExpiryDate > GETDATE())
ORDER BY EffectiveDate DESC

IF @baseRate IS NULL
BEGIN
    -- Fallback: use hardcoded rate. "Shouldn't happen" but it does for weights > 99999
    SET @baseRate = 500.00
    SET @perMileRate = 0.90
    INSERT INTO AuditLog (TableName, RecordID, Action, NewValues, ChangedBy)
    VALUES ('Orders', @OrderID, 'WARN', 'No pricing rule found, used fallback rate', 'system')
END

-- Base calculation
DECLARE @cost money
SET @cost = @baseRate + (@miles * @perMileRate)

-- Fuel surcharge: hardcoded 15%
-- TODO: read from SystemSettings.FuelSurcharge
SET @cost = @cost * 1.15

-- Hazmat fee: hardcoded $75 flat
IF @isHazmat = 1
    SET @cost = @cost + 75.00

-- Priority upcharge
IF @priority = 'H'      SET @cost = @cost * 1.10   -- 10% for High
IF @priority = 'U'      SET @cost = @cost * 1.25   -- 25% for Urgent

-- Apply discount
IF @discountPct > 0
    SET @cost = @cost * (1.0 - @discountPct / 100.0)

-- Round to 2 decimal places
SET @cost = ROUND(@cost, 2)

UPDATE Orders SET TotalCost = @cost WHERE OrderID = @OrderID

RETURN 0
GO

-- ============================================================
-- 27. usp_CreateInvoice
-- Creates invoice for a delivered order.
-- Tax is always 0 (logistics exempt) but the column exists.
-- Calling this twice creates duplicate invoices (no idempotency guard
-- was added after the 2021 incident; see comments in usp_CompleteShipment).
-- ============================================================
CREATE PROCEDURE usp_CreateInvoice
    @OrderID        int,
    @CreatedBy      varchar(50) = NULL,
    @NewInvoiceID   int         OUTPUT
AS
SET NOCOUNT ON
BEGIN TRY
    BEGIN TRANSACTION

    -- Get order details
    DECLARE @customerID int, @totalCost money, @discountPct decimal(5,2), @status varchar(20)
    SELECT
        @customerID  = CustomerID,
        @totalCost   = TotalCost,
        @discountPct = DiscountPct,
        @status      = Status
    FROM Orders WHERE OrderID = @OrderID

    IF @customerID IS NULL
    BEGIN
        RAISERROR('Order %d not found', 16, 1, @OrderID)
        ROLLBACK; SET @NewInvoiceID = -1; RETURN -1
    END

    -- Recalculate cost if missing
    IF @totalCost IS NULL OR @totalCost = 0
    BEGIN
        EXEC usp_CalculateOrderCost @OrderID, 1
        SELECT @totalCost = TotalCost FROM Orders WHERE OrderID = @OrderID
    END

    DECLARE @subTotal money = ISNULL(@totalCost, 0)
    DECLARE @discountAmt money = ROUND(@subTotal * (ISNULL(@discountPct,0) / 100.0), 2)
    -- Note: discount is already baked into TotalCost by usp_CalculateOrderCost,
    -- but we record it separately on the invoice for line-item visibility.
    -- This means the math looks wrong on the invoice. Accounting knows.
    DECLARE @taxAmt money = 0.00  -- always zero
    DECLARE @total money = @subTotal - @discountAmt + @taxAmt

    -- Payment terms from settings
    DECLARE @paymentTerms int = 30
    DECLARE @settingVal varchar(500)
    SELECT @settingVal = SettingValue FROM SystemSettings WHERE SettingKey = 'DefaultPaymentTerms'
    IF @settingVal IS NOT NULL SET @paymentTerms = CAST(@settingVal AS int)

    INSERT INTO Invoices (
        CustomerID, OrderID, InvoiceDate, DueDate,
        SubTotal, TaxAmount, DiscountAmount, TotalAmount, PaidAmount,
        Status, CreatedBy
    )
    VALUES (
        @customerID, @OrderID, GETDATE(),
        DATEADD(day, @paymentTerms, GETDATE()),
        @subTotal, @taxAmt, @discountAmt, @total, 0.00,
        'Draft', ISNULL(@CreatedBy, 'system')
    )

    SET @NewInvoiceID = SCOPE_IDENTITY()

    UPDATE Orders SET IsBilled = 1 WHERE OrderID = @OrderID

    COMMIT
    RETURN 0

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK
    RAISERROR('usp_CreateInvoice failed: %s', 16, 1, ERROR_MESSAGE())
    SET @NewInvoiceID = -1
    RETURN -1
END CATCH
GO

-- ============================================================
-- 28. usp_ProcessPayment
-- Records payment against invoice. Not idempotent.
-- Duplicate ReferenceNumbers are accepted.
-- "We trust accounting not to double-enter" - 2011 comment
-- ============================================================
CREATE PROCEDURE usp_ProcessPayment
    @InvoiceID      int,
    @Amount         money,
    @PaymentMethod  varchar(20),
    @ReferenceNumber varchar(100) = NULL,
    @ProcessedBy    varchar(50) = NULL,
    @Notes          varchar(200) = NULL,
    @NewPaymentID   int         OUTPUT
AS
SET NOCOUNT ON
BEGIN TRY
    BEGIN TRANSACTION

    DECLARE @invoiceTotal money, @alreadyPaid money, @invStatus varchar(20), @customerID int
    SELECT @invoiceTotal = TotalAmount, @alreadyPaid = PaidAmount,
           @invStatus = Status, @customerID = CustomerID
    FROM Invoices WHERE InvoiceID = @InvoiceID

    IF @invoiceTotal IS NULL
    BEGIN
        RAISERROR('Invoice %d not found', 16, 1, @InvoiceID)
        ROLLBACK; SET @NewPaymentID = -1; RETURN -1
    END

    IF @invStatus = 'Void'
    BEGIN
        RAISERROR('Cannot process payment on voided invoice %d', 16, 1, @InvoiceID)
        ROLLBACK; SET @NewPaymentID = -1; RETURN -1
    END

    INSERT INTO Payments (InvoiceID, PaymentDate, Amount, PaymentMethod,
                          ReferenceNumber, ProcessedBy, Notes)
    VALUES (@InvoiceID, GETDATE(), @Amount, @PaymentMethod,
            @ReferenceNumber, @ProcessedBy, @Notes)

    SET @NewPaymentID = SCOPE_IDENTITY()

    DECLARE @newPaidTotal money = @alreadyPaid + @Amount

    DECLARE @newStatus varchar(20)
    IF @newPaidTotal >= @invoiceTotal
        SET @newStatus = 'Paid'
    ELSE IF @newPaidTotal > 0
        SET @newStatus = 'PartialPaid'
    ELSE
        SET @newStatus = @invStatus

    UPDATE Invoices
    SET PaidAmount = @newPaidTotal,
        Status     = @newStatus
    WHERE InvoiceID = @InvoiceID

    -- TR_Invoices_UpdateBalance fires here to update customer balance

    COMMIT
    RETURN 0

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK
    RAISERROR('usp_ProcessPayment failed: %s', 16, 1, ERROR_MESSAGE())
    SET @NewPaymentID = -1
    RETURN -1
END CATCH
GO

-- ============================================================
-- 29. usp_GetInvoice
-- Returns invoice with payment history and order summary.
-- Two result sets: invoice header, payment list.
-- ============================================================
CREATE PROCEDURE usp_GetInvoice
    @InvoiceID  int     = NULL,
    @OrderID    int     = NULL
AS
SET NOCOUNT ON

IF @InvoiceID IS NULL AND @OrderID IS NULL
BEGIN
    RAISERROR('Provide @InvoiceID or @OrderID', 16, 1)
    RETURN -1
END

-- Result set 1: invoice header
SELECT
    i.*,
    c.CompanyName, c.ContactName, c.Address, c.City, c.State, c.ZipCode,
    c.Email         AS CustomerEmail,
    o.PickupCity    AS OriginCity,
    o.DeliveryCity  AS DestCity,
    o.TotalWeight,
    o.Status        AS OrderStatus
FROM Invoices i
INNER JOIN Customers c ON i.CustomerID = c.CustomerID
INNER JOIN Orders    o ON i.OrderID    = o.OrderID
WHERE (@InvoiceID IS NOT NULL AND i.InvoiceID = @InvoiceID)
   OR (@OrderID   IS NOT NULL AND i.OrderID   = @OrderID)

-- Result set 2: payment history
SELECT p.*
FROM Payments p
WHERE p.InvoiceID IN (
    SELECT InvoiceID FROM Invoices
    WHERE (@InvoiceID IS NOT NULL AND InvoiceID = @InvoiceID)
       OR (@OrderID   IS NOT NULL AND OrderID   = @OrderID)
)
ORDER BY p.PaymentDate
GO

-- ============================================================
-- 30. usp_ApplyDiscount
-- Applies or updates discount on an order (and existing invoice if any).
-- No approval workflow. Any user with DB access can give 100% discount.
-- "Internal tool, trust the staff" - original comment
-- ============================================================
CREATE PROCEDURE usp_ApplyDiscount
    @OrderID        int,
    @DiscountPct    decimal(5,2),
    @AppliedBy      varchar(50) = NULL,
    @Reason         varchar(200) = NULL
AS
SET NOCOUNT ON
BEGIN TRY
    BEGIN TRANSACTION

    IF @DiscountPct < 0 OR @DiscountPct > 100
    BEGIN
        RAISERROR('Discount must be between 0 and 100', 16, 1)
        ROLLBACK; RETURN -1
    END

    UPDATE Orders SET DiscountPct = @DiscountPct WHERE OrderID = @OrderID

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('Order %d not found', 16, 1, @OrderID)
        ROLLBACK; RETURN -1
    END

    -- Recalculate cost with new discount
    EXEC usp_CalculateOrderCost @OrderID, 1

    -- If invoice exists, update it too
    DECLARE @invoiceID int
    SELECT TOP 1 @invoiceID = InvoiceID FROM Invoices
    WHERE OrderID = @OrderID AND Status NOT IN ('Paid', 'Void')
    ORDER BY InvoiceID DESC

    IF @invoiceID IS NOT NULL
    BEGIN
        DECLARE @newCost money
        SELECT @newCost = TotalCost FROM Orders WHERE OrderID = @OrderID

        DECLARE @newDiscountAmt money = ROUND(@newCost * (@DiscountPct / 100.0), 2)

        UPDATE Invoices SET
            SubTotal       = @newCost,
            DiscountAmount = @newDiscountAmt,
            TotalAmount    = @newCost - @newDiscountAmt
        WHERE InvoiceID = @invoiceID
        -- Note: if customer already made a partial payment this may put
        -- PaidAmount > TotalAmount. No check for that.
    END

    -- Audit the discount
    INSERT INTO AuditLog (TableName, RecordID, Action, NewValues, ChangedBy)
    VALUES ('Orders', @OrderID, 'DISCOUNT',
            'DiscountPct=' + CAST(@DiscountPct AS varchar) +
            ISNULL('; Reason=' + @Reason, ''),
            ISNULL(@AppliedBy, 'system'))

    COMMIT
    RETURN 0

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK
    RAISERROR('usp_ApplyDiscount failed: %s', 16, 1, ERROR_MESSAGE())
    RETURN -1
END CATCH
GO

-- ============================================================
-- 31. usp_GetOutstandingInvoices
-- Returns unpaid/overdue invoices for collections follow-up.
-- Sorted by days overdue descending.
-- ============================================================
CREATE PROCEDURE usp_GetOutstandingInvoices
    @CustomerID         int     = NULL,
    @OverdueOnly        bit     = 0,
    @MinAmount          money   = NULL
AS
SET NOCOUNT ON

SELECT
    i.InvoiceID,
    i.CustomerID,
    c.CompanyName,
    c.ContactName,
    c.Phone,
    c.Email,
    i.OrderID,
    i.InvoiceDate,
    i.DueDate,
    i.TotalAmount,
    i.PaidAmount,
    i.TotalAmount - i.PaidAmount    AS BalanceDue,
    i.Status,
    DATEDIFF(day, i.DueDate, GETDATE()) AS DaysOverdue,
    c.CustomerType,
    c.SalesRepName
FROM Invoices i
INNER JOIN Customers c ON i.CustomerID = c.CustomerID
WHERE i.Status NOT IN ('Paid', 'Void')
  AND (@CustomerID IS NULL OR i.CustomerID = @CustomerID)
  AND (@OverdueOnly = 0 OR i.DueDate < GETDATE())
  AND (@MinAmount IS NULL OR (i.TotalAmount - i.PaidAmount) >= @MinAmount)
ORDER BY DaysOverdue DESC, i.TotalAmount - i.PaidAmount DESC
GO

-- ============================================================
-- 32. usp_GenerateMonthlyStatement
-- Generates customer statement for a month.
-- Cursor + dynamic SQL. Slow. Called manually from admin page.
-- Takes ~45 seconds for customers with >200 orders.
-- Rewrote attempt in 2019 abandoned mid-way (half the logic is
-- still commented out below).
-- ============================================================
CREATE PROCEDURE usp_GenerateMonthlyStatement
    @CustomerID int,
    @Year       int,
    @Month      int
AS
SET NOCOUNT ON

DECLARE @startDate datetime, @endDate datetime
SET @startDate = CAST(CAST(@Year AS varchar) + '-' + CAST(@Month AS varchar) + '-01' AS datetime)
SET @endDate   = DATEADD(month, 1, @startDate)

-- Statement header
SELECT
    c.CustomerID,
    c.CompanyName,
    c.ContactName,
    c.Address + ', ' + c.City + ', ' + c.State + ' ' + c.ZipCode AS BillingAddress,
    c.CustomerType,
    c.CreditLimit,
    c.CurrentBalance,
    @startDate  AS StatementFrom,
    DATEADD(day, -1, @endDate) AS StatementTo

-- Transactions (orders + payments) using cursor for chronological merge
-- This is the "classic" approach from the original dev. Don't touch.
CREATE TABLE #Transactions (
    TxDate      datetime,
    TxType      varchar(20),
    Reference   varchar(50),
    Description varchar(200),
    Charges     money,
    Payments    money,
    Balance     money
)

DECLARE @runningBalance money = 0
DECLARE @txDate datetime, @txType varchar(20), @ref varchar(50),
        @desc varchar(200), @charges money, @pmts money

-- Build unified transaction list
-- Part 1: invoices
DECLARE tx_cursor CURSOR FOR
    SELECT i.InvoiceDate, 'Invoice', 'INV-' + CAST(i.InvoiceID AS varchar),
           'Delivery: ' + o.PickupCity + ' to ' + o.DeliveryCity,
           i.TotalAmount, 0
    FROM Invoices i
    INNER JOIN Orders o ON i.OrderID = o.OrderID
    WHERE i.CustomerID = @CustomerID
      AND i.InvoiceDate >= @startDate AND i.InvoiceDate < @endDate

    UNION ALL

    -- Part 2: payments
    SELECT p.PaymentDate, 'Payment', 'PMT-' + CAST(p.PaymentID AS varchar),
           p.PaymentMethod + ISNULL(': ' + p.ReferenceNumber, ''),
           0, p.Amount
    FROM Payments p
    INNER JOIN Invoices i ON p.InvoiceID = i.InvoiceID
    WHERE i.CustomerID = @CustomerID
      AND p.PaymentDate >= @startDate AND p.PaymentDate < @endDate

    ORDER BY 1 ASC  -- order by TxDate

OPEN tx_cursor
FETCH NEXT FROM tx_cursor INTO @txDate, @txType, @ref, @desc, @charges, @pmts

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @runningBalance = @runningBalance + @charges - @pmts

    INSERT INTO #Transactions VALUES
    (@txDate, @txType, @ref, @desc, @charges, @pmts, @runningBalance)

    FETCH NEXT FROM tx_cursor INTO @txDate, @txType, @ref, @desc, @charges, @pmts
END

CLOSE tx_cursor
DEALLOCATE tx_cursor

SELECT * FROM #Transactions ORDER BY TxDate

-- Summary totals
SELECT
    SUM(Charges)  AS TotalCharges,
    SUM(Payments) AS TotalPayments,
    MAX(Balance)  AS ClosingBalance
FROM #Transactions

DROP TABLE #Transactions

/*
-- 2019 rewrite attempt - abandoned, leaving for reference
-- Idea was to use a single set-based query with running total
-- via SUM() OVER (ORDER BY TxDate) but SQL 2008 doesn't support
-- the windowed aggregation syntax we wanted. Upgrade is "planned".

SELECT
    TxDate, TxType, Reference, Description, Charges, Payments,
    SUM(Charges - Payments) OVER (ORDER BY TxDate ROWS UNBOUNDED PRECEDING) AS RunningBalance
FROM (
    ...
) AllTx
ORDER BY TxDate
*/
GO
