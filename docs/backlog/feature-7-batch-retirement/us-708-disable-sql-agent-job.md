# US-708: Cutover: disable usp_ProcessEndOfDay SQL Agent job

## User Story

As a Platform Engineer, I want to disable the `usp_ProcessEndOfDay` SQL Agent job after all replacement jobs are verified so that the last active legacy batch proc is cleanly retired.

## Description

Disabling the SQL Agent job is the final operational cutover of Feature 7. It must only happen after all five replacement jobs have proven reliable over a sustained period and a divergence check has confirmed that the replacement outputs match the legacy batch outputs. The job is disabled rather than deleted so that it can be re-enabled as an emergency rollback if a replacement job fails unexpectedly. An alert ensures the Ops team is notified if the legacy job is ever re-enabled after this point.

## Acceptance Criteria

- [ ] Pre-disable checklist verified: all five replacement jobs (US-702 through US-706) have run successfully for at least 7 consecutive nights without errors
- [ ] Divergence check completed for 7 days: invoice counts from the auto-billing job match EOD batch step 1 output; overdue invoice counts match step 2; driver reset counts match step 3; no discrepancies found
- [ ] The SQL Agent job `usp_ProcessEndOfDay` is disabled (not deleted) using SQL Server Agent job properties or T-SQL (`sp_update_job @enabled = 0`)
- [ ] The job definition is retained in the SQL Server instance for rollback reference
- [ ] A SQL Server Agent alert is configured to fire and notify the Ops team if the `usp_ProcessEndOfDay` job is re-enabled
- [ ] The decommission checklist (`docs/decommission-checklist.md`) is updated to mark the SQL Agent job step as complete
- [ ] Rollback procedure is documented: steps to re-enable the SQL Agent job and pause the replacement jobs if an emergency rollback is required
- [ ] The Ops team is notified that the SQL Agent job has been disabled and the replacement schedule is now authoritative
