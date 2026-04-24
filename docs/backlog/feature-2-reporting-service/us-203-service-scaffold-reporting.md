# US-203: .NET 8 Reporting Service scaffold with Docker and health endpoint

## User Story
As a Developer, I want a .NET 8 service scaffold for the Reporting Service with Docker support and a health endpoint so that the service can be deployed before business logic is added.

## Description
A deployable scaffold must exist before report endpoints are implemented so that infrastructure, CI pipeline integration, and Docker Compose wiring can be validated independently of business logic. The scaffold establishes the project layout, dependency injection configuration, and connection string conventions that all subsequent work in this feature will follow. Crucially, the scaffold must be configured with a read-only database connection from the start so that no developer can accidentally introduce a write path into the Reporting Service. The health endpoint provides a uniform liveness signal for load balancers and CI smoke tests.

## Acceptance Criteria
- [ ] .NET 8 Web API project created at `services/reporting/`
- [ ] `dotnet build` succeeds with zero warnings
- [ ] `GET /health` returns HTTP 200 with a JSON body indicating service status
- [ ] `Dockerfile` builds successfully and the resulting image starts and responds to `GET /health`
- [ ] Service added to `docker-compose.yml` with correct port mapping and dependency on the read-replica database container
- [ ] Database connection string is read from environment variables; no connection string is hardcoded in source files
- [ ] Connection is configured with a read-only PostgreSQL role; any attempt to execute an INSERT, UPDATE, or DELETE returns an error at the database level
- [ ] Project structure follows the same conventions established by the Pricing Service scaffold (Feature 1) for consistency
- [ ] Scaffold committed with a passing CI run before any report endpoint implementation begins
