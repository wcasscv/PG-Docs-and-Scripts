#!/bin/bash

# PostgreSQL Logical Replication Setup: Multi-Cloud (AWS RDS → GCP & Azure)
# With firewall rule prep and SSL support

# --- General Configuration ---
REPL_USER="replicator"
REPL_PASS="replica_pass"
DATABASE_NAME="mydb"
PUBLICATION_NAME="pub_all_tables"
SUBSCRIPTION_NAME="sub_all_tables"
SSL_MODE="require"  # use 'verify-full' with proper certificates

# --- Cloud Endpoints ---
AWS_PRIMARY="aws-primary.rds.amazonaws.com"
GCP_SUBSCRIBER="gcp-subscriber.cloudsql.googleapis.com"
AZURE_SUBSCRIBER="azure-subscriber.postgres.database.azure.com"

# --- Step 1: Pre-checks and Firewall Setup (Manual/CLI) ---
echo "🔒 Ensure these IPs are whitelisted in your firewalls:"
echo "- AWS RDS allows GCP and Azure IPs (via VPC security groups or RDS inbound rules)"
echo "- GCP Cloud SQL allows AWS IP (set via gcloud sql instances patch)"
echo "- Azure PostgreSQL allows AWS IP (via azure cli or portal)"

# Example CLI for GCP:
# gcloud sql instances patch INSTANCE_NAME --authorized-networks=AWS_IP/32

# Example CLI for Azure:
# az postgres server firewall-rule create --name AllowAWS --resource-group YOUR_RG --server YOUR_SERVER --start-ip-address AWS_IP --end-ip-address AWS_IP

# --- Step 2: Enable logical replication on AWS RDS parameter group ---
echo "🔧 Ensure RDS parameter group has:"
echo "- wal_level = logical"
echo "- max_replication_slots > 0"
echo "- max_wal_senders > 5"

# --- Step 3: Create replication role and publication on AWS RDS ---
echo "Creating replication user and publication on AWS RDS..."
psql "host=$AWS_PRIMARY dbname=$DATABASE_NAME user=postgres" -c "CREATE ROLE $REPL_USER WITH LOGIN REPLICATION PASSWORD '$REPL_PASS';"
psql "host=$AWS_PRIMARY dbname=$DATABASE_NAME user=postgres" -c "CREATE PUBLICATION $PUBLICATION_NAME FOR ALL TABLES;"

# --- Step 4: Create subscriptions with SSL on GCP and Azure ---
echo "Creating subscription on GCP Cloud SQL..."
psql "host=$GCP_SUBSCRIBER dbname=$DATABASE_NAME user=postgres sslmode=$SSL_MODE" -c \
"CREATE SUBSCRIPTION $SUBSCRIPTION_NAME CONNECTION 'host=$AWS_PRIMARY dbname=$DATABASE_NAME user=$REPL_USER password=$REPL_PASS sslmode=$SSL_MODE' PUBLICATION $PUBLICATION_NAME;"

echo "Creating subscription on Azure PostgreSQL..."
psql "host=$AZURE_SUBSCRIBER dbname=$DATABASE_NAME user=postgres sslmode=$SSL_MODE" -c \
"CREATE SUBSCRIPTION ${SUBSCRIPTION_NAME}_azure CONNECTION 'host=$AWS_PRIMARY dbname=$DATABASE_NAME user=$REPL_USER password=$REPL_PASS sslmode=$SSL_MODE' PUBLICATION $PUBLICATION_NAME;"

echo "✅ Multi-cloud logical replication with SSL and firewall considerations complete!"
