# Grafana: “I Know This Stuff, But in the Interview I Freeze” Kit

## Strong intro

You can use Grafana every week and still freeze in an interview.

That freeze usually does not mean you lack observability experience. It means your knowledge is stored as real operational habits: checking data sources, fixing PromQL queries, adjusting time ranges, tracing missing labels, debugging alert rules, comparing dashboard variables, inspecting panel JSON, checking permissions, provisioning dashboards, and asking, “Is the data missing, or is Grafana just not querying it correctly?”

In production, Grafana is not just a dashboard tool. It is the front door to observability. It connects to metrics, logs, traces, SQL databases, cloud monitoring systems, alerting pipelines, and incident response workflows. If Grafana is wrong, people make wrong operational decisions. If Grafana is slow, incident response slows down. If alerts are noisy, teams stop trusting them.

This kit is built for that interview moment when you know Grafana but need clear, confident words.

It covers 30 common Grafana issues interviewers ask about, with symptoms, causes, diagnostic steps, resolutions, and examples. It is written for DevOps, SRE, platform, observability, infrastructure, and support engineers who want interview-ready explanations under pressure.

When you freeze, start with this sentence:

> “I would first identify whether the Grafana issue is data source connectivity, query syntax, time range, dashboard variable, panel transformation, permissions, provisioning, alert rule evaluation, notification routing, or backend performance. Then I would compare Explore results, panel query inspector output, data source health, Grafana logs, and the source system before changing the dashboard.”

That answer sounds like someone who can operate observability tooling safely.

---

## How to use this kit

For every Grafana issue, use this structure:

```text
Symptom → Scope → Query → Data source → Time range → Permissions → Cause → Fix → Verify
```

A strong Grafana interview answer usually includes:

1. What the user sees.
2. Whether it affects one panel, one dashboard, one folder, one data source, one org, or the whole instance.
3. Whether the issue is query, data source, variable, time range, permission, alerting, provisioning, or performance.
4. What evidence you check first.
5. What safe fix you apply.
6. How you verify the result.
7. How you prevent recurrence.

Example:

> “If a Grafana panel says No data, I would first test the same query in Explore, confirm the time range, inspect dashboard variables, check data source connectivity, and verify the metric or log exists in the backend.”

That is much stronger than saying:

> “I would refresh the dashboard.”

Refresh is an action. Diagnosis is engineering.

---

# Top 30 Grafana issues and resolutions

---

## 1. Panel shows “No data”

### Interview freeze point

The interviewer asks:

> “A Grafana panel shows No data. What do you check?”

A weak answer is “check Prometheus.” A strong answer separates query, time range, variables, and data source.

### Strong interview answer

> “I would check whether the data exists in the source, whether the panel query is valid, whether the time range includes data, whether dashboard variables resolve correctly, and whether the panel uses transformations or thresholds that hide results.”

### Symptoms

- Panel says `No data`.
- Explore shows data but panel does not.
- Panel worked yesterday.
- Only one environment or variable selection fails.
- Alert rule based on panel never fires.

### Diagnostic checklist

```text
Does the data source test succeed?
Does the query work in Explore?
Is the dashboard time range correct?
Do variables resolve to valid values?
Is the query using the right labels?
Are transformations filtering results?
Is the panel using a different data source than expected?
```

### Prometheus example

Panel query:

```promql
rate(http_requests_total{job="$job"}[5m])
```

If `$job` resolves to an empty value or wrong job label, the panel returns no data.

### Debug variable

In the dashboard, inspect the variable preview. Confirm it returns values such as:

```text
api
worker
frontend
```

### Fix

- Test query in Explore.
- Replace variables temporarily with fixed values.
- Widen the time range.
- Check metric name and labels.
- Remove transformations temporarily.
- Confirm the correct data source is selected.

### Verify

```text
Explore returns series.
Panel query inspector shows successful response.
Dashboard variable preview contains expected values.
Panel displays data for known active time range.
```

### Takeaway summary

“No data” does not always mean the system has no data. It often means query, time range, variable, or data source mismatch.

---

## 2. Data source connection error

### Interview freeze point

Grafana cannot query Prometheus, Loki, Elasticsearch, CloudWatch, PostgreSQL, or another source.

### Strong interview answer

> “I would test the data source in Grafana, then check URL, authentication, TLS, network reachability from the Grafana server, proxy settings, and permissions in the backing system.”

### Symptoms

- Data source test fails.
- Panels show connection error.
- Explore cannot query.
- HTTP 401, 403, 502, 503, or TLS error.
- Works from laptop but not from Grafana.
- Only one data source fails.

### Diagnostic checklist

```text
Can Grafana reach the data source URL?
Is the URL correct from the Grafana server, not my laptop?
Is authentication valid?
Is TLS trusted?
Is a proxy required?
Are firewall or NetworkPolicy rules blocking it?
Does the data source require org/project/tenant headers?
```

### Example Prometheus data source URL

Inside Kubernetes:

```text
http://prometheus-server.monitoring.svc.cluster.local:9090
```

From outside Kubernetes, this may not work. From inside Grafana pod, it may.

### Test from Grafana pod

```bash
kubectl exec -it deploy/grafana -n monitoring -- sh
wget -qO- http://prometheus-server.monitoring.svc.cluster.local:9090/-/ready
```

### Common causes

- Wrong URL.
- Data source reachable from browser but not Grafana backend.
- TLS certificate not trusted.
- Token expired.
- Wrong tenant header.
- Firewall blocks Grafana.
- Kubernetes service name wrong.
- Cloud IAM permission missing.
- Proxy misconfigured.

### Resolution

- Fix URL.
- Fix authentication.
- Add trusted CA or correct TLS setting.
- Fix network policy/firewall.
- Test from the Grafana runtime environment.
- Use provisioning for repeatable data source config.

### Takeaway summary

Data source connectivity must be tested from Grafana’s backend, not just from your browser.

---

## 3. Dashboard is slow

### Interview freeze point

The dashboard loads, but it is painful during incidents.

