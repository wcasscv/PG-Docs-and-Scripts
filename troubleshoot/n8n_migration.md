# n8n Migration: “I Know This Stuff, But in the Interview I Freeze” Kit

## Strong intro

You can understand n8n migration work and still freeze in an interview.

That freeze usually does not mean you lack migration experience. It means your knowledge is stored as real operational habits: backing up the database, protecting the encryption key, checking workflow exports, validating credentials, testing webhooks, migrating from SQLite to PostgreSQL, moving Docker volumes, changing URLs behind a reverse proxy, scaling into queue mode, checking workers, and making sure a rollback path exists before touching production.

In production, an n8n migration is not just “copy workflows to a new server.” n8n stores workflows, credentials, executions, users, settings, and runtime state. Credentials are encrypted. Webhook URLs may depend on public host configuration. Queue mode depends on Redis and workers. Docker and Kubernetes deployments depend on persistent storage, environment variables, and database consistency.

This kit is built for the interview moment when you know the work but need calm, structured words.

It covers 30 common n8n migration issues interviewers ask about, with symptoms, causes, diagnostic steps, resolutions, examples, and production-safe wording. It is written for DevOps, platform, automation, SRE, support, and integration engineers who want practical interview-ready answers.

When you freeze, start with this sentence:

> “For an n8n migration, I would first protect state: database backup, encryption key, credentials, workflows, environment variables, binary data, custom nodes, webhook URLs, and rollback path. Then I would migrate in a test environment, validate workflows and credentials, run controlled executions, cut over traffic, and monitor failures before decommissioning the old instance.”

That answer sounds like someone who has done real migrations safely.

---

## How to use this kit

For every n8n migration issue, use this structure:

```text
Symptom → Scope → Evidence → Cause → Fix → Verify → Prevent
```

A strong interview answer usually includes:

1. What is being migrated.
2. Which state must be preserved.
3. Whether the risk is database, encryption key, credentials, workflows, webhooks, binary data, custom nodes, source control, queue mode, or infrastructure.
4. How you back up and test restore.
5. What validation proves the migration worked.
6. How you cut over safely.
7. How you roll back.

Example:

> “Before migrating n8n, I would confirm what database it uses, back it up, save the `N8N_ENCRYPTION_KEY`, export workflows, document environment variables, preserve binary data and custom nodes, and test the restored instance before changing DNS or webhooks.”

That is better than saying:

> “I would export and import the workflows.”

Workflow export alone is not a full n8n migration.

---

# Top 30 n8n migration issues and resolutions

---

## 1. Credentials cannot be decrypted after migration

### Interview freeze point

The new n8n instance starts, workflows are visible, but credentials fail.

### Strong interview answer

> “I would immediately check whether the original n8n encryption key was migrated. n8n encrypts credentials before saving them to the database. If the database is moved without the same encryption key, stored credentials may not decrypt.”

### Symptoms

- Workflows appear after migration.
- Credentials show errors.
- API nodes fail with authentication errors.
- Credential test fails.
- Workers cannot use credentials.
- Recreating credential fixes one node but not all.
- Migration from Docker volume to Kubernetes breaks credentials.

### Critical item

```text
N8N_ENCRYPTION_KEY
```

n8n can generate an encryption key on first startup, but production migrations should explicitly preserve and set the original key.

### Diagnostic checks

Check old deployment:

```bash
docker inspect n8n | grep N8N_ENCRYPTION_KEY
```

Check Docker Compose:

```yaml
environment:
  - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
```

Check Kubernetes Secret:

```bash
kubectl get secret n8n-secrets -n n8n -o yaml
```

### Common causes

- New deployment generated a new encryption key.
- `.n8n` user folder not migrated.
- Kubernetes Secret not created.
- Main and workers use different keys.
- Secret manager value changed.
- Backup included database but not encryption key.
- Old server was destroyed before key was saved.

### Resolution

- Restore the original `N8N_ENCRYPTION_KEY`.
- Set the same key on all n8n processes: main, workers, and webhook processors.
- Restart n8n.
- Test several credentials.
- If the key is permanently lost, credentials may need to be recreated.

### Example Kubernetes Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: n8n-secrets
  namespace: n8n
type: Opaque
stringData:
  N8N_ENCRYPTION_KEY: "replace-with-original-key"
```

### Verify

```text
Open credential → Test credential
Run workflow with credential
Check worker logs if queue mode is enabled
```

### Takeaway summary

The encryption key is migration-critical. Database backup without the original encryption key can leave credentials unusable.

---

## 2. Database backup missing or incomplete

### Interview freeze point

A migration was attempted, but the restored instance has missing workflows, users, executions, or credentials.

### Strong interview answer

> “I would treat the n8n database as the primary state store. Before migration, I would identify whether n8n uses SQLite or PostgreSQL, take a consistent backup, test restore, and verify workflows, credentials, users, and settings.”

### Symptoms

- Workflows missing.
- Credentials missing.
- Execution history missing.
- Users missing.
- Instance starts as fresh install.
- Only exported workflows were moved.
- Production rollback impossible.

### Diagnostic checks

Find database type from env vars:

```text
DB_TYPE
DB_POSTGRESDB_HOST
DB_POSTGRESDB_DATABASE
DB_POSTGRESDB_USER
```

Default self-hosted installs may use SQLite if PostgreSQL is not configured.

### PostgreSQL backup

```bash
pg_dump \
  --host "$DB_HOST" \
  --username "$DB_USER" \
  --dbname "$DB_NAME" \
  --format=custom \
  --file n8n-backup.dump
```

Restore:

```bash
pg_restore \
  --host "$DB_HOST" \
  --username "$DB_USER" \
  --dbname "$DB_NAME" \
  --clean \
  --if-exists \
  n8n-backup.dump
```

### SQLite backup idea

Stop n8n first or ensure a consistent snapshot, then back up the SQLite database file from the n8n user folder.

Example path pattern:

```text
~/.n8n/database.sqlite
```

### Common causes

- Backed up workflows only, not database.
- SQLite file copied while n8n was writing.
- Wrong PostgreSQL database dumped.
- New instance points to empty database.
- Database schema migration interrupted.
- Backup did not include credentials/users/settings.
- No restore test.

### Resolution

- Identify actual source database.
- Take consistent backup.
- Restore into test environment.
- Verify object counts.
- Keep old instance read-only until validation.
- Do not destroy old storage before acceptance.

### Takeaway summary

An n8n migration is a state migration. Back up and test restore of the database before cutover.

---

## 3. SQLite to PostgreSQL migration failure

### Interview freeze point

The team wants to move from a simple single-node setup to PostgreSQL.

### Strong interview answer

> “I would not treat SQLite to PostgreSQL as just changing an environment variable. I would export or migrate the existing data carefully, preserve the encryption key, configure PostgreSQL, validate workflows and credentials, and test in a staging copy first.”

### Symptoms

- New PostgreSQL-backed instance starts empty.
- Workflows missing after DB switch.
- Credentials fail after import.
- Execution history lost.
- Migration works locally but not in container.
- Database tables not created or permission denied.

### Common causes

- Changed `DB_TYPE` without moving data.
- PostgreSQL database not created.
- PostgreSQL user lacks privileges.
- Encryption key not preserved.
- Import overwrote existing objects.
- Version mismatch during migration.
- SQLite backup inconsistent.

### PostgreSQL environment example

```yaml
environment:
  - DB_TYPE=postgresdb
  - DB_POSTGRESDB_HOST=postgres
  - DB_POSTGRESDB_PORT=5432
  - DB_POSTGRESDB_DATABASE=n8n
  - DB_POSTGRESDB_USER=n8n
  - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
  - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
