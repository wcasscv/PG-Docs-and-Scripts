# Oracle: “I Know This Stuff, But in the Interview I Freeze” Kit

## Strong intro

You can know Oracle well and still freeze in an interview.

That freeze usually does not come from lack of experience. It comes from having real-world knowledge stored as incidents, troubleshooting habits, scripts, dashboards, and muscle memory — while the interview demands clean, structured answers on demand.

In production, you do not solve Oracle problems by reciting definitions. You ask what changed, check the wait events, inspect execution plans, look at sessions, validate statistics, review locking, and make the smallest safe change. In an interview, you need to explain that same thinking clearly in a minute or two.

This kit helps you do that.

It covers 20 common Oracle database issues interviewers ask about, with causes, diagnostic steps, resolutions, and examples. The goal is not to memorize every command. The goal is to build calm answer patterns you can reuse when your mind goes blank.

When you freeze, start here:

> “I would first confirm the symptom and scope. Then I would check whether the issue is SQL, execution plan, locking, waits, memory, storage, statistics, sessions, or configuration. I would use Oracle evidence — AWR, ASH, SQL Monitor, execution plans, wait events, and dynamic performance views — before changing anything.”

That answer already sounds like someone who can be trusted with production.

---

## How to use this kit

For each Oracle issue, learn this interview structure:

```text
Symptom → Scope → Evidence → Cause → Fix → Verify → Prevent
```

A strong Oracle troubleshooting answer usually includes:

- What the user sees.
- What you check first.
- Which Oracle views or tools you use.
- What the likely causes are.
- What safe fix you apply.
- How you verify the fix worked.
- How you prevent recurrence.

Example:

> “If a query is slow, I would not immediately add an index. I would check the execution plan, row estimates versus actuals, wait events, bind variables, statistics, and whether the query is CPU-bound, I/O-bound, or blocked. Then I would tune the SQL, statistics, indexes, or memory based on evidence.”

That is better than saying:

> “I would create an index.”

Oracle interviews reward diagnosis.

---

# Top 20 Oracle issues and resolutions

---

## 1. Slow SQL query

### Interview freeze point

The interviewer asks:

> “A query is slow in Oracle. What do you do?”

This question is broad. Many candidates freeze because there are too many possible causes.

### Strong interview answer

> “I would first identify whether the SQL is slow because of a bad execution plan, stale statistics, missing or unsuitable indexes, bind variable issues, locking, I/O waits, CPU pressure, or memory spills. I would check the execution plan with actual runtime information, SQL ID, wait events, and historical performance if AWR is available.”

### Common causes

- Bad execution plan
- Stale optimizer statistics
- Missing or wrong index
- Wrong join order
- Full table scan on large table
- Sort or hash join spilling to TEMP
- Bind variable peeking issue
- Data skew
- Blocking session
- I/O bottleneck
- CPU saturation
- Poor SQL design

### Useful diagnostic queries

Find active SQL:

```sql
SELECT
    s.sid,
    s.serial#,
    s.username,
    s.status,
    s.sql_id,
    s.event,
    s.wait_class,
    s.seconds_in_wait
FROM v$session s
WHERE s.status = 'ACTIVE'
AND s.username IS NOT NULL;
```

Get the execution plan for a SQL ID:

```sql
SELECT *
FROM table(dbms_xplan.display_cursor(
    sql_id => '&&sql_id',
    cursor_child_no => NULL,
    format => 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE'
));
```

Top SQL by elapsed time:

```sql
SELECT
    sql_id,
    executions,
    elapsed_time / 1000000 AS elapsed_seconds,
    cpu_time / 1000000 AS cpu_seconds,
    disk_reads,
    buffer_gets,
    rows_processed
FROM v$sql
ORDER BY elapsed_time DESC
FETCH FIRST 10 ROWS ONLY;
```

### Example problem

```sql
SELECT *
FROM orders
WHERE customer_id = 1001
ORDER BY created_at DESC
FETCH FIRST 20 ROWS ONLY;
```

If `orders` has millions of rows and no useful index, Oracle may scan and sort too much data.

### Resolution

Create an index that matches the filter and order:

```sql
CREATE INDEX idx_orders_customer_created
ON orders (customer_id, created_at DESC);
```

Then verify the plan:

```sql
SELECT *
FROM table(dbms_xplan.display_cursor(
    sql_id => '&&sql_id',
    format => 'ALLSTATS LAST'
));
```

### Interview caution

Do not say “always add an index.” A full table scan can be correct if the query reads a large percentage of the table.

### Takeaway summary

Slow SQL tuning starts with evidence: SQL ID, execution plan, actual rows, wait events, and resource usage.

---

## 2. Bad execution plan

### Interview freeze point

You know the query is slow, but the interviewer asks:

> “Why did Oracle choose a bad plan?”

### Strong interview answer

> “Oracle chooses plans based on optimizer statistics, object metadata, bind values, system statistics, and cost estimates. A bad plan often comes from stale stats, data skew, bind peeking, missing histograms, wrong cardinality estimates, or changed data volume. I would compare estimated rows to actual rows and check whether the optimizer’s assumptions are wrong.”

### Symptoms

- Query suddenly slower
- Same SQL has multiple child cursors
- Plan changed after stats gather
- Full table scan appears unexpectedly
- Wrong join method selected
- Nested loop used for huge row counts
- Hash join used where index access would be better

### Diagnostic query

```sql
SELECT *
FROM table(dbms_xplan.display_cursor(
    sql_id => '&&sql_id',
    format => 'ALLSTATS LAST +ADAPTIVE +PEEKED_BINDS'
));
```

Look for a big mismatch:

```text
E-Rows: 10
A-Rows: 500000
```

That means Oracle estimated 10 rows but actually processed 500,000.

### Common causes

- Stale statistics
- Missing histograms
- Bad bind variable peeking
- Data skew
- Missing extended statistics
- Function on indexed column
- Implicit conversion
- Plan regression after deployment
- Different optimizer settings