### Strong interview answer

> “I would check panel count, query complexity, time range, refresh interval, series cardinality, variable queries, transformations, browser load, and data source performance. Slow dashboards are often caused by too many expensive queries over too much data.”

### Symptoms

- Dashboard takes a long time to load.
- Browser freezes.
- Grafana server CPU rises.
- Data source CPU rises.
- Query timeout.
- Incident dashboard unusable.

### Common causes

- Too many panels.
- Too many time series.
- Expensive PromQL or LogQL.
- Long time range.
- Auto-refresh too frequent.
- Variables query huge label sets.
- Transformations run on large result sets.
- Table panel returns too many rows.
- Backend data source slow.

### Example bad PromQL

```promql
rate(http_requests_total[5m])
```

This may return every label combination.

Better with aggregation:

```promql
sum by (service) (rate(http_requests_total[5m]))
```

### Reduce dashboard load

```text
Reduce panel count.
Aggregate high-cardinality series.
Use shorter default time range.
Avoid 5s refresh unless needed.
Use recording rules for expensive PromQL.
Limit table rows.
Simplify variables.
```

### Grafana query inspector

Use panel query inspector to see:

```text
Query duration
Returned data size
Response status
Raw query
```

### Takeaway summary

A slow dashboard is usually query/cardinality/time-range/refresh pressure. Optimize the dashboard and the data source query.

---

## 4. Dashboard refresh interval overloads backend

### Interview freeze point

A team sets dashboard refresh to 5 seconds and Prometheus starts suffering.

### Strong interview answer

> “I would check dashboard refresh interval, number of viewers, number of panels, and query cost. Refreshing many expensive panels too frequently can overload Grafana and the data source.”

### Symptoms

- Prometheus or Loki CPU spikes.
- Grafana becomes slow.
- Dashboards used in NOC screens overload backend.
- Query rate increases during incidents.
- Browser tabs left open generate load.

### Example

Dashboard has:

```text
30 panels
10 users
Refresh every 5 seconds
```

That can create hundreds of queries per minute.

### Resolution

- Increase refresh interval.
- Use dashboard-level defaults like 30s, 1m, or 5m.
- Use recording rules.
- Reduce panel count.
- Use lower-cost queries.
- Disable auto-refresh on heavy dashboards.
- Use caching/proxy features where appropriate.
- Educate users not to leave high-refresh dashboards open unnecessarily.

### Good default

```text
Refresh: 1m
Time range: last 1h
```

For high-level dashboards, this is often enough.

### Takeaway summary

Dashboard refresh rate is an operational setting. Too-frequent refresh can become a production load problem.

---

## 5. Wrong time range

### Interview freeze point

The data exists, but Grafana does not show it because the time window is wrong.

### Strong interview answer

> “I would check dashboard time range, panel time override, query relative time, timezone, and whether the source data timestamps are correct.”

### Symptoms

- Explore shows data in one range but not another.
- Panel says No data.
- Alert appears missing.
- Recent deployment marker not visible.
- Logs appear outside expected time.
- Users in different timezones see confusing times.

### Common causes

- Dashboard set to last 5 minutes.
- Event happened outside selected range.
- Panel has time override.
- Browser timezone differs from UTC.
- Source timestamps wrong.
- Logs ingested late.
- Query uses offset.

### Panel override example

A panel may have:

```text
Relative time: 24h
Time shift: 1w
```

This can make it differ from the dashboard time range.

### PromQL offset example

```promql
rate(http_requests_total[5m] offset 1h)
```

This intentionally queries old data.

### Resolution

- Widen time range.
- Remove panel time override.
- Check dashboard timezone.
- Check source timestamps.
- Compare in Explore.
- Verify ingestion delay.

### Takeaway summary

Always confirm time range and timezone before assuming the data is missing.

---

## 6. Dashboard variable returns wrong values

### Interview freeze point

The dashboard works for one selection but not another.

### Strong interview answer

> “I would inspect the variable query, preview values, selected value, multi-value behavior, all-value behavior, and whether the panel query handles regex or exact matching correctly.”

### Symptoms

- Variable dropdown empty.
- `$service` or `$namespace` returns wrong data.
- Multi-select breaks panel.
- “All” returns no data.
- Variable works in one panel but not another.
- Query uses wrong label.

### Example variable query for Prometheus

```promql
label_values(up, job)
```

Panel query:

```promql
up{job="$job"}
```

If multi-value is enabled, exact match may fail.

### Multi-value-safe query

```promql
up{job=~"$job"}
```

### Common causes

- Variable query wrong.
- Regex filters out values.
- Multi-value not handled with `=~`.
- All value not configured.
- Variable refresh too infrequent.
- Variable depends on another variable.
- Label name changed.
- Data source changed.

### Debug

```text
Dashboard settings → Variables → Preview values
```

Temporarily replace variable with fixed value:

```promql
up{job="api"}
```

### Takeaway summary

Variable bugs are often regex, multi-select, all-value, or label mismatch problems.

---

## 7. Prometheus query returns too many series

### Interview freeze point

The panel works but is unreadable or slow.

### Strong interview answer

> “I would check label cardinality and aggregate the query to the level the dashboard actually needs. Grafana should not render thousands of raw series unless that is intentional.”

### Bad query

```promql
rate(http_requests_total[5m])
```

This may return per instance, method, status, path, pod, container, and more.

### Better query

```promql
sum by (service) (rate(http_requests_total[5m]))
```

Or for error rate:

```promql
sum by (service) (rate(http_requests_total{status=~"5.."}[5m]))
/
sum by (service) (rate(http_requests_total[5m]))
```

### Symptoms

- Panel legend has hundreds or thousands of lines.
- Browser slow.
- Query timeout.
- Dashboard hard to read.
- Alert too noisy.

### Common causes

- No aggregation.
- High-cardinality labels such as `path`, `pod`, `container_id`, `user_id`.
- Too-long time range.
- Too-frequent scrape or query.
- Querying raw metrics instead of recording rules.

### Resolution

