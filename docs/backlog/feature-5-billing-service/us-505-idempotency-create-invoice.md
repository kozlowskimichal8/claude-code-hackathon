# US-505: Idempotent Invoice Creation

## User Story
As a Developer, I want `POST /invoices` to enforce idempotency via a required idempotency key so that calling the endpoint twice with the same key creates exactly one invoice.

## Description
The legacy `usp_CreateInvoice` stored procedure is non-idempotent: calling it twice with the same order creates two invoice rows. This is a known defect (pinned in Phase 0 characterization tests) that has caused Finance team reconciliation work when `usp_CompleteShipment` is called more than once. The new service must treat the idempotency key as a primary uniqueness mechanism enforced at the database level — application-level checks alone are insufficient because concurrent requests can both pass an existence check before either has committed. The idempotency window must be at least 24 hours to cover retry scenarios from overnight batch processes.

## Acceptance Criteria
- [ ] `POST /invoices` requires either an `Idempotency-Key` request header or an `idempotencyKey` field in the request body
- [ ] A second `POST /invoices` call with the same idempotency key returns HTTP 200 with the existing invoice body (not 201, not an error)
- [ ] The unique constraint on `IdempotencyKey` in the PostgreSQL `Invoices` table prevents race-condition duplicates when two concurrent requests arrive with the same key
- [ ] Idempotency window is at least 24 hours: a key used 24 hours ago still returns the existing invoice on a repeat call
- [ ] `POST /invoices` without an idempotency key returns 400 Bad Request with a clear error message
- [ ] Phase 0 characterization test for duplicate invoice creation (constraint 6) is updated to assert the new idempotent behaviour in the Billing Service, with a comment marking the legacy defect as fixed
- [ ] Legacy `usp_CreateInvoice` non-idempotency is documented as a known defect now fixed, with a reference to the Phase 0 test that previously pinned it
