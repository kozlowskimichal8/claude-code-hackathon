# US-206: Replace `##global` temp table with per-request CTE in daily shipment report

## User Story
As a Developer, I want the `##global` temp table pattern replaced with a per-request CTE in the daily shipment report so that concurrent report requests no longer collide.

## Description
The legacy `usp_GetDailyShipmentReport` uses a `##`-prefixed global temporary table to stage intermediate results. Global temp tables in SQL Server are scoped to the session but share a single namespace across all sessions, meaning two concurrent calls to the proc will attempt to create and populate the same table simultaneously. This causes intermittent errors and data cross-contamination during busy dispatch periods. Replacing the pattern with a Common Table Expression (CTE) scoped to the individual query eliminates the shared-state problem entirely and is the correct fix to carry into the new service. This story specifically validates the fix under concurrent load to ensure the regression does not resurface.

## Acceptance Criteria
- [ ] `GET /reports/daily-shipments` produces correct results when called concurrently by 10 simultaneous clients with different date ranges
- [ ] No `##` global temp table syntax exists anywhere in the Reporting Service codebase
- [ ] Intermediate aggregation in the daily shipment report is expressed as a CTE within the main query
- [ ] A load test of 10 concurrent clients for 30 seconds against `GET /reports/daily-shipments` produces zero HTTP errors and zero result sets that do not match the expected row count for the given date range
- [ ] Single-request results match the Phase 0 characterization baseline for the daily shipment report (same columns, same aggregate values for the seeded test dataset)
- [ ] Load test is automated and runs in CI as part of the Reporting Service test suite
- [ ] The fix is referenced in the commit message with the defect identifier so the fix is traceable in git history
