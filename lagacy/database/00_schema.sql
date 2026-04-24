-- ============================================================
-- Northwind Logistics - Database Schema
-- Created: 2009-03-14  Author: R.Kowalski
-- Last Modified: 2018-11-02  By: anonymous (see change log)
-- ============================================================
-- NOTE: Run this on SQL Server 2008 R2 or later.
--       DO NOT run on production without DBA sign-off.
--       Contact: IT Helpdesk ext 4400 (Ranjit retired, new person TBD)
-- ============================================================

USE master
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'NorthwindLogistics')
BEGIN
    -- DANGER: drops everything. Only run on dev.
    ALTER DATABASE NorthwindLogistics SET SINGLE_USER WITH ROLLBACK IMMEDIATE
    DROP DATABASE NorthwindLogistics
END
GO

CREATE DATABASE NorthwindLogistics
GO

USE NorthwindLogistics
GO

-- ============================================================
-- CUSTOMERS
-- CustomerType: R=Regular, P=Premium, C=Contract
-- NOTE: There's also a 'G' type (Government) added in 2016 but
--       pricing rules don't handle it yet (see TODO in billing procs)
-- ============================================================
CREATE TABLE Customers (
    CustomerID      int IDENTITY(1,1) NOT NULL,
    AccountNum      varchar(20)       NULL,   -- populated for Contract customers only
    CompanyName     varchar(100)      NOT NULL,
    ContactName     varchar(100)      NULL,
    Address         varchar(200)      NULL,
    City            varchar(50)       NULL,
    State           char(2)           NULL,
    ZipCode         varchar(10)       NULL,
    Phone           varchar(20)       NULL,
    Fax             varchar(20)       NULL,   -- lol yes we still use fax
    Email           varchar(100)      NULL,
    CustomerType    char(1)           NOT NULL DEFAULT 'R',
    CreditLimit     money             NOT NULL DEFAULT 5000.00,
    CurrentBalance  money             NOT NULL DEFAULT 0.00,
    CreatedDate     datetime          NOT NULL DEFAULT GETDATE(),
    IsActive        bit               NOT NULL DEFAULT 1,
    Notes           text              NULL,   -- should be varchar(max) but migration was scary
    SalesRepName    varchar(100)      NULL,   -- DENORMALIZED: was supposed to be FK to staff table
                                              -- staff table got dropped in 2013 incident
    CONSTRAINT PK_Customers PRIMARY KEY (CustomerID)
)
GO

-- ============================================================
-- ORDERS
-- Status values (varchar, not int - was int before 2012 migration,
--   some old procs still use integer comparisons, beware):
--   'Pending'   = received, not yet assigned
--   'Assigned'  = driver assigned
--   'PickedUp'  = driver confirmed pickup
--   'InTransit' = on the way
--   'Delivered' = completed
--   'Cancelled' = cancelled before pickup
--   'Failed'    = attempted delivery failed
--   'OnHold'    = added 2017, billing dispute or address issue
-- Priority: N=Normal, H=High, U=Urgent
-- ============================================================
CREATE TABLE Orders (
    OrderID             int IDENTITY(1000,1)  NOT NULL,  -- starts at 1000 for "legacy order IDs" compatibility
    CustomerID          int                   NOT NULL,
    OrderDate           datetime              NOT NULL DEFAULT GETDATE(),
    RequiredDate        datetime              NULL,
    ShippedDate         datetime              NULL,
    Status              varchar(20)           NOT NULL DEFAULT 'Pending',
    PickupAddress       varchar(200)          NULL,
    PickupCity          varchar(50)           NULL,
    PickupState         char(2)               NULL,
    PickupZip           varchar(10)           NULL,
    DeliveryAddress     varchar(200)          NULL,
    DeliveryCity        varchar(50)           NULL,
    DeliveryState       char(2)               NULL,
    DeliveryZip         varchar(10)           NULL,
    TotalWeight         decimal(10,2)         NULL,
    SpecialInstructions varchar(500)          NULL,
    Priority            char(1)               NOT NULL DEFAULT 'N',
    EstimatedMiles      int                   NULL,
    TotalCost           money                 NULL,      -- calculated by usp_CalculateOrderCost
    IsBilled            bit                   NOT NULL DEFAULT 0,
    DiscountPct         decimal(5,2)          NOT NULL DEFAULT 0.00,
    CreatedBy           varchar(50)           NULL,
    LastModifiedBy      varchar(50)           NULL,
    LastModifiedDate    datetime              NULL,
    -- added 2015 for insurance compliance, not always populated
    InsuranceValue      money                 NULL,
    IsHazmat            bit                   NOT NULL DEFAULT 0,
    CONSTRAINT PK_Orders PRIMARY KEY (OrderID),
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
)
GO

