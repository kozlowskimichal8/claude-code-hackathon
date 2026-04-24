# As-Is Known Issues and Technical Debt

Source: `lagacy/docs/SYSTEM_NOTES.txt` (last updated Nov 2021) + code analysis.

## Security

| Ref | Issue | Risk | Status |
|---|---|---|---|
| NWL-389 | SQL injection in `usp_SearchOrders` and `usp_SearchCustomers` via `@SortBy` parameter — column name passed directly into dynamic SQL with no whitelist | High — VPN was breached in 2020 | Open, Low priority |
| NWL-441 | `Admin/EndOfDay.aspx` has no role or auth check — any authenticated user who knows the URL can trigger the EOD batch or rebuild indexes | High | Open, blocked on IT setting up AD groups |
| — | Connection string with plaintext DB credentials duplicated in 3 source files | Medium | Open since 2014 |
| — | `Default.aspx` dashboard has no auth check — auth was removed "temporarily" in 2021 | High | Open |
| — | ViewState not encrypted ("internal app, not needed") | Low | Not tracked |

## Data Integrity

| Issue | Detail |
|---|---|
| Duplicate invoices | `usp_CompleteShipment` called twice creates a second invoice. 7 confirmed post-2021. Fix: idempotency guard in `usp_CreateInvoice`. |
| NULL `TotalCost` on orders | `usp_CalculateOrderCost` runs outside the insert transaction in `usp_CreateOrder`. If it fails, the order exists with `TotalCost=NULL`. Finance finds these monthly. |
| Orphaned `OrderItems` | `OrderItems` are not copied or deleted during order archival. Items for archived orders stay in the live table indefinitely. |
| Government pricing | No `PricingRules` rows for `CustomerType='G'`. Code falls through to Regular rates. Finance manually adjusts invoices. |
| Driver licence expiry | `Drivers.LicenseExpiryDate` is stored but never checked. Expired-licence drivers can be assigned to orders. |
| LOA driver assignment | Drivers with `Status='LOA'` pass the availability check in `usp_AssignOrderToDriver` (only `Available` is blocked). |

## Reliability and Performance

| Issue | Detail |
|---|---|
| Global temp table concurrency | `usp_GetActiveShipments` uses `##GlobalTemp`. Two dispatchers loading the dashboard simultaneously causes errors. Fix: use `#local` temp table or rewrite set-based. |
| EOD batch non-idempotent | No recovery if EOD fails mid-run. Steps 1–N already ran when Step N+1 fails. Fix: add idempotency checks per step. |
| Session lost across web servers | Session is InProc; load balancer sticky sessions are unreliable. Fix: SQL Session State or Redis. Ticket open 3 years. |
| Non-sargable pending orders query | `usp_GetPendingOrders` wraps `Status` in `CONVERT()`, preventing use of `IX_Orders_Status`. Causes full table scan at scale (> ~10k orders). |
| N+1 cursor in `usp_GetOrdersByCustomer` | Cursor loops over orders issuing a per-row invoice lookup. Slow for large customers. A set-based CTE rewrite was attempted in 2017 and reverted. |
| Monthly statement proc | `usp_GetMonthlyStatement` takes ~45 seconds for large customers. 2019 rewrite attempt abandoned. |
| Dashboard: 5 DB connections per load | Each widget opens its own `SqlConnection`. No caching since a 2015 profile (on now-replaced hardware). |

## Architecture / Maintainability

| Issue | Detail |
|---|---|
| Business logic in stored procs | All pricing, state-machine transitions, credit checks, and billing live in SQL Server. Application code cannot be tested without a live database. |
| God procs | `usp_UpdateOrderStatus` (all 8 status transitions), `usp_ProcessEndOfDay` (billing + overdue + archive + email + stats). |
| Trigger side-effects | `TR_Shipments_AutoUpdateOrderStatus` silently mirrors shipment → order status changes. Removal was attempted in 2016 and caused cascading failures; the dependency has never been properly untangled. |
| Three connection strings | Password rotation requires editing three files. A config deploy failure in 2016 prompted a hardcoded fallback in `DBHelper.cs`. |
| xcopy deployment | No build pipeline. No environment promotion. Developers deploy from their laptops to production. |
| No logging | Application errors are caught and either displayed to users or silently swallowed. No structured log output. |
| No monitoring | SQL Server and IIS are not monitored. Downtime is discovered by user calls. |
