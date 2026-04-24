# US-703: Billing Service: nightly overdue invoice marking job

## User Story

As a Platform Engineer, I want a scheduled job in the Billing Service that marks invoices overdue so that the EOD batch overdue-marking step is replaced by an idempotent owned job.

## Description

EOD batch step 2 scans the Invoices table for invoices whose due date has passed and marks them as `Overdue`. The replacement job lives within the Billing Service and runs after the auto-billing job (step 1) to ensure newly created invoices are considered in the same nightly window. The job is idempotent: an invoice already marked `Overdue` will not be updated again, so re-running on the same night produces no spurious writes.

## Acceptance Criteria

- [ ] Job runs nightly at 23:10 (after the auto-billing job at 23:00; time is configurable via environment variable)
- [ ] Job marks all invoices where `DueDate < today` and `PaidAmount < TotalAmount` as `Overdue`
- [ ] Job is idempotent: running the job twice on the same night produces the same set of `Overdue` invoices with no duplicate writes or status flip-flops
- [ ] A checkpoint table records for each run: run date, number of invoices marked `Overdue`, number of invoices already in `Overdue` status (skipped), number of errors, run start time, run end time
- [ ] The output of the replacement job matches the output of EOD batch step 2 for the same input data (verified by running both against a test dataset)
- [ ] Job failures are logged with sufficient detail to identify which invoices failed and why
- [ ] An integration test verifies that an invoice with `DueDate = yesterday` and `PaidAmount < TotalAmount` is marked `Overdue` after the job runs
- [ ] An integration test verifies that an invoice already in `Overdue` status is not re-written when the job runs again
