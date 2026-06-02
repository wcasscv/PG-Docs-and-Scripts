# PostgreSQL: “I Know This Stuff, But in the Interview I Freeze” Kit

## Strong intro

You can know PostgreSQL well and still go blank in an interview.

That does not mean you are weak. It usually means your knowledge is stored as working experience, not as interview-ready language. On the job, you inspect metrics, read logs, ask for context, test a hypothesis, and fix the system. In an interview, you are often asked to compress that whole process into a clean answer in 60 seconds.

This kit is built for that gap.

It gives you the top 20 PostgreSQL issues you are likely to be asked about, how to explain them under pressure, what causes them, how to diagnose them, and how to resolve them. Each section includes examples you can say out loud in an interview.

The goal is not to memorize perfect answers. The goal is to build repeatable answer shapes.

When you freeze, use this pattern:

> “I would first confirm the symptom, then isolate whether it is query, schema, configuration, resource, or concurrency related. Then I would use PostgreSQL views and logs to prove the cause before changing anything.”

That one sentence already sounds like a senior engineer.

---

## How to use this kit

For each issue, learn four things:

1. **The symptom** — what the user or system sees.
2. **The likely cause** — what is usually happening underneath.
3. **The diagnosis path** — what you check first.
4. **The resolution** — what you change and how you verify it.

In interviews, do not jump straight to the fix. Strong candidates show method.

A good PostgreSQL answer sounds like this:

> “If a query suddenly became slow, I would first compare the current plan with a known-good plan using `EXPLAIN (ANALYZE, BUFFERS)`. Then I would check row estimates, index usage, table bloat, stale statistics, and recent schema or data distribution changes. I would avoid adding indexes blindly until I understood the plan.”

That answer is calm, structured, and realistic.

---

# Top 20 PostgreSQL issues and resolutions

---

## 1. Slow queries

### Interview freeze point

You know slow queries are common, but the question is broad. The interviewer asks:

> “A PostgreSQL query is slow. What do you do?”

This is where many candidates freeze because there are too many possible answers.

### Strong interview answer

> “I would start by proving where time is spent. I would use `EXPLAIN (ANALYZE, BUFFERS)` to compare estimated rows to actual rows, check whether indexes are being used, and look for sequential scans, nested loops over large datasets, sorts spilling to disk, or bad join order. Then I would check table statistics, indexes, query shape, and resource pressure.”

### Common causes

- Missing index
- Wrong index
- Stale statistics
- Bad query shape
- Large sequential scan
- Sort spilling to disk
- Join returning more rows than expected
- Parameter-sensitive plan
- Table or index bloat
- Disk I/O pressure

### Diagnostic commands

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM orders
WHERE customer_id = 42
ORDER BY created_at DESC
LIMIT 20;
```

Useful views:

```sql
SELECT query, calls, total_exec_time, mean_exec_time, rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
```

### Example problem

```sql
SELECT *
FROM orders
WHERE customer_id = 42
ORDER BY created_at DESC
LIMIT 20;
```

If `orders` has millions of rows and no useful index, PostgreSQL may scan many rows and sort them.

### Resolution

Create an index that matches the filter and order:

```sql
CREATE INDEX CONCURRENTLY idx_orders_customer_created
ON orders (customer_id, created_at DESC);
```

Then verify:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM orders
WHERE customer_id = 42
ORDER BY created_at DESC
LIMIT 20;
```

### Important detail

Use `CREATE INDEX CONCURRENTLY` in production to avoid blocking writes. It takes longer, but it is safer for live systems.

### Takeaway summary

Slow query troubleshooting is not “add an index.” It is: inspect the plan, compare estimates to reality, identify the expensive operation, fix the root cause, then re-test.

---

## 2. Missing or ineffective indexes

### Interview freeze point

You may know indexes help performance, but interviewers often want to know when an index does not help.

### Strong interview answer

> “An index helps when it matches the query’s filtering, joining, sorting, or uniqueness pattern. I would check whether the index columns match the query predicates and ordering. I would also check selectivity, because an index on a low-cardinality column may not help much.”

### Common causes

- No index on filtered column
- Column order does not match query
- Function used on indexed column
- Type mismatch prevents index use
- Low selectivity
- Index exists but statistics are stale
- Query returns too much of the table

### Example problem: function prevents index use

```sql
SELECT *
FROM users
WHERE lower(email) = 'jack@example.com';
```

An index on `email` may not be used because the query applies `lower(email)`.

### Resolution option 1: expression index

```sql
CREATE INDEX CONCURRENTLY idx_users_lower_email
ON users (lower(email));
```

### Resolution option 2: normalized data

Store email in normalized lowercase form and enforce it at write time.

```sql
CREATE UNIQUE INDEX CONCURRENTLY idx_users_email
ON users (email);
```

### Example problem: composite index order

Query:

```sql
SELECT *
FROM events
WHERE account_id = 10
AND event_type = 'login'
ORDER BY created_at DESC
LIMIT 50;
```

Better index:

```sql
CREATE INDEX CONCURRENTLY idx_events_account_type_created
ON events (account_id, event_type, created_at DESC);
```

### Interview note

