# US-403: PostgreSQL Schema and FK Restoration

## User Story
As a Developer, I want the Orders and OrderItems tables migrated to PostgreSQL with the FK between them restored so that data integrity is enforced at the database level.

## Description
The FK between `OrderItems.OrderId` and `Orders.Id` was removed in 2015 (believed to be a performance workaround) and has never been restored, leaving orphaned `OrderItems` rows possible in the legacy system. Restoring it in PostgreSQL enforces the integrity that the legacy SQL Server schema lacks. The `Status` column should be stored as a PostgreSQL enum rather than a varchar, making invalid status values impossible at the database level. All migrations must be idempotent so they can be run safely in CI and re-run in staging without side effects.

## Acceptance Criteria
- [ ] Migration scripts created under `services/order/db/migrations/` following a numbered naming convention
- [ ] `Orders` table created with all fields from the legacy schema, with `Status` stored as a PostgreSQL enum type
- [ ] `OrderItems` table created with a `FOREIGN KEY (OrderId) REFERENCES Orders(Id)` constraint that is enforced (not deferred)
- [ ] FK constraint verified by attempting to insert an `OrderItem` with a non-existent `OrderId` and confirming rejection
- [ ] All migration scripts are idempotent (re-running produces no error and no duplicate objects)
- [ ] Data migration script exports all non-archived orders and their items from SQL Server
- [ ] Data migration script imports to PostgreSQL and verifies row counts match between source and destination
- [ ] Migrated data contains no orphaned `OrderItems` rows (FK integrity validated after import)
