# Argo CD: “I Know This Stuff, But in the Interview I Freeze” Kit

## Strong intro

You can use Argo CD every day and still freeze in an interview.

That freeze usually does not mean you lack GitOps experience. It means your knowledge is stored as real work: checking Application status, reading sync errors, fixing repo credentials, tracing Helm values, debugging Kustomize overlays, comparing desired versus live state, handling stuck sync waves, and recovering from a bad deployment without making the cluster worse.

In production, Argo CD is not “just a deployment tool.” It is a control plane for desired state. It continuously compares Git with Kubernetes and tells you when reality has drifted. If you misunderstand what Argo CD is doing, you can accidentally fight the controller, overwrite manual fixes, or sync bad manifests across many clusters.

This kit is built for that interview moment when you know the topic but need calm, clear words.

It covers 30 common Argo CD issues interviewers ask about, with symptoms, causes, diagnosis steps, resolutions, and examples. It is written for DevOps, platform, SRE, Kubernetes, and GitOps engineers who want practical interview-ready language.

When you freeze, start with this sentence:

> “I would first identify whether the Argo CD issue is repo access, manifest generation, sync ordering, Kubernetes admission, permissions, health assessment, drift, pruning, Helm or Kustomize rendering, destination cluster access, or Argo CD controller health. Then I would compare desired state from Git with live cluster state and inspect the Application events, sync result, controller logs, and Kubernetes events before changing anything.”

That answer sounds like someone who understands GitOps as an operational system, not just a UI.

---

## How to use this kit

For every Argo CD issue, use this structure:

```text
Symptom → Scope → Evidence → Cause → Fix → Verify → Prevent
```

A strong Argo CD interview answer usually includes:

1. What the user sees.
2. Whether the issue affects one Application, one Project, one repo, one cluster, or all Argo CD.
3. Whether the cause is Git, manifest rendering, sync, Kubernetes validation, RBAC, repo credentials, cluster credentials, or controller health.
4. What logs or status fields you check first.
5. What safe fix you apply.
6. How you verify the application is Synced and Healthy.
7. How you prevent the issue from repeating.

Example:

> “If an Argo CD app is OutOfSync, I would not immediately hit Sync. I would first inspect the diff, check whether the difference is intentional drift, generated field noise, manual cluster changes, Helm rendering, or a missing ignore rule. Then I would decide whether Git should change or the cluster should be reconciled.”

That is better than saying:

> “I would sync it.”

Syncing is an action. Diagnosis is engineering.

---

# Top 30 Argo CD issues and resolutions

---

## 1. Application is OutOfSync

### Interview freeze point

The interviewer asks:

> “An Argo CD app is OutOfSync. What do you do?”

A weak answer is “click Sync.” A strong answer explains why the app is OutOfSync.

### Strong interview answer

> “I would inspect the diff first. OutOfSync means desired state in Git differs from live state in the cluster. I would determine whether the difference is caused by a manual change, generated field, Helm/Kustomize rendering, admission controller mutation, missing resource, extra resource, or intentional emergency drift.”

### Symptoms

- Application status shows `OutOfSync`.
- UI shows resource diff.
- Auto-sync keeps changing resources.
- Manual changes disappear.
- Drift appears after webhook/controller mutation.

### Diagnostic commands

```bash
argocd app get my-app
argocd app diff my-app
kubectl get application my-app -n argocd -o yaml
```

Check live resource:

```bash
kubectl get deployment api -n app -o yaml
```

### Common causes

- Someone changed the resource manually.
- Git was updated but app not synced.
- Mutating admission webhook changed the live resource.
- Kubernetes defaulted a field.
- Helm chart rendered different output.
- Kustomize overlay changed.
- Resource exists in cluster but not Git.
- Argo CD ignore differences not configured.
- Controller-generated fields are being compared.

### Example

Git says:

```yaml
replicas: 3
```

Live cluster says:

```yaml
replicas: 5
```

If someone manually scaled the deployment, Argo CD reports OutOfSync.

### Resolution option 1: Git is correct

Sync the app:

```bash
argocd app sync my-app
```

This restores live state to Git.

### Resolution option 2: live change is correct

Update Git:

```yaml
spec:
  replicas: 5
```

Then let Argo CD sync.

### Resolution option 3: ignore generated field

Example Application ignore rule:

```yaml
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
```

Use carefully. Ignoring replicas may hide real drift unless another system such as HPA owns it.

### Verify

```bash
argocd app get my-app
argocd app diff my-app
```

Expected:

```text
Sync Status: Synced
```

### Takeaway summary

OutOfSync is not automatically bad. It means Git and the cluster differ. First decide which one should be the source of truth.

---

## 2. Application is Degraded

### Interview freeze point

The app synced successfully, but health is bad.

### Strong interview answer

> “Synced means the desired manifests were applied. Healthy means the resources are behaving correctly. If an app is Degraded, I would inspect the unhealthy resource, Kubernetes events, pod status, rollout status, and Argo CD health assessment.”

### Symptoms

- Application shows `Synced` but `Degraded`.
- Deployment rollout failed.
- Pods crash.
- Service has no endpoints.
- Job failed.
- Custom resource reports unhealthy.

### Diagnostic commands

```bash
argocd app get my-app
argocd app resources my-app
kubectl get pods -n app
kubectl describe deployment api -n app
kubectl get events -n app --sort-by=.lastTimestamp
```

### Common causes

- Pods CrashLoopBackOff.
- ImagePullBackOff.
- Readiness probe failing.
- Deployment rollout timeout.
- Job failed.
- PVC not bound.
- Custom resource health check reports failure.
- Service has no endpoints.
- StatefulSet stuck.

### Example

Deployment resource is applied correctly:

```yaml
image: myregistry/api:1.2.3
```

But pods show:

```text
ImagePullBackOff
```

Argo CD may show the app as Degraded because Kubernetes cannot run the workload.

### Resolution

Fix the underlying Kubernetes issue:

```bash
kubectl describe pod api-xxxxx -n app
kubectl logs api-xxxxx -n app --previous
```

Then fix Git or registry credentials.

Example image fix:

```yaml
image: myregistry/api:1.2.4
```

### Verify

```bash
kubectl rollout status deployment/api -n app
argocd app get my-app
```

Expected:

```text
Health Status: Healthy
```

### Takeaway summary

Synced means applied. Healthy means working. A Degraded Argo CD app is usually a Kubernetes runtime problem.

---

## 3. Sync fails due to Kubernetes validation error

### Interview freeze point

Argo CD can render manifests, but the API server rejects them.

### Strong interview answer

> “If sync fails during apply, I would read the sync error and identify the Kubernetes resource rejected by the API server. The cause is often invalid YAML, wrong API version, immutable field change, missing CRD, policy denial, or admission webhook rejection.”

### Symptoms

- Application sync fails.
- Error says resource is invalid.
- API version not found.
- Field is immutable.
- Admission webhook denied request.
- CRD kind not recognized.

