# US-501: ADR-006 Billing Service Architecture Decision

## User Story
As a Business Analyst, I want ADR-006 written and accepted before any Billing Service code is written so that idempotency design, `CurrentBalance` ownership, and eventual-consistency acceptance are formally agreed with the Finance team.

## Description
The Billing domain is directly coupled to the Finance team's operations: invoices, payments, and customer balances are used daily for accounts receivable and month-end close. Before any code is written, the architectural decisions must be formally documented and agreed — including the idempotency key design for `CreateInvoice`, the decision to own `CurrentBalance` as an event-sourced projection in the Billing Service (removing it from the Customers table), and the acceptable lag between delivery confirmation and invoice creation. The Finance team must review and sign off on the eventual-consistency behaviour before the ADR is marked Accepted, because this represents a visible change to their operational workflow.

## Acceptance Criteria
- [ ] ADR-006 covers the idempotency key design for `CreateInvoice`, including the key format, uniqueness scope, and retention window
- [ ] ADR-006 covers `CurrentBalance` ownership transfer: from a denormalized field in the Customers table recalculated by `TR_Invoices_UpdateBalance` to an event-sourced projection owned by the Billing Service
- [ ] ADR-006 documents the agreed eventual-consistency lag tolerance (target under 5 seconds between delivery confirmation and invoice creation) and the Finance team's acceptance of this behaviour
- [ ] ADR-006 documents the trigger retirement plan for `TR_Invoices_UpdateBalance`, including the balance-accuracy verification step required before the trigger is disabled
- [ ] ADR-006 includes a "what we rejected" section covering at minimum: synchronous invoice creation, keeping the trigger, keeping `CurrentBalance` in the Customers table
- [ ] Finance team has reviewed the ADR and their agreement is recorded (e.g. as a reviewer approval or a note in the ADR)
- [ ] ADR committed to `decisions/ADR-006-billing-service.md` with status Accepted before any service implementation begins
