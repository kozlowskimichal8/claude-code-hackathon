# Northwind Logistics — Current System Functionality

> Derived from static analysis of `lagacy/` (schema, 42 stored procs, 4 triggers, ASP.NET shell).
> This document describes **what the system does today**, bugs and all.

---

## 1. System Overview

Northwind Logistics is a SQL Server + ASP.NET WebForms application managing end-to-end logistics operations: order intake, driver dispatch, shipment tracking, delivery confirmation, billing, and reporting. Business logic lives almost entirely in 42 T-SQL stored procedures. The ASP.NET shell is a thin ADO.NET call-forwarder.

**Approximate scale**: 5,000+ customers, 10,000+ active orders, 8–10 drivers, 9 vehicles.

---

## 2. Business Capabilities

### 2.1 Customer Management

| Capability | Procedure | Notes |
|---|---|---|
| Look up a customer by ID | `usp_GetCustomer` | `SELECT *` — fragile to schema changes |
| Search customers | `usp_SearchCustomers` | Filters: name, type, active status; sort by any column |
| Create a customer | `usp_CreateCustomer` | Validates required fields; invalid type silently defaults to 'R' |
| Update customer details | `usp_UpdateCustomer` | Sparse update pattern; cannot explicitly set a field to NULL |
| Get all orders for a customer | `usp_GetCustomerOrders` | Cursor-based; N+1 per order for items/driver |

**Customer types**: Regular (R), Premium (P), Contract (C), Government (G).

Credit limit enforcement: Regular and Premium customers are blocked from new orders if `CurrentBalance + EstimatedCost > CreditLimit`. Contract and Government customers are exempt.

`CurrentBalance` is a denormalized field on `Customers`, recalculated from scratch by `TR_Invoices_UpdateBalance` on every invoice insert/update.

---

### 2.2 Order Management

**Order statuses**: `Pending → Assigned → PickedUp → InTransit → Delivered` (normal), with branches to `Cancelled`, `Failed`, and `OnHold`.

| Capability | Procedure | Notes |
|---|---|---|
| Create an order | `usp_CreateOrder` | Credit check, INSERT, then calls cost calculation outside transaction |
| Get full order detail | `usp_GetOrder` | Returns 3 result sets: header, items, shipment; result-set ORDER must not change |
| Update order status | `usp_UpdateOrderStatus` | God proc (280 lines); handles all transitions with per-state logic |
| Cancel an order | `usp_CancelOrder` | Wrapper around `usp_UpdateOrderStatus('Cancelled')` |
| Search orders | `usp_SearchOrders` | Dynamic SQL; `@SortBy` is not sanitised (SQL injection risk) |
| Get pending orders | `usp_GetPendingOrders` | Returns unassigned orders; non-sargable `CONVERT` on `Status` prevents index use |
| Assign order to driver | `usp_AssignOrderToDriver` | Validates availability; creates Shipment; updates driver/vehicle status |
| Get orders by customer (paged) | `usp_GetOrdersByCustomer` | Cursor + temp-table pagination (pre–`ROW_NUMBER` era) |

**Pricing** is calculated by `usp_CalculateOrderCost`:
1. Look up weight tier in `PricingRules` by `CustomerType` + weight range.
2. `BaseCost = BaseRate + EstimatedMiles × PerMileRate`.
3. Apply 15 % fuel surcharge (hardcoded, not read from `SystemSettings`).
4. Add $75 hazmat fee if `IsHazmat = 1`.
5. Apply priority multiplier: Normal = ×1.0, High = ×1.10, Urgent = ×1.25.
6. Apply `DiscountPct`.
7. Round to 2 decimal places; `UPDATE Orders.TotalCost`.

Government customers have no pricing rules — they silently fall back to Regular rates.

---

### 2.3 Driver Dispatch

| Capability | Procedure | Notes |
|---|---|---|
| Get available drivers | `usp_GetAvailableDrivers` | Flags expiring licences (<1 month) but does **not** exclude expired ones |
| Assign a driver | `usp_AssignDriver` | Sets `Status='OnRoute'`; no licence-expiry validation |
| Update driver GPS location | `usp_UpdateDriverLocation` | Called by decommissioned mobile app; updates last-known position only |
| Get driver schedule | `usp_GetDriverSchedule` | Cursor per day; slow for ranges >2 weeks |
| Create a driver record | `usp_CreateDriver` | Warns on duplicate licence number (does not block) |
| Driver performance KPIs | `usp_GetDriverPerformance` | Delivery rate, on-time rate, avg delivery minutes, total miles |

**Driver statuses**: `Available`, `OnRoute`, `OffDuty`, `Terminated`, `LOA` (added 2019; not fully handled in assignment logic).

EOD batch resets `OffDuty → Available` and recovers drivers stuck `OnRoute > 16 h` with no active shipment.

---

### 2.4 Shipment Tracking

