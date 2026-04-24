# US-106: Unit Tests for Pricing Logic

## User Story
As a QA Engineer, I want unit tests covering all pricing combinations so that every code path is verified independently of the database.

## Description
Unit tests for the Pricing Service exercise the calculation logic in isolation using in-memory fakes or stubs for the `PricingRules` repository. They complement the Phase 0 characterization tests by verifying the new code's correctness before shadow mode begins. The test expectations for shared input/output pairs must match the Phase 0 characterization tests exactly, providing a cross-check that the new implementation is behaviourally equivalent to the legacy proc.

## Acceptance Criteria
- [ ] Tests cover all 4 customer types (Regular, Premium, Contract, Government) across at least 3 different weight tiers each
- [ ] Hazmat fee of $75 is asserted when `isHazmat = true` for at least one input combination
- [ ] No hazmat fee is asserted when `isHazmat = false`
- [ ] All 3 priority levels (Normal, High, Urgent) are tested with their respective multipliers (1.0, 1.10, 1.25)
- [ ] Discount of 0%, 10%, and 50% are each tested on at least one input combination
- [ ] A test asserts that Government customer inputs produce the same `totalCost` as identical Regular customer inputs, and verifies that a log entry is emitted
- [ ] A test asserts that the fuel surcharge is read from the injected configuration value, not a hardcoded constant; the test passes a custom surcharge value and asserts the result reflects it
- [ ] For each input/output pair that overlaps with the Phase 0 characterization tests (US-007), the expected `totalCost` value is identical
- [ ] Code coverage tooling reports 100% branch coverage on the pricing calculation class
