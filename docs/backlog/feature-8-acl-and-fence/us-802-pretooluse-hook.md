# US-802: PreToolUse CI enforcement hook

## User Story

As a Developer, I want a `PreToolUse` hook configured in `.claude/settings.json` that rejects any new-service code importing from the legacy SQL Server schema namespace so that the ACL boundary is enforced deterministically by the CI tooling rather than by code review alone.

## Description

Code review is not a reliable mechanism for preventing legacy data shapes from leaking into new services — reviewers miss things, especially under time pressure. A `PreToolUse` hook inspects every file being written or edited under `services/` and fails the operation if it detects a direct reference to the legacy SQL Server connection string name, the legacy schema name in the legacy SQL Server database context, or `System.Data.SqlClient` used without the ACL library as an intermediary. The hook runs in under 2 seconds per file so it does not materially slow down development. The ACL library itself (`src/Northwind.Acl/`) is explicitly excluded from the hook because it is the one place that is permitted to reference legacy types by design.

## Acceptance Criteria

- [ ] Hook configuration is committed to `.claude/settings.json` under the `PreToolUse` key
- [ ] The hook rejects any file under `services/` that contains a direct reference to the legacy SQL Server connection string name (e.g. `NorthwindConnection` as a raw string literal outside the ACL library)
- [ ] The hook rejects any file under `services/` that references the legacy schema name (`dbo`) in the context of the legacy SQL Server database without going through the ACL library
- [ ] The hook rejects any file under `services/` that imports `System.Data.SqlClient` directly without the `Northwind.Acl` package mediating the call
- [ ] A test commit that intentionally introduces a violation is rejected by the hook with an error message that identifies the offending pattern and the file path
- [ ] The hook does not fire on any file under `src/Northwind.Acl/` — the ACL library is in the allowlist
- [ ] The hook fires correctly for all 6 domain service directories: `services/pricing`, `services/reporting`, `services/customer`, `services/order`, `services/billing`, `services/dispatch-shipment`
- [ ] Hook execution time is under 2 seconds per file, measured on a standard CI runner
