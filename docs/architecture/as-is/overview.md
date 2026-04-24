# As-Is Architecture Overview — Northwind Logistics

## System Summary

Northwind Logistics is a freight dispatch and billing system built in 2009 and incrementally patched through 2021. It manages the full order lifecycle: customer orders → driver/vehicle assignment → shipment tracking → invoice generation and payment collection.

The system has never been redesigned. All meaningful business logic lives in SQL Server stored procedures. The web application is a thin shell that calls procs and renders results.

## Infrastructure

```
                        ┌─────────────────────────────┐
  Browser               │  IIS 7.5 (Classic pipeline)  │
  ──────────────────►   │  NWLWEB01  /  NWLWEB02       │
                        │  .NET 4.5 Web Forms           │
                        │  Session: InProc (per server) │
                        └──────────────┬───────────────┘
                                       │  SQL Server (ADO.NET)
                                       │  3 separate connection strings
                                       ▼
                        ┌─────────────────────────────┐
                        │  SQL Server 2008 R2          │
                        │  NWLSQL01 (physical box)     │
                        │  DB: NorthwindLogistics       │
                        │  ~40 stored procedures        │
                        │  4 triggers                   │
                        │  SQL Agent jobs (EOD, index)  │
                        └──────────────┬───────────────┘
                                       │
                        ┌──────────────▼───────────────┐
                        │  \\fileserver01\pod\          │
                        │  Proof-of-delivery images     │
                        │  (UNC path, no web access)    │
                        └─────────────────────────────┘
```

## Tech Stack

| Layer | Technology |
|---|---|
| Web framework | ASP.NET Web Forms, .NET Framework 4.5 |
| Host | IIS 7.5, Classic pipeline mode, two servers |
| Database | SQL Server 2008 R2 |
| Data access | ADO.NET (`SqlConnection` / `SqlCommand` / `SqlDataAdapter`) |
| Authentication | Forms auth (`Login.aspx`), session cookie |
| File storage | Windows file share (`\\fileserver01\pod\`) |
| Batch scheduling | SQL Server Agent |
| Email | SQL Server Database Mail (`NWLMailProfile`) |
| Deployment | xcopy from developer laptop. No CI/CD. |

## Key Structural Facts

- **Two web servers, broken session sharing.** Session is `InProc`. The load balancer uses sticky sessions, but they're unreliable. Users get logged out when routed to the other server. The fix (SQL Session State or Redis) has been open for three years.
- **Three copies of the connection string.** `web.config`, `Orders/NewOrder.aspx.cs`, and `Admin/EndOfDay.aspx.cs` each hardcode the database password. A password rotation requires three edits.
- **No CI/CD, no test suite.** Releases are manual xcopy deployments from a developer's machine.
- **No application-level logging.** Errors are swallowed (`catch { }`) or written to the user's screen. The `AuditLog` table in SQL Server is the only audit trail.
- **No monitoring.** Availability is discovered when users call.
