
# 🛠️ Top 100 Useful PostgreSQL DBA Production Support Queries

This markdown document compiles 100 essential PostgreSQL queries for DBA and production support tasks.

---

## 🧠 Query Activity & Sessions

```sql
-- 1. Show all active queries
SELECT pid, state, wait_event, query_start, query FROM pg_stat_activity WHERE state != 'idle';

-- 2. Show long running queries
SELECT pid, now() - query_start AS duration, query FROM pg_stat_activity WHERE state='active' ORDER BY duration DESC;

-- 3. Blocked vs Blocking queries
SELECT blocked_locks.pid AS blocked_pid, blocking_locks.pid AS blocking_pid, blocked_activity.query AS blocked_query, blocking_activity.query AS blocking_query FROM pg_locks blocked_locks JOIN pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid JOIN pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple AND blocking_locks.pid != blocked_locks.pid JOIN pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid WHERE NOT blocked_locks.granted;
```

## 🚦 Connection & Locks

```sql
-- 4. Connection count by DB
SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;

-- 5. Lock summary
SELECT locktype, mode, COUNT(*) FROM pg_locks GROUP BY locktype, mode ORDER BY count DESC;
```

## 🧮 Indexes & Table Stats

```sql
-- 6. Index usage stats
SELECT relname, 100 * idx_scan / (seq_scan + idx_scan + 1) AS index_pct FROM pg_stat_user_tables ORDER BY index_pct ASC;

-- 7. Unused indexes
SELECT relname, indexrelname, idx_scan FROM pg_stat_user_indexes WHERE idx_scan = 0 ORDER BY relname;

-- 8. Table scan stats
SELECT relname, seq_scan, idx_scan FROM pg_stat_user_tables ORDER BY seq_scan DESC;
```

## 💾 Size & Storage

```sql
-- 9. Table size
SELECT relname AS table, pg_size_pretty(pg_total_relation_size(relid)) AS total_size FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC;

-- 10. Index size
SELECT relname AS index, pg_size_pretty(pg_relation_size(relid)) FROM pg_stat_user_indexes ORDER BY pg_relation_size(relid) DESC;
```

## 🔥 Performance Metrics

```sql
-- 11. Cache hit ratio
SELECT blks_hit * 100.0 / nullif(blks_hit + blks_read, 0) AS cache_hit_ratio FROM pg_stat_database WHERE datname = current_database();

-- 12. Dead tuples
SELECT relname, n_dead_tup FROM pg_stat_user_tables ORDER BY n_dead_tup DESC;
```

## 🔄 Autovacuum & Analyze

```sql
-- 13. Autovacuum activity
SELECT relname, last_autovacuum, n_dead_tup FROM pg_stat_user_tables ORDER BY last_autovacuum NULLS FIRST;

-- 14. Manual vacuum recommendation
SELECT relname, n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE n_dead_tup > 10000 ORDER BY n_dead_tup DESC;
```

## 📈 Statistics & pg_stat_statements

```sql
-- 15. Top slowest queries
SELECT query, total_time, calls FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;

-- 16. Most called queries
SELECT query, calls FROM pg_stat_statements ORDER BY calls DESC LIMIT 10;

-- 17. Query time distribution
SELECT query, mean_time, stddev_time FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;
```

## 📂 WAL & Replication

```sql
-- 18. WAL stats
SELECT * FROM pg_stat_wal;

-- 19. Replication status
SELECT * FROM pg_stat_replication;

-- 20. Replication lag
SELECT application_name, client_addr, pg_xlog_location_diff(pg_current_xlog_location(), replay_location) AS byte_lag FROM pg_stat_replication;
```

... *(80 more queries in extended sections)*

## 📊 Monitoring & Diagnostics

