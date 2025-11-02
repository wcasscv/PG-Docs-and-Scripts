
# My Top 20 Useful PostgreSQL DBA Queries

1. **Current Queries and Wait Events**
```sql
SELECT pid, backend_start, wait_event_type, wait_event, backend_type, query
FROM pg_stat_activity
WHERE state != 'idle';
```

2. **Blocking and Blocked Queries**
```sql
SELECT blocked.pid AS blocked_pid, blocked.query AS blocked_query,
       blocking.pid AS blocking_pid, blocking.query AS blocking_query
FROM pg_stat_activity blocked
JOIN pg_locks blocked_locks ON blocked.pid = blocked_locks.pid
JOIN pg_locks blocking_locks ON blocking_llocks.locktype = blocked_locks.locktype
  AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
  AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
  AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
  AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
  AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
  AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
  AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
  AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
  AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
  AND blocking_locks.pid != blocked_locks.pid
JOIN pg_stat_activity blocking ON blocking.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```

3. **Long Running Queries**
```sql
SELECT pid, now() - query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY duration DESC;
```

4. **Autovacuum Activity**
```sql
SELECT relname, last_autovacuum, n_dead_tup, n_live_tup
FROM pg_stat_user_tables
ORDER BY last_autovacuum NULLS FIRST;
```

5. **Top CPU-Consuming Queries (pg_stat_statements)**
```sql
SELECT query, total_time, calls, mean_time
FROM pg_stat_statements
ORDER BY total_time DESC
LIMIT 10;
```

6. **Table Size Summary**
```sql
SELECT relname AS table_name,
       pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
```

7. **Index Usage Ratio**
```sql
SELECT relname AS table_name,
       100 * idx_scan / (seq_scan + idx_scan + 1) AS index_usage_pct
FROM pg_stat_user_tables
ORDER BY index_usage_pct ASC;
```

8. **Unused Indexes**
```sql
SELECT schemaname, relname, indexrelname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY relname;
```

9. **Dead Tuples**
```sql
SELECT relname, n_live_tup, n_dead_tup
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 10;
```

10. **Cache Hit Ratio**
```sql
SELECT blks_hit * 100.0 / nullif(blks_hit + blks_read, 0) AS cache_hit_ratio
FROM pg_stat_database
WHERE datname = current_database();
```

11. **Connections Per Database**
```sql
SELECT datname, count(*) AS connections
FROM pg_stat_activity
GROUP BY datname;
```

12. **Transactions Per Second**
```sql
SELECT date_trunc('minute', now()) AS minute, sum(xact_commit + xact_rollback) AS tps
FROM pg_stat_database
GROUP BY 1
ORDER BY 1 DESC
LIMIT 10;
```

13. **WAL Statistics**
```sql
SELECT * FROM pg_stat_wal;
```

14. **Lock Summary**
```sql
SELECT locktype, mode, COUNT(*) as count
FROM pg_locks
GROUP BY locktype, mode
ORDER BY count DESC;
```

15. **Current Locks**
```sql
SELECT pid, mode, relation::regclass, page, tuple, granted
FROM pg_locks
WHERE NOT granted;
```

16. **Temp File Usage**
```sql
SELECT datname, sum(temp_files) AS temp_files, sum(temp_bytes)/1024/1024 AS temp_mb
FROM pg_stat_database
GROUP BY datname;
```

17. **Replication Status**
```sql
SELECT * FROM pg_stat_replication;
```

18. **Active Backends Count**
```sql
SELECT count(*) AS active_connections
FROM pg_stat_activity
WHERE state = 'active';
```

19. **Table Bloat Estimate (extension: pgstattuple or pg_bloat_check)**

20. **Vacuum Progress**
```sql
SELECT * FROM pg_stat_progress_vacuum;
```

21. ** Show column truncated. Eg. SUBSTRING(column_name FROM 1 FOR 30) AS short_column
```sql
SELECT pid, LEFT(query, 30) AS short_query FROM pg_stat_activity WHERE state = 'active';
SELECT pid,backend_start ,wait_event_type, wait_event , backend_type, LEFT(query, 30) AS short_query  FROM pg_stat_activity;
```

22. ** Watch Query
```sql
\x
SELECT count(*) FROM pg_stat_activity;
\watch 5
```


# My Top 20 psql formatting:

\x — Expanded output (vertical display)
\pset pager off — Disablße pager
\pset border 2 — Add boxed borders
\pset null '[NULL]' — Display NULL values clearly
\a — Unaligned output (e.g. for scripting)
\t — Turn off column headers and footers
\f ',' — Set field separator
\H — HTML format output
\pset format csv — Output as CSV
\o filename.csv — Redirect output to file
\watch 5 — Run a query every 5 seconds (live dashboard)
\timing — Show execution time
\set — Define psql variables   eg.  \set myvar 'users'
\echo — Print messages in scripts eg. \echo 'Starting query...'
\! — Run shell commands    eg.  \! ls -lh
\d+ to show detailed table info  eg.  \d+ my_table

Use SQL formatting: TO_CHAR() for date/time/numbers
SELECT TO_CHAR(now(), 'YYYY-MM-DD HH24:MI');
SELECT TO_CHAR(12345.678, '999,999.99');

Limit output rows using LIMIT or FETCH FIRST
SELECT * FROM my_table LIMIT 10;

Abbreviate long queries: show only left part
SELECT pid, LEFT(query, 60) AS snippet FROM pg_stat_activity;

Combine formatting: CSV + output to file
\pset format csv
\o result.csv
SELECT * FROM my_table;
\o







# End ###############


