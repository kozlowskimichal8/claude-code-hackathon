# Feature 4: Order Service

## Goal
Extract all Order-domain stored procedures into a .NET 8 microservice that integrates with the live Pricing Service (Phase 1) and Customer Service (Phase 3), replacing the god-proc pattern with an explicit per-transition status machine.

## Description
This phase completes the extraction of the Order domain from the legacy monolith by replacing eight stored procedures — including the 280-line `usp_UpdateOrderStatus` god proc — with a typed .NET 8 service that models order lifecycle as explicit per-transition handlers. The new service integrates synchronously with the already-live Pricing Service for cost calculation and the Customer Service for credit-limit validation, eliminating the NULL TotalCost bug and the non-transactional cost path in `usp_CreateOrder`. Domain events (`OrderCreated`, `OrderStatusChanged`, `OrderCancelled`) are emitted to the event bus on every state change, decoupling downstream services (Billing, Dispatch) from direct SQL coupling. The FK between `Orders` and `OrderItems` — removed in 2015 — is restored in the PostgreSQL schema, enforcing data integrity at the database level. The SQL injection vulnerability in `usp_SearchOrders` (NWL-389) is closed by replacing the dynamic `@SortBy` SQL with an enum-validated `sortBy` query parameter in the OpenAPI contract.

## Scope
- Stored procedures: `usp_CreateOrder`, `usp_GetOrder`, `usp_UpdateOrderStatus`, `usp_CancelOrder`, `usp_SearchOrders`, `usp_GetPendingOrders`, `usp_AssignOrderToDriver`, `usp_GetOrdersByCustomer`
- Status machine replacing `usp_UpdateOrderStatus` (280 lines, single switch statement): `Pending→Assigned`, `Assigned→PickedUp`, `PickedUp→InTransit`, `InTransit→Delivered`, `InTransit→Failed`, `Pending→Cancelled`, `any→OnHold`
- FK restoration: `OrderItems.OrderId` → `Orders.Id`
- Defects fixed: SQL injection in `usp_SearchOrders` (NWL-389), NULL TotalCost from non-transactional cost calculation in `usp_CreateOrder`, missing credit-limit check atomicity
- ACL adapter abstracting the `usp_GetOrder` 3-result-set shape into a typed `OrderDetail` DTO
- Domain events: `OrderCreated`, `OrderStatusChanged`, `OrderCancelled` emitted via outbox pattern
- Integration with Pricing Service (synchronous, inside create transaction) and Customer Service (credit-limit check)

## User Stories

| ID | Title |
|---|---|
| [US-401](us-401-adr-005-order-service.md) | ADR-005 Order Service Architecture Decision |
| [US-402](us-402-openapi-contracts-order.md) | OpenAPI Contracts for Order Service |
| [US-403](us-403-postgres-schema-order.md) | PostgreSQL Schema and FK Restoration |
| [US-404](us-404-order-status-machine.md) | Order Status Machine |
| [US-405](us-405-event-emission-order.md) | Domain Event Emission |
| [US-406](us-406-pricing-service-integration.md) | Pricing Service Integration |
| [US-407](us-407-customer-service-integration.md) | Customer Service Credit-Limit Integration |
| [US-408](us-408-acl-get-order.md) | ACL Adapter for Order Detail |
| [US-409](us-409-order-data-migration.md) | Order Data Migration Runbook |
| [US-410](us-410-integration-tests-order.md) | Integration Tests for Order Service |
| [US-411](us-411-cutover-order.md) | Order Service Cut-Over |

## Exit Criterion
The full order lifecycle (create, assign, pick-up, transit, deliver, cancel) is served exclusively by the new Order Service; Pricing Service and Customer Service dependencies are satisfied with synchronous calls inside the create transaction; the FK between `OrderItems` and `Orders` is enforced in PostgreSQL; domain events are confirmed visible in the message broker on every transition; all Phase 0 characterization tests remain green against the unmodified legacy stack; and zero calls to `usp_CreateOrder`, `usp_GetOrder`, or `usp_UpdateOrderStatus` appear in the SQL Server activity monitor during a 15-minute production window.
