# US-307: Data migration strategy and runbook for SQL Server to PostgreSQL

## User Story
As a Platform Engineer, I want a data migration strategy and runbook for moving existing customer records from SQL Server to PostgreSQL so that the cut-over does not lose any customer data.

## Description
Moving customer master data from SQL Server to PostgreSQL is a one-time, high-stakes operation that must be prepared and rehearsed before the cut-over window. The migration must exclude `CurrentBalance` (a Billing concern), transform the single-character type codes to enum labels, and validate that the row count in the destination matches the source exactly before the legacy system is switched off. Because customer data changes continuously during business hours, the runbook must account for records created or updated between the initial bulk migration and the cut-over moment. A dry-run mode is mandatory so that operations can validate the migration logic against a production data snapshot without risk. The runbook must also document the rollback procedure in case the migration reveals data quality issues that were not anticipated.

## Acceptance Criteria
- [ ] Migration runbook committed to `services/customer/docs/migration-runbook.md`
- [ ] Runbook covers: pre-migration checks (source row count, data quality scan), export from SQL Server (excluding `CurrentBalance`), type code to enum transformation, import to PostgreSQL, post-migration row-count verification, rollback procedure
- [ ] Migration script is idempotent: running it a second time against the same target database produces no errors, no duplicates, and the same final row count as the first run
- [ ] Migration script has a `--dry-run` flag (or equivalent) that logs every record that would be migrated and every transformation that would be applied without writing to the database
- [ ] Migration verified against a production-sized data snapshot in the staging environment: row count matches source, all type code transformations produce valid enum values, no null constraint violations
- [ ] Runbook documents how to handle records created in SQL Server between the bulk migration and the cut-over moment (delta migration strategy)
- [ ] Runbook includes a rollback procedure: steps to re-enable the legacy procs, verify they are receiving traffic, and document the point at which the failed migration attempt should be investigated
- [ ] Estimated migration duration for the production dataset is recorded in the runbook based on the staging environment test run
