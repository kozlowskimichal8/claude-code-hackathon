# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a Claude Code Hackathon repository. The team is pursuing **Scenario 1 — Code Modernization** ([01-code-modernization.md](hackaton-instructions/01-code-modernization.md)): safely evolving the **Northwind Logistics** legacy monolith (in [lagacy/](lagacy/)) without a big-bang rewrite.

The hackathon emphasizes depth over breadth. Judges read commit history, so meaningful incremental commits matter.

## Scenario 1 Challenges (waypoints, not a checklist)

| # | Waypoint | Status |
|---|---|---|
| 1 | **The Stories** — User stories for the business capabilities that matter, with acceptance criteria sharp enough for a tester. | ✅ Done |
| 2 | **The Patient** — The legacy monolith is already generated (see [lagacy/](lagacy/)). | ✅ Done |
| 3 | **The Map** — Decomposition plan as an ADR: name the seams, rank services by extraction risk, include "what we chose not to do." | ✅ Done |
| 4 | **The Pin** — Characterization tests against the monolith *before* anyone touches it (behavior-pinning, bugs included). Docker Compose env + test plan complete; see [docs/the-pin-plan.md](docs/the-pin-plan.md). | ✅ Done |
| 5 | **The Cut** — Extract the first service with a clean API contract; monolith + service both proven green in a single test run. | ⬜ Next |
| 6 | **The Fence** — Anti-corruption layer between old and new. `PreToolUse` hook enforces the boundary deterministically; `CLAUDE.md` prompt expresses preference. Document the distinction in an ADR. | ⬜ Planned |
| 7 | **The Scorecard** — Eval harness: golden set of correct/incorrect seams, characterization suite as behavior-preservation check, CI metric for boundary correctness. | ⬜ Planned |
| 8 | **The Weekend** *(stretch)* — Cutover runbook for ops at 3am: steps, rollback triggers, decision tree. | ⬜ Planned |
| 9 | **The Scouts** *(stretch, agentic)* — Fan-out risk analysis using Task subagents, one per candidate seam, aggregated into a ranked list. Pass scope explicitly in each Task prompt. | ⬜ Planned |

## Architecture Decision Records

All significant decisions — tech stack choices, service extraction order, cross-cutting concerns, trade-offs with rejected alternatives — **must be recorded as an ADR before implementation begins**. No ADR = no implementation.

ADRs live in **[`decisions/`](decisions/)** and follow the naming convention `ADR-NNN-kebab-case-title.md`.

| ADR | Status | Decision |
|---|---|---|
| [ADR-001](decisions/ADR-001-strangler-fig-decomposition.md) | Accepted | Strangler-fig decomposition into 6 domain services |
| ADR-002 | Planned | Pricing Service — tech stack, Government pricing decision |
| ADR-003 | Planned | Reporting Service — read model strategy |
| ADR-004 | Planned | Customer Service — `CurrentBalance` boundary |
| ADR-005 | Planned | Order Service — status machine, event emission |
| ADR-006 | Planned | Billing Service — idempotency, `CurrentBalance` ownership |
| ADR-007 | Planned | Dispatch/Shipment Service — trigger retirement |
| ADR-008 | Planned | Batch retirement — step decomposition, idempotency |
| ADR-009 | Planned | ACL design — hook enforcement vs. CLAUDE.md preference |

When creating a new ADR, copy the structure from ADR-001: context, decision, extraction/implementation sequence, consequences (positive and negative), risks, and an explicit "what we chose not to do" section.

## Legacy Application Architecture (As-Is)

Full as-is architecture analysis lives in **[`docs/architecture/as-is/`](docs/architecture/as-is/)**. Read these before making any changes to the legacy system.

| Document | What it covers |
|---|---|
| [`overview.md`](docs/architecture/as-is/overview.md) | Infrastructure diagram, tech stack, deployment model |
| [`data-model.md`](docs/architecture/as-is/data-model.md) | All 10 tables, relationships, integrity gaps |
| [`application-layer.md`](docs/architecture/as-is/application-layer.md) | Web pages, data-access patterns, full proc/trigger inventory |
| [`business-flows.md`](docs/architecture/as-is/business-flows.md) | Order lifecycle, pricing formula, EOD batch, billing flow |
| [`known-issues.md`](docs/architecture/as-is/known-issues.md) | Security vulns, data integrity bugs, performance problems, tech debt |

The legacy app is a **database-centric ASP.NET 4.5 WebForms monolith** with SQL Server 2008 R2. About 80% of business logic lives in T-SQL stored procedures, not in application code.

## Target Architecture (To-Be)

The strangler-fig decomposition into 6 domain services is documented in **[`docs/architecture/to-be/overview.md`](docs/architecture/to-be/overview.md)**. Extraction order, ACL design, tech choices, and explicit non-goals are all there.

The rationale and trade-offs: **[`decisions/ADR-001-strangler-fig-decomposition.md`](decisions/ADR-001-strangler-fig-decomposition.md)**.

### Key layers

- **[lagacy/app/](lagacy/app/)** — ASP.NET WebForms (`.aspx` + code-behind `.aspx.cs`), no build system (deployed via xcopy)
  - `App_Code/DBHelper.cs` — sole data-access wrapper; executes `SqlCommand` and returns `DataTable`
  - `Default.aspx` — dashboard (5 separate DB calls per load)
  - `Orders/NewOrder.aspx` — order creation (has its own hardcoded connection string)
  - `Admin/EndOfDay.aspx` — EOD batch with no auth check and no recovery mechanism
