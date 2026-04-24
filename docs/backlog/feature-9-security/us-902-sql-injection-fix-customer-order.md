# US-902: SQL injection fix in Customer and Order search

## User Story

As a Security Engineer, I want SQL injection via `@SortBy` eliminated from Customer Service (Phase 3) and Order Service (Phase 4) search endpoints so that NWL-389 is closed by design in the new services.

## Description

The legacy `usp_SearchCustomers` and `usp_SearchOrders` stored procedures accept a `@SortBy` parameter and concatenate it directly into a dynamic SQL string with no whitelist validation, making them vulnerable to SQL injection (NWL-389). The new Customer Service and Order Service endpoints must not carry this defect forward. The fix is to accept `sortBy` as a string input, validate it against an explicit allowlist of permitted column names before constructing any query, and return a 400 response for any value not on the list. No dynamic SQL string concatenation is permitted anywhere in the Customer Service or Order Service codebases — this is verified by a Grep step in CI. A security test simulating an injection payload is part of the acceptance suite.

## Acceptance Criteria

- [ ] Customer Service `GET /customers` accepts a `sortBy` query parameter; Order Service `GET /orders` accepts a `sortBy` query parameter
- [ ] Both endpoints validate `sortBy` against an explicit allowlist of permitted column names before including the value in any query
- [ ] Any `sortBy` value not on the allowlist returns HTTP 400 with an error body of the form `"Invalid sort column: {value}. Allowed: {list}"`
- [ ] No dynamic SQL string concatenation exists anywhere in the Customer Service or Order Service codebases; this is verified by a Grep pattern check in CI that fails the build if a concatenated SQL string is detected
- [ ] A security test submits `sortBy=1;DROP TABLE Customers--` to both endpoints and asserts: HTTP 400 response; no change in the database (verified by querying the Customers table after the request)
- [ ] The fix for NWL-389 is documented in a changelog entry in both the Customer Service and Order Service, referencing the original defect identifier
