#!/bin/bash

# PostgreSQL Failover and Switchover Script with Checklist
# Ensure SSH access is configured and pg_ctl, repmgr or pg_autoctl is available.

# --- Configuration ---
PRIMARY_HOST="primary"
STANDBY_HOST="standby"
REPL_USER="replicator"
PGDATA="/var/lib/postgresql/15/main"
MONITOR_HOST="monitor"  # if using pg_auto_failover

# --- Checklist ---
echo "===== PostgreSQL Failover/Switchover Checklist ====="
echo "✔ Ensure WAL archiving is enabled"
echo "✔ Confirm replication is running"
echo "✔ Application is behind a proxy/load balancer"
echo "✔ Backup taken prior to switchover"
echo "✔ Monitor node is reachable (if using pg_auto_failover)"
echo ""

# --- Manual Switchover (using pg_ctl) ---
echo "Stopping writes to primary..."
ssh $PRIMARY_HOST "touch ${PGDATA}/stop_writes"

echo "Promoting standby..."
ssh $STANDBY_HOST "pg_ctl promote -D $PGDATA"

echo "Waiting for standby to become new primary..."
sleep 10

echo "Demoting old primary..."
ssh $PRIMARY_HOST "pg_ctl stop -D $PGDATA -m fast"

echo "Reconfiguring old primary as standby..."
ssh $PRIMARY_HOST "pg_basebackup -h $STANDBY_HOST -D $PGDATA -U $REPL_USER -Fp -Xs -P -R"

echo "Starting old primary as standby..."
ssh $PRIMARY_HOST "pg_ctl start -D $PGDATA"

echo "Switchover complete. Cluster is healthy."

# --- Optional: pg_auto_failover Commands ---
# ssh $PRIMARY_HOST "pg_autoctl perform switchover"
# ssh $MONITOR_HOST "pg_autoctl show state"