Do not say every column needs an index. Indexes speed up reads but slow writes and consume disk.

### Takeaway summary

Good indexes are workload-specific. The best index supports the way the application actually filters, joins, sorts, and enforces uniqueness.

---

## 3. Too many indexes

### Interview freeze point

Many people know missing indexes are bad. Fewer explain that too many indexes also hurt.

### Strong interview answer

> “Indexes are not free. Every insert, update, and delete must maintain indexes. Too many indexes can slow writes, increase WAL volume, consume cache, and make vacuum work harder. I would look for unused or duplicate indexes before adding more.”

### Symptoms

- Slow inserts or updates
- High disk usage
- High write-ahead log volume
- Vacuum taking longer
- Poor cache efficiency
- Many similar indexes

### Diagnostic query

```sql
SELECT
    schemaname,
    relname AS table_name,
    indexrelname AS index_name,
    idx_scan,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC, pg_relation_size(indexrelid) DESC;
```

### Duplicate index example

```sql
CREATE INDEX idx_orders_customer_id ON orders (customer_id);
CREATE INDEX idx_orders_customer_created ON orders (customer_id, created_at);
```

The first index may be redundant if the second supports the same access pattern.

### Resolution

Review indexes before dropping. Confirm with application query patterns and monitoring history.

```sql
DROP INDEX CONCURRENTLY idx_orders_customer_id;
```

### Warning

`idx_scan = 0` does not always mean safe to drop. The database may have restarted recently, statistics may have reset, or the index may support rare but critical queries.

### Takeaway summary

Indexes are a trade-off. A senior answer includes both sides: they improve reads, but they increase write cost and operational overhead.

---

## 4. Stale statistics and bad query plans

### Interview freeze point

The interviewer asks why PostgreSQL chose a bad plan even though indexes exist.

### Strong interview answer

> “PostgreSQL chooses plans based on statistics. If stats are stale or data distribution has changed, the planner may misestimate row counts and choose the wrong join or scan. I would compare estimated rows to actual rows in `EXPLAIN ANALYZE`, then run `ANALYZE` or tune autovacuum analyze thresholds.”

### Symptoms

- Query suddenly slow after data growth
- Planner chooses sequential scan unexpectedly
- Estimated rows are far from actual rows
- Join order seems wrong
- Query performance changes after `ANALYZE`

### Diagnostic example

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM orders
WHERE status = 'pending';
```

Look for this kind of mismatch:

```text
rows=100 width=...
actual rows=500000 loops=1
```

That means the planner expected 100 rows but got 500,000.

### Resolution

Run:

```sql
ANALYZE orders;
```

For larger or skewed tables, increase statistics target:

```sql
ALTER TABLE orders
ALTER COLUMN status SET STATISTICS 1000;

ANALYZE orders;
```

### Autovacuum analyze tuning

For high-change tables:

```sql
ALTER TABLE orders SET (
  autovacuum_analyze_scale_factor = 0.02,
  autovacuum_analyze_threshold = 1000
);
```

### Takeaway summary

Bad plans often come from bad estimates. When estimates are wrong, check statistics before blaming PostgreSQL.

---

## 5. Lock contention

### Interview freeze point

You know locks happen, but in interviews the hard part is explaining how to find the blocker.

### Strong interview answer

> “I would identify blocked sessions and blocking sessions using `pg_stat_activity` and `pg_locks`. Then I would inspect the blocking query, transaction age, lock type, and application behavior. The fix might be query tuning, shorter transactions, changing migration strategy, or terminating a bad blocker if necessary.”

### Symptoms

- Queries hang
- Application requests time out
- Deployments freeze
- DDL does not complete
- One transaction blocks many others

### Diagnostic query

```sql
SELECT
    blocked.pid AS blocked_pid,
    blocked.query AS blocked_query,
    blocking.pid AS blocking_pid,
    blocking.query AS blocking_query,
    blocking.state AS blocking_state
FROM pg_stat_activity blocked
JOIN pg_locks blocked_locks
    ON blocked.pid = blocked_locks.pid
JOIN pg_locks blocking_locks
    ON blocking_locks.locktype = blocked_locks.locktype
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
JOIN pg_stat_activity blocking
    ON blocking.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted
  AND blocking_locks.granted;
```

### Simpler blocker check

```sql
SELECT
    pid,
    usename,
    state,
    wait_event_type,
    wait_event,
    age(now(), query_start) AS query_age,
    query
