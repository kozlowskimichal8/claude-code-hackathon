# Feature 7: Batch / Jobs Retirement

## Goal

Retire the legacy `usp_ProcessEndOfDay` SQL Agent job by distributing each of its steps to the service that owns the relevant domain data, replacing a non-idempotent monolith batch with independently operable, idempotent scheduled tasks.

## Description

The legacy EOD batch (`usp_ProcessEndOfDay`) is a six-step SQL Agent job that runs nightly and performs work spanning five domain areas: auto-billing, overdue invoice marking, driver status reset, stale order notification, ops summary email, and database maintenance. It is non-idempotent — a partial failure leaves data in an inconsistent state with no recovery path. The `Admin/EndOfDay.aspx` page that triggers it has no authentication check, and the notification email in step 4 was never wired up.

This phase distributes each step to the service that owns the data: auto-billing and overdue marking go to the Billing Service, driver status reset goes to the Dispatch Service, stale order notification goes to the Order Service, the ops summary email becomes an aggregated call across service health endpoints, and database maintenance moves to PostgreSQL-native `pg_cron` jobs. Each replacement task is an idempotent step function with a checkpoint table, so partial failures are safe to retry. Feature 7 requires all Phases 1 through 6 to be live before it begins.

Upon completion, the SQL Agent job is disabled and the monolith decommission checklist reaches its final item. The strangler-fig decomposition is complete.

## Scope

**Stored procedures retired:**
`usp_ProcessEndOfDay`, `usp_ArchiveOldOrders`, `usp_RecalculateAllPricing`, `usp_CleanupTempData`, `usp_RebuildIndexes`

**Defects fixed:**
- EOD step 4 notification email was never wired up — now connected via SMTP in the Order Service job
- Non-idempotent batch replaced by idempotent step functions with checkpoint tables
- `Admin/EndOfDay.aspx` authentication gap retired with the page (page is no longer needed)
- SQL Server DB Mail dependency eliminated; all notifications use SMTP

**Prerequisite phases:** Features 1–6 all live and passing health checks

## User Stories

| ID | Title |
|---|---|
| [US-701](us-701-adr-008-batch-retirement.md) | ADR-008: Batch retirement architecture decision |
| [US-702](us-702-billing-auto-billing-job.md) | Billing Service: nightly auto-billing job |
| [US-703](us-703-billing-overdue-invoices-job.md) | Billing Service: nightly overdue invoice marking job |
| [US-704](us-704-dispatch-driver-recovery-job.md) | Dispatch Service: nightly driver reset and recovery job |
| [US-705](us-705-order-stale-pending-notifications.md) | Order Service: nightly stale Pending order notification job |
| [US-706](us-706-ops-email-summary.md) | Ops summary email: event-driven replacement for DB Mail |
| [US-707](us-707-database-maintenance-jobs.md) | Database maintenance: PostgreSQL pg_cron replacement for SQL Server index rebuild |
| [US-708](us-708-disable-sql-agent-job.md) | Cutover: disable usp_ProcessEndOfDay SQL Agent job |
| [US-709](us-709-monolith-decommission-checklist.md) | Monolith decommission checklist |

## Exit Criterion

The `usp_ProcessEndOfDay` SQL Agent job is disabled; all five replacement scheduled tasks (US-702 through US-706) have run successfully for at least 7 consecutive nights; PostgreSQL maintenance jobs (US-707) are configured on all service databases; the monolith decommission checklist (US-709) is complete and signed off by the Operations team; zero calls to any of the 42 legacy stored procs appear in the SQL Server activity monitor for 30 consecutive days.
