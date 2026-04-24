# US-005: Customer Domain Tests

## User Story
As a QA Engineer, I want characterization tests covering the Customer domain procs so that the create, update, search, and credit-limit behaviours are pinned before extraction.

## Description
The Customer domain spans `usp_CreateCustomer`, `usp_UpdateCustomer`, `usp_GetCustomer`, `usp_SearchCustomers`, and the credit-limit guard inside `usp_CreateOrder`. Key edge cases include the silent default of invalid `CustomerType` to `'R'`, the sparse-update behaviour that prevents explicit NULL writes, the SQL injection vector in `usp_SearchCustomers` via the `@SortBy` parameter (documented and pinned but not blocked), and the asymmetric credit-limit enforcement between customer types. All tests pin current behaviour; no fixes are in scope.

## Acceptance Criteria
- [ ] `usp_CreateCustomer` called with a missing required field (e.g. null `CustomerName`) returns an error or raises an exception; the exact error is asserted
- [ ] `usp_CreateCustomer` called with an unrecognised `CustomerType` value silently stores `'R'`; test asserts the persisted value is `'R'`
- [ ] `usp_UpdateCustomer` called with a NULL value for an existing non-null field does not overwrite the field with NULL (sparse-update pattern); test asserts the original value is retained
- [ ] `usp_SearchCustomers` called with a valid column name in the `@SortBy` parameter executes without error and returns rows; the SQL injection vector is documented in a test comment but the test does not attempt to block it
- [ ] Credit-limit check in `usp_CreateOrder`: a Regular or Premium customer whose `CurrentBalance + EstimatedCost > CreditLimit` receives an error and no order is created
- [ ] Credit-limit check in `usp_CreateOrder`: a Contract customer bypasses the credit-limit check and the order is created regardless of balance
- [ ] Credit-limit check in `usp_CreateOrder`: a Government customer bypasses the credit-limit check and the order is created regardless of balance
- [ ] All tests are committed to the repository and passing in CI
