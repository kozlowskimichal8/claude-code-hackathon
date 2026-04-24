# US-904: Duplicate invoice prevention via idempotency key

## User Story

As a Security Engineer, I want the idempotency key on `POST /invoices` to prevent duplicate invoice creation so that the billing integrity defect NWL-389 (non-idempotent `usp_CreateInvoice`) is eliminated in the Billing Service.

## Description

The legacy `usp_CreateInvoice` stored procedure is not idempotent: calling it twice with the same inputs creates two invoices, and there is no detection or deduplication mechanism. This has caused billing errors in production that Finance corrects manually. The Billing Service must not carry this defect forward. This story tracks the idempotency requirement as a security and data-integrity concern; its functional delivery is owned by US-505 (Idempotency key on CreateInvoice) in Feature 5. This story exists so that the security team can independently verify that the fix meets the integrity bar, that the Phase 0 characterization test is updated, and that a penetration-style test confirms deduplication under rapid concurrent submissions.

## Acceptance Criteria

- [ ] US-505 (Idempotency key on CreateInvoice, Feature 5) is delivered and passes its own acceptance criteria
- [ ] The Phase 0 characterization test for the duplicate invoice defect (constraint 6) is updated to document the defect as fixed in the Billing Service and to assert the new idempotent behaviour
- [ ] A penetration test scenario submits the same invoice creation request body 5 times in rapid succession (within 500ms) and asserts: exactly 1 invoice record exists in the database after all 5 requests complete; the 2nd through 5th responses each return HTTP 200 (or 409, per the agreed contract) with the same invoice ID as the first response rather than creating new records
- [ ] The fix is documented in the Billing Service changelog referencing the original defect
