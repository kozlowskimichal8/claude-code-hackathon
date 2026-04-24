# Feature 9: Security

## Goal

Resolve all five cross-cutting security defects in the legacy monolith by fixing each one in the domain extraction phase that owns the affected code, with an interim fix for the Admin auth gap applied before any extraction begins.

## Description

Five security defects are present in the legacy monolith: SQL injection via unsanitised `@SortBy` in `usp_SearchCustomers` and `usp_SearchOrders`; no authentication check on `Admin/EndOfDay.aspx`; InProc session state causing random logouts under load balancing; non-idempotent `usp_CreateInvoice` allowing duplicate invoices; and a hardcoded 15% fuel surcharge that cannot be changed without a code deployment. None of these fixes are deferred to a separate security pass — they are designed into the new services from the outset, with each fix landing in the extraction phase that owns the relevant code. The Admin page auth gap receives an interim legacy fix in Phase 0 before any extraction work begins, because the page remains live throughout the entire migration. Stateless JWT authentication at the API gateway replaces InProc session state before any new service goes live, eliminating the load-balancer affinity problem at its root.

## Scope

- `lagacy/app/Admin/EndOfDay.aspx` and `EndOfDay.aspx.cs` — interim auth guard (Phase 0)
- Customer Service `GET /customers` and Order Service `GET /orders` — SQL injection elimination via sort-column whitelist (Phases 3 and 4)
- API gateway JWT configuration — stateless session replacement (cross-cutting, before Phase 1 go-live)
- Billing Service `POST /invoices` — idempotency key satisfying US-505 (Phase 5)
- Pricing Service `FuelSurchargePercent` configuration — satisfying US-105 (Phase 1)
- Cross-cutting: all five defects tracked here as security requirements even when delivery is owned by another feature

## User Stories

| ID | Title |
|---|---|
| [US-901](us-901-interim-admin-auth-guard.md) | Interim auth guard on Admin/EndOfDay.aspx |
| [US-902](us-902-sql-injection-fix-customer-order.md) | SQL injection fix in Customer and Order search |
| [US-903](us-903-stateless-session-api-gateway.md) | Stateless JWT authentication at API gateway |
| [US-904](us-904-duplicate-invoice-prevention.md) | Duplicate invoice prevention via idempotency key |
| [US-905](us-905-fuel-surcharge-from-config.md) | Fuel surcharge read from config, not hardcoded |

## Exit Criterion

All five defects resolved: no SQL injection vector exists in any new service; all mutation endpoints require a valid JWT; session state in new services is stateless; `POST /invoices` is idempotent; the hardcoded `0.15` fuel surcharge literal does not appear in the Pricing Service codebase; `Admin/EndOfDay.aspx` requires an `AdminRole` claim before Phase 1 extraction begins.
