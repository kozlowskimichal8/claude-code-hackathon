# US-402: OpenAPI Contracts for Order Service

## User Story
As a Developer, I want OpenAPI contracts for all Order Service endpoints written before implementation so that consumers have machine-readable schemas before code is written.

## Description
Writing the OpenAPI spec before any implementation forces the API shape to be agreed by consumers (Billing, Dispatch, the legacy WebForms UI) before code is written, and prevents the spec from drifting to match the implementation rather than the contract. The spec must close the SQL injection vulnerability in `usp_SearchOrders` by documenting `sortBy` as an enum of allowed column names rather than a free-text parameter. The `OrderDetail` response schema must abstract the `usp_GetOrder` 3-result-set shape so that no consumer needs to depend on result-set ordinal positions.

## Acceptance Criteria
- [ ] Spec file created at `services/order/openapi.yaml`
- [ ] Endpoint `POST /orders` defined with request body including all required fields and `customerId` reference
- [ ] Endpoint `GET /orders/{id}` defined with `OrderDetail` response schema containing order header, list of `OrderItem`, and shipment summary
- [ ] Endpoint `GET /orders` (search) defined with query parameters including `sortBy` documented as an enum of allowed column names (not a free-text string)
- [ ] Endpoint `POST /orders/{id}/status` (transition) defined with valid transition values enumerated in the request body
- [ ] Endpoint `DELETE /orders/{id}` (cancel) defined with appropriate response codes
- [ ] Endpoint `GET /orders?customerId=&page=&pageSize=` defined with pagination parameters
- [ ] Endpoint `GET /orders/pending` defined
- [ ] `OrderDetail` DTO is defined as a named schema component (not inline) and abstracts the 3-result-set shape
- [ ] Spec passes `spectral lint` with no errors
