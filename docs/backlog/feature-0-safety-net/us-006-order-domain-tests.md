# US-006: Order Domain Tests

## User Story
As a QA Engineer, I want characterization tests covering the full Order status lifecycle so that every valid and invalid transition is pinned before any order logic is touched.

## Description
The Order domain is the hub of the monolith: it coordinates customer credit checks, pricing, driver assignment, and billing. The status state machine — `Pending → Assigned → PickedUp → InTransit → Delivered / Failed`, plus `Cancelled` and `OnHold` — is enforced by `usp_UpdateOrderStatus`. Tests must cover every documented valid transition, at least one invalid transition rejection, and the query procs that depend on status. Pagination behaviour in `usp_GetOrdersByCustomer` must also be pinned.

## Acceptance Criteria
- [ ] Valid transition `Pending → Assigned` is accepted by `usp_UpdateOrderStatus` and the new status is persisted
- [ ] Valid transition `Assigned → PickedUp` is accepted and persisted
- [ ] Valid transition `PickedUp → InTransit` is accepted and persisted
- [ ] Valid transition `InTransit → Delivered` is accepted and persisted
- [ ] Valid transition `InTransit → Failed` is accepted and persisted
- [ ] Valid transition `Pending → Cancelled` is accepted and persisted
- [ ] Valid transition from any active status to `OnHold` is accepted and persisted
- [ ] At least one invalid transition (e.g. `Delivered → Assigned`) is rejected by `usp_UpdateOrderStatus`; the exact error or return code is asserted
- [ ] `usp_GetPendingOrders` returns only orders with `Status = 'Pending'` that have no assigned driver; orders in other statuses are absent from the result
- [ ] `usp_GetOrdersByCustomer` returns results in pages; a request for page 2 of a customer with more than one page of orders returns the correct offset rows
- [ ] All tests are committed to the repository and passing in CI
