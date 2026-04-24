# Team Northwind Navigators

## Participants

- Dominik Bas (Dev / Tester)
- Jakub Foder (Dev / Architect)
- Mariusz Jadach (Dev / Platform)
- Piotr Ostrowski (Dev / Architect)
- Grzegorz Lukas (PM / Quality)
- Michal Kozlowski (Dev / Architect)
- Grzegorz Malicki (Dev / Tester)

## Scenario

Scenario 1: Code Modernization — "The Monolith"

## What we Built

We worked through the modernisation problem in six deliberate steps, using Claude Code at each stage to accelerate the work without losing architectural rigour.

### Step 1 — Generate the Legacy System

We started with nothing and used Claude Code to generate the full Northwind Logistics monolith from scratch: a 10-table SQL Server schema, 42 stored procedures across 7 business domains, 5 triggers, seed data, and a thin ASP.NET 4.5 WebForms shell wired to the database via ADO.NET. The goal was a realistic "patient" — one that had the same anti-patterns you find in real logistics back-offices: logic in the database, no tests, hardcoded config, and tribal knowledge baked into naming conventions.

The legacy system lives in [`lagacy/`](lagacy/).

### Step 2 — Document the As-Is Architecture

With the legacy system in place, we used Claude Code to perform a static analysis of the codebase and produce structured architecture documentation — before touching a single line. This gave the team a shared map of what the system actually does, including the bugs and the coupling that make extraction hard.

Full analysis in [`docs/architecture/as-is/`](docs/architecture/as-is/):

| Document | Contents |
|---|---|
| [`overview.md`](docs/architecture/as-is/overview.md) | Infrastructure diagram, tech stack, deployment model |
| [`data-model.md`](docs/architecture/as-is/data-model.md) | All 10 tables, relationships, integrity gaps |
| [`application-layer.md`](docs/architecture/as-is/application-layer.md) | Web pages, data-access patterns, full proc/trigger inventory |
| [`business-flows.md`](docs/architecture/as-is/business-flows.md) | Order lifecycle, pricing formula, EOD batch, billing flow |
| [`known-issues.md`](docs/architecture/as-is/known-issues.md) | Security vulns, data integrity bugs, performance problems, tech debt |

### Step 3 — Design the To-Be Architecture

With the as-is understood, we used Claude Code to design the target state: 6 domain services, each with its own database, communicating via an event bus, behind an API gateway. The strangler-fig pattern was chosen over a big-bang rewrite — the system runs 24/7 and cannot go dark. The extraction order was ranked by coupling risk, lowest first. Rationale was captured as ADR-001 before any implementation work was scoped.

Target state in [`docs/architecture/to-be/overview.md`](docs/architecture/to-be/overview.md). Decision rationale in [`decisions/ADR-001-strangler-fig-decomposition.md`](decisions/ADR-001-strangler-fig-decomposition.md).

### Step 4 — Generate the Functional Spec

Before planning any work we needed a precise record of what the system does today — including its bugs — that could serve as the baseline for characterization tests. Claude Code performed a deep static analysis of all 42 procs and 5 triggers and produced a complete functional spec: every business capability, every proc, every trigger side-effect, and 10 explicit behavioural constraints that tests must pin before extraction begins.

Spec in [`spec/current-functionality.md`](spec/current-functionality.md).

### Step 5 — Create the Project Plan

With the functional spec as input, we used Claude Code to derive an 8-phase strangler-fig execution plan: Phase 0 (Safety Net / characterization tests) through Phase 7 (Batch Retirement), plus two cross-cutting tracks (ACL & The Fence, Security). Each phase lists the procs being extracted, the defects being fixed by design, and a concrete exit criterion that must be met before the next phase starts.

Plan in [`docs/project-plan.md`](docs/project-plan.md).

### Step 6 — Generate the Product Backlog

Finally, we used Claude Code to decompose the project plan into a full product backlog: 10 features (one per phase), 86 user stories (one per task), each with a role, description, and specific testable acceptance criteria. Five parallel agents generated the backlog simultaneously, one agent per two features, in under 10 minutes.

Backlog in [`docs/backlog/`](docs/backlog/):

| Feature | Stories |
|---|---|
| [Feature 0 — Safety Net](docs/backlog/feature-0-safety-net/) | US-001–009: Docker Compose, CI, connection-string fix, characterization tests per domain |
| [Feature 1 — Pricing Service](docs/backlog/feature-1-pricing-service/) | US-101–110: ADR, OpenAPI, scaffold, schema, logic, shadow mode, ACL adapter, cut-over |
| [Feature 2 — Reporting Service](docs/backlog/feature-2-reporting-service/) | US-201–208: ADR, 5 report endpoints, temp-table fix, cut-over |
| [Feature 3 — Customer Service](docs/backlog/feature-3-customer-service/) | US-301–309: ADR, ACL adapter, `CurrentBalance` boundary, PreToolUse hook, cut-over |
| [Feature 4 — Order Service](docs/backlog/feature-4-order-service/) | US-401–411: ADR, status machine, events, FK restoration, Pricing/Customer integration |
| [Feature 5 — Billing Service](docs/backlog/feature-5-billing-service/) | US-501–510: ADR, event subscription, idempotency key, trigger retirement |
| [Feature 6 — Dispatch/Shipment Service](docs/backlog/feature-6-dispatch-shipment-service/) | US-601–611: ADR, trigger retirement, driver status machine, event pipeline |
| [Feature 7 — Batch Retirement](docs/backlog/feature-7-batch-retirement/) | US-701–709: 5 replacement jobs, SQL Agent disable, decommission checklist |
| [Feature 8 — ACL & The Fence](docs/backlog/feature-8-acl-and-fence/) | US-801–804: shared ACL library, PreToolUse hook, ADR-009, contract tests |
| [Feature 9 — Security](docs/backlog/feature-9-security/) | US-901–905: SQL injection, admin auth, JWT session, duplicate invoices, fuel surcharge config |

