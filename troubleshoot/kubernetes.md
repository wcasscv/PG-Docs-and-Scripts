# Kubernetes: “I Know This Stuff, But in the Interview I Freeze” Kit

## Strong intro

You can work with Kubernetes regularly and still freeze in an interview.

That freeze does not mean you are weak. It usually means your knowledge is practical, not rehearsed. In real incidents, you inspect pods, check events, read logs, compare manifests, look at probes, verify services, inspect networking, check node pressure, and work from symptoms to evidence. In an interview, you are expected to compress that process into a clear answer in under two minutes.

This kit is built for that exact gap.

It gives you 30 common Kubernetes issues that interviewers ask about, with symptoms, causes, diagnostic commands, resolutions, and examples. The goal is not to memorize every command. The goal is to build answer patterns that help you stay calm when your mind goes blank.

When you freeze, use this sentence:

> “I would first identify whether the issue is with the pod, container, deployment, service, ingress, config, storage, node, scheduling, networking, RBAC, or cluster control plane. Then I would use `kubectl describe`, logs, events, resource usage, and the manifest to prove the cause before changing anything.”

That is the voice of someone who can troubleshoot Kubernetes in production.

---

## How to use this kit

For every Kubernetes problem, think in this order:

```text
Symptom → Scope → Evidence → Cause → Fix → Verify → Prevent
```

A strong interview answer usually includes:

1. What users or systems see.
2. Whether the issue affects one pod, one namespace, one node, one service, or the whole cluster.
3. What Kubernetes object is involved.
4. What command you run first.
5. What evidence proves the cause.
6. What safe fix you apply.
7. How you verify the fix.

Example:

> “If a pod is not starting, I would check pod status, events, container logs, image pull status, config references, probes, resource requests, and node scheduling. I would use `kubectl describe pod` first because events usually explain why Kubernetes cannot run or keep the pod healthy.”

That sounds like someone who has done real troubleshooting.

---

# Top 30 Kubernetes issues and resolutions

---

## 1. Pod stuck in Pending

### Interview freeze point

The interviewer asks:

> “A pod is stuck in Pending. What do you do?”

A pod in Pending usually means Kubernetes accepted the pod, but it has not been scheduled or cannot start.

### Strong interview answer

> “I would check `kubectl describe pod` and look at events. Pending usually points to scheduling problems such as insufficient CPU or memory, node selectors, taints and tolerations, affinity rules, unavailable persistent volumes, or quota limits.”

### Symptoms

- Pod status is `Pending`.
- No container logs exist yet.
- Deployment does not become ready.
- Events show scheduling failures.

### Diagnostic commands

```bash
kubectl get pods -n app
kubectl describe pod mypod -n app
kubectl get events -n app --sort-by=.lastTimestamp
kubectl get nodes
kubectl describe nodes
```

### Common causes

- Not enough CPU or memory.
- Node selector does not match any node.
- Taints block scheduling.
- Missing toleration.
- Required pod affinity cannot be satisfied.
- PersistentVolumeClaim is unbound.
- Namespace quota exceeded.
- Cluster autoscaler cannot add nodes.

### Example event

```text
0/5 nodes are available: 5 Insufficient memory.
```

### Resolution: reduce or correct resource requests

Bad example:

```yaml
resources:
  requests:
    memory: "64Gi"
    cpu: "16"
```

Better example:

```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "500m"
```

### Resolution: add toleration if intended

Node taint:

```bash
kubectl taint nodes node01 dedicated=app:NoSchedule
```

Pod toleration:

```yaml
tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "app"
    effect: "NoSchedule"
```

### Verify

```bash
kubectl get pod mypod -n app -o wide
kubectl describe pod mypod -n app
```

### Takeaway summary

Pending means the pod has not successfully landed on a node. Events usually tell you why.

---

## 2. Pod stuck in ImagePullBackOff or ErrImagePull

### Interview freeze point

The pod is created, but the container image cannot be pulled.

### Strong interview answer

> “I would check pod events for the exact image pull error. Common causes are wrong image name, wrong tag, private registry authentication failure, network access to the registry, image pull policy, or missing image pull secret.”

### Symptoms

- Pod status is `ImagePullBackOff`.
- Pod status is `ErrImagePull`.
- Events show image pull failure.
- Container never starts.

### Diagnostic commands

```bash
kubectl describe pod mypod -n app
kubectl get events -n app --sort-by=.lastTimestamp
kubectl get secret -n app
```

### Common causes

- Typo in image name.
- Image tag does not exist.
- Private registry credentials missing.
- Wrong namespace for image pull secret.
- Registry unavailable.
- Node cannot reach registry.
- Image pull secret not referenced.

### Bad example

```yaml
containers:
  - name: api
    image: private-registry.example.com/api:lates
```

The tag should likely be `latest`, not `lates`.

### Resolution: correct image tag

```yaml
containers:
  - name: api
    image: private-registry.example.com/api:1.2.3
```

### Resolution: use imagePullSecrets

Create secret:

```bash
kubectl create secret docker-registry regcred \
  --docker-server=private-registry.example.com \
  --docker-username=myuser \
  --docker-password=mypassword \
  --docker-email=me@example.com \
  -n app
```

Reference it:

```yaml
spec:
  imagePullSecrets:
    - name: regcred
  containers:
    - name: api
      image: private-registry.example.com/api:1.2.3
```

### Verify

```bash
kubectl describe pod mypod -n app
kubectl get pod mypod -n app
```

### Takeaway summary

ImagePullBackOff is usually registry, image name, tag, or credentials. Events contain the real reason.

---

## 3. CrashLoopBackOff

### Interview freeze point

Many candidates say “check logs,” which is correct but incomplete.

### Strong interview answer

> “CrashLoopBackOff means the container starts and exits repeatedly. I would check current and previous container logs, pod events, exit code, command/args, environment variables, config mounts, dependencies, and probes.”

### Symptoms

- Pod status is `CrashLoopBackOff`.
- Restart count increases.
- Application briefly starts then exits.
- Logs may disappear unless previous logs are checked.

### Diagnostic commands

```bash
kubectl get pod mypod -n app
kubectl describe pod mypod -n app
kubectl logs mypod -n app
kubectl logs mypod -n app --previous
```

### Common causes

- Application exits due to config error.
- Missing environment variable.
- Cannot connect to database.
- Bad command or args.
- File or secret missing.
- Permission issue.
- Liveness probe kills app too early.
- Out of memory kill.

### Example problem

```yaml
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: app-secret
        key: database_url
```

If the secret or key is missing, the container may fail.

### Resolution: create missing secret

```bash
kubectl create secret generic app-secret \
  --from-literal=database_url='postgres://user:pass@db:5432/app' \
  -n app
```

### Resolution: fix command

