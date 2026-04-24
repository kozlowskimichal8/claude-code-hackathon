# US-611: Cutover: disable TR_Shipments_AutoUpdateOrderStatus

## User Story

As a Platform Engineer, I want to disable `TR_Shipments_AutoUpdateOrderStatus` after the event pipeline is verified so that the tightest legacy coupling point is cleanly retired.

## Description

Disabling `TR_Shipments_AutoUpdateOrderStatus` is the defining moment of Feature 6 and the highest-risk operation in the strangler-fig plan. The 2016 attempt to remove this trigger caused a full system failure. The cutover must be preceded by a parallel-run window where both the trigger and the event pipeline fire simultaneously, with any divergence logged and investigated. Only after the pipeline has processed at least 1,000 real updates with zero divergence may the trigger be disabled. A rollback plan must be documented and tested before the cutover window opens.

## Acceptance Criteria

- [ ] Pre-cutover: the event pipeline has processed at least 1,000 real shipment status updates in the production environment with zero divergence from the trigger-driven order status (divergence measured by comparing order status records during the parallel-run window)
- [ ] A parallel-run window of at least 1 hour is completed: both `TR_Shipments_AutoUpdateOrderStatus` and the Order Service event listener are active simultaneously; any case where the resulting order status differs between trigger and event is logged and investigated before proceeding
- [ ] Zero divergence cases are recorded during the parallel-run window before the trigger is disabled
- [ ] Rollback plan is documented: steps to re-enable `TR_Shipments_AutoUpdateOrderStatus` and pause the Order Service event listener are tested in a non-production environment before the production cutover
- [ ] Trigger is disabled using `DISABLE TRIGGER TR_Shipments_AutoUpdateOrderStatus ON Shipments` (not dropped — retained for rollback reference)
- [ ] Post-cutover: the `Default.aspx` dispatch board page is served by the new Dispatch/Shipment Service
- [ ] Post-cutover: all Phase 0 characterization tests remain green with the trigger disabled and the event pipeline active
- [ ] Post-cutover: zero calls to any of the 12 legacy dispatch/shipment stored procs appear in the SQL Server activity monitor for 15 consecutive minutes
- [ ] Post-cutover: an alert is configured to fire if `TR_Shipments_AutoUpdateOrderStatus` is re-enabled
