# US-504: Event Subscription for Order Delivered

## User Story
As a Developer, I want the Billing Service to subscribe to `OrderStatusChanged(Delivered)` events from the Order Service and automatically create an invoice so that the `TR_Invoices_UpdateBalance` trigger chain is replaced by a durable event-driven flow.

## Description
In the legacy system, invoice creation is tightly coupled to shipment completion via the `TR_Invoices_UpdateBalance` trigger. The new flow decouples these concerns: the Billing Service subscribes to the event bus and reacts to `OrderStatusChanged` events where `newStatus=Delivered`. Using the `orderId` as the idempotency key (formatted as `order:{orderId}`) means that if the same event is delivered more than once (message broker at-least-once semantics), the second delivery produces no duplicate invoice. Failures in event processing must be retried with exponential backoff, and events that cannot be processed after retries must go to a dead-letter queue with alerting so the Finance team can intervene.

## Acceptance Criteria
- [ ] Billing Service subscribes to the event bus topic/queue receiving `OrderStatusChanged` events from the Order Service
- [ ] On receiving an `OrderStatusChanged` event with `newStatus=Delivered`, the Billing Service calls `POST /invoices` internally using `order:{orderId}` as the idempotency key
- [ ] If the same event is delivered twice (simulated in tests by publishing the identical event payload twice), exactly one invoice is created and the second delivery returns without error
- [ ] Failed event processing is retried with exponential backoff; retry configuration (initial interval, multiplier, max retries) is documented in the service configuration
- [ ] Events that fail all retries are written to a dead-letter queue
- [ ] Dead-letter queue depth triggers a log warning or metric alert visible during local development and in CI
- [ ] Invoice creation latency from event receipt to invoice record committed is under 5 seconds under normal (non-stressed) load
- [ ] End-to-end integration test: publish an `OrderStatusChanged(Delivered)` event to the message broker and verify that an invoice is created in the PostgreSQL database within the 5-second SLA
