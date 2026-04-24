-- ============================================================
-- Northwind Logistics - Triggers
-- WARNING: Business logic lives here. Change carefully.
-- Author: R.Kowalski 2009, modified K.Patel 2014, T.Wu 2017
-- ============================================================

USE NorthwindLogistics
GO

-- ============================================================
-- TR_Orders_UpdateModified
-- Keeps LastModifiedDate/By in sync. "By" comes from APP_USER
-- context variable set by the app. If not set, defaults to 'system'.
-- ============================================================
CREATE TRIGGER TR_Orders_UpdateModified
ON Orders
AFTER UPDATE
AS
BEGIN
    DECLARE @user varchar(50)
    SELECT @user = COALESCE(CAST(CONTEXT_INFO() AS varchar(50)), 'system')

    UPDATE Orders
    SET LastModifiedDate = GETDATE(),
        LastModifiedBy   = @user
    FROM Orders o
    INNER JOIN inserted i ON o.OrderID = i.OrderID
END
GO

-- ============================================================
-- TR_Orders_AuditStatusChange
-- Writes to AuditLog whenever order status changes.
-- Also sends to a notification queue (via table insert).
-- Added 2014 by K.Patel for compliance reasons.
-- TODO: This fires on EVERY update, not just status change.
--       Performance impact on bulk updates is bad. See incident 2017-09.
-- ============================================================
CREATE TRIGGER TR_Orders_AuditStatusChange
ON Orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON

    -- Only audit if status actually changed
    -- BUG: uses != which works but ANSI style would be <>
    INSERT INTO AuditLog (TableName, RecordID, Action, OldValues, NewValues, ChangedBy)
    SELECT
        'Orders',
        i.OrderID,
        'UPDATE',
        'Status=' + ISNULL(d.Status, 'NULL') + ';TotalCost=' + ISNULL(CAST(d.TotalCost AS varchar), 'NULL'),
        'Status=' + ISNULL(i.Status, 'NULL') + ';TotalCost=' + ISNULL(CAST(i.TotalCost AS varchar), 'NULL'),
        COALESCE(CAST(CONTEXT_INFO() AS varchar(50)), 'system')
    FROM inserted i
    INNER JOIN deleted d ON i.OrderID = d.OrderID
    WHERE i.Status != d.Status
       OR ISNULL(i.TotalCost, 0) != ISNULL(d.TotalCost, 0)
END
GO

-- ============================================================
-- TR_Shipments_AutoUpdateOrderStatus
-- THE TROUBLEMAKER. When a shipment status changes, this trigger
-- automatically updates the parent order status.
-- This was "clever" in 2009. Now it causes mysterious order
-- status changes that nobody can explain.
-- K.Patel tried to remove it in 2016. It broke everything.
-- ============================================================
CREATE TRIGGER TR_Shipments_AutoUpdateOrderStatus
ON Shipments
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @shipmentID int, @orderID int, @newShipStatus varchar(20)
    DECLARE @newOrderStatus varchar(20)

    -- cursor because "safer" (original comment)
    DECLARE status_cursor CURSOR FOR
        SELECT i.ShipmentID, i.OrderID, i.Status
        FROM inserted i
        INNER JOIN deleted d ON i.ShipmentID = d.ShipmentID
        WHERE i.Status <> d.Status

    OPEN status_cursor
    FETCH NEXT FROM status_cursor INTO @shipmentID, @orderID, @newShipStatus

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Map shipment status to order status
        -- Note: 'Assigned' shipment status does NOT change order (already set when shipment created)
        SET @newOrderStatus = NULL

        IF @newShipStatus = 'PickedUp'      SET @newOrderStatus = 'PickedUp'
        IF @newShipStatus = 'InTransit'     SET @newOrderStatus = 'InTransit'
        IF @newShipStatus = 'Delivered'     SET @newOrderStatus = 'Delivered'
        IF @newShipStatus = 'Failed'        SET @newOrderStatus = 'Failed'
        IF @newShipStatus = 'Cancelled'     SET @newOrderStatus = 'Cancelled'

        IF @newOrderStatus IS NOT NULL
        BEGIN
            UPDATE Orders
            SET Status = @newOrderStatus
            WHERE OrderID = @orderID
            -- Note: This fires TR_Orders_AuditStatusChange too.
            -- So one shipment update = 2 trigger fires = performance fun.
        END

        FETCH NEXT FROM status_cursor INTO @shipmentID, @orderID, @newShipStatus
    END

    CLOSE status_cursor
    DEALLOCATE status_cursor
END
GO

-- ============================================================
-- TR_Invoices_UpdateBalance
-- When invoice is paid/updated, recalculates customer balance.
-- "Balance" = sum of all unpaid invoice amounts for customer.
-- This recalculates the ENTIRE customer balance from scratch
-- on every invoice update. Slow for customers with many invoices.
-- ============================================================
CREATE TRIGGER TR_Invoices_UpdateBalance
ON Invoices
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON

    -- Recalculate for all affected customers
    UPDATE Customers
    SET CurrentBalance = (
        SELECT ISNULL(SUM(TotalAmount - PaidAmount), 0)
        FROM Invoices
        WHERE CustomerID = Customers.CustomerID
          AND Status NOT IN ('Void', 'Paid')
    )
    WHERE CustomerID IN (SELECT DISTINCT CustomerID FROM inserted)
END
GO

-- ============================================================
-- TR_Customers_PreventDeleteWithOrders
-- Instead of FK enforcement, someone wrote a trigger.
-- The FK exists but this was added "just to be safe" in 2011.
-- ============================================================
CREATE TRIGGER TR_Customers_PreventDeleteWithOrders
ON Customers
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON
    DECLARE @cid int
    SELECT @cid = CustomerID FROM deleted

    IF EXISTS (SELECT 1 FROM Orders WHERE CustomerID = @cid)
    BEGIN
        RAISERROR('Cannot delete customer with existing orders. Set IsActive=0 instead.', 16, 1)
        RETURN
    END

    DELETE FROM Customers WHERE CustomerID = @cid
END
GO
