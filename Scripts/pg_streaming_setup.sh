#!/bin/bash

# --- Configuration ---
PG_PRIMARY_HOST="192.168.1.10"
PG_STANDBY_HOST="192.168.1.20"
REPL_USER="replicator"
REPL_PASS="replica_pass"
PG_VERSION=15
PGDATA="/var/lib/pgsql/${PG_VERSION}/data"
ARCHIVE_DIR="/var/lib/pgsql/${PG_VERSION}/archive"

# --- Step 1: Setup replication user on PRIMARY ---
echo "Creating replication user on primary..."
psql -U postgres -c "CREATE ROLE $REPL_USER WITH REPLICATION LOGIN ENCRYPTED PASSWORD '$REPL_PASS';"

# --- Step 2: Configure primary's postgresql.conf ---
echo "Configuring primary postgresql.conf..."
cat >> "$PGDATA/postgresql.conf" <<EOF
wal_level = replica
archive_mode = on
archive_command = 'cp %p ${ARCHIVE_DIR}/%f'
max_wal_senders = 5
wal_keep_size = 128MB
hot_standby = on
EOF

# --- Step 3: Allow replication in pg_hba.conf ---
echo "Updating pg_hba.conf for replication..."
cat >> "$PGDATA/pg_hba.conf" <<EOF
host replication $REPL_USER $PG_STANDBY_HOST/32 md5
EOF

# --- Step 4: Restart primary ---
echo "Restarting primary PostgreSQL..."
systemctl restart postgresql-${PG_VERSION}

# --- Step 5: Stop standby if running ---
echo "Stopping standby PostgreSQL..."
ssh $PG_STANDBY_HOST "sudo systemctl stop postgresql-${PG_VERSION}"

# --- Step 6: Wipe and clone PGDATA from primary to standby ---
echo "Cloning base backup from primary to standby..."
ssh $PG_STANDBY_HOST "rm -rf $PGDATA"
ssh $PG_STANDBY_HOST "pg_basebackup -h $PG_PRIMARY_HOST -U $REPL_USER -D $PGDATA -Fp -Xs -P -R"

# --- Step 7: Start standby ---
echo "Starting standby PostgreSQL..."
ssh $PG_STANDBY_HOST "sudo systemctl start postgresql-${PG_VERSION}"

echo "Streaming replication setup complete!"