### Diagnostic commands

```bash
argocd app get my-app
argocd app history my-app
argocd app sync my-app --dry-run
kubectl apply --dry-run=server -f rendered.yaml
```

Render manifests if needed:

```bash
argocd app manifests my-app > rendered.yaml
```

### Common causes

- Invalid Kubernetes field.
- Wrong API version.
- CRD missing.
- Immutable field changed.
- Namespace missing.
- Admission webhook denied.
- Resource quota exceeded.
- PodSecurity restriction.
- Policy engine such as Kyverno, OPA Gatekeeper, or admission webhook blocked it.

### Example immutable field issue

Changing a Service `clusterIP` can fail:

```yaml
spec:
  clusterIP: 10.0.0.15
```

Kubernetes does not allow changing some immutable fields after creation.

### Resolution

- Fix manifest in Git.
- Delete and recreate resource only if safe.
- Use a migration plan for immutable fields.
- Install CRDs before CRs.
- Fix policy violation.
- Use sync waves for ordering.

### Example policy-compliant labels

```yaml
metadata:
  labels:
    app.kubernetes.io/name: api
    app.kubernetes.io/part-of: payments
    owner: platform
```

### Takeaway summary

Sync failure means Argo CD could not apply desired state. Read the exact Kubernetes API error and fix the manifest or prerequisite.

---

## 4. Repo connection failure

### Interview freeze point

Argo CD cannot fetch Git.

### Strong interview answer

> “I would check repository URL, credentials, SSH known_hosts, TLS certificates, network egress from argocd-repo-server, token expiry, and whether the repo is registered in Argo CD.”

### Symptoms

- Application cannot refresh.
- `repository not accessible`
- `authentication required`
- `permission denied`
- `x509 certificate signed by unknown authority`
- `ssh: handshake failed`
- Works locally but not in Argo CD.

### Diagnostic commands

```bash
argocd repo list
argocd repo get https://github.com/company/repo.git
kubectl logs -n argocd deployment/argocd-repo-server
```

Add repo:

```bash
argocd repo add https://github.com/company/repo.git \
  --username myuser \
  --password mytoken
```

SSH repo:

```bash
argocd repo add git@github.com:company/repo.git \
  --ssh-private-key-path ~/.ssh/id_rsa
```

### Common causes

- Wrong repo URL.
- Token expired.
- SSH key missing.
- SSH known_hosts missing.
- Repo moved or renamed.
- Private repo permission missing.
- Corporate proxy issue.
- TLS CA not trusted.
- NetworkPolicy blocks repo-server egress.
- Git provider rate limit.

### Resolution

- Update repo credential.
- Add SSH known_hosts.
- Add custom CA cert.
- Fix NetworkPolicy/proxy.
- Use deploy key or GitHub App integration where appropriate.
- Confirm repo-server can reach the Git host.

### Verify

```bash
argocd app refresh my-app
argocd app get my-app
```

### Takeaway summary

Repo failures are usually URL, credential, trust, token, or repo-server network problems.

---

## 5. Manifest generation error

### Interview freeze point

Argo CD can access Git, but cannot render the manifests.

### Strong interview answer

> “I would check whether the app uses plain YAML, Helm, Kustomize, Jsonnet, or a config management plugin. Manifest generation errors happen before Kubernetes apply, so I would inspect repo-server logs and render the same source locally.”

### Symptoms

- `Manifest generation error`
- Helm template error.
- Kustomize build error.
- Missing values file.
- Invalid YAML.
- Plugin failed.
- App never reaches apply phase.

### Diagnostic commands

```bash
argocd app get my-app
kubectl logs -n argocd deployment/argocd-repo-server
argocd app manifests my-app
```

For Helm locally:

```bash
helm template my-app ./chart -f values-prod.yaml
```

For Kustomize locally:

```bash
kustomize build overlays/prod
```

### Common causes

- Missing Helm values file.
- Invalid Helm template.
- Wrong Kustomize path.
- Kustomize patch target missing.
- YAML indentation error.
- Config management plugin missing dependency.
- Environment variable not available to plugin.
- Chart dependency not built.
- Wrong branch or path.

### Example Helm error

```text
Error: template: chart/templates/deployment.yaml: nil pointer evaluating interface
```

This often means a required value is missing.

### Resolution

Define the missing value:

```yaml
image:
  repository: registry.example.com/api
  tag: "1.2.3"
```

Or make template safer:

```yaml
image: "{{ required "image.repository is required" .Values.image.repository }}:{{ required "image.tag is required" .Values.image.tag }}"
```

### Takeaway summary

Manifest generation errors are Git/rendering problems, not cluster apply problems. Reproduce the render locally.

---

## 6. Helm values not applied as expected

### Interview freeze point

The app deploys, but wrong values appear in the cluster.

### Strong interview answer

> “I would check the Application Helm source configuration, valueFiles order, inline values, parameters, chart defaults, environment-specific values, and whether Argo CD is rendering the expected chart revision.”

### Symptoms

- Wrong image tag deployed.
- Wrong replica count.
- Config differs from expected values file.
- Works with local Helm but not Argo CD.
- Values file not found.
- Environment override ignored.

### Example Application source

```yaml
spec:
  source:
    repoURL: https://github.com/company/platform.git
    targetRevision: main
    path: charts/api
    helm:
      valueFiles:
        - values.yaml
        - values-prod.yaml
      parameters:
        - name: image.tag
          value: "1.2.3"
```

### Common causes

- Values files listed in wrong order.
- Values file path wrong.
- Inline parameter overrides file value.
- Chart default wins because override missing.
- App points to wrong branch.
- Helm dependency outdated.
- Multiple sources misunderstood.
- Values file exists in different repo/path.

### Diagnostic commands

```bash
argocd app get api
argocd app manifests api > rendered.yaml
grep -n "image:" rendered.yaml
```

Render locally:

```bash
helm template api ./charts/api \
  -f values.yaml \
  -f values-prod.yaml \
  --set image.tag=1.2.3
```

### Resolution

- Fix value file path.
- Correct override order.
- Avoid ambiguous overrides.
- Use immutable image tags.
- Render and compare.

### Takeaway summary

For Helm in Argo CD, rendered manifests are the truth. Check values order and overrides.

---

## 7. Kustomize overlay issue

### Interview freeze point

The base works, but the overlay fails or renders wrong manifests.

### Strong interview answer

> “I would render the Kustomize overlay locally, check resources, patches, image overrides, name prefixes, namespace settings, and whether patch targets still match after resource name changes.”

### Symptoms

- Kustomize build fails.
- Patch target not found.
- Wrong namespace applied.
- Image tag not updated.
- Base resource missing.
- Overlay works locally but not Argo CD.

### Example structure

```text
apps/api/
  base/
    deployment.yaml
    service.yaml
    kustomization.yaml
  overlays/
    prod/
      kustomization.yaml
      patch-replicas.yaml
```

