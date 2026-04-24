# US-702: Billing Service: nightly auto-billing job

## User Story

As a Platform Engineer, I want a scheduled job in the Billing Service that auto-bills delivered orders with `IsBilled = 0` older than 7 days so that the EOD batch auto-billing step is replaced by an idempotent owned job.

## Description

EOD batch step 1 scans the Orders table for delivered orders that have not yet been invoiced and creates invoices for them. The replacement job lives entirely within the Billing Service, runs on a configurable nightly schedule, and uses an idempotency key per order per run date to prevent duplicate invoice creation if the job is re-run. A checkpoint table provides a per-run audit trail that the Ops team can query to verify the job ran correctly.

## Acceptance Criteria

- [ ] Job runs nightly at 23:00 (time is configurable via environment variable)
- [ ] Job processes all orders in `Delivered` status with `IsBilled = 0` that were created more than 7 days ago
- [ ] Each invoice creation uses an idempotency key in the format `auto-bill:{orderId}:{runDate}` (e.g. `auto-bill:12345:2026-04-24`)
- [ ] Running the job twice on the same night for the same set of orders creates no duplicate invoices; second run is a no-op for already-processed orders
- [ ] A checkpoint table (`billing_job_runs` or equivalent) records for each run: run date, number of orders processed, number of invoices created, number of errors, run start time, run end time
- [ ] Checkpoint records are queryable via a Billing Service internal endpoint or directly in the database
- [ ] The output of the replacement job matches the output of EOD batch step 1 for the same input data (verified by running both against a test dataset)
- [ ] Job failures are logged with sufficient detail to identify which orders failed and why
