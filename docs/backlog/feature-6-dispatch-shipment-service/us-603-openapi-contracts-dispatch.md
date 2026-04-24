# US-603: OpenAPI contracts for Dispatch/Shipment Service

## User Story

As a Developer, I want OpenAPI contracts for all Dispatch/Shipment Service endpoints written before implementation so that consumers have machine-readable schemas.

## Description

Contract-first development ensures that the Order Service and any other consumers can be coded against a stable API shape before the Dispatch/Shipment Service implementation is complete. The OpenAPI specification must be committed to the repository and pass linting before any endpoint code is written. The spec also documents the driver licence-expiry warning header so that consumers know what to expect when a driver is close to expiry.

## Acceptance Criteria

- [ ] OpenAPI specification committed at `services/dispatch/openapi.yaml`
- [ ] Spec includes `POST /drivers` — create a new driver record
- [ ] Spec includes `GET /drivers` — list available drivers (excludes `Terminated` and `LOA` status drivers)
- [ ] Spec includes `PUT /drivers/{id}/status` — update driver status
- [ ] Spec includes `POST /orders/{id}/assign` — assign a driver to an order
- [ ] Spec includes `PUT /drivers/{id}/location` — update driver GPS location
- [ ] Spec includes `GET /drivers/{id}/schedule` — retrieve driver schedule
- [ ] Spec includes `GET /drivers/{id}/performance` — retrieve driver performance metrics
- [ ] Spec includes `POST /shipments` — create a new shipment
- [ ] Spec includes `PUT /shipments/{id}/status` — update shipment status
- [ ] Spec includes `GET /shipments/{id}/tracking` — retrieve shipment tracking information
- [ ] Spec includes `POST /shipments/{id}/complete` — mark a shipment as complete with POD
- [ ] Spec includes `POST /shipments/{id}/fail` — mark a shipment as failed with failure reason
- [ ] Spec includes `GET /shipments/active` — list all active shipments for the dispatch board
- [ ] The `POST /orders/{id}/assign` endpoint documents the `422` response for expired driver licence and the `200` response with `X-Licence-Warning` header for a driver expiring within 30 days
- [ ] `spectral lint services/dispatch/openapi.yaml` exits with zero errors
