# ADR-001: Strangler-Fig Decomposition of the Northwind Logistics Monolith

| Field | Value |
|---|---|
| **Date** | 2026-04-24 |
| **Status** | Accepted |
| **Deciders** | Jakub Foder, Piotr Ostrowski, Michal Kozlowski |

---

## Context

Northwind Logistics runs on a 17-year-old SQL Server 2008 R2 + ASP.NET 4.5 WebForms monolith. Approximately 80% of business logic lives in 42 T-SQL stored procedures; the ASP.NET layer is a thin ADO.NET call-forwarder. The system operates 24/7 for a logistics operation (~5,000 customers, 10,000+ active orders, 8–10 drivers).

The accumulated state of the system:
- Multiple open security vulnerabilities (SQL injection, no auth on admin page)
- Race conditions under concurrent use (global temp tables)
- Non-idempotent batch operations with no recovery path
- Hardcoded configuration in three separate files
- Session state tied to a single web server (random logouts under load balancing)
- No CI/CD, no automated tests, no monitoring
- Original developer retired in 2015; documented tribal knowledge last updated November 2021

The business has asked for modernisation. The constraint is that the system cannot go down: it is a live logistics operation where orders, shipments, and driver dispatch must keep running throughout any transition.

Six bounded contexts are clearly visible in the stored-proc surface: **Customer**, **Order**, **Dispatch/Shipment**, **Billing**, **Reporting**, and **Batch**.

---

## Decision

We will apply the **strangler-fig pattern**: extract domain services one at a time from the monolith, routing traffic progressively to new services while the legacy system remains fully operational as a fallback. No big-bang rewrite.

### Target topology

Six domain services, each with its own database, communicating via an event bus for asynchronous state changes (replacing the current trigger-based cascade). An API gateway handles routing, authentication, and anti-corruption layer enforcement.

Full target-state diagram and service responsibilities: [`docs/architecture/to-be/overview.md`](../docs/architecture/to-be/overview.md).

### Extraction sequence

Ordered by coupling complexity and production risk, lowest first:

| Step | Service | Rationale |
|---|---|---|
| 1 | **Pricing** | Stateless pure function; zero write coupling; safe to shadow-run |
| 2 | **Reporting** | Read-only; no state mutations; can run against a replica |
| 3 | **Customer** | Minimal cross-domain writes; well-bounded data model |
| 4 | **Order** | Depends on Customer + Pricing (already extracted by this point) |
| 5 | **Billing** | Decouple from invoice trigger; replace with order-delivered event |
| 6 | **Dispatch / Shipment** | Tightly coupled via `TR_Shipments_AutoUpdateOrderStatus`; extract last |
| 7 | **Batch / Jobs** | Fan-out to individual service APIs; retire SQL Agent jobs |

### Anti-corruption layer

An explicit ACL sits at every boundary between monolith and new service. It:
- Translates `DataTable` / ordinal result-set responses into typed domain objects
- Maps legacy `CustomerType` codes (`R/P/C/G`) to new enum values
- Prevents the `CurrentBalance` denormalized field (a billing concern) from appearing in the Customer Service public API
- Is enforced by a `PreToolUse` hook in CI that rejects any new-service code importing from the legacy DB schema namespace

### Tech stack for new services

| Concern | Choice | Reason |
|---|---|---|
| Runtime | .NET 8 | LTS; runs on Linux; same language as legacy — lower context-switch cost |
| Database | PostgreSQL (per-service) | Breaks SQL Server 2008 coupling; no per-core licensing |
| Async messaging | RabbitMQ or Azure Service Bus | Replaces trigger cascade with durable, observable events |
| Session state | Redis | Immediate fix for load-balancer session loss |
| Deployment | Docker Compose → Kubernetes | Compose until ≥3 services live, then graduate |
| API contracts | OpenAPI (contract-first) | Each service boundary has a machine-readable contract before code is written |

### Bugs that are not carried forward

Each extracted service fixes the defects in its domain by design:

| Legacy defect | Resolution in new service |
|---|---|
| SQL injection via `@SortBy` | Parameterized queries; sort column whitelist |
| `##global` temp table race condition | Per-request scope; event-driven dispatch board |
| Non-idempotent invoice creation | Idempotency key on `CreateInvoice` |
| Hardcoded 15% fuel surcharge | Read from config / `SystemSettings` |
| InProc session state | Stateless JWTs at API gateway |
| No auth on admin endpoints | All mutation endpoints require role claim |
| Non-recoverable EOD batch | Idempotent step functions with a checkpoint table |

---

## Consequences

**Positive**
- Monolith never goes dark; rollback is always available by re-routing to the legacy proc
- Each extracted service can be tested, deployed, and scaled independently
- Security and data-integrity defects are fixed domain-by-domain, not as a single risky patch
- New services are cloud-portable from day one

**Negative / trade-offs**
- Two systems run in parallel during transition — operational complexity increases before it decreases
- Event-driven billing (replacing the trigger) introduces eventual consistency; the billing team needs to accept a short lag between delivery confirmation and invoice creation
- Data must be kept in sync across two databases during the overlap period for each extracted domain

**Risks**
- The `TR_Shipments_AutoUpdateOrderStatus` trigger is the tightest coupling point; extracting Dispatch/Shipment (step 6) carries the highest rollback risk and needs the most characterization test coverage before any cut
- Government customer pricing (`G` type) has no rules in the current system and falls back to Regular rates; this silent behaviour must be made explicit (and agreed with Finance) before the Pricing Service goes live

---

## What we chose not to do

| Option | Reason rejected |
|---|---|
| Big-bang rewrite | Unacceptable downtime risk for a 24/7 logistics operation |
| GraphQL federation | Over-engineered for current scale (8–10 drivers, 5k customers) |
| Event sourcing | Adds complexity before the domain model is stabilised in new services |
| CQRS from the start | Deferred until Reporting Service proves out the read/write split pattern |
| Rewrite the WebForms UI | Separate decision; UI stays as a thin shell calling new APIs until a front-end track is funded |
| Lift-and-shift to Azure SQL | Does not address the stored-proc coupling or security defects; just moves the problem |

---

## Related documents

- As-is architecture: [`docs/architecture/as-is/`](../docs/architecture/as-is/)
- To-be architecture: [`docs/architecture/to-be/overview.md`](../docs/architecture/to-be/overview.md)
- Legacy known issues: [`docs/architecture/as-is/known-issues.md`](../docs/architecture/as-is/known-issues.md)
- Static-analysis spec: [`spec/current-functionality.md`](../spec/current-functionality.md)
