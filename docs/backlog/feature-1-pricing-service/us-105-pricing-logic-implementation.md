# US-105: Pricing Logic Implementation

## User Story
As a Developer, I want `POST /pricing/calculate` to implement the full pricing formula so that results are identical to `usp_CalculateOrderCost` for all valid inputs.

## Description
The endpoint implements the pricing formula extracted from `usp_CalculateOrderCost` and makes two deliberate improvements: the fuel surcharge is read from a configuration source instead of being hardcoded, and the Government customer fallback to Regular rates is explicit and logged rather than silent. The formula sequence must match the legacy proc exactly to ensure shadow-mode divergence is zero. Unknown customer types must return a 400 error rather than silently falling back.

## Acceptance Criteria
- [ ] Formula steps execute in this order: (1) look up weight tier in `PricingRules` for the given `customerType` and `weightKg`; (2) `BaseCost = BaseRate + EstimatedMiles × PerMileRate`; (3) apply fuel surcharge: `BaseCost × (1 + fuelSurchargePct / 100)` where `fuelSurchargePct` is read from `SystemSettings` or an environment variable; (4) add `$75` if `isHazmat = true`; (5) apply priority multiplier (`Normal = 1.0`, `High = 1.10`, `Urgent = 1.25`); (6) apply discount: `× (1 - discountPct / 100)`; (7) round final result to 2 decimal places
- [ ] Government customers use the Regular pricing tier; a structured log entry at `INFO` level records that Government rates were resolved to Regular for the given `customerId`
- [ ] Fuel surcharge percentage is not hardcoded; it is read from a named config key on every request
- [ ] A request with an unrecognised `customerType` value returns HTTP 400 with a descriptive error message
- [ ] A request with no matching `PricingRules` row (weight outside all tiers) returns HTTP 422 with a descriptive error message
- [ ] Response body matches the OpenAPI 3.1 schema defined in US-102