### Example overlay

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namespace: api-prod

images:
  - name: registry.example.com/api
    newTag: "1.2.3"

patches:
  - path: patch-replicas.yaml
    target:
      kind: Deployment
      name: api
```

### Common causes

- Wrong relative path.
- Patch target name changed by prefix/suffix.
- Namespace set twice.
- Kustomize version difference.
- Deprecated patch syntax.
- Image name mismatch.
- Base missing resource.
- Generated ConfigMap name changes unexpectedly.

### Diagnostic commands

```bash
kustomize build apps/api/overlays/prod
argocd app manifests api
```

### Resolution

- Fix overlay path.
- Fix patch target.
- Pin or align Kustomize version if needed.
- Use consistent naming.
- Render locally before committing.

### Takeaway summary

Kustomize issues are usually path, patch target, namespace, image override, or version differences.

---

## 8. Missing CRD before custom resource sync

### Interview freeze point

Argo CD applies a custom resource before the CRD exists.

### Strong interview answer

> “I would check whether the CRD is installed before the custom resource. CRDs must exist in the cluster before Kubernetes can accept custom resources. In Argo CD, I would use sync waves, separate Applications, or app-of-apps ordering.”

### Symptoms

- Sync fails with `no matches for kind`.
- Custom resource cannot be applied.
- Operator app and CR app sync together but fail.
- CRD installed manually fixes it.

### Example error

```text
no matches for kind "Certificate" in version "cert-manager.io/v1"
```

### Resolution option 1: sync wave

CRD manifest:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"
```

Custom resource:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

### Resolution option 2: separate apps

```text
cert-manager-crds app → cert-manager app → certificates app
```

### Resolution option 3: Helm CRD handling

Some Helm charts put CRDs under `crds/`. Understand whether chart upgrades manage CRDs or not.

### Diagnostic commands

```bash
kubectl get crd | grep cert-manager
argocd app sync cert-manager
argocd app sync certificates
```

### Takeaway summary

Kubernetes cannot apply custom resources until their CRDs exist. Use ordering.

---

## 9. Sync wave or hook ordering problem

### Interview freeze point

The manifests are valid, but resources apply in the wrong order.

### Strong interview answer

> “I would check sync waves and hooks. Argo CD applies lower sync waves first. Hooks can run before, during, or after sync. Ordering problems happen when dependencies are not encoded in Git.”

### Symptoms

- Job runs before Secret exists.
- Deployment starts before migration job.
- Ingress applies before controller is ready.
- CR applies before operator is ready.
- App sync appears partially complete.

### Sync wave example

Secret first:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"
```

Migration job second:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

Deployment third:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2"
```

### Hook example

```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
```

### Common causes

- No sync waves.
- Hook fails.
- Hook not deleted.
- Job is not idempotent.
- Resource dependency not modeled.
- Operator readiness not considered.
- Negative sync waves misunderstood.

### Resolution

- Add sync waves.
- Make hooks idempotent.
- Use readiness checks.
- Separate infrastructure/operator apps from workload apps.
- Avoid fragile hooks where a controller can model the state.

### Takeaway summary

Sync order must be explicit when resources depend on each other.

---

## 10. Auto-sync overwrites manual hotfix

### Interview freeze point

Someone hotfixed production manually, then Argo CD reverted it.

### Strong interview answer

> “That is expected GitOps behavior if auto-sync is enabled. Argo CD reconciles live state back to Git. For emergency changes, the fix should be committed to Git quickly or auto-sync should be paused intentionally with clear ownership.”

### Symptoms

- Manual kubectl change disappears.
- Hotfix reverted.
- App keeps returning to old image.
- Manual scale operation reverted.
- Production emergency fix does not stick.

### Common causes

- Auto-sync enabled.
- Self-heal enabled.
- Git still contains old desired state.
- HPA/manual replicas conflict.
- Operator mutates resource and Argo CD reverts it.
- Team bypasses GitOps process.

### Example auto-sync

```yaml
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Resolution option 1: update Git

Change image in Git:

```yaml
image: registry.example.com/api:1.2.4
```

Commit and let Argo CD sync.

### Resolution option 2: pause auto-sync briefly

```bash
argocd app set my-app --sync-policy none
```

Then re-enable after Git is updated:

```bash
argocd app set my-app --sync-policy automated
```

### Interview caution

Pausing auto-sync should be controlled and temporary. Otherwise Git stops being truth.

### Takeaway summary

With self-heal, manual cluster changes are temporary. In GitOps, durable fixes go through Git.

---

## 11. Prune deletes unexpected resources

### Interview freeze point

A resource disappears after sync.

### Strong interview answer

> “I would check whether prune is enabled and whether the resource was removed from Git or from the app’s generated manifests. Prune removes live resources that Argo CD believes are no longer desired.”

### Symptoms

- Resource deleted after sync.
- ConfigMap, Service, or CR removed unexpectedly.
- Resource existed live but not in Git.
- App deletion removed child resources.
- Namespace resources disappear.

### Auto-prune example

```yaml
spec:
  syncPolicy:
    automated:
      prune: true
```

### Common causes

- Resource removed from Git.
- Helm values disabled resource.
- Kustomize path changed.
- App path points to wrong directory.
- Resource moved to another app.
- App tracking label/annotation conflict.
- Prune enabled without review.
- App deletion cascaded.

### Resolution

- Restore resource to Git if needed.
- Move resource carefully between apps.
- Disable prune temporarily during migration.
- Use `Prune=false` annotation for special resources if justified.

Annotation example:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-options: Prune=false
```

### Safer sync option

```yaml
spec:
  syncPolicy:
    syncOptions:
      - PruneLast=true
```

### Takeaway summary

Prune is powerful and dangerous. It deletes live resources missing from desired state.

---

## 12. Resource stuck Terminating due to finalizer

### Interview freeze point

Argo CD tries to delete an app or resource, but it hangs.

### Strong interview answer

> “I would check finalizers. Kubernetes finalizers block deletion until a controller completes cleanup. If the responsible controller is gone or broken, resources can remain stuck terminating.”

### Symptoms

- Application stuck deleting.
- Namespace stuck Terminating.
- CR stuck Terminating.
- App deletion never completes.
- Resource has finalizers.

### Diagnostic commands

```bash
kubectl get application my-app -n argocd -o yaml
kubectl get <resource> <name> -n <ns> -o yaml
```

Look for:

```yaml
metadata:
  finalizers:
    - resources-finalizer.argocd.argoproj.io
```

### Common causes

- Argo CD finalizer waiting to delete managed resources.
- CRD removed before CR cleanup.
- Operator missing.
- Controller lacks permission.
- Resource deletion blocked by child resources.
- Namespace finalizers stuck.

### Resolution

First, fix the controller if possible.

If emergency cleanup is required and safe, remove finalizer carefully:

```bash
kubectl patch application my-app -n argocd \
  --type merge \
  -p '{"metadata":{"finalizers":[]}}'
```

