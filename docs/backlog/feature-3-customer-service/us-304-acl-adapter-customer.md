# US-304: ACL adapter blocking `CurrentBalance` and mapping legacy type codes to enums

## User Story
As a Developer, I want an ACL adapter that blocks `CurrentBalance` from the Customer API and maps legacy type codes to enums so that no legacy data shapes leak into the Customer Service domain model.

## Description
The Anti-Corruption Layer (ACL) adapter is the translation boundary between the legacy SQL Server data model and the Customer Service domain model. Its two responsibilities are: stripping `CurrentBalance` from any data that enters the service from the legacy system (ensuring it can never appear in an API response even if a future query accidentally selects it), and mapping the single-character type codes (`R`, `P`, `C`, `G`) to the `CustomerType` enum used throughout the service. The adapter must also eliminate all `System.Data.DataTable` references, which are a fingerprint of the legacy `DBHelper.cs` data-access pattern and must not exist in the new service. Unit tests for all known type codes and the error path for unknown codes are mandatory to prevent silent failures when new customer types are introduced.

## Acceptance Criteria
- [ ] ACL adapter code committed to `services/customer/Acl/`
- [ ] `CurrentBalance` is never present in any Customer Service API response, even if the underlying query or data source accidentally includes the field — the adapter strips it before it reaches the serializer
- [ ] Type code `R` maps to `Regular`, `P` maps to `Premium`, `C` maps to `Contract`, `G` maps to `Government`
- [ ] An unknown type code (any character not in `R/P/C/G`) causes the adapter to throw a domain exception, not silently default to `Regular`
- [ ] No `System.Data.DataTable` or `System.Data.DataRow` references exist anywhere in the `services/customer/` project (verified by a grep check in CI)
- [ ] Adapter is unit-tested with test cases for all 4 known type codes, the unknown-code exception path, and the `CurrentBalance` strip behaviour
- [ ] Adapter is the single point where type code translation occurs; no other class in the service performs this mapping
- [ ] Adapter design is documented in a code comment referencing ADR-004 for the rationale
