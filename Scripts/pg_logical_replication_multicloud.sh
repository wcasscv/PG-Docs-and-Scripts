#!/bin/bash

# PostgreSQL Logical Replication Setup for AWS, GCP, and Azure

# --- General Configuration ---
REPL_USER="replicator"
REPL_PASS="replica_pass"
DATABASE_NAME="mydb"
PUBLICATION_NAME="pub_all_tables"
SUBSCRIPTION_NAME="sub_all_tables"

# --- Cloud-Specific Endpoints ---
AWS_PRIMARY="aws-primary.rds.amazonaws.com"
GCP_SUBSCRIBER="gcp-subscriber.cloudsql.googleapis.com"
AZURE_SUBSCRIBER="azure-subscriber.postgres.database.azure.com"

# --- Step 1: Configure Primary (AWS RDS) ---
echo "Creating replication role on AWS RDS..."
psql -h $AWS_PRIMARY -U postgres -d $DATABASE_NAME -c "CREATE ROLE $REPL_USER WITH LOGIN REPLICATION PASSWORD '$REPL_PASS';"

echo "Creating publication on AWS RDS..."
psql -h $AWS_PRIMARY -U postgres -d $DATABASE_NAME -c "CREATE PUBLICATION $PUBLICATION_NAME FOR ALL TABLES;"

# --- Step 2: Configure GCP Subscriber (Cloud SQL) ---
echo "Creating subscription on GCP Cloud SQL..."
psql -h $GCP_SUBSCRIBER -U postgres -d $DATABASE_NAME -c \
"CREATE SUBSCRIPTION $SUBSCRIPTION_NAME CONNECTION 'host=$AWS_PRIMARY dbname=$DATABASE_NAME user=$REPL_USER password=$REPL_PASS' PUBLICATION $PUBLICATION_NAME;"

# --- Step 3: Configure Azure Subscriber (Azure Database for PostgreSQL) ---
echo "Creating subscription on Azure..."
psql -h $AZURE_SUBSCRIBER -U postgres -d $DATABASE_NAME -c \
"CREATE SUBSCRIPTION ${SUBSCRIPTION_NAME}_azure CONNECTION 'host=$AWS_PRIMARY dbname=$DATABASE_NAME user=$REPL_USER password=$REPL_PASS' PUBLICATION $PUBLICATION_NAME;"

echo "✅ Multi-Cloud logical replication setup complete!"
