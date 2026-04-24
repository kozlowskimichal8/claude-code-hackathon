# Northwind Logistics — To-Be Architecture

> Target state for Scenario 1 (Code Modernization). Evolves the legacy monolith via strangler fig — no big-bang rewrite.

---

## Guiding constraints

- Monolith stays live throughout; services are extracted incrementally
- Business logic currently lives in ~42 stored procs; each new service owns its own data
- Six clear bounded contexts already visible in the domain model

---

## Target state: 6 domain services behind an API gateway

```
┌──────────────────────────────────────────────────────────────┐
│                        API Gateway                           │
│          (routing, auth, rate-limit, ACL enforcement)        │
└────┬──────────┬──────────┬──────────┬──────────┬────────────┘
     │          │          │          │          │
  Customer   Order      Dispatch  Billing   Reporting
  Service    Service    /Shipment  Service   Service
     │          │        Service      │          │
  own DB     own DB      own DB    own DB    read from
 (Postgres) (Postgres)  (Postgres)(Postgres)  event store
                                              / replicas

                    ┌──────────────────┐
                    │   Event Bus       │
                    │  (Order events,   │
                    │  Shipment events) │
                    └──────────────────┘
                           ↑↓
             ┌─────────────────────────────┐
             │      Monolith (legacy)       │
             │   SQL Server 2008 R2         │
             │   (shrinks as seams cut)     │
             └─────────────────────────────┘
```

---

## Extraction order (lowest risk first)

| Step | Service | Why first |
|---|---|---|
| 1 | **Pricing** | Stateless, pure function, zero write coupling |
| 2 | **Reporting** | Read-only, no state mutation |
| 3 | **Customer** | Minimal cross-domain writes; credit-limit read only |
| 4 | **Order** | Depends on Customer + Pricing (already new) |
| 5 | **Billing** | Decouple from trigger; use events instead |
| 6 | **Dispatch / Shipment** | Tightly coupled via trigger; extract last |
| 7 | **Batch / Jobs** | Replace with scheduled service tasks across domains |

---

## Anti-corruption layer (The Fence)

The ACL sits between the monolith and any new service. Its responsibilities:

- Translate `DataTable` / result-set-by-ordinal responses into typed domain objects
- Map legacy `CustomerType` codes (`R/P/C/G`) to new enum values
- Absorb multi-result-set procs (e.g. `usp_GetOrder` returning 3 ordered result sets) so callers never touch raw ADO.NET shapes
- Block the `CurrentBalance` denormalized field from leaking into Customer Service's public API (balance is a Billing Service concern)

Enforce boundary in CI with a `PreToolUse` hook that rejects any new service code importing from the legacy DB schema namespace.

---

## Fixes built into new services (not carried forward)

| Legacy bug | Fix in new service |
|---|---|
| SQL injection via `@SortBy` | Parameterized queries only; sort column whitelist |
| `##global` temp table race condition | Scope per-request; or stream via event bus |
| Duplicate invoices (non-idempotent) | Idempotency key on `CreateInvoice` |
| Hardcoded fuel surcharge | Read from `SystemSettings` / config service |
| InProc session state | Stateless JWTs at API gateway |
| No auth on admin page | All mutation endpoints require role claim |
| EOD batch non-recoverable | Idempotent step functions with checkpoint table |

---

## Tech choices

- **.NET 8** for all new services (LTS, runs on Linux, same language as legacy)
- **PostgreSQL** per-service (break SQL Server 2008 coupling; cheaper licensing)
- **RabbitMQ or Azure Service Bus** for order/shipment events (replaces trigger cascade)
- **Redis** for distributed session (immediate fix for random logouts)
- **Docker + Compose** initially, Kubernetes when ≥3 services are live
- **OpenAPI** contract-first for each service boundary

---

## What we are choosing not to do

- No GraphQL federation — overkill for 8–10 drivers, 5k customers
- No event sourcing — adds complexity before the domain is stabilized
- No CQRS (separate read/write models) until Reporting Service proves out the pattern
- No rewrite of the WebForms UI — it stays as a thin shell calling the new APIs until a separate front-end decision is made
