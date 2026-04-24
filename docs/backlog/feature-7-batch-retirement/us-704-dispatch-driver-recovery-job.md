# US-704: Dispatch Service: nightly driver reset and recovery job

## User Story

As a Platform Engineer, I want a scheduled job in the Dispatch Service that resets `OffDuty→Available` drivers and recovers drivers stuck `OnRoute > 16h` with no active shipment so that EOD batch step 3 is replaced by an idempotent owned job.

## Description

EOD batch step 3 performs two driver housekeeping operations: it resets all `OffDuty` drivers to `Available` for the next day, and it identifies drivers who have been in `OnRoute` status for more than 16 hours with no active shipment — a sign of a missed status update — and resets them to `Available` with a recovery note. The replacement job lives within the Dispatch Service and applies the driver status machine transitions, ensuring the same validation rules apply as during normal operations.

## Acceptance Criteria

- [ ] Job runs nightly at 23:15 (time is configurable via environment variable)
- [ ] Job resets all drivers in `OffDuty` status to `Available`
- [ ] Job identifies drivers in `OnRoute` status for more than 16 hours with no active shipment and resets them to `Available` with a recovery note recorded on the driver record
- [ ] Job is idempotent: running the job twice on the same night produces the same driver states with no repeated resets or duplicate recovery notes
- [ ] A checkpoint table records for each run: run date, number of `OffDuty` drivers reset to `Available`, number of stuck `OnRoute` drivers recovered, number of errors, run start time, run end time
- [ ] The output of the replacement job matches the output of EOD batch step 3 for the same input data (verified by running both against a test dataset)
- [ ] An integration test verifies that a driver in `OffDuty` status is reset to `Available` after the job runs
- [ ] An integration test verifies that a driver in `OnRoute` status for more than 16 hours with no active shipment is recovered to `Available` with a recovery note
- [ ] An integration test verifies that a driver in `OnRoute` status with an active shipment is not affected by the recovery step
