# US-205: Implement all 5 report endpoints with parameterized queries and column whitelists

## User Story
As a Developer, I want all 5 report endpoints implemented with parameterized queries and column whitelists so that the SQL injection and race-condition bugs present in the legacy procs are not carried forward.

## Description
The five legacy reporting stored procedures contain two categories of defect that must not be replicated: dynamic SQL string concatenation with unvalidated `@GroupBy` / `@SortBy` parameters, and the `##global` temp table pattern that causes collisions under concurrent execution. Each new endpoint must validate all grouping and sorting inputs against a compile-time whitelist before they touch any query, and must express intermediate aggregations as per-request CTEs rather than session-global state. The response shapes must match the Phase 0 characterization baselines exactly so that the integration test suite can confirm correctness without re-specifying expected values.

## Acceptance Criteria
- [ ] All 5 endpoints return data matching the Phase 0 characterization test column shapes (column names, data types, and nullable flags)
- [ ] `GET /reports/revenue` accepts `groupBy` query parameter with whitelisted values `Day`, `Week`, `Month` only; any other value returns HTTP 400 with a descriptive error body
- [ ] `GET /reports/driver-performance` accepts `sortBy` query parameter with whitelisted values only; any non-whitelisted value returns HTTP 400
- [ ] No dynamic SQL string concatenation exists anywhere in the Reporting Service codebase (verified by static analysis or code review checklist)
- [ ] All query parameters that affect SQL structure (groupBy, sortBy) are validated against a whitelist constant before being used; the whitelist is defined in one place and referenced by both the validation logic and the query builder
- [ ] `GET /reports/daily-shipments` uses a per-request CTE for intermediate aggregation; no `##` global temp table syntax appears anywhere in the service
- [ ] All date range parameters are validated (from <= to, no future end dates where business rules require it); invalid ranges return HTTP 400
- [ ] Each endpoint includes structured logging of query execution time for performance monitoring