## Challenges Attempted

| # | Challenge | Status | Notes |
|---|---|---|---|
| 1 | The Stories | done | 86 user stories across 10 features; every story has role, description, and testable AC — see [`docs/backlog/`](docs/backlog/) |
| 2 | The Patient | done | Stored-proc monolith generated: schema, 40 procs, triggers, ASP.NET shell |
| 3 | The Map | done | ADR-001 accepted; full strangler-fig project plan with 7 extraction phases — see [`docs/project-plan.md`](docs/project-plan.md) |
| 4 | The Pin | skipped | |
| 5 | The Cut | skipped | |
| 6 | The Fence | skipped | |
| 7 | The Scorecard | skipped | |
| 8 | The Weekend | skipped | |
| 9 | The Scouts | skipped | |

## Architecture Decision Records

Significant decisions are recorded as ADRs in [`decisions/`](decisions/) before implementation. Each ADR covers: context, the decision, consequences (positive and negative), risks, and what was explicitly rejected.

| ADR | Status | Decision |
|---|---|---|
| [ADR-001](decisions/ADR-001-strangler-fig-decomposition.md) | Accepted | Strangler-fig decomposition into 6 domain services |

## Key Decisions

**Stored-proc flavor over PHP/Java** — The stored-proc architecture most faithfully represents the "logic lives in the database" anti-pattern common in logistics and finance back-offices. It makes seam identification harder and more interesting: you can't just split files, you have to reason about data coupling across proc groups.

**Strangler fig over big-bang rewrite** — The board said "modernize," not "rewrite." Strangler fig lets us ship value incrementally and keep the legacy running as a fallback, which is the only realistic option for a 24/7 logistics operation. See [ADR-001](decisions/ADR-001-strangler-fig-decomposition.md).

**Three-level CLAUDE.md** — User-level for personal preferences, project-level for shared codebase conventions, and a `lagacy/` directory-level file so Claude understands the legacy constraints (no refactoring of procs without a characterization test, never break the thin-shell contract).

## How to Run It

> Prerequisites: Docker (for SQL Server), .NET SDK 4.8 or the `dotnet` CLI with Windows compatibility layer.

```bash
# 1. Start SQL Server in Docker
docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=Northwind!23" \
  -p 1433:1433 --name northwind-sql -d mcr.microsoft.com/mssql/server:2019-latest

# 2. Apply schema, seed data, triggers, and stored procs
for f in legacy/database/00_schema.sql \
          legacy/database/01_seed_data.sql \
          legacy/database/02_triggers.sql \
          legacy/database/procs/*.sql; do
  sqlcmd -S localhost -U sa -P "Northwind!23" -i "$f"
done

# 3. Update the connection string in legacy/app/web.config if needed, then run
cd legacy/app && dotnet run
```

## If We Had More Time

1. **The Pin** — Characterization tests against the stored procs before any extraction. This is the safety net everything else depends on.
2. **The Cut** — Extract the Order service (lowest coupling, highest business value) with a REST API contract and a contract test that runs alongside the characterization suite.
3. **The Fence** — Anti-corruption layer with a `PreToolUse` hook preventing Claude from writing across the boundary, paired with a `CLAUDE.md` prompt for preference-based guidance and an ADR explaining why each is a hook vs. a prompt.
4. **The Scouts** — Fan-out subagents (one per proc group) scoring extraction risk: coupling, test coverage, data-model tangle, business criticality. Coordinator aggregates into a ranked list and compares against the human ADR from The Map.
5. **The Scorecard** — CI eval harness measuring whether Claude proposes correct seam boundaries and how often it claims high confidence on a wrong answer.
6. **The Weekend** — A 3am-readable cutover runbook with rollback triggers and a decision tree, rehearsed at least once.

## How We Used Claude Code

**What worked well:**
- Generating the full legacy monolith (schema + procs + app) in one coordinated pass — Claude maintained consistency across 40+ procs and the thin-shell contract without drift.
- Three-level `CLAUDE.md` scaffolding helped Claude stay context-aware when switching between the legacy `lagacy/` root and future new-service directories.
- Plan Mode before any schema or proc generation to align on the architecture before writing anything irreversible.

**What surprised us:**
- Claude flagged coupling issues between the billing and shipment proc groups that we hadn't noticed — it effectively did a first-pass seam analysis unprompted.
- The `SYSTEM_NOTES.txt` doc Claude generated was eerily realistic, complete with passive-aggressive warnings about the batch proc scheduler.

**Where it saved the most time:**
- Boilerplate elimination: ADO.NET call-forwarding, web.config wiring, and SQL schema generation that would have taken hours was done in minutes, leaving more time for architectural thinking.
