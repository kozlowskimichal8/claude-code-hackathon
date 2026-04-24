# US-108: ACL Adapter for Customer Type

## User Story
As a Developer, I want an ACL adapter that translates legacy `CustomerType` codes to the `PricingTier` enum so that no legacy `DataTable` or SQL Server type ever leaks into the Pricing Service's domain model.

## Description
The Anti-Corruption Layer adapter is the boundary enforcement mechanism between the legacy monolith's stringly-typed SQL Server world and the Pricing Service's domain model. It translates the single-character legacy `CustomerType` codes to the strongly-typed `PricingTier` enum used internally by the service. The adapter must live inside the Pricing Service codebase, not in the monolith, so the new service's domain model is never polluted by legacy representations. A `PreToolUse` hook in `.claude/settings.json` enforces the boundary at development time.

## Acceptance Criteria
- [ ] An `LegacyCustomerTypeAdapter` class (or equivalent) exists in `services/pricing/Acl/`
- [ ] The adapter maps: `'R'` → `PricingTier.Regular`, `'P'` → `PricingTier.Premium`, `'C'` → `PricingTier.Contract`, `'G'` → `PricingTier.Government`
- [ ] An unknown or null code returns a typed `Result.Failure` or throws a domain exception; it does not return a string fallback or silently default to any tier
- [ ] No reference to `System.Data.DataTable`, `System.Data.SqlClient`, or `System.Data.SqlTypes` exists anywhere under `services/pricing/`; a grep of the directory for these namespaces returns zero matches
- [ ] The adapter is covered by unit tests for all 4 known codes (`R`, `P`, `C`, `G`) and at least one unknown code (e.g. `'X'`) and a null/empty input
- [ ] The `PreToolUse` hook is configured in `.claude/settings.json` to warn when files under `services/pricing/` are modified to import `System.Data.SqlClient` or reference `DataTable`
