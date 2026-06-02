# PostgreSQL Operations Runbook — Disconnecting Sessions, Restarting, Reloading, and DBA Tools

This runbook explains how to inspect, cancel, disconnect, block, reload, stop, start, and restart PostgreSQL safely. It also lists the main PostgreSQL command-line tools used by DBAs, DevOps engineers, and incident responders.

---

## Table of Contents

- [1. Safety Rules](#1-safety-rules)
- [2. Terminology](#2-terminology)
- [3. Quick Decision Tree](#3-quick-decision-tree)
- [4. Inspect Current Connections](#4-inspect-current-connections)
- [5. Cancel a Running Query](#5-cancel-a-running-query)
- [6. Disconnect / Kill a Session](#6-disconnect--kill-a-session)
- [7. Disconnect Many Sessions Safely](#7-disconnect-many-sessions-safely)
- [8. Block New Connections During Maintenance](#8-block-new-connections-during-maintenance)
- [9. Drain a Database Before Maintenance](#9-drain-a-database-before-maintenance)
- [10. Reload Configuration Without Restart](#10-reload-configuration-without-restart)
- [11. Restart PostgreSQL](#11-restart-postgresql)
- [12. Stop and Start PostgreSQL](#12-stop-and-start-postgresql)
- [13. Shutdown Modes](#13-shutdown-modes)
- [14. Validate the Database After Reload or Restart](#14-validate-the-database-after-reload-or-restart)
- [15. Managed PostgreSQL: RDS, Aurora, Cloud SQL, Azure](#15-managed-postgresql-rds-aurora-cloud-sql-azure)
- [16. PostgreSQL DBA Tools](#16-postgresql-dba-tools)
- [17. Useful SQL Views and Functions](#17-useful-sql-views-and-functions)
- [18. Common Incident Patterns](#18-common-incident-patterns)
- [19. Copy/Paste Command Reference](#19-copypaste-command-reference)
- [20. Source References](#20-source-references)

---

## 1. Safety Rules

1. Prefer **cancel query** before **terminate session**.
2. Prefer **reload** before **restart** when the setting supports reload.
3. Do not kill autovacuum casually. Autovacuum protects the database from bloat and transaction ID wraparound.
4. Do not terminate replication, backup, restore, migration, or failover sessions unless you understand the blast radius.
5. Always exclude your own session from bulk termination.
6. For application incidents, first check whether the app is creating new connections faster than you can kill them.
7. For connection storms, combine termination with connection blocking or pool throttling.
8. Before restart, check replication, active writes, long transactions, backups, and maintenance jobs.
9. After restart, verify readiness, replication, logs, and application health.
10. On managed PostgreSQL, use provider-native restart/reboot controls where required.

---

## 2. Terminology

| Term | Meaning |
|---|---|
| Backend | A PostgreSQL server process handling one client connection. |
| Session | A connected client backend. |
| Query | A SQL command currently running in a session. |
| Cancel | Stop the current query but keep the session connected. |
| Terminate | Disconnect the session by ending its backend process. |
| Reload | Re-read config files without full database restart. |
| Restart | Stop and start the PostgreSQL server. Existing sessions disconnect. |
| Postmaster context | PostgreSQL setting context that requires restart. |
| SIGHUP context | PostgreSQL setting context that can usually be reloaded. |

---

## 3. Quick Decision Tree

### Problem: One query is bad

Use:

```sql
SELECT pg_cancel_backend(<pid>);
```

If it does not stop or the session keeps causing damage:

```sql
SELECT pg_terminate_backend(<pid>);
```

### Problem: One user or app has too many sessions

Use:

```sql
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE usename = 'app_user'
  AND pid <> pg_backend_pid();
```

### Problem: Need config change that supports reload

Use:

```sql
SELECT pg_reload_conf();
```

or:

```bash
pg_ctl reload -D "$PGDATA"
```

### Problem: Config change requires restart

Use the service manager or `pg_ctl restart`:

```bash
sudo systemctl restart postgresql
```

or:

```bash
pg_ctl restart -D "$PGDATA" -m fast
```

### Problem: Need clean planned maintenance

1. Block new application connections.
2. Let active work drain.
3. Terminate remaining idle sessions.
4. Reload or restart.
5. Validate.
6. Re-enable application connections.

---

## 4. Inspect Current Connections

### Basic active session view

```sql
SELECT
    pid,
    usename,
    datname,
    application_name,
    client_addr,
    state,
    wait_event_type,
    wait_event,
    now() - xact_start  AS xact_age,
    now() - query_start AS query_age,
    left(query, 160)    AS query
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
ORDER BY query_start NULLS LAST;
```

### Find active long-running queries

```sql
SELECT
    pid,
    usename,
    datname,
    application_name,
    client_addr,
    state,
    now() - query_start AS query_age,
    wait_event_type,
    wait_event,
    left(query, 200) AS query
FROM pg_stat_activity
WHERE state = 'active'
  AND now() - query_start > interval '5 minutes'
ORDER BY query_age DESC;
```

### Find idle transactions

Idle transactions can hold locks, block vacuum, and retain old row versions.

```sql
SELECT
    pid,
    usename,
    datname,
    application_name,
    client_addr,
    state,
    now() - xact_start AS xact_age,
    left(query, 200) AS last_query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
ORDER BY xact_age DESC;
```

### Find connection count by database/user/app

```sql
SELECT
    datname,
    usename,
    application_name,
    client_addr,
    state,
    count(*) AS connections
FROM pg_stat_activity
GROUP BY datname, usename, application_name, client_addr, state
ORDER BY connections DESC;
```

### Find blockers and blocked sessions

```sql
SELECT
    blocked.pid AS blocked_pid,
    blocked.usename AS blocked_user,
    now() - blocked.query_start AS blocked_for,
    left(blocked.query, 120) AS blocked_query,
    blocker.pid AS blocker_pid,
    blocker.usename AS blocker_user,
    now() - blocker.query_start AS blocker_query_age,
    left(blocker.query, 120) AS blocker_query
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
  AND blocker_locks.granted
ORDER BY blocked_for DESC;
```

---

## 5. Cancel a Running Query

`pg_cancel_backend(pid)` sends a cancel request to the backend. This is the safer first step because it tries to stop the active query without disconnecting the client session.

### Cancel one query

```sql
SELECT pg_cancel_backend(12345);
```

### Cancel all long active queries except your own

```sql
SELECT
    pid,
    pg_cancel_backend(pid) AS cancel_sent
FROM pg_stat_activity
WHERE state = 'active'
  AND pid <> pg_backend_pid()
  AND now() - query_start > interval '10 minutes';
```

### Cancel queries from one application

```sql
SELECT
    pid,
    pg_cancel_backend(pid) AS cancel_sent
FROM pg_stat_activity
WHERE application_name = 'my-app'
  AND state = 'active'
  AND pid <> pg_backend_pid();
```

### When cancel is appropriate

Use cancel when:

- A report query is running too long.
- A query is blocking other sessions but the client can stay connected.
- A migration statement was started by mistake.
- You want the least disruptive intervention.

### When cancel may not be enough

Use termination instead if:

- The session is idle in transaction and not actively running a query.
- The client immediately starts the bad query again.
- The backend is stuck waiting or not responding to cancel.
- You must forcibly release locks held by the session.

---

## 6. Disconnect / Kill a Session

`pg_terminate_backend(pid)` terminates the backend process for a session. The client connection is closed. Any open transaction in that session is rolled back.

### Terminate one backend

```sql
SELECT pg_terminate_backend(12345);
```

### Terminate an idle-in-transaction session

```sql
SELECT
    pid,
    usename,
    now() - xact_start AS xact_age,
    pg_terminate_backend(pid) AS terminated
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND pid = 12345
  AND pid <> pg_backend_pid();
```

### Terminate sessions connected to one database

```sql
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    pg_terminate_backend(pid) AS terminated
FROM pg_stat_activity
WHERE datname = 'target_database'
  AND pid <> pg_backend_pid();
```

### Terminate sessions for one user

```sql
SELECT
    pid,
    datname,
    application_name,
    client_addr,
    pg_terminate_backend(pid) AS terminated
FROM pg_stat_activity
WHERE usename = 'app_user'
  AND pid <> pg_backend_pid();
```

### Terminate sessions from one client address

```sql
SELECT
    pid,
    usename,
    datname,
    application_name,
    pg_terminate_backend(pid) AS terminated
FROM pg_stat_activity
WHERE client_addr = inet '10.20.30.40'
  AND pid <> pg_backend_pid();
```

### Terminate only idle sessions older than 30 minutes

```sql
SELECT
    pid,
    usename,
    datname,
    application_name,
    now() - state_change AS idle_for,
    pg_terminate_backend(pid) AS terminated
FROM pg_stat_activity
WHERE state = 'idle'
  AND now() - state_change > interval '30 minutes'
  AND pid <> pg_backend_pid();
```

### Terminate blockers only

Review blockers first, then terminate only the confirmed blocker.

```sql
WITH blockers AS (
    SELECT DISTINCT blocker.pid
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
      AND blocker_locks.granted
)
SELECT
    pid,
    pg_terminate_backend(pid) AS terminated
FROM blockers
WHERE pid <> pg_backend_pid();
```

---

## 7. Disconnect Many Sessions Safely

### Dry-run first

Before terminating sessions, run the matching query without `pg_terminate_backend`.

```sql
SELECT
    pid,
    usename,
    datname,
    application_name,
    client_addr,
    state,
    now() - state_change AS state_age,
    left(query, 120) AS query
FROM pg_stat_activity
WHERE datname = 'target_database'
  AND pid <> pg_backend_pid()
ORDER BY state_age DESC;
```

### Then terminate

```sql
SELECT
    pid,
    pg_terminate_backend(pid) AS terminated
FROM pg_stat_activity
WHERE datname = 'target_database'
  AND pid <> pg_backend_pid();
```

### Avoid these unless it is an emergency

Do not blindly run:

```sql
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE pid <> pg_backend_pid();
```

That can disconnect maintenance jobs, monitoring, replication-related sessions, backup clients, and admin users.

### Safer bulk filter

```sql
SELECT
    pid,
    usename,
    datname,
    application_name,
    client_addr,
    state,
    pg_terminate_backend(pid) AS terminated
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
  AND backend_type = 'client backend'
  AND usename = 'app_user'
  AND application_name = 'my-app';
```

---

## 8. Block New Connections During Maintenance

Disconnecting existing sessions is not enough if the application immediately reconnects. Block or drain new sessions first.

### Option A: Disable login for an application role

```sql
ALTER ROLE app_user NOLOGIN;
```

Re-enable later:

```sql
ALTER ROLE app_user LOGIN;
```

### Option B: Limit a role to zero connections

```sql
ALTER ROLE app_user CONNECTION LIMIT 0;
```

Restore later:

```sql
ALTER ROLE app_user CONNECTION LIMIT -1;
```

### Option C: Disallow connections to one database

This blocks non-superuser connections to the database.

```sql
ALTER DATABASE target_database WITH ALLOW_CONNECTIONS false;
```

Restore later:

```sql
ALTER DATABASE target_database WITH ALLOW_CONNECTIONS true;
```

### Option D: Revoke CONNECT privilege

```sql
REVOKE CONNECT ON DATABASE target_database FROM app_user;
```

Restore later:

```sql
GRANT CONNECT ON DATABASE target_database TO app_user;
```

### Option E: Change `pg_hba.conf`

Edit `pg_hba.conf` to reject or restrict the client source, then reload:

```sql
SELECT pg_reload_conf();
```

or:

```bash
pg_ctl reload -D "$PGDATA"
```

### Option F: Stop or pause the connection pool

For PgBouncer, application pools, Kubernetes workloads, or service mesh routing, drain at the pool/application layer first. This is usually cleaner than killing database sessions repeatedly.

---

## 9. Drain a Database Before Maintenance

### Step 1: Stop new application connections

Choose one:

```sql
ALTER ROLE app_user NOLOGIN;
```

or:

```sql
ALTER DATABASE target_database WITH ALLOW_CONNECTIONS false;
```

or pause the app/pool.

### Step 2: Watch active sessions

```sql
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    state,
    now() - query_start AS query_age,
    left(query, 160) AS query
FROM pg_stat_activity
WHERE datname = 'target_database'
  AND pid <> pg_backend_pid()
ORDER BY query_age DESC NULLS LAST;
```

### Step 3: Cancel long active work

```sql
SELECT
    pid,
    pg_cancel_backend(pid) AS cancel_sent
FROM pg_stat_activity
WHERE datname = 'target_database'
  AND state = 'active'
  AND pid <> pg_backend_pid();
```

### Step 4: Terminate remaining client backends

```sql
SELECT
    pid,
    pg_terminate_backend(pid) AS terminated
FROM pg_stat_activity
WHERE datname = 'target_database'
  AND backend_type = 'client backend'
  AND pid <> pg_backend_pid();
```

### Step 5: Perform maintenance

Examples:

```sql
ALTER DATABASE target_database RENAME TO target_database_old;
```

```bash
pg_ctl restart -D "$PGDATA" -m fast
```

### Step 6: Re-enable connections

```sql
ALTER ROLE app_user LOGIN;
```

```sql
ALTER DATABASE target_database WITH ALLOW_CONNECTIONS true;
```

---

## 10. Reload Configuration Without Restart

A reload rereads configuration files and applies settings that do not require startup-time allocation.

### SQL reload

```sql
SELECT pg_reload_conf();
```

### pg_ctl reload

```bash
pg_ctl reload -D "$PGDATA"
```

### systemd reload

```bash
sudo systemctl reload postgresql
```

Depending on packaging, the unit name may include the version or cluster:

```bash
sudo systemctl reload postgresql@16-main
```

### Debian / Ubuntu cluster reload

```bash
sudo pg_ctlcluster 16 main reload
```

### What reload usually rereads

- `postgresql.conf`
- `postgresql.auto.conf`
- `pg_hba.conf`
- `pg_ident.conf`
- included config files

### Check whether reload applied

```sql
SELECT
    name,
    setting,
    source,
    sourcefile,
    sourceline,
    pending_restart
FROM pg_settings
WHERE pending_restart = true
ORDER BY name;
```

### Check invalid config file entries

```sql
SELECT
    name,
    setting,
    applied,
    error,
    sourcefile,
    sourceline
FROM pg_file_settings
WHERE applied IS NOT TRUE OR error IS NOT NULL
ORDER BY sourcefile, sourceline;
```

---

## 11. Restart PostgreSQL

A restart disconnects clients and starts PostgreSQL again. Use restart for settings with `context = 'postmaster'`, binary upgrades, some extension preload changes, or stuck server-level conditions.

### systemd restart

```bash
sudo systemctl restart postgresql
```

Versioned unit examples:

```bash
sudo systemctl restart postgresql@16-main
```

```bash
sudo systemctl restart postgresql-16
```

### pg_ctl restart

```bash
pg_ctl restart -D "$PGDATA" -m fast
```

Common options:

```bash
pg_ctl restart -D "$PGDATA" -m smart
pg_ctl restart -D "$PGDATA" -m fast
pg_ctl restart -D "$PGDATA" -m immediate
```

### Debian / Ubuntu pg_ctlcluster

```bash
sudo pg_ctlcluster 16 main restart
```

### Red Hat / Rocky / Alma style examples

```bash
sudo systemctl restart postgresql-16
```

or:

```bash
sudo systemctl restart postgresql
```

### macOS Homebrew example

```bash
brew services restart postgresql@16
```

### Docker example

```bash
docker restart postgres_container
```

### Kubernetes example

For a StatefulSet-managed PostgreSQL deployment:

```bash
kubectl rollout restart statefulset/postgres
```

For a single pod, deletion may let the controller recreate it:

```bash
kubectl delete pod postgres-0
```

Use the operator-native method if PostgreSQL is managed by a Kubernetes operator.

---

## 12. Stop and Start PostgreSQL

### Stop with systemd

```bash
sudo systemctl stop postgresql
```

### Start with systemd

```bash
sudo systemctl start postgresql
```

### Stop with pg_ctl

```bash
pg_ctl stop -D "$PGDATA" -m fast
```

### Start with pg_ctl

```bash
pg_ctl start -D "$PGDATA" -l "$PGDATA/server.log"
```

### Check status with pg_ctl

```bash
pg_ctl status -D "$PGDATA"
```

### Check process from OS

```bash
ps -ef | grep '[p]ostgres'
```

### Confirm readiness

```bash
pg_isready -h localhost -p 5432
```

---

## 13. Shutdown Modes

PostgreSQL supports different stop modes. Choose carefully.

| Mode | Command example | Behavior | When to use |
|---|---|---|---|
| Smart | `pg_ctl stop -D "$PGDATA" -m smart` | Waits for clients to disconnect. No new connections. | Planned maintenance with time to drain. |
| Fast | `pg_ctl stop -D "$PGDATA" -m fast` | Disconnects clients and rolls back active transactions. | Normal operational restart. |
| Immediate | `pg_ctl stop -D "$PGDATA" -m immediate` | Abrupt shutdown. Crash recovery required on next start. | Last resort only. |

Recommended default for operational restart:

```bash
pg_ctl restart -D "$PGDATA" -m fast
```

Avoid immediate mode unless the server will not stop and you accept crash recovery on startup.

---

## 14. Validate the Database After Reload or Restart

### Check server accepts connections

```bash
pg_isready -h localhost -p 5432
```

### Check SQL access

```bash
psql -h localhost -p 5432 -U postgres -d postgres -c "SELECT now(), version();"
```

### Check pending restart flags

```sql
SELECT
    name,
    setting,
    context,
    pending_restart
FROM pg_settings
WHERE pending_restart = true
ORDER BY name;
```

### Check background activity

```sql
SELECT
    backend_type,
    state,
    count(*)
FROM pg_stat_activity
GROUP BY backend_type, state
ORDER BY backend_type, state;
```

### Check replication on primary

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

### Check replication receiver on standby

```sql
SELECT
    status,
    sender_host,
    sender_port,
    slot_name,
    latest_end_lsn,
    latest_end_time
FROM pg_stat_wal_receiver;
```

### Check recent logs

Systemd:

```bash
journalctl -u postgresql --since "15 minutes ago" --no-pager
```

Versioned example:

```bash
journalctl -u postgresql@16-main --since "15 minutes ago" --no-pager
```

File logs:

```bash
tail -n 200 "$PGDATA/log/postgresql.log"
```

---

## 15. Managed PostgreSQL: RDS, Aurora, Cloud SQL, Azure

Managed PostgreSQL platforms often restrict OS-level tools. Use provider controls instead.

### Common differences

| Task | Self-managed PostgreSQL | Managed PostgreSQL |
|---|---|---|
| Reload config | `pg_ctl reload`, `SELECT pg_reload_conf()` | Usually parameter group reload or SQL reload for dynamic parameters |
| Restart server | `systemctl restart`, `pg_ctl restart` | Provider reboot/restart action |
| Edit `postgresql.conf` | Direct file edit | Parameter group / database flags |
| Kill session | `pg_terminate_backend(pid)` | Usually supported with role/provider permissions |
| OS process kill | `kill`, `systemctl` | Usually unavailable |
| Logs | Local files / journald | Provider log service |

### AWS RDS / Aurora notes

- Static parameter changes usually need a reboot.
- Dynamic parameter changes may apply without reboot.
- Use provider console, CLI, or API for reboot/failover.
- Some superuser-level actions are restricted to managed roles.

### Cloud SQL / Azure notes

- Use database flags or server parameters.
- Restart through provider tools.
- Some parameters are fixed or restricted.

---

## 16. PostgreSQL DBA Tools

PostgreSQL ships many command-line utilities. Some are client tools and can run from any machine with network access. Others are server-side tools and usually run on the database host.

### Daily client tools

| Tool | Purpose | Example |
|---|---|---|
| `psql` | Interactive SQL shell and scripting client | `psql -h host -U user -d db` |
| `pg_isready` | Check whether server accepts connections | `pg_isready -h host -p 5432` |
| `pg_dump` | Logical backup of one database | `pg_dump -Fc -f db.dump dbname` |
| `pg_restore` | Restore archive created by `pg_dump` | `pg_restore -d dbname db.dump` |
| `pg_dumpall` | Dump all DBs and global objects | `pg_dumpall > cluster.sql` |
| `createdb` | Create a database | `createdb appdb` |
| `dropdb` | Drop a database | `dropdb olddb` |
| `createuser` | Create a role | `createuser appuser` |
| `dropuser` | Drop a role | `dropuser olduser` |
| `reindexdb` | Rebuild indexes from CLI | `reindexdb -d dbname` |
| `vacuumdb` | Run VACUUM / ANALYZE from CLI | `vacuumdb --analyze-in-stages dbname` |
| `clusterdb` | Cluster tables from CLI | `clusterdb -d dbname` |

### Server control tools

| Tool | Purpose | Example |
|---|---|---|
| `pg_ctl` | Start, stop, restart, reload, status | `pg_ctl restart -D "$PGDATA" -m fast` |
| `initdb` | Initialize a new database cluster | `initdb -D "$PGDATA"` |
| `postgres` | Server executable | `postgres -D "$PGDATA"` |
| `pg_controldata` | Show control file metadata | `pg_controldata "$PGDATA"` |
| `pg_resetwal` | Reset WAL after severe corruption | Last resort only |
| `pg_checksums` | Enable, disable, or verify data checksums | `pg_checksums --check -D "$PGDATA"` |
| `pg_upgrade` | Upgrade major PostgreSQL version | `pg_upgrade ...` |
| `pg_config` | Show build/install info | `pg_config --version` |

### Backup and replication tools

| Tool | Purpose | Example |
|---|---|---|
| `pg_basebackup` | Physical base backup / replica bootstrap | `pg_basebackup -h primary -D standby -R -X stream` |
| `pg_receivewal` | Stream WAL from server | `pg_receivewal -D wal_archive -h primary` |
| `pg_recvlogical` | Logical decoding stream client | `pg_recvlogical ...` |
| `pg_waldump` | Inspect WAL files | `pg_waldump path/to/walfile` |
| `pg_archivecleanup` | Clean old WAL archive files | Used by standby/archive scripts |

### Diagnostic and performance tools

| Tool | Purpose | Example |
|---|---|---|
| `pgbench` | Benchmark and load-test PostgreSQL | `pgbench -i -s 10 testdb` |
| `pg_test_fsync` | Test fsync behavior/performance | `pg_test_fsync` |
| `pg_test_timing` | Test system timer overhead | `pg_test_timing` |
| `pg_amcheck` | Check relation corruption using amcheck | `pg_amcheck -d dbname` |

### Extension-based tools commonly used

| Tool / extension | Purpose |
|---|---|
| `pg_stat_statements` | Query fingerprint statistics. |
| `auto_explain` | Log execution plans for slow queries. |
| `pg_buffercache` | Inspect shared buffer cache contents. |
| `pg_prewarm` | Preload relation data into cache. |
| `amcheck` | Verify index/table consistency. |
| `pgstattuple` | Inspect table/index bloat. |
| `pageinspect` | Low-level page inspection. |

---

## 17. Useful SQL Views and Functions

### Views

| View | Use |
|---|---|
| `pg_stat_activity` | Current sessions, queries, waits, client info. |
| `pg_locks` | Locks held and waited on. |
| `pg_stat_database` | Database-level counters. |
| `pg_stat_user_tables` | Table activity, vacuum/analyze stats. |
| `pg_stat_user_indexes` | Index usage. |
| `pg_stat_replication` | Primary-side replication status. |
| `pg_stat_wal_receiver` | Standby-side WAL receiver status. |
| `pg_replication_slots` | Slot status and WAL retention risk. |
| `pg_settings` | Current settings and lifecycle context. |
| `pg_file_settings` | Parsed config file settings and errors. |
| `pg_stat_progress_vacuum` | Active vacuum progress. |
| `pg_stat_progress_create_index` | Active index build progress. |
| `pg_stat_progress_basebackup` | Base backup progress. |
| `pg_stat_progress_copy` | COPY progress. |

### Functions

| Function | Use |
|---|---|
| `pg_cancel_backend(pid)` | Cancel active query in a backend. |
| `pg_terminate_backend(pid)` | Terminate a backend/session. |
| `pg_reload_conf()` | Reload server configuration. |
| `pg_rotate_logfile()` | Rotate log file when logging collector is enabled. |
| `pg_backend_pid()` | Return current session PID. |
| `pg_blocking_pids(pid)` | Return sessions blocking a PID. |
| `pg_is_in_recovery()` | Check whether server is standby/in recovery. |
| `pg_current_wal_lsn()` | Current WAL LSN on primary. |
| `pg_last_wal_receive_lsn()` | Last received WAL LSN on standby. |
| `pg_last_wal_replay_lsn()` | Last replayed WAL LSN on standby. |

---

## 18. Common Incident Patterns

### A. Too many connections

Inspect:

```sql
SELECT
    datname,
    usename,
    application_name,
    client_addr,
    state,
    count(*)
FROM pg_stat_activity
GROUP BY datname, usename, application_name, client_addr, state
ORDER BY count(*) DESC;
```

Actions:

1. Fix or pause the application pool.
2. Terminate excess idle sessions.
3. Consider PgBouncer or better pool sizing.
4. Do not blindly raise `max_connections`; it can worsen memory and scheduling pressure.

Terminate idle app sessions:

```sql
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE usename = 'app_user'
  AND state = 'idle'
  AND pid <> pg_backend_pid();
```

### B. Migration blocked by old transaction

Find idle transactions:

```sql
SELECT
    pid,
    usename,
    application_name,
    now() - xact_start AS xact_age,
    left(query, 160) AS query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
ORDER BY xact_age DESC;
```

Terminate the confirmed blocker:

```sql
SELECT pg_terminate_backend(<pid>);
```

### C. Slow query storm

Cancel long active queries first:

```sql
SELECT pg_cancel_backend(pid)
FROM pg_stat_activity
WHERE state = 'active'
  AND now() - query_start > interval '5 minutes'
  AND pid <> pg_backend_pid();
```

Then investigate with:

```sql
SELECT *
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY query_start;
```

If `pg_stat_statements` is enabled:

```sql
SELECT
    calls,
    total_exec_time,
    mean_exec_time,
    rows,
    left(query, 200) AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

### D. Config changed but nothing happened

Check pending restart:

```sql
SELECT
    name,
    setting,
    context,
    pending_restart
FROM pg_settings
WHERE pending_restart = true;
```

Check bad config file entries:

```sql
SELECT
    name,
    setting,
    applied,
    error,
    sourcefile,
    sourceline
FROM pg_file_settings
WHERE applied IS NOT TRUE OR error IS NOT NULL;
```

Reload:

```sql
SELECT pg_reload_conf();
```

Restart only if required.

### E. PostgreSQL will not stop cleanly

Try fast stop:

```bash
pg_ctl stop -D "$PGDATA" -m fast
```

If it hangs, inspect OS processes and logs. Use immediate mode only as a last resort:

```bash
pg_ctl stop -D "$PGDATA" -m immediate
```

Expect crash recovery during next startup.

---

## 19. Copy/Paste Command Reference

### Current sessions

```sql
SELECT
    pid,
    usename,
    datname,
    application_name,
    client_addr,
    state,
    wait_event_type,
    wait_event,
    now() - query_start AS query_age,
    left(query, 160) AS query
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
ORDER BY query_start NULLS LAST;
```

### Cancel one backend query

```sql
SELECT pg_cancel_backend(<pid>);
```

### Terminate one backend session

```sql
SELECT pg_terminate_backend(<pid>);
```

### Terminate all sessions for one database

```sql
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '<database_name>'
  AND pid <> pg_backend_pid();
```

### Terminate idle app sessions

```sql
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE usename = '<app_user>'
  AND state = 'idle'
  AND pid <> pg_backend_pid();
```

### Reload config

```sql
SELECT pg_reload_conf();
```

```bash
pg_ctl reload -D "$PGDATA"
```

```bash
sudo systemctl reload postgresql
```

### Restart

```bash
sudo systemctl restart postgresql
```

```bash
pg_ctl restart -D "$PGDATA" -m fast
```

### Stop

```bash
pg_ctl stop -D "$PGDATA" -m fast
```

### Start

```bash
pg_ctl start -D "$PGDATA" -l "$PGDATA/server.log"
```

### Readiness

```bash
pg_isready -h localhost -p 5432
```

### Validate SQL

```bash
psql -h localhost -p 5432 -U postgres -d postgres -c "SELECT now(), version();"
```

---

## 20. Source References

These are the PostgreSQL documentation pages used for this runbook:

- PostgreSQL system administration functions: `pg_cancel_backend`, `pg_terminate_backend`, and `pg_reload_conf`  
  https://www.postgresql.org/docs/current/functions-admin.html

- PostgreSQL `pg_stat_activity` and monitoring statistics  
  https://www.postgresql.org/docs/current/monitoring-stats.html

- PostgreSQL `pg_ctl`  
  https://www.postgresql.org/docs/current/app-pg-ctl.html

- PostgreSQL server shutdown modes  
  https://www.postgresql.org/docs/current/server-shutdown.html

- PostgreSQL configuration reload behavior  
  https://www.postgresql.org/docs/current/config-setting.html

- PostgreSQL `ALTER SYSTEM` reload behavior  
  https://www.postgresql.org/docs/current/sql-altersystem.html

- PostgreSQL client applications and utilities  
  https://www.postgresql.org/docs/current/reference-client.html

- PostgreSQL command reference  
  https://www.postgresql.org/docs/current/reference.html

- PostgreSQL `pg_isready`  
  https://www.postgresql.org/docs/current/app-pg-isready.html

---
How to validate includes

After editing files, check the parsed config:
```sql
SELECT
    sourcefile,
    sourceline,
    name,
    setting,
    applied,
    error
FROM pg_file_settings
ORDER BY sourcefile, sourceline;

-- Show only problems:

SELECT
    sourcefile,
    sourceline,
    name,
    setting,
    error
FROM pg_file_settings
WHERE applied IS NOT TRUE OR error IS NOT NULL
ORDER BY sourcefile, sourceline;

-- reload
SELECT pg_reload_conf();

-- check settings that still need restart:

SELECT
    name,
    setting,
    context,
    pending_restart
FROM pg_settings
WHERE pending_restart = true
ORDER BY name;
```

**Safe deployment flow**

Use this sequence:
```bash
sudo mkdir -p "$PGDATA/conf.d"
sudo chown postgres:postgres "$PGDATA/conf.d"
sudo chmod 0750 "$PGDATA/conf.d"
```

**Create the section files:**
```bash
sudo touch "$PGDATA/conf.d/00-base.conf"
sudo touch "$PGDATA/conf.d/10-connections.conf"
sudo touch "$PGDATA/conf.d/20-memory.conf"
sudo touch "$PGDATA/conf.d/30-wal.conf"
sudo touch "$PGDATA/conf.d/40-replication.conf"
sudo touch "$PGDATA/conf.d/50-autovacuum.conf"
sudo touch "$PGDATA/conf.d/60-logging.conf"
sudo touch "$PGDATA/conf.d/90-local-overrides.conf"

sudo chown postgres:postgres "$PGDATA"/conf.d/*.conf
sudo chmod 0640 "$PGDATA"/conf.d/*.conf

# Test reload:
pg_ctl reload -D "$PGDATA"
  OR
SELECT pg_reload_conf();

# Then verify:
SELECT
    sourcefile,
    sourceline,
    name,
    setting,
    applied,
    error
FROM pg_file_settings
WHERE sourcefile LIKE '%conf.d%'
ORDER BY sourcefile, sourceline;
```

- Do not define the same setting in multiple files unless you are intentionally overriding it.
- That makes ownership unclear. Keep each setting in one logical section, and reserve 90-local-overrides.conf for explicit exceptions.

---
