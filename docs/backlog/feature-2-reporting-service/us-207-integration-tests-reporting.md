# US-207: Integration tests asserting result shape parity with legacy procs

## User Story
As a QA Engineer, I want integration tests for all 5 report endpoints that assert result shape parity with the legacy procs so that the Reporting Service is verifiably a drop-in replacement.

## Description
Characterization tests captured in Phase 0 record the exact output of the legacy reporting procs against a known seed dataset. The integration tests for the Reporting Service must compare the new endpoint responses against those same baselines, ensuring that the extraction has not altered any observable behaviour. Tests run inside a Docker Compose environment so that the read replica, seed data, and service are all provisioned deterministically. These tests form the primary regression gate: if any endpoint's response shape, row count, or aggregate value diverges from the Phase 0 baseline, the CI build fails and the cut-over is blocked.

## Acceptance Criteria
- [ ] Integration tests run against a Docker Compose environment with a deterministic seeded test dataset
- [ ] For each of the 5 endpoints, tests assert: correct HTTP status code (200 for valid inputs, 400 for invalid parameters), correct response schema (all expected fields present with correct data types), correct row count for the seeded test dataset, correct aggregate values (sums, averages, counts) for the seeded test dataset
- [ ] Test assertions for row counts and aggregate values are derived directly from the Phase 0 characterization baselines — not independently calculated
- [ ] `GET /reports/revenue` test covers `groupBy=Day`, `groupBy=Week`, `groupBy=Month`, and an invalid `groupBy` value (expects 400)
- [ ] `GET /reports/daily-shipments` test includes a concurrent execution case (at minimum 3 simultaneous requests) confirming no data cross-contamination
- [ ] Tests run automatically in CI on every commit to any file under `services/reporting/`
- [ ] All Phase 0 characterization tests (against the legacy system) continue to pass unchanged after the new tests are added
- [ ] Test results include execution time per endpoint to detect performance regressions