Bad:

```yaml
command: ["python"]
args: ["server.py --port 8080"]
```

Better:

```yaml
command: ["python"]
args: ["server.py", "--port", "8080"]
```

### Verify

```bash
kubectl get pod mypod -n app
kubectl logs mypod -n app
```

### Takeaway summary

CrashLoopBackOff means the container is failing after start. Check previous logs and exit reason.

---

## 4. Pod is Running but not Ready

### Interview freeze point

The pod looks healthy at first glance, but traffic does not reach it.

### Strong interview answer

> “Running only means containers are started. Ready means Kubernetes can send traffic to the pod. If a pod is Running but not Ready, I would check readiness probes, endpoints, app health endpoint, container ports, and dependencies.”

### Symptoms

- Pod status is `Running`.
- READY column shows `0/1`.
- Service has no endpoints.
- Deployment rollout is stuck.
- App is not receiving traffic.

### Diagnostic commands

```bash
kubectl get pods -n app
kubectl describe pod mypod -n app
kubectl get endpoints myservice -n app
kubectl logs mypod -n app
```

### Common causes

- Readiness probe fails.
- App listens on different port.
- Health endpoint returns non-200.
- App not initialized.
- Database dependency unavailable.
- Probe path wrong.
- Probe starts too early.

### Bad readiness probe

```yaml
readinessProbe:
  httpGet:
    path: /healthz
    port: 8080
```

But the app exposes `/ready` on port `8000`.

### Resolution

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 2
  failureThreshold: 3
```

### Verify endpoints

```bash
kubectl get endpoints myservice -n app
kubectl describe endpoints myservice -n app
```

### Takeaway summary

Running is not the same as Ready. Services only send traffic to ready pods.

---

## 5. Liveness probe causing restarts

### Interview freeze point

The app restarts repeatedly, but the real issue is the health check.

### Strong interview answer

> “I would check whether the liveness probe is too aggressive or pointed at the wrong endpoint. Liveness should detect a stuck process, not normal startup delay or dependency readiness. For startup delays, I would use a startup probe or tune initial delays.”

### Symptoms

- Pod restarts repeatedly.
- Logs show app was still starting.
- Events show liveness probe failed.
- Restart count increases.
- App works locally but not in cluster.

### Diagnostic command

```bash
kubectl describe pod mypod -n app
```

Look for:

```text
Liveness probe failed
Killing container
```

### Bad example

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 1
```

If the app takes 60 seconds to start, this probe kills it too early.

### Resolution: add startup probe

```yaml
startupProbe:
  httpGet:
    path: /health
    port: 8080
  failureThreshold: 30
  periodSeconds: 2

livenessProbe:
  httpGet:
    path: /health
    port: 8080
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  periodSeconds: 5
```

### Interview nuance

- Startup probe protects slow-starting apps.
- Readiness probe controls traffic.
- Liveness probe restarts unhealthy containers.

### Takeaway summary

Bad liveness probes create outages. Use liveness to detect deadlock, not normal startup or dependency delay.

---

## 6. Service not routing traffic to pods

### Interview freeze point

Pods are running, but the service does not work.

### Strong interview answer

> “I would check the service selector, pod labels, target port, endpoints, and namespace. A service routes to pods through label selectors. If selectors do not match pod labels, the service has no endpoints.”

### Symptoms

- Service DNS resolves but connection fails.
- Service has no endpoints.
- App works by pod IP but not service name.
- LoadBalancer has no working backend.

### Diagnostic commands

```bash
kubectl get svc -n app
kubectl describe svc api -n app
kubectl get endpoints api -n app
kubectl get pods -n app --show-labels
```

### Bad example

Service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  selector:
    app: api
  ports:
    - port: 80
      targetPort: 8080
```

Pods:

```yaml
metadata:
  labels:
    app: backend
```

The selector does not match.

### Resolution

Either fix service selector:

```yaml
selector:
  app: backend
```

Or fix pod labels:

```yaml
metadata:
  labels:
    app: api
```

### Port mismatch example

Container:

```yaml
ports:
  - containerPort: 8000
```

Service:

```yaml
ports:
  - port: 80
    targetPort: 8080
```

Fix:

```yaml
ports:
  - port: 80
    targetPort: 8000
```

### Verify

```bash
kubectl get endpoints api -n app
kubectl run test --rm -it --image=curlimages/curl -- sh
curl http://api.app.svc.cluster.local
```

### Takeaway summary

A Service is only as good as its selector and target port. Check endpoints first.

---

## 7. DNS resolution failure inside cluster

### Interview freeze point

The app cannot resolve another service by name.

### Strong interview answer

> “I would test DNS from inside the cluster, check service name and namespace, verify CoreDNS pods, check `/etc/resolv.conf`, and confirm network policies are not blocking DNS.”

### Symptoms

- App cannot resolve service name.
- Error: `no such host`.
- DNS works outside cluster but not inside.
- Only some namespaces affected.
- Pods cannot resolve external domains.

### Diagnostic commands

Run DNS test pod:

```bash
kubectl run dns-test --rm -it --image=busybox:1.36 --restart=Never -- nslookup kubernetes.default
```

Check service DNS:

```bash
kubectl run dns-test --rm -it --image=busybox:1.36 --restart=Never -- nslookup api.app.svc.cluster.local
```

Check CoreDNS:

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
kubectl get svc -n kube-system kube-dns
```

### Common causes

- Wrong service name.
- Wrong namespace.
- CoreDNS down.
- NetworkPolicy blocks DNS.
- Node DNS issue.
- Search domain confusion.
- Service does not exist.

### Example

From namespace `web`, this may fail:

```bash
curl http://api
```

If `api` is in namespace `app`, use:

```bash
curl http://api.app.svc.cluster.local
```

Or:

```bash
curl http://api.app
```

### NetworkPolicy DNS allowance example

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: app
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

### Takeaway summary

DNS failures are best tested from a pod. Confirm service name, namespace, CoreDNS health, and DNS egress.

---

## 8. Ingress not working

### Interview freeze point

The service works internally but not externally.

### Strong interview answer

> “I would check whether the ingress controller is installed and healthy, whether the ingress class matches, whether DNS points to the load balancer, whether TLS is configured, and whether the ingress backend service and port are correct.”

### Symptoms

- External URL returns 404.
- External URL times out.
- TLS error.
- Ingress has no address.
- Service works internally.
- Wrong backend receives traffic.

### Diagnostic commands

```bash
kubectl get ingress -A
kubectl describe ingress api -n app
kubectl get svc -n app
kubectl get endpoints api -n app
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### Common causes

- Ingress controller not installed.
- Wrong ingress class.
- DNS not pointing to load balancer.
- Service name or port wrong.
- TLS secret missing.
- Path rules incorrect.
- Backend service has no endpoints.
- Cloud load balancer not provisioned.

### Example ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api
  namespace: app
spec:
  ingressClassName: nginx
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api
                port:
                  number: 80
```

