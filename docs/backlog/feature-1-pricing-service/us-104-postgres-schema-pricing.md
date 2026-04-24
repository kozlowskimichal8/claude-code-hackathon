# US-104: PostgreSQL Schema and Seed Migration

## User Story
As a Developer, I want the `PricingRules` table migrated from SQL Server seed data to PostgreSQL so that the Pricing Service owns its data and is no longer coupled to the legacy SQL Server instance.

## Description
The Pricing Service must own the `PricingRules` data in PostgreSQL to sever the read dependency on the legacy SQL Server `PricingRules` table. The migration must preserve all 15 seed rows exactly as they appear in the legacy `01_seed_data.sql` script and must run automatically on service startup so the service is self-contained in the Docker Compose environment. The migration tooling (EF Core migrations or Flyway) must be chosen consistently with the ADR-002 decision.

## Acceptance Criteria
- [ ] Migration script(s) are located at `services/pricing/db/migrations/`
- [ ] Schema reproduces the legacy `PricingRules` structure: `CustomerType`, `MinWeight`, `MaxWeight`, `BaseRate`, `PerMileRate` columns with compatible data types
- [ ] All 15 seed rows from the legacy `01_seed_data.sql` script are present in the PostgreSQL table after migration
- [ ] Migration is idempotent: running it twice does not produce errors or duplicate rows
- [ ] Migration runs automatically when the service starts, before the first request is served
- [ ] A PostgreSQL instance is added to `docker-compose.yml` and linked to the Pricing Service container
- [ ] The Pricing Service connects to PostgreSQL and not to SQL Server at runtime
