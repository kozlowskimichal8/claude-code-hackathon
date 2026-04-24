# To-Be Architecture — Implementation Tasks

Based on [to-be architecture](../architecture/to-be/overview.md) and [ADR-001](../../decisions/ADR-001-strangler-fig-decomposition.md).
Extraction order: Pricing → Reporting → Customer → Order → Billing → Dispatch/Shipment → Batch/Jobs.

---

## Phase 0 — Foundation

**0.1 Docker Compose scaffold**
Create a `docker-compose.yml` at repo root with named services for PostgreSQL (shared initially, split later), RabbitMQ, and Redis. No application services yet.

*Acceptance criteria:*
- `docker compose up -d` starts all three infrastructure services without errors
- PostgreSQL is reachable on `localhost:5432`, RabbitMQ management UI on `localhost:15672`, Redis on `localhost:6379`
- Each service has a named volume so data survives container restarts
- A `.env.example` documents every required environment variable

---

**0.2 Shared OpenAPI contract conventions**
Document the API design rules all services must follow (naming, error shapes, pagination, versioning).

*Acceptance criteria:*
- A `docs/api-conventions.md` file exists
- Defines: snake_case field names, `application/problem+json` error responses, cursor-based pagination shape, `v1/` URL prefix
- Explicitly prohibits PascalCase field names (monolith leak)
- All future service OpenAPI specs are validated against these rules before merge

---

**0.3 CI skeleton**
Introduce a minimal CI pipeline that runs for every PR.

*Acceptance criteria:*
- Pipeline runs on each push; executes at minimum: lint, build, and fence-guard hook smoke test
- The fence-guard hook is tested with a fixture that confirms it blocks monolith identifiers and allows clean content
- Pipeline passes on a clean branch

---

## Phase 1 — The Fence (ACL infrastructure)

**1.1 PreToolUse hook and blocklist** *(see detailed tasks in [the-fence-tasks.md](the-fence-tasks.md), tasks 1–3)*

*Acceptance criteria:*
- `.claude/hooks/fence-guard.py` blocks writes of monolith field names into any `services/*/api/` path
- `.claude/hooks/monolith-fields.json` contains all column names from all 10 legacy tables
- `.claude/settings.json` registers the hook on `Write|Edit`

---

**1.2 ADR: The Fence** *(see [the-fence-tasks.md](the-fence-tasks.md), task 10)*

*Acceptance criteria:*
- `docs/adr/001-the-fence.md` explains hook-vs-prompt distinction with rationale
- Covers what was not done (CQRS, event sourcing, monolith-side blocking hook)

---

## Phase 2 — Pricing Service (extraction step 1)

**2.1 Characterization tests for `usp_CalculateOrderCost`**
Pin the exact pricing behaviour before touching it. Tests must pass against the legacy database.

*Acceptance criteria:*
- Tests cover: base rate + per-mile calculation, 15% fuel surcharge (hardcoded), $75 hazmat fee, priority multipliers (Normal ×1.0, High ×1.10, Urgent ×1.25), discount application, rounding to 2dp
- Test for Government customer (`G`) confirms it receives Regular rates (bug pinned, not fixed)
- All tests green against the unmodified legacy procs
- A test that would fail if the fuel surcharge changes from 15% (prevents silent drift)

---

**2.2 Pricing Service: domain model and API contract**
Pure stateless service. No database — reads config from environment.

*Acceptance criteria:*
- `GET /pricing/calculate` accepts: `customer_tier`, `weight_kg`, `distance_km`, `is_hazmat`, `priority`, `discount_pct`
- Response: `{ "base_cost": float, "surcharges": [...], "discount": float, "total": float }`
- Fuel surcharge percentage read from environment variable `FUEL_SURCHARGE_PCT`, not hardcoded
- Government tier returns Regular rates with a `"tier_fallback": true` flag in the response (makes the silent bug explicit)
- OpenAPI spec exists before implementation begins (contract-first)
- No monolith field names appear in the API contract

---

**2.3 Pricing Service: shadow mode validation**
Run new service in parallel with the legacy proc; compare outputs.

*Acceptance criteria:*
- For a sample of 100 real orders from the legacy DB, the Pricing Service produces identical totals to `usp_CalculateOrderCost`
- Any discrepancy is logged with the input that caused it
- Zero discrepancies on non-Government orders before the service is considered ready to cut over

---

## Phase 3 — Reporting Service (extraction step 2)

**3.1 Characterization tests for all 5 reporting procs**
Pin current report shapes before touching them.

*Acceptance criteria:*
- Tests cover: `usp_GetDailyShipmentReport`, `usp_GetDriverPerformanceReport`, `usp_GetRevenueReport`, `usp_GetCustomerActivityReport`, `usp_GetDelayedShipmentsReport`
- Each test pins the output column names and data types (not values)
- Tests confirm the `##global` temp table race condition exists (pin the bug)
- All tests green against unmodified legacy procs