### TLS example

```yaml
spec:
  tls:
    - hosts:
        - api.example.com
      secretName: api-tls
```

Check secret:

```bash
kubectl get secret api-tls -n app
```

### Verify

```bash
kubectl get ingress api -n app
curl -I https://api.example.com
```

### Takeaway summary

Ingress problems are usually controller, class, DNS, TLS, path, or backend service issues.

---

## 9. NetworkPolicy blocking traffic

### Interview freeze point

The app worked before NetworkPolicy was added. Now traffic fails.

### Strong interview answer

> “NetworkPolicy is namespace and label based. Once a pod is selected by a policy, traffic not explicitly allowed may be denied depending on ingress or egress policy types. I would check pod labels, namespace labels, selected policies, and whether DNS or required dependencies are allowed.”

### Symptoms

- Service connection times out.
- DNS fails after egress policy.
- Only certain pods cannot connect.
- Same service works from another namespace.
- New policy caused outage.

### Diagnostic commands

```bash
kubectl get networkpolicy -n app
kubectl describe networkpolicy -n app
kubectl get pods -n app --show-labels
kubectl get ns --show-labels
```

### Example deny-all ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: app
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

This selects all pods and denies ingress unless another policy allows it.

### Allow web to api

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-web-to-api
  namespace: app
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: web
      ports:
        - protocol: TCP
          port: 8080
```

### Allow DNS egress

```yaml
egress:
  - to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: kube-system
    ports:
      - protocol: UDP
        port: 53
      - protocol: TCP
        port: 53
```

### Takeaway summary

NetworkPolicy failures are label and direction problems. Check selected pods, allowed peers, ports, and DNS egress.

---

## 10. ConfigMap or Secret not updating in running pods

### Interview freeze point

A ConfigMap changes but the app still uses old values.

### Strong interview answer

> “ConfigMaps and Secrets used as environment variables are read at container start. Updating them does not update existing env vars. If mounted as volumes, updates can eventually appear, but the app may not reload them. I would restart pods or design a reload mechanism.”

### Symptoms

- ConfigMap updated but app uses old value.
- Secret rotated but app still uses old password.
- Deployment rollout not triggered.
- Mounted file updated but app does not reload.
- Env var remains old until pod restart.

### Example ConfigMap env

```yaml
env:
  - name: LOG_LEVEL
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: log_level
```

Changing the ConfigMap does not change `LOG_LEVEL` in existing containers.

### Resolution: restart deployment

```bash
kubectl rollout restart deployment api -n app
```

### Resolution: checksum annotation pattern

In Helm-style templates:

```yaml
spec:
  template:
    metadata:
      annotations:
        checksum/config: "{{ include (print $.Template.BasePath \"/configmap.yaml\") . | sha256sum }}"
```

When config changes, pod template changes, triggering rollout.

### Secret example

```bash
kubectl create secret generic app-secret \
  --from-literal=password='new-password' \
  -n app \
  --dry-run=client -o yaml | kubectl apply -f -
```

Then:

```bash
kubectl rollout restart deployment api -n app
```

### Takeaway summary

ConfigMap and Secret changes do not always update running apps. Env var changes require pod restart.

---

## 11. Secret missing or wrong key

### Interview freeze point

The pod fails because Kubernetes cannot find a Secret or a specific key.

### Strong interview answer

> “I would check whether the Secret exists in the same namespace, whether the key name matches, and whether the pod references it correctly. Secrets are namespace-scoped, and key names are exact.”

### Symptoms

- Pod fails to start.
- `CreateContainerConfigError`.
- Event says secret not found.
- Event says key not found.
- App receives empty or wrong value.

### Diagnostic commands

```bash
kubectl describe pod mypod -n app
kubectl get secret -n app
kubectl describe secret app-secret -n app
```

### Example event

```text
Error: secret "app-secret" not found
```

or:

```text
couldn't find key database_url in Secret app-secret
```

### Bad example

```yaml
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: app-secret
        key: db_url
```

Secret contains:

```text
database_url
```

### Resolution

Fix key reference:

```yaml
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: app-secret
        key: database_url
```

Or create secret with correct key:

```bash
kubectl create secret generic app-secret \
  --from-literal=database_url='postgres://user:pass@db:5432/app' \
  -n app
```

### Takeaway summary

Secrets are namespace-scoped and key-sensitive. Check namespace, name, and key exactly.

---

## 12. Deployment rollout stuck

### Interview freeze point

A deployment update does not complete. Candidates need to connect ReplicaSets, pod readiness, and rollout status.

### Strong interview answer

> “I would check rollout status, describe the deployment, inspect the new ReplicaSet and pods, and determine whether the new pods are failing scheduling, image pull, probes, or readiness. A rollout is usually stuck because new pods do not become Ready.”

### Symptoms

- `kubectl rollout status` hangs.
- New pods fail readiness.
- Old pods remain running.
- Deployment does not reach desired replicas.
- Progress deadline exceeded.

### Diagnostic commands

```bash
kubectl rollout status deployment api -n app
kubectl describe deployment api -n app
kubectl get rs -n app
kubectl get pods -n app
kubectl describe pod <new-pod> -n app
```

### Common causes

- New image fails.
- Readiness probe fails.
- Insufficient resources.
- Bad config.
- Secret missing.
- New pods crash.
- Max unavailable/max surge settings too strict.
- Image pull failure.

### Example deployment strategy

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 1
```

This keeps availability but requires extra capacity.

### Resolution: rollback

```bash
kubectl rollout undo deployment api -n app
```

Check history:

```bash
kubectl rollout history deployment api -n app
```

Rollback to revision:

```bash
kubectl rollout undo deployment api -n app --to-revision=2
```

### Resolution: fix new version and reapply

```bash
kubectl apply -f deployment.yaml
kubectl rollout status deployment api -n app
```

### Takeaway summary

A stuck rollout usually means the new ReplicaSet cannot produce Ready pods. Debug the new pods.

---

## 13. Service account or RBAC permission denied

### Interview freeze point

The app or controller cannot access the Kubernetes API.

### Strong interview answer

> “I would identify which service account the pod uses, then check Role, ClusterRole, RoleBinding, and ClusterRoleBinding. I would use `kubectl auth can-i` to test the exact permission.”

### Symptoms

- `Forbidden`
- Controller logs show permission denied.
- App cannot list pods, configmaps, or secrets.
- Works as admin but not inside pod.
- Operator fails reconciliation.

### Diagnostic commands

