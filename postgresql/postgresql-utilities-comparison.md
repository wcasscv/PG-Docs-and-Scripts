# EDB PostgreSQL Utilities: What They Are, How to Use Them, and Open-Source Equivalents

## Table of Contents

1. [Executive Introduction](#executive-introduction)
2. [At-a-Glance Comparison](#at-a-glance-comparison)
3. [edb-patroni](#edb-patroni)
4. [edb-barman](#edb-barman)
5. [EDB repmgr](#edb-repmgr)
6. [EDB benchmark-framework](#edb-benchmark-framework)
7. [EDB pgldapsync / EDB LDAP Sync](#edb-pgldapsync--edb-ldap-sync)
8. [Which Tool Should You Use?](#which-tool-should-you-use)
9. [Operational Takeaways](#operational-takeaways)
10. [Sources](#sources)

---

## Executive Introduction

PostgreSQL does not become production-grade just because the database engine is installed. In a real estate, banking, SaaS, public-sector, or regulated environment, the hard problems usually sit around the database: failover, backup, recovery, benchmarking, identity synchronization, and operational repeatability.

The EDB tooling ecosystem exists to close those gaps. Some of these tools are upstream open-source projects that EDB maintains, tests, packages, or supports. Others are EDB-owned public repositories intended to make engineering work more repeatable. The important point is that these tools are not interchangeable. They solve different failure modes.

A practical way to think about them:

- **Patroni** keeps PostgreSQL highly available.
- **Barman** keeps PostgreSQL recoverable.
- **repmgr** manages streaming replication and failover with a lighter operational model than Patroni.
- **benchmark-framework** makes performance tests repeatable.
- **pgldapsync / LDAP Sync** keeps PostgreSQL roles aligned with enterprise identity systems.

The strongest PostgreSQL estates use these as separate layers. HA does not replace backup. Backup does not replace failover. Benchmarking does not replace observability. LDAP authentication does not automatically create or remove PostgreSQL roles. Each tool covers a different control plane.

---

## At-a-Glance Comparison

| Tool | Primary job | Typical production use | Open-source equivalent / upstream | EDB difference |
|---|---|---|---|---|
| `edb-patroni` | PostgreSQL HA orchestration | Automatic failover, leader election, controlled switchover | Patroni | EDB-tested and supported packaging for PostgreSQL, EDB Postgres Advanced Server, and EDB Postgres Extended Server |
| `edb-barman` | Backup and disaster recovery | Base backups, WAL archiving, PITR, retention | Barman | EDB-maintained GPL project, available through EDB repositories, with support alignment |
| EDB `repmgr` | Replication and failover management | Standby cloning, replication monitoring, failover, switchover | repmgr | EDB-maintained GPL project; EDB certification differs by Postgres distribution |
| EDB `benchmark-framework` | Repeatable benchmark automation | pgbench, TPROC-C, TPROC-H benchmark runs using Ansible | Same public EDB GitHub repository | No clear separate commercial fork; EDB-originated engineering framework |
| EDB `pgldapsync` / LDAP Sync | LDAP / AD role synchronization | Create or remove PostgreSQL roles based on directory state | `pgldapsync`, `ldap2pg`, or `pg_ldap_sync` depending on tool choice | EDB LDAP Sync packages scheduling/configuration around LDAP synchronization, especially for EDB Postgres Advanced Server |

---

## edb-patroni

### What it is

`edb-patroni` refers to EDB-packaged or EDB-supported Patroni for PostgreSQL high availability.

Patroni is a Python-based HA framework for PostgreSQL. It manages which node is the primary, promotes replicas during failure, coordinates leader election, and stores cluster state in a distributed configuration store such as etcd, Consul, ZooKeeper, or Kubernetes.

EDB describes Patroni as a popular open-source tool for managing replication and failover of Postgres clusters, relying on Postgres streaming replication and hot standby capabilities. EDB also documents a supported topology using PostgreSQL or EDB Postgres variants, Patroni, etcd, and HAProxy.

### What problem it solves

Patroni answers this production question:

> “When the primary PostgreSQL server fails, which node becomes the new primary, and how do applications find it safely?”

Without a tool like Patroni, teams often end up with brittle shell scripts, manual promotion, unclear split-brain handling, and inconsistent replica recovery.

### How to use it

A typical Patroni architecture uses:

1. **PostgreSQL nodes**
   - One primary.
   - Two or more replicas.
   - Physical streaming replication.

2. **Distributed configuration store**
   - Commonly etcd.
   - Holds leader lock and cluster state.
   - Should itself be highly available.

3. **Patroni agent**
   - Runs on every PostgreSQL node.
   - Starts, stops, promotes, demotes, and reconfigures PostgreSQL.

4. **HAProxy, PgBouncer, DNS, or service discovery**
   - Routes read-write traffic to the current primary.
   - Optionally routes read-only traffic to replicas.

Typical workflow:

```bash
# Install Patroni and required dependencies from the appropriate repository.
# Exact package names vary by OS and EDB repository configuration.

sudo dnf install patroni
# or
sudo apt install patroni
```

Example operational commands:

```bash
patronictl -c /etc/patroni/patroni.yml list
patronictl -c /etc/patroni/patroni.yml switchover
patronictl -c /etc/patroni/patroni.yml failover
patronictl -c /etc/patroni/patroni.yml reinit <cluster_name> <member_name>
```

Core configuration areas:

```yaml
scope: prod-pg-cluster
name: pg-node-1

restapi:
  listen: 0.0.0.0:8008
  connect_address: pg-node-1.example.com:8008

etcd3:
  hosts:
    - etcd-1.example.com:2379
    - etcd-2.example.com:2379
    - etcd-3.example.com:2379

postgresql:
  listen: 0.0.0.0:5432
  connect_address: pg-node-1.example.com:5432
  data_dir: /var/lib/postgresql/data
```

### Open-source version

The open-source project is **Patroni**, hosted by the Patroni project. It is not just an EDB-only product. Patroni describes itself as a template for PostgreSQL HA solutions and supports multiple distributed configuration stores.

### EDB version vs open-source version

| Area | Open-source Patroni | EDB Patroni / EDB-supported Patroni |
|---|---|---|
| Source availability | Open-source Patroni project | Based on open-source Patroni |
| Main function | HA orchestration | Same core function |
| Packaging | Community / distro / PyPI / source | EDB repository packaging may be available depending on platform |
| Support | Community support unless separately contracted | EDB support and tested combinations |
| Certification | Generic PostgreSQL-oriented | EDB documents testing with PostgreSQL, EDB Postgres Advanced Server, and EDB Postgres Extended Server |
| Architecture | Requires DCS and routing layer | EDB documents supported topology with etcd and HAProxy |

### Strong engineer’s view

Use Patroni when automatic failover must be deterministic and auditable. Do not treat it as a magic HA appliance. The hard parts are still yours: quorum design, etcd health, fencing assumptions, connection routing, failover testing, WAL retention, and application retry behavior.

### Takeaway summary

Patroni is the right EDB-aligned HA choice when you want robust failover orchestration and can operate the supporting control plane correctly. Its value comes from disciplined architecture, not from simply installing the package.

---

## edb-barman

### What it is

`edb-barman` refers to EDB-packaged or EDB-maintained Barman.

Barman, short for Backup and Recovery Manager, is an open-source backup and disaster recovery tool for PostgreSQL. It manages remote backups, WAL archiving, retention policies, verification, and point-in-time recovery.

EDB describes Barman as an open-source administration tool for remote backups and disaster recovery of PostgreSQL servers in business-critical environments. It is distributed under GNU GPL 3 and maintained by EDB.

### What problem it solves

Barman answers this production question:

> “Can I restore the database to a known point in time after corruption, accidental deletion, failed deployment, ransomware, or site loss?”

Replication is not backup. If someone drops a table on the primary, streaming replication faithfully copies the mistake to replicas. Barman gives you recoverability.

### How to use it

A typical Barman architecture has:

1. **PostgreSQL primary**
   - Produces WAL.
   - Allows replication connection or archive shipping.

2. **Barman server**
   - Separate host or backup environment.
   - Stores base backups and WAL.
   - Applies retention policy.

3. **WAL transport**
   - Streaming replication slot.
   - `archive_command`.
   - `barman-wal-archive`.
   - Cloud archive tooling where appropriate.

Basic operational commands:

```bash
barman check <server_name>
barman backup <server_name>
barman list-backup <server_name>
barman show-backup <server_name> <backup_id>
barman recover <server_name> <backup_id> /restore/target/path
```

Example PostgreSQL archive configuration pattern:

```conf
archive_mode = on
archive_command = 'barman-wal-archive backup-host.example.com pgprod %p'
```

Example Barman server config pattern:

```ini
[pgprod]
description = "Production PostgreSQL cluster"
conninfo = host=pg-primary.example.com user=barman dbname=postgres
streaming_conninfo = host=pg-primary.example.com user=streaming_barman
backup_method = postgres
streaming_archiver = on
slot_name = barman_pgprod
retention_policy = RECOVERY WINDOW OF 14 DAYS
```

### Open-source version

The open-source project is **Barman**, maintained by EnterpriseDB and distributed under GPL-3. The project is public and has its own documentation site.

### EDB version vs open-source version

| Area | Open-source Barman | EDB Barman / EDB-packaged Barman |
|---|---|---|
| Source availability | Public open-source repository | Same project packaged or distributed through EDB channels |
| License | GPL-3 | GPL-3 for Barman itself |
| Main function | Backup, WAL archive, PITR, restore | Same core function |
| Maintenance | Maintained by EDB | EDB maintenance and support path |
| Installation | Source, distro packages, project downloads | EDB repositories may provide packages |
| Enterprise fit | Depends on team support model | Better fit where EDB support contracts and EDB Postgres distributions are used |

### Strong engineer’s view

Barman should be tested by restore, not by backup success. A backup that has not been restored is an assumption. Schedule restore drills, validate recovery time objective, validate recovery point objective, and monitor WAL gaps aggressively.

### Takeaway summary

Barman is the recoverability layer. Use it even when Patroni or repmgr is already in place. HA keeps the service running; Barman lets you recover when the data itself is damaged.

---

## EDB repmgr

### What it is

EDB `repmgr` refers to Replication Manager for PostgreSQL, an open-source suite of tools for managing streaming replication and failover.

repmgr helps clone standbys, register nodes, monitor replication, perform switchovers, and run failover logic through `repmgrd`. EDB documents repmgr as an open-source tool for managing replication and failover of PostgreSQL clusters, distributed under GNU GPL 3 and maintained by EDB.

### What problem it solves

repmgr answers this production question:

> “How do I build and operate a PostgreSQL streaming replication cluster without hand-rolling every standby, switchover, and failover step?”

It is often simpler than Patroni but usually provides less of a full distributed-control-plane model.

### How to use it

A common repmgr deployment includes:

1. **PostgreSQL primary**
2. **One or more standbys**
3. **repmgr metadata database**
4. **repmgr command-line tool**
5. **optional `repmgrd` daemon for monitoring and failover**

Common commands:

```bash
repmgr primary register
repmgr standby clone --host=primary.example.com --user=repmgr --dbname=repmgr
repmgr standby register
repmgr cluster show
repmgr standby switchover
repmgr node rejoin
```

Example configuration pattern:

```conf
node_id=1
node_name='pg-node-1'
conninfo='host=pg-node-1.example.com user=repmgr dbname=repmgr connect_timeout=2'
data_directory='/var/lib/postgresql/data'
failover='automatic'
promote_command='repmgr standby promote -f /etc/repmgr.conf --log-to-file'
follow_command='repmgr standby follow -f /etc/repmgr.conf --log-to-file --upstream-node-id=%n'
```

### Open-source version

The open-source project is **repmgr**, hosted under EnterpriseDB and documented at repmgr.org. It is GPL-3 licensed.

### EDB version vs open-source version

| Area | Open-source repmgr | EDB-supported repmgr |
|---|---|---|
| Source availability | Public open-source project | Same open-source project with EDB packaging/support |
| License | GPL-3 | GPL-3 for repmgr itself |
| Main function | Streaming replication management and failover | Same core function |
| Certification | General PostgreSQL support depending on version | EDB states repmgr is developed, tested, and certified for PostgreSQL and EDB Postgres Extended Server, but not certified for EDB Postgres Advanced Server |
| Operational model | Lightweight, direct PostgreSQL cluster management | Same, with EDB-supported combinations |

### repmgr vs Patroni

| Question | Patroni | repmgr |
|---|---|---|
| Needs a distributed configuration store? | Yes, normally etcd/Consul/ZooKeeper/Kubernetes | No external DCS in the same way |
| Automatic failover? | Yes | Yes, via `repmgrd` |
| Operational complexity | Higher | Lower |
| Split-brain resistance | Stronger when DCS/quorum is designed correctly | More dependent on careful network and witness design |
| Best fit | Mission-critical HA with strong control plane | Simpler replication clusters, controlled failover, smaller estates |
| App routing | Usually HAProxy/PgBouncer/service discovery | Needs separate routing approach too |

### Strong engineer’s view

repmgr is excellent when the environment needs simple, transparent replication management and the team understands the failure modes. For larger estates or stricter split-brain control, Patroni is usually the stronger design.

### Takeaway summary

repmgr is not “less good Patroni.” It is a different HA and replication management style. Use it where simple, scriptable, PostgreSQL-native operations matter more than a full external consensus-backed HA control plane.

---

## EDB benchmark-framework

### What it is

EDB `benchmark-framework` is a public EnterpriseDB GitHub repository containing Ansible playbooks for repeatable PostgreSQL and EDB Postgres benchmarking.

The project README describes it as an Ansible Benchmark Framework used to aid testing and benchmarking of EDB CTO team R&D projects. It is designed to run from a controller machine over SSH and can run tests on one or more benchmark machines. EDB’s blog describes it as a framework for performance testing PostgreSQL and EDB Postgres Advanced Server.

The framework supports common database workload tools such as:

- `pgbench`
- TPROC-C
- TPROC-H

### What problem it solves

benchmark-framework answers this production question:

> “Can I run the same benchmark the same way across hosts, versions, settings, and database builds?”

One-off benchmarks are often misleading. This framework makes the environment, system configuration, benchmark parameters, and run execution more repeatable.

### How to use it

Typical workflow:

```bash
git clone https://github.com/EnterpriseDB/benchmark-framework.git
cd benchmark-framework
ansible-galaxy install -r requirements.yml
```

Prepare inventory:

```yaml
benchmark:
  hosts:
    bench-1.example.com:
    bench-2.example.com:
```

Configure benchmark hosts:

```bash
ansible-playbook -i inventory.yml -l benchmark playbooks/config-system.yml
```

Edit `config.yml` for:

- PostgreSQL or EDB Postgres version.
- Repository access.
- Kernel and system settings.
- PostgreSQL GUCs.
- Benchmark type.
- Scale factor.
- Client count.
- Duration.
- Run number.

Run benchmark:

```bash
./run-benchmark.sh
```

### Open-source version

The open-source version appears to be the same public **EnterpriseDB/benchmark-framework** repository. This is not like Patroni or Barman where there is a broader upstream project independent of EDB. It is an EDB-originated open repository.

### EDB version vs open-source version

| Area | Open-source benchmark-framework | EDB internal / supported usage |
|---|---|---|
| Source availability | Public GitHub repository | EDB may use internally for R&D and benchmarking |
| Main function | Repeatable benchmark automation | Same broad function |
| Product status | Engineering framework, not a database HA/backup product | May underpin EDB testing or examples |
| Support expectation | GitHub/project-level unless covered separately | Depends on EDB engagement |
| Best use | Controlled performance testing | Same, especially for EDB Postgres comparisons |

### Strong engineer’s view

This tool is useful only if the benchmark question is well formed. “Which database is faster?” is not a benchmark question. “What is the p95 latency and TPS impact of PostgreSQL 16 to 17 under this pgbench profile with these GUCs on this hardware?” is a benchmark question.

### Takeaway summary

benchmark-framework is about repeatability. Its real value is not running `pgbench`; it is removing environmental drift so the result means something.

---

## EDB pgldapsync / EDB LDAP Sync

### What it is

There are three names that are easy to confuse:

1. **EnterpriseDB/pgldapsync**
   - A public EDB GitHub project.
   - Python module for synchronizing Postgres login roles with LDAP users.
   - Uses a `config.ini` file.
   - Supports dry-run output.

2. **EDB LDAP Sync**
   - EDB-documented collection of utilities and configuration for synchronizing Postgres with LDAP-compatible directory servers such as OpenLDAP and Active Directory.
   - EDB docs say DBAs can schedule `ldap2pg` to synchronize PostgreSQL users and groups.
   - Replaces external schedulers such as cron with similar syntax.
   - Marked in EDB docs as EDB Postgres Advanced Server only.

3. **Open-source alternatives**
   - `ldap2pg`: synchronizes PostgreSQL roles and privileges from YAML or LDAP.
   - `pg_ldap_sync`: Ruby-based tool that syncs LDAP users, groups, and memberships into PostgreSQL roles.

### What problem it solves

LDAP authentication alone answers:

> “Can this person prove who they are?”

LDAP synchronization answers:

> “Does the corresponding PostgreSQL role exist, and does it have the right memberships or privileges?”

PostgreSQL can authenticate against LDAP, but the database role still needs to exist inside PostgreSQL. LDAP sync tools close that gap.

### How to use EDB pgldapsync

The EDB GitHub project documents this pattern:

```bash
python3 pgldapsync.py /path/to/config.ini
```

Dry run:

```bash
python3 pgldapsync.py --dry-run /path/to/config.ini
```

General workflow:

1. Create a dedicated PostgreSQL role with enough rights to create, alter, and drop target login roles.
2. Create a read-only LDAP bind account.
3. Copy and edit the sample `config.ini`.
4. Run dry-run first.
5. Review generated SQL.
6. Run for real.
7. Schedule it with cron, systemd timer, pipeline job, or orchestration tooling.

### How to use EDB LDAP Sync

EDB LDAP Sync is configured around sample files and scheduling of `ldap2pg`. General workflow:

1. Configure PostgreSQL / EDB Postgres Advanced Server authentication.
2. Configure LDAP or Active Directory connection settings.
3. Configure role and group synchronization rules.
4. Run in dry-run/check mode first.
5. Schedule periodic synchronization.
6. Monitor role drift and failed syncs.

### Open-source versions

The practical open-source choices are:

| Tool | What it does best |
|---|---|
| `pgldapsync` | Simple EDB Python role sync from LDAP users to Postgres login roles |
| `ldap2pg` | More complete role, group, parent role, and privilege synchronization using YAML |
| `pg_ldap_sync` | LDAP users, groups, and memberships synchronization into PostgreSQL using read-only LDAP access |

### EDB version vs open-source version

| Area | EDB pgldapsync | EDB LDAP Sync | ldap2pg | pg_ldap_sync |
|---|---|---|---|---|
| Main scope | Sync LDAP users to Postgres login roles | EDB packaged LDAP synchronization utilities/configuration | Sync roles, memberships, and privileges | Sync users, groups, memberships |
| Language/config | Python, `config.ini` | EDB package/config; uses ldap2pg according to docs | YAML-based configuration | Ruby/YAML |
| Scheduling | External scheduler usually needed | EDB docs say it replaces external schedulers like cron | Usually external scheduler or job runner | Usually cron |
| Privilege management | Basic role synchronization focus | Depends on ldap2pg configuration | Strong privilege and role management | Role/group membership focus |
| Best fit | Simple user-role sync | EDB Postgres Advanced Server estates | Flexible enterprise role/privilege sync | Lightweight OSS group sync |

### Strong engineer’s view

Do not confuse authentication with authorization. LDAP/AD login can work perfectly while PostgreSQL role state is stale, over-permissive, or missing. Always dry-run sync changes and review destructive operations such as `DROP ROLE`, `REVOKE`, or group membership removal.

### Takeaway summary

For new enterprise builds, `ldap2pg` or EDB LDAP Sync is usually the stronger path because it handles more than simple login-role creation. `pgldapsync` is useful when the requirement is narrower: keep PostgreSQL login roles aligned with LDAP users.

---

## Which Tool Should You Use?

| Requirement | Best-fit tool |
|---|---|
| Automatic PostgreSQL failover with a consensus-backed control plane | Patroni |
| Simple streaming replication management and controlled switchover | repmgr |
| Remote backups, WAL archive, retention, and PITR | Barman |
| Repeatable performance testing across hosts and versions | benchmark-framework |
| Sync PostgreSQL roles from LDAP or AD | EDB LDAP Sync, ldap2pg, or pgldapsync |
| Full disaster recovery design | Barman plus tested restore runbooks |
| HA plus recoverability | Patroni or repmgr plus Barman |
| Enterprise identity integration | LDAP authentication plus role synchronization |

---

## Operational Takeaways

1. **Do not choose between HA and backup.**
   Patroni and repmgr solve availability. Barman solves recoverability. You normally need both.

2. **Patroni is stronger for serious HA, but only if etcd/quorum is engineered correctly.**
   A bad DCS design turns HA into a false sense of safety.

3. **repmgr is still valuable.**
   It is simpler, transparent, and effective for many streaming replication estates.

4. **Barman must be judged by restore testing.**
   Backup success is not enough. Measure recovery time and recovery point from real restore drills.

5. **Benchmarking must be repeatable or it is noise.**
   benchmark-framework helps, but the test question and workload model matter more than the tool.

6. **LDAP authentication is not role lifecycle management.**
   LDAP tells PostgreSQL whether a password or identity is valid. Sync tooling ensures the database roles and memberships actually exist.

7. **EDB versions are usually about packaging, testing, certification, and support.**
   For Patroni, Barman, and repmgr, the core technology is open source. The EDB value is in validated combinations, repositories, documentation, and commercial support.

---

## Sources

- EDB Patroni documentation: https://www.enterprisedb.com/docs/supported-open-source/patroni/
- Patroni upstream project: https://github.com/patroni/patroni
- EDB Barman documentation: https://www.enterprisedb.com/docs/supported-open-source/barman/
- Barman upstream project: https://github.com/EnterpriseDB/barman
- EDB repmgr documentation: https://www.enterprisedb.com/docs/supported-open-source/repmgr/
- repmgr upstream project: https://github.com/EnterpriseDB/repmgr
- repmgr documentation: https://www.repmgr.org/docs/current/repmgr.html
- EDB benchmark-framework repository: https://github.com/EnterpriseDB/benchmark-framework
- EDB blog on Ansible Benchmark Framework: https://www.enterprisedb.com/blog/ansible-benchmark-framework-postgresql
- EDB LDAP Sync documentation: https://www.enterprisedb.com/docs/pg_extensions/ldap_sync/
- EDB pgldapsync repository: https://github.com/EnterpriseDB/pgldapsync
- ldap2pg documentation: https://ldap2pg.readthedocs.io/
- pg_ldap_sync repository: https://github.com/larskanis/pg-ldap-sync