FROM pg_stat_activity
WHERE wait_event_type = 'Lock';
```

### Resolution options

- Keep transactions short
- Avoid user interaction inside transactions
- Add indexes to reduce row lock duration
- Use safer migrations
- Use `lock_timeout` for DDL
- Kill blocker only when safe

```sql
SELECT pg_terminate_backend(12345);
```

### Safer migration example

Instead of:

```sql
ALTER TABLE users ADD COLUMN new_col text DEFAULT 'x' NOT NULL;
```

Use phased migration:

```sql
ALTER TABLE users ADD COLUMN new_col text;
UPDATE users SET new_col = 'x' WHERE new_col IS NULL;
ALTER TABLE users ALTER COLUMN new_col SET DEFAULT 'x';
ALTER TABLE users ALTER COLUMN new_col SET NOT NULL;
```

### Takeaway summary

Lock problems are usually application behavior problems. Find the blocker, understand why it is holding the lock, then reduce lock duration.

---

## 6. Long-running transactions

### Interview freeze point

Long transactions feel harmless because they may not use much CPU. But in PostgreSQL, they can cause serious cleanup problems.

### Strong interview answer

> “Long-running transactions can prevent vacuum from cleaning dead rows. That can cause table bloat, index bloat, transaction ID age risk, and degraded performance. I would look for old transaction ages in `pg_stat_activity`, then work with the application team to shorten transaction scope.”

### Symptoms

- Table bloat increases
- Vacuum cannot clean dead tuples
- Disk usage grows
- Query performance slowly degrades
- Replication lag may increase
- Autovacuum appears to run but does not reclaim enough

### Diagnostic query

```sql
SELECT
    pid,
    usename,
    state,
    xact_start,
    age(now(), xact_start) AS transaction_age,
    query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
ORDER BY xact_start ASC;
```

### Common causes

- Idle transaction left open
- Batch job doing too much in one transaction
- Application begins transaction but waits on network or user input
- ORM session not committed
- Reporting query holding snapshot for a long time

### Resolution

Shorten the transaction:

```sql
BEGIN;

-- Do a small unit of work.
UPDATE jobs
SET status = 'processing'
WHERE id = 123;

COMMIT;
```

Avoid this pattern:

```sql
BEGIN;

-- Fetch huge dataset.
-- Process externally for minutes.
-- Write results.

COMMIT;
```

Use timeout protection:

```sql
ALTER DATABASE appdb
SET idle_in_transaction_session_timeout = '60s';
```

### Takeaway summary

PostgreSQL needs old transactions to end so it can clean up old row versions. Long transactions are silent performance killers.

---

## 7. Deadlocks

### Interview freeze point

Deadlocks sound scary, but they are usually caused by inconsistent lock ordering.

### Strong interview answer

> “A deadlock happens when two transactions wait on each other in a cycle. PostgreSQL detects it and aborts one transaction. I would inspect logs for the deadlock details, identify the conflicting statements, and fix the application so it locks resources in a consistent order.”

### Simple deadlock example

Session A:

```sql
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;
COMMIT;
```

Session B:

```sql
BEGIN;
UPDATE accounts SET balance = balance - 50 WHERE id = 2;
UPDATE accounts SET balance = balance + 50 WHERE id = 1;
COMMIT;
```

Session A locks account 1 then wants 2. Session B locks account 2 then wants 1. That creates a deadlock.

### Resolution

Always lock rows in the same order:

```sql
BEGIN;

SELECT *
FROM accounts
WHERE id IN (1, 2)
ORDER BY id
FOR UPDATE;

UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;

COMMIT;
```

### Other fixes

- Keep transactions short
- Retry deadlocked transactions safely
- Reduce batch size
- Avoid touching rows in random order
- Add useful indexes to reduce scanned locked rows

### Application retry pattern

Deadlocks can happen even in healthy systems. The application should retry safe transactions.

Pseudo-code:

```text
try transaction
if deadlock detected:
    wait briefly
    retry transaction
```

### Takeaway summary

Deadlocks are not fixed by turning a knob. They are fixed by consistent lock ordering, shorter transactions, and safe retries.

---

## 8. Connection exhaustion

### Interview freeze point

The app says “database down,” but PostgreSQL may simply have no available connections.

### Strong interview answer

> “I would check active connections, connection states, and whether the application is opening too many connections. PostgreSQL connections are process-based and not free. The usual fix is connection pooling, sane pool sizing, and closing idle or leaked connections.”

### Symptoms

- Error: `too many connections`
- New app requests fail
- Database CPU may be low
- Many idle sessions
- Spiky traffic causes failures
- Deploys create connection storms

### Diagnostic query

```sql
SELECT
    state,
    count(*)
FROM pg_stat_activity
GROUP BY state
ORDER BY count(*) DESC;
```

Connections by application:

```sql
SELECT
    application_name,
    state,
    count(*)
FROM pg_stat_activity
GROUP BY application_name, state
ORDER BY count(*) DESC;
```

### Resolution

Use a connection pooler such as PgBouncer, or tune application pool sizes.

Bad pattern:

```text
50 app instances × 50 connections = 2500 possible DB connections
```

Better pattern:

```text
50 app instances × 5 connections = 250 possible DB connections
```

With PgBouncer, many client connections can share fewer server connections.

### Important pool sizing question

Ask:

> “How many concurrent queries can the database actually run well?”

The answer is not always “as many as possible.” Too many active queries can increase context switching, memory pressure, and lock contention.

### Takeaway summary

Connection count is not throughput. A smaller, well-sized pool often performs better than a large uncontrolled pool.

---

## 9. Autovacuum not keeping up

### Interview freeze point

Autovacuum sounds like background magic. But interviewers expect you to know why it matters.

### Strong interview answer

> “PostgreSQL uses MVCC, so updates and deletes create dead tuples. Vacuum removes dead tuples when old transactions no longer need them. If autovacuum cannot keep up, tables bloat and performance gets worse. I would check dead tuples, vacuum activity, long transactions, and table-specific autovacuum settings.”

### Symptoms

- Disk usage grows
- Queries slow down over time
- Index scans touch many pages
- Autovacuum constantly running
- Dead tuples remain high
- Transaction ID wraparound warnings

### Diagnostic query

```sql
SELECT
    relname,
    n_live_tup,
    n_dead_tup,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 20;
