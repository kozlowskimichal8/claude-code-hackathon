# US-306: `PreToolUse` hook enforcing `CurrentBalance` ACL boundary in CI

## User Story
As a Developer, I want a `PreToolUse` hook configured in CI that rejects any Customer Service code importing `CurrentBalance` from the legacy schema namespace so that the ACL boundary is enforced deterministically rather than by convention.

## Description
Relying on code review to catch `CurrentBalance` leakage into the Customer Service is insufficient: reviewers are human and the risk of the boundary eroding over time is real. A `PreToolUse` hook configured in `.claude/settings.json` provides a deterministic, automated enforcement mechanism that fires before any code modification is applied. When the hook detects a reference to `CurrentBalance` or the legacy schema namespace in a file under `services/customer/`, it blocks the tool use and surfaces an actionable error message. The distinction between this hook (hard enforcement) and the `CLAUDE.md` prompt (preference expression) must be documented in an ADR so that future contributors understand why both mechanisms exist and when each is appropriate.

## Acceptance Criteria
- [ ] Hook configuration committed to `.claude/settings.json` as a `PreToolUse` hook
- [ ] Hook pattern matches any file path under `services/customer/` that contains a reference to `CurrentBalance` or to the legacy SQL Server schema namespace (e.g. `NorthwindLegacy`, `DBHelper`, `System.Data.DataTable`)
- [ ] A test commit that intentionally introduces `CurrentBalance` into a file under `services/customer/` is blocked by the hook in CI — the CI run fails with a clear error message identifying the violation
- [ ] The hook does not fire on files outside `services/customer/` (no false positives on legacy app files, other services, or test fixtures that reference legacy schemas for comparison purposes)
- [ ] ADR-009 is committed to `decisions/ADR-009-acl-boundary-enforcement.md` documenting the distinction between the `PreToolUse` hook (deterministic hard block) and the `CLAUDE.md` preference prompt (soft guidance), with rationale for using both
- [ ] Hook error message is human-readable and explains what violation was detected, which file caused it, and what action the developer should take
- [ ] Hook behaviour is documented in `services/customer/README.md` or equivalent so that developers setting up the project locally understand why certain changes are blocked
