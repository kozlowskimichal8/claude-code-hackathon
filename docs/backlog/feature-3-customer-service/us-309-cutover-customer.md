# US-309: Route customer lookups in `Default.aspx` and `Orders/NewOrder.aspx` to new service

## User Story
As a Platform Engineer, I want to route all customer lookups in `Default.aspx` and `Orders/NewOrder.aspx` to the new Customer Service so that legacy customer procs are no longer in the hot path.

## Description
With the Customer Service fully tested and verified against Phase 0 baselines, the two primary call-sites in the legacy ASP.NET application can be switched to the new service. `Default.aspx` loads customer summary data on the dashboard on every page request, and `Orders/NewOrder.aspx` uses customer lookup and search when creating a new order. Both pages must use the Customer Service endpoints after cut-over. A feature toggle must be in place before the switch so that operations can perform an instant rollback without a deployment. The legacy procs are retained in a deprecated state to preserve the rollback path; they are not deleted until the feature is formally closed and the rollback window has passed.

## Acceptance Criteria
- [ ] `Default.aspx` customer widget data is fetched from the Customer Service (`GET /customers/{id}` or equivalent), not from `usp_GetCustomer` or `usp_SearchCustomers`
- [ ] `Orders/NewOrder.aspx` customer selector (search and lookup) calls Customer Service endpoints, not legacy customer procs
- [ ] A feature toggle (environment variable or config flag) enables instant rollback to the legacy proc calls without a code deployment
- [ ] Legacy customer stored procs (`usp_GetCustomer`, `usp_SearchCustomers`, `usp_CreateCustomer`, `usp_UpdateCustomer`, `usp_GetCustomerOrders`) are retained in the database but annotated with `-- DEPRECATED: use Customer Service` comments
- [ ] Cut-over verified by observing SQL Server activity monitor for a 15-minute window and confirming zero calls to all 5 legacy customer procs
- [ ] All Phase 0 characterization tests remain green after cut-over
- [ ] `CurrentBalance` is confirmed absent from all API responses consumed by `Default.aspx` and `Orders/NewOrder.aspx` during the post-cut-over observation window
- [ ] Cut-over runbook committed to `services/customer/docs/cutover-runbook.md` covering: pre-flight checks, toggle switch procedure, observation period, success criteria, and rollback procedure
- [ ] HTTP error rate and page load time for `Default.aspx` and `Orders/NewOrder.aspx` monitored for 24 hours post-switch with no degradation versus the pre-cut-over baseline
