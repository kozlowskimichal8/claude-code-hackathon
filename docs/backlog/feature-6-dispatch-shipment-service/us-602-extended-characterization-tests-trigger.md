# US-602: Extended characterization tests for trigger cascade

## User Story

As a QA Engineer, I want extended characterization tests targeting `TR_Shipments_AutoUpdateOrderStatus` cascade behaviour so that the event-driven replacement can be verified as behaviourally equivalent before the trigger is disabled.

## Description

`TR_Shipments_AutoUpdateOrderStatus` is the tightest coupling seam in the monolith. Before the event pipeline can replace it, the exact behaviour of the trigger — including edge cases, rapid updates, and concurrent writes — must be pinned by characterization tests committed to the repository. These tests form the acceptance baseline: the event pipeline passes this phase only when all tests remain green after `TR_Shipments_AutoUpdateOrderStatus` is disabled and the listener is live. Tests must be written against the running legacy system and committed before any Dispatch Service code is written.

## Acceptance Criteria

- [ ] Characterization tests are committed to the repository under the Phase 0 test suite before any Dispatch/Shipment Service implementation begins
- [ ] Tests cover the `PickedUp` shipment status transition: a shipment updated to `PickedUp` causes the parent order status to change to `PickedUp`
- [ ] Tests cover the `InTransit` shipment status transition: a shipment updated to `InTransit` causes the parent order status to change to `InTransit`
- [ ] Tests cover the `Delivered` shipment status transition: a shipment updated to `Delivered` causes the parent order status to change to `Delivered`
- [ ] Tests cover the `Failed` shipment status transition: a shipment updated to `Failed` causes the parent order status to change to `Failed`
- [ ] Tests cover rapid back-to-back status updates on the same shipment (e.g. `Pending→PickedUp→InTransit` in quick succession) and verify the final order status is correct
- [ ] Tests cover concurrent status updates to the same shipment from two database sessions and verify the resulting order status is deterministic
- [ ] Tests cover calling `usp_CompleteShipment` directly and verify the resulting status cascade on the parent order
- [ ] All tests pass (green) against the unmodified legacy database before any Feature 6 work is merged
- [ ] Test results are saved as the acceptance baseline and referenced in the US-611 cutover checklist
