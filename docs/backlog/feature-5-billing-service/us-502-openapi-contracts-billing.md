# US-502: OpenAPI Contracts for Billing Service

## User Story
As a Developer, I want OpenAPI contracts for all Billing Service endpoints written before implementation so that consumers have machine-readable schemas.

## Description
Writing the OpenAPI spec before any implementation forces the API shape — especially the idempotency key requirement on `POST /invoices` — to be visible to consumers before code is written. The Finance team's tooling and the Order Service's event-driven invoice creation both depend on the `POST /invoices` contract, so the spec must be precise about the `idempotencyKey` field being required and about the 200-vs-201 response codes for duplicate-vs-new invoice creation. The spec must also define the `GET /customers/{id}/statement` endpoint clearly enough for the Finance team to verify it matches their month-end reporting requirements.

## Acceptance Criteria
- [ ] Spec file created at `services/billing/openapi.yaml`
- [ ] Endpoint `POST /invoices` defined with `idempotencyKey` as a required field in the request body; response is 201 for a new invoice and 200 for a duplicate key
- [ ] Endpoint `GET /invoices/{id}` defined with full invoice response schema including line items and payment history
- [ ] Endpoint `PUT /invoices/{id}` (update status) defined with allowed status values enumerated
- [ ] Endpoint `POST /invoices/{id}/payments` defined with `referenceNumber` as a required field; 409 response defined for duplicate reference
- [ ] Endpoint `POST /invoices/{id}/discount` defined with discount amount and reason fields
- [ ] Endpoint `GET /invoices` (outstanding list) defined with filter parameters for customer, date range, and status
- [ ] Endpoint `GET /customers/{id}/statement` defined with `month` and `year` parameters and a response schema covering all invoice and payment rows for the period
- [ ] Spec passes `spectral lint` with no errors
