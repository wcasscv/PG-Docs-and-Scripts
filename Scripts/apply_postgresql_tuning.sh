#!/bin/bash
# Apply tuned postgresql.conf and restart PostgreSQL

CONF_PATH="/etc/postgresql/15/main/postgresql.conf"
BACKUP_PATH="/etc/postgresql/15/main/postgresql.conf.bak"

echo "Backing up existing config to $BACKUP_PATH..."
sudo cp $CONF_PATH $BACKUP_PATH

echo "Applying tuned configuration..."
sudo cp postgresql_tuned.conf $CONF_PATH

echo "Restarting PostgreSQL service..."
sudo systemctl restart postgresql

echo "Done. Check logs for any errors or warnings."