```bash
kubectl get pod mypod -n app -o yaml | grep serviceAccountName
kubectl get sa -n app
kubectl get role,rolebinding -n app
kubectl get clusterrole,clusterrolebinding
kubectl auth can-i list pods --as=system:serviceaccount:app:app-sa -n app
```

### Example Role

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: app
  name: pod-reader
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
```

### Example RoleBinding

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-sa-pod-reader
  namespace: app
subjects:
  - kind: ServiceAccount
    name: app-sa
    namespace: app
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

### Verify

```bash
kubectl auth can-i list pods --as=system:serviceaccount:app:app-sa -n app
```

### Takeaway summary

RBAC issues are identity plus verb plus resource plus namespace. Test the exact action.

---

## 14. PersistentVolumeClaim stuck Pending

### Interview freeze point

The pod cannot start because storage is not bound.

### Strong interview answer

> “I would check the PVC, StorageClass, provisioner, access mode, requested size, and events. A PVC stuck Pending often means no matching PV exists or dynamic provisioning failed.”

### Symptoms

- PVC status is `Pending`.
- Pod using PVC is Pending.
- Events show provisioning failure.
- StorageClass missing.
- Access mode not supported.

### Diagnostic commands

```bash
kubectl get pvc -n app
kubectl describe pvc data -n app
kubectl get storageclass
kubectl get pv
kubectl get events -n app --sort-by=.lastTimestamp
```

### Example PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data
  namespace: app
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: standard
  resources:
    requests:
      storage: 10Gi
```

### Common causes

- StorageClass does not exist.
- Cloud storage provisioner broken.
- Requested access mode unsupported.
- Requested size unavailable.
- Static PV selector mismatch.
- Volume zone conflicts with node scheduling.
- Missing CSI driver.

### Resolution: correct StorageClass

```yaml
storageClassName: gp3
```

Check:

```bash
kubectl get storageclass
```

### Resolution: install/fix CSI driver

Check CSI pods:

```bash
kubectl get pods -n kube-system | grep csi
```

### Takeaway summary

PVC Pending is a storage binding problem. Check events, StorageClass, provisioner, access mode, and zone.

---

## 15. Volume mount failure

### Interview freeze point

The PVC is bound, but the pod still cannot mount the volume.

### Strong interview answer

> “If the PVC is bound but the pod cannot mount, I would check pod events, CSI driver logs, node attachment, filesystem permissions, access mode conflicts, and whether another node already has the volume attached.”

### Symptoms

- Pod stuck in `ContainerCreating`.
- Events show mount failure.
- Volume attach timeout.
- Permission denied inside container.
- Multi-attach error.

### Diagnostic commands

```bash
kubectl describe pod mypod -n app
kubectl describe pvc data -n app
kubectl get pv
kubectl get volumeattachment
kubectl logs -n kube-system -l app=csi-controller
```

### Common causes

- Volume already attached to another node.
- Access mode `ReadWriteOnce` used by pods on different nodes.
- CSI driver issue.
- Node cannot attach volume.
- Filesystem permission mismatch.
- Secret for storage backend missing.
- SELinux or security context issue.

### Multi-attach example

```text
Multi-Attach error for volume "pvc-..." Volume is already used by pod...
```

### Resolution

If using `ReadWriteOnce`, keep replicas on same node only if safe, or use storage supporting `ReadWriteMany`.

Example:

```yaml
accessModes:
  - ReadWriteMany
```

Only works if the storage provider supports it.

### Fix permissions with securityContext

```yaml
securityContext:
  fsGroup: 1000
```

### Takeaway summary

Bound PVC does not guarantee successful mount. Check node attachment, access mode, CSI, and permissions.

---

## 16. OOMKilled

### Interview freeze point

The pod restarts, but the cause is memory limit.

### Strong interview answer

> “OOMKilled means the container exceeded its memory limit or the node killed it due to memory pressure. I would check pod status, previous termination reason, memory limits, application memory usage, and node pressure.”

### Symptoms

- Pod restart count increases.
- Last state shows `OOMKilled`.
- Exit code 137.
- App dies under load.
- Node memory pressure.

### Diagnostic commands

```bash
kubectl describe pod mypod -n app
kubectl top pod mypod -n app
kubectl top node
kubectl logs mypod -n app --previous
```

### Example status

```text
Last State: Terminated
Reason: OOMKilled
Exit Code: 137
```

### Bad example

```yaml
resources:
  requests:
    memory: "128Mi"
  limits:
    memory: "128Mi"
```

If app normally uses 300Mi, it will be killed.

### Resolution

Set realistic requests and limits:

```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "500m"
```

Also fix the app if memory is leaking.

### Verify

```bash
kubectl top pod -n app
kubectl describe pod mypod -n app
```

### Takeaway summary

OOMKilled is evidence of memory pressure. Fix sizing, workload behavior, or memory leaks.

---

## 17. CPU throttling and poor performance

### Interview freeze point

The app is slow, but pods are not crashing.

### Strong interview answer

> “If performance is poor, I would check CPU requests and limits. CPU limits can throttle containers even when node CPU is available. I would compare application latency with CPU throttling metrics and consider removing or raising CPU limits while keeping requests for scheduling.”

### Symptoms

- High latency.
- No pod restarts.
- CPU usage near limit.
- App slow under load.
- Metrics show throttling.

### Diagnostic commands

```bash
kubectl top pod -n app
kubectl describe pod mypod -n app
```

For detailed throttling, use metrics from Prometheus/cAdvisor if available.

### Example

```yaml
resources:
  requests:
    cpu: "100m"
  limits:
    cpu: "100m"
```

This restricts the app to one tenth of a CPU.

### Resolution

```yaml
resources:
  requests:
    cpu: "250m"
  limits:
    cpu: "1"
```

Or, for some latency-sensitive services, use requests without CPU limits depending on platform policy:

```yaml
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"
  limits:
    memory: "1Gi"
```

### Interview nuance

Memory limits are hard safety boundaries. CPU limits cause throttling. CPU requests affect scheduling.

### Takeaway summary

CPU throttling can make healthy pods slow. Check limits, requests, and workload metrics.

---

## 18. Node NotReady

### Interview freeze point

Pods are failing, but the root issue is the node.

### Strong interview answer

> “If a node is NotReady, I would check node conditions, kubelet status, container runtime, disk, memory, network, and cloud provider health. Then I would cordon or drain if needed to protect workloads.”

### Symptoms

- Node status `NotReady`.
- Pods stuck terminating or unknown.
- New pods not scheduled to node.
- Kubelet not reporting.
- Node pressure conditions.

### Diagnostic commands

```bash
kubectl get nodes
kubectl describe node node01
kubectl get pods -A -o wide | grep node01
```

On node:

```bash
systemctl status kubelet
systemctl status containerd
journalctl -u kubelet -n 100
df -h
free -m
```

