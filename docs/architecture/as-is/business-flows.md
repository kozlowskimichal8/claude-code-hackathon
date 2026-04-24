# As-Is Business Flows — Northwind Logistics

## Order Lifecycle

```
  Customer calls / emails
          │
          ▼
    [NewOrder.aspx]
    usp_CreateOrder
    ├── Credit check (waived for Contract/Govt)
    ├── INSERT Orders (Status='Pending')
    └── usp_CalculateOrderCost  ← separate call, not in same transaction
                                   Order can exist with TotalCost=NULL if this fails

          │ Status: Pending
          ▼
    Dispatch assigns driver manually
    usp_AssignOrderToDriver
    ├── Validate Order=Pending, Driver=Available, Vehicle=Available
    ├── INSERT Shipments (Status='Assigned')
    ├── UPDATE Drivers.Status = 'OnRoute'
    ├── UPDATE Vehicles.Status = 'InUse'
    └── usp_UpdateOrderStatus → 'Assigned'
         └── TR_Orders_AuditStatusChange fires

          │ Status: Assigned
          ▼
    Driver confirms pickup (dispatch updates)
    usp_UpdateOrderStatus → 'PickedUp'
    └── UPDATE Shipments.Status = 'PickedUp'
         └── TR_Shipments_AutoUpdateOrderStatus fires (mirrors back to Order)

          │ Status: PickedUp
          ▼
    usp_UpdateOrderStatus → 'InTransit'

          │ Status: InTransit
          ▼
    ┌─── Delivered ──────────────────────────────────────────────────┐
    │    usp_UpdateOrderStatus → 'Delivered'                        │
    │    ├── UPDATE Orders.ShippedDate                              │
    │    ├── usp_CreateInvoice (if no invoice exists)               │
    │    │    └── TR_Invoices_UpdateBalance → Customers.Balance     │
    │    ├── Release Driver → 'Available'                           │
    │    └── Release Vehicle → 'Available'                          │
    └────────────────────────────────────────────────────────────────┘
    ┌─── Failed ─────────────────────────────────────────────────────┐
    │    usp_FailShipment / usp_UpdateOrderStatus → 'Failed'        │
    │    ├── Shipment.FailureReason recorded                        │
    │    ├── Release Driver and Vehicle                             │
    │    └── Order can be re-queued → 'Pending'                     │
    └────────────────────────────────────────────────────────────────┘
```

## Pricing Calculation

Performed by `usp_CalculateOrderCost`. Called on order creation and during EOD batch.

```
Base cost  = PricingRules.BaseRate (by CustomerType + weight tier)
Miles cost = EstimatedMiles × PricingRules.PerMileRate
Fuel       = (Base + Miles) × 0.15   ← hardcoded, not in PricingRules
Hazmat     = +$50 flat               ← hardcoded
Priority H = +10%                    ← hardcoded
Priority U = +25%                    ← hardcoded
Discount   = −(subtotal × DiscountPct)
─────────────────────────────────────
TotalCost  = all of the above

Government customers: no pricing row exists, silently falls through to Regular ('R') rates.
Default miles if not provided: 50.
```

## Nightly EOD Batch

Runs at 23:30 via SQL Server Agent (`usp_ProcessEndOfDay`). Runtime ~8 minutes.

```
Step 1 — Auto-billing
  For each Delivered, unbilled order in the last 7 days:
    usp_CreateInvoice → creates invoice
    UPDATE Orders.IsBilled = 1

Step 2 — Mark overdue invoices
  UPDATE Invoices SET Status='Overdue'
  WHERE DueDate < today AND Status IN ('Draft','Sent')

Step 3 — Stale order detection
  Flag Pending orders older than 48h in AuditLog

Step 4 — Send summary email via DB Mail (NWLMailProfile)

Step 5 — Archive flag
  Mark old delivered orders for archival (actual copy handled separately)

Step 6 — Stats update
  UPDATE Drivers.TotalMilesDriven from completed Shipments
```

**No transaction spans all steps.** Partial failure leaves data inconsistent. No idempotency checks within steps (only a guard at the top against re-running the same date). The 2022 failure went undetected for three days.

## Billing and Payment

```
usp_CreateInvoice
├── Calculate SubTotal, Tax, Discount from order
├── INSERT Invoices (Status='Draft')
└── TR_Invoices_UpdateBalance fires → Customers.CurrentBalance recalculated

Finance manually sends invoice (no automated send from app)
  ↓
Payment received
INSERT Payments
UPDATE Invoices.PaidAmount, Status
TR_Invoices_UpdateBalance fires again
```

Monthly statement generation: `usp_GetMonthlyStatement` — cursor-based, takes 45 seconds for large customers.

## Credit Check

Run at order creation in `usp_CreateOrder`:

- Skip for `CustomerType IN ('C', 'G')` (Contract, Government)
- Rough estimate: `weight × 0.50 + miles × 0.75`
- If `CurrentBalance + estimate > CreditLimit` → reject with error
- `CurrentBalance` is the trigger-maintained denormalised value on `Customers`