- **[lagacy/database/](lagacy/database/)** — SQL scripts; run manually in numeric order
  - `00_schema.sql` → `01_seed_data.sql` → `02_triggers.sql` → then `procs/01_*` through `procs/07_*`
- **[lagacy/docs/SYSTEM_NOTES.txt](lagacy/docs/SYSTEM_NOTES.txt)** — original architecture notes and known issues (last updated Nov 2021)

### Database domain model

Six core domains with clear seams for extraction: **Customers**, **Orders**, **Shipments**, **Drivers/Vehicles**, **Billing**, **Reporting**.

Customer types: `R`=Regular, `P`=Premium, `C`=Contract, `G`=Government (unsupported — pricing falls back to Regular rates; Finance adjusts invoices manually).

Order status flow: `Pending → Assigned → PickedUp → InTransit → Delivered / Failed`. Also: `Cancelled`, `OnHold`.

### Triggers (side-effects to be aware of)

- `TR_Shipments_AutoUpdateOrderStatus` — mirrors every shipment status change back to the parent order; removal was attempted in 2016 and broke everything
- `TR_Orders_AuditStatusChange` — fires on every Orders UPDATE (not just status changes), writes to `AuditLog`
- `TR_Invoices_UpdateBalance` — recalculates `Customers.CurrentBalance` from scratch on every invoice insert/update

## Known Critical Issues

Full list in [`docs/architecture/as-is/known-issues.md`](docs/architecture/as-is/known-issues.md). Highest-priority items before any refactoring:

- **SQL injection** in `usp_SearchCustomers` and `usp_SearchOrders` via `@SortBy` (dynamic SQL, no whitelist) — NWL-389
- **Race condition** in `usp_GetActiveShipments` — global temp table (`##`) breaks under concurrent dispatchers
- **No auth check** on `Admin/EndOfDay.aspx` — any user who knows the URL can trigger EOD or rebuild indexes — NWL-441
- **Connection string duplicated** in three files: `web.config`, `Orders/NewOrder.aspx.cs`, `Admin/EndOfDay.aspx.cs`
- **Session state is InProc** — users randomly logged out when load balancer hits the second web server
- **EOD batch** has no recovery; partial failure leaves data inconsistent
- **Duplicate invoices** if `usp_CompleteShipment` is called twice

## Project Plan

The full strangler-fig extraction plan is at **[`docs/project-plan.md`](docs/project-plan.md)**. It covers all 8 phases (Phase 0 Safety Net through Phase 7 Batch Retirement) plus two cross-cutting tracks (ACL/Fence, Security). Each phase lists tasks, known defects being fixed, and an exit criterion.

## Product Backlog

User stories live in **[`docs/backlog/`](docs/backlog/)**, one folder per feature/phase:

| Folder | Feature | Stories |
|---|---|---|
| [`feature-0-safety-net/`](docs/backlog/feature-0-safety-net/) | Safety Net — characterization tests | US-001–009 |
| [`feature-1-pricing-service/`](docs/backlog/feature-1-pricing-service/) | Pricing Service extraction | US-101–110 |
| [`feature-2-reporting-service/`](docs/backlog/feature-2-reporting-service/) | Reporting Service extraction | US-201–208 |
| [`feature-3-customer-service/`](docs/backlog/feature-3-customer-service/) | Customer Service extraction | US-301–309 |
| [`feature-4-order-service/`](docs/backlog/feature-4-order-service/) | Order Service extraction | US-401–411 |
| [`feature-5-billing-service/`](docs/backlog/feature-5-billing-service/) | Billing Service extraction | US-501–510 |
| [`feature-6-dispatch-shipment-service/`](docs/backlog/feature-6-dispatch-shipment-service/) | Dispatch/Shipment Service extraction | US-601–611 |
| [`feature-7-batch-retirement/`](docs/backlog/feature-7-batch-retirement/) | Batch / Jobs retirement | US-701–709 |
| [`feature-8-acl-and-fence/`](docs/backlog/feature-8-acl-and-fence/) | Anti-Corruption Layer & The Fence | US-801–804 |
| [`feature-9-security/`](docs/backlog/feature-9-security/) | Cross-cutting security fixes | US-901–905 |

Each `feature.md` describes the goal, scope, story table, and exit criterion. Each `us-NNN-*.md` contains a user story, description, and specific testable acceptance criteria.

## Spec Folder

**[spec/](spec/)** contains static-analysis documents derived from the legacy codebase — written before any extraction work begins.

- **[spec/current-functionality.md](spec/current-functionality.md)** — Complete documentation of what the system does today: all 7 business capability domains (customer, order, dispatch, shipment, billing, reporting, batch), all 42 stored procs, 5 triggers, web pages, data model, and 10 behavioural constraints that characterization tests must pin. Also includes a seam-candidate table ranked by extraction risk, ready to feed into The Map ADR.

> Do not treat this file as a source of truth for the codebase — read the SQL and C# directly. Use it as orientation and as a checklist of behaviours to verify before touching anything.

## No Automated Build or Test Infrastructure

There are no `package.json`, `Makefile`, `Dockerfile`, or test suites. The legacy app was deployed manually. Any CI/CD, containerization, or test harness you introduce will be new work.
