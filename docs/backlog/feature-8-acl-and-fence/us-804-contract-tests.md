# US-804: OpenAPI contract tests for service boundaries

## User Story

As a QA Engineer, I want OpenAPI contract tests for each service boundary that run alongside the characterization suite in CI so that a schema change in one service is caught before it breaks a consumer.

## Description

As new services are extracted, their public API shapes become contracts that consumers depend on. A schema change that removes a required field or renames a property will silently break consumers unless tests exist that detect the mismatch before the change is merged. Consumer-driven contract tests — using a framework such as Pact or Schemathesis — verify that the published OpenAPI schema matches both the service implementation and the expectations of its consumers. These tests are distinct from integration tests: they cover only the public API shape, not business logic. By running them in CI on every commit to any service, breaking changes are caught at the source rather than discovered downstream.

## Acceptance Criteria

- [ ] A contract testing framework (e.g. Pact or Schemathesis) is configured and its dependencies committed to the repository
- [ ] Consumer-driven contracts for each service boundary are committed to the repo alongside the service code
- [ ] Contract tests run in CI on every commit to any file under any `services/` subdirectory
- [ ] A breaking schema change — for example, removing a required field from a response body — causes the contract tests to fail before the change can be merged to the main branch
- [ ] Contract tests do not duplicate integration tests; they cover only the public API shape (request/response schema, required fields, status codes)
- [ ] All 6 domain services have contract tests in place by the time Phase 6 (Dispatch/Shipment extraction) is complete
- [ ] Contract test results are reported in CI alongside the characterization suite results so that failures are visible in the same pipeline view
