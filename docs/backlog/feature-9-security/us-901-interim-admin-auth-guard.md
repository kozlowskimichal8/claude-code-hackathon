# US-901: Interim auth guard on Admin/EndOfDay.aspx

## User Story

As a Security Engineer, I want an interim role check added to `Admin/EndOfDay.aspx` in the legacy app so that the admin page is not accessible to unauthenticated users while Phase 7 (batch retirement) is in progress.

## Description

`Admin/EndOfDay.aspx` has no authentication or authorisation check — any user who knows the URL can trigger the end-of-day batch process or rebuild database indexes (NWL-441). This is the highest-risk open defect in the legacy system because the EOD batch has no recovery mechanism: a partial failure leaves data inconsistent. This interim fix adds a role check in the code-behind before any Phase 1 extraction work begins, closing the unauthenticated access window immediately. The fix is intentionally minimal — it does not redesign the page or the batch mechanism — because Phase 7 will retire the page entirely. The characterization test that documents the auth gap is updated to assert the new protective behaviour rather than the old unprotected behaviour.

## Acceptance Criteria

- [ ] `Admin/EndOfDay.aspx.cs` code-behind checks for an authenticated session and a specific role claim (e.g. `AdminRole`) at the top of the page load handler, before any other processing
- [ ] Unauthenticated requests to `Admin/EndOfDay.aspx` are redirected to the login page (HTTP 302)
- [ ] Authenticated requests from users without the `AdminRole` claim receive a 403 Forbidden response
- [ ] The check is in place before any Phase 1 extraction work starts; it is committed as a standalone Phase 0 change
- [ ] The Phase 0 characterization test for the auth gap (constraint 9) is updated to document the defect as fixed and to assert the new 403 behaviour for non-admin authenticated users
- [ ] The legacy characterization test for the overall shape and functionality of the EOD page still passes for an authenticated admin user — the page's functional behaviour is otherwise unchanged