```

### Migration approach

```text
1. Stop writes on old instance.
2. Back up SQLite database and encryption key.
3. Start a test n8n instance with PostgreSQL.
4. Import/migrate workflows and credentials or use a supported data migration process.
5. Validate credentials, workflows, webhooks, and users.
6. Cut over only after test success.
```

### CLI export/import pattern

Export workflows:

```bash
n8n export:workflow --all --output=workflows.json
```

Export credentials:

```bash
n8n export:credentials --all --output=credentials.json
```

Import:

```bash
n8n import:workflow --input=workflows.json
n8n import:credentials --input=credentials.json
```

Exact command flags may vary by n8n version, so verify against the installed version.

### Takeaway summary

Changing the database config creates a new backend; it does not magically move existing SQLite data.

---

## 4. Import overwrites workflows or credentials

### Interview freeze point

Importing exported objects damages or replaces existing objects.

### Strong interview answer

> “I would check exported IDs before importing into a non-empty instance. n8n exports IDs, and importing objects with matching IDs can overwrite existing workflows or credentials. I would import into a clean target or adjust IDs deliberately.”

### Symptoms

- Existing workflow changed unexpectedly.
- Credential overwritten.
- Imported workflow replaced production workflow.
- IDs conflict.
- Team loses local changes.

### Common causes

- Importing into non-empty environment.
- Export includes IDs.
- Same object exists in target.
- Source control pull overwrites variable/tag files.
- Credentials with same IDs behave differently.
- No pre-import backup.

### Diagnostic steps

```text
Is target instance empty?
Are workflow IDs present in JSON?
Are credential IDs present?
Is this import meant to create or replace?
Was target backed up first?
```

### Example exported workflow contains ID

```json
{
  "id": "abc123",
  "name": "Process Orders",
  "nodes": []
}
```

### Safer import plan

```text
1. Back up target.
2. Import into staging first.
3. Check IDs.
4. Remove/change IDs if creating copies.
5. Import in controlled order.
6. Validate affected workflows.
```

### Resolution

- Restore backup if overwritten.
- Use a clean target instance for full migration.
- For partial imports, remove or adjust IDs where appropriate.
- Document import behavior in runbook.

### Takeaway summary

Import is not always additive. IDs matter. Back up before importing into an existing instance.

---

## 5. Workflows imported without credentials

### Interview freeze point

Workflows are visible, but nodes have missing credentials.

### Strong interview answer

> “I would check whether credentials were exported/imported separately, whether credential IDs match, whether credentials were intentionally excluded for security, and whether the encryption key is the same.”

### Symptoms

- Workflow imported successfully.
- Nodes show missing credential.
- Credential dropdown empty.
- Imported credentials exist but nodes do not link to them.
- Credential test fails.

### Common causes

- Only workflows exported.
- Credentials not imported.
- Credential IDs changed.
- Credential type changed between versions.
- Encryption key mismatch.
- Credential ownership/project sharing issue.
- Source control does not include secret values in expected way.

### Export/import pattern

Export workflows:

```bash
n8n export:workflow --all --output=workflows.json
```

Export credentials:

```bash
n8n export:credentials --all --output=credentials.json
```

Import workflows and credentials:

```bash
n8n import:credentials --input=credentials.json
n8n import:workflow --input=workflows.json
```

### Resolution

- Export and import credentials as part of migration.
- Preserve encryption key.
- Re-map credentials manually if needed.
- Test critical credentials.
- Use environment-specific credentials for dev/stage/prod.
- Avoid assuming workflow JSON includes usable secrets.

### Verify

```text
Open workflow
Check credential selected on each credentialed node
Test credential
Run workflow with controlled input
```

### Takeaway summary

Workflow migration and credential migration are related but separate. A workflow without its credentials may import but not run.

---

## 6. Wrong n8n version during migration

### Interview freeze point

The old instance is on one version, the new instance is on a much newer or older version.

### Strong interview answer

> “I would avoid combining platform migration and major version upgrade unless planned. I would first migrate like-for-like, validate, then upgrade in a separate controlled step with release notes and rollback.”

### Symptoms

- Database migration errors.
- Workflows behave differently.
- Node parameters changed.
- Code node behavior changed.
- Credentials need reconnect.
- Downgrade fails after upgrade.
- UI shows migration warnings.

### Common causes

- New Docker image uses `latest`.
- Major version changed during migration.
- Database migrations applied automatically.
- Attempted rollback to older n8n after DB schema upgrade.
- Breaking changes not reviewed.
- Custom nodes incompatible.

### Safer approach

```text
Step 1: Move old version to new infrastructure.
Step 2: Validate everything.
Step 3: Back up again.
Step 4: Upgrade n8n version.
Step 5: Validate again.
```

### Docker image pinning

Bad:

```yaml
image: n8nio/n8n:latest
```

Better:

```yaml
image: n8nio/n8n:1.XX.X
```

### Resolution

- Pin source and target version.
- Review migration guides and breaking changes.
- Test upgrade with copied database.
- Back up before first startup on new version.
- Avoid downgrading after schema migrations unless supported.

### Takeaway summary

Do not mix migration and major upgrade casually. Pin versions and test database migrations.

---

## 7. Webhook URLs change after migration

### Interview freeze point

Workflows are migrated, but external services still call the old instance.

### Strong interview answer

> “I would inventory all webhook workflows, identify external systems that call them, configure the new public webhook URL, and plan DNS or provider-side cutover. Webhook migration is an integration migration, not just an n8n migration.”

### Symptoms

- Old n8n still receives events.
- New n8n receives no webhooks.
- External provider returns 404.
- OAuth callback fails.
- Test webhook works but production provider fails.
- Duplicates during cutover.

### Common causes

- External services still use old URL.
- `WEBHOOK_URL` not set correctly.
- Reverse proxy base URL wrong.
- Workflow inactive in new instance.
- DNS not cut over.
- Both old and new workflows active.
- Provider caches webhook URL.
- Firewall blocks new endpoint.

### Environment example

```yaml
environment:
  - N8N_HOST=n8n.example.com
  - N8N_PROTOCOL=https
  - WEBHOOK_URL=https://n8n.example.com/
