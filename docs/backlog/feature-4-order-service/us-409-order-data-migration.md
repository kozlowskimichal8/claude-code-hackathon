# US-409: Order Data Migration Runbook

## User Story
As a Platform Engineer, I want a data migration runbook for syncing active orders from SQL Server to PostgreSQL during the cut-over window so that no in-flight orders are lost.

## Description
The migration window is the highest-risk period of the cut-over: orders that are `Pending`, `Assigned`, or `InTransit` in SQL Server must be present in PostgreSQL before the new service goes live, and any orders created or updated during the migration window must not be lost. The runbook must document the chosen strategy (freeze window or dual-write), the exact export and import steps, and the verification procedure. Because the FK between `OrderItems` and `Orders` is being restored, the import must also validate that no orphaned `OrderItems` rows exist in the source data before importing, and must document the remediation if any are found.

## Acceptance Criteria
- [ ] Runbook created at `services/order/docs/migration-runbook.md`
- [ ] Runbook documents the chosen cut-over strategy: either a freeze window (stop writes to Orders in SQL Server for the migration duration) or a dual-write approach, with the rationale for the choice
- [ ] Runbook includes step-by-step export procedure for all non-archived orders (`Status` not in `Delivered`, `Failed`, `Cancelled`) and all their `OrderItems` from SQL Server
- [ ] Runbook includes step-by-step import procedure for PostgreSQL, including the order in which tables are loaded to satisfy FK constraints
- [ ] Runbook includes a row-count verification step comparing source and destination counts for both `Orders` and `OrderItems`
- [ ] Runbook documents the rollback procedure: how to re-enable SQL Server as the source of truth if the migration fails mid-way
- [ ] Runbook includes a pre-import check for orphaned `OrderItems` rows in the source data, and a documented remediation step if orphans are found
- [ ] Migration script is idempotent: re-running it against an already-migrated PostgreSQL database produces no duplicate rows and no errors
- [ ] Migrated data is validated against a production-sized snapshot in a staging environment before the production cut-over is approved
