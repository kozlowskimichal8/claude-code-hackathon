# US-208: Route Admin and Dashboard reporting calls to new Reporting Service

## User Story
As a Platform Engineer, I want to route all Admin and Dashboard reporting calls to the new Reporting Service so that legacy reporting procs are no longer in the hot path.

## Description
With the Reporting Service fully tested and verified against the Phase 0 baselines, the call-sites in the legacy ASP.NET application can be switched to the new service. The two primary consumers are the `Default.aspx` dashboard (which renders summary metrics on every page load) and the `Admin/EndOfDay.aspx` report section. A feature toggle must be in place before the switch is thrown so that operations can perform an instant rollback if an unexpected issue surfaces in production. The legacy procs are retained in a deprecated state — not deleted — so that the rollback path remains viable until the feature is formally closed.

## Acceptance Criteria
- [ ] `Default.aspx` dashboard metrics are fetched from the Reporting Service REST endpoints, not from legacy stored procs
- [ ] `Admin/EndOfDay.aspx` report section is fetched from the Reporting Service REST endpoints, not from legacy stored procs
- [ ] A feature toggle (environment variable or config flag) allows instant rollback to the legacy proc calls without a code deployment
- [ ] Legacy reporting stored procs are retained in the database but annotated with a `-- DEPRECATED: use Reporting Service` comment and documented in the cut-over runbook
- [ ] Cut-over is verified by observing SQL Server activity monitor for a 15-minute window and confirming zero calls to `usp_GetDailyShipmentReport`, `usp_GetDriverPerformanceReport`, `usp_GetRevenueReport`, `usp_GetCustomerActivityReport`, and `usp_GetDelayedShipmentsReport`
- [ ] All Phase 0 characterization tests remain green after cut-over
- [ ] Cut-over runbook committed to `services/reporting/docs/cutover-runbook.md` covering: pre-flight checks, switch procedure, rollback procedure, and success criteria
- [ ] HTTP error rate and p95 latency for the two cut-over pages monitored for 24 hours post-switch with no degradation versus pre-cut-over baseline
