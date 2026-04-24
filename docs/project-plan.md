# Northwind Logistics — Strangler-Fig Modernisation Project Plan

> Based on: [`spec/current-functionality.md`](../spec/current-functionality.md), [`docs/architecture/to-be/overview.md`](architecture/to-be/overview.md), [`decisions/ADR-001`](../../decisions/ADR-001-strangler-fig-decomposition.md)

---

## Guiding principles

- Monolith stays live and rollback-able at every step
- No step ships without characterization tests green
- Each new service owns its own database and fixes the defects in its domain by design
- All significant decisions recorded as ADRs before implementation begins
- OpenAPI contract written before service code

---

## Phase 0 — Safety Net (The Pin)

**Goal**: Pin every observable behaviour of the monolith before touching a single line.

Without this phase, any extraction is a gamble. Tests in this phase are allowed to encode bugs — they pin behaviour, not intent.

### 0.1 Infrastructure baseline

- [ ] Docker Compose file: SQL Server 2019 + seed scripts (`00_schema` → `01_seed` → `02_triggers` → `procs/`)
- [ ] CI pipeline skeleton: runs schema apply + test suite on every commit
- [ ] Connection-string consolidation: remove the two hard-coded copies in `Orders/NewOrder.aspx.cs` and `Admin/EndOfDay.aspx.cs`; single source in `web.config`

### 0.2 Characterization test suite (42 procs, 5 triggers)

For each of the 10 behavioural constraints listed in `spec/current-functionality.md §6`:

