# US-401: ADR-005 Order Service Architecture Decision

## User Story
As a Business Analyst, I want ADR-005 written and accepted before any Order Service code is written so that the status machine design, event emission strategy, and FK restoration decision are formally documented.

## Description
The Order domain is the most complex domain in the legacy system: it touches Pricing, Customer, Dispatch, and Billing, and the 280-line `usp_UpdateOrderStatus` god proc encodes every transition rule as a single switch statement. Before any code is written, the architectural decisions must be agreed and committed — including the explicit per-transition status machine design, the event emission strategy, whether to use RabbitMQ or Azure Service Bus, the FK restoration between `Orders` and `OrderItems`, and how the `usp_GetOrder` 3-result-set shape will be abstracted. The ADR must also enumerate what was explicitly rejected (e.g., keeping the god proc, skipping FK restoration) so future contributors understand the rationale.

## Acceptance Criteria
- [ ] ADR-005 covers the explicit per-transition status machine design replacing `usp_UpdateOrderStatus`, with each transition handler documented as a separate concern
- [ ] ADR-005 documents the event emission strategy, including choice of message broker (RabbitMQ or Azure Service Bus) with rationale and rejected alternatives
- [ ] ADR-005 covers FK restoration between `Orders` and `OrderItems` with explanation of why it was removed in 2015 and why it is safe to restore
- [ ] ADR-005 covers the `usp_GetOrder` 3-result-set ACL abstraction into a typed `OrderDetail` DTO
- [ ] ADR-005 explicitly documents the dependency on Pricing Service (Phase 1) and Customer Service (Phase 3) being live before Phase 4 begins
- [ ] ADR-005 includes a "what we chose not to do" section
- [ ] ADR committed to `decisions/ADR-005-order-service.md` with status Accepted before any service implementation begins
