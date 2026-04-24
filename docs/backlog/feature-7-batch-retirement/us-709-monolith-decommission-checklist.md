# US-709: Monolith decommission checklist

## User Story

As a Platform Engineer, I want a decommission checklist that confirms zero traffic to legacy procs before the monolith is shut down so that the strangler-fig decomposition is complete and the legacy system can be safely retired.

## Description

The decommission checklist is the final gate before the legacy SQL Server + ASP.NET WebForms monolith is permanently retired. It collects evidence across all six domains and all eight phases that the strangler-fig decomposition is complete: no proc calls, no active triggers, no client traffic to the old WebForms app, and a verified backup of the final database state. The checklist must be reviewed and signed off by the Operations team before any infrastructure is decommissioned.

## Acceptance Criteria

- [ ] Checklist document created at `docs/decommission-checklist.md`
- [ ] Checklist item: zero calls to each of the 42 legacy stored procs for 30 consecutive days, verified via SQL Server Extended Events trace or equivalent activity monitoring
- [ ] Checklist item: SQL Agent job `usp_ProcessEndOfDay` is disabled (US-708 complete)
- [ ] Checklist item: all 6 domain services (Customer, Order, Pricing, Billing, Dispatch/Shipment, Reporting) are live and passing their health checks
- [ ] Checklist item: `TR_Shipments_AutoUpdateOrderStatus` is disabled (US-611 complete)
- [ ] Checklist item: `TR_Invoices_UpdateBalance` is disabled (confirmed as part of Billing Service cutover in Feature 5)
- [ ] Checklist item: `CurrentBalance` accuracy verified in Billing Service — balance values match the legacy SQL Server `Customers.CurrentBalance` column for all active customers within an acceptable tolerance
- [ ] Checklist item: the ASP.NET WebForms application is returning `301 Redirect` responses to the new UI for all routes, or has been taken offline with a static decommission notice
- [ ] Checklist item: a final backup of the SQL Server database has been taken, verified, and archived to long-term storage
- [ ] Checklist item: the decommission checklist has been reviewed and signed off by the Operations team lead (name and date recorded in the document)
- [ ] The checklist document is committed to the repository and linked from the main `README.md`