-- ============================================================
-- ORDER ITEMS
-- ============================================================
CREATE TABLE OrderItems (
    ItemID          int IDENTITY(1,1)   NOT NULL,
    OrderID         int                 NOT NULL,
    Description     varchar(200)        NOT NULL,
    Quantity        int                 NOT NULL DEFAULT 1,
    WeightLbs       decimal(10,2)       NULL,
    LengthIn        decimal(8,2)        NULL,
    WidthIn         decimal(8,2)        NULL,
    HeightIn        decimal(8,2)        NULL,
    IsFragile       bit                 NOT NULL DEFAULT 0,
    UnitCost        money               NULL,   -- sometimes populated, sometimes not
    CONSTRAINT PK_OrderItems PRIMARY KEY (ItemID),
    CONSTRAINT FK_OrderItems_Orders FOREIGN KEY (OrderID) REFERENCES Orders(OrderID)
)
GO

-- ============================================================
-- DRIVERS
-- Status: Available, OnRoute, OffDuty, Terminated, LOA
-- LOA (Leave of Absence) added 2019, not all code handles it
-- ============================================================
CREATE TABLE Drivers (
    DriverID            int IDENTITY(1,1)   NOT NULL,
    FirstName           varchar(50)         NOT NULL,
    LastName            varchar(50)         NOT NULL,
    LicenseNumber       varchar(30)         NULL,
    LicenseExpiryDate   datetime            NULL,
    Phone               varchar(20)         NULL,
    CellPhone           varchar(20)         NULL,
    Email               varchar(100)        NULL,
    Status              varchar(20)         NOT NULL DEFAULT 'Available',
    HiredDate           datetime            NULL,
    TerminatedDate      datetime            NULL,
    HourlyRate          money               NULL,
    TotalMilesDriven    int                 NOT NULL DEFAULT 0,
    HomeBase            varchar(100)        NULL,
    EmergencyContact    varchar(100)        NULL,
    EmergencyPhone      varchar(20)         NULL,
    -- added for GPS integration project (never fully deployed)
    LastKnownLat        decimal(9,6)        NULL,
    LastKnownLng        decimal(9,6)        NULL,
    LastLocationUpdate  datetime            NULL,
    CONSTRAINT PK_Drivers PRIMARY KEY (DriverID)
)
GO

-- ============================================================
-- VEHICLES
-- Type: Van, LightTruck, HeavyTruck, Semi, Refrigerated
-- ============================================================
CREATE TABLE Vehicles (
    VehicleID           int IDENTITY(1,1)   NOT NULL,
    LicensePlate        varchar(20)         NOT NULL,
    Make                varchar(50)         NULL,
    Model               varchar(50)         NULL,
    Year                int                 NULL,
    MaxWeightLbs        decimal(10,2)       NULL,
    VehicleType         varchar(20)         NULL,
    Status              varchar(20)         NOT NULL DEFAULT 'Available',
    LastServiceDate     datetime            NULL,
    NextServiceDue      datetime            NULL,   -- added 2020, mostly NULL
    CurrentMileage      int                 NOT NULL DEFAULT 0,
    AssignedDriverID    int                 NULL,   -- soft assignment, not enforced by FK
    Notes               varchar(500)        NULL,
    CONSTRAINT PK_Vehicles PRIMARY KEY (VehicleID)
)
GO

