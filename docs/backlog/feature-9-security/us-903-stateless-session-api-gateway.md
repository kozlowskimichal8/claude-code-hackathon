# US-903: Stateless JWT authentication at API gateway

## User Story

As a Security Engineer, I want stateless JWT authentication at the API gateway level so that the InProc session-state random-logout bug (caused by load balancer affinity) is eliminated before any new service goes live.

## Description

The legacy ASP.NET application uses InProc session state, which means session data lives in a single web server's memory. When a load balancer routes a request to a different server, the session is not found and the user is unexpectedly logged out. This is a known production problem. The fix for new services is to issue short-lived JWTs at login, validate them at the API gateway for every incoming request, and use a Redis-backed revocation list for refresh tokens — none of which requires server-side session affinity. The legacy WebForms pages retain their existing InProc session mechanism during the transition period, as changing them is out of scope until Phase 7. The stateless auth approach must be in place before any new service receives production traffic.

## Acceptance Criteria

- [ ] The API gateway issues a JWT on successful login; the JWT contains: `userId`, `email`, `roles`, and an expiry of 15 minutes from issue time
- [ ] A refresh token with a 24-hour expiry is issued alongside the JWT and stored in an HttpOnly cookie; it is not accessible to JavaScript
- [ ] All new domain service endpoints validate the JWT signature before processing any request; an invalid or expired JWT returns HTTP 401
- [ ] No new domain service uses InProc session state for any purpose
- [ ] A load test running 100 concurrent users across 2 simulated web server nodes over 10 minutes produces zero unexpected session invalidations (i.e. no 401 responses caused by session loss, only by genuinely expired tokens)
- [ ] Redis is used as the refresh token revocation list; a revoked refresh token cannot be used to obtain a new JWT
- [ ] Legacy ASP.NET WebForms pages retain their existing InProc session mechanism for the duration of the transition period; this is documented as a known temporary inconsistency
