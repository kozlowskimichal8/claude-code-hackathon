# US-607: Order Service listener for ShipmentStatusChanged events

## User Story

As a Developer, I want the Order Service to subscribe to `ShipmentStatusChanged` events and update the corresponding order status so that the event pipeline is a drop-in replacement for `TR_Shipments_AutoUpdateOrderStatus`.

## Description

The Order Service must consume `ShipmentStatusChanged` events from the message broker and apply the same order status transitions that the legacy trigger would have applied. The listener must be idempotent — receiving the same event twice must produce the same order state, not a double-write or a conflict. Latency is bounded: the trigger was synchronous and instantaneous, so the event pipeline must be fast enough that dispatchers do not notice a degradation in responsiveness. The Phase 0 characterization tests for trigger cascade behaviour are the acceptance gate.

## Acceptance Criteria

- [ ] The Order Service has a running subscription to `ShipmentStatusChanged` events on the message broker
- [ ] On receipt of a `ShipmentStatusChanged` event, the Order Service updates the corresponding order's status to match the new shipment status using the order status machine (same transitions the trigger enforced)
- [ ] Processing is idempotent: receiving the same `ShipmentStatusChanged` event a second time produces the same order state and does not raise an error
- [ ] End-to-end latency from shipment status change to order status update is under 2 seconds under normal load (measurable in a local integration test)
- [ ] Failed event processing (e.g. transient database error) is retried with exponential backoff; a dead-letter queue captures events that exhaust retries
- [ ] An alert or log entry is produced when a `ShipmentStatusChanged` event is moved to the dead-letter queue
- [ ] The Phase 0 characterization tests for `TR_Shipments_AutoUpdateOrderStatus` cascade behaviour (US-602 baseline) pass when run against the event pipeline with the trigger disabled
- [ ] The Order Service listener is covered by unit tests for each shipment status → order status mapping
