# US-002: CI Pipeline Skeleton

## User Story
As a DevOps Engineer, I want a CI pipeline that runs the schema-apply and characterization test suite on every commit so that no change can ship without proving it does not regress the legacy behaviour.

## Description
The CI pipeline is the enforcement mechanism for all safety-net work. It must reproduce the same Docker Compose environment used locally, apply all SQL scripts in order, and run the full characterization test suite as a required gate. Failure of any single test must fail the build and block merge. Test results must be published as CI artifacts so failures can be diagnosed without re-running locally. The pipeline budget is 10 minutes to keep feedback loops tight.

## Acceptance Criteria
- [ ] Pipeline triggers automatically on every push to any branch and on every pull request targeting `main`
- [ ] Pipeline spins up the Docker Compose environment defined in US-001 before running any tests
- [ ] All SQL scripts are applied in the correct order as part of the pipeline run
- [ ] The full characterization test suite (US-004 through US-009) is executed as a required step
- [ ] Any test failure causes the pipeline to exit with a non-zero status and blocks the pull request from merging
- [ ] Pipeline completes within 10 minutes from trigger to final status
- [ ] Test results (pass/fail counts, failure details) are published as downloadable CI artifacts
