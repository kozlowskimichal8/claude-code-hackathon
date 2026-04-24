# US-609: Fix shipment creation nested-transaction bug with savepoints

## User Story

As a Developer, I want the shipment creation endpoint to use savepoints so that a rollback within shipment creation does not roll back the outer order transaction.

## Description

The legacy `usp_CreateShipment` contains a nested transaction pattern that, on failure, issues a `ROLLBACK` that rolls back the entire transaction stack — including any enclosing order transaction the caller had open. This silently aborts order records when shipment creation fails. The new `POST /shipments` endpoint uses database savepoints instead of nested transactions, so a failure during shipment creation can release its savepoint and return an error to the caller without disturbing any outer transaction context.

## Acceptance Criteria

- [ ] `POST /shipments` wraps its database operations in a named savepoint rather than a nested `BEGIN TRANSACTION`
- [ ] A failure during shipment creation (e.g. constraint violation, simulated mid-insert error) causes the savepoint to be released and a `500` or appropriate error response to be returned, without affecting any outer transaction context held by the caller
- [ ] An integration test simulates a mid-creation failure scenario and asserts that the corresponding order record is untouched after the failure
- [ ] The nested-transaction rollback bug documented in the spec (where `usp_CreateShipment` could silently abort an outer order transaction) is no longer reproducible against the new service
- [ ] Unit tests cover the savepoint rollback path: mock a database failure mid-insert and assert the savepoint is released cleanly
- [ ] Unit tests cover the happy path: successful shipment creation commits the savepoint and returns `201` with the new shipment resource