```

### Migration checklist

```text
List active webhook workflows
Export current webhook URLs
Configure new public URL
Test with curl
Update external providers
Disable old workflows or route traffic once
Monitor delivery logs
```

### Curl test

```bash
curl -i -X POST \
  -H "Content-Type: application/json" \
  -d '{"migration":"test"}' \
  https://n8n.example.com/webhook/order-created
```

### Takeaway summary

Webhook cutover must be planned. If both old and new instances are active, duplicates are likely.

---

## 8. OAuth callbacks break after domain change

### Interview freeze point

Users cannot reconnect OAuth credentials after migration.

### Strong interview answer

> “I would check the public n8n URL and OAuth redirect URI registered with the provider. If the n8n domain or protocol changed, OAuth providers must trust the new callback URL.”

### Symptoms

- OAuth reconnect fails.
- Redirect URI mismatch.
- Login loop.
- Credential test fails after domain migration.
- OAuth provider rejects callback.
- Old domain appears in callback.

### Common callback pattern

```text
https://n8n.example.com/rest/oauth2-credential/callback
```

### Common causes

- `N8N_HOST` or `N8N_PROTOCOL` wrong.
- `WEBHOOK_URL` or public URL wrong.
- OAuth app still has old callback URL.
- Reverse proxy sends wrong `X-Forwarded-Proto`.
- HTTP/HTTPS mismatch.
- Base path changed.

### Resolution

- Set correct public host and protocol.
- Fix reverse proxy headers.
- Update OAuth provider redirect URI.
- Reconnect affected credentials.
- Test OAuth credential.
- Keep old domain redirect during transition if possible.

### Example env

```yaml
environment:
  - N8N_HOST=n8n.example.com
  - N8N_PROTOCOL=https
  - WEBHOOK_URL=https://n8n.example.com/
```

### Takeaway summary

Domain migrations break OAuth unless callback URLs and proxy headers are updated.

---

## 9. Reverse proxy migration causes login or webhook issues

### Interview freeze point

The new server works directly but fails through Nginx, Traefik, ALB, or ingress.

### Strong interview answer

> “I would check forwarded headers, TLS termination, websocket support if needed, body size limits, timeout settings, base URL, and whether webhook paths are routed to the right service.”

### Symptoms

- UI loads but login fails.
- Webhooks return 404/502.
- OAuth callback uses HTTP.
- Large webhook payload rejected.
- Browser mixed-content error.
- Execution UI fails to update.
- File uploads fail.

### Common causes

- Missing `Host` header.
- Missing `X-Forwarded-Proto`.
- Proxy timeout too low.
- Body size limit too low.
- Path rewrite wrong.
- TLS terminated but n8n thinks HTTP.
- Ingress routes `/webhook` incorrectly.
- Cookie secure settings affected.

### Nginx header example

```nginx
proxy_set_header Host $host;
proxy_set_header X-Forwarded-Proto https;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
```

### Body size example

```nginx
client_max_body_size 50m;
```

### Resolution

- Fix forwarded headers.
- Set n8n public URL env vars.
- Increase body size if needed.
- Increase proxy timeout for long requests, but prefer async webhooks.
- Test UI, OAuth, webhook, file upload.

### Takeaway summary

Reverse proxy migration is part of n8n migration. Test UI, OAuth, webhooks, and payload size.

---

## 10. Binary data missing after migration

### Interview freeze point

Workflows and database are migrated, but files/attachments are missing.

### Strong interview answer

> “I would check how binary data is stored. If binary data is stored on filesystem or external storage, database migration alone may not include files. I would migrate the binary data location and preserve the same configuration.”

### Symptoms

- Execution history exists but attachments missing.
- File nodes fail.
- Binary property exists but file cannot be read.
- Old executions cannot display files.
- Worker cannot access binary file.
- Queue mode fails only for binary workflows.

### Common causes

- Binary data stored on local filesystem not migrated.
- Docker volume not copied.
- Kubernetes PVC not mounted.
- External storage config missing.
- Main and workers do not share binary storage.
- Retention cleanup removed files.
- Path changed between deployments.

### Diagnostic checklist

```text
Binary data mode
Filesystem path or external storage
Docker volume/PVC mounted?
Workers can access it?
Old executions need binary history?
```

### Docker volume example

```yaml
volumes:
  - n8n_data:/home/node/.n8n
```

If binary data is under the user folder or configured path, preserve that volume.

### Resolution

- Identify binary storage mode and path.
- Copy filesystem binary data.
- Mount same persistent volume.
- Configure external object storage if used.
- Ensure all queue workers can access binary data.
- Test workflows with file upload/download.

### Takeaway summary

Database backup may not include binary files. Know where n8n stores binary data before migrating.

---

## 11. Custom nodes missing after migration

### Interview freeze point

Workflows import, but custom/community node types are unknown.

### Strong interview answer

> “I would inventory custom and community nodes before migration, install the same node packages and versions on the target, and ensure every worker has them in queue mode.”

### Symptoms

- Workflow shows unknown node type.
- Execution fails with node not found.
- Works on main but fails on worker.
- Custom node appears in old instance only.
- Imported workflow cannot open a node.

### Common causes

- Custom nodes not installed on target.
- Different custom node version.
- Workers do not have custom nodes.
- Custom nodes path changed.
- Docker image did not include custom nodes.
- Community node installation disabled.
- Node package incompatible with new n8n version.

### Diagnostic checklist

```text
List custom/community nodes
Check package versions
Check custom node path
Check target image contains nodes
Check workers contain nodes
Check n8n version compatibility
```

### Docker image pattern

Build custom image:

```dockerfile
FROM n8nio/n8n:1.XX.X
USER root
RUN npm install -g n8n-nodes-example
USER node
```

### Resolution

- Install same custom nodes.
- Pin versions.
- Build repeatable image.
- Deploy same image to main and workers.
- Test workflows using custom nodes.
- Check compatibility before upgrading n8n.

### Takeaway summary

Custom nodes are runtime dependencies. Migrate them like application dependencies.

---

## 12. Environment variables missing after migration

### Interview freeze point

The new n8n starts, but behavior is different.

### Strong interview answer

> “I would export and compare environment variables from the old and new deployment. n8n behavior depends heavily on environment configuration: database, encryption, host, webhook URL, timezone, executions, queue mode, and binary data.”

### Symptoms

- n8n starts fresh.
- Wrong database used.
- Credentials fail.
- Webhook URL wrong.
- Timezone changed.
- Queue mode disabled.
- Executions saved differently.
- Code node loses env access after upgrade/config change.

### Important categories

```text
Database
Encryption key
Host/protocol/webhook URL
Executions
Queue mode/Redis
Binary data
Timezone
Logs
Security
Custom nodes
```

### Docker check

```bash
docker inspect n8n --format '{{json .Config.Env}}' | jq
```

Kubernetes:

```bash
kubectl describe deployment n8n -n n8n
kubectl get secret n8n-secrets -n n8n -o yaml
kubectl get configmap n8n-config -n n8n -o yaml
```

### Resolution

- Create an environment variable inventory.
- Use ConfigMap and Secret separation.
- Keep secrets in secret manager.
- Compare old/new before cutover.
- Use version-controlled deployment manifests.
- Avoid relying on implicit defaults.

### Takeaway summary

Missing environment variables are one of the most common migration causes of “same app, different behavior.”

---

## 13. Timezone changes after migration

### Interview freeze point

Scheduled workflows run at the wrong time.

### Strong interview answer

> “I would check n8n timezone configuration, container timezone, host timezone, and schedule trigger settings. Cron-like workflows are sensitive to timezone changes during migration.”

### Symptoms

- Cron workflows run one hour off.
- Jobs run in UTC instead of local time.
- Business-hours workflows trigger incorrectly.
- Daylight saving behavior changes.
- Old and new instance run schedules at different times.

### Common causes

- Timezone env var missing.
- Container uses UTC.
- Host timezone differed.
- Workflow schedule was interpreted differently.
- Daylight saving transition.
- Multiple active instances in different timezones.

### Example env

```yaml
environment:
  - GENERIC_TIMEZONE=Europe/Dublin
  - TZ=Europe/Dublin
