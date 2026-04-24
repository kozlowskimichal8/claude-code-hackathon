# US-201: ADR-003: Reporting Service read-model strategy

## User Story
As a Business Analyst, I want ADR-003 written and accepted before any Reporting Service code is written so that the read-model strategy (replica vs. event projection) is decided and documented.

## Description
Before any implementation work begins on the Reporting Service, the team must formally decide how the new service will obtain its data. The two primary candidates are a SQL read replica of the legacy SQL Server database and a purpose-built event-projected read model populated from domain events. This decision has downstream consequences for data freshness tolerance, infrastructure complexity, and eventual decoupling from the legacy schema. The ADR must also identify which reports are safe to serve with eventual consistency and which require near-real-time accuracy. All stakeholders — including the Operations team who must support the replica infrastructure — must review and accept the decision before a line of service code is written.

## Acceptance Criteria
- [ ] ADR-003 is committed to `decisions/ADR-003-reporting-service.md` with status `Accepted`
- [ ] ADR-003 covers the read-model approach and recommends SQL read-replica as the first step with rationale
- [ ] ADR-003 documents data sync lag tolerance per report (e.g. daily shipment report: up to 60 s; driver performance: up to 5 min acceptable)
- [ ] ADR-003 identifies which of the 5 reports are safe for eventual consistency and which are not, with justification
- [ ] ADR-003 documents the chosen tech stack for the Reporting Service (.NET 8, PostgreSQL read replica, etc.)
- [ ] ADR-003 includes an explicit "what we chose not to do" section covering rejected alternatives (event sourcing, direct SQL Server reads from new service, CQRS with separate write model)
- [ ] Data sync strategy has been reviewed and signed off by the Operations team before the ADR status is set to Accepted
- [ ] ADR-003 references ADR-001 and is consistent with the strangler-fig extraction sequence