### Common causes

- Kubelet stopped.
- Container runtime down.
- Node disk full.
- Network plugin broken.
- Certificate issue.
- Cloud VM unhealthy.
- Memory pressure.
- Kernel or OS issue.

### Resolution

Cordon node:

```bash
kubectl cordon node01
```

Drain node:

```bash
kubectl drain node01 --ignore-daemonsets --delete-emptydir-data
```

After repair:

```bash
kubectl uncordon node01
```

### Takeaway summary

Node NotReady is usually kubelet, runtime, disk, memory, network, or VM health. Protect workloads before repair.

---

## 19. DiskPressure or node ephemeral storage full

### Interview freeze point

Pods are evicted and the root cause is node disk pressure.

### Strong interview answer

> “DiskPressure means the node is low on disk or ephemeral storage. I would check node conditions, image cache, container logs, emptyDir usage, and ephemeral storage requests/limits. Then I would clean safely and prevent recurrence with limits and log management.”

### Symptoms

- Pods evicted.
- Node condition shows DiskPressure.
- Image pulls fail.
- Kubelet garbage collection messages.
- Node filesystem full.

### Diagnostic commands

```bash
kubectl describe node node01
kubectl get events -A --sort-by=.lastTimestamp
kubectl describe pod evicted-pod -n app
```

On node:

```bash
df -h
du -sh /var/lib/containerd/*
journalctl -u kubelet -n 100
```

### Common causes

- Huge container logs.
- Too many unused images.
- `emptyDir` grows too large.
- App writes to container filesystem.
- No ephemeral storage limits.
- Node disk too small.

### Resolution: set ephemeral storage

```yaml
resources:
  requests:
    ephemeral-storage: "1Gi"
  limits:
    ephemeral-storage: "2Gi"
```

### Resolution: use persistent volume for data

```yaml
volumeMounts:
  - name: data
    mountPath: /var/lib/app
volumes:
  - name: data
    persistentVolumeClaim:
      claimName: app-data
```

### Takeaway summary

DiskPressure is often logs, images, or ephemeral data. Apps should not write unbounded data to node-local storage.

---

## 20. Namespace ResourceQuota or LimitRange blocking workloads

### Interview freeze point

The pod spec looks fine, but admission fails.

### Strong interview answer

> “I would check namespace ResourceQuota and LimitRange. A pod can be rejected if it exceeds quota or does not specify required requests and limits.”

### Symptoms

- Pod creation rejected.
- Error says exceeded quota.
- Deployment cannot create replicas.
- Missing CPU/memory request error.
- Works in one namespace but not another.

### Diagnostic commands

```bash
kubectl get resourcequota -n app
kubectl describe resourcequota -n app
kubectl get limitrange -n app
kubectl describe limitrange -n app
kubectl get events -n app --sort-by=.lastTimestamp
```

### Example ResourceQuota

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: app-quota
  namespace: app
spec:
  hard:
    requests.cpu: "4"
    requests.memory: "8Gi"
    limits.cpu: "8"
    limits.memory: "16Gi"
    pods: "20"
```

### Example LimitRange

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: app-limits
  namespace: app
spec:
  limits:
    - type: Container
      default:
        cpu: "500m"
        memory: "512Mi"
      defaultRequest:
        cpu: "100m"
        memory: "128Mi"
```

### Resolution

Set requests/limits:

```yaml
resources:
  requests:
    cpu: "250m"
    memory: "256Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

Or increase quota if justified.

### Takeaway summary

Quota and LimitRange are admission controls. Check them when a valid-looking pod cannot be created.

---

## 21. HPA not scaling

### Interview freeze point

The HorizontalPodAutoscaler exists but replicas do not change.

### Strong interview answer

> “I would check whether the HPA can read metrics, whether the metrics server or custom metrics adapter is working, whether pods have CPU requests, and whether min/max replicas or stabilization behavior explain the current replica count.”

### Symptoms

- HPA shows `<unknown>` metrics.
- Replicas do not increase under load.
- HPA exists but does nothing.
- CPU target configured but no CPU request.
- Metrics server missing.

### Diagnostic commands

```bash
kubectl get hpa -n app
kubectl describe hpa api -n app
kubectl top pods -n app
kubectl get apiservices | grep metrics
kubectl get pods -n kube-system | grep metrics-server
```

### Example HPA

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api
  namespace: app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

### Required pod resources

```yaml
resources:
  requests:
    cpu: "250m"
    memory: "256Mi"
```

CPU utilization scaling depends on CPU requests.

### Common causes

- Metrics server missing or broken.
- Pods missing CPU requests.
- Wrong scale target.
- Load not reaching pods.
- Max replicas already reached.
- Stabilization window delays scaling.
- Custom metrics adapter broken.

### Takeaway summary

HPA needs metrics and resource requests. If metrics are unknown, fix observability before tuning scaling.

---

## 22. Cluster autoscaler not adding nodes

### Interview freeze point

Pods are Pending, but new nodes are not created.

### Strong interview answer

> “I would check whether Pending pods are schedulable if more nodes existed, whether node groups can scale, whether autoscaler sees the node group, and whether cloud quotas, taints, labels, or resource requests prevent scale-up.”

### Symptoms

- Pods Pending due to resources.
- No new nodes appear.
- Autoscaler logs show no scale-up.
- Node group max size reached.
- Cloud quota exhausted.

### Diagnostic commands

```bash
kubectl describe pod pending-pod -n app
kubectl get nodes
kubectl logs -n kube-system deployment/cluster-autoscaler
```

### Common causes

- Node group max size reached.
- Cloud quota limit.
- Pod requests too large for any node type.
- Taints/labels make nodes unsuitable.
- Autoscaler not configured for node group.
- PVC zone constraints.
- Pod has strict affinity.
- PDB or drain issues during scale-down.

### Example issue

Pod requests:

```yaml
resources:
  requests:
    cpu: "64"
    memory: "256Gi"
```

No node type in the autoscaling group can fit it.

### Resolution

- Increase node group max size.
- Add larger node type.
- Fix pod requests.
- Fix labels/taints.
- Resolve cloud quota.
- Check autoscaler IAM permissions.
- Review autoscaler logs.

### Takeaway summary

Cluster autoscaler only helps if adding a node can actually schedule the pod.

---

## 23. StatefulSet issues

### Interview freeze point

StatefulSets look like Deployments but behave differently.

### Strong interview answer

> “StatefulSets provide stable pod identity, ordered rollout, and stable storage. If a StatefulSet is stuck, I would check pod ordinal, PVC binding, readiness, update strategy, and whether an earlier pod is blocking later pods.”

### Symptoms

- `web-0` starts but `web-1` does not.
- Rollout stuck on one ordinal.
- PVC not deleted when pod is deleted.
- Pod identity matters.
- Update waits forever.

### Diagnostic commands

```bash
kubectl get statefulset -n app
kubectl describe statefulset db -n app
kubectl get pods -n app
kubectl get pvc -n app
kubectl describe pod db-0 -n app
```

### Example StatefulSet

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
  namespace: app
spec:
  serviceName: db
  replicas: 3
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
        - name: db
          image: postgres:16
          ports:
            - containerPort: 5432
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 20Gi
```