```

### Verification

```bash
date
```

Check n8n schedule trigger next run in UI.

### Resolution

- Set timezone explicitly.
- Validate critical schedules.
- Run controlled schedule test.
- Disable old instance before activating new schedules.
- Communicate cutover timing.

### Takeaway summary

Always set timezone explicitly. Do not depend on host or container defaults.

---

## 14. Source control migration overwrites variables, tags, or credentials behavior

### Interview freeze point

n8n source control is used, and pull/push behaves unexpectedly.

### Strong interview answer

> “I would check what source control actually manages and what it does not. I would be careful with variables, tags, credentials metadata, and environment-specific secrets. Pulling source control is not the same as restoring a full instance backup.”

### Symptoms

- Variables overwritten.
- Tags changed.
- Credentials metadata changes but secret values do not update as expected.
- Workflows differ after pull.
- Environment-specific config overwritten.
- Prod gets dev workflow change.

### Common causes

- Source control branch mismatch.
- Variables/tags overwritten by pull.
- Credentials require environment-specific handling.
- Secrets not stored in Git.
- Workflow activation state differs.
- Pull applied to wrong environment.
- No promotion process.

### Safer promotion checklist

```text
Correct branch
Review diff
Confirm variables
Confirm credentials mapping
Confirm activation state
Run test workflow
Backup before pull
```

### Resolution

- Treat source control as deployment mechanism, not full backup.
- Keep secrets environment-specific.
- Use branch strategy.
- Review changes before pull.
- Document what source control covers.
- Validate after pull.

### Takeaway summary

Source control helps promote workflows, but it does not replace database backups, credential handling, or environment mapping.

---

## 15. Active workflows duplicated during cutover

### Interview freeze point

Both old and new n8n instances process the same triggers.

### Strong interview answer

> “I would prevent double-processing by controlling activation and traffic. During cutover, either old or new should own each trigger, not both. This is especially important for schedules and webhooks with side effects.”

### Symptoms

- Duplicate emails.
- Duplicate tickets/orders.
- Same webhook processed twice.
- Cron job runs in both old and new.
- External provider sends to both URLs.
- Data sync creates duplicates.

### Common causes

- Old workflows still active.
- New workflows activated before traffic cutover.
- DNS sends traffic to both.
- Webhook provider has both URLs.
- Cron triggers active in both environments.
- Queue workers from old and new share or compete unexpectedly.
- No idempotency keys.

### Cutover pattern

```text
1. Put old instance in maintenance/read-only mode if possible.
2. Disable old scheduled workflows.
3. Activate new workflows.
4. Switch webhooks/DNS.
5. Monitor.
6. Keep old instance available but not processing.
```

### Safer workflow design

Use dedupe key:

```text
event_id
order_id
external_id
```

Before writing:

```text
Check if already processed
If yes, stop
If no, process and record key
```

### Takeaway summary

During migration, duplicate processing is a bigger risk than downtime for many automations. Control trigger ownership.

---

## 16. Workflow activation state not preserved

### Interview freeze point

The migrated workflows exist but are inactive, or everything becomes active unexpectedly.

### Strong interview answer

> “I would inventory active workflows before migration and verify activation state after import or restore. Activation state matters because triggers and schedules depend on it.”

### Symptoms

- Scheduled workflows do not run.
- Webhook production URL does not work.
- Too many workflows start running after migration.
- Imported workflows are inactive.
- Prod workflows accidentally active in staging.

### Diagnostic checklist

Before migration:

```text
List active workflows
List webhook workflows
List schedule workflows
List high-risk side-effect workflows
```

After migration:

```text
Compare active workflow count
Check critical workflow activation
Test trigger behavior
```

### Common causes

- Export/import does not preserve activation as expected.
- Workflows intentionally inactive after import.
- Source control activation behavior differs.
- Staging environment accidentally activates prod triggers.
- Manual activation missed.
- Permissions prevent activation.

### Resolution

- Document active workflow list.
- Activate only intended workflows.
- Keep staging triggers disabled or pointed to sandbox.
- Use environment-specific variables and credentials.
- Validate production trigger list after cutover.

### Takeaway summary

Migration success includes correct activation state, not just workflow presence.

---

## 17. Execution history lost or too large to migrate

### Interview freeze point

The team wants execution history, but it makes migration heavy.

### Strong interview answer

> “I would clarify whether execution history is required for compliance, debugging, or not needed. Execution history can be large. I would decide retention, archive if needed, and avoid carrying unnecessary data into the new instance.”

### Symptoms

- Database backup huge.
- Restore takes too long.
- n8n UI slow after restore.
- Execution history missing after export/import.
- Compliance asks for old executions.
- Migration window too long.

### Common causes

- Saving all successful executions.
- Large binary data stored with executions.
- No pruning.
- Export/import workflows does not include execution history.
- Full database migration includes everything.
- Old instance kept too much debug data.

### Decision questions

```text
Do we need old executions in new n8n?
Do we need archive-only access?
What is retention policy?
Can we prune before migration?
Are binary files part of history?
```

### Resolution

- Back up full database for archive.
- Prune old executions if acceptable.
- Migrate only workflows/credentials if history is not required.
- Tune execution retention on target.
- Store compliance archive separately.

### Takeaway summary

Execution history is useful but can dominate migration size. Decide retention deliberately.

---

## 18. Queue mode migration fails

### Interview freeze point

The old single n8n instance is migrated to queue mode with workers.

### Strong interview answer

> “I would treat queue mode as an architecture change. It requires Redis, worker processes, shared database, same encryption key, consistent environment variables, custom nodes on every worker, and correct webhook routing.”

### Symptoms

- Executions remain queued.
- Workers cannot decrypt credentials.
- Webhooks accepted but not processed.
- Some workflows fail only on workers.
- Binary files missing.
- Redis connection error.

### Required pieces

```text
Main n8n process
Worker processes
Redis
PostgreSQL
Same N8N_ENCRYPTION_KEY
Same custom nodes
Same relevant env vars
Shared binary storage if needed
```

### Example worker command

```bash
n8n worker
```

### Common causes

- Redis not reachable.
- Workers not started.
- Workers use wrong DB.
- Workers use wrong encryption key.
- Custom nodes missing on workers.
- Binary storage not shared.
- Worker concurrency too high.
- Webhook processors not configured as expected.

### Resolution

- First migrate single-node successfully.
- Then enable queue mode in staging.
- Test one workflow.
- Test credentials on worker.
- Test binary workflow.
- Scale workers gradually.
- Monitor Redis, DB, and worker logs.

### Takeaway summary

Queue mode migration is not just scaling n8n. It changes runtime topology and failure modes.

---

## 19. Redis migration or configuration issue

### Interview freeze point

Queue mode depends on Redis, and Redis is misconfigured.

### Strong interview answer

> “I would check Redis availability, authentication, DB index, TLS if used, network policy, persistence expectations, and whether all n8n processes point to the same Redis.”

### Symptoms

- Queue workers idle.
- Main logs Redis errors.
- Executions stuck waiting.
- Jobs disappear after Redis restart.
- Workers connect to wrong Redis.
- TLS/authentication errors.

### Diagnostic commands

```bash
redis-cli -h redis -p 6379 ping
```

Expected:

```text
PONG
```

Check from n8n pod/container if possible.

### Common causes

- Wrong Redis host.
- Wrong password.
- Redis service not reachable.
- NetworkPolicy blocks connection.
- TLS mismatch.
- Redis DB index mismatch.
- Redis restarted during migration.
- Redis not sized for queue load.

### Resolution

- Validate Redis connectivity from main and workers.
- Set Redis env vars consistently.
- Secure Redis with network controls and auth.
- Monitor Redis memory and connections.
- Avoid using an unreliable Redis for production queue mode.

### Takeaway summary

In queue mode, Redis is part of the execution path. If Redis is unhealthy, workflows do not process normally.

---

## 20. PostgreSQL connection limit reached after migration

### Interview freeze point

The old instance worked, but the new queue setup overloads the database.

### Strong interview answer

> “I would check PostgreSQL connection limits, n8n main and worker count, database pool settings, long-running executions, and whether migration introduced more processes connecting to the same database.”

### Symptoms

- `too many connections`
- Workers fail randomly.
- n8n startup fails sometimes.
- Slow execution listing.
- Database CPU high.
- Queue mode unstable.

### Common causes

- More workers than DB can support.
- Each worker opens DB connections.
- Old and new instances both running.
- Connection pool not tuned.
- PostgreSQL max connections too low.
- Long queries from large execution history.
- Missing DB resources.

### Diagnostic SQL

```sql
select count(*) from pg_stat_activity;
select datname, usename, state, count(*)
from pg_stat_activity
group by datname, usename, state
order by count(*) desc;
```

### Resolution

- Scale workers gradually.
- Increase PostgreSQL capacity if needed.
- Tune n8n/DB connection settings where supported.
- Stop old instance after cutover.
- Prune huge execution history if impacting DB.
- Add monitoring.

### Takeaway summary

Queue mode and migration can increase database connections. PostgreSQL must be sized for the new topology.

---

## 21. Docker volume not migrated

### Interview freeze point

The new Docker container starts fresh because persistent data was not mounted or copied.

### Strong interview answer

> “I would check Docker volumes and the n8n user folder. In Docker, data inside a container is disposable unless stored in a volume or external database. Migration must preserve the mounted volume or external database state.”

### Symptoms

- New container starts as fresh n8n.
- Workflows missing.
- SQLite database missing.
- Encryption key missing.
- Custom files missing.
- Restart loses data.

### Diagnostic commands

```bash
docker volume ls
docker inspect n8n --format '{{json .Mounts}}' | jq
docker compose config
```

### Common Docker volume

```yaml
volumes:
  - n8n_data:/home/node/.n8n
