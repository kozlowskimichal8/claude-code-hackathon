# US-102: OpenAPI Contract for Pricing Endpoint

## User Story
As a Developer, I want an OpenAPI contract for `POST /pricing/calculate` written before implementation so that any consumer can validate requests and responses against a machine-readable schema.

## Description
Contract-first design prevents the implementation from drifting and gives the shadow-mode adapter (US-107) and the ACL adapter (US-108) a stable interface to code against. The spec must be precise enough to generate client stubs and to run contract tests. All request and response fields must have types, constraints, and descriptions that match the domain model of the new service, not the legacy SQL column names.

## Acceptance Criteria
- [ ] OpenAPI 3.1 spec file is committed to `services/pricing/openapi.yaml`
- [ ] Request body schema includes: `customerId` (string), `customerType` (enum: Regular, Premium, Contract, Government), `weightKg` (number, positive), `estimatedMiles` (number, positive), `isHazmat` (boolean), `priority` (enum: Normal, High, Urgent), `discountPct` (number, 0–100 inclusive)
- [ ] Response schema includes: `baseCost` (number), `fuelSurcharge` (number), `hazmatFee` (number), `priorityMultiplier` (number), `discountAmount` (number), `totalCost` (number)
- [ ] All request and response fields have a `description` annotation
- [ ] The spec defines at least one example request and one example response
- [ ] The spec defines error response shapes for 400 (invalid input) and 500 (internal error)
- [ ] Running `spectral lint services/pricing/openapi.yaml` produces no errors
