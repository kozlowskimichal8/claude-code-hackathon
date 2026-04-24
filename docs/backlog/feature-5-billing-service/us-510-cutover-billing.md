# US-510: Billing Service Cut-Over

## User Story
As a Platform Engineer, I want to route all billing operations to the new Billing Service so that legacy billing stored procedures are no longer in the hot path.

## Description
Cut-over routes live invoice creation, payment recording, and outstanding invoice queries from the legacy SQL Server stored procedures to the new Billing Service. The strangler-fig proxy must be configured to forward billing requests to the new service while legacy procs remain in SQL Server as a rollback safety net. A feature flag must allow instant rollback to the legacy procs without a deployment. The cut-over is only declared complete when a 15-minute production monitoring window confirms zero calls to the retired billing procs, `TR_Invoices_UpdateBalance` is disabled, and the full Phase 0 characterization test suite remains green with billing tests updated to reflect idempotent behaviour.

## Acceptance Criteria
- [ ] Invoice creation is served by `POST /invoices` on the new Billing Service for all traffic
- [ ] Payment recording is served by `POST /invoices/{id}/payments` on the new Billing Service for all traffic
- [ ] Outstanding invoice queries are served by `GET /invoices` on the new Billing Service for all traffic
- [ ] Legacy billing stored procedures (`usp_CreateInvoice`, `usp_ProcessPayment`, `usp_GetInvoice`, `usp_ApplyDiscount`, `usp_GetOutstandingInvoices`, `usp_GenerateMonthlyStatement`) are retained in SQL Server but marked with a deprecation comment
- [ ] A feature flag is in place that routes traffic back to the legacy procs instantly without a redeployment
- [ ] Cut-over is verified by monitoring the SQL Server activity monitor for 15 minutes and confirming zero calls to `usp_CreateInvoice` and `usp_ProcessPayment`
- [ ] `TR_Invoices_UpdateBalance` is disabled before cut-over is declared complete (as per US-509)
- [ ] All Phase 0 characterization tests are green at the end of the 15-minute monitoring window, with billing behaviour tests updated to assert idempotent behaviour
- [ ] Rollback procedure is documented: how to flip the feature flag back, re-enable `TR_Invoices_UpdateBalance`, and confirm legacy procs are serving traffic