- Aggregate with `sum by`, `avg by`, `max by`.
- Drop noisy labels in query.
- Avoid high-cardinality labels in metrics design.
- Use recording rules.
- Use topk for focused views:

```promql
topk(10, sum by (pod) (rate(container_cpu_usage_seconds_total[5m])))
```

### Takeaway summary

Prometheus plus Grafana can return too much data. Aggregate to the decision level.

---

## 8. PromQL rate query looks wrong

### Interview freeze point

The graph shows spikes, gaps, or zero when traffic exists.

### Strong interview answer

> “I would check whether the metric is a counter or gauge, whether `rate` or `increase` is appropriate, whether the range window is long enough relative to scrape interval, and whether labels are aggregated correctly.”

### Counter example

Metric:

```text
http_requests_total
```

Use:

```promql
rate(http_requests_total[5m])
```

### Gauge example

Metric:

```text
memory_usage_bytes
```

Do not use `rate()` for current memory usage. Use:

```promql
memory_usage_bytes
```

### Common causes

- Using `rate` on a gauge.
- Range window too short.
- Scrape interval too long.
- Counter resets.
- Missing aggregation.
- Low traffic causes sparse data.
- Query step too coarse.
- Dashboard resolution settings.

### Example

If scrape interval is 60s, this is often too short:

```promql
rate(http_requests_total[1m])
```

Better:

```promql
rate(http_requests_total[5m])
```

### Takeaway summary

Use `rate` for counters, not gauges. Choose a range window that makes sense for scrape interval and traffic volume.

---

## 9. Logs missing in Loki panel

### Interview freeze point

Application logs exist in Kubernetes, but Grafana/Loki does not show them.

### Strong interview answer

> “I would check whether logs are being collected, labeled, shipped to Loki, retained, and queried with the correct label selectors and time range.”

### Symptoms

- Explore shows no logs.
- Only some pods have logs.
- Logs visible with `kubectl logs` but not Grafana.
- Query returns old logs only.
- Labels differ from expected.
- Loki query times out.

### Example LogQL query

```logql
{namespace="prod", app="api"}
```

Filter:

```logql
{namespace="prod", app="api"} |= "error"
```

### Common causes

- Promtail/agent not scraping pod.
- Labels differ.
- Namespace wrong.
- Log stream not shipped.
- Loki tenant mismatch.
- Retention expired.
- Time range wrong.
- Query too broad.
- Pod restarted and logs rotated.
- Ingestion pipeline dropped logs.

### Diagnostic checklist

```text
Does kubectl logs show logs?
Does agent show scrape/shipping errors?
Do labels exist in Loki?
Does Explore label browser show namespace/app?
Is time range correct?
Is tenant/header correct?
```

### Takeaway summary

For Loki, missing logs are usually collection, labels, tenant, retention, or time range issues.

---

## 10. Panel transformation hides data

### Interview freeze point

The query returns data, but the panel displays nothing or wrong fields.

### Strong interview answer

> “I would inspect the raw query result before transformations, then disable transformations one by one. Transformations can filter, join, rename, reduce, or drop fields.”

### Symptoms

- Explore shows data.
- Panel query inspector shows data.
- Panel shows no rows.
- Table columns missing.
- Values are renamed unexpectedly.
- Alert based on transformed panel behaves differently than expected.

### Common transformations

```text
Filter fields
Join by field
Merge
Organize fields
Reduce
Group by
Labels to fields
Outer join
```

### Diagnostic steps

```text
Open panel edit.
Check Query tab.
Check Transform tab.
Disable transformations temporarily.
Inspect raw data.
Add transformations back one at a time.
```

### Common causes

- Field renamed before later transform.
- Join key missing.
- Reduce removes series dimension.
- Filter excludes all fields.
- Transformation order wrong.
- Query format changed.

### Resolution

- Simplify transformations.
- Move logic into query when possible.
- Rename fields consistently.
- Add tests/screenshots for important dashboards.
- Use Query Inspector to compare raw vs transformed.

### Takeaway summary

If Explore works but the panel does not, check transformations.

---

## 11. Alert rule does not fire

### Interview freeze point

The dashboard shows a problem, but the alert stays normal.

### Strong interview answer

> “I would check the alert rule query, evaluation interval, condition, reduce expression, threshold, no-data behavior, error behavior, labels, and whether dashboard variables are being used incorrectly.”

### Symptoms

- Panel shows high error rate.
- Alert state remains Normal.
- Alert preview value does not cross threshold.
- Alert says No Data.
- Alert works manually but not during incident.
- Alert uses different query than panel.

### Important concept

Grafana alert rules evaluate on the backend. They do not always have the same dashboard context as a panel, especially around dashboard variables.

### Example alert query

```promql
sum(rate(http_requests_total{status=~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))
```

Condition:

```text
WHEN last() OF query(A) IS ABOVE 0.05
```

### Common causes

- Query differs from panel.
- Reduce expression wrong.
- Threshold wrong.
- Evaluation interval too long.
- For duration not met.
- No-data state configured as OK.
- Dashboard variable not resolved.
- Data source error state configured incorrectly.
- Alert rule paused.
- Contact point/routing issue mistaken for rule issue.

### Debug

```text
Use alert rule Preview.
Check evaluated value.
Check rule state history.
Check query without dashboard variables.
```

### Takeaway summary

Alert debugging starts with the evaluated alert rule, not the dashboard panel.

---

## 12. Alert fires too often

### Interview freeze point

The team complains about noisy alerts.

### Strong interview answer

> “I would check threshold, evaluation interval, for duration, grouping, notification policy, labels, missing data behavior, and whether the alert is based on symptoms that matter.”

### Symptoms

- Alert flaps.
- Pager fatigue.
- Same incident sends many notifications.
- Alert resolves and fires repeatedly.
- Alerts fire for short spikes.
- Too many label combinations create many alert instances.

### Example noisy alert

```promql
rate(http_requests_total{status=~"5.."}[1m]) > 0
```

This fires on any error.

### Better