### Resolution options

Gather stats:

```sql
BEGIN
  dbms_stats.gather_table_stats(
    ownname => 'APP',
    tabname => 'ORDERS',
    cascade => TRUE
  );
END;
/
```

Create histogram for skewed data:

```sql
BEGIN
  dbms_stats.gather_table_stats(
    ownname    => 'APP',
    tabname    => 'ORDERS',
    method_opt => 'FOR COLUMNS SIZE AUTO status'
  );
END;
/
```

Use SQL Plan Management for stability:

```sql
DECLARE
  l_plans_loaded PLS_INTEGER;
BEGIN
  l_plans_loaded := dbms_spm.load_plans_from_cursor_cache(
    sql_id => '&&sql_id'
  );
END;
/
```

### Takeaway summary

Bad plans are usually bad assumptions. Find where Oracle’s estimated rows diverge from actual rows.

---

## 3. Stale or missing optimizer statistics

### Interview freeze point

People remember “gather stats,” but often cannot explain why.

### Strong interview answer

> “The optimizer depends on statistics to estimate cardinality and cost. If statistics are stale, missing, or not representative of skewed data, Oracle can choose poor plans. I would check table stats freshness, row counts, histograms, and whether recent data changes invalidated assumptions.”

### Symptoms

- Query plan changed
- Full table scans on large tables
- Wrong join method
- Poor cardinality estimates
- Query became slow after bulk load
- Partition queries behave poorly

### Diagnostic query

```sql
SELECT
    owner,
    table_name,
    num_rows,
    blocks,
    last_analyzed,
    stale_stats
FROM dba_tab_statistics
WHERE owner = 'APP'
AND table_name = 'ORDERS';
```

Check column stats:

```sql
SELECT
    column_name,
    num_distinct,
    density,
    histogram,
    last_analyzed
FROM dba_tab_col_statistics
WHERE owner = 'APP'
AND table_name = 'ORDERS';
```

### Resolution

Gather schema stats:

```sql
BEGIN
  dbms_stats.gather_schema_stats(
    ownname => 'APP',
    cascade => TRUE,
    options => 'GATHER AUTO'
  );
END;
/
```

Gather stats after bulk load:

```sql
BEGIN
  dbms_stats.gather_table_stats(
    ownname => 'APP',
    tabname => 'ORDERS',
    estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
    cascade => TRUE
  );
END;
/
```

### Important nuance

Stats gathering can also cause plan changes. In critical systems, stats changes should be monitored and tested.

### Takeaway summary

Optimizer stats are the map Oracle uses to choose a route. If the map is wrong, the route may be wrong.

---

## 4. Missing or ineffective indexes

### Interview freeze point

The interviewer asks:

> “How do you know an index will help?”

### Strong interview answer

> “An index helps when it supports selective filtering, joins, sorting, or uniqueness. I would check the query predicates, column order, selectivity, clustering factor, and whether functions or implicit conversions prevent index use.”

### Common causes

- No index on filtered column
- Composite index columns in poor order
- Function used on indexed column
- Implicit data type conversion
- Low selectivity
- Poor clustering factor
- Index exists but not useful for the query
- Query reads too much of the table

### Example: index not used due to function

```sql
SELECT *
FROM users
WHERE UPPER(email) = 'JACK@EXAMPLE.COM';
```

Index on `email` may not help because the function changes the expression.

### Resolution: function-based index

```sql
CREATE INDEX idx_users_upper_email
ON users (UPPER(email));
```

### Example: composite index

Query:

```sql
SELECT *
FROM orders
WHERE customer_id = 1001
AND status = 'OPEN'
ORDER BY created_at DESC;
```

Index:

```sql
CREATE INDEX idx_orders_customer_status_created
ON orders (customer_id, status, created_at DESC);
```

### Check index usage in plan

```sql
SELECT *
FROM table(dbms_xplan.display_cursor(
    sql_id => '&&sql_id',
    format => 'ALLSTATS LAST'
));
```

### Interview caution

Indexes are not free. They increase DML cost, storage, redo, undo, and maintenance.

### Takeaway summary

A useful index matches the workload. It must support how the SQL filters, joins, sorts, or enforces rules.

---

## 5. Too many indexes and slow DML

### Interview freeze point

Most candidates know indexes help SELECTs. Fewer explain how they hurt INSERT, UPDATE, and DELETE.

### Strong interview answer

> “Each DML operation must maintain affected indexes. Too many indexes can slow writes, increase redo and undo, consume storage, and cause more contention. I would review duplicate, unused, and overlapping indexes before adding new ones.”

### Symptoms

- Inserts are slow
- Updates are slow
- High redo generation
- High undo usage
- Batch loads take too long
- Index maintenance dominates runtime
- Storage growth from indexes

### Diagnostic query

Find indexes on a table:

```sql
SELECT
    index_name,
    uniqueness,
    status,
    distinct_keys,
    clustering_factor,
    num_rows,
    last_analyzed
FROM dba_indexes
WHERE owner = 'APP'
AND table_name = 'ORDERS'
ORDER BY index_name;
```

Find index columns:

```sql
SELECT
    index_name,
    column_position,
    column_name
FROM dba_ind_columns
WHERE table_owner = 'APP'
AND table_name = 'ORDERS'
ORDER BY index_name, column_position;
```

### Example

These may overlap:

```sql
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_customer_status ON orders(customer_id, status);
CREATE INDEX idx_orders_customer_status_date ON orders(customer_id, status, created_at);
```

The shorter indexes may or may not be redundant depending on workload.

### Resolution

- Identify duplicate or overlapping indexes.
- Confirm no critical query depends on them.
- Drop only after monitoring and testing.

```sql
DROP INDEX app.idx_orders_customer;
```

For large systems, consider making an index invisible first:

```sql
ALTER INDEX app.idx_orders_customer INVISIBLE;
```

If no issue appears, drop it later.

### Takeaway summary

