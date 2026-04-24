# US-905: Fuel surcharge read from config, not hardcoded

## User Story

As a Security Engineer, I want the 15% fuel surcharge read from a config service or environment variable rather than hardcoded in the pricing formula so that rate changes do not require a code deployment and the configuration is auditable.

## Description

The legacy `usp_CalculateOrderCost` stored procedure hardcodes a `0.15` (15%) fuel surcharge multiplier directly in T-SQL. Changing the rate requires a stored procedure edit and a manual deployment step, and there is no audit trail of when the rate was last changed or by whom. The Pricing Service must read this value from a named configuration source — either the `SystemSettings` table or an environment variable — so that rate changes can be made without redeployment and every change is traceable. This story tracks the configuration-security requirement; its functional delivery is owned by US-105 (Pricing logic implementation) in Feature 1. The current configured value is exposed in the `/health` endpoint for auditability, treated as non-sensitive operational metadata rather than a secret.

## Acceptance Criteria

- [ ] US-105 (Pricing logic implementation, Feature 1) is delivered and passes its own acceptance criteria
- [ ] The Pricing Service reads `FuelSurchargePercent` from the `SystemSettings` table or from the environment variable `FUEL_SURCHARGE_PERCENT`; the environment variable takes precedence if both are set
- [ ] The literal `0.15` does not appear anywhere in the Pricing Service codebase; this is verified by a Grep step in CI that fails the build if the literal is found in any `.cs` or `.sql` file under `services/pricing/`
- [ ] A configuration change to 18% (`FUEL_SURCHARGE_PERCENT=18`) is applied without redeploying the service and takes effect on the next pricing calculation request
- [ ] The current configured fuel surcharge percentage is included in the Pricing Service `/health` response body (e.g. `"fuelSurchargePercent": 15`); it is treated as operational metadata, not a secret, and is not redacted
- [ ] Change history for the `FuelSurchargePercent` configuration value is auditable — either via the `SystemSettings` table's own audit log or via environment variable change records in the deployment platform
