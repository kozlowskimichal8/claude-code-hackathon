# US-507: CurrentBalance as Event-Sourced Projection

## User Story
As a Developer, I want `CurrentBalance` maintained incrementally from invoice and payment events so that it is accurate in real time and is no longer a full-table recalculation on every invoice change.

## Description
The legacy `TR_Invoices_UpdateBalance` trigger recalculates `CurrentBalance` in the `Customers` table by summing all invoice amounts and subtracting all payments from scratch on every invoice insert or update. This is an O(n) operation per billing event and causes table-level contention under concurrent load. The new `CustomerBalance` projection table in the Billing Service is updated incrementally: invoice creation adds the invoice amount, payment recording subtracts the payment amount, and discount application subtracts the discount amount. A reconciliation endpoint or script must be able to verify the projection against a full recalculation from raw data to detect and alert on drift.

## Acceptance Criteria
- [ ] `CustomerBalance` projection table is updated atomically with each billing operation in the same database transaction
- [ ] Invoice creation adds the invoice amount to the customer's `CustomerBalance` record in the same transaction
- [ ] Payment recording subtracts the payment amount from the customer's `CustomerBalance` record in the same transaction
- [ ] Discount application subtracts the discount amount from the customer's `CustomerBalance` record in the same transaction
- [ ] `GET /customers/{id}/balance` endpoint (or equivalent Customer Service call) returns the projection value from `CustomerBalance`, not a live recalculation
- [ ] A reconciliation script or endpoint compares the `CustomerBalance` projection against a full recalculation from the raw `Invoices` and `Payments` tables and reports any discrepancy
- [ ] Balance accuracy is within 1 cent of a full recalculation for all customers in the test dataset
- [ ] No full-table scan over `Invoices` or `Payments` is triggered by any billing operation (verified by reviewing query plans in tests)
- [ ] Phase 0 characterization test for `CurrentBalance` staleness (constraint 7) is updated to assert that balance is now always current, with a comment marking the legacy recalculation behaviour as retired
