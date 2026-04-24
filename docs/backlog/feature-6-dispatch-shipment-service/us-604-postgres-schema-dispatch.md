# US-604: PostgreSQL schema migration for Drivers, Vehicles, and Shipments

## User Story

As a Developer, I want the Drivers, Vehicles, and Shipments tables migrated to PostgreSQL so that the Dispatch/Shipment Service owns its data independently.

## Description

The Dispatch/Shipment Service requires its own PostgreSQL database with schema and seed data migrated from the legacy SQL Server instance. The migration must be idempotent so it can be re-run safely, and must carry the current production driver roster, vehicle fleet, and all active shipments. Foreign keys to the Orders domain reference Orders by ID only — the legacy SQL Server row structure must not leak into the new schema, consistent with the anti-corruption layer requirement in ADR-001.

## Acceptance Criteria

- [ ] Migration scripts committed under `services/dispatch/db/migrations/` following a numeric naming convention
- [ ] `Drivers` table includes a `LicenceExpiry` date column (not nullable)
- [ ] `Drivers` table includes a `Status` column implemented as a PostgreSQL enum with values: `Available`, `OnRoute`, `OffDuty`, `Terminated`, `LOA`
- [ ] `Vehicles` table includes a `Status` column implemented as a PostgreSQL enum
- [ ] `Shipments` table includes a foreign key to the Orders domain represented as an `OrderId` UUID or integer (matching the Order Service's primary key) — no SQL Server-specific column names or types leak through
- [ ] Migration scripts are idempotent: running the migration twice against the same database produces no errors and no data duplication
- [ ] A data migration script exports the current driver roster and vehicle fleet from the legacy SQL Server instance and imports them into PostgreSQL
- [ ] A data migration script exports all active (non-terminal) shipments from the legacy SQL Server instance and imports them into PostgreSQL
- [ ] Row counts for `Drivers`, `Vehicles`, and active `Shipments` are verified and logged after migration
- [ ] Migration can be executed in a local development environment using `docker compose up`
