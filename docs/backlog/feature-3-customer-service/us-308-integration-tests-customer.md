# US-308: Integration tests asserting parity with Phase 0 characterization baselines

## User Story
As a QA Engineer, I want integration tests for all Customer Service endpoints that assert parity with the Phase 0 characterization baselines so that the service is a verifiable drop-in replacement.

## Description
The Phase 0 characterization tests recorded the exact behaviour of the 5 legacy customer stored procedures against a known seed dataset. The Customer Service integration tests must verify that every endpoint reproduces that behaviour: same data shapes, same search results, same order lists, same error responses for invalid inputs. Tests run inside Docker Compose so that the PostgreSQL database, seed data, and service are all provisioned identically on every CI run. The credit-limit enforcement behaviour — Regular and Premium customers blocked when over limit, Contract and Government customers exempt — must be explicitly tested because this logic is business-critical and was previously buried in multiple stored procedures. `CurrentBalance` must not appear in any test assertion, confirming the boundary is upheld end-to-end.

## Acceptance Criteria
- [ ] Integration tests run against a Docker Compose environment with a deterministic seeded test dataset that mirrors the Phase 0 characterization seed data
- [ ] `POST /customers` tested with: valid inputs for all 4 customer types, missing required fields (expect 400 with field errors), invalid `customerType` value (expect 400 — no silent default), duplicate customer identifier if applicable (expect 409)
- [ ] `PUT /customers/{id}` tested with sparse updates (only some fields provided) confirming unspecified fields are not zeroed out
- [ ] `GET /customers` search tested with all filter combinations (`name`, `type`, `active`) and all whitelisted `sortBy` values; an invalid `sortBy` value returns 400
- [ ] `GET /customers/{id}/orders` tested with a customer that has multiple orders, confirming correct row count and correct pagination behaviour
- [ ] Credit-limit behaviour tested: Regular and Premium customers with balance at/over limit are blocked as per business rules; Contract and Government customers are not blocked
- [ ] No test assertion references `CurrentBalance` — the test confirms its absence from responses
- [ ] Tests run automatically in CI on every commit to any file under `services/customer/`
- [ ] All Phase 0 customer characterization tests (against the legacy system) continue to pass unchanged after these tests are added