### Warning

Removing finalizers can orphan resources. Use only when you understand the cleanup impact.

### Takeaway summary

Finalizers are cleanup contracts. Remove them only when the responsible cleanup path is broken and the risk is understood.

---

## 13. Application points to wrong cluster or namespace

### Interview freeze point

The app syncs, but resources are in the wrong place or fail due to destination mismatch.

### Strong interview answer

> “I would check the Application destination server, namespace, and AppProject restrictions. Argo CD can manage multiple clusters, so destination mistakes can deploy to the wrong cluster or namespace.”

### Symptoms

- Resources appear in wrong namespace.
- Sync denied by project.
- App deploys to staging instead of prod.
- Namespace not found.
- App says destination not permitted.
- Cluster URL wrong.

### Example Application destination

```yaml
spec:
  destination:
    server: https://kubernetes.default.svc
    namespace: app-prod
```

External cluster destination:

```yaml
spec:
  destination:
    name: prod-cluster
    namespace: app-prod
```

### Diagnostic commands

```bash
argocd cluster list
argocd app get my-app
kubectl get application my-app -n argocd -o yaml
```

### Common causes

- Wrong cluster name.
- Wrong destination server.
- Namespace typo.
- AppProject blocks namespace.
- Namespace not created.
- Kube context confusion during bootstrap.
- App-of-apps template uses wrong values.

### Resolution

Fix destination:

```yaml
spec:
  destination:
    name: prod-cluster
    namespace: payments-prod
```

Create namespace if allowed:

```yaml
spec:
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

### Takeaway summary

Always verify Argo CD Application destination. Wrong cluster or namespace is a high-risk GitOps mistake.

---

## 14. AppProject blocks sync

### Interview freeze point

The app looks valid, but Argo CD refuses to deploy it.

### Strong interview answer

> “I would check the AppProject. Projects restrict source repos, destination clusters/namespaces, allowed resource kinds, and sometimes roles. They are an important security boundary in Argo CD.”

### Symptoms

- Sync denied.
- App cannot use repo.
- Destination not permitted.
- Cluster-scoped resource denied.
- Resource kind not allowed.
- Team cannot access app.

### Example AppProject

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: payments
  namespace: argocd
spec:
  sourceRepos:
    - https://github.com/company/payments-platform.git
  destinations:
    - server: https://kubernetes.default.svc
      namespace: payments-*
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
  namespaceResourceWhitelist:
    - group: '*'
      kind: '*'
```

### Common causes

- Repo URL not in `sourceRepos`.
- Destination namespace not allowed.
- Destination cluster not allowed.
- Cluster-scoped resource blocked.
- Namespace resource kind blocked.
- Project role missing permissions.
- App assigned to wrong project.

### Diagnostic commands

```bash
kubectl get appproject payments -n argocd -o yaml
argocd app get my-app
```

### Resolution

- Add allowed repo.
- Add allowed destination.
- Add specific resource kind if justified.
- Move app to correct project.
- Avoid broad `*` in sensitive environments unless intentional.

### Takeaway summary

AppProjects are Argo CD guardrails. If sync is denied, check project policy.

---

## 15. Argo CD RBAC denies user action

### Interview freeze point

A user can see Argo CD but cannot sync or edit apps.

### Strong interview answer

> “I would check Argo CD RBAC policy, group claims from SSO, role bindings, and whether the user has permission for the project and application. Kubernetes RBAC and Argo CD RBAC are different layers.”

### Symptoms

- User cannot sync app.
- User cannot view project.
- User cannot delete app.
- Works for admin but not team member.
- SSO login works but permissions wrong.

### Argo CD RBAC example

`argocd-rbac-cm`:

```yaml
data:
  policy.csv: |
    p, role:developer, applications, get, payments/*, allow
    p, role:developer, applications, sync, payments/*, allow
    g, payments-team, role:developer
  policy.default: role:readonly
```

### Common causes

- SSO group claim missing.
- Group name mismatch.
- Policy uses wrong project/app pattern.
- User has Kubernetes RBAC but not Argo CD RBAC.
- Default role too restrictive.
- Local account disabled.
- OIDC scopes misconfigured.

### Diagnostic commands

```bash
kubectl get configmap argocd-rbac-cm -n argocd -o yaml
argocd account get-user-info
```

### Resolution

- Fix group claim mapping.
- Add correct RBAC policy.
- Use project-scoped roles where possible.
- Keep admin access limited.
- Test with a non-admin account.

### Takeaway summary

Argo CD RBAC controls Argo CD actions. Do not confuse it with Kubernetes RBAC.

---

## 16. Destination cluster connection failure

### Interview freeze point

Argo CD can access Git but cannot apply to the target cluster.

### Strong interview answer

> “I would check whether the target cluster is registered, credentials are valid, API server is reachable from the Argo CD application controller, and the cluster service account has the required Kubernetes permissions.”

### Symptoms

- Cluster shows unknown or unavailable.
- Sync fails with authentication error.
- App cannot list resources.
- TLS or certificate error.
- Works for local cluster but not remote cluster.

### Diagnostic commands

```bash
argocd cluster list
argocd cluster get <cluster-name>
kubectl logs -n argocd deployment/argocd-application-controller
```

Add cluster:

```bash
argocd cluster add <kube-context>
```

### Common causes

- Cluster credentials expired.
- API server unreachable.
- NetworkPolicy/firewall blocks access.
- Cluster CA changed.
- Service account token invalid.
- Argo CD lacks RBAC in target cluster.
- Cluster name changed.
- Private cluster endpoint not reachable.

### Resolution

- Re-register the cluster.
- Fix network connectivity.
- Rotate cluster credentials.
- Confirm target service account permissions.
- Use private connectivity for private clusters.
- Check API server certificate trust.

### Takeaway summary

Repo access and cluster access are separate. Argo CD needs both to deploy.

---

## 17. Argo CD cannot delete or update resources due to Kubernetes RBAC

### Interview freeze point

Argo CD sees resources but cannot manage them.

### Strong interview answer

> “I would check the Kubernetes service account Argo CD uses against the target namespace and resource types. Argo CD may have permission to read but not create, update, patch, or delete.”

### Symptoms

- Sync fails with `forbidden`.
- Cannot create Namespace.
- Cannot update CRD.
- Cannot delete resource during prune.
- Argo CD app is stuck OutOfSync.

### Diagnostic commands

Check access as service account:

```bash
kubectl auth can-i create deployments \
  --as system:serviceaccount:argocd:argocd-application-controller \
  -n app

kubectl auth can-i delete services \
  --as system:serviceaccount:argocd:argocd-application-controller \
  -n app
```

### Common causes

- Argo CD service account lacks namespace permissions.
- Cluster-scoped resource requires ClusterRole.
- App tries to create namespace without permission.
- Project allows resource but Kubernetes RBAC denies it.
- Remote cluster registration used limited service account.
- Prune requires delete permission.