```promql
(
  sum(rate(http_requests_total{status=~"5.."}[5m]))
  /
  sum(rate(http_requests_total[5m]))
) > 0.05
```

Add `for` duration:

```text
For: 10m
```

### Common causes

- Threshold too sensitive.
- No `for` duration.
- High-cardinality labels.
- Alert per pod instead of per service.
- No grouping in notification policy.
- Missing-data handling wrong.
- Alerting on cause instead of user impact.
- No SLO/error budget thinking.

### Resolution

- Alert on service-level symptoms.
- Add `for` duration.
- Aggregate labels.
- Group notifications.
- Tune thresholds with history.
- Use warning vs critical levels carefully.
- Remove low-value alerts.

### Takeaway summary

Good alerts are actionable, stable, and routed correctly. Noise is an alert design bug.

---

## 13. Notification not sent

### Interview freeze point

The alert fires, but nobody gets notified.

### Strong interview answer

> “I would separate alert evaluation from notification routing. If the rule is firing, I would check contact points, notification policies, labels, mute timings, silences, and integration delivery errors.”

### Symptoms

- Alert state is Firing.
- No Slack/PagerDuty/email message.
- Notification sent to wrong team.
- Alert appears silenced.
- Contact point test works but real alert does not.
- Notification policy does not match labels.

### Diagnostic checklist

```text
Is alert rule firing?
Which labels does it have?
Which notification policy matches?
Is there a mute timing?
Is there a silence?
Is contact point enabled?
Any delivery errors?
```

### Example labels

```yaml
team: platform
severity: critical
service: api
```

Notification policy may route:

```text
team=platform → Platform PagerDuty
severity=warning → Slack only
```

### Common causes

- Label mismatch.
- Alert routed to default policy.
- Contact point disabled.
- Mute timing active.
- Silence active.
- Integration token expired.
- Webhook URL wrong.
- Email SMTP misconfigured.
- Notification grouping delay.

### Takeaway summary

A firing alert and a delivered notification are different stages. Check routing and contact points.

---

## 14. Alert notification goes to wrong team

### Interview freeze point

The alert fires and notifies, but the wrong people get paged.

### Strong interview answer

> “I would check alert labels and notification policy matchers. Routing should be label-driven and tested with realistic labels.”

### Example alert labels

```yaml
service: checkout
team: payments
severity: critical
```

Policy:

```text
team=payments → Payments on-call
team=platform → Platform on-call
```

### Common causes

- Missing `team` label.
- Wrong team label.
- Default route catches alert.
- Matchers too broad.
- Nested notification policies ordered incorrectly.
- Alert created manually without labels.
- Label changed in query.
- Multi-dimensional alert creates unexpected labels.

### Resolution

- Standardize alert labels.
- Require `team`, `service`, and `severity`.
- Test routing.
- Create catch-all policy that is visible but not noisy.
- Review notification policy order.
- Use folder/team ownership.

### Takeaway summary

Alert routing is only as good as alert labels. Standardize labels before scaling alerting.

---

## 15. Dashboard permissions issue

### Interview freeze point

A user cannot see or edit a dashboard.

### Strong interview answer

> “I would check organization, folder permissions, dashboard permissions, team membership, role, data source permissions, and whether the dashboard is in the expected folder.”

### Symptoms

- User sees 403.
- Dashboard missing from search.
- User can view but not edit.
- User can see dashboard but panel queries fail.
- Team has access in one folder but not another.
- Admin can see everything.

### Common permission layers

```text
Organization role
Folder permissions
Dashboard permissions
Team membership
Data source permissions
Service account permissions
Grafana Cloud stack/org access
```

### Resolution

- Add user to correct team.
- Grant folder-level permission instead of per-dashboard sprawl.
- Check data source access.
- Avoid giving Admin just to fix view issue.
- Use teams/groups from SSO where possible.
- Document folder ownership.

### Takeaway summary

Grafana permissions are layered. Check folder, dashboard, team, role, and data source access.

---

## 16. Data source permissions issue

### Interview freeze point

The dashboard opens, but queries fail for one user.

### Strong interview answer

> “I would check whether the user has permission to query the data source. Dashboard access does not always mean data source query access.”

### Symptoms

- User can open dashboard but panel errors.
- Query works for admin.
- Explore data source hidden.
- Data source permission denied.
- Service account cannot query.

### Common causes

- Data source permissions restrict query access.
- User not in correct team.
- Folder permission granted but data source permission missing.
- Organization mismatch.
- Cloud role mismatch.
- Service account token lacks permission.

### Resolution

- Grant data source query permission to team.
- Use team-based access.
- Check service account permissions for automation.
- Avoid broad Admin grants.
- Confirm with user impersonation/test account if possible.

### Takeaway summary

Dashboard permission and data source permission are separate concerns.

---

## 17. Provisioned dashboard cannot be edited permanently

### Interview freeze point

A user edits a dashboard, but changes disappear after restart or provisioning sync.

### Strong interview answer

> “I would check whether the dashboard is provisioned from files. Provisioned dashboards are managed as code, so UI edits may be overwritten unless changes are made in the source file.”

### Symptoms

- Dashboard changes disappear.
- UI says dashboard is provisioned.
- Save disabled or warning appears.
- Restart reverts dashboard.
- GitOps process overwrites changes.

### Provisioning concept

Grafana can provision dashboards and data sources from configuration files. This is useful for version-controlled dashboards and repeatable environments.

### Example dashboard provider

```yaml
apiVersion: 1

providers:
  - name: default
    folder: "Platform"
    type: file
    options:
      path: /var/lib/grafana/dashboards
```

### Common causes

- Dashboard managed by file provisioning.
- GitOps sync overwrites UI edits.
- Dashboard UID collision.
- Multiple providers manage same dashboard.
- File path mounted read-only.
- User expects UI changes to persist.

### Resolution

- Edit dashboard JSON/source file.
- Commit through Git.
- Re-provision.
- For experimental dashboards, create non-provisioned copy.
- Document dashboard ownership model.

