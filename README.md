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

## What We Built

Northwind Logistics runs on a classic stored-procedure architecture: 40+ T-SQL procs spanning customers, orders, shipments, drivers, billing, reporting, and nightly batch operations, with a thin ASP.NET WebForms shell that is little more than ADO.NET call-forwarding. The original developers are long gone; what remains is `SYSTEM_NOTES.txt`, a handful of undocumented triggers, and tribal knowledge baked into proc naming conventions.

We generated the full legacy system (schema, seed data, triggers, stored procs, and thin ASP.NET app) as a realistic starting point. From there we applied a strangler-fig decomposition strategy: identify seams in the stored-proc surface, characterize the existing behavior before touching anything, then extract the first clean service behind an API façade — leaving the monolith intact and testable on every commit.

### As-Is Architecture Documentation

Full architecture analysis is in [`docs/architecture/as-is/`](docs/architecture/as-is/):

| Document | Contents |
|---|---|
| [`overview.md`](docs/architecture/as-is/overview.md) | Infrastructure diagram, tech stack, deployment model |
| [`data-model.md`](docs/architecture/as-is/data-model.md) | All 10 tables, relationships, integrity gaps |
| [`application-layer.md`](docs/architecture/as-is/application-layer.md) | Web pages, data-access patterns, full proc/trigger inventory |
| [`business-flows.md`](docs/architecture/as-is/business-flows.md) | Order lifecycle, pricing formula, EOD batch, billing flow |
| [`known-issues.md`](docs/architecture/as-is/known-issues.md) | Security vulns, data integrity bugs, performance problems, tech debt |

## Challenges Attempted

| # | Challenge | Status | Notes |
|---|---|---|---|
| 1 | The Stories | partial | Core capabilities: order intake, dispatch, billing run, customer lookup |
| 2 | The Patient | done | Stored-proc monolith generated: schema, 40 procs, triggers, ASP.NET shell |
| 3 | The Map | partial | Decomposition ADR drafted; seams ranked by extraction risk |
| 4 | The Pin | skipped | |
| 5 | The Cut | skipped | |
| 6 | The Fence | skipped | |
| 7 | The Scorecard | skipped | |
| 8 | The Weekend | skipped | |
| 9 | The Scouts | skipped | |

## Key Decisions

**Stored-proc flavor over PHP/Java** — The stored-proc architecture most faithfully represents the "logic lives in the database" anti-pattern common in logistics and finance back-offices. It makes seam identification harder and more interesting: you can't just split files, you have to reason about data coupling across proc groups.

**Strangler fig over big-bang rewrite** — The board said "modernize," not "rewrite." Strangler fig lets us ship value incrementally and keep the legacy running as a fallback, which is the only realistic option for a 24/7 logistics operation.

**Three-level CLAUDE.md** — User-level for personal preferences, project-level for shared codebase conventions, and a `lagacy/` directory-level file so Claude understands the legacy constraints (no refactoring of procs without a characterization test, never break the thin-shell contract).

See `/decisions/` for full ADRs (to be added).

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
