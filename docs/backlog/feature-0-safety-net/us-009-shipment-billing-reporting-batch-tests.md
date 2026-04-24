# US-009: Shipment, Billing, Reporting, and Batch Domain Tests

## User Story
As a QA Engineer, I want characterization tests covering Shipment, Billing, Reporting, and Batch domains so that all remaining proc behaviours are pinned before any extraction begins.

## Description
This story completes the characterization coverage by pinning the four remaining domains. The Shipment domain includes the global temp table race condition in `usp_GetActiveShipments` (pinned, not fixed) and the failure handling gap in `usp_FailShipment`. The Billing domain pins the duplicate invoice bug and the full-recalculation approach of `TR_Invoices_UpdateBalance`. The Reporting domain pins the column shapes of all five report procs. The Batch domain pins the non-idempotent EOD behaviour. Together with US-004 through US-008, this story completes full coverage of all 42 procs and 5 triggers.

## Acceptance Criteria

**Shipment domain:**
- [ ] `usp_GetActiveShipments` executes without error in a single-connection test; the use of a `##` global temp table is documented in a test comment as a known concurrency hazard (NWL reference or equivalent)
- [ ] `usp_FailShipment` records the failure reason on the `Shipments` row
- [ ] `usp_FailShipment` releases the assigned driver's status back to available
- [ ] `usp_FailShipment` releases the assigned vehicle's status back to available
- [ ] `usp_FailShipment` does NOT re-queue the failed order for dispatch; test asserts the order status is `Failed`, not `Pending`
- [ ] `usp_GetShipmentTracking` returns driver initials (not full first+last name) in the tracking result
- [ ] `usp_GetShipmentTracking` returns an ETA value calculated as `EstimatedMiles / 50`; test asserts the formula with a known input/output pair

**Billing domain:**
- [ ] `usp_CreateInvoice` called twice on the same order ID creates two invoice rows; test asserts `COUNT(*) = 2` for that order (bug pinned)
- [ ] `usp_ProcessPayment` called twice with the same `ReferenceNumber` accepts both payments without error; test asserts both payment rows exist
- [ ] `TR_Invoices_UpdateBalance` recalculates `Customers.CurrentBalance` as the sum of all unpaid invoices from scratch on each insert or update to the `Invoices` table; test asserts the balance value after inserting two invoices then deleting one

**Reporting domain:**
- [ ] All 5 reporting procs (`usp_GetRevenueReport`, `usp_GetDriverPerformanceReport`, `usp_GetCustomerReport`, `usp_GetOperationalMetrics`, `usp_GetTopCustomers` or equivalent names from the schema) return at least one row when seed data is present
- [ ] Each reporting proc's result set contains the expected column names; column shape is asserted for each proc

**Batch domain:**
- [ ] `usp_ProcessEndOfDay` executes all 6 documented steps without error in a clean test run
- [ ] Running `usp_ProcessEndOfDay` a second time in the same test run creates duplicate auto-billed invoice rows for any orders processed in both runs; test asserts the duplicate count (bug pinned)

**Coverage gate:**
- [ ] All tests are committed to the repository and passing in CI
- [ ] Combined with US-004 through US-008, every one of the 42 stored procs and all 5 triggers has at least one test that exercises it