### Takeaway summary

If a dashboard is provisioned, the source of truth is the file or Git repo, not the UI.

---

## 18. Provisioned data source not updating

### Interview freeze point

A data source YAML was changed, but Grafana still uses old settings.

### Strong interview answer

> “I would check provisioning file location, syntax, version, secureJsonData behavior, container mount, Grafana logs, and whether a restart or reload is required.”

### Example provisioning file

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
```

### Common causes

- File not mounted into Grafana.
- YAML syntax wrong.
- Grafana not restarted/reloaded.
- Data source name/UID mismatch.
- Secure fields not updated as expected.
- Provisioning file in wrong directory.
- Multiple provisioning files conflict.
- Environment variable not expanded as expected.

### Diagnostic

Check Grafana logs for provisioning messages.

Docker/Kubernetes:

```bash
kubectl logs deploy/grafana -n monitoring
```

Check mounted file:

```bash
kubectl exec -it deploy/grafana -n monitoring -- cat /etc/grafana/provisioning/datasources/datasource.yaml
```

### Takeaway summary

Provisioning problems are usually file path, syntax, mount, restart, UID/name, or secure field behavior.

---

## 19. Dashboard UID conflict

### Interview freeze point

Importing or provisioning dashboards overwrites another dashboard.

### Strong interview answer

> “I would check dashboard UID. Grafana uses UIDs as stable identifiers. If two dashboards share a UID, imports or provisioning can update the wrong dashboard.”

### Symptoms

- Imported dashboard replaces existing dashboard.
- Links go to wrong dashboard.
- Provisioning overwrites a dashboard.
- Dashboard title differs but UID same.
- Git dashboards conflict.

### Dashboard JSON example

```json
{
  "uid": "service-overview",
  "title": "Service Overview"
}
```

### Common causes

- Copying dashboard JSON without changing UID.
- Importing community dashboard with same UID.
- Multiple teams reuse template UID.
- Provisioning same UID in multiple folders.
- Git branch conflict.

### Resolution

- Use unique UIDs.
- Decide UID naming convention.
- Remove UID before import if you want Grafana to generate one.
- Keep UIDs stable for dashboards that are linked.
- Avoid duplicate dashboard providers managing same UID.

### Takeaway summary

Dashboard UID is identity. Duplicate UIDs create overwrite and linking problems.

---

## 20. Dashboard import fails

### Interview freeze point

A dashboard JSON from another instance or Grafana.com does not import cleanly.

### Strong interview answer

> “I would check data source mapping, plugin requirements, Grafana version compatibility, dashboard UID, folder permissions, and whether the JSON includes instance-specific IDs.”

### Symptoms

- Import error.
- Panels show missing data source.
- Plugin visualization missing.
- Variables broken.
- Dashboard imports but panels fail.
- JSON model error.

### Common causes

- Missing data source.
- Data source UID differs.
- Required plugin not installed.
- Dashboard built for newer Grafana.
- Old panel plugin deprecated.
- UID conflict.
- Folder permission missing.
- JSON edited manually and invalid.

### Resolution

- Install required plugins.
- Map data sources during import.
- Update data source UIDs.
- Remove or change dashboard UID if needed.
- Validate JSON.
- Test imported dashboard in staging first.
- Prefer provisioning for repeatable imports.

### Takeaway summary

Dashboard import is not only JSON. It also depends on data sources, plugins, UIDs, and Grafana version.

---

## 21. Grafana login or SSO issue

### Interview freeze point

Users cannot log in after SSO/OAuth/SAML change.

### Strong interview answer

> “I would check the identity provider config, callback URL, client ID/secret, scopes, group mapping, allowed domains, Grafana server root URL, and logs.”

### Symptoms

- Login loop.
- OAuth callback error.
- User gets wrong role.
- Groups not mapped.
- Admin locked out.
- Works for some users but not others.

### Common causes

- Wrong callback URL.
- `root_url` wrong behind proxy.
- Client secret rotated.
- Scope missing.
- Group claim not sent.
- Role mapping wrong.
- Allowed domain restriction.
- TLS/proxy issue.
- Clock skew.

### Example config concept

```ini
[server]
root_url = https://grafana.example.com/