```sql
-- 21. Check current WAL insert location
SELECT pg_current_wal_lsn();

-- 22. Check archive mode status
SHOW archive_mode;

-- 23. Show background writer stats
SELECT * FROM pg_stat_bgwriter;

-- 24. Temporary file usage
SELECT datname, sum(temp_bytes)/1024/1024 AS temp_mb FROM pg_stat_database GROUP BY datname ORDER BY temp_mb DESC;

-- 25. Active temp file queries
SELECT pid, query, temp_files, temp_bytes FROM pg_stat_activity JOIN pg_stat_database ON pg_stat_activity.datid = pg_stat_database.datid WHERE temp_files > 0;

-- 26. Top bloated tables
WITH bloat AS (
  SELECT schemaname, tablename, reltuples::bigint AS est_rows,
         relpages::bigint AS pages, otta,
         ROUND(CASE WHEN otta=0 THEN 0.0 ELSE relpages/otta::numeric END,1) AS bloat_ratio
  FROM (
    SELECT schemaname, tablename, reltuples, relpages,
           CEIL((reltuples*((datahdr+ma)+(nullhdr+ma)+4))/(blocksize-20)) AS otta
    FROM (
      SELECT
        ma, blocksize, schemaname, tablename, reltuples, relpages,
        (datawidth + hdr) AS datahdr,
        (maxfracsum * nullhdrwidth) AS nullhdr
      FROM (
        SELECT
          23 AS hdr, 4 AS ma, 8192 AS blocksize, schemaname, tablename,
          reltuples, relpages,
          SUM((1-null_frac)*avg_width) AS datawidth,
          MAX(null_frac) AS maxfracsum,
          COUNT(*) AS nullhdrwidth
        FROM pg_stats
        JOIN pg_class ON pg_stats.tablename = pg_class.relname
        JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
        GROUP BY 1,2,3, schemaname, tablename, reltuples, relpages
      ) AS foo
    ) AS bar
  ) AS baz
)
SELECT * FROM bloat WHERE bloat_ratio > 1.1 ORDER BY bloat_ratio DESC;
```

## 🛡️ Security & Role Management

```sql
-- 27. List all roles
SELECT rolname, rolsuper, rolcreaterole, rolcreatedb FROM pg_roles;

-- 28. Check privileges for a table
SELECT grantee, privilege_type FROM information_schema.role_table_grants WHERE table_name='your_table';

-- 29. Show current user privileges
\du

-- 30. Password expiry check
SELECT usename, valuntil FROM pg_user WHERE valuntil IS NOT NULL;
```

## 📁 Schema Introspection

```sql
-- 31. List all tables
SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema');

-- 32. List all columns of a table
SELECT column_name, data_type FROM information_schema.columns WHERE table_name='your_table';

-- 33. List indexes on a table
SELECT indexname, indexdef FROM pg_indexes WHERE tablename='your_table';

-- 34. Show foreign key constraints
SELECT conname, confrelid::regclass AS referenced_table FROM pg_constraint WHERE contype = 'f';

-- 35. Check default values of columns
SELECT column_name, column_default FROM information_schema.columns WHERE table_name = 'your_table';
```

## 🔁 Maintenance Planning

```sql
-- 36. Tables needing vacuum
SELECT relname, n_dead_tup FROM pg_stat_user_tables WHERE n_dead_tup > 10000 ORDER BY n_dead_tup DESC;

-- 37. Last analyze
SELECT relname, last_analyze FROM pg_stat_user_tables ORDER BY last_analyze;

-- 38. Tables with most updates
SELECT relname, n_tup_upd FROM pg_stat_user_tables ORDER BY n_tup_upd DESC LIMIT 10;

-- 39. Tables with most inserts
SELECT relname, n_tup_ins FROM pg_stat_user_tables ORDER BY n_tup_ins DESC LIMIT 10;

-- 40. Tables with most deletes
SELECT relname, n_tup_del FROM pg_stat_user_tables ORDER BY n_tup_del DESC LIMIT 10;
```

## 📋 Object Size & Usage

```sql
-- 41. Largest databases
SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database ORDER BY pg_database_size(datname) DESC;

-- 42. Top 10 largest tables
SELECT relname AS "Table", pg_size_pretty(pg_total_relation_size(relid)) AS "Size" FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC LIMIT 10;

-- 43. Top 10 largest indexes
SELECT relname AS "Index", pg_size_pretty(pg_relation_size(indexrelid)) AS "Size" FROM pg_stat_user_indexes ORDER BY pg_relation_size(indexrelid) DESC LIMIT 10;
```

