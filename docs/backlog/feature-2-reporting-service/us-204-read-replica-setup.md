# US-204: Read replica / event projection database for reporting

## User Story
As a Platform Engineer, I want a read replica or event projection database set up for the Reporting Service so that reporting queries never contend with write traffic on the primary database.

## Description
Reporting queries are historically the heaviest read workload in the Northwind Logistics system, and running them against the primary database has caused lock contention during peak dispatch hours. Introducing a dedicated read replica (or event-projected read store) isolates this workload entirely. For local development and CI a Docker Compose configuration is sufficient; the same configuration will be promoted to staging and production infrastructure. Replica lag must be observable because some downstream consumers (e.g. the EOD batch) may require fresh data; an alert threshold of 60 seconds ensures operations are notified before stale reports become a business problem.

## Acceptance Criteria
- [ ] A read replica or projected read database container is defined in `docker-compose.yml` for local development
- [ ] The Reporting Service connection string (via environment variable) points to the replica, not the primary database
- [ ] The Reporting Service database role has SELECT permissions only; INSERT, UPDATE, and DELETE are denied at the database level — verified by attempting a write from the service and confirming it fails with a permission error
- [ ] Replica lag is measured and written to the service structured log on a configurable interval (default: every 30 seconds)
- [ ] If replica lag exceeds 60 seconds an alert is raised (log entry at ERROR level and, in staging/production, a monitoring alert fires)
- [ ] A README or runbook section in `services/reporting/docs/` describes how to reset and reseed the read replica in a local development environment
- [ ] Read replica setup validated in CI: the integration test suite connects through the replica, not the primary
