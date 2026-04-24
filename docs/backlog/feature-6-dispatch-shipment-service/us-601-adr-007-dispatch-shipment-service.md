# US-601: ADR-007: Dispatch/Shipment Service architecture decision

## User Story

As a Business Analyst, I want ADR-007 written and accepted before any Dispatch/Shipment Service code is written so that the trigger retirement plan, driver status machine, and licence-expiry enforcement decision are formally documented.

## Description

The Dispatch/Shipment Service extraction carries the highest architectural risk in the strangler-fig plan. Before a single line of service code is written, the team must reach a formal, recorded decision on how to retire `TR_Shipments_AutoUpdateOrderStatus`, what the authoritative driver status machine looks like, and whether licence expiry is a hard block or a warning at assignment time. ADR-007 captures these decisions along with the trade-offs considered and the alternatives that were rejected, providing a durable record that future engineers can audit when the trigger is eventually disabled.

## Acceptance Criteria

- [ ] ADR-007 is committed to `decisions/ADR-007-dispatch-shipment-service.md` with status `Accepted`
- [ ] ADR-007 documents the trigger retirement strategy: `TR_Shipments_AutoUpdateOrderStatus` replaced by a `ShipmentStatusChanged` event pipeline, including the parallel-run window approach and rollback plan
- [ ] ADR-007 defines the driver status machine with all valid states: `Available`, `OnRoute`, `OffDuty`, `Terminated`, `LOA` and all valid transitions between them
- [ ] ADR-007 records the licence-expiry enforcement decision: whether expiry is a hard block (422 returned) or a warning (200 with header) at assignment time — a concrete decision is made, not deferred
- [ ] ADR-007 documents the nested-transaction fix strategy for `usp_CreateShipment` (savepoints chosen or rejected with rationale)
- [ ] ADR-007 documents `usp_FailShipment` re-queue behaviour change: failed orders will be re-queued for reassignment in the new service, whereas the legacy proc does not do this
- [ ] ADR-007 explicitly calls out the risk that trigger retirement was attempted in 2016 and broke the system, and describes the mitigation strategy for this phase
- [ ] ADR-007 includes a "What we chose not to do" section covering at least two rejected alternatives
- [ ] The ADR is reviewed and signed off by at least one team member before Feature 6 implementation begins