Indexes are performance tools with a cost. Too many indexes can make write-heavy systems slower.

---

## 6. Locking and blocking sessions

### Interview freeze point

The app hangs, but nothing looks “slow.” It may be waiting on a lock.

### Strong interview answer

> “I would check whether sessions are blocked, identify the blocking session, inspect the SQL and transaction age, then decide whether to wait, kill, or fix the application pattern. The root cause is often long transactions, uncommitted changes, missing indexes on foreign keys, or DDL locking.”

### Symptoms

- Query hangs
- Application requests timeout
- DML waits
- Deployment stuck
- Many sessions waiting on one blocker
- Wait events show enqueue waits

### Diagnostic query

```sql
SELECT
    s.sid,
    s.serial#,
    s.username,
    s.status,
    s.blocking_session,
    s.event,
    s.wait_class,
    s.seconds_in_wait,
    s.sql_id
FROM v$session s
WHERE s.blocking_session IS NOT NULL;
```

Find blocker details:

```sql
SELECT
    sid,
    serial#,
    username,
    machine,
    program,
    status,
    sql_id,
    event,
    logon_time
FROM v$session
WHERE sid = &&blocking_sid;
```

### Lock details

```sql
SELECT
    l.session_id,
    o.owner,
    o.object_name,
    o.object_type,
    l.locked_mode
FROM v$locked_object l
JOIN dba_objects o
    ON l.object_id = o.object_id;
```

### Resolution options

- Commit or rollback the blocking transaction.
- Tune the blocking SQL.
- Add missing foreign key indexes.
- Make transactions shorter.
- Use safer deployment windows.
- Kill only when necessary.

Kill session:

```sql
ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;
```

### Interview caution

Killing a session may trigger rollback, which can also take time.

### Takeaway summary

Blocking is not always a database failure. It is often a transaction design or application behavior problem.

---

## 7. Deadlocks

### Interview freeze point

Deadlocks sound dramatic, but in Oracle they are usually caused by inconsistent locking order or missing indexes on foreign keys.

### Strong interview answer

> “A deadlock occurs when sessions wait on each other in a cycle. Oracle detects it and rolls back one statement. I would inspect the deadlock trace file, identify the SQL and objects involved, then fix lock ordering, transaction scope, or missing foreign key indexes.”

### Symptoms

- ORA-00060 deadlock detected
- One statement fails while transaction may remain active
- Trace file generated
- Happens intermittently under concurrency

### Common causes

- Two sessions update rows in different order
- Missing index on foreign key
- Application locks parent/child rows inconsistently
- Triggers update tables in unexpected order
- Long transactions

### Example deadlock pattern

Session A:

```sql
UPDATE accounts SET balance = balance - 100 WHERE account_id = 1;
UPDATE accounts SET balance = balance + 100 WHERE account_id = 2;
```

Session B:

```sql
UPDATE accounts SET balance = balance - 50 WHERE account_id = 2;
UPDATE accounts SET balance = balance + 50 WHERE account_id = 1;
```

### Resolution

Lock rows in a consistent order:

```sql
SELECT *
FROM accounts
WHERE account_id IN (1, 2)
ORDER BY account_id
FOR UPDATE;
```

Then perform updates.

### Foreign key index check

```sql
SELECT
    c.owner,
    c.table_name,
    c.constraint_name,
    cc.column_name
FROM dba_constraints c
JOIN dba_cons_columns cc
    ON c.owner = cc.owner
   AND c.constraint_name = cc.constraint_name
WHERE c.constraint_type = 'R'
AND c.owner = 'APP';
```

Make sure child foreign key columns are indexed where needed.

### Takeaway summary

Deadlocks are usually fixed in application transaction order, schema indexing, or trigger behavior — not by a magic database setting.

---

## 8. High CPU usage

### Interview freeze point

High CPU does not automatically mean “add CPU.” It may mean inefficient SQL.

### Strong interview answer

> “I would identify which SQL statements or sessions are consuming CPU. Then I would check execution plans, logical reads, parse activity, PL/SQL loops, and inefficient joins. If SQL is already efficient and workload is valid, then I would consider capacity scaling.”

### Symptoms

- Database CPU near 100%
- Application latency increases
- High buffer gets
- Top SQL consumes CPU
- Hard parse spikes
- Reports or batch jobs overload system

### Diagnostic query

Top SQL by CPU:

```sql
SELECT
    sql_id,
    executions,
    cpu_time / 1000000 AS cpu_seconds,
    elapsed_time / 1000000 AS elapsed_seconds,
    buffer_gets,
    rows_processed
FROM v$sql
ORDER BY cpu_time DESC
FETCH FIRST 10 ROWS ONLY;
```

Active sessions:

```sql
SELECT
    sid,
    serial#,
    username,
    sql_id,
    event,
    wait_class,
    state
FROM v$session
WHERE status = 'ACTIVE'
AND username IS NOT NULL;
```

### Common causes

- Inefficient SQL
- Too many logical reads
- Cartesian join
- Poor indexes
- High hard parsing
- PL/SQL row-by-row processing
- Excessive concurrent workload
- Bad plan after stats change

### Resolution

- Tune top SQL
- Reduce logical reads
- Add or adjust indexes
- Use bind variables
- Avoid row-by-row processing
- Control concurrency
- Scale CPU only after tuning waste

### Example: row-by-row problem

Bad PL/SQL style:

```sql
FOR r IN (SELECT order_id FROM orders WHERE status = 'OPEN') LOOP
  UPDATE orders SET processed_flag = 'Y' WHERE order_id = r.order_id;
END LOOP;
```

Better set-based SQL:

```sql
UPDATE orders
SET processed_flag = 'Y'
WHERE status = 'OPEN';
```

### Takeaway summary

High CPU is often caused by inefficient SQL doing too much work. Find the top consumers before adding hardware.

---

## 9. I/O bottlenecks

### Interview freeze point

A query is slow, but CPU is not high. The system may be waiting on storage.

