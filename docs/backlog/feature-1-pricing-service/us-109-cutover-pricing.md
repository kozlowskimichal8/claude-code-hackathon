# US-109: Cut-Over

## User Story
As a Platform Engineer, I want to cut over all `usp_CalculateOrderCost` callers to the new Pricing Service so that the legacy proc is no longer in the hot path, while remaining available as a fallback.

## Description
Cut-over is the final step that makes the Pricing Service the live pricing authority. It must only proceed once the shadow-mode gate (500 calls, zero divergences) has been met. The change routes all callers — `usp_CreateOrder`, the EOD batch, and any ad-hoc call sites — through the ACL adapter to the new service. The legacy proc is retained in SQL Server and marked deprecated so it can be restored instantly via a feature flag if an unexpected issue emerges. The cut-over is verified empirically by observing zero legacy proc calls during a 15-minute monitoring window.

## Acceptance Criteria
- [ ] Cut-over is only executed after the shadow-mode gate (US-107) is confirmed: at least 500 calls with zero divergences documented in a comment or PR description
- [ ] All call sites within the legacy application that invoke `usp_CalculateOrderCost` are updated to call the Pricing Service via the ACL adapter instead
- [ ] Callers confirmed updated: `usp_CreateOrder` (or its application-layer equivalent), the EOD batch path in `Admin/EndOfDay.aspx.cs`
- [ ] The legacy `usp_CalculateOrderCost` stored procedure is retained in the database but has a deprecation comment added to its header
- [ ] A feature flag or configuration toggle exists that, when flipped, routes all callers back to the legacy proc with no code change or deployment required
- [ ] After cut-over, a 15-minute observation window shows zero executions of `usp_CalculateOrderCost` in SQL Server activity monitor or equivalent trace; this observation is documented in the PR or deployment record