---

**3.2 Reporting Service: read-only API against a DB replica**

*Acceptance criteria:*
- Service connects to a read replica (or the primary with a read-only account); never writes
- Five report endpoints exist, one per legacy proc equivalent
- `usp_GetActiveShipments` race condition is resolved: no global temp tables; per-request scoping
- `usp_GetRevenueReport`'s `@GroupBy` dynamic SQL injection is resolved: `GroupBy` is an enum (`day | week | month`), not a raw string
- All five characterization tests from 3.1 pass against the new endpoints

---

## Phase 4 — Customer Service (extraction step 3)

**4.1–4.9** See [the-fence-tasks.md](the-fence-tasks.md) for the detailed Customer Service tasks with acceptance criteria.

**4.10 Customer Service: PostgreSQL schema**
Own database; no shared tables with the monolith.

*Acceptance criteria:*
- Migration script creates the `customers` table using new field names (`postal_code` not `ZipCode`, etc.)
- `account_manager` is nullable (reflects the dropped staff table)
- `outstanding_balance` is not stored here — it is a Billing Service concern; column does not exist in this schema
- Migration is idempotent (safe to re-run)

---

**4.11 Customer Service: data sync during overlap**
The monolith and new service run in parallel until the cutover. Data must stay consistent.

*Acceptance criteria:*
- A sync script (or CDC approach) propagates writes from the legacy `Customers` table to the new PostgreSQL DB
- Sync lag is < 60 seconds under normal load
- The sync is observable (logs row counts and last-sync timestamp)
- A test confirms that a customer created in the monolith appears in the new service within the lag window

---

## Phase 5 — Order Service (extraction step 4)

**5.1 Characterization tests for order state machine**
The `usp_UpdateOrderStatus` god proc (280 lines, 8 transitions) must be fully pinned before extraction.

*Acceptance criteria:*
- Tests cover every valid transition: Pending→Assigned, Assigned→PickedUp, PickedUp→InTransit, InTransit→Delivered, InTransit→Failed, any→Cancelled, any→OnHold
- Tests pin the note-appending behaviour (timestamped notes appended to `SpecialInstructions`)
- Tests pin the auto-invoice creation on Delivered transition
- Tests cover the invalid transition cases (e.g. Delivered→Pending) and confirm they are rejected
- All tests green against unmodified legacy

---

**5.2 Order Service: state machine implementation**

*Acceptance criteria:*
- State machine is implemented as an explicit type (not a string field with if/else chains)
- All 8 valid transitions from 5.1 are implemented
- Invalid transitions return HTTP 422 with a message naming the current and requested states
- Note-appending on status change is replaced by a structured `status_history` array — no more free-text mutation of `special_instructions`
- `total_cost` is never `NULL` — order creation calls Pricing Service inside the same transaction; if pricing fails the order is rejected

---

**5.3 Order Service: credit limit enforcement**

*Acceptance criteria:*
- `POST /orders` calls Customer Service to retrieve the customer's tier and credit limit
- Regular and Premium customers are rejected if `outstanding_balance + estimated_cost > credit_limit` (HTTP 402)
- Contract and Government customers are not subject to the credit check
- The check uses the Customer Service's API — not a direct DB query against the legacy `Customers` table

---

## Phase 6 — Billing Service (extraction step 5)

**6.1 Replace invoice trigger with an order-delivered event**
`TR_Invoices_UpdateBalance` and the auto-invoice call in `usp_UpdateOrderStatus` are replaced by an event subscription.

*Acceptance criteria:*
- Order Service publishes an `order.delivered` event to the event bus when an order reaches `Delivered` status
- Billing Service subscribes to `order.delivered` and creates an invoice
- An idempotency key (order ID) prevents duplicate invoices — calling the handler twice produces exactly one invoice
- The `CurrentBalance` denormalized field on the legacy `Customers` table is no longer the source of truth; balance is queried from Billing Service

---

**6.2 Billing Service: invoice lifecycle**

*Acceptance criteria:*
- Invoice status transitions: `Draft → Sent → Paid` (full), `Sent → PartialPaid → Paid`, `Sent → Overdue`
- `POST /invoices` is idempotent: providing the same `order_id` twice returns the existing invoice (HTTP 200) not a duplicate (no HTTP 201)
- `POST /payments` rejects a duplicate `reference_number` for the same invoice
- Discount requires an `approved_by` field — any-user-can-grant-100%-discount vulnerability is closed
- Tax is always $0.00 (logistics exemption, but stored explicitly, not omitted)

---

## Phase 7 — Dispatch / Shipment Service (extraction step 6)

> Highest-risk extraction. `TR_Shipments_AutoUpdateOrderStatus` is the tightest coupling point. Do not begin until steps 1–6 are live and stable.

