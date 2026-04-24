# As-Is Application Layer — Northwind Logistics

## Web Application Structure

The application is a single ASP.NET Web Forms site with no namespacing, no service layer, and no separation between UI and data access. Pages talk directly to SQL Server.

```
lagacy/app/
├── Default.aspx(.cs)              Dashboard (summary widgets + pending orders + active shipments)
├── Login.aspx                     Forms auth login (unchanged since 2010)
├── Error.aspx                     Blank error page (custom errors redirect here)
├── web.config                     App config + connection string #1
├── App_Code/
│   └── DBHelper.cs                Shared static data-access helper
├── Orders/
│   ├── NewOrder.aspx(.cs)         Order creation (connection string #2 hardcoded)
│   └── OrderList.aspx(.cs)        Order search + order detail (dual-mode, same page)
└── Admin/
    └── EndOfDay.aspx(.cs)         Manual EOD batch trigger (connection string #3 hardcoded)
```

## Data Access Patterns

### DBHelper (the intended pattern)
`App_Code/DBHelper.cs` is a static helper used by most pages. The caller constructs a `SqlCommand`, adds parameters, and calls one of:

- `ExecuteDataTable(cmd)` — returns a single-table result
- `ExecuteDataSet(cmd)` — returns multiple result sets (used by `usp_GetOrder` which returns 3)
- `ExecuteNonQuery(cmd)` — mutations; 60-second timeout hardcoded
- `ExecuteWithOutput(cmd)` — mutations that return a new ID via `@NewID` OUTPUT param
- `ExecuteScalar(cmd)` — single value

`DBHelper` opens a new connection per call; there is no connection pooling configuration beyond ADO.NET defaults.

### Bypass pattern (the actual pattern in two pages)
`Orders/NewOrder.aspx.cs` and `Admin/EndOfDay.aspx.cs` each declare their own `private const string CONN` with the connection string hardcoded inline and open `SqlConnection` directly. This was "temporary" in 2012.

### Dashboard pattern (worst case)
`Default.aspx` opens **five separate connections** in sequence on every page load, one per widget (today's orders, active shipments, pending orders, drivers, vehicles). No caching. The 2015 profiling that justified this was invalidated when the DB server was upgraded in 2016.

## Page Descriptions

### Default.aspx — Dashboard
Loads four inline SQL queries plus calls `usp_GetPendingOrders` and `usp_GetActiveShipments`. The global temp table in `usp_GetActiveShipments` (`##GlobalTemp`) means concurrent dashboard loads from two dispatchers can collide.

### Orders/OrderList.aspx — Order Search + Detail
One page serves two functions selected by the `?id=` query string: absent = search/list view, present = detail view. The `@SortBy` parameter passed to `usp_SearchOrders` comes from a client-controlled hidden field, inheriting a SQL injection vulnerability from the proc.

### Orders/NewOrder.aspx — New Order
Creates an order via `usp_CreateOrder`, then optionally inserts the first `OrderItem` with inline SQL. Uses its own hardcoded connection string. The OUTPUT parameter the proc uses is `@NewOrderID`, which is incompatible with `DBHelper.ExecuteWithOutput` which expects `@NewID` — so it doesn't use `DBHelper` at all.

### Admin/EndOfDay.aspx — EOD Batch Trigger
Calls `usp_ProcessEndOfDay` with a 10-minute command timeout. **No role or auth check** — any user who knows the URL can trigger EOD. JIRA NWL-441 open since 2022. Also exposes index rebuild (`usp_RebuildIndexes`) which takes 15–20 minutes and locks tables.

## Authentication and Authorization

- Forms authentication with a 30-minute session cookie.
- Session stored InProc — lost when the load balancer routes to the other web server.
- Authorization is performed in code-behind on a per-page basis — inconsistently. The dashboard has no auth check ("VPN is the security layer"). The Admin page has no auth check.
- No role system; IT was asked to set up Active Directory groups in 2021 and never did.

## Stored Procedure Inventory

| Proc | Purpose |
|---|---|
| `usp_CreateOrder` | Insert order + run cost calc (no transaction wrapping both) |
| `usp_GetOrder` | 3-result-set fetch: header, items, shipment |
| `usp_UpdateOrderStatus` | God proc: handles all 8 status transitions with inline side-effects |
| `usp_CancelOrder` | Thin wrapper around `usp_UpdateOrderStatus` |
| `usp_SearchOrders` | Dynamic SQL search; SQL injection via `@SortBy` |
| `usp_GetPendingOrders` | Dashboard list; non-sargable WHERE prevents index use |
| `usp_GetOrdersByCustomer` | Cursor + per-row invoice lookup (N+1) |
| `usp_AssignOrderToDriver` | Creates `Shipment`, updates driver/vehicle status, calls `usp_UpdateOrderStatus` |
| `usp_CalculateOrderCost` | Pricing: PricingRules lookup + hardcoded 15% fuel surcharge + hazmat/priority fees |
| `usp_CreateInvoice` | Creates invoice record; not idempotent (duplicate invoices if called twice) |
| `usp_ProcessEndOfDay` | Nightly batch: auto-billing, overdue marking, archival, email report |
| `usp_SearchCustomers` | SQL injection via `@SortBy` |
| `usp_GetActiveShipments` | Uses `##global` temp table; unsafe under concurrency |
| `usp_FailShipment` | Marks shipment failed, releases driver/vehicle |
| `usp_CompleteShipment` | Marks delivered; calling twice creates duplicate invoice |
| `usp_RebuildIndexes` | Index maintenance; ~15–20 min runtime, no dry-run |
| `usp_ProcessEndOfDay` | EOD batch (see Business Flows) |
| `usp_CleanupTempData` | Fixes orphaned items, stuck driver/vehicle statuses |

## Triggers

| Trigger | Table | Behaviour |
|---|---|---|
| `TR_Orders_UpdateModified` | Orders AFTER UPDATE | Sets `LastModifiedDate/By` from `CONTEXT_INFO()` |
| `TR_Orders_AuditStatusChange` | Orders AFTER UPDATE | Writes to `AuditLog` on any status or cost change; fires on ALL updates (perf impact) |
| `TR_Shipments_AutoUpdateOrderStatus` | Shipments AFTER UPDATE | Mirrors shipment status changes to the parent order — the source of mysterious order status changes; cursor-based |
| `TR_Invoices_UpdateBalance` | Invoices AFTER INSERT/UPDATE | Recalculates `Customers.CurrentBalance` from scratch on every invoice change |
| `TR_Customers_PreventDeleteWithOrders` | Customers INSTEAD OF DELETE | Redundant guard alongside FK; added "just to be safe" in 2011 |
