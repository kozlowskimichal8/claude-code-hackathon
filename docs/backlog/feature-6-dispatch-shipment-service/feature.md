# Feature 6: Dispatch / Shipment Service

## Goal

Extract the Dispatch and Shipment domain into an independent service by replacing the tightest coupling seam in the monolith — `TR_Shipments_AutoUpdateOrderStatus` — with an event-driven pipeline.

## Description

This is the highest-risk extraction in the strangler-fig plan. The `TR_Shipments_AutoUpdateOrderStatus` trigger has been the primary coupling mechanism between the Shipments and Orders tables since 2016, when an attempt to remove it caused a full system failure. This phase replaces the trigger cascade with a `ShipmentStatusChanged` domain event emitted by the new Dispatch/Shipment Service and consumed by the Order Service. Before any code is written, extended characterization tests must pin every status transition the trigger produces so that the event pipeline can be verified as behaviourally equivalent.

Alongside trigger retirement, this phase fixes four defects in the legacy dispatch procs: the nested-transaction rollback bug in `usp_CreateShipment` (which can silently roll back an enclosing order transaction), the `##global` temp table collision in `usp_GetActiveShipments` that corrupts results under concurrent dispatchers, the absence of a licence-expiry check that allows expired-licence drivers to be assigned, and `usp_FailShipment` not re-queuing failed orders for reassignment. Because this phase carries the highest coupling risk of any extraction, it requires the most characterization test coverage before cutover.

## Scope

**Stored procedures covered:**
`usp_GetAvailableDrivers`, `usp_AssignDriver`, `usp_UpdateDriverLocation`, `usp_GetDriverSchedule`, `usp_CreateDriver`, `usp_GetDriverPerformance`, `usp_CreateShipment`, `usp_UpdateShipmentStatus`, `usp_GetShipmentTracking`, `usp_CompleteShipment`, `usp_FailShipment`, `usp_GetActiveShipments`

**Triggers retired:**
`TR_Shipments_AutoUpdateOrderStatus` (replaced by `ShipmentStatusChanged` event pipeline)

**Defects fixed:**
- NWL-???  Nested-transaction rollback in `usp_CreateShipment` silently aborts outer order transaction
- NWL-???  `##global` temp table in `usp_GetActiveShipments` causes result collisions under concurrent dispatchers
- NWL-???  Expired driver licence not blocked at assignment time — `usp_AssignDriver` has no expiry check
- NWL-???  `usp_FailShipment` does not re-queue the failed order for reassignment

**Prerequisite phases:** Feature 0 (characterization tests), Feature 4 (Order Service live)

## User Stories

| ID | Title |
|---|---|
| [US-601](us-601-adr-007-dispatch-shipment-service.md) | ADR-007: Dispatch/Shipment Service architecture decision |
| [US-602](us-602-extended-characterization-tests-trigger.md) | Extended characterization tests for trigger cascade |
| [US-603](us-603-openapi-contracts-dispatch.md) | OpenAPI contracts for Dispatch/Shipment Service |
| [US-604](us-604-postgres-schema-dispatch.md) | PostgreSQL schema migration for Drivers, Vehicles, and Shipments |
| [US-605](us-605-driver-status-machine.md) | Driver status machine with licence-expiry hard block |
| [US-606](us-606-event-emission-dispatch.md) | Event emission: ShipmentStatusChanged, ShipmentCompleted, ShipmentFailed |
| [US-607](us-607-order-service-listener.md) | Order Service listener for ShipmentStatusChanged events |
| [US-608](us-608-per-request-dispatch-board.md) | Per-request active dispatch board (replace ##global temp table) |
| [US-609](us-609-fix-shipment-create-transaction.md) | Fix shipment creation nested-transaction bug with savepoints |
| [US-610](us-610-integration-tests-dispatch.md) | Integration tests: shipment lifecycle and event-pipeline trigger parity |
| [US-611](us-611-cutover-disable-trigger.md) | Cutover: disable TR_Shipments_AutoUpdateOrderStatus |

## Exit Criterion

`TR_Shipments_AutoUpdateOrderStatus` is disabled on the production SQL Server instance; the event pipeline (`ShipmentStatusChanged` → Order Service listener) has processed at least 1,000 real shipment status updates with zero divergence from the legacy trigger behaviour; all Phase 0 characterization tests remain green; the `Default.aspx` dispatch board is served by the new Dispatch Service; no calls to any of the 12 legacy dispatch/shipment procs appear in the SQL Server activity monitor for 15 consecutive minutes.