**7.1 Characterization tests for the trigger cascade**
Pin the exact behaviour of `TR_Shipments_AutoUpdateOrderStatus` before any attempt to remove it.

*Acceptance criteria:*
- Tests prove that updating a `Shipments` row automatically updates the parent `Orders.Status`
- Tests cover every status value the trigger propagates
- Tests confirm the 2016 removal attempt failure scenario is reproducible (or documented as unverifiable)
- All tests green against unmodified legacy

---

**7.2 Replace trigger cascade with events**

*Acceptance criteria:*
- Dispatch/Shipment Service publishes a `shipment.status_changed` event for every status update
- Order Service subscribes and updates the order status accordingly
- The legacy trigger `TR_Shipments_AutoUpdateOrderStatus` can be disabled without any characterization test failing
- The trigger is disabled (not dropped) initially, with a rollback path documented

---

**7.3 Dispatch board: fix `##global` temp table race condition**

*Acceptance criteria:*
- `GET /dispatch/active-shipments` is safe under concurrent requests (no global state)
- Load test with 10 concurrent requests produces no errors and returns consistent data
- The legacy proc's race condition test from the Reporting characterization suite now has a corresponding green test against the new endpoint

---

**7.4 Driver licence expiry and LOA enforcement**

*Acceptance criteria:*
- `POST /dispatch/assign` rejects drivers with `license_expiry_date < today` (HTTP 422)
- `POST /dispatch/assign` rejects drivers with `status = LOA` (HTTP 422)
- Both validations have tests that confirm they were not enforced in the legacy system (characterization) and are enforced in the new service (contract)

---

## Phase 8 — Batch / Jobs retirement (extraction step 7)

**8.1 Replace EOD SQL Agent job with idempotent scheduled tasks**

*Acceptance criteria:*
- Each EOD step (auto-bill, mark overdue, reset drivers, stale-order log, ops email, stats update) is a separate scheduled task owned by its domain service
- Each task is idempotent: re-running after a partial failure produces the same end state as a clean run
- A checkpoint table or equivalent records which steps completed, so a retry can skip already-completed work
- The SQL Agent job can be disabled without any business operation breaking

---

**8.2 Replace `usp_ArchiveOldOrders` with an Order Service archival task**

*Acceptance criteria:*
- Archived orders include their `OrderItems` (fixes the orphan accumulation bug)
- Archive is queryable via `GET /orders?status=archived`
- Running the archival task twice on the same dataset produces no duplicates

---

## Phase 9 — API Gateway

**9.1 Gateway routing**

*Acceptance criteria:*
- All six services are reachable through a single gateway host
- Routes: `/customers/*` → Customer Service, `/orders/*` → Order Service, `/pricing/*` → Pricing Service, `/reports/*` → Reporting Service, `/invoices/*` → Billing Service, `/dispatch/*` → Dispatch Service
- The legacy monolith is also reachable through the gateway as a fallback during the transition period

---

**9.2 Authentication: stateless JWTs replace InProc session**

*Acceptance criteria:*
- `POST /auth/login` returns a signed JWT with `sub`, `roles`, and `exp` claims
- All mutation endpoints (`POST`, `PATCH`, `DELETE`) require a valid JWT; unauthenticated requests receive HTTP 401
- Admin operations (EOD trigger, index rebuild) require a `role=admin` claim; requests without it receive HTTP 403
- The `Default.aspx` auth removal ("temporary" since 2021) is closed: the dashboard endpoint requires authentication
- Redis is used for token revocation; a logged-out token cannot be reused

---

**9.3 Government customer pricing: explicit agreement**
Before the Pricing Service goes live, the silent Regular-rate fallback for Government customers must be resolved.

*Acceptance criteria:*
- Finance has confirmed in writing (or an ADR) what rate Government customers should receive
- `PricingRules` has at least one row for `CustomerType='G'`, or the Pricing Service returns an explicit error for Government customers rather than a silent fallback
- The `"tier_fallback": true` flag from task 2.2 is removed once proper rules are in place

---

## Phase 10 — Cutover

**10.1 Cutover runbook** *(The Weekend)*

*Acceptance criteria:*
- Step-by-step instructions for switching production traffic from monolith to each new service
- Each step has a rollback trigger (observable signal that means "revert this step")
- Decision tree for the three most likely failure modes during cutover
- The runbook has been rehearsed at least once in a staging environment before production use
- Estimated time per step is documented so an ops team knows what they are committing to at 3am

---

**10.2 Decommission legacy stored procedures domain-by-domain**

*Acceptance criteria:*
- A stored proc is only decommissioned after its owning service has been live in production for ≥2 weeks with no incidents
- Decommissioning is recorded in an ADR update, not silently dropped
- The `TR_Shipments_AutoUpdateOrderStatus` trigger is the last item removed; its removal is preceded by a full regression run of all characterization tests
