# US-408: ACL Adapter for Order Detail

## User Story
As a Developer, I want an ACL adapter that abstracts the `usp_GetOrder` 3-result-set shape into a typed `OrderDetail` DTO so that no consumer ever needs to depend on result-set ordinal positions.

## Description
The legacy `usp_GetOrder` procedure returns three separate result sets: the order header, a list of order items, and a shipment summary. Consumers in the legacy WebForms code access these by result-set index (0, 1, 2) and column ordinal, which is fragile and opaque. The ACL adapter must translate this multi-result-set shape into a typed `OrderDetail` DTO during the migration window so that any caller of `GET /orders/{id}` works with named fields, not ordinal positions. The adapter must be unit-tested against the exact legacy output to confirm correct field mapping, and the Phase 0 characterization test for `usp_GetOrder` (constraint 1) must continue to pass, confirming that the legacy behaviour is preserved through the adapter.

## Acceptance Criteria
- [ ] `OrderDetail` DTO is defined with named fields covering: all order header columns, a typed list of `OrderItem` objects, and a shipment summary object
- [ ] ACL adapter translates the legacy 3-result-set shape into the `OrderDetail` DTO during the migration window (while SQL Server is still the source)
- [ ] No caller of `GET /orders/{id}` accesses any field by result-set index or column ordinal position
- [ ] ACL adapter is unit-tested with fixture data matching the exact 3-result-set output of `usp_GetOrder`, verifying that every field in `OrderDetail` is correctly populated
- [ ] Phase 0 characterization test covering `usp_GetOrder` behaviour (constraint 1) still passes after the adapter is introduced, confirming the legacy behaviour is preserved
- [ ] The adapter is located in a clearly named ACL package/namespace (e.g. `Acl`, `Legacy`, `Adapters`) separate from the domain model
