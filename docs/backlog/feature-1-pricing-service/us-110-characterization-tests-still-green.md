# US-110: Characterization Tests Still Green After Cut-Over

## User Story
As a QA Engineer, I want all Phase 0 characterization tests to remain green after the Pricing Service cut-over so that I have confidence the extraction did not change any observable system behaviour.

## Description
The characterization test suite from Feature 0 is the single most important regression guard for the entire strangler-fig programme. After the Pricing Service cut-over, no test in that suite may be modified, skipped, or quarantined to make it pass — the suite must pass as-is against the post-cut-over system. This story formalises that gate as a CI requirement and provides the explicit sign-off that the first extraction is complete and safe.

## Acceptance Criteria
- [ ] The full Phase 0 characterization test suite (US-004 through US-009) runs without any modification to test code after the Pricing Service cut-over is applied
- [ ] All pricing-related characterization tests (primarily US-007) produce results identical to the pre-cut-over baseline; no new test failures are introduced
- [ ] No test from the Phase 0 suite is marked as `skip`, `ignore`, `pending`, or moved to a quarantine category as a result of the cut-over
- [ ] The CI pipeline includes the Phase 0 characterization suite as a required step after each Pricing Service deployment; the pipeline cannot pass if any characterization test fails
- [ ] A CI run showing all Phase 0 tests green in the post-cut-over configuration is linked in the feature completion record or pull request