[auth.generic_oauth]
enabled = true
client_id = ...
client_secret = ...
scopes = openid profile email
```

### Resolution

- Check Grafana logs.
- Check IdP app redirect URI.
- Verify root URL and proxy headers.
- Confirm claims in token.
- Keep break-glass admin access.
- Test with non-admin user.

### Takeaway summary

SSO issues are usually callback URL, root URL, scopes, claims, or role mapping problems.

---

## 22. Grafana behind reverse proxy has wrong links

### Interview freeze point

Grafana works internally but breaks externally.

### Strong interview answer

> “I would check `root_url`, `serve_from_sub_path`, proxy headers, TLS termination, path rewrites, and WebSocket support if live features are affected.”

### Symptoms

- Links point to localhost.
- Login redirects incorrectly.
- Static assets fail.
- Grafana under `/grafana` path breaks.
- OAuth callback wrong.
- WebSocket/live features fail.

### Example root URL

```ini
[server]
root_url = https://example.com/grafana/
serve_from_sub_path = true
```

### Nginx headers concept

```nginx
proxy_set_header Host $host;
proxy_set_header X-Forwarded-Proto https;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
```

### Common causes

- `root_url` wrong.
- Missing forwarded headers.
- Subpath not configured.
- Proxy strips path incorrectly.
- TLS terminated but Grafana thinks HTTP.
- OAuth callback uses wrong scheme.
- CDN/proxy caching static assets incorrectly.

### Takeaway summary

Grafana must know its public URL. Reverse proxy settings affect login, links, OAuth, and assets.

---

## 23. Plugin missing or unsigned plugin issue

### Interview freeze point

A dashboard panel or data source depends on a plugin.

### Strong interview answer

> “I would check whether the plugin is installed, compatible with the Grafana version, signed or allowed if unsigned, and available on all Grafana instances.”

### Symptoms

- Panel says plugin not found.
- Data source type missing.
- Plugin fails after upgrade.
- Dashboard import has unknown panel.
- Grafana logs plugin signature error.
- HA instances behave differently.

### Common causes

- Plugin not installed.
- Plugin version incompatible.
- Unsigned plugin blocked.
- Plugin installed on one pod but not others.
- Plugin directory not persistent.
- Grafana upgrade broke old plugin.
- Enterprise plugin license missing.

### Install plugin example

```bash
grafana-cli plugins install grafana-piechart-panel
```

In container/Kubernetes, prefer baking plugin into image or using controlled plugin install config.

### Resolution

- Install required plugin.
- Pin plugin version if needed.
- Use signed/maintained plugins.
- Restart Grafana.
- Ensure all replicas have the plugin.
- Test after Grafana upgrades.

### Takeaway summary

Dashboards depend on plugins. Manage plugin versions like application dependencies.

---

## 24. Grafana database issue

### Interview freeze point

Grafana starts but loses dashboards/users, or HA behaves inconsistently.

### Strong interview answer

> “I would check which database Grafana uses. SQLite may be fine for small single-node setups, but production or HA deployments should use an external database such as PostgreSQL or MySQL.”

### Symptoms

- Dashboards disappear after pod restart.
- Users missing.
- Multiple replicas inconsistent.
- Database locked errors.
- Upgrade migration fails.
- Provisioned dashboards exist but UI-created dashboards vanish.

### Common causes

- SQLite stored on ephemeral disk.
- No persistent volume.
- Multiple Grafana replicas using local SQLite.
- External database credentials wrong.
- DB migration failed.
- DB connection limit reached.
- Backup missing.

### Example PostgreSQL config concept

```ini
[database]
type = postgres
host = postgres:5432
name = grafana
user = grafana
password = ...
```

### Resolution

- Use persistent storage for single-node SQLite.
- Use PostgreSQL/MySQL for HA.
- Back up Grafana DB.
- Test DB migrations before upgrades.
- Monitor DB connectivity.
- Keep provisioning for reproducible dashboards/data sources.

### Takeaway summary

Grafana state lives in its database unless provisioned. Protect it and choose the right backend for your topology.

---

## 25. Grafana upgrade breaks dashboards or alerting

### Interview freeze point

After upgrade, dashboards or alert rules behave differently.

### Strong interview answer

> “I would check release notes, plugin compatibility, database migration logs, dashboard JSON changes, alerting changes, and test the upgrade in staging with a database copy.”

### Symptoms

- Grafana fails to start.
- Plugin broken.
- Dashboard panel changed.
- Alert rules behave differently.
- Provisioning errors.
- Database migration error.
- SSO broken.

### Common causes

- Major version change.
- Plugin incompatibility.
- Deprecated panel/plugin.
- Alerting behavior changed.
- Database migration issue.
- Config option renamed.
- Custom image missing plugins.

### Safe upgrade approach

```text
Back up database.
Back up provisioning files.
Record Grafana version and plugins.
Test upgrade in staging.
Check logs.
Validate critical dashboards and alerts.
Upgrade production.
Monitor.
Keep rollback plan.
```

### Docker image pinning

Bad:

```yaml
image: grafana/grafana:latest
```

Better:

```yaml
image: grafana/grafana:11.5.0
```

Use the version appropriate to your environment.

### Takeaway summary

Grafana upgrades are production changes. Test dashboards, plugins, alerting, and database migration first.

---

## 26. Too many users have Admin access

### Interview freeze point

The instance works but governance is weak.

### Strong interview answer

> “I would review organization roles, folder permissions, teams, service accounts, and SSO role mapping. Admin should be limited; most users need Viewer or Editor plus folder-level permissions.”

### Symptoms

- Users can edit critical dashboards.
- Data sources changed accidentally.
- Alerts modified without review.
- Service account has broad Admin.
- Auditing unclear.
- Teams bypass folder ownership.

### Common causes

- Everyone made Admin to fix access quickly.
- No team-based permissions.
- SSO maps broad group to Admin.
- Service accounts over-privileged.
- Folder permissions not used.
- No dashboard ownership model.

### Safer pattern

```text
Admins: platform/observability team only
Editors: service owners in owned folders
Viewers: broad read-only access
Service accounts: scoped to automation need
```

### Resolution

- Audit Admin users.
- Move to team-based access.
- Use folder permissions.
- Scope service account tokens.
- Review SSO role mapping.
- Use provisioning/Git for controlled changes.

### Takeaway summary

Grafana Admin access controls dashboards, data sources, and alerts. Limit it.

---

## 27. Service account token problem

### Interview freeze point

Automation that provisions dashboards or calls Grafana API fails.

### Strong interview answer

> “I would check token scope, service account role, organization, expiration, API URL, and whether the token was rotated or revoked.”

### Symptoms

- API returns 401 or 403.
- Terraform Grafana provider fails.
- Dashboard provisioning script fails.
- Token worked before.
- Automation affects wrong organization.
- Token expired.

### API example

```bash
curl -H "Authorization: Bearer $GRAFANA_TOKEN" \
  https://grafana.example.com/api/search
```

### Common causes

- Token expired.
- Token revoked.
- Service account lacks role.
- Wrong Grafana org.
- Wrong URL.
- SSO user token used instead of service account.
- Secret not updated in CI.
- Network/proxy issue.

### Resolution

- Rotate token.
- Scope service account role.
- Store token in secret manager.
- Test with simple API call.
- Avoid using personal tokens for automation.
- Document owner and expiry.

### Takeaway summary

Service account tokens should be scoped, rotated, and tested with the Grafana API.

---

## 28. Dashboard JSON too hard to manage

### Interview freeze point

Teams want dashboards as code, but JSON is large and noisy.

### Strong interview answer

> “I would use provisioning and version control, but I would also consider dashboard-as-code tooling or templates when raw dashboard JSON becomes hard to review.”

### Symptoms

- Dashboard PRs are huge.
- Small UI change creates massive JSON diff.
- Teams overwrite each other.
- UID conflicts.
- Reviewers cannot understand dashboard changes.
- Git history is noisy.

### Common approaches

```text
Provision raw JSON.
Use Jsonnet/Grafonnet.
Use Terraform provider.
Use custom generation scripts.
Use dashboard export/import with review process.
```

### Provisioning example

```yaml
apiVersion: 1

