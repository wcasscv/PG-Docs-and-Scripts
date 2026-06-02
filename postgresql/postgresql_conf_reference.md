# PostgreSQL Configuration Reference — Sectioned `postgresql.conf`

## Table of Contents

- [1. Change Lifecycle Legend](#1-change-lifecycle-legend)
- [2. Verification Queries](#2-verification-queries)
- [3. Connections and Network](#3-connections-and-network)
- [4. Memory](#4-memory)
- [5. Query Planner and Tuning](#5-query-planner-and-tuning)
- [6. Disk and I/O](#6-disk-and-io)
- [7. WAL and Checkpoints](#7-wal-and-checkpoints)
- [8. Replication](#8-replication)
- [9. Autovacuum](#9-autovacuum)
- [10. Logging and Observability](#10-logging-and-observability)
- [11. Timeouts and Safety Limits](#11-timeouts-and-safety-limits)
- [12. Background Workers and Extensions](#12-background-workers-and-extensions)
- [13. Locale, Client Defaults, and Compatibility](#13-locale-client-defaults-and-compatibility)
- [14. Lock Management](#14-lock-management)
- [15. Include Files](#15-include-files)
- [16. Restart-Required Settings Summary](#16-restart-required-settings-summary)
- [17. Reload / Reconnect Settings Summary](#17-reload--reconnect-settings-summary)
- [18. Operational Notes](#18-operational-notes)

---

## 1. Change Lifecycle Legend

| Label | PostgreSQL context | What it means |
|---|---|---|
| **Restart** | `postmaster` | Requires PostgreSQL restart. Reload is not enough. |
| **Reload** | `sighup` | Edit `postgresql.conf`, then reload with `SELECT pg_reload_conf();`, `pg_ctl reload`, or service reload. |
| **Reload + reconnect** | `backend` / `superuser-backend` | Reload is enough for the server to read the change, but only new sessions get the new value. Existing sessions keep the old value. |
| **Session / reload** | `user` / `superuser` | Can usually be changed with `SET` for a session. If set in `postgresql.conf`, reload applies where no session-local override exists. |
| **Internal** | `internal` | Not directly configurable. |

---

## 2. Verification Queries

Use these on the real server to confirm the active value, source file, lifecycle, and whether a restart is pending.

```sql
SELECT
    name,
    setting,
    unit,
    context,
    source,
    sourcefile,
    sourceline,
    pending_restart,
    short_desc
FROM pg_settings
WHERE name IN (
    'listen_addresses',
    'port',
    'max_connections',
    'shared_buffers',
    'work_mem',
    'maintenance_work_mem',
    'effective_cache_size',
    'wal_level',
    'max_wal_senders',
    'max_replication_slots',
    'max_wal_size',
    'checkpoint_timeout',
    'checkpoint_completion_target',
    'autovacuum',
    'autovacuum_max_workers',
    'log_min_duration_statement',
    'shared_preload_libraries'
)
ORDER BY context, name;
```

Check for settings changed in config files but not yet applied:

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

Reload safely:

```sql
SELECT pg_reload_conf();
```

Find settings waiting on a restart:

```sql
SELECT
    name,
    setting,
    unit,
    context,
    source,
    pending_restart
FROM pg_settings
WHERE pending_restart = true
ORDER BY name;
```

---

## 3. Connections and Network

Connection settings define how clients reach the server and how many backends PostgreSQL can run.

```conf
#------------------------------------------------------------------------------
# CONNECTIONS AND NETWORK
#------------------------------------------------------------------------------

# Listen interfaces.
# Lifecycle: Restart
# Risk: exposing "*" without strict pg_hba.conf and firewall rules can create security risk.
listen_addresses = 'localhost'

# TCP port.
# Lifecycle: Restart
port = 5432

# Maximum concurrent database connections.
# Lifecycle: Restart
# Tuning note: high values increase memory and scheduler pressure.
max_connections = 100

# Emergency connection slots for superusers.
# Lifecycle: Restart
superuser_reserved_connections = 3

# Reserved slots for roles with pg_use_reserved_connections.
# Lifecycle: Restart
# Available in newer PostgreSQL versions.
reserved_connections = 0

# Unix socket directory.
# Lifecycle: Restart
unix_socket_directories = '/var/run/postgresql'

# Unix socket permissions.
# Lifecycle: Restart
unix_socket_permissions = 0777

# TCP keepalive idle time.
# Lifecycle: Session / reload
tcp_keepalives_idle = 0

# TCP keepalive interval.
# Lifecycle: Session / reload
tcp_keepalives_interval = 0

# TCP keepalive count.
# Lifecycle: Session / reload
tcp_keepalives_count = 0
```

---

## 4. Memory

Memory settings have the biggest blast radius. Tune them with connection count, workload shape, and OS memory together.

```conf
#------------------------------------------------------------------------------
# MEMORY
#------------------------------------------------------------------------------

# Main shared buffer cache.
# Lifecycle: Restart
shared_buffers = 128MB

# Per-operation memory for sorts, hashes, aggregations, and joins.
# Lifecycle: Session / reload
# Risk: can be used multiple times per query and per connection.
work_mem = 4MB

# Memory for VACUUM, CREATE INDEX, ALTER TABLE ADD FOREIGN KEY, etc.
# Lifecycle: Session / reload
maintenance_work_mem = 64MB

# Memory available for each autovacuum worker.
# Lifecycle: Reload
autovacuum_work_mem = -1

# Planner estimate of OS + PostgreSQL cache available.
# Lifecycle: Session / reload
effective_cache_size = 4GB

# Use huge pages where supported.
# Lifecycle: Restart
huge_pages = try

# Minimum dynamic shared memory.
# Lifecycle: Restart
min_dynamic_shared_memory = 0
```

Memory sanity check:

```sql
SELECT
    name,
    setting,
    unit,
    context,
    pending_restart
FROM pg_settings
WHERE name IN (
    'shared_buffers',
    'work_mem',
    'maintenance_work_mem',
    'autovacuum_work_mem',
    'effective_cache_size',
    'huge_pages'
)
ORDER BY name;
```

---

## 5. Query Planner and Tuning

These settings influence plans. Prefer fixing statistics, indexes, and SQL first.

```conf
#------------------------------------------------------------------------------
# QUERY PLANNER AND TUNING
#------------------------------------------------------------------------------

# Planner estimate for random page cost.
# Lifecycle: Session / reload
random_page_cost = 4.0

# Planner estimate for sequential page cost.
# Lifecycle: Session / reload
seq_page_cost = 1.0

# Planner estimate for CPU cost per tuple.
# Lifecycle: Session / reload
cpu_tuple_cost = 0.01

# Planner estimate for CPU cost per index tuple.
# Lifecycle: Session / reload
cpu_index_tuple_cost = 0.005

# Planner estimate for CPU cost per operator/function.
# Lifecycle: Session / reload
cpu_operator_cost = 0.0025

# Planner estimate for effective disk concurrency.
# Lifecycle: Session / reload
effective_io_concurrency = 1

# Minimum table size before parallel scan is considered.
# Lifecycle: Session / reload
min_parallel_table_scan_size = 8MB

# Minimum index size before parallel index scan is considered.
# Lifecycle: Session / reload
min_parallel_index_scan_size = 512kB

# Default statistics target for ANALYZE.
# Lifecycle: Session / reload
default_statistics_target = 100
```

---

## 6. Disk and I/O

Use these to reduce temporary spill pain and improve storage behavior.

```conf
#------------------------------------------------------------------------------
# DISK AND I/O
#------------------------------------------------------------------------------

# Temporary file limit per process.
# Lifecycle: Session / reload
# -1 means no limit.
temp_file_limit = -1

# Maximum files each server process may keep open.
# Lifecycle: Restart
max_files_per_process = 1000

# Flush dirty data to disk with fsync.
# Lifecycle: Reload
# Risk: turning this off can corrupt data after crash/power loss.
fsync = on

# Method used to flush WAL data.
# Lifecycle: Reload
wal_sync_method = fsync

# Pre-warm relation data if pg_prewarm is used.
# Lifecycle: Reload
autoprewarm = on
```

---

## 7. WAL and Checkpoints

WAL settings control durability, crash recovery, replication, and write amplification.

```conf
#------------------------------------------------------------------------------
# WAL AND CHECKPOINTS
#------------------------------------------------------------------------------

# WAL level: minimal, replica, or logical.
# Lifecycle: Restart
wal_level = replica

# WAL buffers.
# Lifecycle: Restart
wal_buffers = -1

# Compress full-page images in WAL.
# Lifecycle: Reload
wal_compression = off

# Full-page writes after checkpoints.
# Lifecycle: Reload
full_page_writes = on

# Commit durability.
# Lifecycle: Session / reload
synchronous_commit = on

# Maximum WAL size before checkpoint pressure increases.
# Lifecycle: Reload
max_wal_size = 1GB

# Minimum WAL retained for recycling.
# Lifecycle: Reload
min_wal_size = 80MB

# Time between automatic checkpoints.
# Lifecycle: Reload
checkpoint_timeout = 5min

# Spread checkpoint I/O over checkpoint interval.
# Lifecycle: Reload
checkpoint_completion_target = 0.9

# Log checkpoints.
# Lifecycle: Reload
log_checkpoints = on

# WAL writer delay.
# Lifecycle: Reload
wal_writer_delay = 200ms

# Archive mode.
# Lifecycle: Restart for archive_mode changes in many deployments.
archive_mode = off

# Archive command.
# Lifecycle: Reload
archive_command = ''
```

---

## 8. Replication

Replication settings affect read replicas, logical replication, failover, and WAL retention.

```conf
#------------------------------------------------------------------------------
# REPLICATION
#------------------------------------------------------------------------------

# WAL level must be replica or logical for replication.
# Lifecycle: Restart
wal_level = replica

# Maximum WAL sender processes.
# Lifecycle: Restart
max_wal_senders = 10

# Maximum replication slots.
# Lifecycle: Restart
max_replication_slots = 10

# WAL kept for standby servers.
# Lifecycle: Reload
wal_keep_size = 0

# Cap WAL retained by replication slots.
# Lifecycle: Reload
max_slot_wal_keep_size = -1

# Synchronous standby configuration.
# Lifecycle: Reload
synchronous_standby_names = ''

# Enable hot standby queries on a replica.
# Lifecycle: Restart
hot_standby = on

# Let standby report query xmin to primary.
# Lifecycle: Reload
# Risk: can increase bloat on primary if standby queries are long-running.
hot_standby_feedback = off

# Standby connection info.
# Lifecycle: Reload + reconnect / standby-sensitive
primary_conninfo = ''

# Standby slot name.
# Lifecycle: Reload + reconnect / standby-sensitive
primary_slot_name = ''
```

Replication health checks:

```sql
-- On primary
SELECT
    application_name,
    client_addr,
    state,
    sync_state,
    write_lag,
    flush_lag,
    replay_lag
FROM pg_stat_replication;

-- Replication slots and retained WAL risk
SELECT
    slot_name,
    slot_type,
    active,
    restart_lsn,
    wal_status,
    safe_wal_size
FROM pg_replication_slots
ORDER BY slot_name;
```

---

## 9. Autovacuum

Autovacuum protects against bloat and transaction ID wraparound. Do not disable it casually.

```conf
#------------------------------------------------------------------------------
# AUTOVACUUM
#------------------------------------------------------------------------------

# Master autovacuum switch.
# Lifecycle: Reload
autovacuum = on

# Number of autovacuum workers.
# Lifecycle: Restart
autovacuum_max_workers = 3

# Delay between autovacuum runs.
# Lifecycle: Reload
autovacuum_naptime = 1min

# Vacuum threshold before autovacuum.
# Lifecycle: Reload
autovacuum_vacuum_threshold = 50

# Analyze threshold before autoanalyze.
# Lifecycle: Reload
autovacuum_analyze_threshold = 50

# Vacuum scale factor.
# Lifecycle: Reload
autovacuum_vacuum_scale_factor = 0.2

# Analyze scale factor.
# Lifecycle: Reload
autovacuum_analyze_scale_factor = 0.1

# Cost delay for autovacuum.
# Lifecycle: Reload
autovacuum_vacuum_cost_delay = 2ms

# Cost limit for autovacuum.
# Lifecycle: Reload
autovacuum_vacuum_cost_limit = -1

# Aggressive vacuum age guardrail.
# Lifecycle: Reload
autovacuum_freeze_max_age = 200000000

# Multixact age guardrail.
# Lifecycle: Reload
autovacuum_multixact_freeze_max_age = 400000000
```

Autovacuum triage:

```sql
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
```

---

## 10. Logging and Observability

Logging should make incidents explainable without drowning the system in noise.

```conf
#------------------------------------------------------------------------------
# LOGGING AND OBSERVABILITY
#------------------------------------------------------------------------------

# Enable logging collector.
# Lifecycle: Restart
logging_collector = on

# Log directory.
# Lifecycle: Reload
log_directory = 'log'

# Log filename pattern.
# Lifecycle: Reload
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'

# Log rotation age.
# Lifecycle: Reload
log_rotation_age = 1d

# Log rotation size.
# Lifecycle: Reload
log_rotation_size = 10MB

# Minimum duration for slow query logging.
# Lifecycle: Reload
log_min_duration_statement = -1

# Log lock waits.
# Lifecycle: Reload
log_lock_waits = off

# Deadlock timeout; also affects lock wait logging.
# Lifecycle: Session / reload
deadlock_timeout = 1s

# Log checkpoints.
# Lifecycle: Reload
log_checkpoints = on

# Log connections.
# Lifecycle: Reload
log_connections = off

# Log disconnections.
# Lifecycle: Reload
log_disconnections = off

# Log temp files above this size.
# Lifecycle: Reload
log_temp_files = -1

# Prefix fields for logs.
# Lifecycle: Reload
log_line_prefix = '%m [%p] %q%u@%d '

# Track I/O timing.
# Lifecycle: Reload
track_io_timing = off

# Track function timing.
# Lifecycle: Session / reload
track_functions = none

# Track commit timestamp.
# Lifecycle: Restart
track_commit_timestamp = off
```

---

## 11. Timeouts and Safety Limits

Timeouts protect the database from stuck sessions, runaway queries, and unsafe migrations.

```conf
#------------------------------------------------------------------------------
# TIMEOUTS AND SAFETY LIMITS
#------------------------------------------------------------------------------

# Terminate statements running longer than this.
# Lifecycle: Session / reload
statement_timeout = 0

# Timeout for lock acquisition.
# Lifecycle: Session / reload
lock_timeout = 0

# Timeout for idle sessions inside an open transaction.
# Lifecycle: Session / reload
idle_in_transaction_session_timeout = 0

# Timeout for idle sessions.
# Lifecycle: Session / reload
idle_session_timeout = 0

# Timeout for authentication.
# Lifecycle: Reload
authentication_timeout = 1min

# Timeout for deadlock detection.
# Lifecycle: Session / reload
deadlock_timeout = 1s

# Maximum prepared transactions.
# Lifecycle: Restart
# Keep 0 unless two-phase commit is required.
max_prepared_transactions = 0
```

---

## 12. Background Workers and Extensions

Settings here affect preload behavior, parallelism, and extension hooks.

```conf
#------------------------------------------------------------------------------
# BACKGROUND WORKERS AND EXTENSIONS
#------------------------------------------------------------------------------

# Libraries loaded at server start.
# Lifecycle: Restart
# Examples: 'pg_stat_statements', 'auto_explain'
shared_preload_libraries = ''

# Maximum background worker processes.
# Lifecycle: Restart
max_worker_processes = 8

# Maximum parallel workers.
# Lifecycle: Session / reload
max_parallel_workers = 8

# Maximum parallel workers per gather.
# Lifecycle: Session / reload
max_parallel_workers_per_gather = 2

# Maximum parallel maintenance workers.
# Lifecycle: Session / reload
max_parallel_maintenance_workers = 2

# Maximum logical replication workers.
# Lifecycle: Restart / version-sensitive
max_logical_replication_workers = 4

# Maximum sync workers per subscription.
# Lifecycle: Reload / version-sensitive
max_sync_workers_per_subscription = 2
```

---

## 13. Locale, Client Defaults, and Compatibility

These defaults mostly affect client behavior and query semantics.

```conf
#------------------------------------------------------------------------------
# LOCALE, CLIENT DEFAULTS, AND COMPATIBILITY
#------------------------------------------------------------------------------

# Client encoding.
# Lifecycle: Session / reload
client_encoding = 'UTF8'

# Date style.
# Lifecycle: Session / reload
datestyle = 'iso, mdy'

# Time zone.
# Lifecycle: Session / reload
timezone = 'UTC'

# Default transaction isolation.
# Lifecycle: Session / reload
default_transaction_isolation = 'read committed'

# Default transaction read-only mode.
# Lifecycle: Session / reload
default_transaction_read_only = off

# Default tablespace.
# Lifecycle: Session / reload
default_tablespace = ''

# Default temp tablespace.
# Lifecycle: Session / reload
temp_tablespaces = ''
```

---

## 14. Lock Management

Lock table sizing and predicate locks can require restart because memory structures are sized at startup.

```conf
#------------------------------------------------------------------------------
# LOCK MANAGEMENT
#------------------------------------------------------------------------------

# Average number of object locks per transaction.
# Lifecycle: Restart
max_locks_per_transaction = 64

# Predicate locks per transaction.
# Lifecycle: Restart
max_pred_locks_per_transaction = 64

# Predicate locks per relation.
# Lifecycle: Restart
max_pred_locks_per_relation = -2

# Predicate locks per page.
# Lifecycle: Restart
max_pred_locks_per_page = 2
```

---

## 15. Include Files

Use include files to keep environment-specific or role-specific settings manageable.

```conf
#------------------------------------------------------------------------------
# INCLUDE FILES
#------------------------------------------------------------------------------

# Include one file.
include = 'conf.d/common.conf'

# Include if file exists.
include_if_exists = 'conf.d/local.conf'

# Include all .conf files in a directory.
include_dir = 'conf.d'
```

Suggested layout:

```text
postgresql.conf
conf.d/
  00-base.conf
  10-connections.conf
  20-memory.conf
  30-wal.conf
  40-replication.conf
  50-autovacuum.conf
  60-logging.conf
  90-local-overrides.conf
```

---

## 16. Restart-Required Settings Summary

Common settings that usually require restart:

| Setting | Area |
|---|---|
| `listen_addresses` | Connections |
| `port` | Connections |
| `max_connections` | Connections |
| `superuser_reserved_connections` | Connections |
| `reserved_connections` | Connections |
| `unix_socket_directories` | Connections |
| `shared_buffers` | Memory |
| `huge_pages` | Memory |
| `min_dynamic_shared_memory` | Memory |
| `wal_level` | WAL / replication |
| `wal_buffers` | WAL |
| `archive_mode` | WAL / archiving |
| `max_wal_senders` | Replication |
| `max_replication_slots` | Replication |
| `hot_standby` | Replication |
| `autovacuum_max_workers` | Autovacuum |
| `logging_collector` | Logging |
| `track_commit_timestamp` | Observability |
| `shared_preload_libraries` | Extensions |
| `max_worker_processes` | Workers |
| `max_prepared_transactions` | Transactions |
| `max_locks_per_transaction` | Locks |

---

## 17. Reload / Reconnect Settings Summary

Common settings that can usually be handled without full restart:

| Setting | Area | Action |
|---|---|---|
| `work_mem` | Memory | Reload or session `SET` |
| `maintenance_work_mem` | Memory | Reload or session `SET` |
| `effective_cache_size` | Planner | Reload or session `SET` |
| `random_page_cost` | Planner | Reload or session `SET` |
| `effective_io_concurrency` | Planner / I/O | Reload or session `SET` |
| `max_wal_size` | WAL | Reload |
| `min_wal_size` | WAL | Reload |
| `checkpoint_timeout` | WAL | Reload |
| `checkpoint_completion_target` | WAL | Reload |
| `wal_compression` | WAL | Reload |
| `full_page_writes` | WAL | Reload |
| `archive_command` | Archiving | Reload |
| `wal_keep_size` | Replication | Reload |
| `max_slot_wal_keep_size` | Replication | Reload |
| `synchronous_standby_names` | Replication | Reload |
| `hot_standby_feedback` | Replication | Reload |
| `autovacuum` | Autovacuum | Reload |
| `autovacuum_naptime` | Autovacuum | Reload |
| `autovacuum_vacuum_scale_factor` | Autovacuum | Reload |
| `log_min_duration_statement` | Logging | Reload |
| `log_lock_waits` | Logging | Reload |
| `log_temp_files` | Logging | Reload |
| `track_io_timing` | Observability | Reload |
| `statement_timeout` | Safety | Reload or session `SET` |
| `lock_timeout` | Safety | Reload or session `SET` |
| `idle_in_transaction_session_timeout` | Safety | Reload or session `SET` |

---

## 18. Operational Notes

1. Treat `max_connections`, `shared_buffers`, `wal_level`, `max_wal_senders`, `max_replication_slots`, and `shared_preload_libraries` as planned-change settings because they commonly need restart.
2. Treat `work_mem` carefully. It is not a global memory pool; it can be consumed many times per query and per backend.
3. Use `pending_restart = true` from `pg_settings` as the truth source after config changes.
4. Use `pg_file_settings` before reload to catch syntax or invalid-value problems.
5. On RDS/Aurora, map these lifecycle labels to parameter group behavior: dynamic parameters can apply without reboot; static parameters require reboot.
6. For production, change one small group at a time, reload/restart intentionally, and validate with workload metrics.