## 📦 Replication & WAL

```sql
-- 44. Show WAL sender stats
SELECT * FROM pg_stat_replication;

-- 45. WAL archive status
SELECT * FROM pg_stat_archiver;

-- 46. WAL generation rate
SELECT date_trunc('minute', now()) as minute, pg_xlog_location_diff(pg_current_xlog_insert_location(), '0/0')/1024/1024 as wal_generated_mb;
```

## 🔍 Diagnostics & Explain

```sql
-- 47. Analyze query plan
EXPLAIN ANALYZE SELECT * FROM your_table WHERE id = 123;

-- 48. Show planner statistics
SELECT * FROM pg_stats WHERE tablename = 'your_table';

-- 49. Identify slow functions
SELECT * FROM pg_stat_user_functions ORDER BY total_time DESC LIMIT 10;
```

... *(50 additional queries continued in next batch)*

## 🔧 System Views & Metadata

```sql
-- 50. View system catalogs
SELECT * FROM pg_catalog.pg_class LIMIT 10;

-- 51. View extensions installed
SELECT * FROM pg_extension;

-- 52. Check current settings
SELECT name, setting FROM pg_settings ORDER BY name;

-- 53. Find queries with temporary files
SELECT datname, query, temp_files, temp_bytes FROM pg_stat_activity JOIN pg_stat_database USING(datid) WHERE temp_files > 0;

-- 54. Log file location
SHOW log_directory;
```

## 🛠️ Configuration & Parameters

```sql
-- 55. Current config parameters
SELECT name, setting FROM pg_settings ORDER BY name;

-- 56. Max connections allowed
SHOW max_connections;

-- 57. Work memory settings
SHOW work_mem;

-- 58. Check timezone setting
SHOW timezone;

-- 59. Check shared buffers
SHOW shared_buffers;
```

## 🗂️ Partitioning & Table Management

```sql
-- 60. List all partitions
SELECT inhrelid::regclass AS child, inhparent::regclass AS parent FROM pg_inherits;

-- 61. Find table inheritance
SELECT c.relname AS child, p.relname AS parent FROM pg_inherits i JOIN pg_class c ON i.inhrelid = c.oid JOIN pg_class p ON i.inhparent = p.oid;

-- 62. Partition sizes
SELECT relname, pg_size_pretty(pg_total_relation_size(relname::regclass)) FROM pg_class WHERE relkind = 'r';

-- 63. Check vacuum settings
SELECT relname, reloptions FROM pg_class WHERE reloptions IS NOT NULL;
```

## 🧪 Monitoring Extensions

```sql
-- 64. pg_stat_statements summary
SELECT queryid, query, calls, total_time FROM pg_stat_statements ORDER BY total_time DESC LIMIT 5;

-- 65. pg_stat_kcache usage
SELECT * FROM pg_stat_kcache LIMIT 5;

-- 66. pg_stat_user_indexes index scans
SELECT relname, indexrelname, idx_scan FROM pg_stat_user_indexes ORDER BY idx_scan DESC;

-- 67. pg_stat_user_tables buffer hits
SELECT relname, heap_blks_hit, heap_blks_read FROM pg_statio_user_tables ORDER BY heap_blks_hit DESC;
```

## 🚨 Alerts & Incidents

```sql
-- 68. Long transactions
SELECT datname, pid, age(clock_timestamp(), xact_start), query FROM pg_stat_activity WHERE state = 'active';

-- 69. Sessions with idle in transaction
SELECT pid, state, query FROM pg_stat_activity WHERE state = 'idle in transaction';

-- 70. Connections per user
SELECT usename, count(*) FROM pg_stat_activity GROUP BY usename;
```

## 🏗️ DDL & Schema Changes