providers:
  - name: platform
    folder: Platform
    type: file
    options:
      path: /var/lib/grafana/dashboards/platform
```

### Resolution

- Define dashboard ownership.
- Keep stable UIDs.
- Use folders by team/service.
- Use dashboard-as-code where helpful.
- Review important dashboard changes.
- Avoid editing provisioned dashboards directly in UI.

### Takeaway summary

Dashboard-as-code is valuable, but raw JSON can be noisy. Choose a workflow teams can review.

---

## 29. Alerting provisioning mismatch

### Interview freeze point

Alerting resources are provisioned, but UI changes or API changes do not behave as expected.

### Strong interview answer

> “I would check whether alert rules, contact points, notification policies, and templates are managed by file provisioning, API provisioning, Terraform, or UI. Mixing sources of truth can cause drift.”

### Symptoms

- Alert UI changes disappear.
- Provisioned alert cannot be edited as expected.
- Contact point differs after restart.
- Notification policy overwritten.
- Terraform fights UI.
- File provisioning and API output do not match.

### Common causes

- Multiple sources manage same resource.
- File provisioning overwrites UI changes.
- Terraform state drift.
- Alert rule UID conflict.
- Contact point secret values handled differently.
- Grafana-managed vs data source-managed alert rules confused.

### Resolution

- Decide source of truth.
- Use file provisioning or Terraform consistently.
- Avoid manual UI edits to managed resources.
- Use unique UIDs.
- Review provisioning logs.
- Export/backup alerting resources before migration.
- Document ownership.

### Takeaway summary

Alerting must have a clear source of truth. Mixing UI, files, API, and Terraform creates drift.

---

## 30. Poor observability dashboard design

### Interview freeze point

This tests senior-level Grafana thinking.

### Strong interview answer

> “A good Grafana dashboard should answer operational questions quickly. It should not be a wall of every metric. I would design dashboards around service health, user impact, saturation, errors, latency, throughput, and drill-down paths.”

### Symptoms

- Dashboard has too many panels.
- Nobody knows what to look at.
- Panels are decorative, not actionable.
- No ownership.
- No links to logs/traces.
- No thresholds.
- Alerts do not match dashboard.
- Dashboards are slow and noisy.

### Better dashboard structure

```text
Top row: service health summary
Golden signals: latency, traffic, errors, saturation
Dependency health
Recent deploy annotations
Links to logs and traces
Drill-down panels
Owner and runbook links
```

### Example useful panels

```text
Request rate by service
5xx error percentage
p95/p99 latency
CPU/memory saturation
Queue depth
Error logs by service
Recent deployments
Alert list
```

### Design principles

```text
Start with questions.
Aggregate for overview.
Drill down only when needed.
Use consistent labels and units.
Set useful thresholds.
Avoid high-cardinality chaos.
Keep dashboards fast.
Add owner/runbook links.
```

### Takeaway summary

Good dashboards support decisions during incidents. They should be fast, focused, and owned.

---

# Bonus: Grafana interview answer frameworks

## Framework 1: The “No data” answer

Use this when asked:

> “A Grafana panel shows No data. What do you do?”

```text
1. Check dashboard time range.
2. Check panel query.
3. Run query in Explore.
4. Check data source health.
5. Check variables.
6. Check labels and metric/log name.
7. Check transformations.
8. Check permissions.
9. Compare with source system.
10. Fix and verify.
```

Interview version:

> “I separate data absence from query absence. First I prove whether the source has data, then I prove whether Grafana is asking for it correctly.”

---

## Framework 2: The slow dashboard answer

Use this when asked:

> “A Grafana dashboard is slow. How do you troubleshoot?”

```text
1. Check number of panels.
2. Check query inspector.
3. Check time range.
4. Check refresh interval.
5. Check series cardinality.
6. Check variable queries.
7. Check transformations.
8. Check data source performance.
9. Optimize queries or add recording rules.
10. Reduce dashboard load.
```

Interview version:

> “Slow dashboards are usually caused by too many expensive queries over too much data too often.”

---

## Framework 3: The alert not firing answer

Use this when asked:

> “A Grafana alert does not fire. What do you check?”

```text
1. Check rule is enabled.
2. Preview alert query.
3. Check reduce expression.
4. Check threshold.
5. Check evaluation interval.
6. Check for duration.
7. Check no-data and error states.
8. Remove dashboard variables.
9. Check data source errors.
10. Check alert state history.
```

Interview version:

> “I debug alert rules from the alert evaluator’s point of view, not from the dashboard panel.”

---

## Framework 4: The notification routing answer

Use this when asked:

> “An alert fires but the wrong team is notified.”

```text
1. Check alert labels.
2. Check notification policies.
3. Check matcher order.
4. Check contact point.
5. Check mute timings.
6. Check silences.
7. Check default route.
8. Test routing.
9. Standardize team/severity labels.
10. Document ownership.
```

Interview version:

> “Notification routing is label-driven. Bad labels create bad routing.”

---

## Framework 5: The production Grafana answer

Use this when asked:

> “How do you run Grafana safely in production?”

```text
1. External database for HA.
2. Backups.
3. SSO and least privilege.
4. Team/folder permissions.
5. Provisioned data sources and dashboards.
6. Plugin/version control.
7. Alerting source of truth.
8. Monitoring Grafana itself.
9. Secure service account tokens.
10. Upgrade testing.
```

Interview version:

> “Production Grafana is an observability control plane. I treat dashboards, data sources, alerting, permissions, and plugins as managed infrastructure.”

---

# Common Grafana interview traps and better answers

## Trap 1: “No data means the app is not emitting metrics?”

Weak answer:

> “Yes.”

Better answer:

> “Not necessarily. It could be time range, query, variable, label, data source, transformation, or permission issue.”

---

## Trap 2: “A dashboard and an alert use the same query, so they behave the same?”

Weak answer:

> “Yes.”

Better answer:

> “Not always. Alert rules evaluate on the backend and may not have dashboard variable context. I would check the alert preview.”

---

## Trap 3: “If the panel is slow, Grafana is the problem?”

Weak answer:

> “Yes.”

Better answer:

> “Maybe, but slow panels are often expensive data source queries, high cardinality, large time ranges, frequent refresh, or too many panels.”

---

## Trap 4: “Provisioned dashboards should be edited in the UI?”

Weak answer:

> “Yes.”

Better answer:

> “If dashboards are provisioned, the source of truth is the file or Git repo. UI edits may be overwritten.”

---

## Trap 5: “All users can query all data sources if they can see the dashboard?”

Weak answer:

> “Yes.”

Better answer:

> “Not always. Dashboard permissions and data source permissions can be separate.”

---

## Trap 6: “Alert noise is normal?”

Weak answer:

> “Yes.”

Better answer:

> “No. Noisy alerts are design problems. Alerts should be actionable, stable, routed correctly, and based on user or service impact.”

---

## Trap 7: “Grafana only needs dashboards backed up?”

Weak answer:

> “Yes.”

Better answer:

> “Grafana also has data sources, users, teams, folders, alerting resources, preferences, plugins, and database state unless everything is provisioned.”

---

# Grafana interview quick-reference table

| Issue | Main symptom | First thing to check | Common fix |
|---|---|---|---|
| No data | Empty panel | Time range/query | Fix query/variables/source |
| Data source error | Query fails | Data source health | Fix URL/auth/network |
| Slow dashboard | Long load | Query inspector | Reduce panels/cardinality |
| Refresh overload | Backend load | Refresh interval | Increase interval |
| Wrong time range | Missing recent/old data | Time picker | Fix time override/timezone |
| Bad variable | Wrong dropdown | Variable preview | Fix query/regex |
| Too many series | Browser slow | Query cardinality | Aggregate/topk |
| Bad rate query | Weird graph | Metric type/window | Use correct PromQL |
| Missing Loki logs | No logs | Labels/agent/time | Fix collection/query |
| Transform issue | Raw data hidden | Transform tab | Simplify/disable transform |
| Alert not firing | Normal state | Alert preview | Fix condition/query |
| Alert noisy | Too many pages | Threshold/for/grouping | Tune alert |
| Notification missing | Firing no message | Policies/contact point | Fix routing |
| Wrong team notified | Bad route | Labels | Standardize labels |
| Dashboard permission | 403/missing dash | Folder/team role | Fix permissions |
| Data source permission | Panel denied | DS permission | Grant query access |
| Provisioned UI change lost | Changes revert | Provisioning source | Edit Git/file |
| Provisioning not updating | Old data source | Mounted file/logs | Fix provisioning |
| UID conflict | Dashboard overwritten | Dashboard UID | Unique UID |
| Import fails | Broken dashboard | Data source/plugin | Map/install/fix JSON |
| SSO issue | Login failure | root URL/IdP | Fix callback/claims |
| Proxy issue | Bad links/login | root_url/headers | Fix proxy config |
| Plugin missing | Unknown panel | Plugin install | Install/pin plugin |
| DB issue | Lost state | Database config | Use persistent/external DB |
| Upgrade break | Dash/alert broken | Release notes/plugins | Test upgrade |
| Too many admins | Governance risk | Roles/teams | Least privilege |
| API token fail | 401/403 | Token/role | Rotate/scope token |
| JSON unmanageable | Huge diffs | Dashboard workflow | Use as-code tooling |
| Alert provisioning drift | UI changes vanish | Source of truth | Standardize provisioning |
| Poor dashboard design | Not actionable | Dashboard purpose | Redesign around signals |

---

# Strong closing takeaway

Grafana interviews are not just about knowing where to click. They are about showing that you understand observability data flow, query behavior, dashboard design, alert evaluation, permissions, provisioning, and production operations.

A weak answer sounds like:

> “I would refresh the dashboard.”

A strong answer sounds like:

> “I would test the query in Explore, confirm the time range and variables, inspect the data source health and query inspector, check transformations and permissions, then compare Grafana’s result with the source system.”

Grafana problems usually leave evidence in:

```text
Explore query results
Panel query inspector
Dashboard variables
Data source health check
Grafana server logs
Data source logs
Alert rule preview
Notification policy routing
Provisioning logs
Plugin logs
```

When you freeze, return to this sequence:

```text
Dashboard → Panel → Query → Time range → Variables → Data source → Permissions → Transformations → Alerting → Fix → Verify
```

That sequence will carry you through most Grafana interview questions.

---

# Final takeaway summaries

## The one-minute summary

Grafana issues usually come from data source connectivity, wrong queries, time range mistakes, dashboard variables, high-cardinality results, slow dashboards, transformations, alert rule conditions, notification routing, permissions, provisioning, dashboard UID conflicts, plugin problems, SSO/proxy configuration, database state, upgrades, service account tokens, and poor dashboard design. The best answer starts with Explore, query inspector, data source health, and alert preview.

## The senior-engineer summary

A senior Grafana engineer understands that Grafana is an observability control plane. They do not assume “No data” means no data. They verify queries, time ranges, variables, permissions, and source systems. They design dashboards around operational questions, alerts around actionable symptoms, and Grafana operations around provisioning, access control, backups, plugins, and safe upgrades.

## The interview survival summary

When your mind goes blank, say:

> “I would first determine whether the issue is dashboard rendering, query logic, data source connectivity, variables, time range, permissions, transformations, alert evaluation, or notification routing. Then I would test in Explore, inspect query inspector output, check data source health and Grafana logs, verify alert preview if alerting is involved, fix the proven cause, and validate with a known time range.”

That answer works across most Grafana interview scenarios.
