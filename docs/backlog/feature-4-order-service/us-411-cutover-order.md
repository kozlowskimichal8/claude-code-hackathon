# US-411: Order Service Cut-Over

## User Story
As a Platform Engineer, I want to route `Orders/NewOrder.aspx` and `Orders/OrderList.aspx` to the new Order Service so that legacy order stored procedures are no longer in the hot path.

## Description
Cut-over is the point at which live traffic shifts from the legacy SQL Server stored procedures to the new Order Service. The strangler-fig proxy must be configured to route new order creation and order search/detail requests to the new service while the legacy procs are retained (but marked deprecated) as a rollback safety net. A feature flag must allow instant rollback without a deployment. The cut-over is only declared complete when a 15-minute production monitoring window confirms zero calls to the retired procs, and the full Phase 0 characterization test suite remains green throughout.

## Acceptance Criteria
- [ ] Strangler-fig proxy routes `Orders/NewOrder.aspx` POST traffic to the new Order Service `POST /orders` endpoint
- [ ] Strangler-fig proxy routes `Orders/OrderList.aspx` GET traffic to the new Order Service `GET /orders` endpoint
- [ ] Order detail lookups are served by `GET /orders/{id}` on the new service
- [ ] Legacy order stored procedures (`usp_CreateOrder`, `usp_GetOrder`, `usp_UpdateOrderStatus`, `usp_AssignOrderToDriver`, `usp_GetPendingOrders`, `usp_SearchOrders`, `usp_GetOrdersByCustomer`, `usp_CancelOrder`) are retained in SQL Server but marked with a deprecation comment
- [ ] A feature flag is in place that routes traffic back to the legacy procs instantly without a redeployment
- [ ] Cut-over is verified by monitoring the SQL Server activity monitor for 15 minutes and confirming zero calls to `usp_CreateOrder`, `usp_GetOrder`, and `usp_UpdateOrderStatus`
- [ ] All Phase 0 characterization tests are green at the end of the 15-minute monitoring window
- [ ] Rollback procedure is documented: how to flip the feature flag back and confirm legacy procs are serving traffic again