```

Check active autovacuum:

```sql
SELECT
    pid,
    now() - xact_start AS duration,
    query
FROM pg_stat_activity
WHERE query LIKE 'autovacuum:%';
```

### Common causes

- High update/delete workload
- Long-running transactions
- Autovacuum thresholds too high for large tables
- Autovacuum cost delay too conservative
- I/O saturation
- Tables with frequent churn

### Resolution

Tune per-table settings:

```sql
ALTER TABLE events SET (
  autovacuum_vacuum_scale_factor = 0.02,
  autovacuum_vacuum_threshold = 1000,
  autovacuum_analyze_scale_factor = 0.01,
  autovacuum_analyze_threshold = 1000
);
```

Manual vacuum when needed:

```sql
VACUUM (ANALYZE) events;
```

For severe bloat, consider:

```sql
VACUUM FULL events;
```

But `VACUUM FULL` rewrites the table and takes strong locks, so it must be planned carefully.

### Takeaway summary

Autovacuum is not optional maintenance. It is core to PostgreSQL health.

---

## 10. Table and index bloat

### Interview freeze point

Bloat is often misunderstood. It is not just “large tables.” It is wasted space from old row versions and fragmented indexes.

### Strong interview answer

> “Bloat happens because PostgreSQL keeps old row versions for MVCC. If dead tuples are not cleaned or space is not reused efficiently, tables and indexes grow larger than needed. I would check dead tuples, table size trends, vacuum behavior, and long transactions. For fixes, I would prefer normal vacuum and tuning first, then online rebuild tools or scheduled rewrites for severe cases.”

### Symptoms

- Disk usage grows faster than data
- Query performance degrades
- Index scans become slower
- Vacuum takes longer
- Cache hit ratio worsens
- Backups become larger

### Basic size check

```sql
SELECT
    relname,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
    n_live_tup,
    n_dead_tup
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 20;
```

### Index size check

```sql
SELECT
    indexrelname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    idx_scan
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 20;
```

### Resolution options

Normal maintenance:

```sql
VACUUM (ANALYZE) large_table;
```

Rebuild an index online:

```sql
REINDEX INDEX CONCURRENTLY idx_large_table_col;
```

Severe table bloat options:

- `VACUUM FULL` during maintenance window
- `pg_repack` if available
- Partitioning or archiving old data
- Reducing update churn
- Lowering table fillfactor for hot update-heavy tables

Example fillfactor:

```sql
ALTER TABLE accounts SET (fillfactor = 80);
VACUUM FULL accounts;
```

### Takeaway summary

Bloat is a storage and performance issue. Fix the cause first, then reclaim space safely.

---

## 11. Replication lag

### Interview freeze point

Replication lag can be caused by the primary, replica, network, workload, or queries on the replica.

### Strong interview answer

> “I would first confirm whether lag is in bytes, time, or replay delay. Then I would check WAL generation on the primary, network throughput, replica replay speed, long-running queries on the replica, and whether replication slots are retaining WAL. The fix depends on which stage is lagging.”

### Symptoms

- Read replica returns stale data
- Replica falls behind during peak writes
- Disk fills on primary due to retained WAL
- Failover risk increases
- Backups or analytics on replica slow replay

### Primary-side check

```sql
SELECT
    application_name,
    state,
    sync_state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS replay_lag_bytes
FROM pg_stat_replication;
```

### Replica-side check

```sql
SELECT
    now() - pg_last_xact_replay_timestamp() AS replica_lag;
```

### Common causes

- High WAL generation
- Slow network
- Replica under-provisioned
- Long queries on replica delaying replay
- Replication slot retaining WAL
- Disk I/O bottleneck
- Large batch writes

### Resolution

- Tune or scale replica resources
- Reduce large write spikes
- Move heavy analytics elsewhere
- Set query timeouts on replicas
- Monitor replication slots
- Use appropriate synchronous or asynchronous replication strategy

Check slots:

```sql
SELECT
    slot_name,
    active,
    restart_lsn,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal
FROM pg_replication_slots;
```

### Takeaway summary

Replication lag is not one problem. It is a pipeline problem: send, write, flush, and replay.

---

## 12. WAL growth and disk pressure

### Interview freeze point

The disk is filling, but deleting rows may make it worse or not help immediately.

### Strong interview answer

> “I would identify whether disk growth is from table data, indexes, WAL, logs, temporary files, or replication slot retention. If WAL is growing, I would check archiving, replication slots, checkpoints, and replica lag. I would avoid deleting data blindly because deletes also generate WAL and may not reclaim space immediately.”

### Symptoms

- Database disk usage rising quickly
- `pg_wal` directory grows
- Primary at risk of running out of disk
- Replication slot retaining WAL
- Failed WAL archiving
- Long-running backup

### Disk usage query

```sql
SELECT
    pg_size_pretty(pg_database_size(current_database())) AS db_size;