```sql
-- 71. Recent DDL changes (log parsing)
-- Requires logging to be enabled, use pgBadger or logs

-- 72. Last DDL change timestamp
SELECT relname, relkind, pg_stat_file('base/'||oid||'/PG_VERSION') FROM pg_class LIMIT 5;

-- 73. Create table DDL
-- Use pg_dump -s -t table_name dbname

-- 74. Show table definition
SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name = 'your_table';
```

## 📡 Extensions & Plugins

```sql
-- 75. Installed extensions
SELECT * FROM pg_available_extensions WHERE installed_version IS NOT NULL;

-- 76. Extension update checks
SELECT name, default_version, installed_version FROM pg_available_extensions WHERE installed_version IS NOT NULL;
```

## 🧵 Background Workers

```sql
-- 77. List background workers
SELECT * FROM pg_stat_activity WHERE backend_type LIKE 'background%';

-- 78. Check autovacuum workers
SELECT * FROM pg_stat_activity WHERE backend_type = 'autovacuum worker';
```

## 📑 Logs & IO

```sql
-- 79. View recent log entries (if log_table enabled)
-- SELECT * FROM pg_log ORDER BY log_time DESC LIMIT 10;

-- 80. IO stats by table
SELECT relname, heap_blks_read, heap_blks_hit FROM pg_statio_user_tables ORDER BY heap_blks_read DESC;
```

## 🗂 Object Dependencies

```sql
-- 81. Table dependencies
SELECT objid::regclass AS object, refobjid::regclass AS depends_on FROM pg_depend WHERE classid = 'pg_class'::regclass;

-- 82. Functions used by triggers
SELECT tgname, tgrelid::regclass, tgfoid::regprocedure FROM pg_trigger WHERE NOT tgisinternal;
```

## 📚 Miscellaneous

```sql
-- 83. Show all databases
SELECT datname FROM pg_database;

-- 84. Tables with no primary key
SELECT relname FROM pg_stat_user_tables WHERE relid NOT IN (SELECT conrelid FROM pg_constraint WHERE contype = 'p');

-- 85. Table row counts
SELECT relname, n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC;

-- 86. All functions in schema
SELECT proname, proargnames FROM pg_proc JOIN pg_namespace ON pg_proc.pronamespace = pg_namespace.oid WHERE nspname = 'public';

-- 87. Check for prepared statements
SELECT * FROM pg_prepared_statements;

-- 88. Show notifications
-- LISTEN some_channel; -- Then WAIT for NOTIFY

-- 89. Check temp file size
SELECT sum(temp_bytes)/1024/1024 AS temp_file_size_mb FROM pg_stat_database;

-- 90. Detect heavy write activity
SELECT relname, heap_blks_written FROM pg_statio_user_tables ORDER BY heap_blks_written DESC;

-- 91. Oldest transaction
SELECT datname, pid, now() - xact_start AS age FROM pg_stat_activity WHERE xact_start IS NOT NULL ORDER BY age DESC LIMIT 1;

-- 92. Count all active backends
SELECT count(*) FROM pg_stat_activity;

-- 93. List triggers
SELECT tgname, tgrelid::regclass FROM pg_trigger WHERE NOT tgisinternal;

-- 94. Index bloat estimate (rough)
SELECT schemaname, relname, 100 * idx_scan::float / (seq_scan + idx_scan + 1) AS idx_usage_pct FROM pg_stat_user_tables;

-- 95. Redundant indexes
-- Use pg_repack or pg_index_advisor to detect

-- 96. Invalid indexes
SELECT * FROM pg_index WHERE indisvalid = false;

-- 97. Autovacuum settings per table
SELECT relname, reloptions FROM pg_class WHERE relkind = 'r' AND reloptions IS NOT NULL;

-- 98. Slow query log candidates
-- pg_stat_statements + total_time + mean_time filter

-- 99. Explain slowest queries
EXPLAIN ANALYZE SELECT * FROM big_table WHERE column = 'value';

-- 100. Check logical replication slots
SELECT * FROM pg_replication_slots WHERE slot_type = 'logical';
```

---

📘 **Usage Tips**: Combine `\\x` for expanded output, `\\watch` for auto-refreshing, or integrate into dashboards and tooling.

