#!/bin/bash
# PostgreSQL + HashiCorp Vault Integration Setup Script

# Set these values before running
VAULT_ADDR="http://127.0.0.1:8200"
VAULT_TOKEN="root"  # Replace with actual token
PG_HOST="localhost"
PG_PORT="5432"
PG_USER="vault_admin"
PG_PASSWORD="secure-password"
PG_DB="mydb"

# Login to Vault
export VAULT_ADDR=$VAULT_ADDR
vault login $VAULT_TOKEN

# Enable Vault DB secrets engine
vault secrets enable database

# Configure PostgreSQL plugin
vault write database/config/postgresql-db     plugin_name=postgresql-database-plugin     allowed_roles="readonly"     connection_url="postgresql://{{username}}:{{password}}@$PG_HOST:$PG_PORT/$PG_DB?sslmode=disable"     username="$PG_USER"     password="$PG_PASSWORD"

# Create dynamic role
vault write database/roles/readonly     db_name=postgresql-db     creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";"     default_ttl="1h"     max_ttl="24h"

echo "Vault PostgreSQL integration configured."
