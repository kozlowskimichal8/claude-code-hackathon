# Feature 2: Reporting Service

## Goal
Extract all 5 reporting stored procedures into a read-only .NET 8 service backed by a read replica or event projection.

## Description
This phase lifts the 5 reporting stored procedures out of the SQL Server monolith and into a standalone .NET 8 service that reads from a dedicated read replica or event-projected database. Because the service performs no state mutations it can be deployed and exercised in parallel with the monolith before any cut-over occurs, making this the lowest-risk extraction in the strangler-fig sequence. Two critical defects are eliminated in the process: the `##global` temp table race condition in the daily shipment report (NWL-concurrent-dispatch) and the unvalidated `@GroupBy` dynamic SQL injection vector in the revenue report. The service exposes five REST endpoints whose response shapes are locked to the Phase 0 characterization baselines, giving the QA team a deterministic regression gate. Once all five legacy reporting procs are confirmed idle the monolith call-sites are deprecated but not deleted, preserving a rollback path.

## Scope
**Stored procedures extracted:**
- `usp_GetDailyShipmentReport` — fixes `##global` temp table race condition
- `usp_GetDriverPerformanceReport`
- `usp_GetRevenueReport` — fixes unvalidated `@GroupBy` dynamic SQL injection
- `usp_GetCustomerActivityReport`
- `usp_GetDelayedShipmentsReport`

**Defects fixed:**
- `##global` temp table collision under concurrent dispatchers (NWL-concurrent-dispatch)
- Unvalidated `@GroupBy` / `@SortBy` dynamic SQL in revenue report

**Components touched:**
- `Default.aspx` — dashboard metrics routed to new service
- `Admin/EndOfDay.aspx` — report section routed to new service
- New: `services/reporting/` .NET 8 project
- New: read replica / projected read database in Docker Compose

## User Stories

| ID | Title |
|---|---|
| [US-201](us-201-adr-003-reporting-service.md) | ADR-003: Reporting Service read-model strategy |
| [US-202](us-202-openapi-contracts-reporting.md) | OpenAPI contracts for all 5 report endpoints |
| [US-203](us-203-service-scaffold-reporting.md) | .NET 8 Reporting Service scaffold with Docker and health endpoint |
| [US-204](us-204-read-replica-setup.md) | Read replica / event projection database for reporting |
| [US-205](us-205-implement-report-endpoints.md) | Implement all 5 report endpoints with parameterized queries and column whitelists |
| [US-206](us-206-fix-global-temp-table.md) | Replace `##global` temp table with per-request CTE in daily shipment report |
| [US-207](us-207-integration-tests-reporting.md) | Integration tests asserting result shape parity with legacy procs |
| [US-208](us-208-cutover-reporting.md) | Route Admin and Dashboard reporting calls to new Reporting Service |

## Exit Criterion
All 5 report endpoints are served exclusively by the new Reporting Service; response shapes match the Phase 0 characterization baselines for every report; a 30-second load test of 10 concurrent clients against `GET /reports/daily-shipments` produces zero errors and zero incorrect result counts; SQL Server activity monitor records zero calls to the 5 legacy reporting procs during a 15-minute observation window; all Phase 0 characterization tests remain green.
