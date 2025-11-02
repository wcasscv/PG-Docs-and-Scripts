#!/bin/bash

# PostgreSQL Cluster Inspection Script
# Purpose: Quickly inspect PostgreSQL physical structures and system state.

PGUSER=postgres
PGDATA=$(psql -U $PGUSER -Atc "SHOW data_directory;")
echo "PostgreSQL Data Directory: $PGDATA"

echo -e "\nListing key PGDATA directories:"
ls -lh $PGDATA | grep -E "base|global|pg_wal|pg_tblspc|pg_multixact"

echo -e "\nTop 10 largest tables:"
psql -U $PGUSER -c "
SELECT relname AS table,
       pg_size_pretty(pg_relation_size(relid)) AS size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_relation_size(relid) DESC
LIMIT 10;"

echo -e "\nToast tables (tables with TOAST storage):"
psql -U $PGUSER -c "
SELECT c.relname AS table_name, t.relname AS toast_table
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_class t ON c.reltoastrelid = t.oid
WHERE c.reltoastrelid <> 0;"

echo -e "\nAutovacuum and dead tuple statistics:"
psql -U $PGUSER -c "
SELECT relname,
       n_dead_tup,
       last_autovacuum,
       vacuum_count
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 10;"

echo -e "\nWAL activity overview:"
ls -lh $PGDATA/pg_wal | tail

echo -e "\nPostgreSQL Cluster Inspection Complete."
