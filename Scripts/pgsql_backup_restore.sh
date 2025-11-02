#!/bin/bash
# PostgreSQL Backup and Restore Script (Logical)

# Configuration
PGUSER="postgres"
DBNAME="mydb"
BACKUPFILE="mydb_backup_$(date +%F).dump"

# Export with pg_dump (custom format)
pg_dump -U $PGUSER -F c -f $BACKUPFILE $DBNAME
echo "Backup created: $BACKUPFILE"

# Restore with pg_restore (example)
# pg_restore -U $PGUSER -d ${DBNAME}_restored $BACKUPFILE