### Resolution

Grant only required permissions.

Example Role:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: app
  name: argocd-app-manager
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

RoleBinding:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: app
  name: argocd-app-manager
subjects:
  - kind: ServiceAccount
    name: argocd-application-controller
    namespace: argocd
roleRef:
  kind: Role
  name: argocd-app-manager
  apiGroup: rbac.authorization.k8s.io
```

### Takeaway summary

Argo CD needs Kubernetes RBAC for the exact resources it manages.

---

## 18. Image tag changed but Argo CD does not deploy

### Interview freeze point

A new image was pushed, but Argo CD does nothing.

### Strong interview answer

> “Argo CD watches Git, not container registries by default. If the image tag in Git does not change, Argo CD has no desired-state change to sync unless an image updater or another automation updates Git.”

### Symptoms

- New Docker image pushed.
- Argo CD app remains Synced.
- Deployment still uses old image.
- Using `latest` does not trigger rollout.
- Pods do not restart.

### Common cause

Git still says:

```yaml
image: registry.example.com/api:1.2.3
```

Even if `1.2.4` exists in the registry, Argo CD does not know to use it.

### Resolution option 1: update Git

```yaml
image: registry.example.com/api:1.2.4
```

Commit and let Argo CD sync.

### Resolution option 2: use Argo CD Image Updater

Image Updater can update Git or Argo CD parameters depending on configuration.

Example annotation style:

```yaml
metadata:
  annotations:
    argocd-image-updater.argoproj.io/image-list: api=registry.example.com/api
    argocd-image-updater.argoproj.io/api.update-strategy: semver
```

### Avoid ambiguous `latest`

Bad:

```yaml
image: registry.example.com/api:latest
```

Better:

```yaml
image: registry.example.com/api:1.2.4
```

or immutable digest:

```yaml
image: registry.example.com/api@sha256:abc123...
```

### Takeaway summary

Argo CD deploys Git changes. New images must be reflected in Git or through controlled image update automation.

---

## 19. App stuck in Progressing

### Interview freeze point

The sync completes, but health never becomes Healthy.

### Strong interview answer

> “Progressing usually means Kubernetes accepted the manifests but the resource has not reached its expected health state. I would check rollouts, pod readiness, jobs, statefulset ordinals, custom resource status, and Argo CD health checks.”

### Symptoms

- App status `Progressing`.
- Deployment rollout not complete.
- StatefulSet waiting on pod.
- Job running too long.
- Custom resource has no healthy condition.
- App never becomes Healthy.

### Diagnostic commands

```bash
argocd app resources my-app
kubectl rollout status deployment/api -n app
kubectl get pods -n app
kubectl describe pod <pod> -n app
```

### Common causes

- Readiness probe failing.
- Deployment unavailable.
- Pod Pending.
- Job still running.
- StatefulSet ordered rollout stuck.
- Custom resource health unknown.
- Controller not updating status.
- HPA or PDB slowing rollout.

### Resolution

Fix the underlying resource health.

Example readiness probe fix:

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
```

### For custom resources

Define custom health checks if Argo CD cannot infer health.

### Takeaway summary

Progressing is usually a Kubernetes workload readiness issue, not a Git issue.

---

## 20. Custom resource health shows Unknown

### Interview freeze point

Argo CD manages a CRD, but cannot tell if it is healthy.

### Strong interview answer

> “Argo CD has built-in health checks for common resources, but custom resources may need custom health logic. I would inspect the CR status fields and configure a custom health check if needed.”

### Symptoms

- Custom resource shows `Unknown`.
- App health remains Unknown.
- Operator says resource is ready.
- Argo CD UI cannot assess health.
- Sync works but app health unclear.

### Diagnostic commands

```bash
kubectl get <kind> <name> -n <ns> -o yaml
argocd app get my-app
```

Check CR status:

```yaml
status:
  conditions:
    - type: Ready
      status: "True"
```

### Example custom health check

In `argocd-cm`:

```yaml
data:
  resource.customizations.health.example.com_MyResource: |
    hs = {}
    if obj.status ~= nil and obj.status.conditions ~= nil then
      for i, condition in ipairs(obj.status.conditions) do
        if condition.type == "Ready" and condition.status == "True" then
          hs.status = "Healthy"
          hs.message = "Resource is ready"
          return hs
        end
      end
    end
    hs.status = "Progressing"
    hs.message = "Waiting for Ready condition"
    return hs
```

### Common causes

- CRD has no status.
- Operator does not update conditions.
- Argo CD lacks built-in health check.
- Custom health script missing.
- Health field differs by operator version.

### Takeaway summary

For custom resources, Argo CD may need custom health logic based on the CR status.

---

## 21. Diff noise from generated fields

### Interview freeze point

Argo CD constantly reports differences that are not meaningful.

### Strong interview answer

> “I would inspect the diff and identify whether the field is managed by Kubernetes, a webhook, an operator, or another controller. If the field is intentionally managed outside Git, I would add a narrow ignoreDifferences rule.”

### Symptoms

- App always OutOfSync.
- Diff shows managedFields, annotations, status, replicas, webhook-injected fields, or generated cert data.
- Sync does not clear diff.
- Another controller keeps mutating resource.

### Common noisy fields

```text
metadata.managedFields
status
replicas when HPA owns scaling
webhook-injected annotations
cert-manager generated fields
service mesh sidecar injection
```

### Example ignore rule

```yaml
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
```

Ignore by managed field manager:

```yaml
spec:
  ignoreDifferences:
    - group: "*"
      kind: "*"
      managedFieldsManagers:
        - kube-controller-manager
```

### Caution

Do not ignore broad fields just to make the UI green. You may hide real drift.

### Resolution

- Identify field owner.
- Add narrow ignore rule.
- Move field ownership into Git if appropriate.
- Disable conflicting mutation if unwanted.
- Avoid multiple controllers fighting over the same field.

### Takeaway summary

Diff noise means ownership is unclear. Ignore only fields intentionally managed outside Git.

---

## 22. App-of-apps ordering or bootstrap issue

### Interview freeze point

A parent app creates child apps, but children fail or deploy in the wrong order.

### Strong interview answer

> “In app-of-apps, I would check parent application manifests, child AppProjects, destinations, repo access, sync waves, and whether foundational apps such as CRDs, namespaces, and controllers deploy before dependent apps.”

### Symptoms

- Parent app Synced but child apps fail.
- Child app missing project.
- Apps deploy before CRDs.
- Namespace missing.
- Wrong destination in generated child app.
- Deleting parent affects children unexpectedly.

### Example child Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: payments-api
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "10"
spec:
  project: payments
  source:
    repoURL: https://github.com/company/platform.git
    targetRevision: main
    path: apps/payments/api
  destination:
    name: prod-cluster
    namespace: payments