-- ============================================================
-- SHIPMENTS
-- One shipment per order (1:1). There was a plan to support
-- multi-leg shipments but it never happened.
-- Status: Assigned, PickedUp, InTransit, Delivered, Failed, Cancelled
-- ============================================================
CREATE TABLE Shipments (
    ShipmentID          int IDENTITY(1,1)   NOT NULL,
    OrderID             int                 NOT NULL,
    DriverID            int                 NOT NULL,
    VehicleID           int                 NOT NULL,
    AssignedDate        datetime            NOT NULL DEFAULT GETDATE(),
    StartTime           datetime            NULL,
    EndTime             datetime            NULL,
    Status              varchar(20)         NOT NULL DEFAULT 'Assigned',
    ActualPickupTime    datetime            NULL,
    ActualDeliveryTime  datetime            NULL,
    FailureReason       varchar(500)        NULL,
    ProofOfDeliveryPath varchar(500)        NULL,   -- UNC path to scanned image \\fileserver01\pod\...
    DriverNotes         varchar(500)        NULL,
    MilesLogged         int                 NULL,
    CONSTRAINT PK_Shipments PRIMARY KEY (ShipmentID),
    CONSTRAINT FK_Shipments_Orders   FOREIGN KEY (OrderID)   REFERENCES Orders(OrderID),
    CONSTRAINT FK_Shipments_Drivers  FOREIGN KEY (DriverID)  REFERENCES Drivers(DriverID),
    CONSTRAINT FK_Shipments_Vehicles FOREIGN KEY (VehicleID) REFERENCES Vehicles(VehicleID)
)
GO

-- ============================================================
-- INVOICES
-- Status: Draft, Sent, Paid, PartialPaid, Overdue, Void
-- ============================================================
CREATE TABLE Invoices (
    InvoiceID       int IDENTITY(5000,1)    NOT NULL,   -- starts at 5000, accounting said so
    CustomerID      int                     NOT NULL,
    OrderID         int                     NOT NULL,
    InvoiceDate     datetime                NOT NULL DEFAULT GETDATE(),
    DueDate         datetime                NULL,
    SubTotal        money                   NOT NULL DEFAULT 0,
    TaxAmount       money                   NOT NULL DEFAULT 0,
    DiscountAmount  money                   NOT NULL DEFAULT 0,
    TotalAmount     money                   NOT NULL DEFAULT 0,
    PaidAmount      money                   NOT NULL DEFAULT 0,
    Status          varchar(20)             NOT NULL DEFAULT 'Draft',
    Notes           varchar(500)            NULL,
    CreatedBy       varchar(50)             NULL,
    SentDate        datetime                NULL,
    CONSTRAINT PK_Invoices PRIMARY KEY (InvoiceID),
    CONSTRAINT FK_Invoices_Customers FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
    CONSTRAINT FK_Invoices_Orders    FOREIGN KEY (OrderID)    REFERENCES Orders(OrderID)
)
GO

-- ============================================================
-- PAYMENTS
-- ============================================================
CREATE TABLE Payments (
    PaymentID       int IDENTITY(1,1)   NOT NULL,
    InvoiceID       int                 NOT NULL,
    PaymentDate     datetime            NOT NULL DEFAULT GETDATE(),
    Amount          money               NOT NULL,
    PaymentMethod   varchar(20)         NULL,   -- Check, ACH, CreditCard, Cash, Wire
    ReferenceNumber varchar(100)        NULL,
    ProcessedBy     varchar(50)         NULL,
    Notes           varchar(200)        NULL,
    CONSTRAINT PK_Payments PRIMARY KEY (PaymentID),
    CONSTRAINT FK_Payments_Invoices FOREIGN KEY (InvoiceID) REFERENCES Invoices(InvoiceID)
)
GO

