# US-107: Shadow Mode

## User Story
As a Platform Engineer, I want the Pricing Service to run in shadow mode alongside the legacy proc so that I can verify zero divergence before cutting over any traffic.

## Description
Shadow mode is the safety gate between implementing the new service and trusting it with live traffic. Every real `usp_CalculateOrderCost` call in the legacy application is intercepted by the shadow adapter, which calls both the legacy proc and the new service in parallel (or sequentially with negligible latency impact), compares the results, and logs any divergence with full input and output detail. The legacy result is always returned to the caller during shadow mode. Cut-over is blocked until at least 500 real calls have been observed with zero divergence.

## Acceptance Criteria
- [ ] A shadow-mode adapter class or middleware intercepts every invocation of `usp_CalculateOrderCost` within the legacy application code path
- [ ] The adapter calls the Pricing Service's `POST /pricing/calculate` endpoint for each intercepted call, translating inputs via the ACL adapter (US-108)
- [ ] The adapter compares the legacy proc's `TotalCost` result with the Pricing Service's `totalCost` response; a divergence is defined as a difference greater than $0.01
- [ ] Any divergence is logged with: timestamp, all input parameters, legacy result, new service result, and the absolute difference
- [ ] Divergences do not affect the value returned to the original caller; the legacy result is always used during shadow mode
- [ ] A log query or dashboard metric shows the total number of shadow calls processed and the total number of divergences; the metric is accessible without querying the production database
- [ ] Cut-over (US-109) is blocked by a documented gate: at least 500 shadow calls with zero divergences logged
