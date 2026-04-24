# US-509: Disable TR_Invoices_UpdateBalance

## User Story
As a Platform Engineer, I want `TR_Invoices_UpdateBalance` disabled after the Billing Service cut-over with a balance-accuracy verification step so that the legacy trigger is cleanly retired.

## Description
`TR_Invoices_UpdateBalance` fires on every `Invoices` INSERT or UPDATE and recalculates `CurrentBalance` in the `Customers` table from scratch by summing all invoice and payment rows. Once the Billing Service is live and owning `CurrentBalance` as a projection, the trigger must not also be updating the field — it will cause double-counting. Before disabling the trigger, a verification script must confirm that the Billing Service projection matches a full recalculation from raw data to within zero discrepancy. The trigger must not be dropped (so rollback is possible) but disabled. Disabling the trigger is the final gate before cut-over is declared complete.

## Acceptance Criteria
- [ ] Balance verification script compares `CurrentBalance` in the Billing Service `CustomerBalance` projection against a fresh full recalculation from `Invoices` and `Payments` tables for every customer
- [ ] Discrepancy threshold is zero: no customer's balance may differ between projection and full recalculation by any amount before the trigger is disabled
- [ ] If the verification script finds any discrepancy, the trigger disable step is blocked and an alert is raised
- [ ] Trigger is disabled using `DISABLE TRIGGER TR_Invoices_UpdateBalance ON Invoices` (not dropped)
- [ ] Disabling the trigger is documented as the last step before cut-over is declared complete
- [ ] Rollback plan documented: how to re-enable the trigger (`ENABLE TRIGGER TR_Invoices_UpdateBalance ON Invoices`) and pause the Billing Service event-driven flow simultaneously to prevent a race during rollback
- [ ] Post-disable verification: run the balance verification script again immediately after disabling the trigger and confirm zero discrepancy
- [ ] Verification script is committed to the repository and executable in CI against a production-sized staging snapshot
