# US-801: ACL shared NuGet library

## User Story

As a Developer, I want a shared NuGet package providing ACL utilities — DataTable-to-DTO translation, CustomerType code-to-enum mapping, and result-set ordinal abstraction — so that every new service has a consistent, tested way to consume legacy data shapes without copying boilerplate.

## Description

The legacy monolith returns data as `DataTable` objects with positional columns and single-character type codes. Each new domain service needs to translate these shapes into its own clean domain model without duplicating translation logic. The `Northwind.Acl` package provides three core utilities that cover all known translation patterns found in the 42 stored procedures. By centralising this code, a bug fix or a new `CustomerType` code value needs to be changed in one place and all services pick it up on the next package update. The package is published to the team's local NuGet feed so that any service can reference it as a standard dependency from day one.

## Acceptance Criteria

- [ ] NuGet package project exists at `src/Northwind.Acl/` and is published to the local package source
- [ ] `DataTableMapper<T>` maps column names to target DTO properties by name (case-insensitive); it does not use positional ordinals
- [ ] `CustomerTypeMapper` converts single-character codes `R`, `P`, `C`, `G` to the `CustomerType` enum values `Regular`, `Premium`, `Contract`, `Government` respectively
- [ ] `MultiResultSetReader` wraps an `IDataReader` and exposes each result set by a named key, not by numeric index
- [ ] Any unknown `CustomerType` code (e.g. `X`, empty string, null) throws `UnknownCustomerTypeException` with the offending code in the message; no silent fallback to a default value
- [ ] All public methods in the package have unit tests achieving 100% branch coverage
- [ ] Package version follows SemVer; a `CHANGELOG.md` inside `src/Northwind.Acl/` records every change
- [ ] All 6 domain service projects reference the `Northwind.Acl` package; no service contains its own DataTable-to-DTO translation code