```

### Backup volume pattern

```bash
docker run --rm \
  -v n8n_data:/data \
  -v "$PWD":/backup \
  alpine \
  tar czf /backup/n8n_data_backup.tgz -C /data .
```

Restore:

```bash
docker run --rm \
  -v n8n_data_new:/data \
  -v "$PWD":/backup \
  alpine \
  tar xzf /backup/n8n_data_backup.tgz -C /data
```

### Resolution

- Identify old volume.
- Stop n8n for consistent copy if using SQLite.
- Back up volume.
- Restore volume to target.
- Preserve encryption key.
- Prefer PostgreSQL for production migrations.

### Takeaway summary

Docker containers are replaceable. Docker volumes contain the state you probably care about.

---

## 22. Kubernetes PVC or Secret missing during migration

### Interview freeze point

The new Kubernetes deployment starts, but state or config is missing.

### Strong interview answer

> “I would check Kubernetes PersistentVolumeClaims, Secrets, ConfigMaps, service account permissions, ingress, and environment variables. In Kubernetes, migration is declarative only if the stateful dependencies are included.”

### Symptoms

- Pods start but n8n is fresh.
- Credentials fail.
- Pod CrashLoopBackOff.
- Webhook URL wrong.
- Binary files missing.
- Workers cannot decrypt credentials.
- Ingress works but OAuth fails.

### Diagnostic commands

```bash
kubectl get pods -n n8n
kubectl get pvc -n n8n
kubectl get secrets -n n8n
kubectl get configmap -n n8n
kubectl describe pod -n n8n <pod>
kubectl logs -n n8n <pod>
```

### Key Kubernetes objects

```text
Secret for N8N_ENCRYPTION_KEY
Secret for database password
ConfigMap for non-secret env
PVC for local n8n data/binary data if used
Ingress for public URL
Service for internal routing
Deployment/StatefulSet for n8n
Worker Deployment if queue mode
```

### Resolution

- Restore PVC if needed.
- Create Secret with original encryption key.
- Configure DB connection.
- Mount custom nodes/binary storage.
- Use same image version.
- Validate ingress and webhook URL.

### Takeaway summary

Kubernetes manifests alone are not the migration. Secrets, PVCs, and external databases are critical state.

---

## 23. File permissions break after migration

### Interview freeze point

n8n starts but cannot write to its user folder, binary storage, or mounted volume.

### Strong interview answer

> “I would check the user n8n runs as, UID/GID ownership of mounted volumes, Kubernetes security context, and filesystem permissions. Container migrations often fail because volumes are owned by a different user.”

### Symptoms

- Permission denied.
- Cannot write to `.n8n`.
- Cannot save settings.
- Cannot store binary data.
- SQLite database cannot open.
- Pod CrashLoopBackOff after mounting PVC.

### Diagnostic commands

Inside container/pod:

```bash
id
ls -ld /home/node/.n8n
ls -la /home/node/.n8n
```

Docker:

```bash
docker exec -it n8n sh
```

Kubernetes:

```bash
kubectl exec -it -n n8n deploy/n8n -- sh
```

### Common causes

- Volume owned by root.
- UID changed between images.
- Kubernetes `runAsUser` mismatch.
- Restored files have wrong ownership.
- Read-only filesystem.
- PVC permissions not compatible.
- NFS/root squash issue.

### Kubernetes security context example

```yaml
securityContext:
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
```

### Docker fix example

```bash
sudo chown -R 1000:1000 ./n8n_data
```

### Takeaway summary

State migration includes ownership and permissions, not just copying files.

---

## 24. Custom certificates or corporate proxy not migrated

### Interview freeze point

Workflows that call internal APIs fail only on the new instance.

### Strong interview answer

> “I would check whether custom CA certificates, proxy settings, DNS, and network routes were migrated. API connectivity depends on trust and network configuration, not just workflow JSON.”

### Symptoms

- Internal HTTPS API fails with certificate error.
- Works on old server but not new.
- Corporate proxy required.
- DNS for internal service fails.
- HTTP Request node fails for private endpoints.
- OAuth token endpoint unreachable.

### Common causes

- Custom CA not installed in new image.
- Proxy env vars missing.
- No egress route.
- DNS differs.
- Firewall rules not updated.
- Kubernetes NetworkPolicy blocks egress.
- Private endpoint accessible only from old network.

### Proxy env example

```yaml
environment:
  - HTTP_PROXY=http://proxy.example.com:8080
  - HTTPS_PROXY=http://proxy.example.com:8080
  - NO_PROXY=localhost,127.0.0.1,.svc,.cluster.local
