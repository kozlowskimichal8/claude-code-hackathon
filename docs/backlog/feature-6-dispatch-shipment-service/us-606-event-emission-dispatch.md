# US-606: Event emission: ShipmentStatusChanged, ShipmentCompleted, ShipmentFailed

## User Story

As a Developer, I want the Dispatch/Shipment Service to emit `ShipmentStatusChanged`, `ShipmentCompleted`, and `ShipmentFailed` events to the event bus so that the Order Service can update order status via event subscription instead of the trigger.

## Description

The event pipeline is the direct replacement for `TR_Shipments_AutoUpdateOrderStatus`. Every shipment status change must produce an event on the bus; if the service crashes between writing the status change to the database and publishing the event, the event must still be delivered. The outbox pattern achieves this guarantee by writing the event to a local outbox table within the same database transaction as the status change, and having a background relay publish it to the broker. Events must carry enough information for the Order Service to update order state without querying the Dispatch Service.

## Acceptance Criteria

- [ ] A `ShipmentStatusChanged` event is published to the message broker on every shipment status change
- [ ] `ShipmentStatusChanged` payload includes: `shipmentId`, `orderId`, `driverId`, `previousStatus`, `newStatus`, `timestamp` (UTC ISO-8601)
- [ ] A `ShipmentCompleted` event is published when a shipment is marked complete; payload includes: `shipmentId`, `orderId`, `podPath` (proof-of-delivery file path), `actualMiles`
- [ ] A `ShipmentFailed` event is published when a shipment is marked failed; payload includes: `shipmentId`, `orderId`, `failureReason`, `orderRequeued` (boolean)
- [ ] Events are written using the outbox pattern: the outbox record is inserted in the same database transaction as the shipment status change, preventing event loss on crash
- [ ] A background relay process publishes outbox records to the message broker and marks them as published
- [ ] If the message broker is temporarily unavailable, outbox records accumulate and are published when the broker recovers — no events are silently dropped
- [ ] All three event types (`ShipmentStatusChanged`, `ShipmentCompleted`, `ShipmentFailed`) are observable in the message broker UI during local development
- [ ] Event schemas are committed to `services/dispatch/events/` as JSON Schema files