```

Largest tables:

```sql
SELECT
    relname,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 20;
```

Replication slots:

```sql
SELECT
    slot_name,
    active,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal
FROM pg_replication_slots;
```

### Common causes

- Replica down while using replication slot
- WAL archiving failing
- Large batch updates/deletes
- Checkpoints poorly tuned
- Bulk load
- Logical replication consumer stopped

### Resolution examples

If a replication slot is inactive and no longer needed:

```sql
SELECT pg_drop_replication_slot('old_slot_name');
```

If a replica is still needed, do not drop the slot casually. First understand whether the replica can catch up.

For large deletes, prefer batches:

```sql
DELETE FROM events
WHERE created_at < now() - interval '90 days'
LIMIT 10000;
```

PostgreSQL does not support `LIMIT` directly in all delete forms, so a common pattern is:

```sql
DELETE FROM events
WHERE id IN (
  SELECT id
  FROM events
  WHERE created_at < now() - interval '90 days'
  LIMIT 10000
);
```

### Takeaway summary

When disk fills, first identify what is growing. WAL, table bloat, logs, and temp files have different fixes.

---

## 13. Checkpoint pressure

### Interview freeze point

Checkpoint issues often show up as random latency spikes. Candidates may miss this if they only think about queries.

### Strong interview answer

> “Checkpoints flush dirty pages to disk. If checkpoints are too frequent or too aggressive, they can cause I/O spikes and latency. I would check checkpoint frequency, WAL volume, write latency, and tune checkpoint settings carefully.”

### Symptoms

- Periodic latency spikes
- High write I/O
- Logs show frequent checkpoints
- Query latency worsens during write-heavy periods
- Storage saturation

### Useful logging

Enable checkpoint logging:

```sql
ALTER SYSTEM SET log_checkpoints = on;
SELECT pg_reload_conf();
```

Then inspect logs for checkpoint frequency and duration.

### Common causes

- `max_wal_size` too low
- Write-heavy workload
- Slow disks
- Bulk operations
- Checkpoints happening too often

### Resolution

Example tuning:

```sql
ALTER SYSTEM SET max_wal_size = '8GB';
ALTER SYSTEM SET checkpoint_timeout = '15min';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
SELECT pg_reload_conf();
```

### Important explanation

Increasing `max_wal_size` often reduces checkpoint frequency, but it can increase crash recovery time. That is a trade-off.

### Takeaway summary

Checkpoint tuning is about smoothing I/O, not just changing numbers.

---

## 14. Memory misconfiguration

### Interview freeze point

PostgreSQL memory settings are not always intuitive. More memory is not always better.

### Strong interview answer

> “I would look at memory from both global and per-operation settings. `shared_buffers` is global, but `work_mem` can be used many times per query and per connection. Setting `work_mem` too high can cause memory exhaustion under concurrency. I would tune based on workload, concurrency, and evidence of sorts or hashes spilling to disk.”

### Important settings

- `shared_buffers`
- `work_mem`
- `maintenance_work_mem`
- `effective_cache_size`
- `temp_buffers`
- OS page cache

### Symptoms

- Sorts spill to disk
- Hash joins spill
- Out-of-memory events
- Swapping
- Slow maintenance operations
- High temp file usage

### Detect temp file activity

Enable logging:

```sql
ALTER SYSTEM SET log_temp_files = 0;
SELECT pg_reload_conf();
```

Or set a threshold:

```sql
ALTER SYSTEM SET log_temp_files = '64MB';
SELECT pg_reload_conf();
```

### Example problem

A query sorts millions of rows:

```sql
SELECT *
FROM events
ORDER BY created_at;
```

If `work_mem` is too low, sort may spill to disk.

### Resolution

For one session:

```sql
SET work_mem = '128MB';
```

For a specific role:

```sql
ALTER ROLE reporting_user SET work_mem = '128MB';
```

Do not blindly set high globally:

```sql
ALTER SYSTEM SET work_mem = '512MB';
```

That can be dangerous if many connections run many sort/hash operations at once.

### Takeaway summary

Memory tuning must include concurrency. `work_mem` is powerful but dangerous when set too high globally.

---

## 15. Sorting and temporary files

### Interview freeze point

A query may be slow not because of missing indexes, but because it sorts or hashes too much data.

### Strong interview answer

> “I would check whether the query is creating temporary files or spilling sorts and hashes to disk. Then I would see if an index can support the order, whether the result set can be reduced earlier, or whether `work_mem` should be adjusted for that workload.”

### Symptoms

- High temp file usage
- Slow `ORDER BY`, `DISTINCT`, `GROUP BY`
- Disk I/O spikes
- Reports slow under load
- Logs show temp files

### Example query

```sql
SELECT customer_id, count(*)
FROM orders
GROUP BY customer_id
ORDER BY count(*) DESC;
```

This can require large sort/hash operations.

### Diagnosis

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, count(*)
FROM orders
GROUP BY customer_id
ORDER BY count(*) DESC;
```

