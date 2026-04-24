# US-608: Per-request active dispatch board (replace ##global temp table)

## User Story

As a Developer, I want the active dispatch board (`GET /shipments/active`) to use a per-request query instead of a `##global` temp table so that concurrent dispatchers never see corrupted or colliding results.

## Description

The legacy `usp_GetActiveShipments` uses a `##global` temporary table, which is shared across all SQL Server sessions. Under concurrent load from multiple dispatcher clients, sessions write over each other's temp table contents, producing corrupted or mixed result sets. The new `GET /shipments/active` endpoint replaces the proc entirely with a direct parameterised query scoped to the request, eliminating the concurrency hazard. A load test is the acceptance gate: ten simultaneous clients must each receive a correct, distinct result.

## Acceptance Criteria

- [ ] `GET /shipments/active` returns the correct set of active shipments when called by 10 concurrent clients simultaneously
- [ ] No `##` global temporary table (or any session-shared temporary structure) exists anywhere in the Dispatch Service codebase
- [ ] A load test of 10 concurrent requests sustained for 30 seconds produces zero HTTP errors and zero result set collisions (where "collision" means one client's result contains shipments that belong to another client's session context)
- [ ] Response time for `GET /shipments/active` is under 500ms for a dataset of up to 50 active shipments
- [ ] The Phase 0 characterization test that documents the `##global` temp table collision bug is updated to assert that the bug is no longer reproducible in the new service
- [ ] The fix is covered by an integration test that calls `GET /shipments/active` from two concurrent test clients and verifies result integrity