| Capability | Procedure | Notes |
|---|---|---|
| Create a shipment record | `usp_CreateShipment` | Nested-transaction bug: a `ROLLBACK` here rolls back the outer transaction too |
| Update shipment status | `usp_UpdateShipmentStatus` | Accumulates driver miles and vehicle mileage; fires `TR_Shipments_AutoUpdateOrderStatus` |
| Customer-facing tracking | `usp_GetShipmentTracking` | Returns sanitised view (driver initials only, rough ETA = miles ÷ 50) |
| Complete a shipment (delivery) | `usp_CompleteShipment` | Stores POD path, notes, miles; calls `usp_UpdateShipmentStatus('Delivered')` |
| Fail a shipment | `usp_FailShipment` | Records failure reason; releases driver/vehicle; does **not** re-queue order |
| Dispatch board view | `usp_GetActiveShipments` | Uses a `##global` temp table — concurrent dispatchers collide |

**Status cascade**: `TR_Shipments_AutoUpdateOrderStatus` automatically propagates shipment status changes to the parent `Orders` row. Removing it broke the system in 2016 and it has stayed ever since.

---

### 2.5 Billing & Invoicing

| Capability | Procedure | Notes |
|---|---|---|
| Calculate order cost | `usp_CalculateOrderCost` | See pricing rules in §2.2 |
| Create an invoice | `usp_CreateInvoice` | Not idempotent — calling twice creates duplicate invoices |
| Record a payment | `usp_ProcessPayment` | Duplicate `ReferenceNumber` accepted; "we trust accounting" |
| Get invoice with payments | `usp_GetInvoice` | 2 result sets: header and payment history |
| Apply a discount | `usp_ApplyDiscount` | No approval workflow; any DB user can grant 100 % discount |
| List outstanding invoices | `usp_GetOutstandingInvoices` | Filters by customer, overdue flag, minimum amount |
| Generate monthly statement | `usp_GenerateMonthlyStatement` | 3 result sets; ~45 s for large customers; 2019 rewrite abandoned |

**Invoice lifecycle**: `Draft → Sent → Paid` (or `PartialPaid` on partial payment, `Overdue` after due date). Tax is always $0 (logistics exemption). Discount is recorded separately even though it is already baked into `TotalCost` (accounting confusion).

Invoices are created automatically when an order reaches `Delivered` status via `usp_UpdateOrderStatus`. The EOD batch also auto-bills any delivered orders with `IsBilled = 0` older than 7 days.

---

### 2.6 Reporting

| Report | Procedure | Notes |
|---|---|---|
| Daily shipment summary | `usp_GetDailyShipmentReport` | Totals, revenue, failed-shipment list; uses `##global` temp table |
| Driver performance scorecard | `usp_GetDriverPerformanceReport` | Monthly KPIs; star rating 0–5; ~2 min runtime for 8 drivers |
| Revenue by period | `usp_GetRevenueReport` | `@GroupBy` (Day/Week/Month) inserted into dynamic SQL without validation |
| Top customers by revenue | `usp_GetCustomerActivityReport` | Top N customers; nested subqueries repeated in `ORDER BY` |
| Delayed shipments | `usp_GetDelayedShipmentsReport` | Flags: not picked up after 4 h assigned, not delivered after 8 h in transit, past required date (thresholds hardcoded) |

---

### 2.7 Nightly Batch Operations

`usp_ProcessEndOfDay` runs via SQL Agent at 23:30. Runtime: ~8 minutes. **Not idempotent** — a mid-run failure requires manual intervention to avoid duplicate invoices.

| Step | Action |
|---|---|
| 1 | Auto-bill any `Delivered` orders with `IsBilled = 0` (cursor over last 7 days) |
| 2 | Mark invoices `Overdue` where `DueDate < today` and `PaidAmount < TotalAmount` |
| 3 | Reset `OffDuty → Available`; recover `OnRoute > 16 h` drivers with no active shipment |
| 4 | Log stale `Pending` orders (>48 h) — notification email never wired up |
| 5 | Send HTML ops-summary email via DB Mail (`NWLMailProfile`) |
| 6 | `UPDATE STATISTICS … WITH FULLSCAN` on Orders, Shipments, Invoices (3–4 min) |

Other maintenance procedures:

| Procedure | Purpose |
|---|---|
| `usp_ArchiveOldOrders` | Moves completed orders >365 days old to `Orders_Archive`; does **not** archive `OrderItems` (orphan accumulation) |
| `usp_RecalculateAllPricing` | Re-prices all `Pending`/`Assigned` orders; dangerous if run without dry-run flag |
| `usp_CleanupTempData` | Manually removes orphaned `OrderItems`, stuck drivers, stuck vehicles |
| `usp_RebuildIndexes` | Full index rebuild every Sunday 02:00; `OrderItems` missing from ONLINE list (table-lock risk) |

---

## 3. Web Application Pages