Look for:

```text
Sort Method: external merge Disk: ...
```

That means the sort spilled to disk.

### Resolution options

- Add an index where it helps
- Filter earlier
- Aggregate smaller datasets
- Increase `work_mem` for reporting role
- Precompute summaries
- Use materialized views

Example materialized view:

```sql
CREATE MATERIALIZED VIEW customer_order_counts AS
SELECT customer_id, count(*) AS order_count
FROM orders
GROUP BY customer_id;

CREATE INDEX idx_customer_order_counts_count
ON customer_order_counts (order_count DESC);
```

Refresh:

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY customer_order_counts;
```

### Takeaway summary

Temp files are a signal. They often mean PostgreSQL needed more memory for a sort/hash or the query is processing too much data.

---

## 16. Bad joins and row explosion

### Interview freeze point

The query looks correct, but it returns too many rows or runs forever.

### Strong interview answer

> “I would check join cardinality. A missing join condition, wrong relationship assumption, or many-to-many join can explode row counts. I would inspect actual rows at each plan step and validate keys, uniqueness, and filters.”

### Example problem

```sql
SELECT *
FROM users u
JOIN orders o ON o.customer_id = u.id
JOIN order_items oi ON oi.order_id = o.id
JOIN product_tags pt ON pt.product_id = oi.product_id;
```

If products have many tags, each order item may multiply into many rows.

### Diagnosis

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT ...
```

Look for a plan node where rows jump sharply.

Also check assumptions:

```sql
SELECT product_id, count(*)
FROM product_tags
GROUP BY product_id
ORDER BY count(*) DESC
LIMIT 10;
```

### Resolution

- Add missing join predicates
- Use `EXISTS` instead of joins when checking existence
- Aggregate before joining
- Enforce uniqueness
- Add proper indexes
- Filter earlier

### Example: use `EXISTS`

Instead of:

```sql
SELECT DISTINCT u.*
FROM users u
JOIN orders o ON o.customer_id = u.id
WHERE o.status = 'paid';
```

Use:

```sql
SELECT u.*
FROM users u
WHERE EXISTS (
  SELECT 1
  FROM orders o
  WHERE o.customer_id = u.id
  AND o.status = 'paid'
);
```

### Takeaway summary

When joins are slow, do not only ask “which index is missing?” Ask “did the row count multiply?”

---

## 17. Transaction isolation surprises

### Interview freeze point

Many people use transactions daily but struggle to explain isolation levels.

### Strong interview answer

> “PostgreSQL defaults to Read Committed. Each statement sees a fresh committed snapshot. Repeatable Read keeps a stable snapshot for the whole transaction. Serializable provides stronger guarantees but can raise serialization failures that the application must retry.”

### Common isolation issues

- Seeing different results inside one transaction under Read Committed
- Serialization failures under Serializable
- Race conditions in check-then-insert logic
- Lost update patterns
- Confusion around row locks

### Example race condition

Bad pattern:

```sql
BEGIN;

SELECT count(*)
FROM bookings
WHERE room_id = 10
AND starts_at < '2026-06-01 11:00'
AND ends_at > '2026-06-01 10:00';

-- If count is 0, insert booking.

INSERT INTO bookings(room_id, starts_at, ends_at)
VALUES (10, '2026-06-01 10:00', '2026-06-01 11:00');

COMMIT;
```

Two transactions may both see count 0 and both insert.

### Resolution options

- Use constraints where possible
- Use row locks
- Use exclusion constraints for ranges
- Use Serializable with retries

Example exclusion constraint:

```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE bookings
ADD CONSTRAINT no_overlapping_bookings
EXCLUDE USING gist (
  room_id WITH =,
  tstzrange(starts_at, ends_at) WITH &&
);
```

### Takeaway summary

Transactions do not automatically prevent every race. Strong systems use constraints, locks, and retries deliberately.

---

## 18. Constraint and data integrity failures

### Interview freeze point

People often focus on app validation and forget that the database should protect core rules.

### Strong interview answer

> “I prefer enforcing critical data integrity in PostgreSQL, not only in application code. Constraints give stronger guarantees under concurrency. I would use primary keys, foreign keys, unique constraints, check constraints, and exclusion constraints depending on the rule.”

### Common issues

- Duplicate records
- Orphaned rows
- Invalid states
- Negative balances
- Overlapping bookings
- Application race conditions
- Soft-delete uniqueness problems

### Examples

Unique email:

```sql
ALTER TABLE users
ADD CONSTRAINT users_email_unique UNIQUE (email);
```

Positive balance:

```sql
ALTER TABLE accounts
ADD CONSTRAINT balance_non_negative CHECK (balance >= 0);
```

Foreign key:

```sql
ALTER TABLE orders
ADD CONSTRAINT orders_customer_fk
FOREIGN KEY (customer_id)
REFERENCES customers(id);
```

### Soft-delete uniqueness

Problem:

```text
A user can reuse an email only after the old account is soft-deleted.
```

Partial unique index:

```sql
CREATE UNIQUE INDEX users_active_email_unique
ON users (email)
WHERE deleted_at IS NULL;
```