### Common causes

- PVC Pending.
- Pod `0` not Ready, blocking pod `1`.
- Bad readiness probe.
- Storage class issue.
- Ordered rollout behavior misunderstood.
- Headless service missing.
- Manual PVC cleanup expected but not automatic.

### Resolution

Fix the first failing ordinal:

```bash
kubectl describe pod db-0 -n app
kubectl logs db-0 -n app
```

Check PVC:

```bash
kubectl get pvc -n app
```

### Takeaway summary

StatefulSets are ordered and identity-based. Debug the lowest failing ordinal first.

---

## 24. DaemonSet not running on all nodes

### Interview freeze point

A logging or monitoring agent is missing from some nodes.

### Strong interview answer

> “DaemonSets run one pod per eligible node. If pods are missing, I would check node selectors, taints and tolerations, affinity, resource pressure, and whether the DaemonSet is allowed on control-plane nodes.”

### Symptoms

- Agent missing from some nodes.
- Desired number lower than node count.
- Pods Pending on tainted nodes.
- Control-plane nodes excluded.
- New nodes do not get agent.

### Diagnostic commands

```bash
kubectl get daemonset -A
kubectl describe daemonset log-agent -n monitoring
kubectl get pods -n monitoring -o wide
kubectl describe node node01
```

### Common causes

- Node selector excludes nodes.
- Taints not tolerated.
- Resource requests too high.
- Affinity rules too strict.
- Control-plane taints not tolerated.
- Unsupported node OS/architecture.

### Toleration example

```yaml
tolerations:
  - operator: "Exists"
```

This tolerates all taints. Use carefully.

Control-plane toleration example:

```yaml
tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"
```

### Takeaway summary

DaemonSets run on eligible nodes, not necessarily every node. Check eligibility rules.

---

## 25. Job or CronJob failing

### Interview freeze point

A batch workload fails but disappears or retries.

### Strong interview answer

> “For Jobs and CronJobs, I would check job pods, logs, completion status, backoff limit, schedule, concurrency policy, service account, and whether failed pods are retained long enough to debug.”

### Symptoms

- Job never completes.
- CronJob does not run.
- CronJob runs too often or overlaps.
- Pods fail then disappear.
- Backoff limit exceeded.

### Diagnostic commands

```bash
kubectl get cronjob -n app
kubectl describe cronjob cleanup -n app
kubectl get job -n app
kubectl describe job cleanup-123 -n app
kubectl get pods -n app
kubectl logs job/cleanup-123 -n app
```

### Example CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup
  namespace: app
spec:
  schedule: "0 2 * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 2
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: cleanup
              image: app-cleanup:1.0.0
              command: ["./cleanup.sh"]
```

### Common causes

- Wrong schedule.
- Wrong timezone assumption.
- Image pull failure.
- Command exits non-zero.
- Missing secret/config.
- Service account lacks permissions.
- Concurrency policy blocks new run.
- Backoff limit reached.
- Restart policy wrong.

### Takeaway summary

Jobs are debugged through the pods they create. Check pod logs, job events, and retry policy.

---

## 26. Admission webhook blocking resources

### Interview freeze point

The manifest is valid, but the API server rejects it due to a webhook.

### Strong interview answer

> “If admission fails, I would read the rejection message and identify the validating or mutating webhook. Then I would check webhook service availability, certificates, timeout policy, failure policy, and whether the object violates a policy.”

### Symptoms

- `kubectl apply` fails.
- Error mentions admission webhook.
- Deployments blocked cluster-wide.
- Webhook service unavailable.
- Certificate error.
- Policy denies image, labels, privileges, or resources.

### Diagnostic commands

```bash
kubectl get validatingwebhookconfiguration
kubectl get mutatingwebhookconfiguration
kubectl describe validatingwebhookconfiguration <name>
kubectl get pods -A | grep webhook
kubectl get svc -A | grep webhook
```

### Example error

```text
admission webhook "validate.example.com" denied the request
```

or:

```text
failed calling webhook: service "policy-webhook" not found
```

### Common causes

- Policy violation.
- Webhook pod down.
- Webhook service missing.
- TLS certificate expired.
- Network path blocked.
- Failure policy set to Fail.
- Timeout too low.

### Resolution

If policy violation, fix manifest:

```yaml
metadata:
  labels:
    owner: platform
    environment: prod
```

If webhook is down, repair webhook deployment or service.

Emergency option only with change control:

```yaml
failurePolicy: Ignore
```

This can reduce safety, so use carefully.

### Takeaway summary

Admission webhooks can block valid Kubernetes YAML because they enforce cluster policy or mutate objects.

---

## 27. Pod Security or security context issue

### Interview freeze point

A workload fails because it violates security settings.

### Strong interview answer

> “I would check namespace Pod Security settings, admission errors, container securityContext, privileged mode, hostPath usage, runAsUser, capabilities, and whether the image can run as non-root.”

### Symptoms

- Pod rejected by admission.
- Error mentions restricted policy.
- Container cannot write to filesystem.
- App fails as non-root.
- Permission denied on mounted volume.
- Privileged container blocked.

### Diagnostic commands

```bash
kubectl describe pod mypod -n app
kubectl get ns app --show-labels
kubectl get events -n app --sort-by=.lastTimestamp
```

### Secure example

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

containers:
  - name: api
    image: api:1.0.0
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
          - ALL
```

### Common causes

- Image requires root.
- Container writes to read-only filesystem.
- Missing writable volume for temp files.
- Needs Linux capability not allowed.
- hostPath blocked.
- Privileged mode denied.
- Volume permissions wrong.

### Resolution: add writable tmp volume

```yaml
volumeMounts:
  - name: tmp
    mountPath: /tmp

volumes:
  - name: tmp
    emptyDir: {}
```

### Takeaway summary

Security context failures often reveal image assumptions. Build images that can run as non-root.

---

## 28. API server or control plane issue

### Interview freeze point

The whole cluster seems broken. Strong candidates know how to separate workload from control plane issues.

### Strong interview answer

> “If the control plane is unhealthy, I would check API server availability, etcd health, scheduler, controller manager, cloud-controller-manager, certificates, and node connectivity. I would also check whether the issue is only kubectl access or actual cluster control plane health.”

### Symptoms

