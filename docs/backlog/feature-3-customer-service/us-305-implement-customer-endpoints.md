# US-305: Implement Customer Service endpoints with parameterized queries and sort-column whitelist

## User Story
As a Developer, I want all Customer Service endpoints implemented with parameterized queries and a sort-column whitelist so that the SQL injection bug in the legacy `usp_SearchCustomers` is eliminated.

## Description
The legacy `usp_SearchCustomers` procedure accepts a `@SortBy` parameter that is concatenated directly into a dynamic SQL string without validation, creating a SQL injection vulnerability (NWL-389). The new `GET /customers` endpoint eliminates this by validating the `sortBy` query parameter against a compile-time whitelist before any query is constructed. The `GET /customers/{id}/orders` endpoint replaces the cursor-based N+1 pattern in `usp_GetCustomerOrders` with a single JOIN query, improving performance at scale. All endpoints use typed DTOs derived from the OpenAPI contract rather than `SELECT *`, ensuring that `CurrentBalance` cannot inadvertently appear in a response even if the underlying table schema changes.

## Acceptance Criteria
- [ ] `GET /customers` accepts `sortBy` query parameter; allowed values are defined in a whitelist constant and documented in the OpenAPI spec; any non-whitelisted value returns HTTP 400 with an error body listing the allowed values
- [ ] `GET /customers` search filters (`name`, `type`, `active`) all use parameterized query variables, not string interpolation
- [ ] `GET /customers/{id}` returns a typed DTO; no `SELECT *` queries exist in the Customer Service codebase
- [ ] `POST /customers` validates all required fields and returns HTTP 400 with field-level error detail for any missing or invalid required field
- [ ] `POST /customers` with an invalid `customerType` value returns HTTP 400 (no silent default to `Regular`)
- [ ] `GET /customers/{id}/orders` uses a single JOIN query to retrieve all orders for a customer; no cursor or loop-based N+1 pattern exists in the endpoint handler
- [ ] `GET /customers/{id}/orders` returns paginated results; `page` and `pageSize` parameters are validated (positive integers, `pageSize` capped at a configurable maximum)
- [ ] No `CurrentBalance` field appears in any endpoint response, confirmed by a test that inspects the raw serialized JSON
- [ ] All endpoints return HTTP 404 for requests against non-existent customer IDs with a consistent error response format
