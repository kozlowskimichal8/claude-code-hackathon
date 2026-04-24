# US-405: Domain Event Emission

## User Story
As a Developer, I want the Order Service to emit `OrderCreated`, `OrderStatusChanged`, and `OrderCancelled` events to the event bus so that downstream services (Billing, Dispatch) can react without polling or direct coupling.

## Description
Downstream services currently couple to the Orders table via direct SQL queries or stored procedure calls. Replacing this coupling with domain events allows Billing and Dispatch to react to order lifecycle changes asynchronously without knowing the Order Service's internal data model. The outbox pattern (or equivalent) must be used to prevent silent event loss: if the service crashes after writing the order row but before publishing the event, the event must still be delivered on restart. A dead-letter queue must capture events that cannot be processed after retries, with alerting so the team is notified of stuck events.

## Acceptance Criteria
- [ ] `OrderCreated` event is published to the message broker on every successful `POST /orders`
- [ ] `OrderStatusChanged` event is published to the message broker on every successful status transition, including `OnHold` transitions
- [ ] `OrderCancelled` event is published to the message broker on every successful `DELETE /orders/{id}`
- [ ] All event payloads include: `orderId`, `customerId`, `previousStatus` (null for `OrderCreated`), `newStatus`, `timestamp` (UTC ISO-8601)
- [ ] Event publication uses an outbox pattern or equivalent transactional outbox; a service restart after a commit but before publication does not result in a lost event
- [ ] Events are visible in a local message broker UI (e.g. RabbitMQ Management) during local development using Docker Compose
- [ ] A dead-letter queue is configured for events that fail delivery after the configured retry count
- [ ] Dead-letter queue depth triggers an alert (log warning or metric) visible during local dev and in CI
- [ ] Integration tests verify event emission for create, at least three status transitions, and cancel scenarios
