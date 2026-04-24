-- ============================================================
-- Northwind Logistics - Seed / Reference Data
-- Run AFTER 00_schema.sql
-- ============================================================

USE NorthwindLogistics
GO

-- ============================================================
-- SYSTEM SETTINGS
-- ============================================================
INSERT INTO SystemSettings (SettingKey, SettingValue, Description) VALUES
('FuelSurcharge',        '0.15',                       'Fuel surcharge multiplier applied to all orders'),
('DefaultPaymentTerms',  '30',                         'Days until invoice is due'),
('MaxCreditCheckAmount', '10000',                      'Orders above this trigger manual credit check'),
('ArchiveDaysOld',       '365',                        'Orders older than this many days get archived'),
('EODReportEmail',       'ops@northwindlogistics.com', 'End-of-day report recipient'),
('SmtpServer',           'mail.northwindlogistics.com','Internal mail relay'),
('PODBasePath',          '\\\\fileserver01\\pod\\',    'UNC path for proof of delivery scans'),
('MaxDriverHoursDay',    '10',                         'DOT compliance: max driving hours per day'),
('TaxRate',              '0.0',                        'Sales tax rate (logistics is exempt in most states)'),
('BatchLockTimeout',     '300',                        'Seconds to wait for batch lock before giving up')
GO

-- ============================================================
-- PRICING RULES
-- Regular customers
-- ============================================================
INSERT INTO PricingRules (CustomerType, WeightFrom, WeightTo, BaseRate, PerMileRate, EffectiveDate, IsActive) VALUES
('R',   0,      50,     25.00,  0.85,   '2010-01-01',   1),
('R',   50,     200,    45.00,  0.80,   '2010-01-01',   1),
('R',   200,    500,    75.00,  0.75,   '2010-01-01',   1),
('R',   500,    1000,   120.00, 0.70,   '2010-01-01',   1),
('R',   1000,   99999,  200.00, 0.65,   '2010-01-01',   1),
-- Premium customers (10% cheaper)
('P',   0,      50,     22.00,  0.75,   '2010-01-01',   1),
('P',   50,     200,    40.00,  0.70,   '2010-01-01',   1),
('P',   200,    500,    65.00,  0.65,   '2010-01-01',   1),
('P',   500,    1000,   105.00, 0.60,   '2010-01-01',   1),
('P',   1000,   99999,  175.00, 0.55,   '2010-01-01',   1),
-- Contract customers (negotiated flat rates)
('C',   0,      50,     18.00,  0.60,   '2010-01-01',   1),
('C',   50,     200,    32.00,  0.55,   '2010-01-01',   1),
('C',   200,    500,    55.00,  0.50,   '2010-01-01',   1),
('C',   500,    1000,   90.00,  0.48,   '2010-01-01',   1),
('C',   1000,   99999,  150.00, 0.45,   '2010-01-01',   1)
-- NOTE: 'G' (Government) type has no pricing rules. usp_CalculateOrderCost
--       falls back to 'R' pricing for Government customers. Finance knows.
GO

-- ============================================================
-- DRIVERS (sample)
-- ============================================================
INSERT INTO Drivers (FirstName, LastName, LicenseNumber, LicenseExpiryDate, Phone, CellPhone, Email, Status, HiredDate, HourlyRate, HomeBase) VALUES
('Mike',    'Tanner',   'DL-IL-449921', '2025-06-30', '312-555-0101', '312-555-0201', 'mtanner@nwl.com',  'Available', '2009-04-01', 18.50, 'Chicago-North'),
('Sandra',  'Voss',     'DL-IL-882234', '2024-12-31', '312-555-0102', '312-555-0202', 'svoss@nwl.com',    'Available', '2011-08-15', 19.00, 'Chicago-South'),
('Dmitri',  'Patel',    'DL-IL-331177', '2026-03-31', '312-555-0103', '312-555-0203', 'dpatel@nwl.com',   'OnRoute',   '2014-02-10', 17.75, 'Chicago-North'),
('Leon',    'Crawford', 'DL-WI-556644', '2025-09-30', '414-555-0104', '414-555-0204', 'lcrawford@nwl.com','Available', '2015-07-01', 18.00, 'Milwaukee'),
('Amy',     'Schultz',  'DL-IL-774455', '2023-08-31', '312-555-0105', '312-555-0205', 'aschultz@nwl.com', 'OffDuty',   '2013-11-20', 18.25, 'Chicago-West'),
-- WARNING: Amy''s license expired. Nobody caught it. usp_AssignDriver doesn''t check.
('Frank',   'DeLuca',   'DL-IL-123098', '2026-01-31', '312-555-0106', '312-555-0206', NULL,               'Available', '2018-03-05', 17.50, 'Chicago-South'),
('Grace',   'Kim',      'DL-IN-998811', '2025-11-30', '317-555-0107', '317-555-0207', 'gkim@nwl.com',     'Available', '2020-09-14', 18.00, 'Indianapolis'),
('Harold',  'Benson',   'DL-IL-447733', '2024-07-31', '312-555-0108', NULL,           NULL,               'Terminated','2009-01-15', 16.00, 'Chicago-North')
GO