### Strong interview answer

> “I would check wait events and determine whether sessions are waiting on single-block reads, multiblock reads, direct path reads, log file sync, or TEMP I/O. Then I would map the wait to SQL, execution plans, storage, and workload patterns.”

### Symptoms

- High latency with low CPU
- Wait events related to reads or writes
- Slow full table scans
- Slow index lookups
- Slow commits
- TEMP usage
- Storage queue depth high

### Common wait events

- `db file sequential read`
- `db file scattered read`
- `direct path read`
- `direct path write temp`
- `log file sync`
- `log file parallel write`

### Diagnostic query

```sql
SELECT
    event,
    total_waits,
    time_waited / 100 AS time_waited_seconds,
    average_wait / 100 AS avg_wait_seconds
FROM v$system_event
WHERE wait_class <> 'Idle'
ORDER BY time_waited DESC
FETCH FIRST 20 ROWS ONLY;
```

Session waits:

```sql
SELECT
    sid,
    serial#,
    sql_id,
    event,
    wait_class,
    seconds_in_wait
FROM v$session
WHERE status = 'ACTIVE'
AND wait_class <> 'Idle';
```

### Resolution options

- Tune SQL to reduce physical reads
- Improve indexes
- Reduce full scans if inappropriate
- Increase cache effectiveness
- Move hot data to faster storage
- Fix TEMP spills
- Review storage latency
- Tune commit behavior for `log file sync`

### Takeaway summary

I/O tuning starts by identifying what type of I/O wait is dominant and which SQL causes it.

---

## 10. TEMP tablespace exhaustion

### Interview freeze point

TEMP fills up and people often think “just add space.” That may be necessary, but it may not be the root cause.

### Strong interview answer

> “TEMP is used for sorts, hash joins, global temporary tables, index builds, and other operations. If TEMP fills, I would identify the sessions and SQL consuming TEMP, then tune the SQL, increase memory if appropriate, or add TEMP space as a safe short-term fix.”

### Symptoms

- ORA-01652 unable to extend temp segment
- Reports fail
- Large sorts fail
- Hash joins spill
- Index creation fails
- TEMP files grow quickly

### Diagnostic query

Current TEMP usage:

```sql
SELECT
    s.sid,
    s.serial#,
    s.username,
    s.sql_id,
    u.tablespace,
    u.blocks * t.block_size / 1024 / 1024 AS mb_used
FROM v$tempseg_usage u
JOIN v$session s
    ON u.session_addr = s.saddr
JOIN dba_tablespaces t
    ON u.tablespace = t.tablespace_name
ORDER BY mb_used DESC;
```

TEMP files:

```sql
SELECT
    tablespace_name,
    file_name,
    bytes / 1024 / 1024 AS mb
FROM dba_temp_files;
```

### Common causes

- Large sort
- Large hash join
- Missing filter
- Bad join order
- `DISTINCT` on huge result set
- Index rebuild
- Parallel query
- Reporting workload

### Resolution

Short-term:

```sql
ALTER TABLESPACE temp
ADD TEMPFILE '/u02/oradata/DB/temp02.dbf'
SIZE 10G AUTOEXTEND ON NEXT 1G MAXSIZE 50G;
```

Root-cause fixes:

- Tune SQL plan
- Add selective filters
- Add useful indexes
- Increase PGA target if appropriate
- Reduce parallelism
- Break large jobs into chunks
- Use pre-aggregated tables or materialized views

### Takeaway summary

Adding TEMP may stop the outage, but tuning the SQL prevents the repeat incident.

---

## 11. Undo tablespace issues

### Interview freeze point

Undo is often confused with redo. In interviews, clear distinction matters.

### Strong interview answer

> “Undo stores before-images for read consistency and rollback. Undo issues happen when long queries need old versions, long transactions generate too much undo, or undo retention is insufficient. I would check undo usage, long transactions, ORA-01555 errors, and retention settings.”

### Symptoms

- ORA-01555 snapshot too old
- ORA-30036 unable to extend undo segment
- Long query fails
- Large DML fails
- Undo tablespace fills
- Rollback takes long time

### Diagnostic queries

Undo usage:

```sql
SELECT
    tablespace_name,
    status,
    SUM(bytes) / 1024 / 1024 AS mb
FROM dba_undo_extents
GROUP BY tablespace_name, status;
```

Long transactions:

```sql
SELECT
    s.sid,
    s.serial#,
    s.username,
    t.start_time,
    t.used_ublk,
    t.used_urec,
    s.sql_id
FROM v$transaction t
JOIN v$session s
    ON t.ses_addr = s.saddr
ORDER BY t.used_ublk DESC;
```

### Common causes

- Large update/delete
- Long-running query
- Undo retention too low
- Undo tablespace too small
- Batch job without commits
- Heavy concurrent DML

### Resolution

Increase undo tablespace:

```sql
ALTER DATABASE DATAFILE '/u02/oradata/DB/undotbs01.dbf'
AUTOEXTEND ON NEXT 1G MAXSIZE 50G;
```

Tune retention:

```sql
ALTER SYSTEM SET undo_retention = 3600;
```

Break large DML into batches where safe:

```sql
DELETE FROM audit_log
WHERE created_at < SYSDATE - 90
AND ROWNUM <= 10000;
```

### Important nuance

Frequent commits are not always better. They can make business consistency harder and may not solve all undo issues. Batch carefully.

### Takeaway summary

Undo protects read consistency and rollback. Long queries and large DML are the usual pressure points.

---

## 12. Redo log and commit latency

### Interview freeze point

Users report slow commits. The root cause may be redo log writes.

### Strong interview answer

> “For slow commits, I would check `log file sync` waits. That means sessions are waiting for commit confirmation. Then I would check redo log I/O latency, commit frequency, storage performance, redo size, and whether the application commits too often.”

### Symptoms

- Slow commits
- High `log file sync`
- High `log file parallel write`
- Application latency on write transactions
- Redo logs switching too frequently
- Storage latency on redo disks