```

### Common causes

- Project not created before child apps.
- Repo credentials missing.
- Sync waves missing.
- Namespace not created.
- CRDs not installed before CRs.
- Parent app prune deletes child apps.
- Child app uses wrong cluster.

### Resolution

- Use sync waves for parent resources.
- Bootstrap projects and repos first.
- Separate platform foundations from workloads.
- Use `CreateNamespace=true` if appropriate.
- Be careful with cascade deletion.

### Takeaway summary

App-of-apps is powerful but ordering and ownership must be explicit.

---

## 23. ApplicationSet generator creates wrong apps

### Interview freeze point

ApplicationSet automates app creation, but creates too many, too few, or wrong destinations.

### Strong interview answer

> “I would inspect the generator output and template variables. ApplicationSet problems usually come from incorrect cluster labels, Git directory matching, list generator values, matrix combinations, or template fields.”

### Symptoms

- Apps missing.
- Too many apps created.
- Apps target wrong cluster.
- Wrong namespace.
- Directory generator picks unexpected folders.
- Cluster generator selects wrong clusters.

### Example cluster generator

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: platform-addons
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            environment: prod
  template:
    metadata:
      name: '{{name}}-addons'
    spec:
      project: platform
      source:
        repoURL: https://github.com/company/platform.git
        targetRevision: main
        path: addons
      destination:
        server: '{{server}}'
        namespace: platform
```

### Common causes

- Cluster labels wrong.
- Git path glob too broad.
- Matrix generator creates unintended combinations.
- Template variable name wrong.
- Destination uses `server` when `name` expected.
- Project restrictions block generated apps.
- ApplicationSet controller lacks permissions.

### Diagnostic commands

```bash
kubectl get applicationset -n argocd
kubectl describe applicationset platform-addons -n argocd
kubectl logs -n argocd deployment/argocd-applicationset-controller
kubectl get applications -n argocd
```

### Resolution

- Tighten generator selectors.
- Label clusters accurately.
- Narrow Git directory patterns.
- Validate template variables.
- Use preview/testing in non-prod.
- Add project guardrails.

### Takeaway summary

ApplicationSet issues are usually generator selection or template variable problems.

---

## 24. Sync stuck because hook job failed

### Interview freeze point

The app will not complete sync because a PreSync or Sync hook failed.

### Strong interview answer

> “I would identify the hook resource, check its pod logs, job status, hook delete policy, and whether the hook is idempotent. Failed hooks block sync until resolved.”

### Symptoms

- Sync operation stuck or failed.
- Hook job failed.
- PreSync migration failed.
- Hook resource remains.
- Sync retries keep failing.

### Example hook job

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: migrate
          image: registry.example.com/api:1.2.3
          command: ["./migrate.sh"]
```

### Diagnostic commands

```bash
kubectl get jobs -n app
kubectl describe job db-migrate -n app
kubectl logs job/db-migrate -n app
argocd app get my-app
```

### Common causes

- Migration script fails.
- Missing secret.
- Job not idempotent.
- Image pull failure.
- Hook delete policy wrong.
- Previous failed hook remains.
- Database unavailable.
- Job timeout/backoff limit reached.

### Resolution

- Fix hook job failure.
- Make migrations idempotent.
- Delete failed hook if safe.
- Use timeout/backoff intentionally.
- Avoid destructive hooks.

### Takeaway summary

Hooks are part of deployment logic. Failed hooks must be debugged like production jobs.

---

## 25. Argo CD UI or API unavailable

### Interview freeze point

Users cannot access Argo CD.

### Strong interview answer

> “I would check argocd-server pod health, service, ingress, TLS, SSO, Redis, repo-server, application-controller, and Kubernetes events. UI availability and sync controller health are related but different.”

### Symptoms

- Argo CD UI down.
- API login fails.
- CLI cannot connect.
- Ingress returns 502.
- SSO login loops.
- Apps still sync or stop syncing depending on component health.

### Diagnostic commands

```bash
kubectl get pods -n argocd
kubectl get svc -n argocd
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server
kubectl logs -n argocd deployment/argocd-server
kubectl get ingress -n argocd
```

### Common causes

- argocd-server pod crash.
- Ingress misconfigured.
- TLS certificate expired.
- SSO/OIDC configuration broken.
- Redis down.
- Service selector wrong.
- NetworkPolicy blocks traffic.
- Resource limits too low.
- Argo CD upgrade issue.

### Resolution

- Fix ingress/TLS.
- Restart unhealthy component.
- Roll back bad config.
- Check SSO config.
- Check Redis and controller pods.
- Scale components if needed.

### Takeaway summary

Argo CD UI/API outage is not always a deployment outage. Check which Argo CD component is unhealthy.

---

## 26. Repo-server high CPU or manifest rendering slow

### Interview freeze point

Argo CD refreshes and syncs become slow.

### Strong interview answer

> “I would check repo-server CPU, memory, concurrent manifest generation, large repos, Helm dependency downloads, plugin performance, and cache behavior. Manifest generation can become a bottleneck in large GitOps installations.”

### Symptoms

- App refresh slow.
- Manifest generation timeout.
- Repo-server CPU high.
- Many apps stuck refreshing.
- Helm/Kustomize rendering slow.
- UI sluggish when viewing apps.

### Diagnostic commands

```bash
kubectl top pod -n argocd
kubectl logs -n argocd deployment/argocd-repo-server
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

### Common causes

- Large monorepo.
- Many apps refreshing at once.
- Heavy Helm charts.
- Plugin downloads dependencies every render.
- Repo-server resource limits too low.
- No caching for dependencies.
- Very large generated manifests.
- Git provider slow.

### Resolution

- Increase repo-server resources.
- Scale repo-server if supported by deployment design.
- Reduce unnecessary refreshes.
- Split very large repos or apps.
- Cache Helm dependencies.
- Optimize config management plugins.
- Avoid huge generated manifests.

### Takeaway summary

Repo-server is the manifest rendering engine. If rendering is slow, sync and refresh are slow.

---

## 27. Application controller overloaded

### Interview freeze point

Argo CD has many apps and starts lagging.

### Strong interview answer

> “I would check application-controller logs, reconciliation queue, Kubernetes API rate limits, number of applications, cluster count, resource count, and controller CPU/memory. At scale, Argo CD needs tuning and app boundaries.”

### Symptoms

- Apps take long to reconcile.
- Sync status stale.
- Controller CPU high.
- Kubernetes API throttling.
- App status updates delayed.
- Many apps stuck in refresh.

### Diagnostic commands

```bash
kubectl top pod -n argocd
kubectl logs -n argocd statefulset/argocd-application-controller
kubectl get applications -n argocd | wc -l
```

### Common causes

- Too many apps/resources for controller sizing.
- Very large apps.
- Frequent syncs.
- Kubernetes API throttling.
- Slow destination clusters.
- Controller resource limits too low.
- Excessive diff customizations.
- App-of-apps explosion.

### Resolution

