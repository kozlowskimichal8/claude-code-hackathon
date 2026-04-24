# Feature 8: Anti-Corruption Layer & The Fence

## Goal

Prevent legacy data shapes and schema concepts from leaking into new domain service models by establishing a shared ACL library and a deterministic CI enforcement hook.

## Description

The ACL is the structural barrier that prevents legacy data shapes — DataTables, ordinal result sets, and type codes such as `R/P/C/G` — from leaking into new service domain models. Every new service consumes legacy data exclusively through the shared `Northwind.Acl` NuGet package, which provides DataTable-to-DTO translation, CustomerType code-to-enum mapping, and result-set ordinal abstraction. The Fence is a deterministic CI enforcement layer implemented as a `PreToolUse` hook in `.claude/settings.json`; it rejects any new-service code that imports from the legacy schema namespace or uses `System.Data.SqlClient` directly without going through the ACL library. Together, the ACL and the Fence ensure the boundary is enforced both at design time by the hook and by convention through CLAUDE.md preference guidance. The ACL library is introduced in Phase 1 and tightened with each subsequent extraction phase, so no domain service is ever authored without it in scope.

## Scope

- `src/Northwind.Acl/` — shared NuGet package with all translation utilities
- `.claude/settings.json` — `PreToolUse` hook configuration
- `decisions/ADR-009-acl-design.md` — documents what the hook enforces vs. what CLAUDE.md expresses as preference
- All 6 domain service directories (`services/pricing`, `services/reporting`, `services/customer`, `services/order`, `services/billing`, `services/dispatch-shipment`)
- Cross-cutting: applies from Phase 1 onwards across all extraction phases
- OpenAPI contract tests for every service boundary, run in CI alongside the characterization suite

## User Stories

| ID | Title |
|---|---|
| [US-801](us-801-acl-shared-library.md) | ACL shared NuGet library |
| [US-802](us-802-pretooluse-hook.md) | PreToolUse CI enforcement hook |
| [US-803](us-803-adr-009-acl-design.md) | ADR-009 — ACL design decision record |
| [US-804](us-804-contract-tests.md) | OpenAPI contract tests for service boundaries |

## Exit Criterion

All new domain services consume legacy data exclusively through the `Northwind.Acl` package with no duplicate translation code; the `PreToolUse` hook fires on boundary violations in CI and rejects the offending commit with an informative error message; ADR-009 is committed to `decisions/` with status Accepted; all 6 domain services have OpenAPI contract tests running in CI.
