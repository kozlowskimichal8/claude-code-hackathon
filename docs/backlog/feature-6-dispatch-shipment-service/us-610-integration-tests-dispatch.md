# US-610: Integration tests: shipment lifecycle and event-pipeline trigger parity

## User Story

As a QA Engineer, I want integration tests for the full shipment lifecycle and event-pipeline trigger parity so that the Dispatch/Shipment Service is verifiably equivalent to the legacy procs.

## Description

Integration tests for Feature 6 are the primary safety net before the trigger cutover in US-611. They must cover the full shipment lifecycle from creation to terminal state, the driver licence-expiry enforcement, the fail-and-requeue behaviour, and the end-to-end event pipeline from shipment status change through to order status update. The comparison against the Phase 0 characterization baseline is the key acceptance gate: if the event pipeline produces a different order state than the trigger would have, the cutover must not proceed.

## Acceptance Criteria

- [ ] Integration test covers driver assignment — valid driver assigned successfully with `200` response
- [ ] Integration test covers driver assignment blocked — driver with expired licence receives `422` response
- [ ] Integration test covers driver assignment expiring-soon — driver with licence expiring within 30 days receives `200` with `X-Licence-Warning` header
- [ ] Integration test covers the full shipment lifecycle: `POST /shipments` → `PUT /shipments/{id}/status` (PickedUp) → `PUT /shipments/{id}/status` (InTransit) → `POST /shipments/{id}/complete`
- [ ] Integration test covers `POST /shipments/{id}/fail`: shipment is marked Failed and the corresponding order is re-queued (new behaviour)
- [ ] Integration test covers `POST /shipments/{id}/complete`: POD path is stored and the `ShipmentCompleted` event is emitted
- [ ] Integration test covers the dispatch board concurrency: 10 concurrent calls to `GET /shipments/active` all return correct results with no collisions
- [ ] End-to-end event pipeline test: shipment status change → `ShipmentStatusChanged` event emitted → Order Service listener receives event → order status updated; result compared against the Phase 0 trigger cascade baseline (US-602)
- [ ] All Phase 0 characterization tests for the dispatch and shipment domain remain green with the new service live
- [ ] All integration tests run in CI as part of the Feature 6 pipeline gate
