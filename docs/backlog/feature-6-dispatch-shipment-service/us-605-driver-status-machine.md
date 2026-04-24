# US-605: Driver status machine with licence-expiry hard block

## User Story

As a Developer, I want the driver status machine implemented with a hard licence-expiry check at assignment time so that expired-licence drivers can never be assigned to an order.

## Description

The legacy `usp_AssignDriver` proc performs no licence-expiry validation, allowing drivers with expired licences to be assigned to orders. The new service implements a formal status machine with all valid transitions enforced in application code, and adds a hard licence-expiry check at assignment time. Drivers whose licence has already expired receive a 422 response; drivers whose licence expires within 30 days receive a 200 with a warning header so that dispatchers can take action before the licence lapses.

## Acceptance Criteria

- [ ] The following status transitions are permitted: `Available → OnRoute` (triggered by driver assignment), `OnRoute → Available` (triggered by shipment complete, shipment fail, or recovery), `Available → OffDuty`, `OffDuty → Available`, any non-`Terminated` state → `LOA`, `LOA → Available`
- [ ] All other status transitions are rejected with a `422 Unprocessable Entity` response and a descriptive error message
- [ ] The assignment endpoint (`POST /orders/{id}/assign`) returns `422` if the driver's `LicenceExpiry` date is earlier than today
- [ ] The assignment endpoint returns `200` with an `X-Licence-Warning: expiring-soon` response header if the driver's `LicenceExpiry` date is between today and today + 30 days (inclusive)
- [ ] `GET /drivers` (available) excludes drivers with status `Terminated` or `LOA`
- [ ] `Terminated` drivers cannot transition to any other status; attempts return `422`
- [ ] Unit tests cover every permitted transition
- [ ] Unit tests cover every rejected transition and assert the `422` response
- [ ] Unit tests cover the expired-licence block (422) and the expiring-soon warning (200 + header)
- [ ] Unit tests cover that `Terminated` and `LOA` drivers are excluded from the available drivers list
