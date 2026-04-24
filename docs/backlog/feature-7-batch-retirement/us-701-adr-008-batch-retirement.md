# US-701: ADR-008: Batch retirement architecture decision

## User Story

As a Business Analyst, I want ADR-008 written and accepted before batch retirement work begins so that the step decomposition, idempotency design, and notification strategy are formally documented.

## Description

Retiring the EOD batch requires decisions that span multiple services and affect operational procedures that the Ops team relies on every night. The decomposition of each step to its owning service, the idempotency key design, the checkpoint table pattern, and the replacement for the SQL Server DB Mail notification must all be agreed and recorded before implementation begins. ADR-008 provides the formal record that prevents ad hoc decisions during implementation and gives the Ops team visibility into what changes before the SQL Agent job is disabled.

## Acceptance Criteria

- [ ] ADR-008 is committed to `decisions/ADR-008-batch-retirement.md` with status `Accepted`
- [ ] ADR-008 documents the decomposition of all 6 EOD steps to their owning services: auto-billing → Billing Service, overdue marking → Billing Service, driver status reset → Dispatch Service, stale order notification → Order Service, ops summary → new ops summary job, DB maintenance → PostgreSQL pg_cron
- [ ] ADR-008 documents the idempotency key design for each replacement step (key format, storage mechanism)
- [ ] ADR-008 documents the checkpoint table pattern: schema, what is recorded per run, how partial failures are recovered
- [ ] ADR-008 documents the replacement for SQL Server DB Mail: SMTP configuration approach, which service is responsible for sending
- [ ] ADR-008 includes a "What we chose not to do" section covering at least two rejected alternatives (e.g. keeping a central batch orchestrator, using a workflow engine)
- [ ] The Ops team has reviewed the proposed cutover schedule for the SQL Agent job and their sign-off is noted in the ADR or in a linked comment
- [ ] ADR-008 is reviewed and accepted before any Feature 7 implementation begins
