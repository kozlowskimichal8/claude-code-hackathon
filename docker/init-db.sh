#!/bin/bash
set -e

HOST="${DB_HOST:-sqlserver}"
USER="sa"
PASS="${SA_PASSWORD}"

# Locate sqlcmd (path differs between mssql-tools and mssql-tools18 packages)
if [ -f "/opt/mssql-tools/bin/sqlcmd" ]; then
    SQLCMD="/opt/mssql-tools/bin/sqlcmd"
elif [ -f "/opt/mssql-tools18/bin/sqlcmd" ]; then
    SQLCMD="/opt/mssql-tools18/bin/sqlcmd"
else
    echo "sqlcmd not found" >&2
    exit 1
fi

run_sql() {
    "$SQLCMD" -S "$HOST" -U "$USER" -P "$PASS" -b -C -i "$1"
    echo "  OK: $1"
}

echo "=== Northwind Logistics — database init ==="
run_sql /scripts/00_schema.sql
run_sql /scripts/01_seed_data.sql
run_sql /scripts/02_triggers.sql
run_sql /scripts/procs/01_customer_procs.sql
run_sql /scripts/procs/02_order_procs.sql
run_sql /scripts/procs/03_shipment_procs.sql
run_sql /scripts/procs/04_driver_procs.sql
run_sql /scripts/procs/05_billing_procs.sql
run_sql /scripts/procs/06_reporting_procs.sql
run_sql /scripts/procs/07_batch_procs.sql
echo "=== Database ready ==="