### Diagnostic query

```sql
SELECT
    event,
    total_waits,
    time_waited / 100 AS seconds_waited,
    average_wait / 100 AS avg_wait_seconds
FROM v$system_event
WHERE event IN ('log file sync', 'log file parallel write');
```

Redo log switches:

```sql
SELECT
    TO_CHAR(first_time, 'YYYY-MM-DD HH24') AS hour,
    COUNT(*) AS switches
FROM v$log_history
GROUP BY TO_CHAR(first_time, 'YYYY-MM-DD HH24')
ORDER BY hour DESC;
```

### Common causes

- Slow redo storage
- Too many commits
- Small redo logs
- Excessive redo generation
- Synchronous Data Guard latency
- Write-heavy workload
- Index-heavy DML

### Resolution options

- Put redo logs on low-latency storage
- Reduce excessive commits
- Increase redo log size if switching too often
- Tune DML and indexes
- Review synchronous replication latency
- Batch writes safely

Example add redo log group:

```sql
ALTER DATABASE ADD LOGFILE GROUP 4
('/u02/oradata/DB/redo04a.log', '/u03/oradata/DB/redo04b.log')
SIZE 1024M;
```

### Takeaway summary

Slow commits often mean redo write pressure. Check `log file sync`, commit frequency, and redo storage latency.

---

## 13. Tablespace full

### Interview freeze point

The obvious answer is “add space,” but a better answer includes cause and prevention.

### Strong interview answer

> “I would first identify which tablespace is full, whether autoextend is enabled, what segments are growing, and whether growth is expected. As a short-term fix, I may add or resize a datafile. Then I would address root causes such as runaway loads, index growth, LOB growth, audit data, or missing retention.”

### Symptoms

- ORA-01653 unable to extend table
- ORA-01654 unable to extend index
- ORA-01691 unable to extend LOB segment
- Inserts fail
- Index rebuild fails
- Batch load stops

### Tablespace usage

```sql
SELECT
    df.tablespace_name,
    ROUND(df.bytes / 1024 / 1024) AS total_mb,
    ROUND(fs.free_bytes / 1024 / 1024) AS free_mb,
    ROUND((df.bytes - fs.free_bytes) / df.bytes * 100, 2) AS pct_used
FROM
    (SELECT tablespace_name, SUM(bytes) bytes
     FROM dba_data_files
     GROUP BY tablespace_name) df
LEFT JOIN
    (SELECT tablespace_name, SUM(bytes) free_bytes
     FROM dba_free_space
     GROUP BY tablespace_name) fs
ON df.tablespace_name = fs.tablespace_name
ORDER BY pct_used DESC;
```

Largest segments:

```sql
SELECT
    owner,
    segment_name,
    segment_type,
    tablespace_name,
    bytes / 1024 / 1024 AS mb
FROM dba_segments
WHERE tablespace_name = 'APP_DATA'
ORDER BY bytes DESC
FETCH FIRST 20 ROWS ONLY;
```

### Short-term resolution

Add datafile:

```sql
ALTER TABLESPACE app_data
ADD DATAFILE '/u02/oradata/DB/app_data02.dbf'
SIZE 20G AUTOEXTEND ON NEXT 1G MAXSIZE 100G;
```

Resize datafile:

```sql
ALTER DATABASE DATAFILE '/u02/oradata/DB/app_data01.dbf'
RESIZE 50G;
```

### Root-cause fixes

- Archive old data
- Purge audit/log tables
- Partition large tables
- Compress suitable data
- Rebuild bloated indexes when justified
- Monitor growth trends
- Fix runaway jobs

### Takeaway summary

Adding space fixes the symptom. Understanding segment growth prevents the next outage.

---

## 14. Fragmentation and high-water mark issues

### Interview freeze point

A table has deleted many rows, but space does not return to the OS. This surprises people.

### Strong interview answer

> “Oracle segments have a high-water mark. Deleting rows frees space for reuse inside the segment, but it does not automatically lower the high-water mark or shrink the datafile. I would check segment size, free space, and whether shrink, move, rebuild, or partition maintenance is appropriate.”

### Symptoms

- Table still large after deletes
- Full scan remains slow
- Space not returned to tablespace or OS
- Segment size much larger than live data
- High-water mark remains high

### Check segment size

```sql
SELECT
    owner,
    segment_name,
    segment_type,
    bytes / 1024 / 1024 AS mb
FROM dba_segments
WHERE owner = 'APP'
AND segment_name = 'ORDERS';
```

### Resolution options

Enable row movement and shrink:

```sql
ALTER TABLE app.orders ENABLE ROW MOVEMENT;

ALTER TABLE app.orders SHRINK SPACE;
```

Move table:

```sql
ALTER TABLE app.orders MOVE;
```

Then rebuild indexes if needed:

```sql
ALTER INDEX app.idx_orders_customer REBUILD;
```

Partition maintenance can be better:

```sql
ALTER TABLE app.orders DROP PARTITION orders_2024_q1;
```

### Important caution

Table moves and shrink operations can affect indexes, locks, and availability. Plan carefully.

### Takeaway summary

Deletes remove rows, not necessarily allocated segment space. Understand the high-water mark before promising reclaimed disk.

---

## 15. PGA, SGA, and memory pressure

### Interview freeze point

Oracle memory has several moving parts. Candidates often list parameters without explaining symptoms.

### Strong interview answer

> “I would separate SGA and PGA issues. SGA helps cache data and shared SQL. PGA is used for session work areas such as sorts and hash joins. Memory pressure may show as physical reads, hard parsing, TEMP spills, or OS swapping. I would tune based on evidence, not just increase memory.”

### Key areas

- SGA
- Buffer cache
- Shared pool
- Library cache
- PGA
- Work areas
- TEMP spills
- Automatic memory management

### Symptoms

- High physical reads
- Shared pool errors
- Hard parse pressure
- TEMP spills
- ORA-04031 unable to allocate shared memory
- OS swapping
- Slow sorts and hash joins