- Increase controller resources.
- Tune reconciliation settings carefully.
- Split huge apps.
- Reduce unnecessary auto-sync churn.
- Use app sharding where appropriate in large installations.
- Monitor Argo CD metrics.
- Avoid one app owning thousands of unrelated resources.

### Takeaway summary

At scale, Argo CD performance is about app count, resource count, API load, and controller capacity.

---

## 28. Rollback confusion

### Interview freeze point

The team asks how to roll back with Argo CD.

### Strong interview answer

> “In GitOps, the preferred rollback is a Git revert or a commit that restores the previous desired state. Argo CD can sync to a previous revision, but Git should remain the durable source of truth.”

### Symptoms

- Bad deployment synced.
- Need to restore previous version.
- Argo CD history shows good revision.
- Manual rollback gets overwritten.
- Team uses kubectl rollout undo but Argo CD reapplies bad Git state.

### Diagnostic commands

```bash
argocd app history my-app
argocd app get my-app
```

### Preferred rollback

Revert Git commit:

```bash
git revert <bad-commit>
git push
```

Then sync:

```bash
argocd app sync my-app
```

### Argo CD revision sync

```bash
argocd app sync my-app --revision <good-git-sha>
```

### Caution

If you sync to an old revision but Git branch still points to bad desired state, future refresh/sync may return to bad state depending on configuration.

### Takeaway summary

For GitOps, rollback should usually be a Git change. Keep Git as truth.

---

## 29. Multiple apps manage the same resource

### Interview freeze point

Two Argo CD apps fight over one Kubernetes object.

### Strong interview answer

> “I would check resource ownership and tracking. A resource should have one GitOps owner. If two applications manage the same object, Argo CD can create sync fights, prune risk, and confusing diffs.”

### Symptoms

- Resource flips between two states.
- One app sync makes another OutOfSync.
- Prune deletes resource used by another app.
- Diff keeps returning.
- Ownership labels/annotations conflict.

### Diagnostic commands

```bash
argocd app resources app-a
argocd app resources app-b
kubectl get deployment api -n app -o yaml
```

Look for Argo CD tracking labels/annotations.

### Common causes

- Shared base included in multiple apps.
- App-of-apps duplicate path.
- Helm chart and raw manifest both create same resource.
- Namespace or Secret managed by multiple apps.
- Resource moved between apps without migration.
- Prune enabled during ownership move.

### Resolution

- Define one owner per resource.
- Move shared resources to a platform app.
- Disable prune temporarily during migration.
- Remove duplicate manifests.
- Use clear app boundaries.
- Validate app resources before sync.

### Takeaway summary

GitOps ownership must be clear. One live resource should not be actively managed by multiple Argo CD apps.

---

## 30. Bad GitOps repository structure causes unsafe deployments

### Interview freeze point

This is less about one error and more about design maturity.

### Strong interview answer

> “I would structure GitOps repos around ownership, environment separation, promotion flow, and blast radius. Poor structure causes accidental prod changes, duplicate ownership, hard reviews, and unsafe app generation.”

### Symptoms

- Dev change affects prod.
- Values files are confusing.
- Same app deployed differently without clear reason.
- AppSet generates too many apps.
- Reviewers cannot see what changes.
- Teams bypass GitOps due to complexity.
- Secrets accidentally committed.
- Shared resources duplicated.

### Common poor patterns

```text
One giant app for everything
Prod and dev values mixed together
Unclear overlays
Using latest image tags
Generated manifests committed without clear source
Secrets in Git
No ownership boundaries
No promotion process
```

### Better repo pattern

```text
platform-gitops/
  clusters/
    prod-eu/
      apps/
      platform/
    staging-eu/
      apps/
      platform/
  apps/
    payments-api/
      base/
      overlays/
        staging/
        prod/
  projects/
  appsets/
```

### Promotion pattern

```text
Build image → update staging Git value → test → promote same image tag/digest to prod Git value
```

### Example immutable image value

```yaml
image:
  repository: registry.example.com/payments-api
  tag: "1.2.3"
```

or:

```yaml
image:
  digest: "sha256:abc123..."
```

### Prevention

- Separate environments clearly.
- Use AppProjects for guardrails.
- Keep app ownership clear.
- Use immutable versions.
- Keep secrets out of Git or use sealed/encrypted secret workflow.
- Require PR review for production.
- Use policy checks.
- Keep generated output understandable.

### Takeaway summary

Good GitOps repo design reduces blast radius. Bad repo design turns Argo CD into a fast way to make mistakes.

---

# Bonus: Argo CD interview answer frameworks

## Framework 1: The OutOfSync answer

Use this when asked:

> “An app is OutOfSync. What do you do?”

```text
1. Inspect the diff.
2. Identify the resource and field.
3. Determine field owner.
4. Check whether drift was manual, generated, webhook, operator, or Git change.
5. Decide whether Git or live state is correct.
6. Update Git or sync live state.
7. Add ignoreDifferences only if ownership is external.
8. Verify Synced.
```

Interview version:

> “I would not sync blindly. I would first decide whether the cluster drift or Git desired state is correct.”

---

## Framework 2: The sync failure answer

Use this when asked:

> “Argo CD sync failed. How do you troubleshoot?”

```text
1. Read the sync error.
2. Determine phase: repo access, manifest generation, apply, health, or hook.
3. Check Application events and sync result.
4. Check repo-server logs for rendering errors.
5. Check application-controller logs for apply/sync issues.
6. Check Kubernetes events for rejected resources.
7. Fix Git or cluster prerequisite.
8. Sync again.
9. Verify Synced and Healthy.
```

Interview version:

> “I separate rendering failures from Kubernetes apply failures. They are different classes of problems.”

---

## Framework 3: The GitOps rollback answer

Use this when asked:

> “How do you roll back with Argo CD?”

```text
1. Identify bad revision.
2. Identify last known good revision.
3. Prefer Git revert.
4. Push revert commit.
5. Let Argo CD sync or manually sync.
6. Verify workload health.
7. Avoid kubectl-only rollback unless emergency.
8. Record incident and prevention action.
```

Interview version:

> “In GitOps, rollback should usually be a Git rollback, because Git must remain the durable source of truth.”

---

## Framework 4: The Argo CD access answer

Use this when asked:

> “A user cannot sync an app. What do you check?”

```text
1. Check Argo CD login identity.
2. Check SSO group claims.
3. Check argocd-rbac-cm.
4. Check AppProject roles.
5. Check app project/name pattern.
6. Check whether Kubernetes RBAC is also needed.
7. Test with least privilege.
8. Avoid giving admin.
```

Interview version:

> “Argo CD RBAC controls Argo CD actions. Kubernetes RBAC controls cluster API actions. They are related but different.”

---

## Framework 5: The production-safe sync answer

Use this when asked:

> “How do you safely deploy with Argo CD?”

