# Feature 1: Pricing Service

## Goal
Extract `usp_CalculateOrderCost` into a stateless .NET 8 minimal API backed by PostgreSQL, running first in shadow mode to prove zero divergence before any traffic is cut over.

## Description
Pricing is the safest first extraction target: it is pure read logic with no write coupling to the legacy database, it has a single well-defined input/output contract, and its only side-effect is returning a calculated cost. The new service owns the `PricingRules` data in PostgreSQL, eliminating the dependency on the legacy SQL Server `PricingRules` table. Shadow mode runs both the legacy proc and the new service on every real pricing call, logs any divergence, and returns the legacy result until divergence is confirmed to be zero. Two known defects are corrected as part of this extraction: the hardcoded 15% fuel surcharge is moved to configuration, and the Government customer pricing fallback is made explicit and logged rather than silent. An Anti-Corruption Layer adapter ensures no legacy `DataTable` or SQL Server type leaks into the new service's domain model.

## Scope
- Stored procedure: `usp_CalculateOrderCost`
- Database table: `PricingRules` (migrated to PostgreSQL)
- Defects fixed: hardcoded fuel surcharge (moved to config), silent Government pricing fallback (made explicit with logging)
- Defects not fixed in this feature: all other known issues remain in the legacy monolith
- ACL adapter between legacy `CustomerType` codes and the new `PricingTier` enum
- ADR-002 required before implementation begins

## User Stories

| ID | Title |
|---|---|
| [US-101](us-101-adr-002-pricing-service.md) | ADR-002: Pricing Service Architecture Decision |
| [US-102](us-102-openapi-contract-pricing.md) | OpenAPI Contract for Pricing Endpoint |
| [US-103](us-103-service-scaffold.md) | Pricing Service Scaffold |
| [US-104](us-104-postgres-schema-pricing.md) | PostgreSQL Schema and Seed Migration |
| [US-105](us-105-pricing-logic-implementation.md) | Pricing Logic Implementation |
| [US-106](us-106-unit-tests-pricing.md) | Unit Tests for Pricing Logic |
| [US-107](us-107-shadow-mode.md) | Shadow Mode |
| [US-108](us-108-acl-adapter-pricing.md) | ACL Adapter for Customer Type |
| [US-109](us-109-cutover-pricing.md) | Cut-Over |
| [US-110](us-110-characterization-tests-still-green.md) | Characterization Tests Still Green After Cut-Over |

## Exit Criterion
Shadow mode has processed at least 500 real pricing calls with zero divergence logged; all callers of `usp_CalculateOrderCost` are routed through the new Pricing Service; the legacy proc is retained but deprecated; the full Phase 0 characterization test suite passes without modification in CI.