### Diagnostic queries

PGA advice:

```sql
SELECT
    pga_target_for_estimate / 1024 / 1024 AS pga_mb,
    estd_pga_cache_hit_percentage,
    estd_overalloc_count
FROM v$pga_target_advice
ORDER BY pga_target_for_estimate;
```

SGA advice:

```sql
SELECT
    sga_size / 1024 / 1024 AS sga_mb,
    estd_db_time
FROM v$sga_target_advice
ORDER BY sga_size;
```

Library cache reloads:

```sql
SELECT
    namespace,
    pins,
    reloads,
    invalidations
FROM v$librarycache;
```

### Resolution options

- Increase PGA if work areas spill and memory is available
- Tune SQL to avoid huge sorts/hashes
- Increase SGA/buffer cache if physical reads are excessive and cacheable
- Use bind variables to reduce hard parsing
- Avoid OS swapping
- Review memory advisors

Example:

```sql
ALTER SYSTEM SET pga_aggregate_target = 8G SCOPE=BOTH;
```

### Takeaway summary

Oracle memory tuning is workload-specific. Diagnose whether the pressure is cache, parse, sort, hash, or OS related.

---

## 16. Hard parsing and shared pool problems

### Interview freeze point

High CPU and latch/mutex waits can come from excessive parsing, not query execution.

### Strong interview answer

> “Hard parsing is expensive because Oracle must check syntax, permissions, objects, optimize the statement, and allocate shared pool memory. If an application sends many unique literals instead of bind variables, it can cause high CPU, shared pool pressure, and library cache contention.”

### Symptoms

- High CPU
- Many similar SQL statements
- Low cursor reuse
- Library cache waits
- Shared pool pressure
- ORA-04031
- High parse count

### Diagnostic query

Parse stats:

```sql
SELECT
    name,
    value
FROM v$sysstat
WHERE name IN (
    'parse count (total)',
    'parse count (hard)',
    'execute count'
);
```

Find similar SQL with literals:

```sql
SELECT
    force_matching_signature,
    COUNT(*) AS sql_count,
    SUM(executions) AS executions
FROM v$sql
WHERE force_matching_signature <> 0
GROUP BY force_matching_signature
HAVING COUNT(*) > 10
ORDER BY sql_count DESC
FETCH FIRST 20 ROWS ONLY;
```

### Bad pattern

```sql
SELECT * FROM orders WHERE order_id = 1001;
SELECT * FROM orders WHERE order_id = 1002;
SELECT * FROM orders WHERE order_id = 1003;
```

### Better pattern

```sql
SELECT * FROM orders WHERE order_id = :order_id;
```

### Resolution

- Use bind variables
- Fix ORM settings
- Avoid dynamic SQL with literal values
- Use cursor sharing carefully
- Size shared pool appropriately
- Reduce unnecessary invalidations

Possible emergency mitigation:

```sql
ALTER SYSTEM SET cursor_sharing = FORCE SCOPE=BOTH;
```

### Interview caution

`cursor_sharing=FORCE` can help temporarily, but it may cause plan issues. Fixing application SQL is better.

### Takeaway summary

Hard parsing is wasted work. Bind variables and cursor reuse are key to scalable Oracle applications.

---

## 17. RAC cluster contention

### Interview freeze point

RAC questions can be intimidating. Keep the answer focused on global cache and workload design.

### Strong interview answer

> “In RAC, multiple instances access the same database. Performance issues can come from interconnect latency, global cache waits, hot blocks, sequence contention, or workloads bouncing between nodes. I would check RAC-specific wait events and whether the application workload is partitioned or causing cross-instance block transfers.”

### Symptoms

- Performance worse on RAC than single instance
- High `gc` wait events
- Hot block contention
- Interconnect latency
- Sequence contention
- Cache fusion overhead
- Sessions on different nodes fight for same blocks

### Common wait events

- `gc current block busy`
- `gc cr block busy`
- `gc buffer busy acquire`
- `gc current grant busy`
- `gc cr request`

### Diagnostic query

```sql
SELECT
    inst_id,
    event,
    total_waits,
    time_waited / 100 AS seconds_waited
FROM gv$system_event
WHERE event LIKE 'gc %'
ORDER BY time_waited DESC;
```

Active sessions across instances:

```sql
SELECT
    inst_id,
    sid,
    serial#,
    username,
    sql_id,
    event,
    wait_class
FROM gv$session
WHERE status = 'ACTIVE'
AND username IS NOT NULL;
```

### Common causes

- Hot index blocks
- Monotonically increasing indexes
- Sequence hot spots
- Poor service placement
- Same hot rows updated from multiple instances
- Batch jobs spread across nodes unnecessarily

### Resolution options

- Use services to route workloads
- Keep related workload on same instance where useful
- Reduce hot block updates
- Review sequence caching
- Use reverse key indexes only when appropriate
- Partition data/workload
- Check interconnect health

Example sequence cache:

```sql
ALTER SEQUENCE order_seq CACHE 1000;
```

### Takeaway summary

RAC does not make bad workload design disappear. It adds scale, but cross-instance block contention must be managed.

---

## 18. Data Guard replication lag or apply issues

### Interview freeze point

Data Guard issues can involve transport, apply, network, standby resources, or archive gaps.

### Strong interview answer

> “I would separate transport lag from apply lag. Transport lag means redo is not reaching the standby fast enough. Apply lag means redo arrived but is not being applied fast enough. I would check Data Guard status, archive gaps, managed recovery, standby wait events, and network/storage performance.”

### Symptoms

- Standby behind primary
- Apply lag increasing
- Archive logs missing
- Failover readiness risk
- Read-only standby stale
- Managed recovery stopped

### Diagnostic queries

Database role:

```sql
SELECT
    database_role,
    open_mode,
    protection_mode,
    protection_level
FROM v$database;
```

Managed standby:

```sql
SELECT
    process,
    status,
    sequence#,
    block#,
    blocks
FROM v$managed_standby;
```

Archive gaps:

```sql
SELECT *
FROM v$archive_gap;
```

Data Guard stats:

```sql
SELECT
    name,
    value,
    unit
FROM v$dataguard_stats;
```

### Common causes

- Network throughput issue
- Standby I/O too slow
- Apply process stopped
- Archive log gap
- Primary generating redo faster than standby can apply
- Synchronous mode latency
- Standby queries delaying apply

### Resolution options

- Restart managed recovery if stopped
- Resolve archive gaps
- Tune standby I/O
- Increase apply parallelism where appropriate
- Reduce redo spikes
- Review network latency
- Use real-time apply if configured and suitable

Start managed recovery:

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
```

Cancel recovery:

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;
```

### Takeaway summary

Data Guard lag must be split into transport lag and apply lag. Each has different causes and fixes.

---

## 19. Backup and recovery gaps

### Interview freeze point

A candidate says “we use RMAN,” but the interviewer wants operational confidence.

### Strong interview answer

> “A backup strategy is only valid if restores are tested. I would define RPO and RTO, use RMAN backups, archive logs for point-in-time recovery, validate backups, test restores, and monitor backup failures. I would also confirm control file, spfile, encryption wallet, and archive logs are protected.”

### Key concepts

- RMAN backup
- Archivelog mode
- Point-in-time recovery
- Control file autobackup
- Backup validation
- Restore testing
- RPO and RTO
- Offsite copies
- Encryption wallet backup

### Check archive mode

```sql
ARCHIVE LOG LIST;
```

RMAN backup example

```rman
BACKUP DATABASE PLUS ARCHIVELOG;
```

Validate backup:

```rman
RESTORE DATABASE VALIDATE;
```

Crosscheck:

```rman
CROSSCHECK BACKUP;
DELETE EXPIRED BACKUP;
```

### Common issues

- Backups exist but restore was never tested
- Archive logs missing
- Backup pieces deleted outside RMAN
- Control file not backed up
- Wallet not backed up for encrypted DB
- Recovery time exceeds business need
- Backups on same storage failure domain

### Resolution

- Enable control file autobackup:

```rman
CONFIGURE CONTROLFILE AUTOBACKUP ON;
```

- Test restore regularly.
- Keep backups off-host and offsite.
- Monitor backup jobs.
- Document recovery steps.
- Align backup frequency with RPO/RTO.

### Interview-safe phrase

> “I do not consider backups healthy until I have restored from them.”

### Takeaway summary

Backups are assumptions. Restores are proof.

---

## 20. Privileges, roles, and security misconfiguration

### Interview freeze point

Security questions are easy to answer too generally. Be specific.

### Strong interview answer

> “I would apply least privilege. Users should have only the privileges they need, preferably through roles for human users and direct grants where stored procedures require them. I would audit powerful privileges, avoid shared accounts, rotate credentials, and protect sensitive data with encryption or masking where required.”

### Symptoms

- Application fails with ORA-01031 insufficient privileges
- Stored procedure works manually but fails in execution
- Users have excessive privileges
- Shared schemas used by many people
- Audit findings
- Production data exposed in lower environments

### Check user privileges

```sql
SELECT *
FROM dba_sys_privs
WHERE grantee = 'APP_USER';

SELECT *
FROM dba_tab_privs
WHERE grantee = 'APP_USER';

SELECT *
FROM dba_role_privs
WHERE grantee = 'APP_USER';
```

### Common issue: roles inside stored procedures

Definer-rights stored procedures do not use privileges granted through roles in the same way interactive sessions do. Required object privileges often need direct grants.

Example:

```sql
GRANT SELECT ON app.orders TO reporting_user;
```

Not only through a role if a stored procedure needs direct access.

### Resolution options

- Use least privilege
- Avoid granting `DBA` casually
- Use roles for manageability
- Use direct grants where PL/SQL requires them
- Audit powerful privileges
- Use separate accounts per application/service
- Rotate passwords and secrets
- Use Transparent Data Encryption where required
- Mask production data in non-production

### Example least-privilege grant

```sql
GRANT SELECT, INSERT, UPDATE ON app.orders TO app_user;
GRANT SELECT ON app.customers TO app_user;
```

Avoid:

```sql
GRANT DBA TO app_user;
```

### Takeaway summary

Security misconfiguration is a production risk. Least privilege and clear ownership prevent both outages and audit failures.

---

# Bonus: Oracle interview answer frameworks

## Framework 1: The slow database answer

Use when asked:

> “The Oracle database is slow. What do you do?”

```text
1. Confirm the symptom.
2. Determine scope: one SQL, one module, one user group, or whole database.
3. Check active sessions and wait events.
4. Identify top SQL by elapsed time, CPU, I/O, and executions.
5. Check blocking sessions.
6. Inspect execution plans and statistics.
7. Check memory, TEMP, undo, redo, and storage.
8. Apply the safest fix.
9. Verify with metrics.
10. Prevent recurrence.
```

Interview version:

> “I would not start by changing parameters. I would first identify whether the database is waiting, working, or blocked. Oracle wait events are very useful here. If top waits are I/O, I investigate storage and SQL read patterns. If top waits are locks, I find blockers. If CPU is high, I identify top CPU SQL. Then I fix the proven bottleneck.”

---

## Framework 2: The SQL tuning answer

```text
1. Get SQL ID.
2. Check current and historical plans.
3. Review actual rows versus estimated rows.
4. Identify expensive operations.
5. Check wait events.
6. Validate statistics and histograms.
7. Check indexes and access paths.
8. Review bind variables and child cursors.
9. Rewrite SQL or adjust schema if needed.
10. Verify improvement.
```

Interview version:

> “I tune SQL by evidence. I look at the actual execution plan, not just the explain plan, because the actual runtime stats show where time and rows are spent.”

---

## Framework 3: The locking answer