-- ============================================================
-- PRICING RULES
-- CustomerType matches Customers.CustomerType
-- Weight tiers: if order weight falls in [WeightFrom, WeightTo)
--   cost = BaseRate + (EstimatedMiles * PerMileRate)
-- TODO: fuel surcharge not handled here, it's hardcoded in
--       usp_CalculateOrderCost as 0.15 (15%). Should be a rule.
-- ============================================================
CREATE TABLE PricingRules (
    RuleID          int IDENTITY(1,1)   NOT NULL,
    CustomerType    char(1)             NOT NULL,
    WeightFrom      decimal(10,2)       NOT NULL,
    WeightTo        decimal(10,2)       NOT NULL,
    BaseRate        money               NOT NULL,
    PerMileRate     money               NOT NULL,
    EffectiveDate   datetime            NOT NULL,
    ExpiryDate      datetime            NULL,
    IsActive        bit                 NOT NULL DEFAULT 1,
    CONSTRAINT PK_PricingRules PRIMARY KEY (RuleID)
)
GO

-- ============================================================
-- AUDIT LOG
-- Written to by triggers and some stored procs.
-- Grew to 80M rows by 2021, DBA trimmed it, lost history.
-- ============================================================
CREATE TABLE AuditLog (
    LogID       int IDENTITY(1,1)   NOT NULL,
    TableName   varchar(50)         NULL,
    RecordID    int                 NULL,
    Action      varchar(10)         NULL,   -- INSERT, UPDATE, DELETE
    OldValues   text                NULL,
    NewValues   text                NULL,
    ChangedBy   varchar(50)         NULL,
    ChangedDate datetime            NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_AuditLog PRIMARY KEY (LogID)
)
GO

-- ============================================================
-- SYSTEM SETTINGS  (key-value config store)
-- ============================================================
CREATE TABLE SystemSettings (
    SettingKey      varchar(50)     NOT NULL,
    SettingValue    varchar(500)    NULL,
    Description     varchar(200)    NULL,
    LastModified    datetime        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_SystemSettings PRIMARY KEY (SettingKey)
)
GO

-- ============================================================
-- ARCHIVE TABLES (used by nightly batch)
-- Same schema as Orders/Shipments but no FKs - "for speed"
-- ============================================================
CREATE TABLE Orders_Archive (
    OrderID             int             NOT NULL,
    CustomerID          int             NOT NULL,
    OrderDate           datetime        NULL,
    RequiredDate        datetime        NULL,
    ShippedDate         datetime        NULL,
    Status              varchar(20)     NULL,
    PickupAddress       varchar(200)    NULL,
    PickupCity          varchar(50)     NULL,
    PickupState         char(2)         NULL,
    PickupZip           varchar(10)     NULL,
    DeliveryAddress     varchar(200)    NULL,
    DeliveryCity        varchar(50)     NULL,
    DeliveryState       char(2)         NULL,
    DeliveryZip         varchar(10)     NULL,
    TotalWeight         decimal(10,2)   NULL,
    TotalCost           money           NULL,
    DiscountPct         decimal(5,2)    NULL,
    SpecialInstructions varchar(500)    NULL,
    Priority            char(1)         NULL,
    ArchivedDate        datetime        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_Orders_Archive PRIMARY KEY (OrderID)
)
GO

-- ============================================================
-- INDEXES
-- (only the ones someone thought to add)
-- ============================================================
CREATE INDEX IX_Orders_CustomerID   ON Orders(CustomerID)
CREATE INDEX IX_Orders_Status       ON Orders(Status)
CREATE INDEX IX_Orders_OrderDate    ON Orders(OrderDate)
CREATE INDEX IX_Shipments_OrderID   ON Shipments(OrderID)
CREATE INDEX IX_Shipments_DriverID  ON Shipments(DriverID)
CREATE INDEX IX_Invoices_CustomerID ON Invoices(CustomerID)
CREATE INDEX IX_AuditLog_TableName  ON AuditLog(TableName, RecordID)
-- Note: OrderItems has no index on OrderID - was "on the list" since 2015
-- Note: Drivers has no index on Status - causes full scan in GetAvailableDrivers
GO
