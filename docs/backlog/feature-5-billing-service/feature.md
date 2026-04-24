# Feature 5: Billing Service

## Goal
Replace trigger-based billing with an event-driven Billing Service that subscribes to `OrderStatusChanged(Delivered)` events, enforces idempotent invoice creation, and owns `CurrentBalance` as an incrementally-maintained projection.

## Description
This phase retires the `TR_Invoices_UpdateBalance` trigger — which recalculates `CurrentBalance` from scratch on every invoice insert or update — and replaces it with an event-driven flow: the Billing Service subscribes to `OrderStatusChanged(Delivered)` events from the Order Service (Phase 4) and creates invoices asynchronously. Idempotency is enforced via a required idempotency key on `POST /invoices`, eliminating the duplicate-invoice defect that occurs when `usp_CompleteShipment` is called twice. `CurrentBalance` is maintained incrementally as a projection updated on invoice creation, payment recording, and discount application, removing the full-table recalculation that fires on every billing operation. The Finance team must formally accept a short eventual-consistency lag between delivery confirmation and invoice creation before this phase begins. Unique constraints on payment `ReferenceNumber` replace the legacy "we trust accounting" pattern of silently accepted duplicate payments.

## Scope
- Stored procedures: `usp_CreateInvoice`, `usp_ProcessPayment`, `usp_GetInvoice`, `usp_ApplyDiscount`, `usp_GetOutstandingInvoices`, `usp_GenerateMonthlyStatement`
- Trigger retired: `TR_Invoices_UpdateBalance`
- Defects fixed: non-idempotent invoice creation (duplicate invoices when called twice), `CurrentBalance` full-table recalculation on every invoice change, duplicate payment acceptance
- Event subscription: `OrderStatusChanged` with `newStatus=Delivered` from the Order Service event bus
- Idempotency key enforced on `POST /invoices` with unique constraint in PostgreSQL
- `CurrentBalance` as an incrementally-maintained projection in the Billing Service database, no longer a denormalized field in the Customers table
- Eventual consistency: billing team accepts a short lag (target under 5 seconds) between delivery confirmation and invoice creation

## User Stories

| ID | Title |
|---|---|
| [US-501](us-501-adr-006-billing-service.md) | ADR-006 Billing Service Architecture Decision |
| [US-502](us-502-openapi-contracts-billing.md) | OpenAPI Contracts for Billing Service |
| [US-503](us-503-postgres-schema-billing.md) | PostgreSQL Schema for Billing |
| [US-504](us-504-event-subscription-order-delivered.md) | Event Subscription for Order Delivered |
| [US-505](us-505-idempotency-create-invoice.md) | Idempotent Invoice Creation |
| [US-506](us-506-unique-payment-reference.md) | Unique Payment Reference Constraint |
| [US-507](us-507-current-balance-event-sourced.md) | CurrentBalance as Event-Sourced Projection |
| [US-508](us-508-integration-tests-billing.md) | Integration Tests for Billing Service |
| [US-509](us-509-disable-invoices-trigger.md) | Disable TR_Invoices_UpdateBalance |
| [US-510](us-510-cutover-billing.md) | Billing Service Cut-Over |

## Exit Criterion
Event-driven billing is live and confirmed processing `OrderStatusChanged(Delivered)` events; `POST /invoices` returns the existing invoice on a duplicate idempotency key; `TR_Invoices_UpdateBalance` is disabled after a balance-accuracy verification showing zero discrepancy between the projection and a full recalculation; `CurrentBalance` in the Billing Service is accurate to within 1 cent for all customers; all Phase 0 characterization tests remain green (with billing behaviour tests updated to assert idempotent behaviour).
