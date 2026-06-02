# PostgreSQL Engineer — 2nd Interview Response Guide

## Table of Contents

1. [Strong Intro / Opening Statement](#strong-intro--opening-statement)
2. [30-Second Positioning Summary](#30-second-positioning-summary)
3. [Technical Leadership Themes](#technical-leadership-themes)
4. [Interview Responses by Topic](#interview-responses-by-topic)
   - [Performance Tuning](#1-performance-tuning)
   - [Query Planning and EXPLAIN](#2-query-planning-and-explain)
   - [Indexing Strategy](#3-indexing-strategy)
   - [Vacuum, Bloat, and Autovacuum](#4-vacuum-bloat-and-autovacuum)
   - [High Availability and Replication](#5-high-availability-and-replication)
   - [Backup and Recovery](#6-backup-and-recovery)
   - [Locking and Blocking](#7-locking-and-blocking)
   - [Monitoring and Observability](#8-monitoring-and-observability)
   - [Security and Access Control](#9-security-and-access-control)
   - [Migrations and Change Safety](#10-migrations-and-change-safety)
   - [Incident Response](#11-incident-response)
   - [Working with Developers](#12-working-with-developers)
5. [Scenario-Based Interview Answers](#scenario-based-interview-answers)
6. [PostgreSQL Query and Check Library](#postgresql-query-and-check-library)
7. [Questions to Ask the Hiring Technical Team](#questions-to-ask-the-hiring-technical-team)
8. [Closing Statement](#closing-statement)

---

## Strong Intro / Opening Statement

I see PostgreSQL engineering as a mix of database reliability, performance investigation, and disciplined change management. My focus is not only keeping the database online, but making sure it stays understandable, observable, recoverable, and scalable as the business grows.

In a second technical interview, I would position myself as someone who can work across the full lifecycle of PostgreSQL: schema design, query tuning, indexing, replication, backup and recovery, monitoring, security, incident response, and developer enablement. I tend to approach database work with a simple operating model: measure first, isolate the bottleneck, make the smallest safe change, validate the result, and leave better visibility behind.

What I bring is practical production judgment. I am comfortable digging into `EXPLAIN ANALYZE`, wait events, lock chains, autovacuum behavior, replication lag, index usage, and slow query patterns. I also understand that the best database engineers do more than fix symptoms. They help teams design safer systems, reduce operational risk, and make performance a shared engineering responsibility.

### Takeaway Summary

The strongest message to land early: **I am a production-minded PostgreSQL engineer who combines deep troubleshooting skills with safe operational discipline and clear communication.**

---

## 30-Second Positioning Summary

I specialize in running PostgreSQL reliably under real production pressure. My approach is evidence-driven: I use query plans, statistics, logs, wait events, locks, and system metrics to identify what is actually happening before making changes. I care about performance, but I care just as much about safety: backups, rollback plans, replication health, migration controls, and clear communication with developers and stakeholders. In this role, I would aim to reduce database risk, improve observability, and help teams build systems that scale cleanly instead of reacting to the same issues repeatedly.

### Takeaway Summary

**Performance matters, but safe performance matters more.**

---

## Technical Leadership Themes

Use these themes throughout the interview:

- **Measure before changing.** Avoid guessing; use PostgreSQL evidence.
- **Prefer small, reversible changes.** Especially in production.
- **Tune queries before scaling hardware.** Hardware can hide bad patterns, not fix them.
- **Index intentionally.** Every index has read benefits and write/storage costs.
- **Protect recovery first.** A database is only as reliable as its restore process.
- **Make invisible problems visible.** Logging, metrics, dashboards, and alerts matter.
- **Work with developers, not against them.** Database reliability is a shared system property.

---

# Interview Responses by Topic

## 1. Performance Tuning

### Interview Question

**How do you approach PostgreSQL performance tuning?**

### Strong Response

I start by separating symptoms from causes. A slow database can be caused by inefficient queries, missing or poor indexes, stale statistics, lock contention, I/O pressure, CPU saturation, connection storms, autovacuum lag, checkpoint pressure, or application behavior. I do not assume the database engine is the problem until the evidence supports that.

My first step is usually to identify the top contributors: slow queries, high-frequency queries, lock waits, replication lag, CPU, memory, disk I/O, and connection usage. Then I narrow the scope. If the issue is query-specific, I use `EXPLAIN (ANALYZE, BUFFERS)` to compare estimated rows against actual rows, check scan types, joins, sorts, memory spills, and buffer reads. If the issue is system-wide, I look at wait events, active sessions, checkpoints, cache hit ratios, and I/O patterns.

I prefer making focused changes: rewrite a query, add or adjust an index, refresh statistics, tune autovacuum, tune memory for sorts, reduce connection pressure, or address schema patterns that create recurring pain. After any change, I validate with before-and-after metrics.

### Example Checks

```sql
-- Active sessions and wait events
SELECT
    pid,
    usename,
    application_name,
    state,
    wait_event_type,
    wait_event,
    now() - query_start AS query_age,
    query
FROM pg_stat_activity
WHERE state <> 'idle'
ORDER BY query_age DESC;
```

```sql
-- Top statements by total execution time, requires pg_stat_statements
SELECT
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    rows,
    shared_blks_hit,
    shared_blks_read
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
```

### Takeaway Summary

**I tune PostgreSQL by finding the highest-impact bottleneck, proving it with data, applying a controlled fix, and validating the result.**

---

## 2. Query Planning and EXPLAIN

### Interview Question

**How do you use `EXPLAIN ANALYZE`?**

### Strong Response

I use `EXPLAIN ANALYZE` to compare what PostgreSQL expected to happen with what actually happened. The most important thing I look for is mismatch: estimated rows versus actual rows. If PostgreSQL expects 100 rows and gets 10 million, the plan choice may be wrong because the planner is working from poor assumptions.

I also look at whether the query is doing sequential scans, index scans, bitmap scans, nested loops, hash joins, merge joins, sorts, disk spills, and high buffer reads. `BUFFERS` is especially useful because it shows whether the query is mostly served from cache or doing heavy physical reads.

I am careful with `EXPLAIN ANALYZE` because it actually runs the query. For write queries, I use a transaction and roll it back, or I test safely outside production.

### Example

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT
    c.customer_id,
    c.email,
    COUNT(o.order_id) AS order_count
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
WHERE o.created_at >= now() - interval '30 days'
GROUP BY c.customer_id, c.email
ORDER BY order_count DESC
LIMIT 20;
```

### What I Look For

- Estimated rows versus actual rows
- Sequential scans on large tables
- Expensive nested loops
- Sorts spilling to disk
- Large buffer reads
- Join order and join method
- Whether predicates are indexable
- Whether statistics are stale or insufficient

### Takeaway Summary

**`EXPLAIN ANALYZE` is not just about finding the slow step; it is about understanding why PostgreSQL chose that plan.**

---

## 3. Indexing Strategy

### Interview Question

**How do you decide when to add an index?**

### Strong Response

I do not add indexes automatically just because a query is slow. I first check the query pattern, table size, selectivity, frequency, write volume, and whether existing indexes are already close to useful. An index is a tradeoff: it can improve reads, but it adds storage cost and slows writes, updates, deletes, and vacuum work.

I usually start by asking: what predicate is filtering the data, what columns are used for joins, what order is required, and whether the query can benefit from a composite, partial, covering, or expression index. I also check whether existing indexes are unused or redundant before adding more.

For high-write systems, I am especially careful. A badly chosen index can improve one dashboard query while hurting the entire write path.

### Example Checks

```sql
-- Existing indexes for a table
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'orders'
ORDER BY indexname;
```

```sql
-- Index usage statistics
SELECT
    relname AS table_name,
    indexrelname AS index_name,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC, indexrelname;
```

### Example Indexes

```sql
-- Composite index for customer lookups by recent order date
CREATE INDEX CONCURRENTLY idx_orders_customer_created_at
ON orders (customer_id, created_at DESC);
```

```sql
-- Partial index for common filtered access pattern
CREATE INDEX CONCURRENTLY idx_orders_open_created_at
ON orders (created_at DESC)
WHERE status = 'open';
```

```sql
-- Expression index for case-insensitive email lookup
CREATE INDEX CONCURRENTLY idx_users_lower_email
ON users (lower(email));
```

### Takeaway Summary

**Good indexing is workload-specific. I design indexes around real query patterns, not generic rules.**

---

## 4. Vacuum, Bloat, and Autovacuum

### Interview Question

**How do you troubleshoot table bloat or autovacuum issues?**

### Strong Response

I start by confirming whether the problem is dead tuples, table growth, index bloat, transaction ID age, or vacuum falling behind. PostgreSQL uses MVCC, so updates and deletes create dead tuples that must eventually be cleaned up. If autovacuum cannot keep up, performance can degrade, tables and indexes can grow, and transaction ID wraparound risk can increase.

I check dead tuple counts, last vacuum times, table size, update/delete rates, long-running transactions, and whether autovacuum is blocked or under-tuned for that table. Long-running transactions are a common root cause because they prevent cleanup of old row versions.

The fix depends on the cause. It may be tuning autovacuum thresholds, increasing vacuum cost limits, changing fillfactor, fixing long transactions, using `VACUUM (ANALYZE)`, or in more severe cases planning `pg_repack` or table rebuilds.

### Example Checks

```sql
-- Tables with high dead tuples
SELECT
    schemaname,
    relname,
    n_live_tup,
    n_dead_tup,
    last_autovacuum,
    last_vacuum,
    autovacuum_count,
    vacuum_count
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 20;
```

```sql
-- Long-running transactions that may prevent vacuum cleanup
SELECT
    pid,
    usename,
    state,
    now() - xact_start AS transaction_age,
    query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
ORDER BY transaction_age DESC;
```

```sql
-- Transaction ID age risk
SELECT
    datname,
    age(datfrozenxid) AS xid_age
FROM pg_database
ORDER BY xid_age DESC;
```

### Takeaway Summary

**Autovacuum problems are often workload and transaction-behavior problems, not just configuration problems.**

---

## 5. High Availability and Replication

### Interview Question

**What do you check when PostgreSQL replication lag increases?**

### Strong Response

I look at replication lag as a pipeline problem. Lag can happen because the primary is generating WAL faster than replicas can receive, write, flush, replay, or apply it. It can also happen because of network issues, disk I/O limits, long-running queries on replicas, replication slots retaining WAL, or replica hardware being undersized.

I check the primary’s replication view, WAL generation rate, replica replay position, wait events, disk usage, and whether replication slots are retaining too much WAL. On the replica, I check whether it is receiving WAL but not replaying it, or not receiving it at all. Those are different failure modes.

Operationally, I care about what lag means for the application. If reads are served from replicas, lag may cause stale reads. If a failover happens while lag is high, data loss risk depends on the replication mode and recovery point.

### Example Checks

```sql
-- On primary: replication status
SELECT
    application_name,
    client_addr,
    state,
    sync_state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    write_lag,
    flush_lag,
    replay_lag
FROM pg_stat_replication;
```

```sql
-- Replication slots and retained WAL
SELECT
    slot_name,
    plugin,
    slot_type,
    active,
    restart_lsn,
    confirmed_flush_lsn,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal
FROM pg_replication_slots;
```

```sql
-- On replica: replay delay
SELECT
    now() - pg_last_xact_replay_timestamp() AS replica_replay_delay;
```

### Takeaway Summary

**Replication lag is not one metric; it is a chain. I identify where the chain is slowing down before acting.**

---

## 6. Backup and Recovery

### Interview Question

**How do you evaluate a PostgreSQL backup strategy?**

### Strong Response

I evaluate backups from the recovery side, not the backup side. A backup strategy is only valid if the team can restore within the required recovery time objective and recover to the required recovery point objective.

I want to know whether the environment uses physical backups, logical dumps, WAL archiving, point-in-time recovery, retention policies, encryption, offsite storage, and automated restore testing. I also check whether backups are monitored and whether failures alert the right people.

For production systems, I prefer regular physical base backups plus continuous WAL archiving for point-in-time recovery. Logical dumps are useful for portability and object-level restore, but they are not always enough for large production databases or tight recovery windows.

### Example Checks

```sql
-- Check whether WAL archiving is enabled
SHOW archive_mode;
SHOW archive_command;
```

```sql
-- Check current WAL location
SELECT pg_current_wal_lsn();
```

```sql
-- Check database sizes for backup planning
SELECT
    datname,
    pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
ORDER BY pg_database_size(datname) DESC;
```

### Takeaway Summary

**The real test of a backup strategy is not whether backups exist; it is whether restores are proven.**

---

## 7. Locking and Blocking

### Interview Question

**How do you investigate blocking or lock contention?**

### Strong Response

I first identify the blocked sessions and the blockers. Then I look at transaction age, query age, lock mode, and whether the blocker is active or idle in transaction. An idle transaction holding locks is often more dangerous than a visibly active query because it may be forgotten by the application.

I avoid killing sessions blindly. I check business impact, transaction type, application owner, and whether terminating the blocker is safer than waiting. After the incident, I look for prevention: shorter transactions, safer migration patterns, better timeouts, smaller batches, and application changes.

### Example Lock Chain Query

```sql
SELECT
    blocked.pid AS blocked_pid,
    blocked.usename AS blocked_user,
    now() - blocked.query_start AS blocked_duration,
    blocked.query AS blocked_query,
    blocker.pid AS blocker_pid,
    blocker.usename AS blocker_user,
    now() - blocker.query_start AS blocker_duration,
    blocker.state AS blocker_state,
    blocker.query AS blocker_query
FROM pg_stat_activity blocked
JOIN pg_locks blocked_locks
    ON blocked_locks.pid = blocked.pid
JOIN pg_locks blocker_locks
    ON blocker_locks.locktype = blocked_locks.locktype
    AND blocker_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocker_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocker_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocker_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocker_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocker_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocker_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocker_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocker_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocker_locks.pid <> blocked_locks.pid
JOIN pg_stat_activity blocker
    ON blocker.pid = blocker_locks.pid
WHERE NOT blocked_locks.granted
  AND blocker_locks.granted;
```

### Takeaway Summary

**For lock incidents, the key is to find the blocker quickly, act safely, and prevent the same lock pattern from recurring.**

---

## 8. Monitoring and Observability

### Interview Question

**What PostgreSQL metrics do you monitor?**

### Strong Response

I monitor PostgreSQL at multiple layers: database health, query behavior, replication, storage, operating system resources, and application connection behavior. Important database metrics include active sessions, wait events, slow queries, transaction rates, cache hit ratio, dead tuples, vacuum activity, checkpoint behavior, WAL generation, locks, replication lag, and database growth.

I also care about alert quality. Alerts should point to user impact or risk, not just noise. For example, replication lag should alert based on business tolerance. Disk usage should alert early enough to act. Failed backups should page because recovery risk is production risk.

### Example Checks

```sql
-- Database activity overview
SELECT
    datname,
    numbackends,
    xact_commit,
    xact_rollback,
    blks_read,
    blks_hit,
    tup_returned,
    tup_fetched,
    tup_inserted,
    tup_updated,
    tup_deleted
FROM pg_stat_database
ORDER BY numbackends DESC;
```

```sql
-- Cache hit ratio by database
SELECT
    datname,
    round(100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 2) AS cache_hit_percent
FROM pg_stat_database
WHERE blks_hit + blks_read > 0
ORDER BY cache_hit_percent ASC;
```

```sql
-- Checkpoint pressure
SELECT
    checkpoints_timed,
    checkpoints_req,
    checkpoint_write_time,
    checkpoint_sync_time,
    buffers_checkpoint,
    buffers_clean,
    maxwritten_clean
FROM pg_stat_bgwriter;
```

### Takeaway Summary

**Good PostgreSQL monitoring should expose user impact, saturation, and future risk before they become incidents.**

---

## 9. Security and Access Control

### Interview Question

**How do you approach PostgreSQL security?**

### Strong Response

I approach PostgreSQL security through least privilege, strong authentication, network controls, encryption, auditability, and operational hygiene. Users and applications should have only the permissions they need. Administrative access should be limited, reviewed, and logged.

I also separate application roles from human roles, avoid shared accounts where possible, and make privilege grants explicit. For sensitive systems, I want SSL/TLS enforced, secrets managed outside the application codebase, and access reviewed regularly.

### Example Checks

```sql
-- Roles and key attributes
SELECT
    rolname,
    rolsuper,
    rolcreaterole,
    rolcreatedb,
    rolcanlogin,
    rolreplication
FROM pg_roles
ORDER BY rolname;
```

```sql
-- Table privileges in public schema
SELECT
    grantee,
    table_schema,
    table_name,
    privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
ORDER BY grantee, table_name, privilege_type;
```

```sql
-- Default privileges can be important for future objects
SELECT
    defaclrole::regrole AS role,
    defaclnamespace::regnamespace AS schema,
    defaclobjtype AS object_type,
    defaclacl AS privileges
FROM pg_default_acl;
```

### Takeaway Summary

**Database security is strongest when permissions are explicit, minimal, reviewed, and automated.**

---

## 10. Migrations and Change Safety

### Interview Question

**How do you handle PostgreSQL schema migrations in production?**

### Strong Response

I treat production migrations as operational events, not just code changes. The key questions are: will this lock a large table, rewrite data, block writes, break old application versions, or create a rollback problem?

For high-traffic systems, I prefer backward-compatible migrations. For example: add a nullable column first, deploy application code that writes both old and new paths, backfill in batches, validate, then remove old structures later. I avoid large blocking operations during peak traffic and use `CREATE INDEX CONCURRENTLY` where appropriate.

I also want clear pre-checks, post-checks, monitoring, and rollback steps. A safe migration should be boring.

### Example Safer Pattern

```sql
-- Safer index creation for production workloads
CREATE INDEX CONCURRENTLY idx_orders_created_at
ON orders (created_at);
```

```sql
-- Batch backfill example
UPDATE orders
SET processed_at = created_at
WHERE processed_at IS NULL
  AND id BETWEEN 100000 AND 110000;
```

```sql
-- Check remaining backfill count
SELECT COUNT(*)
FROM orders
WHERE processed_at IS NULL;
```

### Takeaway Summary

**A good migration plan protects availability first, then correctness, then cleanup.**

---

## 11. Incident Response

### Interview Question

**Describe how you respond to a PostgreSQL production incident.**

### Strong Response

I first stabilize the system and protect data. That means understanding impact, stopping the bleeding, and avoiding risky changes. I quickly check whether the issue is availability, latency, data correctness, replication, storage, locks, or application-driven load.

My first commands usually inspect active sessions, wait events, locks, disk pressure, replication, and top queries. I communicate clearly while investigating: what is known, what is suspected, what action is being taken, and what risk exists.

Once stable, I focus on root cause and prevention. The incident is not finished when the page stops. It is finished when the team understands what happened and has reduced the chance of recurrence.

### Example First Checks

```sql
-- What is active right now?
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    state,
    wait_event_type,
    wait_event,
    now() - query_start AS age,
    query
FROM pg_stat_activity
WHERE state <> 'idle'
ORDER BY age DESC;
```

```sql
-- Are there many idle-in-transaction sessions?
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    now() - xact_start AS xact_age,
    query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
ORDER BY xact_age DESC;
```

```sql
-- Database size growth check
SELECT
    datname,
    pg_size_pretty(pg_database_size(datname)) AS db_size
FROM pg_database
ORDER BY pg_database_size(datname) DESC;
```

### Takeaway Summary

**During incidents, I prioritize data safety, system stabilization, clear communication, and prevention.**

---

## 12. Working with Developers

### Interview Question

**How do you work with application developers on database performance?**

### Strong Response

I try to make database performance collaborative rather than adversarial. Developers usually do not write bad queries intentionally; they are often missing visibility into how the database executes them at scale.

I help by showing concrete evidence: query plans, row estimates, index usage, lock behavior, and before-and-after measurements. I also try to give practical patterns: pagination that avoids deep offsets, selective predicates, safe migration patterns, better transaction boundaries, and avoiding N+1 query behavior.

The goal is not to make every developer a DBA. The goal is to give the team enough shared understanding to avoid repeat problems.

### Example Developer-Friendly Explanation

A query can look harmless in development because the table has 5,000 rows. In production, the same query may scan 500 million rows, sort to disk, and block other work. My role is to help the team see that difference early and design access patterns that stay healthy as data grows.

### Takeaway Summary

**The best PostgreSQL work often happens before production: during design reviews, query reviews, and migration planning.**

---

# Scenario-Based Interview Answers

## Scenario 1: CPU Is Suddenly High on the PostgreSQL Primary

### Response

I would first determine whether CPU is being consumed by a small number of expensive queries, a large number of frequent queries, connection pressure, parallel workers, autovacuum, or background processes. I would check active sessions, top queries from `pg_stat_statements`, wait events, and OS-level CPU usage.

If one query is responsible, I would inspect the plan and determine whether it changed due to stale statistics, parameter changes, missing index usage, or data growth. If many queries are responsible, I would look for application release changes, traffic spikes, connection pool behavior, or repeated inefficient patterns.

### Checks

```sql
SELECT
    pid,
    usename,
    application_name,
    state,
    wait_event_type,
    wait_event,
    now() - query_start AS age,
    query
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY age DESC;
```

```sql
SELECT
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    max_exec_time
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

### Takeaway Summary

**High CPU is a symptom. I would identify whether the pressure is query-specific, workload-wide, or caused by a recent application change.**

---

## Scenario 2: A Migration Is Blocking Production Traffic

### Response

I would identify the blocked sessions and the blocker, confirm the lock mode, and determine whether the migration can safely be cancelled. If it is blocking critical traffic, I would usually stop the migration first, then reassess a safer approach.

After stabilizing, I would redesign the migration to reduce locking risk. That may mean using `CREATE INDEX CONCURRENTLY`, breaking data changes into batches, avoiding table rewrites, separating schema changes from backfills, or using a multi-phase deployment.

### Checks

```sql
SELECT
    pid,
    state,
    wait_event_type,
    wait_event,
    now() - query_start AS age,
    query
FROM pg_stat_activity
WHERE wait_event_type = 'Lock'
ORDER BY age DESC;
```

```sql
-- Cancel a problematic backend after confirming impact
SELECT pg_cancel_backend(<pid>);

-- Terminate only if cancellation is not enough and the risk is understood
SELECT pg_terminate_backend(<pid>);
```

### Takeaway Summary

**When migrations hurt production, stabilize first, then redesign the change so it is online-safe.**

---

## Scenario 3: Replica Lag Is Growing

### Response

I would determine whether the replica is failing to receive WAL, write WAL, flush WAL, or replay WAL. On the primary, I would inspect `pg_stat_replication`; on the replica, I would check replay delay and system resources. I would also check whether long-running queries on the replica are delaying WAL replay.

If the application reads from replicas, I would also evaluate user-facing impact. Stale reads can be just as damaging as errors, depending on the workload.

### Checks

```sql
SELECT
    application_name,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    write_lag,
    flush_lag,
    replay_lag
FROM pg_stat_replication;
```

```sql
SELECT now() - pg_last_xact_replay_timestamp() AS replay_delay;
```

### Takeaway Summary

**Replica lag must be diagnosed by stage: send, write, flush, or replay.**

---

## Scenario 4: A Query Was Fast Yesterday and Slow Today

### Response

I would compare the query plan today against a known-good plan if available. I would check whether table statistics changed, data distribution changed, an index became less selective, the query parameters changed, or the table grew enough to change planner behavior.

I would also check for environmental causes: lock waits, I/O saturation, cache changes, autovacuum activity, or a deployment that changed the query text.

### Checks

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT ...;
```

```sql
-- Check last analyze time and table activity
SELECT
    relname,
    n_live_tup,
    n_dead_tup,
    last_analyze,
    last_autoanalyze,
    analyze_count,
    autoanalyze_count
FROM pg_stat_user_tables
WHERE relname = 'target_table';
```

```sql
-- Refresh statistics if appropriate
ANALYZE target_table;
```

### Takeaway Summary

**A sudden plan regression usually comes from changed data, changed statistics, changed parameters, or changed workload context.**

---

# PostgreSQL Query and Check Library

## Active Sessions

```sql
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    state,
    wait_event_type,
    wait_event,
    now() - query_start AS query_age,
    query
FROM pg_stat_activity
WHERE state <> 'idle'
ORDER BY query_age DESC;
```

## Idle in Transaction

```sql
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    now() - xact_start AS transaction_age,
    query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
ORDER BY transaction_age DESC;
```

## Top Queries by Total Time

```sql
SELECT
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    max_exec_time,
    rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

## Top Queries by Average Time

```sql
SELECT
    query,
    calls,
    mean_exec_time,
    max_exec_time,
    rows
FROM pg_stat_statements
WHERE calls > 10
ORDER BY mean_exec_time DESC
LIMIT 20;
```

## Table Size

```sql
SELECT
    schemaname,
    relname,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
    pg_size_pretty(pg_relation_size(relid)) AS table_size,
    pg_size_pretty(pg_indexes_size(relid)) AS index_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 20;
```

## Dead Tuples

```sql
SELECT
    schemaname,
    relname,
    n_live_tup,
    n_dead_tup,
    last_autovacuum,
    last_vacuum
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 20;
```

## Index Usage

```sql
SELECT
    relname AS table_name,
    indexrelname AS index_name,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC;
```

## Missing-Index Investigation Starting Point

```sql
SELECT
    schemaname,
    relname,
    seq_scan,
    seq_tup_read,
    idx_scan,
    n_live_tup
FROM pg_stat_user_tables
WHERE n_live_tup > 100000
ORDER BY seq_tup_read DESC
LIMIT 20;
```

## Replication Status

```sql
SELECT
    application_name,
    client_addr,
    state,
    sync_state,
    write_lag,
    flush_lag,
    replay_lag
FROM pg_stat_replication;
```

## Database Growth

```sql
SELECT
    datname,
    pg_size_pretty(pg_database_size(datname)) AS database_size
FROM pg_database
ORDER BY pg_database_size(datname) DESC;
```

## Lock Waits

```sql
SELECT
    pid,
    usename,
    wait_event_type,
    wait_event,
    now() - query_start AS age,
    query
FROM pg_stat_activity
WHERE wait_event_type = 'Lock'
ORDER BY age DESC;
```

## Cache Hit Ratio

```sql
SELECT
    datname,
    round(100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 2) AS cache_hit_percent
FROM pg_stat_database
WHERE blks_hit + blks_read > 0
ORDER BY cache_hit_percent ASC;
```

## Role Review

```sql
SELECT
    rolname,
    rolsuper,
    rolcreaterole,
    rolcreatedb,
    rolcanlogin,
    rolreplication
FROM pg_roles
ORDER BY rolname;
```

---

# Questions to Ask the Hiring Technical Team

## Architecture and Scale

1. What is the current PostgreSQL footprint: number of clusters, database sizes, peak TPS, and largest tables?
2. Are workloads mostly OLTP, analytics, mixed, multi-tenant, or event-driven?
3. What are the most common database pain points today: latency, bloat, migrations, failover, cost, or developer query patterns?

## Reliability and Recovery

4. What are the current RPO and RTO expectations?
5. How often are restores tested, and are point-in-time recovery drills part of operations?
6. What HA tooling is currently used for failover and replication management?

## Performance and Observability

7. Do you use `pg_stat_statements`, query plan capture, wait-event dashboards, or slow query logging?
8. What are the most important PostgreSQL alerts today, and which ones are noisy?
9. How do developers currently get feedback on query performance before production?

## Change Management

10. How are database migrations reviewed and deployed?
11. Have there been recent incidents caused by schema changes, long locks, or unsafe backfills?
12. Is there a standard pattern for online migrations?

## Team Fit

13. What would success look like for this role in the first 90 days?
14. Where do you want this person to be hands-on versus advisory?
15. What PostgreSQL risks would you most want reduced this year?

### Takeaway Summary

These questions show that I care about the full production system: scale, risk, recovery, observability, developer workflow, and business priorities.

---

# Closing Statement

What I would bring to this PostgreSQL role is calm, structured production judgment. I know how to investigate performance problems deeply, but I also know that the database engineer’s job is bigger than tuning individual queries. It is about protecting data, reducing operational risk, improving reliability, and helping developers build systems that age well.

My working style is evidence-based and collaborative. I like to make problems visible, explain tradeoffs clearly, and leave behind better checks, documentation, and automation than I found. In a production PostgreSQL environment, that means fewer surprises, safer changes, faster diagnosis, and a database platform the wider engineering team can trust.

### Final Takeaway Summary

**I would position myself as a PostgreSQL engineer who can operate under pressure, tune with evidence, protect recovery, guide developers, and improve the reliability of the whole data platform.**

