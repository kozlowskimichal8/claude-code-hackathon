# The Pin — Implementation Plan

**Scenario 1, Waypoint 4**: Characterization tests against the legacy monolith, before any code changes.

---

## What We Are Building

A reproducible test environment that runs the full legacy SQL Server database in Docker and executes a pytest-based characterization suite against every stored procedure and trigger. The goal is to pin every observable behaviour — bugs included — so that future extractions are caught immediately if they change anything.

---

## Output Locations

| Artefact | Path | Purpose |
|---|---|---|
| Docker Compose | `docker-compose.yml` | Starts SQL Server 2019 + runs init scripts |
| DB init script | `docker/init-db.sh` | Applies all SQL scripts in order via `sqlcmd` |
| Test dependencies | `tests/requirements.txt` | `pytest`, `pyodbc` |
| pytest config | `tests/pytest.ini` | Test root, verbosity, short tracebacks |
| Test fixtures | `tests/characterization/conftest.py` | DB connection, per-test cleanup helper, shared `create_*` helpers |
| Behavioural constraints | `tests/characterization/test_behavioral_constraints.py` | US-004: 10 cross-cutting constraint tests |
| Customer domain | `tests/characterization/test_customer_domain.py` | US-005: 5 procs |
| Order domain | `tests/characterization/test_order_domain.py` | US-006: 8 procs + state machine |
| Pricing domain | `tests/characterization/test_pricing_domain.py` | US-007: all weight tiers, hazmat, priority, discount, Government fallback |
| Dispatch domain | `tests/characterization/test_dispatch_domain.py` | US-008: 6 driver procs, LOA gap |
| Shipment domain | `tests/characterization/test_shipment_domain.py` | US-009 part 1: 6 shipment procs, global temp table note |
| Billing domain | `tests/characterization/test_billing_domain.py` | US-009 part 2: 7 billing procs, duplicate invoice bug |
| Reporting domain | `tests/characterization/test_reporting_domain.py` | US-009 part 3: 5 reporting procs, column shapes |
| Batch domain | `tests/characterization/test_batch_domain.py` | US-009 part 4: EOD, archive, cleanup, index rebuild |
| CI pipeline | `.github/workflows/characterization-tests.yml` | US-002: runs on every push/PR |

Total: **42 stored procedures** and **5 triggers** covered.

---

## Technology Choices

- **SQL Server 2019** in Docker (`mcr.microsoft.com/mssql/server:2019-latest`) — behaviourally compatible with the legacy 2008 R2 schema and procs; the only containerised option from Microsoft.
- **Python + pytest + pyodbc** — no .NET SDK required, cross-platform, straightforward SQL result assertions. ODBC Driver 17/18 for SQL Server handles the connection.
- **GitHub Actions** for CI — free for public repos; uses the same Docker Compose setup so CI and local runs are identical.

---

## Docker Compose Design

```
docker-compose.yml
  └─ sqlserver          mcr.microsoft.com/mssql/server:2019-latest
                        port 1433 exposed; healthcheck via sqlcmd SELECT 1
  └─ db-init            same image (has sqlcmd); depends_on sqlserver healthy
                        mounts lagacy/database/ and docker/
                        runs init-db.sh, then exits

docker/init-db.sh       runs all scripts in strict order:
                          00_schema.sql
                          01_seed_data.sql
                          02_triggers.sql
                          procs/01_customer_procs.sql … procs/07_batch_procs.sql
```

`docker compose up` is the single command to start a ready database. `docker compose down -v` removes all state.

---

## Test Infrastructure (conftest.py)

- **Session-scoped connection** — one `pyodbc` connection (`autocommit=True`) shared across the entire test run; no per-test reconnect overhead.
- **`cursor` fixture** — function-scoped; yields a fresh cursor and closes it after each test.
- **`cleanup` fixture** — function-scoped; collects `(table, pk_column, pk_value)` tuples during each test and deletes them in reverse FK-safe order after the test. This lets every test create real, committed data without polluting subsequent tests.
- **`create_*` helpers** — `create_customer`, `create_order`, `create_driver`, `create_vehicle` — call the stored procedures via `EXEC … OUTPUT` and return the new ID, also registering the entity for cleanup.

---

## What Each Test File Covers

### test_behavioral_constraints.py (US-004)

The 10 highest-risk cross-cutting behaviours. Each test is independent and pins the behaviour as-is, including bugs:

| # | Behaviour pinned |
|---|---|
| 1 | `usp_GetOrder` returns exactly 3 result sets in fixed ordinal position |
| 2 | Updating a `Shipments` row fires `TR_Shipments_AutoUpdateOrderStatus` and propagates status to `Orders` |
| 3 | `usp_UpdateOrderStatus` appends a timestamped note to `SpecialInstructions` |
| 4 | `usp_CreateOrder` with no matching pricing rule leaves `TotalCost = NULL` on the order row |
| 5 | `usp_CreateInvoice` called twice on the same order ID inserts two invoice rows (no idempotency guard) |
| 6 | `usp_CompleteShipment` called twice on the same shipment does not create duplicate invoices (the explicit `usp_UpdateOrderStatus` call was commented out in 2021 — pinning the fixed state) |
| 7 | `Customers.CurrentBalance` is stale until a new invoice is inserted; `TR_Invoices_UpdateBalance` refreshes it on INSERT |
| 8 | `usp_ArchiveOldOrders` moves `Orders` rows to `Orders_Archive` but leaves their child `OrderItems` rows in the live table |
| 9 | `Admin/EndOfDay.aspx` returns HTTP 200 with no authentication header (requires the ASP.NET app to be running; skipped in DB-only CI, documented as manual check) |
| 10 | A Government (`G`) customer is billed at Regular (`R`) rates — `usp_CalculateOrderCost` maps `G → R` before the pricing-rule lookup |

