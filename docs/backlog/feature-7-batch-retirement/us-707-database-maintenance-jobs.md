# US-707: Database maintenance: PostgreSQL pg_cron replacement for SQL Server index rebuild

## User Story

As a Platform Engineer, I want index rebuild and statistics update moved to PostgreSQL maintenance windows on each service so that the SQL Server FULLSCAN operations in EOD step 6 are replaced by database-native maintenance.

## Description

EOD batch step 6 rebuilds SQL Server indexes with `FULLSCAN` statistics updates and uses an `ONLINE` rebuild for all tables except `OrderItems` (which was excluded because it caused blocking in the legacy system). The replacement uses PostgreSQL-native maintenance: `VACUUM ANALYZE` for statistics and `REINDEX` for index rebuild, scheduled via `pg_cron` on each service's PostgreSQL database. The `OrderItems` exclusion does not apply in PostgreSQL — all tables are included. Maintenance windows are aligned with the legacy Sunday 02:00 schedule to minimise operational disruption.

## Acceptance Criteria

- [ ] Each PostgreSQL service database (Billing, Dispatch, Order, Pricing, Reporting, Customer) has `pg_cron` or an equivalent scheduled maintenance mechanism configured
- [ ] Each service database runs `VACUUM ANALYZE` on its tables on a regular schedule (at minimum weekly)
- [ ] Each service database runs `REINDEX` on its indexes on a regular schedule (at minimum weekly)
- [ ] Maintenance windows are set to Sunday 02:00 local time, matching the legacy SQL Server maintenance schedule
- [ ] The `OrderItems` table equivalent in the Order Service database (previously excluded from SQL Server `ONLINE` rebuild) is included in the PostgreSQL maintenance schedule with no exclusion
- [ ] The maintenance schedule for each service is documented in `services/{service-name}/db/maintenance.md`
- [ ] `usp_RebuildIndexes` is marked as deprecated in the legacy codebase with a comment indicating it is replaced by PostgreSQL pg_cron jobs
- [ ] An integration check verifies that `pg_cron` jobs are scheduled and visible in `cron.job` on each service database after deployment
