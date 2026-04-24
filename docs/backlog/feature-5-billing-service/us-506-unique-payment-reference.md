# US-506: Unique Payment Reference Constraint

## User Story
As a Developer, I want a unique constraint on payment `ReferenceNumber` so that the "we trust accounting" pattern of accepted duplicate payments is replaced by explicit rejection.

## Description
The legacy `usp_ProcessPayment` procedure accepts duplicate payments with the same reference number, relying on the Finance team to detect and reverse duplicates during reconciliation. This is a manual, error-prone process. The new service must reject duplicate payment references at the API level (409 Conflict) and at the database level (unique constraint), replacing the trust-based approach with a structural guarantee. The Finance team must be notified of this behaviour change before cut-over, as it will affect their tooling for re-submitting failed payment files.

## Acceptance Criteria
- [ ] `POST /invoices/{id}/payments` with a `referenceNumber` that already exists in the `Payments` table returns HTTP 409 Conflict
- [ ] A unique constraint on `ReferenceNumber` in the PostgreSQL `Payments` table is in place and enforced at the database level
- [ ] The 409 response body includes the `id` of the existing payment record that holds the duplicate reference number
- [ ] The 409 response body includes a human-readable message explaining that a payment with this reference number already exists
- [ ] Finance team has been notified of the behaviour change from silent acceptance to 409 rejection, and the notification is recorded (e.g. as a comment in the ADR or a linked issue)
- [ ] Phase 0 characterization test for duplicate payment acceptance is updated to assert the 409 response (new behaviour), with a comment documenting that the legacy silent acceptance is now replaced by explicit rejection
- [ ] Integration test covers: first payment with a reference number succeeds (201), second payment with the same reference number returns 409 with the existing payment id in the response
