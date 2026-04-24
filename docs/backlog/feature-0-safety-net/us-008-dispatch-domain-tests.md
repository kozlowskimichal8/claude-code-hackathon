# US-008: Dispatch Domain Tests

## User Story
As a QA Engineer, I want characterization tests covering driver dispatch behaviours so that availability logic, LOA handling, and assignment flows are pinned before extraction.

## Description
The Dispatch domain manages driver and vehicle availability and the assignment of orders to drivers. Several known gaps exist: drivers on LOA still appear in availability results, drivers with licences expiring within one month are flagged but not blocked, and duplicate licence numbers produce a warning rather than an error. These gaps are pinned as-is. The assignment flow that creates a `Shipments` record and updates both driver and vehicle status must also be covered end-to-end.

## Acceptance Criteria
- [ ] `usp_GetAvailableDrivers` returns drivers whose licence expires within 1 month; the result set includes a flag or indicator column for the near-expiry; the drivers are not excluded from results
- [ ] `usp_AssignDriver` successfully assigns a driver whose licence expires within 1 month; no error or block occurs; test asserts the assignment is persisted
- [ ] `usp_GetAvailableDrivers` includes drivers whose status is `LOA`; test asserts the LOA driver appears in the result set and documents this as a known gap
- [ ] `usp_CreateDriver` called with a licence number that already exists in the `Drivers` table produces a warning (return code or output message) but does not raise a terminating error; the duplicate row is created; test asserts both rows exist
- [ ] `usp_AssignOrderToDriver` creates a new `Shipments` row linked to the specified order and driver
- [ ] `usp_AssignOrderToDriver` updates the assigned driver's status to indicate they are no longer available
- [ ] `usp_AssignOrderToDriver` updates the assigned vehicle's status to indicate it is no longer available
- [ ] All tests are committed to the repository and passing in CI
