# US-007: Pricing Domain Tests

## User Story
As a QA Engineer, I want characterization tests covering all pricing combinations so that the exact calculation produced by `usp_CalculateOrderCost` is pinned for every customer type, weight tier, priority, and hazmat flag.

## Description
`usp_CalculateOrderCost` implements the full pricing formula: weight-tier lookup from `PricingRules`, base cost calculation, a hardcoded 15% fuel surcharge, a $75 hazmat fee, priority multipliers, and a discount. The hardcoded fuel surcharge value must be asserted as-is in these tests — it is a known defect that will be fixed in Feature 1, but here it is pinned so that Feature 1 can demonstrate the improvement. Government customers receiving Regular rates must also be pinned explicitly.

## Acceptance Criteria
- [ ] Tests cover all 4 customer types: Regular (`R`), Premium (`P`), Contract (`C`), and Government (`G`)
- [ ] For each customer type, at least 3 different weight tiers from the `PricingRules` table are exercised
- [ ] Hazmat fee of exactly $75 is asserted when `IsHazmat = 1`; no hazmat fee is asserted when `IsHazmat = 0`
- [ ] Priority multiplier `Normal = 1.0` is asserted (i.e. no change to base cost)
- [ ] Priority multiplier `High = 1.10` is asserted
- [ ] Priority multiplier `Urgent = 1.25` is asserted
- [ ] The 15% fuel surcharge is asserted as a hardcoded value; a test comment notes this is a known defect (NWL reference or equivalent) to be resolved in Feature 1
- [ ] Discount application is tested: an order with a non-zero discount percentage produces a `TotalCost` lower than the pre-discount amount by the expected fraction
- [ ] A Government customer (`CustomerType = 'G'`) produces the same `TotalCost` as a Regular customer (`CustomerType = 'R'`) with identical inputs; the test comment notes this is the known Government pricing fallback
- [ ] Calculated `TotalCost` stored on the `Orders` row after `usp_CreateOrder` matches the value returned by `usp_CalculateOrderCost` for the same inputs
- [ ] All tests are committed to the repository and passing in CI
