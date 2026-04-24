# US-406: Pricing Service Integration

## User Story
As a Developer, I want `POST /orders` to call the Pricing Service for cost calculation inside the create transaction so that `TotalCost` is always set when an order is created successfully (fixing the NULL TotalCost bug).

## Description
In the legacy `usp_CreateOrder`, the cost calculation is performed outside the main transaction, leaving a window in which an order row exists with a NULL `TotalCost` if the proc is interrupted. The new service must call the Pricing Service synchronously and include the returned cost in the same database transaction as the order insert, so that a NULL `TotalCost` after a successful `POST /orders` is structurally impossible. If the Pricing Service is unavailable or returns an error, the order must not be created — the caller receives a 502 Bad Gateway with a clear error message and no partial row is written.

## Acceptance Criteria
- [ ] `POST /orders` calls the Pricing Service synchronously before committing the order row
- [ ] The `TotalCost` returned by the Pricing Service is written in the same database transaction as the order insert
- [ ] If the Pricing Service returns any non-success HTTP response, `POST /orders` returns 502 Bad Gateway and no order row is written to the database
- [ ] `TotalCost` is never NULL after a successful `POST /orders` (verified by integration test querying the database directly)
- [ ] Pricing Service call timeout is set to 2 seconds; a timeout causes order creation to fail with 502 and no partial record is written
- [ ] Phase 0 characterization test for NULL `TotalCost` (constraint 4) is updated to assert the absence of that behaviour in the new service, with a comment explaining it was a known defect now fixed
- [ ] Pricing results match Phase 0 characterization baseline for the same input parameters (customer type, weight, distance, service level)
