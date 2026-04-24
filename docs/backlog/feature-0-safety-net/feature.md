# Feature 0: Safety Net (The Pin)

## Goal
Pin every observable behaviour of the legacy monolith with integration tests before a single line of production code is changed.

## Description
This phase establishes the characterization test suite that acts as the safety net for all subsequent extraction work. Tests encode what the system actually does today — including bugs — not what it should do. Every stored procedure (all 42) and every trigger (all 5) must have at least one test that fails if its observable behaviour changes. The suite runs in a reproducible Docker environment so any contributor can verify the full legacy stack locally, and CI enforces it on every commit. No extraction work in later features may begin until this suite is fully green and checked in.

## Scope
- All 42 stored procedures across Customer, Order, Dispatch, Shipment, Billing, Reporting, and Batch domains
- All 5 triggers: `TR_Shipments_AutoUpdateOrderStatus`, `TR_Orders_AuditStatusChange`, `TR_Invoices_UpdateBalance`, and the two additional triggers defined in `02_triggers.sql`
- Connection string consolidation (prerequisite hygiene before tests can be written cleanly)
- Docker Compose environment for SQL Server 2019 running all legacy scripts in order
- CI pipeline skeleton that enforces the suite on every push and pull request
- Known defects are pinned, not fixed: duplicate invoices, Government pricing fallback, global temp table race condition, missing auth on `Admin/EndOfDay.aspx`

## User Stories

| ID | Title |
|---|---|
| [US-001](us-001-docker-compose-environment.md) | Docker Compose Environment |
| [US-002](us-002-ci-pipeline-skeleton.md) | CI Pipeline Skeleton |
| [US-003](us-003-connection-string-consolidation.md) | Connection String Consolidation |
| [US-004](us-004-behavioural-constraint-tests.md) | Behavioural Constraint Tests |
| [US-005](us-005-customer-domain-tests.md) | Customer Domain Tests |
| [US-006](us-006-order-domain-tests.md) | Order Domain Tests |
| [US-007](us-007-pricing-domain-tests.md) | Pricing Domain Tests |
| [US-008](us-008-dispatch-domain-tests.md) | Dispatch Domain Tests |
| [US-009](us-009-shipment-billing-reporting-batch-tests.md) | Shipment, Billing, Reporting, and Batch Domain Tests |

## Exit Criterion
All characterization tests (US-004 through US-009) are green against the unmodified legacy database; the Docker Compose environment starts cleanly from a fresh checkout; the CI pipeline passes on `main`; the full suite is committed to the repository and no test is marked skip or quarantine.
