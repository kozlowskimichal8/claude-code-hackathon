# Feature 3: Customer Service

## Goal
Extract all 5 Customer-domain stored procedures into a .NET 8 service backed by PostgreSQL, with a formally enforced ACL boundary that keeps `CurrentBalance` out of the Customer Service public API.

## Description
This phase migrates the Customer domain out of the SQL Server monolith and into a dedicated .NET 8 service with its own PostgreSQL database. The defining boundary decision for this feature is that `CurrentBalance` — a denormalized column on the `Customers` table that is actually a Billing concern — must not appear in the Customer Service public API or data model. This boundary is enforced deterministically by a `PreToolUse` CI hook, not merely by convention, so that future contributors cannot accidentally reintroduce the coupling. Two defects in the legacy procs are eliminated: the SQL injection vulnerability in `usp_SearchCustomers` via the unvalidated `@SortBy` parameter (NWL-389), and the cursor-based N+1 query pattern in `usp_GetCustomerOrders` which degrades under load. All four customer types (`R`, `P`, `C`, `G`) are formally modelled as an enum at the API boundary, replacing the silent fallback-to-Regular behaviour for Government customers that currently requires manual Finance intervention.

## Scope
**Stored procedures extracted:**
- `usp_GetCustomer` — customer lookup by ID
- `usp_SearchCustomers` — fixes SQL injection via `@SortBy` (NWL-389)
- `usp_CreateCustomer` — customer creation
- `usp_UpdateCustomer` — customer update (sparse fields)
- `usp_GetCustomerOrders` — fixes cursor-based N+1 query

**Defects fixed:**
- SQL injection via `@SortBy` in `usp_SearchCustomers` (NWL-389)
- Cursor-based N+1 in `usp_GetCustomerOrders` replaced with JOIN query
- Government customer type (`G`) silent fallback eliminated; explicit enum mapping enforced at API boundary

**ACL boundary enforced:**
- `CurrentBalance` absent from all Customer Service API responses
- Legacy type codes `R/P/C/G` mapped to `Regular/Premium/Contract/Government` enum; no `DataTable` references in service

**Components touched:**
- `Default.aspx` — customer widget routed to new service
- `Orders/NewOrder.aspx` — customer selector routed to new service
- New: `services/customer/` .NET 8 project with PostgreSQL
- New: `PreToolUse` hook in `.claude/settings.json` enforcing `CurrentBalance` boundary

## User Stories

| ID | Title |
|---|---|
| [US-301](us-301-adr-004-customer-service.md) | ADR-004: Customer Service data ownership and credit-limit boundary |
| [US-302](us-302-openapi-contract-customer.md) | OpenAPI contract for all Customer Service endpoints |
| [US-303](us-303-postgres-schema-customer.md) | Migrate `Customers` table to PostgreSQL without `CurrentBalance` |
| [US-304](us-304-acl-adapter-customer.md) | ACL adapter blocking `CurrentBalance` and mapping legacy type codes to enums |
| [US-305](us-305-implement-customer-endpoints.md) | Implement Customer Service endpoints with parameterized queries and sort-column whitelist |
| [US-306](us-306-pretooluse-hook-customer.md) | `PreToolUse` hook enforcing `CurrentBalance` ACL boundary in CI |
| [US-307](us-307-customer-data-migration.md) | Data migration strategy and runbook for SQL Server to PostgreSQL |
| [US-308](us-308-integration-tests-customer.md) | Integration tests asserting parity with Phase 0 characterization baselines |
| [US-309](us-309-cutover-customer.md) | Route customer lookups in `Default.aspx` and `Orders/NewOrder.aspx` to new service |

## Exit Criterion
All Customer CRUD and search operations are served exclusively by the new Customer Service; `CurrentBalance` does not appear in any Customer Service API response; the `PreToolUse` ACL hook is active in CI and rejects boundary violations deterministically; a feature toggle allows instant rollback; SQL Server activity monitor records zero calls to the 5 legacy customer procs during a 15-minute observation window; all Phase 0 characterization tests remain green.