-- ============================================================
-- VEHICLES
-- ============================================================
INSERT INTO Vehicles (LicensePlate, Make, Model, Year, MaxWeightLbs, VehicleType, Status, LastServiceDate, CurrentMileage) VALUES
('IL-NWL-001', 'Ford',   'Transit 350',    2015, 3500,   'Van',        'Available',   '2023-08-10', 187432),
('IL-NWL-002', 'Ford',   'Transit 350',    2016, 3500,   'Van',        'Available',   '2023-09-22', 142110),
('IL-NWL-003', 'GMC',    'Savana 3500',    2014, 4000,   'Van',        'Maintenance', '2022-12-01', 234900),
('IL-NWL-004', 'Isuzu',  'NPR',            2017, 10000,  'LightTruck', 'Available',   '2023-07-15', 98000),
('IL-NWL-005', 'Isuzu',  'NPR',            2018, 10000,  'LightTruck', 'InUse',       '2023-10-01', 76500),
('IL-NWL-006', 'Isuzu',  'FTR',            2016, 26000,  'HeavyTruck', 'Available',   '2023-06-20', 312000),
('IL-NWL-007', 'Freightliner', 'M2 106',   2019, 33000,  'HeavyTruck', 'Available',   '2023-11-05', 55000),
('IL-NWL-008', 'Kenworth','T680',          2020, 80000,  'Semi',       'Available',   '2023-10-28', 41000),
-- retired but not removed from system (causes issues in availability checks)
('IL-NWL-000', 'Dodge',  'Ram Van',        2001, 2000,   'Van',        'Retired',     '2018-01-01', 489000)
GO

-- ============================================================
-- CUSTOMERS (sample)
-- ============================================================
INSERT INTO Customers (AccountNum, CompanyName, ContactName, Address, City, State, ZipCode, Phone, Email, CustomerType, CreditLimit, SalesRepName, IsActive) VALUES
(NULL,       'Acme Hardware Co',          'Bob Figgins',      '1200 W Industrial Dr',  'Chicago',      'IL', '60608', '312-555-1001', 'bfiggins@acmehardware.com',  'R', 5000,   'Dave Ortiz',   1),
(NULL,       'Great Lakes Produce',       'Maria Santos',     '4400 N Pulaski Rd',     'Chicago',      'IL', '60630', '312-555-1002', 'msantos@glproduce.com',      'P', 25000,  'Dave Ortiz',   1),
('C-10042',  'Midwest Auto Parts LLC',   'Jim Kowalczyk',    '8800 S Cicero Ave',     'Oak Lawn',     'IL', '60453', '708-555-1003', 'jim.k@midwestauto.com',      'C', 50000,  'Lisa Hernandez',1),
(NULL,       'Chicago Print Shop',        'Teri Olsen',       '220 W Randolph St',     'Chicago',      'IL', '60601', '312-555-1004', NULL,                         'R', 3000,   NULL,           1),
('C-10088',  'Regional Hospital Supply', 'David Nguyen',     '1000 N Lake Shore Dr',  'Chicago',      'IL', '60611', '312-555-1005', 'dnguyen@reghosp.org',        'C', 100000, 'Lisa Hernandez',1),
(NULL,       'Crafty Candles Inc',        'Sue Barnes',       '780 Waukegan Rd',       'Deerfield',    'IL', '60015', '847-555-1006', 'sue@craftycandles.com',      'R', 2500,   'Dave Ortiz',   1),
(NULL,       'Burlington Cold Storage',   'Pete Warwick',     '2200 S Throop St',      'Chicago',      'IL', '60608', '312-555-1007', 'pwarwick@bcstorage.com',     'P', 40000,  'Lisa Hernandez',1),
('G-00015',  'City of Chicago - Parks',  'Renee Caldwell',   '69 W Washington St',    'Chicago',      'IL', '60602', '312-555-1008', 'rcaldwell@cityofchicago.gov','G', 200000, NULL,           1),
-- inactive, keep for historical orders
(NULL,       'Sunset Florist',           'Phil Markowitz',   '405 N Wells St',        'Chicago',      'IL', '60654', '312-555-1009', NULL,                         'R', 1000,   'Dave Ortiz',   0)
GO
