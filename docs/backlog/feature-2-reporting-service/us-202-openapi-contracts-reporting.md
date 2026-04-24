# US-202: OpenAPI contracts for all 5 report endpoints

## User Story
As a Developer, I want OpenAPI contracts for all 5 report endpoints written before implementation so that consumers have machine-readable specs to code against.

## Description
Defining the API contract before writing implementation code ensures that the new Reporting Service endpoints are shaped by consumer needs rather than by what is convenient to query. Each endpoint must document its accepted query parameters with allowed values enumerated explicitly — this is the mechanism that eliminates the free-text `@GroupBy` and `@SortBy` injection vectors from the legacy procs. Response schemas must include all fields currently returned by the legacy stored procedures so that the Phase 0 characterization baselines can be validated against the contract. The spec file becomes the single source of truth for both the service implementation and the integration test suite.

## Acceptance Criteria
- [ ] Spec file created at `services/reporting/openapi.yaml`
- [ ] Endpoint `GET /reports/daily-shipments` documented with date-range query parameters (`from`, `to`)
- [ ] Endpoint `GET /reports/driver-performance` documented with date-range and optional driver-filter parameters
- [ ] Endpoint `GET /reports/revenue` documented with `groupBy` parameter whose allowed values are enumerated as `Day`, `Week`, `Month` only — no free-text values permitted
- [ ] Endpoint `GET /reports/top-customers` documented with `topN` integer parameter and activity type filter
- [ ] Endpoint `GET /reports/delayed-shipments` documented with threshold-hours and date-range parameters
- [ ] All sort and group column parameters specify an explicit enum of allowed values; no parameter accepts arbitrary string values that would be interpolated into SQL
- [ ] Response schemas for all 5 endpoints include every field returned by the corresponding legacy stored procedure (verified against Phase 0 characterization baseline column lists)
- [ ] Spec passes `spectral lint` with zero errors
- [ ] Spec is committed and linked from the feature ADR (ADR-003)
