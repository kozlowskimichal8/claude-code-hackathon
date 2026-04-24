# US-003: Connection String Consolidation

## User Story
As a Developer, I want the database connection string defined in exactly one place so that environment-specific configuration changes do not require editing multiple files.

## Description
The legacy codebase has the SQL Server connection string hardcoded in three separate files: `web.config`, `Orders/NewOrder.aspx.cs`, and `Admin/EndOfDay.aspx.cs`. This is a known critical issue (documented in `known-issues.md`) that must be resolved before characterization tests are written, because the test harness needs to inject a single connection string pointing at the Docker Compose SQL Server instance. The fix is purely mechanical — no business logic changes — and must not alter any observable behaviour.

## Acceptance Criteria
- [ ] `web.config` is the single source of truth for the database connection string under `<connectionStrings>`
- [ ] The hardcoded connection string is removed from `Orders/NewOrder.aspx.cs`; the page reads from `ConfigurationManager.ConnectionStrings["NorthwindLogistics"]` (or equivalent named key)
- [ ] The hardcoded connection string is removed from `Admin/EndOfDay.aspx.cs`; the page reads from the same `ConfigurationManager.ConnectionStrings` key
- [ ] `App_Code/DBHelper.cs` also reads from `ConfigurationManager.ConnectionStrings` if it contains any hardcoded string
- [ ] All existing page functionality (order creation, EOD batch trigger) continues to work after the change
- [ ] All characterization tests that were passing before this change continue to pass after it
