#!/bin/bash

# --- Configuration ---
PG_PRIMARY_HOST="192.168.1.10"
PG_SUBSCRIBER_HOST="192.168.1.30"
REPL_USER="replicator"
REPL_PASS="replica_pass"
PG_VERSION=15
PUBLICATION_NAME="my_pub"
SUBSCRIPTION_NAME="my_sub"
DATABASE_NAME="mydb"

# --- Step 1: Create replication user on PRIMARY ---
echo "Creating replication user on primary..."
psql -h $PG_PRIMARY_HOST -U postgres -d $DATABASE_NAME -c "CREATE ROLE $REPL_USER WITH LOGIN REPLICATION PASSWORD '$REPL_PASS';"

# --- Step 2: Enable logical replication on PRIMARY ---
echo "Configuring primary for logical replication..."
ssh $PG_PRIMARY_HOST "echo 'wal_level = logical' | sudo tee -a /var/lib/pgsql/${PG_VERSION}/data/postgresql.conf"
ssh $PG_PRIMARY_HOST "echo 'host replication $REPL_USER $PG_SUBSCRIBER_HOST/32 md5' | sudo tee -a /var/lib/pgsql/${PG_VERSION}/data/pg_hba.conf"
ssh $PG_PRIMARY_HOST "sudo systemctl restart postgresql-${PG_VERSION}"

# --- Step 3: Create publication on PRIMARY ---
echo "Creating publication on primary..."
psql -h $PG_PRIMARY_HOST -U postgres -d $DATABASE_NAME -c "CREATE PUBLICATION $PUBLICATION_NAME FOR ALL TABLES;"

# --- Step 4: Create subscription on SUBSCRIBER ---
echo "Creating subscription on subscriber..."
psql -h $PG_SUBSCRIBER_HOST -U postgres -d $DATABASE_NAME -c \
"CREATE SUBSCRIPTION $SUBSCRIPTION_NAME CONNECTION 'host=$PG_PRIMARY_HOST dbname=$DATABASE_NAME user=$REPL_USER password=$REPL_PASS' PUBLICATION $PUBLICATION_NAME;"

echo "✅ Logical replication setup complete!"
