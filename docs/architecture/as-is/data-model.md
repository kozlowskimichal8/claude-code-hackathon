# As-Is Data Model — Northwind Logistics

## Entity Relationship

```
Customers ──────────────────────────────────────────────────────┐
    │                                                           │
    │ 1:N                                                       │ 1:N
    ▼                                                           ▼
  Orders ──── 1:N ──── OrderItems                          Invoices
    │                                                           │
    │ 1:1 (intended)                                           │ 1:N
    ▼                                                           ▼
Shipments                                                   Payments
    │ N:1
    ├──► Drivers
    └──► Vehicles

PricingRules   (looked up during cost calculation, no FK)
AuditLog       (append-only, written by triggers and procs)
SystemSettings (key-value config)
Orders_Archive (shadow copy of closed orders, no FKs)
```

## Tables

### Customers
Core entity. `CustomerType` drives pricing: `R`=Regular, `P`=Premium, `C`=Contract, `G`=Government. Government was added in 2016 but pricing rules were never created for it — government orders silently fall through to Regular rates. `CurrentBalance` is a denormalised sum maintained by trigger `TR_Invoices_UpdateBalance`. `SalesRepName` is a free-text string; the staff table it was meant to reference was dropped in a 2013 incident.

### Orders
Central entity. `OrderID` starts at 1000 (compatibility with a pre-2009 system). `Status` is a `varchar(20)` — it was an `int` before a 2012 migration; some old procs still use integer comparisons. `TotalCost` is calculated by `usp_CalculateOrderCost` after insert; it can be `NULL` if that proc fails. `DiscountPct` is stored per-order but applied in the billing proc.

**Status values:** `Pending` → `Assigned` → `PickedUp` → `InTransit` → `Delivered` / `Failed`. Also: `Cancelled`, `OnHold` (2017).

**Priority values:** `N`=Normal, `H`=High, `U`=Urgent.

### OrderItems
Line items for an order. The FK to Orders exists but was removed "for performance" in 2015 and restored — check current DDL. No index on `OrderID` (on the to-do list since 2015).

### Shipments
Represents a driver+vehicle assignment for an order. Intended as 1:1 with Orders; a multi-leg design was planned but never built. `ProofOfDeliveryPath` is a UNC path (`\\fileserver01\pod\...`) to a scanned image.

### Drivers
`Status` values: `Available`, `OnRoute`, `OffDuty`, `Terminated`, `LOA` (Leave of Absence, added 2019). LOA is not handled by the assignment proc — drivers on LOA can be assigned to orders. `LicenseExpiryDate` is stored but never checked by any proc. Dead columns: `LastKnownLat/Lng/LocationUpdate` (GPS integration project abandoned).

### Vehicles
`AssignedDriverID` is a soft reference with no FK enforcement.

### Invoices
`InvoiceID` starts at 5000 (accounting requirement). Status: `Draft`, `Sent`, `Paid`, `PartialPaid`, `Overdue`, `Void`. Created automatically when an order is marked `Delivered` (via `usp_UpdateOrderStatus` calling `usp_CreateInvoice`). Calling `usp_CompleteShipment` twice creates duplicate invoices — known issue, 7 duplicates post-2021.

### Payments
Records individual payment receipts against an invoice. `PaymentMethod`: `Check`, `ACH`, `CreditCard`, `Cash`, `Wire`.

### PricingRules
Weight-tier lookup table: `cost = BaseRate + (miles × PerMileRate)`. A 15% fuel surcharge and hazmat/priority premiums are **hardcoded** in `usp_CalculateOrderCost` rather than stored here. No row exists for `CustomerType='G'`.

### AuditLog
Written by triggers (`TR_Orders_AuditStatusChange`) and directly by procs. `OldValues`/`NewValues` are free-text key=value strings, not structured. Grew to 80M rows by 2021 before being trimmed (history lost). No indexed columns other than `(TableName, RecordID)`.

### Orders_Archive
Flat copy of closed orders, no foreign keys ("for speed"). Populated by the nightly EOD batch. `OrderItems` are **not** archived — orphaned items remain in `OrderItems` after archival.

## Notable Integrity Issues

| Issue | Impact |
|---|---|
| `OrderItems.OrderID` FK missing | Orphaned items after order archival |
| `Vehicles.AssignedDriverID` no FK | Stale driver references possible |
| `Government` (`G`) pricing missing | Government orders billed at Regular rates |
| `Orders.TotalCost` can be NULL | Finance finds ~monthly orphan orders |
| `usp_CreateInvoice` not idempotent | 7 duplicate invoices recorded post-2021 |
