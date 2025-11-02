
-- PostgreSQL Metadata and Performance Insights

-- 1. List Tables
SELECT 
  n.nspname AS schema,
  c.relname AS table_name,
  c.relkind,
  c.reltuples::BIGINT AS estimated_rows
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY n.nspname, c.relname;

-- 2. List Columns
SELECT 
  c.relname AS table_name,
  a.attname AS column_name,
  pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type,
  a.attnotnull AS not_null,
  a.attnum AS ordinal_position
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_attribute a ON a.attrelid = c.oid
WHERE c.relkind = 'r'
  AND a.attnum > 0
  AND NOT a.attisdropped
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY c.relname, a.attnum;

-- 3. Show Indexes
-- 3.1 Index Definitions
SELECT 
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schemaname, tablename;

-- 3.2 Index Usage Stats
SELECT 
  relname AS table_name,
  indexrelname AS index_name,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC
LIMIT 10;

-- 4. Show Constraints
SELECT 
  conname AS constraint_name,
  contype AS type,
  conrelid::regclass AS table_name,
  confrelid::regclass AS referenced_table,
  pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE contype IN ('p', 'f', 'u', 'c')
ORDER BY table_name;

-- 5. Show Object Sizes
SELECT 
  relname AS object_name,
  pg_size_pretty(pg_relation_size(relid)) AS data_size,
  pg_size_pretty(pg_total_relation_size(relid)) AS total_size_with_indexes
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 10;

-- 6. Runtime Stats
SELECT 
  relname AS table_name,
  seq_scan,
  idx_scan,
  n_tup_ins AS inserts,
  n_tup_upd AS updates,
  n_tup_del AS deletes,
  n_live_tup AS live_rows,
  n_dead_tup AS dead_rows,
  last_vacuum,
  last_autovacuum
FROM pg_stat_user_tables
ORDER BY n_tup_upd + n_tup_ins + n_tup_del DESC
LIMIT 10;
