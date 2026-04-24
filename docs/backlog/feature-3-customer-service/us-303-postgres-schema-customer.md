# US-303: Migrate `Customers` table to PostgreSQL without `CurrentBalance`

## User Story
As a Developer, I want the `Customers` table migrated to PostgreSQL without the `CurrentBalance` denormalized field so that the Customer Service owns clean customer master data.

## Description
The legacy `Customers` table carries `CurrentBalance` as a denormalized cache column maintained by the `TR_Invoices_UpdateBalance` trigger. Migrating the table to PostgreSQL is the opportunity to remove this coupling: the new schema contains all genuine customer master data attributes but excludes `CurrentBalance`, which will be owned by the future Billing Service. The `CustomerType` column, currently stored as a single-character code (`R`, `P`, `C`, `G`), is stored as a PostgreSQL enum type in the new schema for type safety and readability. The migration must be idempotent and must include a data migration script that can be run against a production SQL Server export without data loss.

## Acceptance Criteria
- [ ] Database migration files created at `services/customer/db/migrations/` following a sequential naming convention
- [ ] Migration schema includes all `Customers` table fields from the legacy system except `CurrentBalance`
- [ ] `CustomerType` is stored as a PostgreSQL enum type with values `Regular`, `Premium`, `Contract`, `Government`
- [ ] All relevant indexes from the legacy schema are reproduced (or intentionally replaced with better alternatives, documented in a comment)
- [ ] Migration is idempotent: running it twice against the same database produces no errors and no duplicate data
- [ ] A data migration script at `services/customer/db/migrate-from-sqlserver.sql` (or equivalent) exports customer rows from SQL Server (excluding `CurrentBalance`), transforms type codes to enum labels, and imports into PostgreSQL
- [ ] After running the data migration script against a copy of the production dataset, the PostgreSQL row count matches the SQL Server source row count exactly
- [ ] Migration and data migration script both run successfully in CI against the Docker Compose database container
- [ ] Migration is reviewed and approved before any application code that depends on the new schema is merged