```text
1. Review Git diff.
2. Render manifests if needed.
3. Check app diff in Argo CD.
4. Use sync waves for dependencies.
5. Use health checks and readiness.
6. Avoid broad prune without review.
7. Use AppProjects for guardrails.
8. Roll out through environments.
9. Monitor app health.
10. Roll back through Git if needed.
```

Interview version:

> “Argo CD makes deployment repeatable, but safety still depends on review, ordering, health checks, and clear ownership.”

---

# Common Argo CD interview traps and better answers

## Trap 1: “The app is OutOfSync. Should you sync it?”

Weak answer:

> “Yes.”

Better answer:

> “Not immediately. I would inspect the diff first and decide whether Git or live state is correct.”

---

## Trap 2: “Synced means the app is working, right?”

Weak answer:

> “Yes.”

Better answer:

> “No. Synced means manifests were applied. Healthy means Kubernetes resources are working as expected.”

---

## Trap 3: “Can we hotfix with kubectl?”

Weak answer:

> “Yes, just patch it.”

Better answer:

> “Only for emergency mitigation. With auto-sync/self-heal, Argo CD may revert it. The durable fix should go through Git.”

---

## Trap 4: “Can Argo CD deploy a new image just because it exists?”

Weak answer:

> “Yes.”

Better answer:

> “Not by default. Argo CD watches Git, not registries. Git must change, or image updater automation must update desired state.”

---

## Trap 5: “Prune is always safe?”

Weak answer:

> “Yes, it cleans up old resources.”

Better answer:

> “Prune is useful but dangerous. It deletes live resources missing from desired state. I would review ownership and app boundaries carefully.”

---

## Trap 6: “Argo CD RBAC is the same as Kubernetes RBAC?”

Weak answer:

> “Yes.”

Better answer:

> “No. Argo CD RBAC controls Argo CD actions. Kubernetes RBAC controls what Argo CD or users can do in the cluster.”

---

## Trap 7: “Helm values are obvious from Git?”

Weak answer:

> “Yes.”

Better answer:

> “Not always. Chart defaults, value file order, parameters, and inline values all affect the rendered manifests. I would inspect the rendered output.”

---

# Argo CD interview quick-reference table

| Issue | Main symptom | First thing to check | Common fix |
|---|---|---|---|
| OutOfSync | Git and live differ | App diff | Update Git or sync live |
| Degraded | Synced but unhealthy | App resources/pods | Fix Kubernetes runtime issue |
| Sync validation fail | API rejects manifest | Sync error | Fix manifest/policy/CRD |
| Repo failure | Cannot fetch Git | Repo status/logs | Fix URL, credentials, network |
| Manifest generation | Render fails | repo-server logs | Fix Helm/Kustomize/plugin |
| Helm values wrong | Wrong config deployed | Rendered manifests | Fix values order/overrides |
| Kustomize issue | Overlay fails | `kustomize build` | Fix path/patch/namespace |
| Missing CRD | No matches for kind | CRD existence | Order CRD before CR |
| Sync order issue | Resource applies too early | Waves/hooks | Add sync waves/hooks |
| Auto-sync hotfix revert | Manual fix disappears | Sync policy | Commit fix to Git |
| Prune deletion | Resource removed | Prune/app ownership | Restore Git/fix ownership |
| Finalizer stuck | Deletion hangs | Finalizers | Fix controller/remove carefully |
| Wrong destination | Wrong cluster/ns | Application destination | Fix server/name/namespace |
| Project block | Sync denied | AppProject | Allow repo/destination/kind |
| Argo RBAC deny | User cannot act | `argocd-rbac-cm` | Fix role/group mapping |
| Cluster access fail | Cannot deploy to cluster | Cluster credentials | Re-register/fix network/RBAC |
| K8s RBAC deny | Forbidden on apply | `kubectl auth can-i` | Grant required permissions |
| Image not deployed | New image ignored | Git image value | Update Git/use image updater |
| Progressing stuck | Never healthy | Rollout/pods | Fix readiness/runtime |
| Health Unknown | CR health unknown | CR status | Add custom health check |
| Diff noise | Always OutOfSync | Field owner | Narrow ignoreDifferences |
| App-of-apps issue | Child apps fail | Parent/child ordering | Add waves/bootstrap order |
| ApplicationSet issue | Wrong apps generated | Generator/template | Fix selector/template |
| Hook failure | Sync blocked | Hook job logs | Fix hook/idempotency |
| UI/API down | Argo unavailable | argocd-server logs | Fix ingress/server/SSO |
| Repo-server slow | Refresh slow | repo-server metrics/logs | Tune resources/repo layout |
| Controller overloaded | Status lag | controller logs/resources | Scale/tune/split apps |
| Rollback confusion | Bad deploy rollback | Git history | Revert Git/sync |
| Duplicate ownership | Apps fight | App resources | One owner per resource |
| Bad repo design | Unsafe deploys | Repo/app boundaries | Separate envs/ownership |

---

# Strong closing takeaway

Argo CD interviews are not just about knowing where the Sync button is. They are about showing that you understand GitOps control loops, desired state, drift, ownership, and production safety.

A weak answer sounds like:

> “I would sync the app.”

A strong answer sounds like:

> “I would inspect the diff, identify whether Git or live state is correct, check manifest rendering and Kubernetes events, verify the resource owner, and then sync or update Git safely.”

Argo CD problems usually leave evidence in:

```text
Application status
Application diff
Sync result
Resource health
Repo-server logs
Application-controller logs
Kubernetes events
Helm or Kustomize rendered output
AppProject policy
RBAC configuration
```

When you freeze, return to this sequence:

```text
Application → Source → Render → Diff → Sync → Kubernetes apply → Health → Drift → Ownership → Fix → Verify
```

That sequence will carry you through most Argo CD interview questions.

---

# Final takeaway summaries

## The one-minute summary

Argo CD issues usually come from repo access, manifest rendering, Helm values, Kustomize overlays, missing CRDs, sync ordering, hooks, Kubernetes validation, RBAC, AppProjects, cluster access, drift, prune, health checks, ApplicationSets, duplicate ownership, or poor GitOps repo structure. The best answer starts with Application status, diff, sync error, rendered manifests, controller logs, and Kubernetes events.

## The senior-engineer summary

A senior Argo CD engineer understands that Argo CD is a reconciliation system. They do not sync blindly, hotfix casually, ignore broad diffs, or let multiple apps own the same resource. They know that Synced is not the same as Healthy, Git should remain the source of truth, and prune/self-heal are powerful but risky. Seniority is shown by clear ownership, safe rollback, strong repo structure, and careful diagnosis.

## The interview survival summary

When your mind goes blank, say:

> “I would first check the Application status, sync result, and diff. Then I would determine whether the issue is repo access, manifest generation, Helm or Kustomize rendering, Kubernetes apply, RBAC, AppProject policy, destination cluster access, health assessment, drift, or prune behavior. I would fix the source of truth in Git where possible, sync safely, and verify the app is both Synced and Healthy.”

That answer works across most Argo CD interview scenarios.
