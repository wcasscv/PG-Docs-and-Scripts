#!/bin/bash

# PostgreSQL Auto Failover Setup Script
# This script assumes Debian/Ubuntu and default PostgreSQL paths

# --- Config ---
PG_VERSION=15
REPL_USER="replicator"
REPL_PASS="replica_pass"
MONITOR_HOST="monitor"
PRIMARY_HOST="primary"
SECONDARY_HOST="secondary"
DATA_DIR="/var/lib/postgresql"

# --- Install pg_auto_failover ---
echo "Installing pg_auto_failover..."
sudo apt-get update
sudo apt-get install -y pg-auto-failover

# --- Setup Monitor ---
echo "Setting up monitor node..."
ssh $MONITOR_HOST "pg_autoctl create monitor --pgdata ${DATA_DIR}/monitor"

# --- Setup Primary ---
echo "Setting up primary node..."
ssh $PRIMARY_HOST \
"pg_autoctl create postgres --pgdata ${DATA_DIR}/primary --monitor postgres://autoctl_node@${MONITOR_HOST}/pg_auto_failover"

# --- Setup Secondary ---
echo "Setting up secondary node..."
ssh $SECONDARY_HOST \
"pg_autoctl create postgres --pgdata ${DATA_DIR}/secondary --monitor postgres://autoctl_node@${MONITOR_HOST}/pg_auto_failover"

# --- Show Cluster State ---
echo "Displaying cluster state..."
ssh $MONITOR_HOST "pg_autoctl show state"

echo "✅ PostgreSQL Auto Failover setup complete!"
