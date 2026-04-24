# US-503: PostgreSQL Schema for Billing

## User Story
As a Developer, I want the Invoices, Payments, and CustomerBalance tables migrated to PostgreSQL so that the Billing Service owns its data independently of SQL Server.

## Description
The Billing Service must own its data in PostgreSQL to be independent of the legacy SQL Server schema. The `Invoices` table needs an `IdempotencyKey` column with a unique constraint to enforce idempotent creation at the database level, preventing race-condition duplicates that application-level checks alone cannot prevent. The `Payments` table needs a unique constraint on `ReferenceNumber` to replace the legacy "we trust accounting" pattern. The `CustomerBalance` projection table is a new addition that stores the incrementally-maintained balance per customer, replacing the denormalized `CurrentBalance` field in the legacy `Customers` table.

## Acceptance Criteria
- [ ] Migration scripts created under `services/billing/db/migrations/` following a numbered naming convention
- [ ] `Invoices` table includes an `IdempotencyKey` column with a unique constraint enforced at the database level
- [ ] `Payments` table includes a unique constraint on `ReferenceNumber` enforced at the database level
- [ ] `CustomerBalance` projection table created with columns: `CustomerId` (PK), `Balance` (decimal, not null), `LastUpdatedAt` (UTC timestamp), `Version` (for optimistic concurrency)
- [ ] All migration scripts are idempotent (re-running produces no error and no duplicate objects)
- [ ] Data migration script exports all existing invoices and payments from SQL Server
- [ ] Data migration script imports to PostgreSQL and verifies that total invoice amounts and total payment amounts match between source and destination
- [ ] `CustomerBalance` projection is populated from the imported invoice and payment data after migration, not pre-populated with the legacy `CurrentBalance` value
