# US-803: ADR-009 — ACL design decision record

## User Story

As a Business Analyst, I want ADR-009 written and accepted that documents what the `PreToolUse` hook enforces vs. what the CLAUDE.md prompt expresses as preference so that the distinction between deterministic enforcement and guidance is explicit and understood by the whole team.

## Description

The ACL strategy uses two complementary mechanisms: a deterministic hook that blocks boundary violations and a CLAUDE.md preference that guides extraction order and naming conventions. Without a written decision record, future team members cannot tell which behaviours are enforced by tooling and which are merely encouraged. ADR-009 captures the rationale for this split, documents the specific patterns the hook blocks, records the rejected alternative of relying on CLAUDE.md prompts alone, and lists the consequences of the approach. It must be committed and accepted before the ACL library or hook is implemented, in line with the project's "no ADR = no implementation" rule.

## Acceptance Criteria

- [ ] ADR-009 is committed to `decisions/ADR-009-acl-design.md` with status `Accepted`
- [ ] ADR covers what the `PreToolUse` hook blocks: imports from the legacy namespace, direct SQL Server connection strings in service code, and `System.Data.SqlClient` usage outside the ACL library
- [ ] ADR covers what the CLAUDE.md preference states: "prefer the new service for X domain" guidance and extraction order recommendations
- [ ] ADR explains why safety-critical boundary violations are enforced by the hook (they must never slip; code review is insufficient) and why style preferences and extraction order are expressed as prompts (they are guidance, not hard constraints)
- [ ] ADR documents the rejected alternative: relying solely on CLAUDE.md prompts for boundary enforcement, with an explanation of why this was rejected
- [ ] ADR follows the structure established by ADR-001: context, decision, implementation sequence, consequences (positive and negative), risks, and an explicit "what we chose not to do" section
- [ ] ADR is committed before either US-801 (ACL library) or US-802 (hook) implementation begins
