# US-001: Docker Compose Environment

## User Story
As a Developer, I want a Docker Compose environment that spins up SQL Server 2019 and applies all legacy seed scripts so that any contributor can reproduce the full legacy stack locally in one command.

## Description
The legacy application targets SQL Server 2008 R2 but the characterization test suite needs a reproducible, containerised environment. SQL Server 2019 is chosen for container availability while remaining behaviourally compatible with the legacy schema and procs. The Compose file must apply all database scripts in strict numeric order and expose a health check so dependent services do not start against a partially initialised database. The environment must work for contributors on both macOS and Windows without manual configuration.

## Acceptance Criteria
- [ ] `docker compose up` starts SQL Server 2019 with no manual steps beyond cloning the repository
- [ ] Scripts are applied automatically in order: `00_schema.sql` → `01_seed_data.sql` → `02_triggers.sql` → `procs/01_*` through `procs/07_*`
- [ ] A health check endpoint or SQL probe confirms the database is ready before any dependent service or test runner starts
- [ ] `docker compose down -v` removes all volumes and leaves no residual state
- [ ] Environment starts successfully on a Windows host and a macOS host without any OS-specific edits to `docker-compose.yml`
