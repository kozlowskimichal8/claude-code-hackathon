# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a Claude Code Hackathon repository. The team is pursuing **Scenario 1 — Code Modernization** ([01-code-modernization.md](hackaton-instructions/01-code-modernization.md)): safely evolving the **Northwind Logistics** legacy monolith (in [lagacy/](lagacy/)) without a big-bang rewrite.

The hackathon emphasizes depth over breadth. Judges read commit history, so meaningful incremental commits matter.

## Scenario 1 Challenges (waypoints, not a checklist)

1. **The Stories** — User stories for the business capabilities that matter, with acceptance criteria sharp enough for a tester.
2. **The Patient** — The legacy monolith is already generated (see [lagacy/](lagacy/)).
3. **The Map** — Decomposition plan as an ADR: name the seams, rank services by extraction risk, include "what we chose not to do."
4. **The Pin** — Characterization tests against the monolith *before* anyone touches it (behavior-pinning, bugs included).
5. **The Cut** — Extract the first service with a clean API contract; monolith + service both proven green in a single test run.
6. **The Fence** — Anti-corruption layer between old and new. Monolith data model must not leak into the new service's public shape. Use a `PreToolUse` hook to enforce the boundary deterministically; use a `CLAUDE.md` prompt to express preference ("prefer the new service for X"). Document the distinction in an ADR.
7. **The Scorecard** — Eval harness for LLM-driven refactoring: golden set of correct/incorrect seams, characterization suite as behavior-preservation check, CI metric for boundary correctness.
8. **The Weekend** *(stretch)* — Cutover runbook for ops at 3am: steps, rollback triggers, decision tree.
9. **The Scouts** *(stretch, agentic)* — Fan-out risk analysis using Task subagents, one per candidate seam, aggregated into a ranked list. Pass scope explicitly in each Task prompt.

## Legacy Application Architecture

The legacy app is a **database-centric ASP.NET 4.5 WebForms monolith** with SQL Server 2008 R2. About 80% of business logic lives in T-SQL stored procedures, not in application code.

### Key layers

- **[lagacy/app/](lagacy/app/)** — ASP.NET WebForms (`.aspx` + code-behind `.aspx.cs`), no build system (deployed via xcopy)
  - `App_Code/DBHelper.cs` — sole data-access wrapper; executes `SqlCommand` and returns `DataTable`
  - `Default.aspx` — dashboard (5 separate DB calls per load)
  - `Orders/NewOrder.aspx` — order creation (has its own hardcoded connection string)
  - `Admin/EndOfDay.aspx` — EOD batch with no auth check and no recovery mechanism
- **[lagacy/database/](lagacy/database/)** — SQL scripts; run manually in numeric order
  - `00_schema.sql` → `01_seed_data.sql` → `02_triggers.sql` → then `procs/01_*` through `procs/07_*`
- **[lagacy/docs/SYSTEM_NOTES.txt](lagacy/docs/SYSTEM_NOTES.txt)** — authoritative architecture notes and known issues (last updated Nov 2021)

### Database domain model

Six core domains with clear seams for extraction: **Customers**, **Orders**, **Shipments**, **Drivers/Vehicles**, **Billing**, **Reporting**.

Customer types: `R`=Regular, `P`=Premium, `C`=Contract, `G`=Government (unsupported — pricing falls back to a manual Finance workaround).

Order status flow: `Pending → Assigned → PickedUp → InTransit → Delivered`.

## Known Critical Issues (from SYSTEM_NOTES.txt)

These are documented bugs — relevant context before refactoring:

- **SQL injection** in `usp_SearchCustomers` and `usp_SearchOrders` via the `@SortBy` parameter (dynamic SQL, unparameterized)
- **Race condition** in `usp_GetActiveShipments` — uses a global temp table (`##ActiveShipments`), breaks under concurrent dispatchers
- **Connection string duplicated** in three files: `web.config`, `DBHelper.cs`, `EndOfDay.aspx.cs`
- **Session state is InProc** — users are randomly logged out when the load balancer hits the second web server
- **EOD batch** (`usp_EndOfDayProcessing`) has no recovery; partial failure leaves the system in an inconsistent state
- **Duplicate invoices** if `usp_CompleteShipment` is called twice (idempotency not enforced)
- **`usp_GenerateMonthlyStatements`** takes ~45 seconds (cursor-based; needs set-based rewrite)

## No Automated Build or Test Infrastructure

There are no `package.json`, `Makefile`, `Dockerfile`, or test suites. The legacy app was deployed manually. Any CI/CD, containerization, or test harness you introduce will be new work.
