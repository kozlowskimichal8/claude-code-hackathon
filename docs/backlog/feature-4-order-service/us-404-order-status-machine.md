# US-404: Order Status Machine

## User Story
As a Developer, I want the order status transitions implemented as explicit per-transition handlers so that invalid transitions are rejected at the domain layer and the god-proc pattern is eliminated.

## Description
The 280-line `usp_UpdateOrderStatus` stored procedure encodes all transition logic as a single switch statement, making it difficult to reason about, test, or extend. The replacement must model each transition as a separate handler class or method so that each transition can be independently tested and the set of valid transitions is self-documenting. The `SpecialInstructions` append-on-transition behaviour observed in Phase 0 characterization tests must be preserved exactly. Any attempt to drive an order into a state that is not reachable from its current state must be rejected before any database write occurs.

## Acceptance Criteria
- [ ] Valid transitions implemented and enforced: `Pending→Assigned`, `Assigned→PickedUp`, `PickedUp→InTransit`, `InTransit→Delivered`, `InTransit→Failed`, `Pending→Cancelled`, `any→OnHold`
- [ ] Attempting any transition not in the valid list returns HTTP 422 with a descriptive error message identifying both the current status and the attempted target status
- [ ] `SpecialInstructions` append-on-transition behaviour is preserved as per Phase 0 US-004 constraint 3 (instructions are appended, not overwritten, on each transition)
- [ ] Each transition is implemented as a separate class or method; there is no single switch statement or if-else chain covering all transitions
- [ ] All transition handlers are covered by unit tests that verify: valid transition succeeds, invalid transition is rejected with 422, `SpecialInstructions` append behaviour
- [ ] `OnHold` transition is valid from any status and is covered by tests from at least three source states
- [ ] Status machine is enforced in the domain layer before any database write; invalid transitions do not produce partial writes
