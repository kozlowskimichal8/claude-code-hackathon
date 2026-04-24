# US-101: ADR-002: Pricing Service Architecture Decision

## User Story
As a Business Analyst, I want ADR-002 written and accepted before any Pricing Service code is written so that the Government customer pricing gap and fuel surcharge decisions are agreed with Finance before they go live.

## Description
The Pricing Service extraction is the first strangler-fig seam and sets the pattern for all subsequent extractions. Two business decisions embedded in the legacy proc have never been formally agreed: Government customers are silently billed at Regular rates (Finance adjusts invoices manually), and the 15% fuel surcharge is hardcoded with no mechanism for Finance to update it. These decisions must be resolved with Finance stakeholders and recorded in an ADR before any code is written. The ADR must also document the rejected alternatives so future contributors understand what was considered.

## Acceptance Criteria
- [ ] ADR-002 is created at `decisions/ADR-002-pricing-service.md` following the structure established by ADR-001
- [ ] ADR covers the tech stack choice: .NET 8 minimal API and PostgreSQL, with rationale
- [ ] ADR covers the deployment model: Docker container, with rationale
- [ ] ADR contains an explicit decision on Government customer pricing — either a dedicated Government tier is introduced or the Regular-rate fallback is formalised — and documents that Finance has agreed to the chosen option
- [ ] ADR specifies that the fuel surcharge will be read from a configuration source (e.g. `SystemSettings` table or environment variable) rather than hardcoded
- [ ] ADR includes a "what we chose not to do" section listing at least two rejected alternatives with reasons
- [ ] ADR status is set to `Accepted` before any implementation work in US-103 or later begins
- [ ] The file is committed to the repository
