# US-508: Integration Tests for Billing Service

## User Story
As a QA Engineer, I want integration tests covering idempotency, balance accuracy, and statement generation so that the Billing Service is a verifiable replacement for the legacy billing stored procedures.

## Description
Integration tests must cover every code path that Phase 0 characterization tests pin against the legacy billing stored procedures, so that the new service can be proven behaviourally equivalent (or demonstrably better, where defects are fixed) before cut-over. Tests for idempotent invoice creation and duplicate payment rejection must run against a real PostgreSQL instance with the unique constraints in place to confirm database-level enforcement. The event-driven invoice creation path must be tested end-to-end with a real message broker (not a mock), so that the full consumer-to-database path is exercised in CI.

## Acceptance Criteria
- [ ] Test: `POST /invoices` with a new idempotency key returns 201 and creates one invoice row
- [ ] Test: `POST /invoices` with the same idempotency key returns 200 with the existing invoice; exactly one row exists in the database
- [ ] Test: concurrent `POST /invoices` calls with the same idempotency key (simulated with parallel requests) result in exactly one invoice row (database unique constraint enforced)
- [ ] Test: `POST /invoices/{id}/payments` with a new reference number returns 201
- [ ] Test: `POST /invoices/{id}/payments` with a duplicate reference number returns 409 with the existing payment id in the response
- [ ] Test: balance after creating one invoice and one full payment equals zero
- [ ] Test: balance after creating two invoices and one partial payment reflects the correct running total (within 1 cent)
- [ ] Test: discount application reduces the balance by the discount amount
- [ ] Test: `GET /invoices` with `status=outstanding` returns only unpaid invoices
- [ ] Test: `GET /customers/{id}/statement` for a given month returns correct invoice and payment rows and summary totals
- [ ] End-to-end test: publish `OrderStatusChanged(Delivered)` to the real message broker and verify invoice is created in PostgreSQL within 5 seconds
- [ ] All Phase 0 billing characterization tests updated to reflect idempotent behaviour and passing in CI
