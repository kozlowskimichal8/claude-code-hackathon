# US-004: Behavioural Constraint Tests

## User Story
As a QA Engineer, I want integration tests that pin all 10 documented behavioural constraints of the monolith so that any future extraction that silently changes these behaviours is caught immediately.

## Description
These 10 tests cover the highest-risk cross-cutting behaviours: multi-result-set procedures, trigger side-effects, status-field mutation, NULL propagation on calculation failure, idempotency failures (bugs pinned as-is), stale denormalised balance, orphaned child rows after archive, missing authentication, and incorrect pricing for Government customers. Each test must assert the exact current behaviour, including the bugs. Fixing any bug is out of scope for this story — the goal is that the test suite will fail if a future change accidentally alters any of these behaviours, whether that change is a fix or a regression.

## Acceptance Criteria
- [ ] Test 1: `usp_GetOrder` returns exactly 3 result sets; each result set's ordinal position and column shape are asserted
- [ ] Test 2: Updating a `Shipments` row fires `TR_Shipments_AutoUpdateOrderStatus` and the parent `Orders.Status` changes to match the new shipment status
- [ ] Test 3: `usp_UpdateOrderStatus` appends a timestamped entry to the `SpecialInstructions` field in the expected format
- [ ] Test 4: `usp_CreateOrder` with a failing cost calculation (e.g. no matching pricing rule) results in `TotalCost = NULL` on the created order row
- [ ] Test 5: Calling `usp_ProcessEndOfDay` twice in the same test run produces duplicate invoice rows (bug pinned — test asserts the duplicate exists, not that it is prevented)
- [ ] Test 6: Calling `usp_CompleteShipment` twice on the same shipment ID creates two invoice rows (bug pinned — test asserts count = 2)
- [ ] Test 7: `Customers.CurrentBalance` is not updated until a new invoice is inserted or updated; the test asserts the stale value before and the refreshed value after a `TR_Invoices_UpdateBalance` trigger fires
- [ ] Test 8: `usp_ArchiveOldOrders` moves matching `Orders` rows to the archive table but leaves their child `OrderItems` rows in the live `OrderItems` table
- [ ] Test 9: A GET request to `Admin/EndOfDay.aspx` with no authentication header returns HTTP 200
- [ ] Test 10: A Government-type customer (`CustomerType = 'G'`) is billed at the Regular (`'R'`) rate, not at a dedicated Government rate
- [ ] All 10 tests are committed to the repository and passing in CI