### Resolution mindset

If data must always be true, put the rule in the database.

### Takeaway summary

Application validation improves user experience. Database constraints protect truth.

---

## 19. Partitioning mistakes

### Interview freeze point

Partitioning sounds like a performance feature, but it can hurt if used incorrectly.

### Strong interview answer

> “Partitioning helps when it matches access patterns, retention, or maintenance needs. It is not automatic performance magic. I would partition large time-series or tenant data only if queries can prune partitions and operations benefit from smaller physical chunks.”

### Good use cases

- Time-series data
- Large append-only tables
- Retention by date
- Tenant isolation at large scale
- Faster archival and deletion

### Bad use cases

- Small tables
- Queries that do not filter on partition key
- Too many tiny partitions
- Partition key not aligned with workload
- Expecting partitioning to replace indexes

### Example

Create partitioned table:

```sql
CREATE TABLE events (
    id bigint generated always as identity,
    account_id bigint not null,
    created_at timestamptz not null,
    event_type text not null,
    payload jsonb
) PARTITION BY RANGE (created_at);
```

Monthly partition:

```sql
CREATE TABLE events_2026_05
PARTITION OF events
FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
```

Query that prunes partitions:

```sql
SELECT *
FROM events
WHERE created_at >= '2026-05-01'
AND created_at < '2026-06-01';
```

Query that may scan many partitions:

```sql
SELECT *
FROM events
WHERE account_id = 123;
```

Unless partitioning or indexes support that access path, this may not help.

### Fast retention

```sql
DROP TABLE events_2025_01;
```

Dropping an old partition is much faster than deleting millions of rows.

### Takeaway summary

Partitioning is mainly about manageability and pruning. It works best when query filters and retention match the partition key.

---

## 20. Backup, restore, and disaster recovery gaps

### Interview freeze point

Many candidates say “we have backups,” but interviewers want proof that restores work.

### Strong interview answer

> “A backup strategy is only real if restores are tested. I would define RPO and RTO, use physical or logical backups as appropriate, enable WAL archiving for point-in-time recovery if needed, and regularly test restores in an isolated environment.”

### Key terms

- **RPO**: how much data loss is acceptable.
- **RTO**: how long recovery may take.
- **Logical backup**: SQL-level dump.
- **Physical backup**: file-level/base backup.
- **PITR**: point-in-time recovery using base backup plus WAL.

### Common issues

- Backups exist but restores are never tested
- WAL archiving broken
- Backups stored on same failure domain
- No clear RPO/RTO
- Large restore takes longer than expected
- Credentials or extensions missing
- Backup does not include roles or global objects

### Logical backup example

```bash
pg_dump -Fc -d appdb -f appdb.dump
```

Restore:

```bash
createdb appdb_restore
pg_restore -d appdb_restore appdb.dump
```

### Roles backup

```bash
pg_dumpall --globals-only > globals.sql
```

### Interview-safe answer

> “I would not claim the backup strategy is healthy until I have restored it and run validation checks.”

### Validation examples

After restore:

```sql
SELECT count(*) FROM critical_table;
```

Check application smoke tests, permissions, extensions, and expected data freshness.

### Takeaway summary

Backups are promises. Restores are proof.

---

# Bonus: interview answer frameworks

## Framework 1: The PostgreSQL incident answer

Use this when asked: “Production is slow. What do you do?”

```text
1. Confirm the symptom.
2. Check scope: one query, one service, one table, or whole database?
3. Check active sessions and waits.
4. Check top queries.
5. Inspect query plans.
6. Check locks, connections, CPU, memory, I/O, WAL, replication.
7. Apply the safest reversible fix first.
8. Verify with metrics.
9. Prevent recurrence.
```

Example answer:

> “I would first determine whether the issue is global or query-specific. If global, I would check connections, waits, locks, CPU, memory, disk I/O, WAL, and replication. If query-specific, I would use `pg_stat_statements` and `EXPLAIN (ANALYZE, BUFFERS)`. I would avoid making schema changes until I had evidence.”

---

## Framework 2: The slow query answer

```text
1. Capture the exact query.
2. Run EXPLAIN ANALYZE with BUFFERS.
3. Compare estimated rows to actual rows.
4. Find the expensive plan node.
5. Check index usage.
6. Check stale statistics.
7. Check sorting/hash spilling.
8. Rewrite query or add index if justified.
9. Re-run the plan.
```

---

## Framework 3: The locking answer

```text
1. Identify blocked sessions.
2. Identify blocking sessions.
3. Check transaction age.
4. Read the blocking query.
5. Decide whether to wait, cancel, or terminate.
6. Fix root cause: shorter transaction, safer migration, better indexes, consistent ordering.
```

---

## Framework 4: The capacity answer

```text
1. Separate connections from active work.
2. Measure CPU, memory, I/O, locks, and waits.
3. Check top queries and write volume.
4. Check autovacuum and bloat.
5. Check replication and WAL.
6. Tune pool sizes and workload shape.
7. Scale only after removing obvious waste.
```

---

# Common interview traps and better answers

## Trap 1: “Would you add an index?”

Weak answer:

> “Yes, I would add an index.”

Better answer:

> “Maybe. I would first inspect the plan and confirm whether the query is selective enough and whether the proposed index matches the filter, join, and sort pattern. I would also consider write overhead before adding it.”

---

## Trap 2: “Why is PostgreSQL doing a sequential scan?”

Weak answer:

> “Because the index is missing.”

Better answer:

> “A sequential scan can be correct if the query reads a large portion of the table, the index is not selective, statistics suggest many rows, or the planner estimates a seq scan is cheaper. I would compare estimates to actual rows.”

---

## Trap 3: “Can we just increase max_connections?”

Weak answer:

> “Yes.”

Better answer:

> “Increasing `max_connections` may make things worse if the database is already saturated. I would first check active versus idle sessions and use connection pooling. Throughput usually improves when concurrency is controlled.”

---

## Trap 4: “Can we kill the blocking query?”

Weak answer:

> “Yes, kill it.”

Better answer:

> “Only after understanding what it is doing. Killing a backend may roll back work and impact users. If it is safe and causing an outage, I may terminate it, but I would also fix why it held the lock.”

---

## Trap 5: “Are backups enough?”

Weak answer:

> “Yes, we run backups daily.”

Better answer:

> “Backups are not enough unless restores are tested. I would validate restore time, data freshness, roles, extensions, and application smoke tests against the RPO and RTO.”

---

# PostgreSQL interview quick-reference table

| Issue | Main symptom | First thing to check | Common fix |
|---|---|---|---|
| Slow query | One query is slow | `EXPLAIN (ANALYZE, BUFFERS)` | Index, rewrite, stats, memory |
| Missing index | Large scan | Query predicates and plan | Add matching index |
| Too many indexes | Slow writes | `pg_stat_user_indexes` | Drop duplicate/unused indexes carefully |
| Stale stats | Bad estimates | Estimated vs actual rows | `ANALYZE`, stats target |
| Locks | Queries hang | `pg_locks`, `pg_stat_activity` | Short transactions, safer DDL |
| Long transactions | Bloat, vacuum issues | `xact_start` age | Commit sooner, timeout idle transactions |
| Deadlocks | Transaction aborted | Logs | Consistent lock order, retries |
| Connection exhaustion | Too many connections | Connection states | Pooling, sane pool sizes |
| Autovacuum lag | Dead tuples high | `pg_stat_user_tables` | Tune autovacuum |
| Bloat | Disk growth | Table/index size | Vacuum, reindex, repack |
| Replication lag | Stale replica | `pg_stat_replication` | Tune replica, reduce WAL, fix slots |
| WAL growth | Disk filling | `pg_replication_slots` | Fix archiving/slots |
| Checkpoints | Latency spikes | Logs, WAL volume | Tune checkpoint settings |
| Memory | OOM or temp files | `work_mem`, temp logs | Tune per workload |
| Temp files | Slow sort/hash | Temp file logs | Filter earlier, tune work_mem |
| Bad joins | Row explosion | Actual rows per plan node | Fix joins, aggregate, indexes |
| Isolation | Race conditions | Transaction logic | Constraints, locks, retries |
| Constraints | Bad data | Schema rules | Add database constraints |
| Partitioning | Big table pain | Query access pattern | Partition by useful key |
| Backups | Recovery risk | Restore tests | PITR, tested restores |

---

# Strong closing takeaway

PostgreSQL interviews are not memory tests. They are judgment tests.

The interviewer wants to know whether you can stay calm, form a hypothesis, use PostgreSQL evidence, and choose a safe fix. You do not need to know every command by heart. You need to show that you understand how PostgreSQL behaves under load.

When you feel yourself freezing, return to this sentence:

> “I would verify the symptom, inspect the evidence, isolate the bottleneck, apply the safest fix, and confirm the result.”

That is the voice of someone who can be trusted with production.

---

# Final takeaway summaries

## The one-minute summary

PostgreSQL performance issues usually come from query plans, indexes, statistics, locks, connections, vacuum, memory, WAL, or workload shape. The best interview answer starts with diagnosis, not guesses. Use `EXPLAIN (ANALYZE, BUFFERS)`, `pg_stat_activity`, `pg_locks`, `pg_stat_statements`, `pg_stat_user_tables`, and replication views to prove the cause.

## The senior-engineer summary

A senior PostgreSQL operator does not randomly tune parameters. They reason from symptoms to evidence. They understand that every fix has a trade-off: indexes speed reads but slow writes, higher connection counts can reduce throughput, larger WAL settings can smooth checkpoints but affect recovery, and killing sessions may create rollback pain. Seniority is shown by calm diagnosis and safe change management.

## The interview survival summary

When you freeze, use this structure:

```text
Symptom → Scope → Evidence → Cause → Fix → Verify → Prevent
```

Example:

> “The symptom is slow checkout. I would check whether it affects one query or the whole database. I would inspect active waits, top queries, and the query plan. If the plan shows bad row estimates, I would check statistics. If it shows lock waits, I would find the blocker. Then I would make the smallest safe fix and verify latency improved.”

That structure will carry you through most PostgreSQL interview questions.
