# US-302: OpenAPI contract for all Customer Service endpoints

## User Story
As a Developer, I want an OpenAPI contract for all Customer Service endpoints written before implementation so that consumers have a machine-readable schema.

## Description
The OpenAPI contract for the Customer Service is the authoritative definition of the new domain boundary. Its most important constraint is what it must not contain: the `CurrentBalance` field must be absent from every response schema, making the boundary explicit and machine-verifiable. The contract must also enumerate the `customerType` values as a formal enum rather than accepting free-text strings, eliminating the silent Government-to-Regular fallback at the API level. The search endpoint must define sort parameters with an explicit allowlist, directly replacing the unvalidated `@SortBy` parameter that enables SQL injection in the legacy proc. Writing the contract before implementation ensures the service is shaped by these requirements rather than by what is easiest to implement.

## Acceptance Criteria
- [ ] Spec file created at `services/customer/openapi.yaml`
- [ ] Endpoint `GET /customers/{id}` documented with a response schema that includes all customer fields except `CurrentBalance`
- [ ] Endpoint `POST /customers` documented with a request schema covering all required and optional fields; `CurrentBalance` absent from both request and response
- [ ] Endpoint `PUT /customers/{id}` documented supporting sparse updates; `CurrentBalance` absent
- [ ] Endpoint `GET /customers` (search) documented with `name`, `type`, and `active` filter parameters and a `sortBy` parameter whose allowed values are enumerated (e.g. `Name`, `CreatedAt`, `Type`) — no free-text sort values
- [ ] Endpoint `GET /customers/{id}/orders` documented as a paginated list with `page` and `pageSize` parameters
- [ ] `customerType` field documented as an enum with values `Regular`, `Premium`, `Contract`, `Government` in all schemas where it appears
- [ ] `CurrentBalance` does not appear anywhere in the spec file
- [ ] Spec passes `spectral lint` with zero errors
- [ ] Spec is committed and referenced from ADR-004
