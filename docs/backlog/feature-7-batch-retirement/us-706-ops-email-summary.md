# US-706: Ops summary email: event-driven replacement for DB Mail

## User Story

As an Operations Engineer, I want the nightly ops summary email replaced with an event-driven summary aggregated from service health endpoints so that the DB Mail dependency is eliminated and the summary reflects actual service state.

## Description

The legacy EOD batch sends an ops summary email via SQL Server DB Mail. This creates a hard dependency on the SQL Server DB Mail subsystem and means the summary reflects only data that the batch proc can query — not the actual health of the distributed services. The replacement aggregates information from the health and reporting endpoints of each live service, formats it into an HTML summary email, and sends it via SMTP. If any service is unreachable, that is flagged in the email rather than causing the job to fail silently.

## Acceptance Criteria

- [ ] A scheduled job (in a designated ops service or as a standalone scheduled task) runs nightly at 23:30
- [ ] Job calls `GET /health` and `GET /reports/daily-summary` on the Billing Service and includes the results in the summary
- [ ] Job calls `GET /health` and `GET /reports/driver-status` on the Dispatch Service and includes the results in the summary
- [ ] Job calls `GET /health` and `GET /reports/pending-orders` on the Order Service and includes the results in the summary
- [ ] If any service endpoint is unreachable or returns a non-200 response, that service is flagged as unavailable in the email body rather than silently omitted
- [ ] Aggregated results are formatted as an HTML email
- [ ] Email is sent via SMTP (not SQL Server DB Mail); SMTP configuration via environment variables
- [ ] Email structure matches the legacy EOD ops summary format (same sections, same data labels) so Ops team does not need to change their review process
- [ ] Job is idempotent: if triggered twice on the same night, a second email is sent (ops summary emails are not deduplicated — re-runs are intentional)
- [ ] An integration test verifies the email content when all services are healthy
- [ ] An integration test verifies that an unreachable service is flagged in the email rather than causing the job to fail