- `kubectl` times out.
- New pods not scheduled.
- Deployments do not reconcile.
- Nodes stop updating status.
- API requests fail.
- Controllers not acting.

### Diagnostic commands

```bash
kubectl cluster-info
kubectl get componentstatuses
kubectl get pods -n kube-system
kubectl get --raw='/readyz?verbose'
kubectl get --raw='/livez?verbose'
```

On control plane node where applicable:

```bash
journalctl -u kubelet -n 100
crictl ps
```

### Common causes

- API server down.
- etcd unhealthy.
- Expired certificates.
- Control plane node down.
- Network issue.
- Overloaded API server.
- Broken admission webhook.
- Cloud provider issue.

### Resolution

Depends on cluster type:

- Managed Kubernetes: check provider control plane health and open support incident if needed.
- Self-managed: check static pods, etcd, certificates, kubelet, and control plane logs.
- If webhook blocks API requests, repair or disable carefully.
- If API overloaded, reduce noisy clients/controllers.

### Takeaway summary

Control plane issues affect cluster decision-making. Separate API access problems from workload runtime problems.

---

## 29. etcd pressure or failure

### Interview freeze point

etcd is often hidden in managed clusters, but interviewers may ask because it is core to Kubernetes.

### Strong interview answer

> “etcd stores Kubernetes cluster state. If etcd is unhealthy, the API server and controllers suffer. I would check etcd health, disk latency, leader stability, database size, alarms, and backups. For production, tested etcd backups are critical.”

### Symptoms

- API server slow.
- Writes fail.
- Leader changes frequently.
- Control plane unstable.
- Cluster state operations time out.
- etcd disk full or latency high.

### Diagnostic examples for self-managed clusters

```bash
ETCDCTL_API=3 etcdctl endpoint health
ETCDCTL_API=3 etcdctl endpoint status --write-out=table
ETCDCTL_API=3 etcdctl alarm list
```

Snapshot backup:

```bash
ETCDCTL_API=3 etcdctl snapshot save snapshot.db
```

### Common causes

- Slow disk.
- etcd database too large.
- Network issues between members.
- Disk full.
- Too many API writes.
- Faulty member.
- No compaction/defrag where needed.
- Certificate issues.

### Resolution options

- Restore etcd quorum.
- Fix disk latency.
- Remove unhealthy member carefully.
- Compact/defrag as appropriate.
- Reduce noisy controllers.
- Restore from tested backup if needed.

### Takeaway summary

etcd is the source of cluster truth. Protect it with fast disk, monitoring, quorum health, and tested backups.

---

## 30. Helm release failure or bad chart values

### Interview freeze point

Kubernetes objects are generated by Helm, so the raw manifest may not be obvious.

### Strong interview answer

> “For Helm issues, I would render the chart locally with values, inspect the generated manifests, check release history, and compare what Helm thinks is installed with what exists in the cluster. Many Helm failures are wrong values, template errors, immutable field changes, or failed hooks.”

### Symptoms

- `helm install` fails.
- `helm upgrade` fails.
- Chart renders invalid YAML.
- Wrong image or resource value.
- Release stuck in failed state.
- Hook job fails.
- Kubernetes rejects immutable field change.

### Diagnostic commands

```bash
helm list -n app
helm status api -n app
helm history api -n app
helm get values api -n app
helm get manifest api -n app
helm template api ./chart -f values-prod.yaml
helm lint ./chart
```

### Example values problem

Values:

```yaml
image:
  repository: my-registry/api
  tag: ""
```

Template:

```yaml
image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
```

Rendered image becomes invalid:

```text
my-registry/api:
```

### Resolution

Set valid values:

```yaml
image:
  repository: my-registry/api
  tag: "1.2.3"
```

Upgrade:

```bash
helm upgrade api ./chart -n app -f values-prod.yaml
```

Rollback:

```bash
helm rollback api 3 -n app
```

### Immutable field problem

Changing a Service `clusterIP` or certain StatefulSet fields may fail. The fix may require careful delete/recreate or chart change, depending on object and risk.

### Takeaway summary

For Helm, debug the rendered manifests. Kubernetes runs YAML, not intentions.

---

# Bonus: Kubernetes interview answer frameworks

## Framework 1: The pod troubleshooting answer

Use this when asked:

> “A pod is not working. How do you troubleshoot?”

```text
1. Check pod status.
2. Describe the pod and read events.
3. Check container logs, including previous logs.
4. Check image pull, command, args, env, secrets, config.
5. Check probes.
6. Check resources and OOM/CPU throttling.
7. Check node placement and scheduling.
8. Check service endpoints if traffic is involved.
9. Apply the smallest safe fix.
10. Verify status, logs, readiness, and traffic.
```

Interview version:

> “I start with `kubectl describe pod` because events often tell me whether the problem is scheduling, image pull, config, probes, or volume mounts. Then I use logs to understand app-level failure.”

---

## Framework 2: The service/networking answer

Use this when asked:

> “Pods are running, but the app is unreachable.”

```text
1. Check pod readiness.
2. Check service selector.
3. Check endpoints.
4. Check targetPort and containerPort.
5. Test from inside the cluster.
6. Check DNS.
7. Check NetworkPolicy.
8. Check ingress/controller/load balancer.
9. Check external DNS/TLS/firewall.
10. Verify with curl from multiple points.
```

Interview version:

> “I would follow traffic path: client → DNS → ingress/load balancer → service → endpoints → pod port → application.”

---

## Framework 3: The deployment rollout answer

Use this when asked:

> “A deployment is stuck. What do you do?”

```text
1. Check rollout status.
2. Describe deployment.
3. Identify new ReplicaSet.
4. Inspect new pods.
5. Check image, config, probes, resources, scheduling.
6. Decide fix forward or rollback.
7. Use rollout history and undo if needed.
8. Verify readiness and endpoints.
```

Interview version:

> “A rollout is stuck because the new ReplicaSet cannot create enough Ready pods. I debug the new pods, not the old healthy ones.”

---

## Framework 4: The node health answer

Use this when asked:

> “A node is unhealthy. What do you do?”

```text
1. Check node condition.
2. Identify affected pods.
3. Cordon to stop new scheduling.
4. Drain if needed and safe.
5. Check kubelet, runtime, disk, memory, network.
6. Repair or replace node.
7. Uncordon after validation.
8. Investigate recurrence.
```

Interview version:

> “I protect workloads first with cordon or drain, then troubleshoot kubelet, runtime, disk, memory, and networking.”

---

## Framework 5: The production safety answer

Use this when asked:

> “How do you safely change Kubernetes production workloads?”

```text
1. Review manifest diff.
2. Confirm namespace and context.
3. Use staging first.
4. Use readiness probes.
5. Use rolling updates.
6. Use PodDisruptionBudgets.
7. Watch rollout.
8. Monitor logs and metrics.
9. Roll back if health degrades.
10. Capture prevention actions.
```