```

### Custom CA pattern

Use a custom Docker image or mount CA certificates, then configure Node.js trust as required by your deployment model.

### Resolution

- Inventory internal APIs.
- Test connectivity from new container/pod.
- Migrate proxy settings.
- Migrate custom CA trust.
- Update firewall allowlists.
- Validate DNS resolution.

### Takeaway summary

Workflow migration fails if the new runtime cannot reach or trust the same services.

---

## 25. IP allowlists break after migration

### Interview freeze point

External APIs reject the new n8n instance.

### Strong interview answer

> “I would check whether downstream systems allowlist the old server IP or NAT gateway. A migration often changes outbound IP, which can break APIs even when credentials are correct.”

### Symptoms

- API returns 403.
- Works from old instance.
- New instance credentials are valid but rejected.
- Vendor says IP not allowed.
- Only some integrations fail.
- Cloud NAT or egress IP changed.

### Diagnostic commands

From new instance:

```bash
curl https://ifconfig.me
```

or:

```bash
curl https://api.ipify.org
```

### Common causes

- New VM public IP.
- New Kubernetes NAT gateway.
- New cloud region.
- Different egress path.
- Proxy not used.
- Vendor allowlist still has old IP.
- Private API firewall not updated.

### Resolution

- Identify new outbound IP.
- Update vendor allowlists.
- Use stable NAT gateway/static egress IP.
- Route through approved proxy.
- Test from runtime environment, not laptop.
- Keep old allowlist during cutover window if safe.

### Takeaway summary

Credentials can be correct and still fail if the new outbound IP is not trusted.

---

## 26. DNS cutover causes split traffic or stale callbacks

### Interview freeze point

Some events hit old n8n and some hit new n8n after migration.

### Strong interview answer

> “I would lower DNS TTL before migration, plan the cutover, monitor both old and new endpoints, and avoid running both as active processors unless workflows are idempotent.”

### Symptoms

- Some webhooks go to old server.
- Some users see old UI.
- OAuth callbacks inconsistent.
- Duplicates or missed events.
- DNS resolves differently by location.
- Rollback unclear.

### Common causes

- High DNS TTL.
- Load balancer still includes old backend.
- External providers cache DNS or URL.
- Both old and new active.
- CDN/proxy cache.
- Manual webhook URLs not updated.

### Cutover plan

```text
1. Lower DNS TTL ahead of migration.
2. Validate new endpoint with temporary hostname.
3. Disable processing on old instance or make workflows idempotent.
4. Change DNS/load balancer.
5. Monitor old access logs.
6. Keep rollback path.
```

### Verification

```bash
dig n8n.example.com
curl -I https://n8n.example.com
```

### Takeaway summary

DNS cutover is not instant everywhere. Plan for overlap and avoid double processing.

---

## 27. Source and target both write to same database

### Interview freeze point

Old and new n8n point to the same database during migration.

### Strong interview answer

> “I would be very cautious with two n8n instances using the same database, especially across versions or active triggers. This can cause duplicate executions, schema conflicts, or unexpected runtime behavior.”

### Symptoms

- Duplicate executions.
- Old and new instances both process schedules.
- Database migrations happen unexpectedly.
- Version mismatch errors.
- Workflows changed from one instance appear in another.
- Hard-to-debug race conditions.

### Common causes

- New instance tested against production DB.
- Old instance not stopped.
- Both active during cutover.
- New version migrates schema while old version still running.
- Queue workers from both environments connected.
- Same Redis queue used by both.

### Safer pattern

```text
Production DB → backup → restore copy to staging
Test migration on copy
Stop old production or put in maintenance
Start new production against production DB
Avoid mixed versions writing to same DB
```

### Resolution

- Do not test migrations against live DB with active old instance.
- Use DB snapshots for staging.
- Stop old instance before final DB migration.
- Ensure only one active writer set.
- Keep versions aligned during cutover.

### Takeaway summary

Two active n8n deployments sharing one database is high risk unless intentionally designed and version-aligned.

---

## 28. Rollback plan fails

### Interview freeze point

Migration fails, but rollback is not possible.

### Strong interview answer

> “I would define rollback before migration. That means database backup, encryption key, old instance preserved, DNS rollback, old webhook routes, old image version, and a decision point before destructive schema upgrades.”

### Symptoms

- Cannot restore old credentials.
- Old instance deleted.
- Database schema upgraded and old version cannot run.
- DNS rollback not planned.
- Webhook providers updated manually with no record.
- New instance partially processed data.
- Duplicate side effects make rollback unsafe.

### Rollback checklist

```text
Old instance still available?
Old database backup tested?
Encryption key saved?
Old Docker image/version known?
DNS TTL low enough?
Webhook provider old URLs documented?
Can external side effects be reconciled?
Is old instance disabled or paused safely?
```

### Safer migration stages

```text
Backup
Restore test
Validate
Freeze writes/triggers
Cut over
Monitor
Rollback decision window
Decommission later
```

### Resolution

- Restore DB backup.
- Restore original encryption key.
- Point DNS/webhooks back.
- Re-enable old workflows.
- Reconcile any events processed by new instance.
- Use idempotency logs to avoid duplicates.

### Takeaway summary

Rollback is not a hope. It is a tested path with state, DNS, credentials, and side effects accounted for.

---

## 29. Upgrade to n8n v2 breaks workflows

### Interview freeze point

A migration includes a major upgrade and workflows behave differently.

### Strong interview answer

> “I would run the migration report/tooling where available, review breaking changes, test workflows in staging, and avoid combining major upgrade with infrastructure migration unless necessary.”

### Symptoms

- Workflows using environment variables in Code node fail.
- Custom nodes incompatible.
- Credentials need updates.
- Node behavior changed.
- Migration report flags workflows.
- Previously working workflows fail after upgrade.

### Example v2 concern

Recent n8n v2 migration guidance highlights behavior changes such as environment variable access from Code nodes being blocked by default for security, depending on configuration.

### Diagnostic steps

```text
Run migration report/tool if available
Review breaking changes
Search workflows for Code node env usage
Test critical workflows
Check custom nodes
Check credentials
```

### Example Code node pattern at risk

```javascript
const apiUrl = $env.API_BASE_URL;
```

If environment access is blocked, this can fail depending on configuration.

### Better pattern

- Use credentials for secrets.
- Use variables or explicit workflow configuration where appropriate.
- Avoid relying on unrestricted environment access from Code nodes.

### Resolution

- Review migration report.
- Fix flagged workflows.
- Update custom nodes.
- Adjust secure environment access only if justified.
- Test before production upgrade.
- Keep backup and rollback path.

### Takeaway summary

Major n8n upgrades need workflow compatibility testing. Do not assume all nodes behave exactly the same.

---

## 30. No migration validation checklist

### Interview freeze point

The migration technically completes, but no one knows if it worked.

### Strong interview answer

> “I would define success criteria before migration. A good n8n migration validation checks workflows, credentials, webhooks, schedules, queue workers, binary data, external APIs, error workflows, execution history, and monitoring.”

### Symptoms

- Migration declared complete too early.
- Hidden workflow failures appear days later.
- Webhook integrations silently stop.
- Scheduled workflows missed.
- Credentials fail only when used.
- Error alerts not configured.
- Old instance decommissioned too soon.

### Validation checklist

```text
n8n UI accessible
Correct version running
Database connected
Encryption key correct
Credentials test successfully
Critical workflows execute
Webhook URLs receive external requests
Schedule triggers fire at expected time
Queue workers process jobs
Binary file workflows work
Custom nodes load
Error workflows alert
Execution retention configured
Monitoring/logging active
Old instance disabled, not deleted immediately
Rollback still possible
```

### Smoke test pattern

For each critical workflow:

```text
Known input → Expected node path → Expected external side effect → Expected log/alert
```

Example:

```text
Test order webhook → Create test ticket → Send Slack notification → Record execution success
```

### Resolution

- Create migration test plan.
- Assign owners for critical workflows.
- Run smoke tests before DNS cutover.
- Monitor after cutover.
- Keep old instance available for defined period.
- Document final sign-off.

### Takeaway summary

Migration is complete only when the important workflows are proven working in the new environment.

---

# Bonus: n8n migration interview answer frameworks

## Framework 1: The full n8n migration answer

Use this when asked:

> “How would you migrate n8n to a new server?”

```text
1. Inventory current instance.
2. Identify database type.
3. Back up database.
4. Save N8N_ENCRYPTION_KEY.
5. Export workflows and credentials as secondary backup.
6. Record environment variables.
7. Record custom nodes.
8. Record binary data storage.
9. Restore into staging.
10. Validate workflows, credentials, webhooks, and schedules.
11. Plan DNS/webhook cutover.
12. Disable old triggers or ensure idempotency.
13. Cut over.
14. Monitor.
15. Keep rollback path until stable.
```

Interview version:

> “I would migrate state first, not just workflows. The database, encryption key, environment variables, binary data, and webhook cutover are the critical pieces.”

---

## Framework 2: The credential-safe migration answer

Use this when asked:

> “How do you make sure credentials survive migration?”

```text
1. Preserve the original encryption key.
2. Back up database.
3. Export credentials if needed.
4. Restore database and key together.
5. Use same key on main and workers.
6. Test representative credentials.
7. Reconnect OAuth credentials if callback domain changed.
8. Avoid exposing secrets in logs or Git.
9. Keep old instance until validation.
10. Document recovery process.
```

Interview version:

> “Credentials are encrypted state. Database plus encryption key must move together.”

---

## Framework 3: The webhook cutover answer

Use this when asked:

> “How do you migrate n8n webhooks safely?”

```text
1. Inventory active webhook workflows.
2. Identify external providers.
3. Configure new public URL.
4. Test production webhook URL.
5. Lower DNS TTL if using DNS cutover.
6. Disable old processing or make idempotent.
7. Update provider URLs or cut DNS.
8. Watch old and new logs.
9. Prevent duplicate processing.
10. Keep rollback path.
```

Interview version:

> “Webhook migration is integration cutover. The biggest risks are missed events and duplicate processing.”

---

## Framework 4: The queue mode migration answer

Use this when asked:

> “How would you migrate n8n to queue mode?”

```text
1. First stabilize single-node migration.
2. Use PostgreSQL.
3. Add Redis.
4. Configure EXECUTIONS_MODE=queue.
5. Start workers.
6. Use same encryption key everywhere.
7. Use same custom nodes everywhere.
8. Ensure shared binary storage if needed.
9. Tune concurrency gradually.
10. Monitor Redis, DB, and worker logs.
```

Interview version:

> “Queue mode is an architecture migration. Main, workers, Redis, database, binary storage, and encryption key must be consistent.”

---

## Framework 5: The rollback answer

Use this when asked:

> “How do you roll back an n8n migration?”

```text
1. Stop new processing.
2. Determine what new side effects happened.
3. Restore old DNS/webhook routing.
4. Re-enable old workflows if safe.
5. Restore database backup if needed.
6. Use original encryption key.
7. Reconcile duplicate or partial events.
8. Keep audit notes.
9. Fix root cause in staging.
10. Retry migration only after validation.
```

Interview version:

> “Rollback must account for state and side effects. It is not just restarting the old container.”

---

# Common n8n migration interview traps and better answers

## Trap 1: “Can we just export workflows and import them?”

Weak answer:

> “Yes.”

Better answer:

> “That may move workflow definitions, but a full migration also needs credentials, database state, encryption key, environment variables, binary data, custom nodes, webhooks, and validation.”

---

## Trap 2: “If workflows appear in the UI, is migration complete?”

Weak answer:

> “Yes.”

Better answer:

> “No. I would test credentials, triggers, webhooks, schedules, queue workers, binary workflows, and critical executions.”

---

## Trap 3: “Can we use a new encryption key?”

Weak answer:

> “Yes.”

Better answer:

> “Not if we need existing credentials to decrypt. The original encryption key must be preserved.”

---

## Trap 4: “Can old and new instances both stay active during cutover?”

Weak answer:

> “Yes, for safety.”

Better answer:

> “Only with careful design. If both process triggers, duplicate side effects can happen. I would control trigger ownership.”

---

## Trap 5: “Can we migrate and upgrade major versions at the same time?”

Weak answer:

> “Yes.”

Better answer:

> “I prefer not to. I would migrate like-for-like first, validate, then upgrade separately after reviewing breaking changes.”

---

## Trap 6: “Does database backup include binary files?”

Weak answer:

> “Yes.”

Better answer:

> “Not always. It depends on binary data storage mode. Files may be on filesystem or external storage.”

---

## Trap 7: “If OAuth credentials worked before, they will work after domain migration?”

Weak answer:

> “Yes.”

Better answer:

> “Not necessarily. OAuth redirect URIs and public URL/proxy settings must match the new domain.”

---

# n8n migration quick-reference table

| Issue | Main symptom | First thing to check | Common fix |
|---|---|---|---|
| Credential decrypt fail | Credentials unusable | Encryption key | Restore original key |
| Bad backup | Missing workflows/users | DB backup | Take/test consistent backup |
| SQLite to Postgres fail | New DB empty | DB migration path | Export/import or migrate carefully |
| Import overwrite | Existing objects changed | Exported IDs | Backup, adjust IDs |
| No credentials | Workflows import only | Credential export/import | Import/map credentials |
| Version mismatch | Migration errors | n8n version | Pin/test versions |
| Webhook URL change | No external triggers | Public webhook URL | Update DNS/providers |
| OAuth callback fail | Redirect mismatch | Public URL/OAuth app | Update callback/reconnect |
| Proxy issue | UI/webhook broken | Headers/routes | Fix reverse proxy |
| Binary missing | Files unavailable | Binary storage mode | Migrate volume/storage |
| Custom nodes missing | Unknown node type | Node packages | Install same nodes |
| Env vars missing | Different behavior | Env inventory | Copy Config/Secrets |
| Timezone changed | Schedules wrong | Timezone env | Set explicit timezone |
| Source control surprise | Variables/tags overwritten | Pull behavior | Review/map env config |
| Duplicate processing | Double side effects | Active triggers | Disable old/idempotency |
| Activation mismatch | Workflows not running | Active state | Verify activation |
| History too large | Slow migration | Execution data size | Archive/prune |
| Queue mode fail | Jobs stuck | Redis/workers/key | Align queue config |
| Redis issue | Workers idle | Redis connectivity | Fix Redis/auth/network |
| DB connection limit | Random DB errors | Postgres connections | Tune/scale DB/workers |
| Docker volume missing | Fresh instance | Volume mounts | Backup/restore volume |
| Kubernetes state missing | Pod starts fresh | PVC/Secrets | Restore PVC/Secrets |
| Permission denied | Cannot write files | UID/GID | Fix ownership/securityContext |
| CA/proxy missing | Internal APIs fail | Trust/proxy/DNS | Migrate CA/proxy config |
| IP allowlist fail | API 403 | Egress IP | Update allowlists |
| DNS split traffic | Old/new both receive | TTL/routing | Plan cutover |
| Shared DB active | Race/duplicates | Old/new DB usage | One active writer |
| Rollback fails | Cannot restore | Rollback plan | Test backup/DNS/key |
| v2 breakage | Workflows fail after upgrade | Migration report | Fix breaking changes |
| No validation | Hidden failures | Smoke tests | Run migration checklist |

---

# Strong closing takeaway

n8n migration interviews are not about saying “export and import.” They are about proving you understand n8n state, credentials, runtime configuration, and integration cutover.

A weak answer sounds like:

> “I would copy the workflows.”

A strong answer sounds like:

> “I would back up the database, preserve the encryption key, inventory environment variables, custom nodes, binary data, credentials, workflows, webhooks, schedules, and queue mode settings. Then I would restore into staging, validate critical workflows, cut over triggers carefully, monitor, and keep rollback available.”

n8n migration problems usually leave evidence in:

```text
Database connection logs
Credential decrypt/test errors
Webhook delivery logs
OAuth callback errors
n8n main logs
Worker logs
Redis logs
PostgreSQL logs
Execution history
Environment variable differences
Docker/Kubernetes volume mounts
Reverse proxy logs
```

When you freeze, return to this sequence:

```text
State → Database → Encryption key → Credentials → Workflows → Env vars → Binary data → Custom nodes → Webhooks → Cutover → Validate → Rollback
```

That sequence will carry you through most n8n migration interview questions.

---

# Final takeaway summaries

## The one-minute summary

n8n migration issues usually come from missing database backups, lost encryption keys, incomplete credential migration, SQLite-to-PostgreSQL mistakes, wrong versions, changed webhook URLs, OAuth callback issues, reverse proxy headers, missing binary data, custom nodes, environment variables, timezone differences, source control behavior, duplicate active triggers, queue mode misconfiguration, Redis, PostgreSQL connection limits, Docker volumes, Kubernetes Secrets/PVCs, file permissions, custom CAs, IP allowlists, DNS cutover, rollback gaps, and missing validation. The best answer starts by protecting state and testing restore.

## The senior-engineer summary

A senior n8n migration engineer understands that workflows are only one part of the system. The real migration risk is encrypted credentials, database state, runtime environment, webhooks, binary data, custom nodes, queue workers, Redis, PostgreSQL, and external integrations. Seniority is shown by testing restore before cutover, preventing duplicate side effects, preserving rollback, and validating critical workflows with known inputs.

## The interview survival summary

When your mind goes blank, say:

> “I would first identify what state must move: database, encryption key, credentials, workflows, users, environment variables, binary data, custom nodes, source control settings, and webhook URLs. Then I would back up, restore into staging, validate credentials and critical workflows, plan trigger cutover, monitor the new instance, and keep the old instance available for rollback until success is proven.”

That answer works across most n8n migration interview scenarios.
