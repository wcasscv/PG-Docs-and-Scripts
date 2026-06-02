# PostgreSQL on AWS RDS — Interview Responses, Operational Patterns, Tuning, and Replication Realities

## Table of contents

- [Strong intro](#strong-intro)
- [1. PostgreSQL on AWS RDS: how I describe the platform](#1-postgresql-on-aws-rds-how-i-describe-the-platform)
- [2. Common RDS PostgreSQL operational patterns](#2-common-rds-postgresql-operational-patterns)
  - [Pattern: Multi-AZ for local high availability](#pattern-multi-az-for-local-high-availability)
  - [Pattern: Read replicas for read scale and reporting](#pattern-read-replicas-for-read-scale-and-reporting)
  - [Pattern: Blue/Green deployments for safer change](#pattern-bluegreen-deployments-for-safer-change)
- [3. Tuning and configuration in AWS RDS PostgreSQL](#3-tuning-and-configuration-in-aws-rds-postgresql)
  - [Connections](#connections)
  - [Memory](#memory)
  - [Query performance](#query-performance)
  - [Vacuum and bloat](#vacuum-and-bloat)
  - [Logging and slow query visibility](#logging-and-slow-query-visibility)
  - [I/O and storage](#io-and-storage)
- [4. Cross-Region and multi-datacenter PostgreSQL realities](#4-cross-region-and-multi-datacenter-postgresql-realities)
  - [Replication types and tools](#replication-types-and-tools)
  - [Cross-Region practical checks](#cross-region-practical-checks)
- [5. How I would answer direct interview questions](#5-how-i-would-answer-direct-interview-questions)
- [6. Incident-style examples](#6-incident-style-examples)
- [7. Closing interview answer](#7-closing-interview-answer)

---

## Strong intro

My PostgreSQL engineering approach on AWS is to treat RDS as a managed control plane around PostgreSQL, not as a magic abstraction that removes database fundamentals. RDS gives you automation for backups, patching, failover, monitoring hooks, parameter groups, storage management, and replication workflows. But the hard engineering work is still the same: understand the workload, protect write availability, control memory and connection pressure, measure query behavior, and be honest about replication lag and failure modes.

When I discuss PostgreSQL on AWS, I frame it around four questions:

1. What is the recovery objective?
2. What is the write path?
3. What is the read path?
4. What is the operational blast radius when something fails?

That usually leads to better answers than simply saying “use Multi-AZ” or “add read replicas.” Multi-AZ, read replicas, cross-Region replicas, logical replication, DMS, Blue/Green deployments, and application-level dual writes solve different problems. They are not interchangeable.

The core message I would give in an interview is this: **RDS reduces undifferentiated operational work, but it does not remove the need for PostgreSQL discipline. You still need to tune around workload shape, connection behavior, vacuum, WAL, replication lag, failover behavior, parameter groups, and application retry logic.**

---

# 1. PostgreSQL on AWS RDS: how I describe the platform

## Interview response

PostgreSQL on RDS is a good fit when the business wants PostgreSQL semantics but does not want to operate the full database host lifecycle. With RDS, AWS owns a lot of the heavy lifting: provisioning, managed backups, minor version patching options, storage integration, snapshots, encryption integration, monitoring integrations, and managed failover patterns.

But I do not treat RDS as “PostgreSQL without operations.” I treat it as PostgreSQL with a managed boundary. Inside that boundary, I still care about schema design, query plans, bloat, vacuum health, connection pooling, lock behavior, WAL generation, replication lag, and parameter discipline. Outside the boundary, I care about AWS primitives: subnet groups, security groups, KMS, IAM auth where appropriate, CloudWatch alarms, Performance Insights, Enhanced Monitoring, parameter groups, option groups where relevant, and event subscriptions.

A strong RDS PostgreSQL production design usually includes:

- A clear primary write endpoint.
- Multi-AZ for high availability inside a Region.
- Automated backups and tested point-in-time restore.
- Read replicas only when there is a proven read-scaling, reporting, or DR need.
- Connection pooling, usually PgBouncer or application-side pooling.
- Parameter groups managed as code.
- Observability around CPU, memory, connections, IOPS, storage, WAL generation, replica lag, locks, vacuum, and slow queries.
- A documented failover and promotion runbook.

The mistake I try to avoid is using replicas as a substitute for workload control. If the primary is overloaded because of bad queries, too many connections, poor indexes, vacuum starvation, or write amplification, adding replicas may hide symptoms but does not fix the write-side bottleneck.

## Takeaway summary

RDS is managed PostgreSQL, not maintenance-free PostgreSQL. The best engineers know both sides: native PostgreSQL behavior and AWS operational constraints.

---

# 2. Common RDS PostgreSQL operational patterns

## Pattern: Multi-AZ for local high availability

## Interview response

For high availability inside one AWS Region, I normally start with Multi-AZ. The goal is not read scaling; the goal is surviving an Availability Zone or instance failure with a managed failover path.

For the classic RDS DB instance Multi-AZ deployment, there is a standby in another AZ, but the standby is not used as a normal read target. Application design should assume one active writer endpoint and reconnect/retry during failover.

For newer Multi-AZ DB cluster patterns, there can be readable instances depending on configuration, but I still separate the concepts: HA is about failover and recovery, while read replicas are about read scale or DR.

The application side matters. A good RDS HA design includes reasonable TCP timeouts, retry logic, idempotent writes where possible, and connection pool behavior that does not hold dead connections forever after failover.

## Practical checks

```sql
-- Confirm the instance view of recovery state.
SELECT pg_is_in_recovery();
   OR
psql "$REPLICA_DSN" -c "SELECT pg_is_in_recovery();"
   OR
-- AWS RDS
aws rds describe-db-instances \
  --db-instance-identifier prod-postgres \
  --query 'DBInstances[0].{DB:DBInstanceIdentifier,ReadReplicaSource:ReadReplicaSourceDBInstanceIdentifier,Replicas:ReadReplicaDBInstanceIdentifiers,Status:DBInstanceStatus}' \
  --output table

Rule of thumb:

ReadReplicaSource is set      → behaves like pg_is_in_recovery() = true
ReadReplicaSource is null     → likely primary/writer, pg_is_in_recovery() = false
Replicas list is non-empty    → this DB has read replicas


-- Check server identity and version.
SELECT version();
SHOW server_version;

-- Check current connections by database and state.
SELECT datname, state, count(*)
FROM pg_stat_activity
GROUP BY datname, state
ORDER BY datname, state;
```

AWS CLI examples:

```bash
aws rds describe-db-instances \
  --db-instance-identifier prod-postgres \
  --query 'DBInstances[0].{MultiAZ:MultiAZ,Engine:Engine,EngineVersion:EngineVersion,Class:DBInstanceClass,Storage:AllocatedStorage,Status:DBInstanceStatus}'

Sample output:
{
  "MultiAZ": true,         -- true means the DB has a standby in another AZ
  "Engine": "postgres",    -- Database engine, for example postgres
  "EngineVersion": "15.5", -- Exact PostgreSQL engine version
  "Class": "db.r6g.large", -- RDS instance size
  "Storage": 100,          -- Allocated storage in GiB
  "Status": "available"    -- Current DB state
}

aws rds describe-events \
  --source-type db-instance \
  --source-identifier prod-postgres \
  --duration 1440

Output:
{
  "Events": [
    {
      "SourceIdentifier": "prod-postgres",
      "SourceType": "db-instance",
      "Message": "DB instance restarted",
      "EventCategories": [
        "availability"
      ],
      "Date": "2026-06-01T14:22:31.123000+00:00",
      "SourceArn": "arn:aws:rds:eu-west-1:123456789012:db:prod-postgres"
    },
    {
      "SourceIdentifier": "prod-postgres",
      "SourceType": "db-instance",
      "Message": "Finished DB Instance backup",
      "EventCategories": [
        "backup"
      ],
      "Date": "2026-06-01T02:14:05.456000+00:00",
      "SourceArn": "arn:aws:rds:eu-west-1:123456789012:db:prod-postgres"
    }
  ]
}

A better Verion:
aws rds describe-events \
  --source-type db-instance \
  --source-identifier prod-postgres \
  --duration 1440 \
  --query 'Events[].{Time:Date,Category:EventCategories,Message:Message}' \
  --output table

```

## Takeaway summary

Multi-AZ is a high-availability pattern, not a silver bullet. You still need application reconnect behavior, timeout discipline, monitoring, and failover testing.

---

## Pattern: Read replicas for read scale and reporting

## Interview response

Read replicas are useful when the workload has a real read-scaling problem or when analytical/reporting traffic needs isolation from the primary. They are also useful as part of a DR posture, especially cross-Region, but I am careful with expectations: read replicas are asynchronous, can lag, and are not a substitute for synchronous multi-site consistency.

For PostgreSQL, RDS read replicas are read-only. They can be promoted to standalone databases, but promotion changes the topology and is not a reversible “pause button.” That means a promotion plan must include DNS or endpoint cutover, application configuration, sequence behavior, client routing, and a reconciliation plan if the old primary comes back.

I also watch out for replica query behavior. Long-running queries on a replica can conflict with WAL replay. A replica that is used for reporting can accumulate lag if queries block replay or if the primary generates WAL faster than the replica can consume it.

## Practical checks

On the primary:

```sql
-- Replication status from the primary side.
SELECT
  application_name,
  client_addr,
  state,
  sync_state,
  sent_lsn,
  write_lsn,
  flush_lsn,
  replay_lsn,
  pg_wal_lsn_diff(sent_lsn, replay_lsn) AS bytes_lag
FROM pg_stat_replication;
```

On a replica:

```sql
-- Is this server in recovery?
SELECT pg_is_in_recovery();

-- Replica replay lag as wall-clock time.
SELECT now() - pg_last_xact_replay_timestamp() AS replica_replay_delay;
   OR
-- using RDS to get Replica replay lag as wall-clock time.
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ReplicaLag \
  --dimensions Name=DBInstanceIdentifier,Value=prod-postgres-replica \
  --start-time "$(date -u -v-30M +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --period 60 \
  --statistics Average,Maximum \
  --query 'Datapoints[].{Time:Timestamp,AvgLagSeconds:Average,MaxLagSeconds:Maximum}' \
  --output table

-- Last WAL receive/replay positions.
SELECT
  pg_last_wal_receive_lsn() AS receive_lsn,
  pg_last_wal_replay_lsn() AS replay_lsn,
  pg_wal_lsn_diff(pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn()) AS bytes_not_replayed;

 receive_lsn | replay_lsn | bytes_not_replayed
-------------+------------+--------------------
 0/900001A8  | 0/90000060 |                328

SQL bytes_not_replayed        → not available from aws rds describe-* commands
CloudWatch ReplicaLag         → available via aws cloudwatch, lag in seconds
Exact WAL receive/replay LSNs → must query PostgreSQL directly
```

AWS CLI example:

```bash
aws rds describe-db-instances \
  --query 'DBInstances[].{DB:DBInstanceIdentifier,ReadReplicaSource:ReadReplicaSourceDBInstanceIdentifier,Replicas:ReadReplicaDBInstanceIdentifiers,Status:DBInstanceStatus}'
```

AWS CLI outout:
```json
[
  {
    "DB": "prod-db",
    "ReadReplicaSource": null,
    "Replicas": [
      "prod-db-replica-1",
      "prod-db-replica-2"
    ],
    "Status": "available"
  },
  {
    "DB": "prod-db-replica-1",
    "ReadReplicaSource": "prod-db",
    "Replicas": [],
    "Status": "available"
  },
  {
    "DB": "prod-db-replica-2",
    "ReadReplicaSource": "prod-db",
    "Replicas": [],
    "Status": "available"
  },
  {
    "DB": "dev-db",
    "ReadReplicaSource": null,
    "Replicas": [],
    "Status": "stopped"
  }
]
```

Meaning:
```text
prod-db
  - Primary/source DB
  - Has replicas: prod-db-replica-1, prod-db-replica-2

prod-db-replica-1
  - Read replica of prod-db

prod-db-replica-2
  - Read replica of prod-db

dev-db
  - Standalone DB
  - No replicas
```

## Takeaway summary

Read replicas are great for scaling reads and isolating reporting, but they introduce lag, read-your-writes problems, and promotion complexity.

---

## Pattern: Blue/Green deployments for safer change

## Interview response

For major changes like version upgrades, risky parameter changes, or controlled cutovers, I like Blue/Green deployments when the workload and topology are supported. The value is that production continues running while the green environment is prepared and tested. Then the cutover can be controlled.

For PostgreSQL, I pay close attention to the replication method used by the Blue/Green workflow. Physical replication and logical replication have different limits. Logical replication can be more flexible for major version changes, but it brings replication slot overhead, table eligibility concerns, identity/key requirements for updates and deletes, sequence handling, and lag risk.

Before a Blue/Green cutover, I verify:

- Replication lag is low and stable.
- The green parameter group is correct.
- Application compatibility has been tested.
- Extensions exist and are at expected versions.
- Long-running transactions are cleared.
- Rollback strategy is documented.
- Monitoring and alarms exist for both environments.

## Practical checks

```sql
-- Long-running transactions that can hold back vacuum or replication.
SELECT
  pid,
  usename,
  datname,
  state,
  now() - xact_start AS xact_age,
  wait_event_type,
  wait_event,
  left(query, 200) AS query_sample
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
ORDER BY xact_age DESC
LIMIT 20;

-- Installed extensions and versions.
SELECT extname, extversion
FROM pg_extension
ORDER BY extname;

-- Tables without primary keys; important for logical replication planning.
SELECT n.nspname AS schema_name, c.relname AS table_name
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND NOT EXISTS (
    SELECT 1
    FROM pg_index i
    WHERE i.indrelid = c.oid
      AND i.indisprimary
  )
ORDER BY 1, 2;
```

## Takeaway summary

Blue/Green is a safer change-management pattern, but it still needs database checks. Replication type, lag, slots, schema compatibility, extensions, and application cutover behavior matter.

---

# 3. Tuning and configuration in AWS RDS PostgreSQL

## Interview response

My tuning approach is measurement-first. I do not start by changing ten parameters. I start by identifying the bottleneck: CPU, memory, I/O, locks, connection pressure, WAL pressure, vacuum, query planning, or application behavior.

In RDS, parameters are managed through parameter groups. Some settings are dynamic and can be changed immediately. Others are static and require a reboot. I treat parameter groups as production artifacts: reviewed, version-controlled, tested in lower environments, and rolled out with a maintenance plan.

The RDS-specific point is that you do not have unrestricted host access. You use PostgreSQL views, RDS views/functions where available, CloudWatch, Performance Insights, Enhanced Monitoring, logs, and AWS APIs instead of shelling into the box.

## Tuning areas I discuss in interviews

### Connections

Too many direct PostgreSQL connections are a common failure mode. Each connection has memory overhead. If every application pod opens a large pool, the database becomes a connection manager instead of a query engine.

My normal pattern is:

- Keep `max_connections` sane.
- Use PgBouncer or application-side pooling.
- Size pools from actual concurrency, not from arbitrary defaults.
- Alert before connection exhaustion.
- Separate admin access from application pool exhaustion where possible.

Checks:

```sql
SHOW max_connections;

SELECT count(*) AS current_connections
FROM pg_stat_activity;

SELECT
  datname,
  usename,
  state,
  count(*)
FROM pg_stat_activity
GROUP BY datname, usename, state
ORDER BY count(*) DESC;

SELECT
  max_conn.setting::int AS max_connections,
  used.used_connections,
  round(100.0 * used.used_connections / max_conn.setting::int, 2) AS pct_used
FROM
  (SELECT setting FROM pg_settings WHERE name = 'max_connections') max_conn,
  (SELECT count(*) AS used_connections FROM pg_stat_activity) used;
```

### Memory

For memory, I look at `shared_buffers`, `work_mem`, `maintenance_work_mem`, `effective_cache_size`, and connection count together. `work_mem` is especially dangerous because it can be used multiple times per query and per connection. Raising it globally without understanding concurrency can cause memory pressure.

Checks:

```sql
SELECT name, setting, unit, context, pending_restart
FROM pg_settings
WHERE name IN (
  'shared_buffers',
  'work_mem',
  'maintenance_work_mem',
  'effective_cache_size',
  'max_connections'
)
ORDER BY name;
```

Example interview wording:

> I avoid tuning memory parameters in isolation. A `work_mem` value that is safe at 20 active sessions may be unsafe at 500 active sessions, especially with complex joins and sorts. I prefer to fix bad plans, add indexes, use pooling, and set higher memory locally for controlled maintenance or reporting jobs rather than globally inflating memory.

Session-level example:

```sql
BEGIN;
SET LOCAL work_mem = '256MB';
-- Run one known-heavy reporting query here.
COMMIT;
```

### Query performance

For query tuning, I want `pg_stat_statements` enabled if possible. I look for high total time, high mean time, high rows scanned, temp file usage, and queries with poor plan stability.

Checks:

```sql
-- Extension check.
SELECT *
FROM pg_extension
WHERE extname = 'pg_stat_statements';

-- Top queries by total execution time.
SELECT
  queryid,
  calls,
  round(total_exec_time::numeric, 2) AS total_exec_ms,
  round(mean_exec_time::numeric, 2) AS mean_exec_ms,
  rows,
  left(query, 300) AS query_sample
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;

-- Queries creating temp blocks, often sorts/hash operations spilling to disk.
SELECT
  calls,
  temp_blks_read,
  temp_blks_written,
  round(mean_exec_time::numeric, 2) AS mean_exec_ms,
  left(query, 300) AS query_sample
FROM pg_stat_statements
WHERE temp_blks_written > 0
ORDER BY temp_blks_written DESC
LIMIT 20;
```

Plan check:

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT ...;
```

Interview wording:

> I do not call a query tuned until I have looked at the actual plan with buffers. Estimated cost alone is not enough. I want to know whether we are doing sequential scans intentionally, whether joins match the expected cardinality, whether sorts spill, whether indexes are selective, and whether the query shape is stable under production-like parameters.

### Vacuum and bloat

Autovacuum is not optional in PostgreSQL. In RDS, I pay close attention to dead tuples, transaction age, long transactions, and whether autovacuum is keeping up. Most teams notice vacuum only after they have bloat, wraparound warnings, or query degradation.

Checks:

```sql
-- Dead tuples and vacuum activity.
SELECT
  schemaname,
  relname,
  n_live_tup,
  n_dead_tup,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 30;

-- Transaction age risk.
SELECT
  datname,
  age(datfrozenxid) AS xid_age
FROM pg_database
ORDER BY xid_age DESC;

-- Tables with high dead tuple ratio.
SELECT
  schemaname,
  relname,
  n_live_tup,
  n_dead_tup,
  round(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_pct
FROM pg_stat_user_tables
WHERE n_live_tup + n_dead_tup > 0
ORDER BY dead_pct DESC
LIMIT 30;
```

Interview wording:

> I treat autovacuum as a workload participant. For write-heavy tables, the defaults may not be aggressive enough. I tune per table when needed instead of blindly increasing global autovacuum settings. I also look for long transactions because they can prevent cleanup even when autovacuum is running.

Per-table example:

```sql
ALTER TABLE public.orders SET (
  autovacuum_vacuum_scale_factor = 0.02,
  autovacuum_analyze_scale_factor = 0.01,
  autovacuum_vacuum_threshold = 5000,
  autovacuum_analyze_threshold = 5000
);
```

### Logging and slow query visibility

In RDS, PostgreSQL logs can be exported and reviewed through AWS tooling. I usually want slow query logging, lock wait visibility, and enough context to debug incidents without drowning the system in logs.

Checks:

```sql
SELECT name, setting, unit, context, pending_restart
FROM pg_settings
WHERE name IN (
  'log_min_duration_statement',
  'log_lock_waits',
  'deadlock_timeout',
  'log_temp_files',
  'log_statement'
)
ORDER BY name;
```

Example parameter stance:

```text
log_min_duration_statement = 500ms or 1000ms depending on workload
log_lock_waits = on
log_temp_files = 0 in short diagnostic windows, otherwise a higher threshold
log_statement = usually not 'all' in production unless doing a controlled investigation
```

### I/O and storage

For I/O, I connect PostgreSQL symptoms to AWS metrics. High read latency, write latency, queue depth, burst balance issues, or storage throughput limits can look like database slowness. I also check whether query plans are forcing unnecessary I/O.

Checks:

```sql
-- Database-level block hit ratio. Useful, but do not worship it blindly.
SELECT
  datname,
  blks_read,
  blks_hit,
  round(100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 2) AS cache_hit_pct
FROM pg_stat_database
ORDER BY blks_read DESC;

-- Index usage signal.
SELECT
  schemaname,
  relname,
  seq_scan,
  idx_scan,
  n_live_tup
FROM pg_stat_user_tables
ORDER BY seq_scan DESC
LIMIT 30;
```

AWS metrics I care about:

```text
CPUUtilization
FreeableMemory
DatabaseConnections
ReadLatency / WriteLatency
ReadIOPS / WriteIOPS
ReadThroughput / WriteThroughput
DiskQueueDepth
FreeStorageSpace
ReplicaLag
TransactionLogsGeneration or WAL-related metrics where available
```

## Takeaway summary

Good RDS tuning is not random parameter editing. It is bottleneck isolation, measured changes, parameter group discipline, and tight feedback from PostgreSQL views plus AWS telemetry.

---

# 4. Cross-Region and multi-datacenter PostgreSQL realities

## Interview response

The most important thing to say about cross-Region PostgreSQL is that physics wins. Latency, asynchronous replication, conflict handling, failover time, DNS propagation, application retries, and data reconciliation are the real system. A diagram with two Regions does not automatically mean active-active, zero data loss, or simple failover.

In most RDS PostgreSQL designs, cross-Region read replicas are asynchronous. They are useful for disaster recovery and sometimes for local reads in another geography, but they do not provide strong global write consistency. If Region A accepts a write and fails before the WAL reaches Region B, there may be data loss unless the architecture has a synchronous commit path, which is usually not what standard cross-Region RDS read replicas provide.

So I make the trade-off explicit:

- If the business needs low RPO and simple operations, stay single-writer and use managed HA plus async DR.
- If the business needs local writes in multiple Regions, expect conflict resolution, data ownership rules, or a different database architecture.
- If the business needs global reads, replicas can help, but read-your-writes semantics must be handled carefully.

## Replication types and tools

### Physical streaming replication

Best for:

- Same-engine, same-major-version style replication.
- HA/read replica patterns.
- Whole-cluster replication.
- Fast setup when source and target are compatible.

Trade-offs:

- Replicates the whole physical database state.
- Less flexible for selective table replication.
- Version and platform compatibility matter.
- Asynchronous replicas can lag.

RDS examples:

- Same-Region read replicas.
- Cross-Region read replicas.
- Some managed Blue/Green cases depending on version path and AWS support.

### Logical replication

Best for:

- Selective table/database replication.
- Migrations.
- Some major version upgrade paths.
- Feeding reporting systems.
- Controlled data movement between different PostgreSQL versions.

Trade-offs:

- Needs replica identity for update/delete behavior.
- Sequences are not automatically solved in the same way as table rows.
- DDL replication is limited and usually needs separate handling.
- Replication slots can retain WAL if consumers fall behind.
- Large transactions can create lag and apply pressure.
- Conflict handling is not magic.

Native logical replication checks:

```sql
-- Publications.
SELECT * FROM pg_publication;

-- Publication tables.
SELECT * FROM pg_publication_tables
ORDER BY pubname, schemaname, tablename;

-- Subscriptions.
SELECT * FROM pg_subscription;

-- Subscription status.
SELECT * FROM pg_stat_subscription;

-- Replication slots and retained WAL risk.
SELECT
  slot_name,
  plugin,
  slot_type,
  database,
  active,
  restart_lsn,
  confirmed_flush_lsn,
  wal_status
FROM pg_replication_slots;
```

### AWS Database Migration Service

Best for:

- Heterogeneous migrations.
- One-time load plus change data capture.
- Moving data into or out of PostgreSQL.
- Migration projects where operational simplicity is more important than pure PostgreSQL-native behavior.

Trade-offs:

- DMS is a migration/CDC service, not a general-purpose substitute for database-native HA.
- You still validate row counts, constraints, latency, type mappings, and cutover behavior.
- LOB handling, DDL changes, and transformation rules need careful testing.

### pglogical or third-party logical tooling

Best for:

- More advanced logical replication needs than built-in publication/subscription provides.
- Selective replication and migration patterns where supported.

Trade-offs:

- Extension support and RDS compatibility must be verified.
- Operational complexity increases.
- You need strong monitoring for lag, slots, conflicts, and schema drift.

### Application-level replication or outbox pattern

Best for:

- Event-driven systems.
- Controlled cross-service data propagation.
- Avoiding multi-writer database conflicts by making ownership explicit.

Trade-offs:

- The application owns ordering, retries, idempotency, and reconciliation.
- Not a transparent database failover solution.

### Multi-master / active-active PostgreSQL

Best for:

- Rare cases with clear conflict rules, partitioned ownership, or specialized platforms.

Trade-offs:

- This is where many designs become unsafe. PostgreSQL is traditionally strongest as a single-writer system with replicas. Multi-writer across Regions needs serious conflict detection, conflict resolution, identity generation strategy, sequence strategy, and application semantics.

Interview wording:

> I am cautious with the phrase active-active. If both Regions can write the same logical rows, the hard problem is not replication transport. The hard problem is correctness: conflicts, ordering, uniqueness, sequences, idempotency, and what the application promises to users during partitions.

## Cross-Region practical checks

```sql
-- On primary: replication clients and lag.
SELECT
  application_name,
  client_addr,
  state,
  sent_lsn,
  replay_lsn,
  pg_wal_lsn_diff(sent_lsn, replay_lsn) AS bytes_lag
FROM pg_stat_replication
ORDER BY bytes_lag DESC NULLS LAST;

-- WAL generation rate sample. Run twice and compare over time.
SELECT now() AS sample_time, pg_current_wal_lsn() AS current_lsn;

-- Replication slots that may retain WAL.
SELECT
  slot_name,
  slot_type,
  active,
  restart_lsn,
  pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal
FROM pg_replication_slots
WHERE restart_lsn IS NOT NULL
ORDER BY pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) DESC;
```

AWS CLI cross-Region example:

```bash
aws rds describe-db-instances \
  --region us-east-1 \
  --query 'DBInstances[].{DB:DBInstanceIdentifier,Replicas:ReadReplicaDBInstanceIdentifiers,Source:ReadReplicaSourceDBInstanceIdentifier,Status:DBInstanceStatus}'

aws rds describe-db-instances \
  --region eu-west-1 \
  --query 'DBInstances[].{DB:DBInstanceIdentifier,Replicas:ReadReplicaDBInstanceIdentifiers,Source:ReadReplicaSourceDBInstanceIdentifier,Status:DBInstanceStatus}'
```

## Takeaway summary

Cross-Region database design is a trade-off between RPO, RTO, latency, consistency, cost, and operational complexity. Replication is not the same as correctness.

---

# 5. How I would answer direct interview questions

## Question: “How would you run PostgreSQL on AWS RDS?”

## Response

I would start by defining the workload and recovery objectives. For a normal production OLTP system, I would use RDS PostgreSQL with Multi-AZ, automated backups, encryption, a custom parameter group, controlled maintenance windows, and monitoring through CloudWatch, Performance Insights, logs, and PostgreSQL system views.

I would keep the write path simple: one primary writer endpoint. I would add read replicas only when there is a real need for read scale, reporting isolation, or DR. I would also put connection pooling in front of the database because connection storms are one of the fastest ways to turn a healthy PostgreSQL system into an incident.

Operationally, I would manage parameter groups as code, test restores, define alarms, review slow queries, watch vacuum health, and maintain a runbook for failover and replica promotion.

## Takeaway

I optimize first for correctness and recoverability, then for scale. RDS gives the platform; PostgreSQL engineering still gives the reliability.

---

## Question: “How do you tune PostgreSQL in RDS?”

## Response

I tune from evidence. First I identify whether the bottleneck is CPU, I/O, memory, locks, connections, vacuum, WAL, or query plans. Then I change the smallest thing that addresses that bottleneck and verify the result.

For RDS PostgreSQL, I look at PostgreSQL internals and AWS telemetry together. Inside PostgreSQL, I use `pg_stat_activity`, `pg_stat_statements`, `pg_stat_user_tables`, `pg_stat_database`, `pg_locks`, and `EXPLAIN (ANALYZE, BUFFERS)`. On AWS, I look at CloudWatch, Performance Insights, Enhanced Monitoring, RDS events, and logs.

The parameters I commonly review are `max_connections`, `shared_buffers`, `work_mem`, `maintenance_work_mem`, `effective_cache_size`, autovacuum settings, logging settings, and replication/WAL-related settings where applicable. I am careful with memory settings because the product of connections, query complexity, and `work_mem` can create instability.

## Takeaway

Good tuning is diagnosis, not folklore. The best parameter change is often no parameter change; sometimes the fix is a query, index, pool, vacuum setting, or application behavior.

---

## Question: “What are the hard parts of cross-Region PostgreSQL?”

## Response

The hard parts are latency, consistency, lag, failover, and reconciliation. Cross-Region read replicas are normally asynchronous, so they are useful for DR and distributed reads, but they do not guarantee zero data loss. If the primary Region fails before changes reach the replica, the business needs to understand the possible RPO impact.

Promotion is also not just a database command. You need endpoint routing, application retry behavior, DNS or configuration changes, secrets and IAM access, monitoring cutover, and a plan for what happens if the old primary returns.

For active-active, I am very cautious. If both sides can write the same data, you need conflict handling, global identity strategy, idempotency, and clear data ownership. Otherwise, the architecture can look highly available while quietly becoming incorrect.

## Takeaway

Cross-Region replication solves availability and locality problems only when the consistency model and failover process are explicit.

---

## Question: “Which replication tool would you use?”

## Response

It depends on the goal.

For normal RDS read scaling or DR, I would use managed RDS read replicas, including cross-Region replicas when needed. For whole-cluster compatible replication, physical replication is usually the cleanest path.

For selective replication, migrations, or some major-version upgrade paths, I would consider native logical replication or an AWS-managed workflow like Blue/Green where supported. I would verify table keys, replica identity, slots, lag, sequences, DDL handling, and application cutover.

For heterogeneous migrations or moving data between different engines or platforms, I would consider AWS DMS, but I would treat it as a migration and CDC tool, not as a native HA mechanism.

For active-active, I would push back and ask what problem we are solving. If it is local write latency, maybe the data model should partition ownership by Region. If it is disaster recovery, async replica plus tested promotion may be safer. If true multi-writer semantics are required, I would want a platform and design that explicitly supports conflict resolution.

## Takeaway

Choose the replication tool based on the failure mode and data semantics, not because it sounds more advanced.

---

# 6. Incident-style examples

## Example: CPU spike on RDS PostgreSQL

I would first identify whether CPU is query execution, connection churn, autovacuum, background workers, or lock contention.

Checks:

```sql
SELECT
  pid,
  usename,
  datname,
  state,
  wait_event_type,
  wait_event,
  now() - query_start AS query_age,
  left(query, 300) AS query_sample
FROM pg_stat_activity
WHERE state <> 'idle'
ORDER BY query_age DESC;

SELECT
  calls,
  round(total_exec_time::numeric, 2) AS total_exec_ms,
  round(mean_exec_time::numeric, 2) AS mean_exec_ms,
  left(query, 300) AS query_sample
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

Actions I would consider:

- Kill only clearly harmful sessions after understanding impact.
- Add or fix an index if a plan regressed.
- Roll back a bad deployment.
- Reduce pool size if connection pressure is amplifying CPU.
- Use a replica for safe reporting if reporting caused the spike.
- Scale instance class only if the workload is legitimate and optimized enough.

## Example: Replica lag increasing

I would check WAL generation, replica replay delay, long-running replica queries, network/Region issues, and whether a replication slot is retaining WAL.

Checks:

```sql
SELECT now() - pg_last_xact_replay_timestamp() AS replay_delay;

SELECT
  pid,
  state,
  now() - query_start AS query_age,
  wait_event_type,
  wait_event,
  left(query, 300) AS query_sample
FROM pg_stat_activity
WHERE state <> 'idle'
ORDER BY query_age DESC;
```

Actions I would consider:

- Stop or move long-running reporting queries.
- Increase replica size if apply cannot keep up.
- Check primary WAL generation after a batch job or migration.
- Review network and CloudWatch metrics.
- For logical replication, inspect subscription status and slots.

## Example: RDS parameter change needed

I would identify whether the parameter is dynamic or requires restart, test it in lower environments, update the parameter group through code, plan the maintenance window if needed, and check `pending_restart`.

Checks:

```sql
SELECT name, setting, context, pending_restart
FROM pg_settings
WHERE pending_restart = true
ORDER BY name;
```

AWS CLI:

```bash
aws rds describe-db-parameters \
  --db-parameter-group-name prod-postgres-params \
  --query 'Parameters[?ParameterName==`work_mem` || ParameterName==`max_connections` || ParameterName==`shared_buffers`].[ParameterName,ParameterValue,ApplyType,ApplyMethod]'
```

---

# 7. Closing interview answer

The way I operate PostgreSQL on AWS is pragmatic: let RDS handle the managed platform work, but keep PostgreSQL engineering discipline close to the workload. I do not assume Multi-AZ means the application is highly available. I do not assume replicas mean reads are consistent. I do not tune parameters without evidence. And I do not describe cross-Region replication without talking about RPO, RTO, lag, promotion, and reconciliation.

My strongest PostgreSQL teams have the same habits: they measure before changing, test restores, rehearse failover, keep parameter groups under control, use connection pooling, monitor vacuum and locks, and choose replication tools based on the actual data semantics.

Final takeaway: **RDS makes PostgreSQL easier to operate, but reliability still comes from clear architecture, measured tuning, and honest failure-mode thinking.**
