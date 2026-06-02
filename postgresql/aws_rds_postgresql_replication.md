# AWS RDS PostgreSQL Replication — Interview Responses

## Strong Opening

In an interview, I would frame PostgreSQL replication on AWS RDS as a reliability, scale, and recovery design topic, not just a database feature. The first thing I clarify is the business goal: are we trying to improve availability, scale reads, migrate data, reduce recovery time, or stream selected data into another system?

On RDS PostgreSQL, the important distinction is this:

- **Physical replication** moves the database at the WAL/block level and is used by RDS read replicas and standby/failover architectures.
- **Logical replication** moves row-level changes based on publications, subscriptions, or logical decoding slots, and is useful when we need selective replication, migrations, CDC, or integration with downstream systems.
- **Standby** means the replica exists primarily for high availability or failover. In classic RDS Multi-AZ DB instance deployments, the standby is managed by AWS and does not serve application read traffic.
- **Read replica** means a separate readable copy used for read scaling, reporting, DR, or migration support.

My practical approach is to design replication around RPO, RTO, lag tolerance, write volume, failover behavior, application connection handling, and operational monitoring.

---

## Table of Contents

1. [Executive Interview Summary](#executive-interview-summary)
2. [Replication in RDS PostgreSQL](#replication-in-rds-postgresql)
3. [Physical Replication](#physical-replication)
4. [Logical Replication](#logical-replication)
5. [Standby and Multi-AZ](#standby-and-multi-az)
6. [Read Replicas](#read-replicas)
7. [Common Interview Questions and Strong Responses](#common-interview-questions-and-strong-responses)
8. [Queries, Checks, and Examples](#queries-checks-and-examples)
9. [Troubleshooting Playbook](#troubleshooting-playbook)
10. [Takeaway Summary](#takeaway-summary)

---

## Executive Interview Summary

### How I would answer

AWS RDS PostgreSQL supports several replication patterns. I separate them by purpose:

| Pattern | Main Purpose | Readable? | Typical Use |
|---|---:|---:|---|
| Multi-AZ standby | High availability | Usually no for single-standby DB instance | Automatic failover |
| Read replica | Scale reads / DR / reporting | Yes | Read-heavy workloads |
| Physical replication | Full-instance WAL replication | Replica is physical copy | Read replicas and HA internals |
| Logical replication | Table-level or change-level replication | Subscriber can be writable depending on design | CDC, migration, selective replication |
| Cascading replica | Offload replication fanout | Yes | Reduce WAL sender pressure on primary |

The key interview point is that replication is not one design. It depends on whether we need fast failover, read scaling, selective data movement, or zero/low-downtime migration.

### Takeaway

A strong PostgreSQL engineer does not just say “use a replica.” They explain the tradeoff: physical replication is simple and complete, logical replication is flexible and selective, standby is for HA, and read replicas are for read scale and recovery options.

---

## Replication in RDS PostgreSQL

### Interview response

In PostgreSQL, replication is driven by the write-ahead log, or WAL. Every committed change is recorded in WAL before data files are updated. RDS PostgreSQL uses WAL-based replication for read replicas and high availability designs.

In RDS, some low-level access is abstracted away because AWS manages the underlying host, storage, and replication plumbing. That means I focus on supported parameters, replication slots, CloudWatch metrics, PostgreSQL system views, parameter groups, and failover behavior instead of managing `recovery.conf`, file system access, or direct OS-level PostgreSQL configuration.

### Key RDS-specific points

- RDS read replicas are managed by AWS.
- RDS Multi-AZ is primarily an HA feature.
- Logical replication requires parameter changes such as enabling `rds.logical_replication`.
- Logical replication can increase WAL volume, so it should not be enabled casually.
- Replica lag must be monitored from both PostgreSQL and CloudWatch.
- Application connection handling matters during failover because clients must reconnect.
- DNS caching and connection pools can delay recovery after failover.

### Takeaway

In RDS PostgreSQL, replication is PostgreSQL WAL-based technology wrapped in AWS-managed operations. The engineering skill is knowing what AWS manages, what PostgreSQL exposes, and what the application must still handle.

---

## Physical Replication

### Interview response

Physical replication copies the database at the WAL level. It replicates the whole database cluster as a binary-compatible copy, so the replica must run a compatible PostgreSQL version and storage format. In RDS PostgreSQL, read replicas are based on physical streaming replication concepts, although AWS manages much of the implementation.

I use physical replication when I need a full copy of the database for read scaling, disaster recovery, reporting, or regional placement. It is simple and reliable because it does not require table-by-table publication definitions. The tradeoff is that it is all-or-nothing: I cannot choose only certain tables or transform data during replication.

### Good interview wording

Physical replication is the right choice when I want the replica to be a faithful copy of the source database. It is ideal for read replicas and DR patterns. I would monitor replication lag, WAL retention, replica health, and query load on the replica, because long-running queries or resource pressure can cause lag.

### Advantages

- Full database copy.
- Simple operational model.
- Good for read scaling and DR.
- Managed read replica creation in RDS.
- Lower logical design complexity.

### Limitations

- Not selective at table level.
- Replica is read-only.
- Version compatibility matters.
- Replication lag can occur.
- Heavy read queries can slow WAL replay.
- Not a data transformation mechanism.

### Example: create a read replica using AWS CLI

```bash
aws rds create-db-instance-read-replica \
  --db-instance-identifier prod-pg-ro-1 \
  --source-db-instance-identifier prod-pg-primary \
  --db-instance-class db.m6i.large \
  --publicly-accessible false
```

### Check replica status from AWS CLI

```bash
aws rds describe-db-instances \
  --db-instance-identifier prod-pg-ro-1 \
  --query 'DBInstances[0].{Status:DBInstanceStatus,ReplicaSource:ReadReplicaSourceDBInstanceIdentifier,ReplicaMode:ReplicaMode,Engine:Engine,EngineVersion:EngineVersion}'
```

### Check PostgreSQL recovery state

Run this on the replica:

```sql
SELECT pg_is_in_recovery();
```

Expected result on a physical read replica:

```text
t
```

### Check replay timestamp and estimated lag

Run this on the replica:

```sql
SELECT
  now() AS replica_time,
  pg_last_wal_receive_lsn() AS received_lsn,
  pg_last_wal_replay_lsn() AS replayed_lsn,
  now() - pg_last_xact_replay_timestamp() AS replay_delay;
```

### Check sender status on the primary

Run this on the primary:

```sql
SELECT
  pid,
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

### Takeaway

Physical replication is best when I need a complete copy of the database with minimal application-level complexity. In RDS, I treat physical replicas as managed read replicas and focus on lag, WAL retention, workload isolation, and failover planning.

---

## Logical Replication

### Interview response

Logical replication replicates data changes at a logical level rather than copying the entire physical database. PostgreSQL uses publications and subscriptions, or logical decoding slots, to stream row changes. In RDS PostgreSQL, this is commonly used for selective table replication, change data capture, migrations, data warehouse feeds, and integration with services such as AWS DMS.

I use logical replication when the target does not need to be an exact physical copy, or when I need to replicate only specific tables, move data across versions, or stream changes into another platform. The tradeoff is that logical replication needs more careful setup: primary keys or replica identity, permissions, slots, publications, subscriptions, WAL retention, schema management, and conflict handling.

### Good interview wording

Logical replication gives flexibility, but it also creates operational responsibility. I check slot lag, table replica identity, subscription state, apply lag, schema drift, and whether the target can keep up. I am especially careful because an inactive logical replication slot can retain WAL and create storage pressure on the source.

### RDS prerequisites and considerations

- Use a custom DB parameter group.
- Enable `rds.logical_replication = 1`.
- Reboot is usually required because this is a static parameter.
- Ensure the user has suitable privileges, commonly `rds_superuser` for setup and `rds_replication` for replication-related work.
- Size `max_replication_slots`, `max_wal_senders`, and related settings appropriately.
- Watch WAL growth after enabling logical replication.
- Manage publications, subscriptions, and logical slots intentionally.

### Example: check logical replication parameter

```sql
SHOW rds.logical_replication;
SHOW wal_level;
SHOW max_replication_slots;
SHOW max_wal_senders;
```

### Example: create a publication on the source

```sql
CREATE TABLE public.customer_events (
  event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id bigint NOT NULL,
  event_type text NOT NULL,
  event_ts timestamptz NOT NULL DEFAULT now()
);

CREATE PUBLICATION customer_events_pub
FOR TABLE public.customer_events;
```

### Example: check publications

```sql
SELECT
  pubname,
  puballtables,
  pubinsert,
  pubupdate,
  pubdelete,
  pubtruncate
FROM pg_publication;
```

### Example: create a subscription on the target

```sql
CREATE SUBSCRIPTION customer_events_sub
CONNECTION 'host=source-rds-endpoint.amazonaws.com port=5432 dbname=appdb user=repl_user password=REDACTED sslmode=require'
PUBLICATION customer_events_pub
WITH (
  copy_data = true,
  create_slot = true,
  enabled = true
);
```

### Example: check subscription status on the subscriber

```sql
SELECT
  subname,
  pid,
  relid::regclass AS relation_name,
  received_lsn,
  latest_end_lsn,
  latest_end_time
FROM pg_stat_subscription;
```

### Example: check replication slots on the publisher

```sql
SELECT
  slot_name,
  plugin,
  slot_type,
  database,
  active,
  restart_lsn,
  confirmed_flush_lsn,
  pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal
FROM pg_replication_slots
ORDER BY pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) DESC;
```

### Example: check tables without primary keys

Logical replication works best when replicated tables have primary keys. Without a primary key, updates and deletes can become problematic unless replica identity is configured.

```sql
SELECT
  n.nspname AS schema_name,
  c.relname AS table_name
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_index i
  ON i.indrelid = c.oid
 AND i.indisprimary
WHERE c.relkind = 'r'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND i.indrelid IS NULL
ORDER BY 1, 2;
```

### Example: set replica identity carefully

```sql
ALTER TABLE public.customer_events REPLICA IDENTITY DEFAULT;
```

For a table without a primary key, only when the workload and table size justify it:

```sql
ALTER TABLE public.some_table REPLICA IDENTITY FULL;
```

### Logical decoding slot example

```sql
SELECT *
FROM pg_create_logical_replication_slot('cdc_slot_1', 'test_decoding');
```

```sql
SELECT *
FROM pg_logical_slot_get_changes('cdc_slot_1', NULL, 10);
```

Clean up when done:

```sql
SELECT pg_drop_replication_slot('cdc_slot_1');
```

### Takeaway

Logical replication is the flexible option for selective replication, migrations, CDC, and integrations. The operational risk is uncontrolled WAL retention, schema drift, poor replica identity, and subscribers that cannot keep up.

---

## Standby and Multi-AZ

### Interview response

In RDS PostgreSQL, a standby is usually discussed in the context of Multi-AZ high availability. With a classic Multi-AZ DB instance deployment, RDS maintains a synchronous standby in another Availability Zone. The purpose is failover, not read scaling. The standby is not used by the application for reads.

If the primary instance fails, RDS automatically fails over by promoting the standby and updating the database endpoint. From an application perspective, the endpoint remains the same, but connections are interrupted and must reconnect. That is why I always check connection pool behavior, DNS caching, retry logic, transaction retry safety, and timeout settings.

### Good interview wording

A standby is insurance for availability. A read replica is capacity for reads. Confusing those two is a common design mistake. For HA, I use Multi-AZ. For read scale, I use read replicas. For both, I may use a Multi-AZ primary plus read replicas, but I monitor each for a different purpose.

### Multi-AZ DB instance standby

| Characteristic | Behavior |
|---|---|
| Replication mode | Synchronous |
| Main purpose | High availability |
| Read traffic | No |
| Failover | Managed by RDS |
| Endpoint | Same DB endpoint after DNS update |
| User control over standby | Limited |
| Common concern | Application reconnect and DNS cache |

### Multi-AZ DB cluster note

RDS Multi-AZ DB clusters are different from classic Multi-AZ DB instances. Multi-AZ DB clusters have a writer and readable standby DB instances. They can provide both failover support and read capability depending on the deployment type.

### Check whether an RDS instance is Multi-AZ

```bash
aws rds describe-db-instances \
  --db-instance-identifier prod-pg-primary \
  --query 'DBInstances[0].{MultiAZ:MultiAZ,AvailabilityZone:AvailabilityZone,SecondaryAZ:SecondaryAvailabilityZone,Status:DBInstanceStatus}'
```

### Check failover-related events

```bash
aws rds describe-events \
  --source-type db-instance \
  --source-identifier prod-pg-primary \
  --duration 1440
```

### Application-level checks

```text
- Does the application reconnect cleanly?
- Does the connection pool discard broken connections?
- Is DNS TTL low enough?
- Are transactions idempotent or retry-safe?
- Are writes retried only when safe?
- Are health checks testing real database connectivity?
- Are long-running jobs able to resume after disconnect?
```

### Takeaway

Standby in RDS Multi-AZ is about HA and failover, not read scaling. The database platform may fail over automatically, but the application still needs proper reconnect and retry behavior.

---

## Read Replicas

### Interview response

A read replica is a readable copy of the primary database. In RDS PostgreSQL, I use read replicas for read scaling, reporting, expensive analytics, operational dashboards, and disaster recovery patterns. Read replicas are asynchronous, so I design applications with replica lag in mind.

I do not send strongly consistent reads to a replica immediately after a write unless the application can tolerate stale data or has read-after-write routing logic.

### Good interview wording

Read replicas are great for offloading read traffic, but they are not a free consistency layer. I design read routing carefully. For example, after a user updates their profile, I may read from the primary for a short window to avoid stale reads.

### Example read routing strategy

```text
- Writes go to primary.
- Critical read-after-write queries go to primary.
- Reporting queries go to read replica.
- Search/indexing/ETL jobs use replicas where lag is acceptable.
- If replica lag exceeds threshold, route sensitive reads back to primary.
```

### Check read replica lag in SQL

On a replica:

```sql
SELECT
  now() - pg_last_xact_replay_timestamp() AS replay_delay,
  pg_last_wal_receive_lsn() AS received_lsn,
  pg_last_wal_replay_lsn() AS replayed_lsn;
```

On the primary:

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

### CloudWatch metrics to monitor

```text
- ReplicaLag
- FreeStorageSpace
- WriteIOPS
- ReadIOPS
- DiskQueueDepth
- CPUUtilization
- DatabaseConnections
- TransactionLogsGeneration
- TransactionLogsDiskUsage
```

### Takeaway

Read replicas are for read scale and workload isolation. They must be treated as eventually consistent unless the architecture explicitly handles lag.

---

## Common Interview Questions and Strong Responses

### 1. What is the difference between logical and physical replication?

Physical replication copies the whole database at the WAL level and produces a binary-compatible copy. It is best for read replicas, DR, and full-instance replication.

Logical replication sends row-level changes from selected tables or publications. It is best for CDC, migrations, selective replication, and heterogeneous downstream systems.

The key tradeoff is simplicity versus flexibility. Physical replication is simpler and complete. Logical replication is more flexible but requires more operational care.

### 2. What is the difference between a standby and a read replica in RDS?

A standby is for high availability. In a classic RDS Multi-AZ DB instance deployment, AWS maintains a synchronous standby in another AZ and promotes it during failover. It does not serve read traffic.

A read replica is for read scaling or DR. It is readable and usually asynchronous, so lag must be monitored.

### 3. How do you monitor replication health?

I monitor at three levels:

1. PostgreSQL system views:
   - `pg_stat_replication`
   - `pg_stat_subscription`
   - `pg_replication_slots`
   - `pg_stat_wal_receiver`

2. AWS metrics:
   - `ReplicaLag`
   - CPU, IOPS, storage, transaction log usage

3. Application behavior:
   - stale reads
   - reconnect behavior
   - failed jobs
   - increased query latency

### 4. What causes replication lag?

Common causes include:

- High write volume on the primary.
- Slow network or cross-Region distance.
- Under-sized replica instance.
- Long-running queries on the replica.
- Lock contention or replay conflicts.
- WAL retention pressure.
- Subscriber apply process cannot keep up.
- Missing indexes on the subscriber for logical replication workloads.
- Large transactions.

### 5. How do you troubleshoot replica lag?

I first identify whether the bottleneck is generation, transport, or replay/apply.

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

Then I check the replica:

```sql
SELECT
  pg_is_in_recovery(),
  pg_last_wal_receive_lsn(),
  pg_last_wal_replay_lsn(),
  now() - pg_last_xact_replay_timestamp() AS replay_delay;
```

For logical replication, I check slots:

```sql
SELECT
  slot_name,
  active,
  restart_lsn,
  confirmed_flush_lsn,
  pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal
FROM pg_replication_slots;
```

Then I check resources: CPU, I/O, locks, long queries, and storage.

### 6. How would you design HA and read scaling together?

I would use Multi-AZ for HA and separate read replicas for read scaling. Multi-AZ protects the writer through automatic failover. Read replicas offload read traffic. They solve different problems, so I would not use a read replica as my only HA design unless the RTO/RPO requirements were loose and manual promotion was acceptable.

### 7. What are the risks of logical replication?

The main risks are:

- WAL retention from inactive slots.
- Schema drift between publisher and subscriber.
- Tables without primary keys.
- Large transactions causing apply delay.
- Replication conflicts.
- Subscriber capacity limits.
- Initial copy impact.
- Operational complexity during upgrades and failovers.

### 8. What happens during an RDS Multi-AZ failover?

RDS promotes the standby and updates the DB endpoint. Existing connections are interrupted. The application must reconnect. Good systems use connection pool validation, low DNS cache TTL, retries with backoff, and safe transaction retry logic.

### 9. Can logical replication replicate DDL?

Native PostgreSQL logical replication focuses on data changes, not general schema changes. DDL must usually be managed separately through migrations. In an interview, I would explicitly call out schema migration discipline as part of the logical replication design.

### 10. How do you avoid stale reads from read replicas?

I use one or more of these patterns:

- Route read-after-write traffic to the primary.
- Use session stickiness to primary after writes.
- Check replica lag before routing.
- Use application-level consistency rules.
- Avoid replicas for user-facing critical confirmation reads.
- Use replicas mainly for reporting, dashboards, and async workloads.

---

## Queries, Checks, and Examples

### Check if current node is primary or replica

```sql
SELECT
  CASE
    WHEN pg_is_in_recovery() THEN 'replica'
    ELSE 'primary'
  END AS node_role;
```

### Check WAL location on primary

```sql
SELECT pg_current_wal_lsn();
```

### Check WAL receive and replay on replica

```sql
SELECT
  pg_last_wal_receive_lsn(),
  pg_last_wal_replay_lsn(),
  pg_last_xact_replay_timestamp();
```

### Estimate replica replay delay

```sql
SELECT now() - pg_last_xact_replay_timestamp() AS replay_delay;
```

### Check physical replication senders on primary

```sql
SELECT
  pid,
  usename,
  application_name,
  client_addr,
  backend_start,
  state,
  sync_state,
  sent_lsn,
  write_lsn,
  flush_lsn,
  replay_lsn,
  write_lag,
  flush_lag,
  replay_lag
FROM pg_stat_replication
ORDER BY application_name;
```

### Check WAL receiver on replica

```sql
SELECT
  status,
  receive_start_lsn,
  written_lsn,
  flushed_lsn,
  received_tli,
  last_msg_send_time,
  last_msg_receipt_time,
  latest_end_lsn,
  latest_end_time,
  conninfo
FROM pg_stat_wal_receiver;
```

### Check logical replication subscriptions

```sql
SELECT
  subid,
  subname,
  pid,
  relid::regclass AS relation_name,
  received_lsn,
  latest_end_lsn,
  latest_end_time
FROM pg_stat_subscription;
```

### Check logical replication slot retention

```sql
SELECT
  slot_name,
  slot_type,
  plugin,
  database,
  active,
  restart_lsn,
  confirmed_flush_lsn,
  pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal
FROM pg_replication_slots
ORDER BY pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) DESC;
```

### Check publication tables

```sql
SELECT
  p.pubname,
  schemaname,
  tablename
FROM pg_publication p
JOIN pg_publication_tables pt
  ON p.pubname = pt.pubname
ORDER BY p.pubname, schemaname, tablename;
```

### Check subscription table sync state

```sql
SELECT
  srsubid,
  srrelid::regclass AS table_name,
  srsubstate,
  srsublsn
FROM pg_subscription_rel
ORDER BY table_name;
```

### Check long-running queries on replica

```sql
SELECT
  pid,
  usename,
  application_name,
  client_addr,
  state,
  now() - query_start AS query_age,
  wait_event_type,
  wait_event,
  query
FROM pg_stat_activity
WHERE state <> 'idle'
ORDER BY query_age DESC;
```

### Check blocked sessions

```sql
SELECT
  blocked.pid AS blocked_pid,
  blocked.query AS blocked_query,
  blocking.pid AS blocking_pid,
  blocking.query AS blocking_query
FROM pg_stat_activity blocked
JOIN pg_locks blocked_locks
  ON blocked_locks.pid = blocked.pid
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
 AND blocking_locks.pid <> blocked_locks.pid
JOIN pg_stat_activity blocking
  ON blocking.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted
  AND blocking_locks.granted;
```

### Check RDS DB instance metadata

```bash
aws rds describe-db-instances \
  --db-instance-identifier prod-pg-primary \
  --query 'DBInstances[0].{
    DBInstanceIdentifier:DBInstanceIdentifier,
    Engine:Engine,
    EngineVersion:EngineVersion,
    MultiAZ:MultiAZ,
    DBInstanceStatus:DBInstanceStatus,
    ReadReplicaSource:ReadReplicaSourceDBInstanceIdentifier,
    ReadReplicas:ReadReplicaDBInstanceIdentifiers,
    AvailabilityZone:AvailabilityZone,
    SecondaryAZ:SecondaryAvailabilityZone
  }'
```

### Check CloudWatch replica lag

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ReplicaLag \
  --dimensions Name=DBInstanceIdentifier,Value=prod-pg-ro-1 \
  --statistics Average,Maximum \
  --period 60 \
  --start-time 2026-06-02T00:00:00Z \
  --end-time 2026-06-02T01:00:00Z
```

---

## Troubleshooting Playbook

### Scenario 1: Read replica lag is increasing

First, determine if WAL is not reaching the replica or if replay is slow.

```sql
SELECT
  application_name,
  state,
  write_lag,
  flush_lag,
  replay_lag
FROM pg_stat_replication;
```

Then check replica resource pressure:

```sql
SELECT
  now() - query_start AS query_age,
  wait_event_type,
  wait_event,
  query
FROM pg_stat_activity
WHERE state <> 'idle'
ORDER BY query_age DESC;
```

Likely fixes:

- Scale the replica.
- Stop or tune long-running reporting queries.
- Add indexes for read workload.
- Reduce primary write bursts.
- Move heavy analytics elsewhere.
- Review cross-Region latency.
- Check storage, IOPS, and CPU.

### Scenario 2: Logical replication slot is retaining too much WAL

Check slot retention:

```sql
SELECT
  slot_name,
  active,
  pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal
FROM pg_replication_slots
ORDER BY pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) DESC;
```

Likely fixes:

- Restart the subscriber or CDC consumer.
- Check subscriber apply errors.
- Drop unused slots.
- Increase subscriber capacity.
- Break up large transactions.
- Alert on retained WAL size.

### Scenario 3: Logical replication subscription is not applying changes

Check subscription state:

```sql
SELECT *
FROM pg_stat_subscription;
```

Check table sync state:

```sql
SELECT
  srrelid::regclass AS table_name,
  srsubstate,
  srsublsn
FROM pg_subscription_rel;
```

Likely fixes:

- Check target table schema.
- Check permissions.
- Check primary keys or replica identity.
- Check network/security group rules.
- Check subscription connection string.
- Review PostgreSQL logs in RDS.

### Scenario 4: Application had errors during Multi-AZ failover

Likely causes:

- Connection pool held stale connections.
- DNS was cached too long.
- Application did not retry safely.
- Long transactions were interrupted.
- Health checks did not force reconnect.

Recommended controls:

```text
- Use short connection lifetime in pools.
- Validate connections before reuse.
- Configure retry with backoff.
- Make writes idempotent where possible.
- Keep DNS TTL behavior sane.
- Test failover regularly.
```

### Scenario 5: Connecting Using RDS/EC2

#### 1. Get the replica endpoint from AWS
```bash
aws rds describe-db-instances \
  --db-instance-identifier prod-postgres-replica \
  --query 'DBInstances[0].Endpoint.{Address:Address,Port:Port}' \
  --output table
```

Example output:
```
------------------------------------------------
|              DescribeDBInstances             |
+----------+-----------------------------------+
| Address  | prod-postgres-replica.abc123.eu-west-1.rds.amazonaws.com |
| Port     | 5432                              |
```


#### 2. Export the DSN
```bash
export REPLICA_DSN="postgresql://DB_USER:DB_PASSWORD@prod-postgres-replica.abc123.eu-west-1.rds.amazonaws.com:5432/DB_NAME?sslmode=require"

Replace:
DB_USER       your PostgreSQL username
DB_PASSWORD   your PostgreSQL password
DB_NAME       the database name, for example postgres or appdb
```

#### 3. Test it
```bash
psql "$REPLICA_DSN" -c "SELECT pg_is_in_recovery();"

Expected result for a read replica:

 pg_is_in_recovery
-------------------
 t

```

A safer pattern is to avoid putting the password in shell history:
```bash
export PGHOST="prod-postgres-replica.abc123.eu-west-1.rds.amazonaws.com"
export PGPORT="5432"
export PGDATABASE="DB_NAME"
export PGUSER="DB_USER"
export PGPASSWORD='DB_PASSWORD'

psql "sslmode=require" -c "SELECT pg_is_in_recovery();"
```

For production, prefer AWS Secrets Manager, IAM auth, or a .pgpass file instead of exporting PGPASSWORD

Store something like this in Secrets Manager:
```json
{
  "username": "app_readonly",
  "password": "REDACTED_PASSWORD",
  "dbname": "postgres",
  "host": "prod-postgres-replica.abc123.eu-west-1.rds.amazonaws.com",
  "port": 5432
}
```


**Load it into a DSN**

```bash
SECRET_ID="prod/postgres/replica"
REGION="eu-west-1"

SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ID" \
  --region "$REGION" \
  --query SecretString \
  --output text)

DB_USER=$(echo "$SECRET_JSON" | jq -r '.username')
DB_PASSWORD=$(echo "$SECRET_JSON" | jq -r '.password')
DB_NAME=$(echo "$SECRET_JSON" | jq -r '.dbname')
DB_HOST=$(echo "$SECRET_JSON" | jq -r '.host')
DB_PORT=$(echo "$SECRET_JSON" | jq -r '.port')

export REPLICA_DSN="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=require"

psql "$REPLICA_DSN" -c "SELECT pg_is_in_recovery();"
```

Better for shell history: avoid putting the password into the DSN string.
```bash
export PGHOST="$DB_HOST"
export PGPORT="$DB_PORT"
export PGDATABASE="$DB_NAME"
export PGUSER="$DB_USER"
export PGPASSWORD="$DB_PASSWORD"

psql "sslmode=require" -c "SELECT pg_is_in_recovery();"
```

Best fit: scripts, CI jobs, ECS tasks, Lambda, Kubernetes jobs, and automation where password auth is acceptable but secrets must be centrally managed.


##### Option 2: IAM database authentication

1. Enable IAM auth on the RDS instance
```bash
aws rds modify-db-instance \
  --db-instance-identifier prod-postgres-replica \
  --enable-iam-database-authentication \
  --apply-immediately
```

2. Create or alter a PostgreSQL user

Run this as a privileged DB user:
```sql
CREATE USER iam_readonly;
GRANT rds_iam TO iam_readonly;

GRANT CONNECT ON DATABASE postgres TO iam_readonly;
GRANT USAGE ON SCHEMA public TO iam_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO iam_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO iam_readonly;
```

3. Give your AWS principal permission to connect
The IAM policy uses rds-db:connect, not normal rds:* permissions.
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "rds-db:connect",
      "Resource": "arn:aws:rds-db:eu-west-1:123456789012:dbuser:db-RESOURCE-ID/iam_readonly"
    }
  ]
}
```

You need the RDS resource ID, not just the instance name:
```bash
aws rds describe-db-instances \
  --db-instance-identifier prod-postgres-replica \
  --query 'DBInstances[0].DbiResourceId' \
  --output text
```

4. Generate a token and connect
- AWS provides generate-db-auth-token for this flow.
- https://docs.aws.amazon.com/cli/latest/reference/rds/generate-db-auth-token.html

```bash
REGION="eu-west-1"
DB_HOST="prod-postgres-replica.abc123.eu-west-1.rds.amazonaws.com"
DB_PORT="5432"
DB_NAME="postgres"
DB_USER="iam_readonly"

export PGPASSWORD="$(aws rds generate-db-auth-token \
  --hostname "$DB_HOST" \
  --port "$DB_PORT" \
  --region "$REGION" \
  --username "$DB_USER")"

psql \
  "host=$DB_HOST port=$DB_PORT dbname=$DB_NAME user=$DB_USER sslmode=require" \
  -c "SELECT pg_is_in_recovery();"
```

Best fit: EC2 with instance profiles, ECS task roles, EKS IRSA/pod identity, Lambda roles, and operators who already use AWS SSO or assumed roles.


##### Option 3: .pgpass file
Use this when you want simple local psql access without typing a password. PostgreSQL’s libpq clients, including psql, can read passwords from ~/.pgpass. The format is hostname:port:database:username:password

**Create the file**
```bash
cat > ~/.pgpass <<'EOF'
prod-postgres-replica.abc123.eu-west-1.rds.amazonaws.com:5432:postgres:app_readonly:REDACTED_PASSWORD
EOF

chmod 600 ~/.pgpass
```

The permission matters. If it is too open, PostgreSQL clients may ignore it.


**Connect without password prompt**
```bash
psql \
  "host=prod-postgres-replica.abc123.eu-west-1.rds.amazonaws.com port=5432 dbname=postgres user=app_readonly sslmode=require" \
  -c "SELECT pg_is_in_recovery();"
```

You can also define:
```bash
export REPLICA_DSN="host=prod-postgres-replica.abc123.eu-west-1.rds.amazonaws.com port=5432 dbname=postgres user=app_readonly sslmode=require"

psql "$REPLICA_DSN" -c "SELECT pg_is_in_recovery();"
```

Best fit: local admin boxes, bastion hosts, cron jobs, and quick operational checks. Avoid this on shared machines unless file permissions and OS user boundaries are tight.

- For production automation, use IAM auth where possible. No long-lived DB password, good fit for AWS-native workloads.
- For existing apps that already use password auth, use Secrets Manager.
- For your own terminal or a controlled bastion, .pgpass is the fastest and simplest.

---

## Takeaway Summary

### Replication

Replication in RDS PostgreSQL should always be tied to a goal: HA, read scale, DR, migration, or data integration.

### Logical replication

Logical replication is best for selective replication, CDC, migrations, and cross-system integrations. It requires careful management of slots, schema, replica identity, and subscriber health.

### Physical replication

Physical replication is best for complete database copies, read replicas, and DR. It is simpler but less flexible.

### Standby

A standby in classic RDS Multi-AZ is for automatic failover, not read scaling. It protects availability but does not remove the need for application reconnect logic.

### Read replicas

Read replicas are readable and useful for scaling reads, but they are asynchronous and can return stale data.

### Final interview close

My closing answer would be:

> I design RDS PostgreSQL replication by separating HA from scale and physical replication from logical replication. Multi-AZ standby protects availability. Read replicas scale reads and support DR patterns. Logical replication supports selective data movement, CDC, and migrations. The operational success depends on monitoring lag, WAL retention, replication slots, failover behavior, and application reconnect logic.