### test_customer_domain.py (US-005)

- `usp_CreateCustomer`: null `CompanyName` raises an error; unknown `CustomerType` silently stores `'R'`
- `usp_UpdateCustomer`: sparse-update pattern — passing `NULL` for an existing non-null field leaves the original value unchanged
- `usp_SearchCustomers`: valid `@SortBy` executes without error; SQL injection vector documented in test comment, not blocked
- Credit-limit enforcement in `usp_CreateOrder`: Regular/Premium blocked when balance + estimated cost > limit; Contract and Government exempt

### test_order_domain.py (US-006)

- Every valid status transition through the `usp_UpdateOrderStatus` state machine: `Pending → Assigned → PickedUp → InTransit → Delivered`, `InTransit → Failed`, `Pending → Cancelled`, any active → `OnHold`
- At least one invalid transition (`Delivered → Assigned`) is rejected with an error
- `usp_GetPendingOrders` returns only `Pending` orders; other statuses absent
- `usp_GetOrdersByCustomer` cursor-based pagination: page 2 returns the correct offset rows

### test_pricing_domain.py (US-007)

Exact `TotalCost` values are pre-computed from the pricing formula and asserted precisely:

- All 4 customer types (`R`, `P`, `C`, `G`) × 3+ weight tiers each
- Hazmat fee: exactly **$75** added when `IsHazmat = 1`, absent when `0`
- Priority multipliers: `N` = ×1.0, `H` = ×1.10, `U` = ×1.25
- Fuel surcharge hardcoded at **15%** — test comment references NWL known-issue (to be fixed in Feature 1)
- Discount: order with `DiscountPct = 10` produces `TotalCost` 10% below the pre-discount amount
- Government customer with identical inputs to a Regular customer produces the same `TotalCost`

### test_dispatch_domain.py (US-008)

- `usp_GetAvailableDrivers`: driver with licence expiring within 1 month appears in results with `LicenseExpiringSoon = 1`; driver with `Status = 'LOA'` does **not** appear (the WHERE clause filters on `'Available'` — pinning actual code behaviour, which contradicts the code comment)
- `usp_AssignDriver`: assigns a driver with a near-expiry licence without error
- `usp_CreateDriver`: duplicate licence number creates a second row and writes a warning to `AuditLog`; both rows exist
- `usp_AssignOrderToDriver`: creates a `Shipments` row; sets driver `Status = 'OnRoute'`; sets vehicle `Status = 'InUse'`

### test_shipment_domain.py (US-009)

- `usp_GetActiveShipments`: executes without error in a single-connection test; test comment documents the `##global` temp table concurrency hazard (NWL reference)
- `usp_FailShipment`: sets `FailureReason`; releases driver back to `Available`; releases vehicle back to `Available`; order status is `Failed`, not `Pending` (no re-queue)
- `usp_GetShipmentTracking`: `DriverInitials` column contains first name + first letter of last name + `.`; ETA formula is `StartTime + (EstimatedMiles / 50) hours`

### test_billing_domain.py (US-009)

- `usp_CreateInvoice` called twice on the same `OrderID` → `COUNT(*) = 2` in `Invoices` (bug pinned)
- `usp_ProcessPayment` called twice with the same `ReferenceNumber` → both rows exist in `Payments`
- `TR_Invoices_UpdateBalance`: insert invoice 1, assert balance updated; insert invoice 2, assert balance increased; delete invoice 2, balance does NOT automatically decrease (trigger only fires on INSERT/UPDATE, not DELETE — pinning this limitation)

### test_reporting_domain.py (US-009)

- All 5 reporting procs execute without error against the seed data
- Each proc's first result set column names are asserted: `usp_GetDailyShipmentReport`, `usp_GetDriverPerformanceReport`, `usp_GetRevenueReport`, `usp_GetCustomerActivityReport`, `usp_GetDelayedShipmentsReport`

### test_batch_domain.py (US-009)

- `usp_ProcessEndOfDay @DryRun=1` completes without error and returns the summary result set with the expected columns
- Non-idempotency bug: create a `Delivered`, `IsBilled=0` order with no invoice; call `usp_CreateInvoice` directly; reset `IsBilled=0`; run EOD (`@DryRun=0, @ForceRerun=1`) → second invoice created; assert `COUNT(*) = 2` for that order
- `usp_ArchiveOldOrders @DryRun=1` returns an `OrdersArchived` count without modifying data
- `usp_CleanupTempData @DryRun=1` returns orphan/stuck counts without modifying data

---

## CI Pipeline (GitHub Actions)

```
.github/workflows/characterization-tests.yml

Trigger: push or PR to main

Jobs:
  characterization-tests (ubuntu-latest)
    1. Checkout
    2. docker compose up -d sqlserver       # start DB
    3. Wait for sqlserver healthcheck
    4. docker compose up db-init            # run SQL init scripts
    5. Install msodbcsql18 + unixodbc-dev
    6. pip install -r tests/requirements.txt
    7. pytest tests/characterization/ -v    # run the full suite
    env: DB_HOST=localhost, DB_PORT=1433, DB_USER=sa, DB_PASSWORD=NWL_Dev_2024!
```

The job fails if any test fails. No test may be skipped or quarantined — per the feature exit criterion.

---

## Exit Criterion (from US-001 – US-009)

The suite is considered complete when:
- `docker compose up` starts a clean database in one command from a fresh checkout
- `pytest tests/characterization/` passes green with zero skips
- CI passes on `main`
- Every one of the 42 stored procedures and 5 triggers has at least one test exercising it