Interview version:

> “I treat Kubernetes changes as production releases. I confirm context, review diff, roll gradually, watch readiness, and keep rollback ready.”

---

# Common Kubernetes interview traps and better answers

## Trap 1: “The pod is Running, so it is healthy, right?”

Weak answer:

> “Yes.”

Better answer:

> “Not necessarily. Running means the container started. Ready means it can receive traffic. I would check readiness, logs, and service endpoints.”

---

## Trap 2: “Should we delete the pod?”

Weak answer:

> “Yes, deleting the pod fixes it.”

Better answer:

> “Deleting a pod may temporarily restart it, but I would first understand why it failed. If the controller recreates it with the same bad config, the problem returns.”

---

## Trap 3: “The service does not work. Is Kubernetes networking broken?”

Weak answer:

> “Probably.”

Better answer:

> “I would first check selectors and endpoints. Many service issues are label or targetPort mismatches, not cluster networking failures.”

---

## Trap 4: “Can we set high resource limits to be safe?”

Weak answer:

> “Yes.”

Better answer:

> “Requests and limits affect scheduling and runtime. Overstated requests cause Pending pods. Low memory limits cause OOMKills. Low CPU limits cause throttling. I would size from real usage.”

---

## Trap 5: “Can we use liveness for all health checks?”

Weak answer:

> “Yes.”

Better answer:

> “No. Liveness restarts containers. Readiness controls traffic. Startup protects slow boot. Mixing them badly can cause outages.”

---

## Trap 6: “Can we just use latest image tag?”

Weak answer:

> “Yes, it gets the newest version.”

Better answer:

> “I avoid `latest` in production because it is not reproducible. I prefer immutable version tags or digests.”

---

## Trap 7: “Does ConfigMap update restart pods?”

Weak answer:

> “Yes.”

Better answer:

> “Not automatically. Env vars are fixed at container start. Mounted files may update, but the app must reload them. Often a rollout restart is needed.”

---

## Trap 8: “Is Helm the source of truth?”

Weak answer:

> “Yes.”

Better answer:

> “Helm manages releases, but Kubernetes runs the rendered manifests. I debug both Helm values and the generated Kubernetes objects.”

---

# Kubernetes interview quick-reference table

| Issue | Main symptom | First thing to check | Common fix |
|---|---|---|---|
| Pod Pending | Pod not scheduled | Pod events | Fix resources, taints, PVC, affinity |
| ImagePullBackOff | Image cannot pull | Pod events | Fix image, tag, registry secret |
| CrashLoopBackOff | Container restarts | Previous logs | Fix app/config/probe/OOM |
| Running not Ready | No traffic to pod | Readiness probe | Fix probe/app dependency |
| Liveness restarts | Repeated restarts | Events | Add startup probe/tune liveness |
| Service broken | No routing | Endpoints | Fix selector or targetPort |
| DNS failure | Name not resolving | Test pod/CoreDNS | Fix service name, CoreDNS, DNS egress |
| Ingress broken | External access fails | Ingress/controller | Fix class, DNS, TLS, backend |
| NetworkPolicy block | Connection timeout | Policies and labels | Allow ingress/egress/DNS |
| Config not updating | Old config used | Env vs volume | Restart pods/reload app |
| Secret missing | Config error | Pod events | Create/fix secret/key |
| Rollout stuck | Deployment not ready | New pods | Fix image/probe/config or rollback |
| RBAC denied | Forbidden | `auth can-i` | Fix Role/Binding |
| PVC Pending | Storage not bound | PVC events | Fix StorageClass/provisioner |
| Mount failure | ContainerCreating | Pod events | Fix CSI, access mode, permissions |
| OOMKilled | Exit 137 | Pod status | Increase memory/fix leak |
| CPU throttling | Slow app | CPU limits/metrics | Adjust CPU requests/limits |
| Node NotReady | Node unhealthy | Node describe | Fix kubelet/runtime/node |
| DiskPressure | Pod eviction | Node conditions | Clean disk/set storage limits |
| Quota blocked | Admission denied | ResourceQuota | Set requests/increase quota |
| HPA not scaling | Replicas unchanged | HPA describe | Fix metrics/requests |
| Autoscaler stuck | Pending pods remain | Autoscaler logs | Fix node group/requests/quota |
| StatefulSet stuck | Ordered rollout blocked | Lowest ordinal pod | Fix PVC/readiness/storage |
| DaemonSet missing | Agent not on node | DaemonSet describe | Fix taints/selectors/resources |
| Job failing | Batch not complete | Job pod logs | Fix command/config/backoff |
| Webhook blocking | Apply denied | Admission message | Fix policy/webhook |
| Security issue | Pod rejected | Events/securityContext | Run non-root/fix policy |
| API server issue | Cluster API failing | `/readyz` | Check control plane |
| etcd issue | Control plane unstable | etcd health | Fix quorum/disk/backup |
| Helm issue | Release failed | Rendered manifest | Fix values/templates/hooks |

---

# Strong closing takeaway

Kubernetes interviews are not just command tests. They are production reasoning tests.

A weak answer sounds like this:

> “I would restart the pod.”

A strong answer sounds like this:

> “I would check the pod status, events, logs, readiness, service endpoints, node placement, resources, and recent changes. Then I would apply the smallest safe fix and verify from both Kubernetes status and application behavior.”

Kubernetes is a system of controllers. Most failures are not random. They leave evidence in object status, events, logs, metrics, and manifests.

When you freeze, return to this sequence:

```text
Context → Namespace → Object → Status → Events → Logs → Config → Network → Node → Fix → Verify
```

That sequence will carry you through most Kubernetes interview questions.

---

# Final takeaway summaries

## The one-minute summary

Kubernetes problems usually come from scheduling, image pulls, crashes, probes, services, DNS, ingress, NetworkPolicy, ConfigMaps, Secrets, storage, resources, nodes, RBAC, autoscaling, security policy, or control plane health. The best answer starts with `kubectl describe`, events, logs, and scope.

## The senior-engineer summary

A senior Kubernetes engineer does not randomly delete pods. They follow the control loop. They know that a pod can be Running but not Ready, a service can exist without endpoints, a ConfigMap can change without updating env vars, and a liveness probe can cause an outage. They understand resources, rollout safety, node health, and blast radius.

## The interview survival summary

When your mind goes blank, say:

> “I would first confirm the namespace and object, then check status, events, logs, resource usage, probes, service endpoints, and node placement. I would determine whether the issue is scheduling, image pull, app crash, config, network, storage, RBAC, or node health. Then I would make the smallest safe fix and verify the workload is Ready and receiving traffic.”

That answer works across most Kubernetes interview scenarios.
