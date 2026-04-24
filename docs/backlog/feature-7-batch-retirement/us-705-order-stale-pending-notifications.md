# US-705: Order Service: nightly stale Pending order notification job

## User Story

As a Platform Engineer, I want a scheduled job in the Order Service that logs and notifies about stale Pending orders older than 48h so that EOD batch step 4 is replaced — and the notification email that was never wired up is finally connected.

## Description

EOD batch step 4 was supposed to send a notification email about stale `Pending` orders but the email was never wired up in the legacy system (documented in known-issues as "notification email never wired up"). The replacement job in the Order Service both identifies the stale orders and actually sends the notification email via SMTP. This is a genuine behaviour improvement over the legacy step: the Ops team will receive actionable alerts about orders that have been sitting in `Pending` status for more than 48 hours and need manual intervention.

## Acceptance Criteria

- [ ] Job runs nightly at 23:20 (time is configurable via environment variable)
- [ ] Job identifies all orders in `Pending` status that were created more than 48 hours ago
- [ ] Job sends a notification email to the configured Ops email address (configurable via environment variable)
- [ ] Email includes: list of order IDs, corresponding customer names, and the number of hours each order has been in `Pending` status
- [ ] Email is sent via SMTP (configuration via environment variables: `SMTP_HOST`, `SMTP_PORT`, `SMTP_FROM`, `SMTP_OPS_ADDRESS`) — SQL Server DB Mail is not used
- [ ] Job is idempotent: the same stale orders are not double-notified within the same calendar night (tracked via checkpoint table)
- [ ] A checkpoint table records for each run: run date, number of stale orders found, number of emails sent, number of errors, run start time, run end time
- [ ] The output of the replacement job matches the output of EOD batch step 4 for the same input data (verified by running both against a test dataset), with the additional difference that the email is now actually sent
- [ ] An integration test verifies that an order in `Pending` status older than 48 hours appears in the notification email content
- [ ] An integration test verifies that an order in `Pending` status newer than 48 hours does not appear in the notification email content
