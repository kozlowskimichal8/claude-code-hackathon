# US-410: Integration Tests for Order Service

## User Story
As a QA Engineer, I want integration tests covering the full order lifecycle, credit-limit logic, and pricing parity so that the Order Service is verifiably equivalent to the legacy stored procedures.

## Description
Integration tests must cover every code path that Phase 0 characterization tests pin against the legacy system, so that the new service can be proven behaviourally equivalent before cut-over. Tests must run against a real PostgreSQL instance and a real (or stubbed) message broker so that event emission is verified end-to-end. Pricing parity tests must use the same inputs as the Phase 0 baseline and assert that the new service returns identical results, to confirm that the Pricing Service integration does not change the calculated costs.

## Acceptance Criteria
- [ ] Test: `POST /orders` with valid data succeeds and returns the created order with a non-NULL `TotalCost`
- [ ] Test: `POST /orders` for a Regular customer whose balance would exceed credit limit returns 422
- [ ] Test: `POST /orders` when the Pricing Service returns an error returns 502 and no order row exists in the database
- [ ] Tests for all valid status transitions: `Pending→Assigned`, `Assigned→PickedUp`, `PickedUp→InTransit`, `InTransit→Delivered`, `InTransit→Failed`, `Pending→Cancelled`, `any→OnHold`
- [ ] Test: attempting an invalid status transition returns 422 with a descriptive error
- [ ] Test: `DELETE /orders/{id}` for a `Pending` order succeeds and order status is `Cancelled`
- [ ] Test: `GET /orders` with `sortBy` filter returns results sorted correctly; `sortBy` with a value not in the allowed enum returns 400
- [ ] Test: `GET /orders?customerId=&page=&pageSize=` returns paginated results with correct total count
- [ ] Test: `GET /orders/pending` returns only orders with status `Pending`
- [ ] Test: `SpecialInstructions` append behaviour is asserted across at least two sequential transitions
- [ ] Pricing results for the same inputs as Phase 0 characterization baseline match exactly
- [ ] Credit-limit tests match Phase 0 characterization baseline for Regular, Premium, Contract, and Government customers
- [ ] All Phase 0 order characterization tests still passing unchanged in the same CI run
