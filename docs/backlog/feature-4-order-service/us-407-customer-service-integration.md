# US-407: Customer Service Credit-Limit Integration

## User Story
As a Developer, I want `POST /orders` to call the Customer Service for credit-limit validation so that Regular and Premium customers are blocked when their balance would exceed their credit limit.

## Description
The legacy credit-limit check in `usp_CreateOrder` is non-atomic: it reads `CurrentBalance` and `CreditLimit` separately from the Customers table and then proceeds to create the order in a separate step, leaving a race window in which two concurrent orders for the same customer can both pass the check even though only one should. The new service must perform the credit-limit check as part of the create transaction, calling the Customer Service for the credit limit and the Billing Service for the current balance, and must enforce that the combined total does not exceed the limit for Regular and Premium customers. Contract and Government customers must bypass the check, consistent with the legacy behaviour documented in Phase 0.

## Acceptance Criteria
- [ ] `POST /orders` calls the Customer Service to retrieve the customer's credit limit and customer type before committing the order
- [ ] `POST /orders` calls the Billing Service to retrieve the customer's current outstanding balance
- [ ] If `CurrentBalance + EstimatedCost > CreditLimit` for a Regular (`R`) or Premium (`P`) customer, order creation returns 422 with the message "Credit limit would be exceeded"
- [ ] Contract (`C`) and Government (`G`) customers bypass the credit-limit check and order creation proceeds normally
- [ ] The credit-limit check and order insert are atomic: no partial order row is written if the check fails
- [ ] Phase 0 characterization tests for credit-limit behaviour (from US-005 and US-006) pass against the new service without modification
- [ ] Integration tests cover: Regular customer within limit (succeeds), Regular customer over limit (422), Premium customer over limit (422), Contract customer over limit (succeeds), Government customer over limit (succeeds)