| Page | Path | Responsibility |
|---|---|---|
| Dashboard | `Default.aspx` | Real-time widget counts (today's orders, active shipments, pending orders, available drivers/vehicles); pending-orders grid; active-shipments grid with OVERDUE flag |
| Create Order | `Orders/NewOrder.aspx` | Order intake form: customer selection, addresses, weight, miles, priority, hazmat, items |
| Order Search / Detail | `Orders/OrderList.aspx` | Dual-purpose: search with status/date filters and column sort; detail view with action buttons (Cancel, Fail, Deliver) |
| EOD Admin | `Admin/EndOfDay.aspx` | Manual trigger for EOD batch, cleanup, and index rebuild; **no role check** |

---

## 4. Data Model Summary

| Table | Rows (approx.) | Purpose |
|---|---|---|
| `Customers` | 5,000+ | Customer master |
| `Orders` | 10,000+ active | One per shipment; primary transaction record |
| `OrderItems` | Many | Line items per order; no FK to `Orders` (removed 2015) |
| `Drivers` | ~10 | Driver roster and availability |
| `Vehicles` | 9 (1 retired) | Fleet inventory |
| `Shipments` | 1:1 with Orders | Execution record; links driver and vehicle |
| `Invoices` | 5,000+ | Billing document per delivered order |
| `Payments` | Many | Individual payment records per invoice |
| `PricingRules` | 15 | Rate schedule by customer type and weight tier |
| `AuditLog` | 80 M+ | Change tracking; truncated without archiving (history lost) |
| `SystemSettings` | ~10 | Key-value config (fuel surcharge, payment terms, etc.) |
| `Orders_Archive` | Historical | Completed orders >365 days old; no corresponding items archive |

---

## 5. Triggers

| Trigger | Table | Event | Effect |
|---|---|---|---|
| `TR_Orders_UpdateModified` | Orders | AFTER UPDATE | Sets `LastModifiedDate` and `LastModifiedBy` on every update |
| `TR_Orders_AuditStatusChange` | Orders | AFTER UPDATE | Inserts to `AuditLog` when `Status` or `TotalCost` changes |
| `TR_Shipments_AutoUpdateOrderStatus` | Shipments | AFTER UPDATE | Propagates shipment status to parent `Orders` row |
| `TR_Invoices_UpdateBalance` | Invoices | AFTER INSERT/UPDATE | Recalculates `Customers.CurrentBalance` from scratch |
| `TR_Customers_PreventDeleteWithOrders` | Customers | INSTEAD OF DELETE | Blocks deletion of customers who have orders (FK also exists) |

---

## 6. Known Behavioural Constraints (not bugs — just how it works)

These are behaviours that **characterization tests must pin** before any extraction:

1. `usp_GetOrder` returns exactly 3 result sets in a fixed order; callers depend on ordinal position.
2. `TR_Shipments_AutoUpdateOrderStatus` fires on every shipment update; removing it breaks the system.
3. `usp_UpdateOrderStatus` appends timestamped notes to `SpecialInstructions` (history-in-field pattern).
4. `usp_CreateOrder` may leave an order with `TotalCost = NULL` if cost calculation fails (not transactional).
5. `usp_ProcessEndOfDay` has no restart safety; re-running after a failure will double-bill.
6. `usp_CompleteShipment` calling `usp_CreateInvoice` is not idempotent; calling twice produces duplicate invoices.
7. `CurrentBalance` on `Customers` is a denormalized aggregate, not a source of truth — it is correct only after the most recent invoice insert/update.
8. `Orders_Archive` contains no corresponding `OrderItems`; orphaned items accumulate in `OrderItems`.
9. Admin page (`EndOfDay.aspx`) has no role check; any authenticated session can trigger destructive operations.
10. Government (`G`) customers have no pricing rules; they silently receive Regular rates.

---

## 7. Seam Candidates (for The Map)

Based on proc coupling and data-model dependencies:

| Domain | Procs | Coupling notes |
|---|---|---|
| **Customer** | 5 procs | Low coupling to other domains; `CurrentBalance` is written by billing trigger |
| **Pricing** | `usp_CalculateOrderCost`, `PricingRules` table | Called by order creation and EOD; safe to extract |
| **Order Intake** | `usp_CreateOrder`, `usp_CalculateOrderCost` | Depends on Customer and Pricing |
| **Dispatch** | `usp_AssignOrderToDriver`, driver + vehicle procs | Writes to Shipments; coupled via status cascade trigger |
| **Shipment Tracking** | 6 procs | Tightly coupled to Orders via `TR_Shipments_AutoUpdateOrderStatus` |
| **Billing** | 7 procs | Triggered by order status; `CurrentBalance` denorm is a coupling point |
| **Reporting** | 5 procs | Read-only; easiest to extract first |
| **Batch** | 5 procs | Calls across all domains; extract last |

Recommended extraction order (lowest risk first): **Reporting → Pricing → Customer → Order Intake → Billing → Dispatch/Shipment → Batch**.