```text
1. Find blocked sessions.
2. Find blocking sessions.
3. Identify locked objects.
4. Check SQL and transaction age.
5. Decide whether to wait, kill, or escalate.
6. Fix root cause: shorter transaction, proper indexes, safer DDL, consistent lock order.
```

Interview version:

> “Killing the blocker may be necessary in an incident, but it is not the root-cause fix. The root cause is usually transaction design.”

---

## Framework 4: The storage answer

```text
1. Identify what filled: data, index, LOB, TEMP, undo, redo, archive logs.
2. Apply safe short-term space relief.
3. Identify the segment or process causing growth.
4. Fix retention, purge, partitioning, or job behavior.
5. Add monitoring and alerts.
```

Interview version:

> “When storage fills, I first identify what is growing. TEMP, undo, redo, archive logs, and table data all require different fixes.”

---

# Common Oracle interview traps and better answers

## Trap 1: “Would you gather stats?”

Weak answer:

> “Yes, gather stats.”

Better answer:

> “Maybe. I would check whether stats are stale and whether estimates differ from actual rows. Gathering stats can fix bad plans, but it can also cause plan changes, so I would be careful in production.”

---

## Trap 2: “Would you add an index?”

Weak answer:

> “Yes, indexes make queries faster.”

Better answer:

> “Only if the index matches the query pattern and selectivity. I would check the execution plan, predicates, column order, clustering factor, and DML overhead.”

---

## Trap 3: “Can we kill the blocking session?”

Weak answer:

> “Yes.”

Better answer:

> “Possibly, if it is causing impact and we understand the rollback risk. I would first identify the blocker, SQL, transaction age, and business impact.”

---

## Trap 4: “Can we increase memory?”

Weak answer:

> “Yes, more memory helps.”

Better answer:

> “It depends where the pressure is. If the issue is bad SQL, memory may hide the problem. I would check whether the pressure is buffer cache, shared pool, PGA, TEMP spills, or OS swapping.”

---

## Trap 5: “Are backups configured?”

Weak answer:

> “Yes, RMAN runs every night.”

Better answer:

> “That is not enough. I would confirm restore testing, archive log availability, control file autobackup, wallet backup if encrypted, and whether restore time meets RTO.”

---

# Oracle interview quick-reference table

| Issue | Main symptom | First thing to check | Common fix |
|---|---|---|---|
| Slow SQL | One SQL is slow | SQL ID and execution plan | Tune SQL, stats, index, memory |
| Bad plan | Plan regression | Estimated vs actual rows | Stats, histograms, SPM |
| Stale stats | Wrong estimates | `DBA_TAB_STATISTICS` | Gather stats carefully |
| Missing index | Excessive scan | Predicates and plan | Create matching index |
| Too many indexes | Slow DML | Index list and workload | Drop/invisible duplicate indexes |
| Blocking | Sessions hang | `V$SESSION.BLOCKING_SESSION` | Commit, kill safely, shorten transactions |
| Deadlocks | ORA-00060 | Trace file | Lock order, FK indexes |
| High CPU | CPU saturated | Top SQL by CPU | Tune SQL, reduce parsing |
| I/O waits | Low CPU, slow DB | Wait events | Tune SQL/storage |
| TEMP full | ORA-01652 | `V$TEMPSEG_USAGE` | Tune SQL, add TEMP |
| Undo issues | ORA-01555, ORA-30036 | Undo usage, long transactions | Increase undo, tune transactions |
| Redo latency | Slow commits | `log file sync` | Redo storage, commit batching |
| Tablespace full | ORA-01653 | Tablespace usage | Add space, fix growth |
| HWM/fragmentation | Space not reclaimed | Segment size | Shrink, move, partition |
| Memory pressure | TEMP spills, ORA-04031 | PGA/SGA advisors | Tune memory and SQL |
| Hard parsing | High CPU | Parse counts | Bind variables |
| RAC contention | `gc` waits | `GV$SYSTEM_EVENT` | Service routing, reduce hot blocks |
| Data Guard lag | Standby behind | Transport/apply lag | Fix network/apply/gaps |
| Backup gaps | Recovery risk | Restore tests | RMAN validation, PITR |
| Privileges | ORA-01031, audit risk | Grants and roles | Least privilege, direct grants |

---

# Strong closing takeaway

Oracle interviews are not just about knowing commands. They are about showing production judgment.

A strong answer does not sound like this:

> “I would tune the database.”

It sounds like this:

> “I would identify whether the database is waiting, working, or blocked. Then I would use Oracle evidence — wait events, SQL IDs, execution plans, ASH/AWR, and dynamic performance views — to isolate the bottleneck. I would make the smallest safe change, verify impact, and prevent recurrence.”

That is the answer of someone who has operated real systems.

When you freeze, return to this:

```text
Symptom → Scope → Evidence → Cause → Fix → Verify → Prevent
```

You do not need the perfect answer immediately. You need a reliable troubleshooting path.

---

# Final takeaway summaries

## The one-minute summary

Oracle issues usually fall into SQL plans, statistics, indexes, locks, waits, memory, TEMP, undo, redo, storage, replication, backups, or security. The strongest interview answers start with evidence: SQL ID, execution plans, wait events, session views, AWR/ASH, and object statistics. Do not guess. Diagnose first.

## The senior-engineer summary

A senior Oracle engineer understands trade-offs. Indexes help reads but slow DML. Gathering stats can fix plans but may also change them. Killing blockers may restore service but can cause rollback impact. Adding space may stop an outage but does not fix growth. Increasing memory may help, but bad SQL can consume any amount of memory. Seniority is calm diagnosis plus safe change control.

## The interview survival summary

When your mind goes blank, say:

> “I would first confirm the symptom and scope. Then I would check active sessions, wait events, top SQL, execution plans, locks, memory, TEMP, undo, redo, and storage. I would use evidence to identify the bottleneck, apply the safest fix, verify improvement, and then prevent recurrence.”

That answer works across most Oracle interview scenarios.
