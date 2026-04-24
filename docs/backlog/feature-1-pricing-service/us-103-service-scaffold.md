# US-103: Pricing Service Scaffold

## User Story
As a Developer, I want a .NET 8 minimal API scaffold for the Pricing Service with Docker support and a health endpoint so that the service can be deployed and verified before any business logic is added.

## Description
The scaffold establishes the project layout, build pipeline, and container configuration that all subsequent implementation stories will build on. It must be deployable and verifiable in isolation — no legacy SQL Server connection is required at startup. The health endpoint provides a liveness probe for the Docker Compose environment and future Kubernetes deployments. The project must build cleanly with no warnings to enforce code quality from the start.

## Acceptance Criteria
- [ ] Project is located at `services/pricing/` with a standard .NET 8 minimal API project structure
- [ ] `dotnet build` completes with exit code 0 and zero warnings
- [ ] `GET /health` returns HTTP 200 with body `{"status":"healthy"}`
- [ ] A `Dockerfile` at `services/pricing/Dockerfile` builds the image with `docker build` and runs with `docker run`; the health endpoint is reachable in the running container
- [ ] The service is added to the root `docker-compose.yml` with the health endpoint configured as a health check
- [ ] The service starts successfully with no SQL Server or legacy database connection present
- [ ] No references to `System.Data.SqlClient` or any SQL Server-specific library exist in the scaffold
