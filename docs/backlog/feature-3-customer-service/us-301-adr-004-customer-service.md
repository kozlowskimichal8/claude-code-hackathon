# US-301: ADR-004: Customer Service data ownership and credit-limit boundary

## User Story
As a Business Analyst, I want ADR-004 written and accepted before any Customer Service code is written so that the `CurrentBalance` ownership boundary is formally decided and the credit-limit check ownership is clear.

## Description
The `Customers` table in the legacy system carries a denormalized `CurrentBalance` column that is recalculated by the `TR_Invoices_UpdateBalance` trigger on every invoice change. This column is a Billing concern masquerading as a Customer attribute. Before any Customer Service code is written, the team must formally decide that `CurrentBalance` lives in the Billing Service domain and must not appear in the Customer Service public API. The ADR must also resolve the related question of credit-limit checks: the Customer Service can legitimately expose a customer's credit limit (a static attribute), but the Billing Service owns the logic of comparing that limit against the current balance. The Government customer type behaviour — currently undocumented and silently falling back to Regular rates — must also be formally described so that the Customer Service enum mapping is unambiguous.

## Acceptance Criteria
- [ ] ADR-004 is committed to `decisions/ADR-004-customer-service.md` with status `Accepted`
- [ ] ADR-004 documents that the `Customers` table is the Customer Service's primary data entity but explicitly excludes `CurrentBalance` from the Customer Service data model
- [ ] ADR-004 states that `CurrentBalance` is a Billing Service concern, owned and maintained by the Billing Service
- [ ] ADR-004 documents the credit-limit read strategy: Customer Service exposes `CreditLimit` as a customer attribute; Billing Service owns the balance-vs-limit comparison logic
- [ ] ADR-004 documents all 4 customer types (`Regular`, `Premium`, `Contract`, `Government`) and their meaning, including the Government type's current undocumented behaviour and the intended behaviour in the new service
- [ ] ADR-004 includes an explicit "what we chose not to do" section (e.g. keeping `CurrentBalance` as a cached field in Customer Service, using a shared database)
- [ ] ADR-004 references ADR-001 for extraction sequence context and is consistent with it