| # | Behaviour to pin | Test type |
|---|---|---|
| 1 | `usp_GetOrder` returns exactly 3 result sets in fixed ordinal order | Integration |
| 2 | `TR_Shipments_AutoUpdateOrderStatus` propagates status on every shipment update | Integration |
| 3 | `usp_UpdateOrderStatus` appends timestamped note to `SpecialInstructions` | Integration |
| 4 | `usp_CreateOrder` may leave `TotalCost = NULL` if cost calc fails | Integration |
| 5 | `usp_ProcessEndOfDay` double-bills on re-run (pin the bug, don't fix it yet) | Integration |
| 6 | `usp_CompleteShipment` creates duplicate invoices when called twice | Integration |
| 7 | `CurrentBalance` is correct only after an invoice insert/update | Integration |
| 8 | `Orders_Archive` does not archive `OrderItems` | Integration |
| 9 | `Admin/EndOfDay.aspx` accessible without a role claim | Integration |
| 10 | Government customers silently receive Regular rates | Integration |

Additional coverage targets (per domain):

- **Customer**: create, update, credit-limit block, silent-type-default
- **Order**: full status lifecycle (`Pending → Delivered`, `→ Failed`, `→ Cancelled`, `OnHold`)
- **Pricing**: all customer types × weight tiers; hazmat fee; priority multipliers
- **Dispatch**: driver assignment, availability check, LOA status ignored in assignment
- **Shipment**: status cascade via trigger; `##global` temp table collision (documented, not fixed)
- **Billing**: invoice create/duplicate; payment recording; balance recalc trigger
- **Reporting**: 5 report procs return expected row shapes
- **Batch**: EOD steps 1–6 execute in order; double-run produces duplicate invoices

**Exit criterion**: all tests green against the unmodified legacy database; suite checked into CI.

---

## Phase 1 — Pricing Service (Step 1 of 7)

**Rationale**: Stateless pure function; no writes; safe to shadow-run against the legacy proc before cutting over.

**Procs covered**: `usp_CalculateOrderCost`, `PricingRules` table.

**Known defect to fix**: hardcoded 15% fuel surcharge → read from `SystemSettings`.

**Known gap to make explicit**: Government (`G`) customer pricing falls back to Regular — agree with Finance before go-live.

### Tasks

- [ ] ADR-002: Pricing Service — tech stack, deployment model, Government-type decision
- [ ] OpenAPI contract for `POST /pricing/calculate`
- [ ] .NET 8 minimal API service scaffold (Docker, health endpoint)
- [ ] PostgreSQL schema: `PricingRules` table migrated from SQL Server seed
- [ ] Implement pricing logic (weight tier lookup → base cost → fuel surcharge → hazmat → priority → discount)
- [ ] Unit tests: all customer types × weight tiers × priority × hazmat combinations (parity with legacy characterization tests)
- [ ] Shadow mode: route 100% of pricing calls to both legacy proc and new service; assert identical results; log divergences
- [ ] ACL adapter: translate `CustomerType` codes `R/P/C/G` → `PricingTier` enum; no `DataTable` leaks
- [ ] Cut-over: route `usp_CalculateOrderCost` callers via new service; legacy proc retained as fallback
- [ ] Characterization tests still green after cut-over

---

## Phase 2 — Reporting Service (Step 2 of 7)

**Rationale**: Read-only; no state mutations; can run against a replica without touching the write path.

**Procs covered**: `usp_GetDailyShipmentReport`, `usp_GetDriverPerformanceReport`, `usp_GetRevenueReport`, `usp_GetCustomerActivityReport`, `usp_GetDelayedShipmentsReport`.

**Known defects to fix**: `##global` temp table in daily report; unvalidated `@GroupBy` dynamic SQL injection in revenue report; nested subquery duplication in customer activity report.

### Tasks

- [ ] ADR-003: Reporting Service — read model, data sync strategy (replica vs. event projection)
- [ ] OpenAPI contracts for all 5 report endpoints
- [ ] .NET 8 service scaffold
- [ ] Read-replica or event projection setup (no direct writes to this service's DB)
- [ ] Implement 5 report endpoints with parameterized queries and column whitelist for sort/group
- [ ] Fix `##global` temp table → per-request CTE or `#local` temp table
- [ ] Integration tests: result shape parity against legacy procs
- [ ] Cut-over: Admin/Dashboard calls routed to new service; legacy procs retained

---

## Phase 3 — Customer Service (Step 3 of 7)

**Rationale**: Well-bounded data model; minimal cross-domain writes; `CurrentBalance` is a Billing concern and must not leak into this service's public API.

**Procs covered**: `usp_GetCustomer`, `usp_SearchCustomers`, `usp_CreateCustomer`, `usp_UpdateCustomer`, `usp_GetCustomerOrders`.

**Known defects to fix**: SQL injection in `usp_SearchCustomers` via `@SortBy`; `SELECT *` fragility; cursor-based N+1 in `usp_GetCustomerOrders`.

### Tasks

- [ ] ADR-004: Customer Service — data ownership, `CurrentBalance` boundary decision
- [ ] OpenAPI contract: CRUD endpoints + customer order list (paginated)
- [ ] PostgreSQL schema: `Customers` table (without `CurrentBalance` — that is Billing's write)
- [ ] ACL adapter: `CurrentBalance` field blocked from Customer API response; `CustomerType` codes → enum
- [ ] Implement endpoints with parameterized queries; sort column whitelist
- [ ] `PreToolUse` hook: rejects any Customer Service code that reads `CurrentBalance` from the legacy schema
- [ ] Migration strategy for existing customer data
- [ ] Integration tests: parity with legacy characterization tests
- [ ] Cut-over: `Default.aspx` and `Orders/NewOrder.aspx` customer lookups routed to new service

---

## Phase 4 — Order Service (Step 4 of 7)

**Rationale**: Depends on Customer (Phase 3) and Pricing (Phase 1), both already extracted by this point. Highest business value — this is the primary transaction record.

**Procs covered**: `usp_CreateOrder`, `usp_GetOrder`, `usp_UpdateOrderStatus`, `usp_CancelOrder`, `usp_SearchOrders`, `usp_GetPendingOrders`, `usp_AssignOrderToDriver`, `usp_GetOrdersByCustomer`.

**Known defects to fix**: SQL injection in `usp_SearchOrders` via `@SortBy`; `usp_CreateOrder` cost-calc outside transaction; non-sargable `CONVERT` on status; `usp_UpdateOrderStatus` 280-line god proc decomposed into per-transition handlers.

### Tasks

- [ ] ADR-005: Order Service — status machine design, event emission strategy
- [ ] OpenAPI contracts: create, get, search, status transition, cancel, assign
- [ ] PostgreSQL schema: `Orders`, `OrderItems` (with FK restored)
- [ ] Implement order status machine with explicit per-transition handlers
- [ ] `OrderCreated`, `OrderStatusChanged`, `OrderCancelled` events emitted to event bus
- [ ] Call Pricing Service (Phase 1) for cost calculation inside the create transaction
- [ ] Call Customer Service (Phase 3) for credit-limit check
- [ ] `usp_GetOrder` contract: 3-result-set shape abstracted behind typed `OrderDetail` DTO in ACL
- [ ] Migration strategy: active orders synced from legacy during cut-over window
- [ ] Integration tests: full status lifecycle, credit-limit block, pricing parity
- [ ] Cut-over: `Orders/NewOrder.aspx` and `Orders/OrderList.aspx` routed to new service

---

## Phase 5 — Billing Service (Step 5 of 7)

**Rationale**: Replace trigger-based billing (`TR_Invoices_UpdateBalance`) with event-driven billing; fix non-idempotent invoice creation.

**Procs covered**: `usp_CreateInvoice`, `usp_ProcessPayment`, `usp_GetInvoice`, `usp_ApplyDiscount`, `usp_GetOutstandingInvoices`, `usp_GenerateMonthlyStatement`, `usp_CalculateOrderCost` (billing side).

**Known defects to fix**: non-idempotent invoice creation (add idempotency key); duplicate payment reference accepted; `TR_Invoices_UpdateBalance` full-table recalc replaced with incremental event handler; `CurrentBalance` becomes an event-sourced balance in this service.

### Tasks

- [ ] ADR-006: Billing Service — idempotency design, `CurrentBalance` ownership
- [ ] OpenAPI contracts: invoice CRUD, payment record, statement, outstanding list
- [ ] PostgreSQL schema: `Invoices`, `Payments`; `CustomerBalance` projection table
- [ ] Subscribe to `OrderStatusChanged(Delivered)` event from Order Service (replaces trigger)
- [ ] Idempotency key on `CreateInvoice` (deduplicate on `OrderId`)
- [ ] Unique constraint on payment `ReferenceNumber`
- [ ] `CurrentBalance` maintained incrementally via invoice/payment events
- [ ] Integration tests: idempotency, balance accuracy, statement generation
- [ ] `TR_Invoices_UpdateBalance` trigger disabled after cut-over and balance verified
- [ ] Cut-over: billing flow routed to new service; legacy invoice procs retained for read-back

---

## Phase 6 — Dispatch / Shipment Service (Step 6 of 7)

**Rationale**: Highest coupling. The `TR_Shipments_AutoUpdateOrderStatus` trigger is the tightest seam. Extract last, with the most characterization test coverage.

**Procs covered**: `usp_GetAvailableDrivers`, `usp_AssignDriver`, `usp_UpdateDriverLocation`, `usp_GetDriverSchedule`, `usp_CreateDriver`, `usp_GetDriverPerformance`, `usp_CreateShipment`, `usp_UpdateShipmentStatus`, `usp_GetShipmentTracking`, `usp_CompleteShipment`, `usp_FailShipment`, `usp_GetActiveShipments`.

**Known defects to fix**: nested-transaction rollback bug in `usp_CreateShipment`; `##global` temp table in dispatch board; expired licence not blocking assignment; `usp_FailShipment` not re-queuing the order.

**Trigger retirement**: `TR_Shipments_AutoUpdateOrderStatus` replaced by `ShipmentStatusChanged` event → Order Service listener.

### Tasks

- [ ] ADR-007: Dispatch/Shipment Service — trigger retirement plan, driver status machine
- [ ] Additional characterization tests targeting `TR_Shipments_AutoUpdateOrderStatus` cascade (highest-risk seam)
- [ ] OpenAPI contracts: driver CRUD, assignment, location update, shipment lifecycle, tracking
- [ ] PostgreSQL schema: `Drivers`, `Vehicles`, `Shipments`
- [ ] Implement driver status machine; enforce licence-expiry check at assignment
- [ ] Event emission: `ShipmentStatusChanged`, `ShipmentCompleted`, `ShipmentFailed`
- [ ] Order Service listener: consume `ShipmentStatusChanged` to update order status (replaces trigger)
- [ ] Per-request dispatch board (replace `##global` temp table)
- [ ] Shipment create: fix nested-transaction rollback via savepoints
- [ ] Integration tests: full shipment lifecycle; trigger cascade parity via events
- [ ] Cut-over: dispatch board routed to new service; `TR_Shipments_AutoUpdateOrderStatus` disabled after event pipeline verified

---

## Phase 7 — Batch / Jobs Retirement (Step 7 of 7)

**Rationale**: `usp_ProcessEndOfDay` calls across all domains. Once each domain service is live, the batch is replaced by scheduled tasks in the services that own the data.

**Procs covered**: `usp_ProcessEndOfDay`, `usp_ArchiveOldOrders`, `usp_RecalculateAllPricing`, `usp_CleanupTempData`, `usp_RebuildIndexes`.

**Known defects to fix**: non-idempotent batch → idempotent step functions with checkpoint table; orphaned `OrderItems` accumulation fixed by FK restoration in Order Service.

### Tasks

- [ ] ADR-008: Batch retirement — step decomposition, idempotency design
- [ ] Billing Service: scheduled job for auto-billing delivered orders with `IsBilled = 0`
- [ ] Billing Service: scheduled job for marking overdue invoices
- [ ] Dispatch Service: scheduled job for driver status recovery (`OnRoute > 16h` with no active shipment)
- [ ] Order Service: scheduled job for stale pending order notifications (wire up the email that was never connected)
- [ ] Ops email summary: replace `DB Mail` with an event-driven summary aggregated from service health endpoints
- [ ] Database maintenance: index rebuild and statistics update moved to PostgreSQL maintenance windows per service
- [ ] SQL Agent job `usp_ProcessEndOfDay` disabled after all replacement jobs verified
- [ ] Legacy monolith decommission checklist: confirm zero traffic to legacy procs before shutdown

---

## Cross-cutting: Anti-Corruption Layer & The Fence

Applied from Phase 1 onwards; tightened with each extraction.

- [ ] ACL library (shared NuGet package): `DataTable` → typed DTO translation; `CustomerType` code → enum mapping; result-set ordinal abstraction
- [ ] `PreToolUse` hook: rejects any new-service code importing from the legacy DB schema namespace (CI enforced from Phase 1)
- [ ] ADR-009: ACL design — what the hook enforces vs. what the `CLAUDE.md` prompt expresses as preference
- [ ] Contract tests: each service boundary has an OpenAPI contract test that runs alongside the characterization suite in CI

---

## Cross-cutting: Security (apply at each phase)

| Defect | Phase that fixes it |
|---|---|
| SQL injection in `usp_SearchCustomers` / `usp_SearchOrders` | Phase 3 / Phase 4 |
| No auth on `Admin/EndOfDay.aspx` | Phase 7 (decommission) — add role check to legacy page as interim fix in Phase 0 |
| InProc session state → random logouts | API Gateway (before Phase 1 cut-over) |
| Duplicate invoices | Phase 5 |
| Fuel surcharge hardcoded | Phase 1 |

---

## Milestone summary

| Milestone | Deliverable | Exit criterion |
|---|---|---|
| **M0** | Characterization suite + CI | All 42 procs behaviorally pinned; suite green in CI |
| **M1** | Pricing Service live | Shadow mode parity; cut-over complete; characterization suite still green |
| **M2** | Reporting Service live | 5 reports served by new service; legacy procs idle |
| **M3** | Customer Service live | CRUD + search via new service; ACL hook enforced |
| **M4** | Order Service live | Full order lifecycle via new service; Pricing + Customer dependencies satisfied |
| **M5** | Billing Service live | Event-driven billing; idempotent invoices; `TR_Invoices_UpdateBalance` disabled |
| **M6** | Dispatch/Shipment Service live | `TR_Shipments_AutoUpdateOrderStatus` retired; event pipeline verified |
| **M7** | Batch retired | SQL Agent job disabled; all replacement scheduled tasks verified |

---

## ADR register (planned)

| ADR | Decision | Needed by |
|---|---|---|
| ADR-001 | Strangler-fig decomposition | Done |
| ADR-002 | Pricing Service + Government pricing decision | Phase 1 start |
| ADR-003 | Reporting Service + read model strategy | Phase 2 start |
| ADR-004 | Customer Service + `CurrentBalance` boundary | Phase 3 start |
| ADR-005 | Order Service + status machine + events | Phase 4 start |
| ADR-006 | Billing Service + idempotency + balance ownership | Phase 5 start |
| ADR-007 | Dispatch/Shipment + trigger retirement | Phase 6 start |
| ADR-008 | Batch retirement + idempotency design | Phase 7 start |
| ADR-009 | ACL design: hook vs. prompt boundary | Phase 1 start |
