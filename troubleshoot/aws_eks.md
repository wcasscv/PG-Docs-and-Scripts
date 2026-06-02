# AWS EKS: “I Know This Stuff, But in the Interview I Freeze” Kit

## Strong intro

You can run workloads on Amazon EKS every week and still freeze in an interview.

That freeze usually does not mean you lack Kubernetes or AWS experience. It means your knowledge is stored as real incident muscle memory: checking node readiness, reading pod events, tracing AWS IAM permissions, debugging CNI IP exhaustion, fixing load balancer annotations, checking CoreDNS, reviewing security groups, inspecting `aws-auth` or access entries, testing IRSA or Pod Identity, and asking, “Is this a Kubernetes problem, an AWS problem, or the join between them?”

EKS is where Kubernetes and AWS meet. That is why interviews can feel tricky. A normal Kubernetes issue may actually be IAM. A pod scheduling issue may actually be EC2 capacity. A service issue may actually be a security group, subnet tag, or AWS Load Balancer Controller problem. A DNS issue may be CoreDNS, VPC DNS, node security groups, or upstream resolver limits.

This kit is built for that interview moment when you know the topic but need calm, structured words.

It covers 30 common Amazon EKS issues interviewers ask about, with symptoms, likely causes, diagnostic commands, resolutions, examples, and interview-ready wording. It is written for DevOps, SRE, platform, Kubernetes, cloud, and infrastructure engineers who want practical answers under pressure.

When you freeze, start with this sentence:

> “I would first separate the problem into Kubernetes control plane, worker nodes, pod scheduling, CNI networking, IAM permissions, service/load balancer, DNS, storage, autoscaling, add-ons, or deployment configuration. Then I would inspect Kubernetes events, pod status, node status, EKS cluster health, AWS IAM/CloudTrail, VPC/subnet/security group settings, and the relevant controller logs before changing anything.”

That answer sounds like someone who understands EKS as both Kubernetes and AWS infrastructure.

---

## How to use this kit

For every EKS issue, use this structure:

```text
Symptom → Scope → Kubernetes evidence → AWS evidence → Root cause → Fix → Verify → Prevent
```

A strong EKS interview answer usually includes:

1. What the user sees.
2. Whether the problem affects one pod, one node, one node group, one namespace, one service, one add-on, or the whole cluster.
3. Whether Kubernetes accepted the object.
4. Whether AWS infrastructure can support it.
5. What logs or events you check.
6. What safe fix you apply.
7. How you verify.
8. How you prevent recurrence.

Example:

> “If pods are Pending on EKS, I would check `kubectl describe pod` events first. If the scheduler says insufficient CPU or memory, I would look at node capacity and autoscaler behavior. If it says node affinity, taints, or volume binding, I would follow that path. If no nodes exist, I would check node group health, EC2 capacity, IAM role, subnet, and bootstrap logs.”

That is stronger than saying:

> “I would restart the pod.”

Restarting is an action. Diagnosis is engineering.

---

# Top 30 AWS EKS issues and resolutions

---

## 1. Cannot connect to the EKS cluster

### Interview freeze point

The interviewer asks:

> “You run `kubectl get pods` and get unauthorized or connection errors. What do you check?”

### Strong interview answer

> “I would check whether my kubeconfig points to the right cluster, whether my AWS identity has EKS access, whether the cluster endpoint is public or private, whether the network path can reach the endpoint, and whether Kubernetes RBAC allows the action.”

### Symptoms

- `Unable to connect to the server`
- `You must be logged in to the server`
- `Unauthorized`
- `Forbidden`
- `dial tcp: i/o timeout`
- Works for one engineer but not another.
- Works from VPN but not laptop.
- Works from bastion but not CI.

### Diagnostic commands

```bash
aws sts get-caller-identity

aws eks describe-cluster \
  --name my-cluster \
  --region eu-west-1 \
  --query "cluster.{status:status,endpoint:endpoint,public:endpointPublicAccess,private:endpointPrivateAccess}"

aws eks update-kubeconfig \
  --name my-cluster \
  --region eu-west-1

kubectl cluster-info
kubectl auth can-i get pods --all-namespaces
```

### Common causes

- Wrong AWS account or role.
- Wrong region.
- Kubeconfig points to old cluster.
- Cluster endpoint is private only.
- No VPN, Direct Connect, bastion, or private network path.
- EKS access entry or `aws-auth` mapping missing.
- Kubernetes RBAC denies action.
- AWS CLI profile wrong.
- Cluster deleted or updating.
- Corporate proxy breaks endpoint access.

### Example fix: update kubeconfig

```bash
aws eks update-kubeconfig \
  --name my-cluster \
  --region eu-west-1 \
  --profile platform-prod
```

### Example check identity

```bash
aws sts get-caller-identity --profile platform-prod
```

### Resolution

- Confirm AWS account, role, and region.
- Regenerate kubeconfig.
- Confirm endpoint accessibility.
- Add EKS access entry or `aws-auth` mapping as appropriate.
- Add Kubernetes RBAC binding for required permissions.
- Use bastion/VPN/private access path for private endpoint clusters.

### Takeaway summary

Cluster access has two layers: AWS authentication to EKS and Kubernetes authorization inside the cluster.

---

## 2. User authenticated but forbidden by Kubernetes RBAC

### Interview freeze point

The user can connect to the cluster, but cannot list pods or deploy workloads.

### Strong interview answer

> “Authentication proves who I am. Authorization decides what I can do. In EKS, I would check the AWS identity mapping into Kubernetes and then Kubernetes RBAC roles and bindings.”

### Symptoms

- `Forbidden`
- `User cannot list resource pods`
- `kubectl auth can-i` returns no.
- Admin can do it, developer cannot.
- CI role can connect but cannot deploy.

### Diagnostic commands

```bash
aws sts get-caller-identity

kubectl auth can-i get pods -n app
kubectl auth can-i create deployments -n app

kubectl get rolebinding,clusterrolebinding -A | grep developer
```

### EKS access mapping concepts

EKS clusters may use access entries or legacy `aws-auth` ConfigMap mappings depending on cluster configuration and age.

### Kubernetes RBAC example

Role:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: app
  name: app-developer
rules:
  - apiGroups: ["", "apps"]
    resources: ["pods", "services", "deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
```

RoleBinding:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: app
  name: app-developer-binding
subjects:
  - kind: Group
    name: app-developers
roleRef:
  kind: Role
  name: app-developer
  apiGroup: rbac.authorization.k8s.io
```

### Common causes

- AWS role is not mapped to Kubernetes user/group.
- Mapped group has no RBAC binding.
- Binding exists in wrong namespace.
- ClusterRole needed but only Role exists.
- CI role changed.
- Old `aws-auth` entry removed.
- Access entry exists but policy association is wrong.
- User assumes AWS IAM permissions equal Kubernetes permissions.

### Resolution

- Verify identity.
- Verify EKS access mapping.
- Verify Kubernetes RBAC.
- Use least privilege.
- Prefer group/team-based access.
- Test with `kubectl auth can-i`.

### Takeaway summary

EKS access is AWS identity plus Kubernetes RBAC. Both must be correct.

---

## 3. Worker nodes fail to join the cluster

### Interview freeze point

The EKS control plane exists, but nodes never become Ready.

### Strong interview answer

> “I would check node group health, EC2 instances, node IAM role, subnet routing, security groups, bootstrap logs, cluster endpoint access, and whether the node can reach the EKS API and required AWS services.”

### Symptoms

- `kubectl get nodes` shows no nodes.
- Managed node group creation fails.
- EC2 instances launch then terminate.
- Node group status degraded.
- Nodes exist in EC2 but not Kubernetes.
- Bootstrap errors in cloud-init logs.

### Diagnostic commands

```bash
aws eks describe-nodegroup \
  --cluster-name my-cluster \
  --nodegroup-name my-ng \
  --region eu-west-1

kubectl get nodes

aws ec2 describe-instances \
  --filters "Name=tag:eks:cluster-name,Values=my-cluster"
```

On node:

```bash
sudo journalctl -u kubelet -n 100
sudo cat /var/log/cloud-init-output.log
```

### Common causes

- Node IAM role lacks required policies.
- Node role not mapped to cluster access.
- Node security group cannot reach cluster endpoint.
- Private endpoint unreachable from node subnet.
- No NAT or VPC endpoints for private nodes.
- Subnet route table wrong.
- DNS resolution disabled in VPC.
- User data/bootstrap failure.
- AMI/Kubernetes version mismatch.
- EC2 capacity unavailable.
- Launch template misconfigured.

### Required node role examples

Common managed node role policies include Amazon EKS worker node, CNI, and ECR read-only permissions, though exact policies depend on your design and add-on model.

### Resolution

- Check managed node group health issues.
- Check node IAM role.
- Check endpoint access and security groups.
- Check subnet routing and NAT/VPC endpoints.
- Check node bootstrap logs.
- Confirm node AMI and Kubernetes version compatibility.
- Recreate node group if launch template is broken.

### Takeaway summary

Node join failures usually come from IAM, endpoint reachability, security groups, routing, DNS, or bootstrap configuration.

---

## 4. Nodes are NotReady

### Interview freeze point

Nodes joined, but Kubernetes marks them NotReady.

### Strong interview answer

> “I would inspect node conditions, kubelet logs, CNI pod status, disk pressure, memory pressure, network plugin readiness, and whether the node can communicate with the control plane.”

### Symptoms

- `kubectl get nodes` shows `NotReady`.
- Pods stuck Pending or Terminating.
- CNI errors.
- Kubelet unhealthy.
- Node conditions show pressure.
- Workloads evicted.

### Diagnostic commands

```bash
kubectl get nodes
kubectl describe node ip-10-0-1-10.eu-west-1.compute.internal

kubectl get pods -n kube-system -o wide

kubectl logs -n kube-system daemonset/aws-node
```

On node:

```bash
sudo journalctl -u kubelet -n 200
df -h
free -m
```

### Common causes

- VPC CNI `aws-node` not running.
- Kubelet cannot reach API server.
- Node disk pressure.
- Node memory pressure.
- Container runtime issue.
- Security group/network path broken.
- IAM permissions broken for CNI.
- DNS issue.
- Bad AMI or kernel problem.
- Node resource exhaustion.

### Resolution

- Fix CNI DaemonSet.
- Fix kubelet/API connectivity.
- Drain and replace unhealthy node if needed.
- Free disk or increase root volume.
- Fix IAM permissions for node/CNI.
- Restart kubelet only if root cause is understood.
- Replace node group if systemic.

### Takeaway summary

A NotReady node is usually kubelet, CNI, pressure, runtime, or control plane connectivity.

---

## 5. Pods stuck Pending

### Interview freeze point

A deployment was applied, but pods do not start.

### Strong interview answer

> “I would describe the pod and read scheduler events. Pending pods tell you why: insufficient resources, taints, node selectors, affinity, volume binding, missing nodes, or autoscaler not scaling.”

### Symptoms

- Pods show `Pending`.
- Deployment has unavailable replicas.
- Scheduler events mention insufficient CPU/memory.
- Pod cannot tolerate taint.
- PVC not bound.
- Autoscaler does not add nodes.

### Diagnostic commands

```bash
kubectl get pods -n app
kubectl describe pod my-pod -n app

kubectl get nodes
kubectl describe nodes | grep -A5 Taints

kubectl get pvc -n app
```

### Common scheduler messages

```text
0/3 nodes are available: insufficient cpu
0/3 nodes are available: node(s) had untolerated taint
0/3 nodes are available: node(s) didn't match node selector
pod has unbound immediate PersistentVolumeClaims
```

### Example resource request issue

```yaml
resources:
  requests:
    cpu: "4"
    memory: "8Gi"
```

If nodes have only 2 vCPU available, pod stays Pending.

### Resolution

- Reduce or right-size resource requests.
- Add node capacity.
- Fix node selector/affinity.
- Add toleration if workload should run on tainted nodes.
- Fix PVC/storage class.
- Check Cluster Autoscaler or Karpenter.
- Check EC2 capacity and subnet capacity.

### Takeaway summary

For Pending pods, `kubectl describe pod` events are the first source of truth.

---

## 6. Pods stuck CrashLoopBackOff

### Interview freeze point

The pod schedules, starts, then repeatedly crashes.

### Strong interview answer

> “I would check container logs, previous logs, exit code, environment variables, secrets, config maps, image command, readiness/liveness probes, and application dependencies.”

### Symptoms

- Pod status `CrashLoopBackOff`.
- Restart count increases.
- App unavailable.
- Logs show startup error.
- Works locally but not in EKS.

### Diagnostic commands

```bash
kubectl logs pod-name -n app
kubectl logs pod-name -n app --previous
kubectl describe pod pod-name -n app

kubectl get events -n app --sort-by=.lastTimestamp
```

### Common causes

- Application exception.
- Missing environment variable.
- Secret/config missing.
- Bad image or command.
- Database unavailable.
- Permission issue.
- Liveness probe kills app too early.
- Wrong CPU/memory limit causing OOM.
- Architecture mismatch.

### Example missing env var

```yaml
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: db-secret
        key: url
```

If `db-secret` or key `url` is missing, pod may fail or not start.

### Resolution

- Read current and previous logs.
- Fix app config.
- Fix secrets/config maps.
- Adjust probes.
- Check dependencies.
- Check resource limits.
- Roll back image if needed.

### Takeaway summary

CrashLoopBackOff is usually application startup failure, config failure, probe failure, or resource limit failure.

---

## 7. ImagePullBackOff or ErrImagePull

### Interview freeze point

Kubernetes cannot pull the image.

### Strong interview answer

> “I would check image name, tag, registry, architecture, node IAM permissions for ECR, image pull secret for private registries, and whether the image exists in the region/account.”

### Symptoms

- Pod status `ImagePullBackOff`
- `ErrImagePull`
- `pull access denied`
- `manifest unknown`
- `no basic auth credentials`
- Works from laptop but not from node.

### Diagnostic commands

```bash
kubectl describe pod pod-name -n app
kubectl get events -n app --sort-by=.lastTimestamp
```

Check ECR:

```bash
aws ecr describe-images \
  --repository-name my-repo \
  --region eu-west-1
```

### Common causes

- Wrong image tag.
- Image not pushed.
- Wrong AWS account or region.
- Node role lacks ECR pull permissions.
- Private registry secret missing.
- Image architecture mismatch.
- Registry rate limit.
- Repository policy denies pull.
- Typo in repository URL.

### ECR image format

```text
123456789012.dkr.ecr.eu-west-1.amazonaws.com/my-app:1.2.3
```

### Private registry secret example

```bash
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=password \
  -n app
```

Pod:

```yaml
imagePullSecrets:
  - name: regcred
```

### Takeaway summary

Image pull failures are usually image reference, registry auth, ECR permissions, region/account, or architecture problems.

---

## 8. Pod cannot reach AWS service

### Interview freeze point

A pod cannot access S3, DynamoDB, SQS, Secrets Manager, or another AWS service.

### Strong interview answer

> “I would check IAM permissions, whether the pod uses IRSA or EKS Pod Identity, service account annotation or association, AWS SDK credential resolution, network egress, VPC endpoints or NAT, and CloudTrail AccessDenied events.”

### Symptoms

- AWS SDK returns `AccessDenied`.
- AWS SDK cannot find credentials.
- Connection timeout to AWS endpoint.
- Works on node but not pod.
- Works locally but not in EKS.
- Some pods can access service, others cannot.

### Diagnostic commands

Inside pod:

```bash
aws sts get-caller-identity
aws s3 ls
```

Check service account:

```bash
kubectl get sa my-sa -n app -o yaml
```

Check CloudTrail for denied API calls.

### Common causes

- IAM policy missing.
- Wrong service account.
- IRSA annotation missing or wrong.
- Pod Identity association missing.
- Trust policy wrong.
- SDK too old for expected credential source.
- Pod uses node role instead of pod role.
- Network egress blocked.
- No NAT or VPC endpoint in private subnet.
- AWS region wrong.

### IRSA service account example

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-reader
  namespace: app
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/app-s3-reader
```

### EKS Pod Identity note

EKS now also supports Pod Identity associations. If both older IRSA-style settings and Pod Identity are present in some add-on scenarios, current AWS guidance says Pod Identity can take precedence when the Pod Identity Agent is installed for certain EKS add-on integrations. Review the exact cluster/add-on behavior before assuming which identity path is used.

### Takeaway summary

AWS service access from pods is both IAM and network. Check identity first, then egress path.

---

## 9. IRSA trust policy misconfigured

### Interview freeze point

The service account has an IAM role annotation, but AWS calls still fail.

### Strong interview answer

> “I would verify the cluster OIDC provider, role trust policy, service account namespace/name condition, annotation, token audience, and CloudTrail errors.”

### Symptoms

- `AccessDenied`
- `InvalidIdentityToken`
- Pod assumes wrong role.
- AWS SDK uses node role.
- Service account annotation looks right.

### Diagnostic commands

```bash
aws eks describe-cluster \
  --name my-cluster \
  --query "cluster.identity.oidc.issuer" \
  --output text

kubectl get sa s3-reader -n app -o yaml
```

### Trust policy pattern

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLE"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLE:sub": "system:serviceaccount:app:s3-reader",
      "oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLE:aud": "sts.amazonaws.com"
    }
  }
}
```

### Common causes

- OIDC provider not created in IAM.
- Trust policy has wrong OIDC provider ID.
- Namespace/name in trust policy wrong.
- Service account annotation wrong.
- Pod uses different service account.
- IAM policy attached to role lacks permissions.
- SDK ignores web identity due to old version or env override.
- Token audience mismatch.

### Resolution

- Confirm OIDC issuer.
- Confirm IAM OIDC provider exists.
- Correct trust policy.
- Correct service account annotation.
- Restart pods after service account changes.
- Test with `aws sts get-caller-identity` inside pod.
- Check CloudTrail.

### Takeaway summary

IRSA failures usually come from trust policy conditions, OIDC provider mismatch, wrong service account, or missing IAM permissions.

---

## 10. EKS Pod Identity association issue

### Interview freeze point

The team uses EKS Pod Identity instead of, or alongside, IRSA.

### Strong interview answer

> “I would check that the EKS Pod Identity Agent is installed, the pod identity association exists for the right namespace/service account, the IAM role trust policy is correct, and CloudTrail shows whether the role is assumed or denied.”

### Symptoms

- Pod cannot get AWS credentials.
- Add-on cannot assume role.
- `AccessDenied`
- Pod uses unexpected role.
- Association exists but app still fails.

### Diagnostic commands

```bash
aws eks list-pod-identity-associations \
  --cluster-name my-cluster

kubectl get pods -n kube-system | grep pod-identity

kubectl get sa my-service-account -n app -o yaml
```

### Common causes

- Pod Identity Agent not installed.
- Association namespace/name wrong.
- IAM role trust policy wrong.
- IAM policy missing.
- Pod uses different service account.
- Add-on-owned association deleted with add-on.
- Both Pod Identity and IRSA assumptions misunderstood.
- AWS SDK/version issue.

### Resolution

- Install/verify EKS Pod Identity Agent.
- Create or correct pod identity association.
- Correct IAM role trust policy.
- Attach needed IAM permissions.
- Restart workload pods.
- Test identity from pod.
- Check CloudTrail for denied calls.

### Takeaway summary

Pod Identity makes pod IAM cleaner, but association, agent, trust policy, and IAM policy still must line up.

---

## 11. VPC CNI IP exhaustion

### Interview freeze point

Pods cannot start because the cluster runs out of pod IPs.

### Strong interview answer

> “I would check pod events, node ENI/IP capacity, subnet free IPs, VPC CNI logs, and whether prefix delegation or larger subnets are needed.”

### Symptoms

- Pods stuck `Pending` or `ContainerCreating`.
- Events mention failed to assign IP.
- `aws-node` logs show IP allocation failure.
- Nodes have capacity but pods cannot network.
- Subnets have few free IPs.
- High pod density fails.

### Diagnostic commands

```bash
kubectl describe pod pod-name -n app
kubectl logs -n kube-system daemonset/aws-node

aws ec2 describe-subnets \
  --subnet-ids subnet-abc123 \
  --query "Subnets[*].AvailableIpAddressCount"
```

### Common causes

- Subnet IP exhaustion.
- Node ENI/IP limits reached.
- Too many pods per node.
- VPC CNI warm IP settings too high or low.
- Small subnets.
- No prefix delegation.
- Security groups for pods config issue.
- Custom networking misconfigured.

### Resolution

- Add larger subnets or new node groups in subnets with IP capacity.
- Reduce pod density.
- Enable/tune prefix delegation where appropriate.
- Tune VPC CNI warm IP/prefix settings.
- Review subnet sizing.
- Use Karpenter/node groups across enough subnets.
- Monitor subnet free IPs.

### Takeaway summary

In EKS with VPC CNI, pods consume VPC IP capacity. Subnet sizing is a cluster scaling concern.

---

## 12. Pod-to-pod or pod-to-service networking fails

### Interview freeze point

Pods are running, but services cannot communicate.

### Strong interview answer

> “I would check service selectors, endpoints, pod labels, DNS resolution, kube-proxy, network policies, security groups, and CNI health.”

### Symptoms

- Service connection refused.
- DNS resolves but no response.
- Service has no endpoints.
- Pod can curl IP but not service name.
- Only some namespaces fail.
- NetworkPolicy recently changed.

### Diagnostic commands

```bash
kubectl get svc,endpoints -n app
kubectl describe svc api -n app
kubectl get pods -n app --show-labels

kubectl exec -it client-pod -n app -- nslookup api.app.svc.cluster.local
kubectl exec -it client-pod -n app -- curl -v http://api:8080
```

### Common causes

- Service selector does not match pod labels.
- Pods not Ready, so endpoints absent.
- Target port wrong.
- App listens on wrong port.
- NetworkPolicy blocks traffic.
- kube-proxy issue.
- CoreDNS issue.
- Security group for pods issue.
- CNI issue.

### Service selector example

Service:

```yaml
selector:
  app: api
```

Pod labels must include:

```yaml
labels:
  app: api
```

### Resolution

- Fix service selector/labels.
- Fix targetPort.
- Check endpoints.
- Check NetworkPolicy.
- Check DNS.
- Check kube-proxy and CNI pods.
- Test from a debug pod.

### Takeaway summary

Service networking starts with labels and endpoints. If endpoints are empty, fix selector or pod readiness first.

---

## 13. DNS resolution fails inside pods

### Interview freeze point

Pods cannot resolve service names or external domains.

### Strong interview answer

> “I would check CoreDNS pods, kube-dns service, pod DNS config, node DNS, VPC DNS settings, upstream resolver behavior, and whether DNS traffic is blocked.”

### Symptoms

- `nslookup kubernetes.default` fails.
- App errors with unknown host.
- External DNS fails but service DNS works.
- Service DNS fails cluster-wide.
- CoreDNS pods CrashLoop or Pending.
- DNS timeouts under load.

### Diagnostic commands

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system deployment/coredns

kubectl get svc -n kube-system kube-dns

kubectl run -it --rm debug --image=busybox:1.36 --restart=Never -- nslookup kubernetes.default
```

### Common causes

- CoreDNS pods down.
- CoreDNS cannot schedule.
- CoreDNS add-on outdated or misconfigured.
- kube-dns service broken.
- Node security group blocks DNS.
- VPC DNS hostnames/resolution disabled.
- Upstream DNS timeout.
- NetworkPolicy blocks DNS.
- Too much DNS load.
- Node local DNS cache missing/misconfigured.

### Resolution

- Restore CoreDNS deployment.
- Check CoreDNS ConfigMap.
- Scale CoreDNS if needed.
- Check kube-proxy.
- Check network policies allow UDP/TCP 53 to kube-dns.
- Check VPC DNS settings.
- Update CoreDNS add-on carefully.
- Use NodeLocal DNSCache if appropriate.

### Takeaway summary

DNS issues can be CoreDNS, kube-proxy, network policy, VPC DNS, or upstream resolver problems.

---

## 14. LoadBalancer service not creating AWS load balancer

### Interview freeze point

A Kubernetes Service of type LoadBalancer exists, but no AWS load balancer appears.

### Strong interview answer

> “I would check service events, AWS Load Balancer Controller or cloud provider integration, subnet tags, security groups, IAM permissions, annotations, and AWS quota or subnet capacity.”

### Symptoms

- Service external IP stays pending.
- No NLB/ELB created.
- Service events show access denied.
- Load balancer created in wrong subnets.
- Controller logs show errors.

### Diagnostic commands

```bash
kubectl describe svc my-service -n app
kubectl get events -n app --sort-by=.lastTimestamp

kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

### Common causes

- Missing or unhealthy AWS Load Balancer Controller.
- Controller IAM permissions missing.
- Subnets not tagged for cluster/role.
- Service annotations wrong.
- Security group rules blocked.
- AWS load balancer quota exceeded.
- No suitable subnets.
- Internal vs internet-facing mismatch.
- Unsupported service configuration.

### Example annotations

```yaml
metadata:
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
```

### Subnet tag examples

Public LB subnets commonly need role tags such as:

```text
kubernetes.io/role/elb = 1
```

Internal LB subnets:

```text
kubernetes.io/role/internal-elb = 1
```

Cluster ownership/shared tags may also be part of your environment’s setup.

### Takeaway summary

LoadBalancer problems are usually controller, IAM, subnet tags, annotations, security groups, or AWS quota issues.

---

## 15. Ingress does not create ALB

### Interview freeze point

An Ingress is applied, but no ALB appears or it is misconfigured.

### Strong interview answer

> “I would check AWS Load Balancer Controller installation, ingress class, annotations, subnet tags, IAM permissions, target type, service backend, and controller logs.”

### Symptoms

- Ingress address empty.
- ALB not created.
- ALB exists but target group unhealthy.
- Ingress events show errors.
- Controller logs show access denied.
- Wrong scheme or certificate.

### Diagnostic commands

```bash
kubectl describe ingress my-ingress -n app
kubectl get ingressclass
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

### Example Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api
  namespace: app
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:eu-west-1:123456789012:certificate/abc
spec:
  ingressClassName: alb
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

### Common causes

- Missing `ingressClassName`.
- Controller not installed.
- Controller IAM role wrong.
- Subnet tags missing.
- ACM cert region mismatch.
- Backend service missing.
- Target type wrong.
- Security group rules wrong.
- Health check path wrong.
- DNS not pointed to ALB.

### Takeaway summary

ALB Ingress issues usually live in controller logs, ingress events, annotations, subnet tags, IAM, and target health.

---

## 16. ALB/NLB target health checks failing

### Interview freeze point

The load balancer exists, but traffic fails.

### Strong interview answer

> “I would check target group health, health check path/port/protocol, pod readiness, service target port, security groups, and whether the app listens on the expected interface and port.”

### Symptoms

- ALB returns 503.
- Target group unhealthy.
- Service has endpoints but LB fails.
- Pod works with port-forward.
- Health check path returns 404.
- Security group blocks LB to pod/node.

### Diagnostic commands

```bash
kubectl get svc,endpoints -n app
kubectl describe ingress api -n app
kubectl describe pod api-pod -n app

aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:...
```

### Common causes

- Health check path wrong.
- App returns non-200.
- Service targetPort wrong.
- Pod readiness failing.
- Security group blocks traffic.
- Target type `ip` vs `instance` mismatch.
- App listens on localhost only.
- Container port mismatch.
- Protocol mismatch HTTP/HTTPS.

### Example annotation

```yaml
alb.ingress.kubernetes.io/healthcheck-path: /health
alb.ingress.kubernetes.io/healthcheck-port: traffic-port
```

### Resolution

- Fix health endpoint.
- Fix service port/targetPort.
- Fix readiness probe.
- Fix security group rules.
- Confirm app listens on `0.0.0.0`.
- Use correct target type.
- Check target group health reason.

### Takeaway summary

Load balancer created does not mean app is reachable. Target health is the real test.

---

## 17. EBS volume does not attach or PVC stays Pending

### Interview freeze point

A stateful workload cannot start because storage is unavailable.

### Strong interview answer

> “I would check StorageClass, PVC events, EBS CSI driver, IAM permissions, availability zone, volume binding mode, and whether the pod and volume are in the same AZ.”

### Symptoms

- PVC Pending.
- Pod Pending with unbound PVC.
- Volume attach timeout.
- Multi-AZ scheduling conflict.
- CSI driver logs AccessDenied.
- StatefulSet stuck.

### Diagnostic commands

```bash
kubectl get pvc,pv -n app
kubectl describe pvc data -n app
kubectl describe pod pod-name -n app

kubectl get pods -n kube-system | grep ebs-csi
kubectl logs -n kube-system deployment/ebs-csi-controller
```

### StorageClass example

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3
```

### Common causes

- EBS CSI driver missing.
- CSI IAM permissions missing.
- StorageClass wrong.
- PVC requests unsupported size/type.
- Volume AZ mismatch.
- Pod scheduled in wrong AZ.
- EBS volume already attached to another node.
- AWS EBS quota exceeded.
- Security/permissions issue.

### Resolution

- Install/update EBS CSI driver.
- Configure Pod Identity/IRSA for CSI driver.
- Use `WaitForFirstConsumer`.
- Check AZ constraints.
- Check AWS EBS quotas.
- Check volume attachment state.
- Recreate stuck PVC only if data safety is understood.

### Takeaway summary

EBS is AZ-scoped. PVC scheduling and node AZ must line up.

---

## 18. EFS mount fails

### Interview freeze point

A shared filesystem volume fails to mount.

### Strong interview answer

> “I would check EFS CSI driver, mount targets in each AZ, security groups allowing NFS, IAM if using access points, DNS, and file system permissions.”

### Symptoms

- Pod stuck ContainerCreating.
- Mount timeout.
- Permission denied.
- Works in one AZ but not another.
- EFS CSI logs errors.
- App cannot write to mounted path.

### Diagnostic commands

```bash
kubectl describe pod pod-name -n app
kubectl get pods -n kube-system | grep efs
kubectl logs -n kube-system daemonset/efs-csi-node
```

### Common causes

- EFS CSI driver missing.
- No EFS mount target in node AZ.
- Security group blocks NFS TCP 2049.
- DNS resolution issue.
- Access point permissions wrong.
- File ownership/UID mismatch.
- IAM permissions missing if using dynamic provisioning.
- Network path blocked.

### Resolution

- Install EFS CSI driver.
- Create mount targets in required AZs.
- Allow NFS 2049 from worker nodes/pods.
- Fix access point POSIX permissions.
- Fix IAM permissions.
- Test mount path with debug pod.
- Check node subnet/AZ.

### Takeaway summary

EFS failures are usually mount targets, security groups, NFS, CSI driver, or POSIX permission issues.

---

## 19. Cluster Autoscaler not scaling up

### Interview freeze point

Pods are Pending, but new nodes are not added.

### Strong interview answer

> “I would check Cluster Autoscaler logs, pod scheduling events, node group tags/discovery, IAM permissions, max size, resource requests, taints, and whether the pending pods are actually scale-up candidates.”

### Symptoms

- Pods Pending with insufficient resources.
- Node group does not grow.
- Autoscaler logs show no expansion options.
- Max node group size reached.
- Pods have unsupported constraints.
- ASG tags missing.

### Diagnostic commands

```bash
kubectl logs -n kube-system deployment/cluster-autoscaler

kubectl describe pod pending-pod -n app

aws autoscaling describe-auto-scaling-groups \
  --query "AutoScalingGroups[?contains(Tags[?Key=='k8s.io/cluster-autoscaler/enabled'].Value, 'true')]"
```

### Common causes

- Autoscaler not installed.
- IAM permissions missing.
- ASG discovery tags missing.
- Node group max size reached.
- Pod requests too large for any node type.
- Taints/affinity prevent scheduling.
- PVC/AZ constraints prevent scale-up.
- Expander policy not appropriate.
- Autoscaler version mismatch.

### Resolution

- Fix autoscaler IAM.
- Add required ASG tags.
- Increase node group max size.
- Add larger node type.
- Fix pod requests/affinity/tolerations.
- Check autoscaler version compatibility.
- Consider Karpenter for more flexible provisioning.

### Takeaway summary

Autoscaler only scales when pending pods can be helped by adding a valid node.

---

## 20. Karpenter not provisioning nodes

### Interview freeze point

The cluster uses Karpenter, but pods stay Pending.

### Strong interview answer

> “I would check Karpenter controller logs, NodePool/NodeClass configuration, IAM permissions, subnet and security group discovery, instance type constraints, capacity availability, disruption settings, and pod scheduling constraints.”

### Symptoms

- Pods Pending.
- Karpenter logs show no instance type satisfies requirements.
- Nodes created then terminated.
- EC2 Fleet errors.
- IAM AccessDenied.
- Subnet/security group discovery fails.

### Diagnostic commands

```bash
kubectl get nodepool,nodeclass -A
kubectl describe pod pending-pod -n app
kubectl logs -n karpenter deployment/karpenter
```

### Common causes

- Karpenter IAM role missing permissions.
- NodeClass subnet/security group selector wrong.
- Instance type constraints too narrow.
- Capacity unavailable.
- Pod requests too large.
- AMI family/config wrong.
- Cluster endpoint/CA config wrong.
- Taints/tolerations mismatch.
- Limits reached.

### Example requirement issue

NodePool allows only small instances:

```yaml
requirements:
  - key: node.kubernetes.io/instance-type
    operator: In
    values: ["t3.small"]
```

Pod requests:

```yaml
resources:
  requests:
    cpu: "4"
    memory: "8Gi"
```

No matching node can fit.

### Resolution

- Check Karpenter logs.
- Broaden instance requirements.
- Fix subnet/security group selectors.
- Fix IAM.
- Check EC2 capacity and quotas.
- Check pod constraints.
- Validate NodePool/NodeClass.

### Takeaway summary

Karpenter failures are usually constraints, discovery, IAM, EC2 capacity, or pod scheduling mismatch.

---

## 21. Node group update or upgrade fails

### Interview freeze point

Managed node group update fails or gets stuck.

### Strong interview answer

> “I would check node group health, launch template changes, update strategy, pod disruption budgets, unavailable capacity, drain failures, and whether workloads can be safely evicted.”

### Symptoms

- Node group update failed.
- Nodes stuck draining.
- Old AMI nodes remain.
- PDB prevents eviction.
- New instances fail to join.
- Workloads unavailable during update.

### Diagnostic commands

```bash
aws eks describe-nodegroup \
  --cluster-name my-cluster \
  --nodegroup-name my-ng

kubectl get pdb -A
kubectl get nodes -l eks.amazonaws.com/nodegroup=my-ng
kubectl describe node node-name
```

### Common causes

- PodDisruptionBudget blocks drain.
- Pods without controllers cannot be evicted safely.
- New launch template broken.
- New AMI/bootstrap failure.
- EC2 capacity unavailable.
- Node group max unavailable too low.
- DaemonSets or local storage complicate drain.
- Security group or IAM broken for new nodes.

### Resolution

- Review node group health.
- Fix launch template or IAM.
- Adjust PDB carefully.
- Add capacity before draining.
- Drain manually only with care.
- Roll back launch template if broken.
- Replace node group if update path is unsafe.

### Takeaway summary

Node upgrades are scheduling and disruption events. PDBs, capacity, and node bootstrap must be healthy.

---

## 22. EKS control plane upgrade issues

### Interview freeze point

The cluster upgrade is planned or failed.

### Strong interview answer

> “I would treat EKS upgrades as staged changes: review version skew, deprecated APIs, add-on compatibility, node versions, controllers, CRDs, and workload readiness before upgrading the control plane.”

### Symptoms

- Upgrade blocked or fails.
- APIs removed after upgrade.
- Add-ons incompatible.
- Nodes lag behind.
- Controllers fail after upgrade.
- Workloads use deprecated API versions.

### Pre-upgrade checklist

```bash
kubectl version
kubectl get nodes
kubectl get apiservices
kubectl get crd
kubectl get events -A
```

Check deprecated APIs with tools such as `kubent` or `pluto` if available.

### Common causes

- Deprecated Kubernetes APIs still used.
- Add-ons not compatible.
- Nodes too old.
- Webhooks fail.
- PDBs block node update.
- Controllers not compatible.
- CRDs need upgrade.
- Terraform/module version mismatch.

### Safe upgrade flow

```text
Review AWS EKS upgrade guidance.
Check deprecated APIs.
Upgrade add-ons as needed.
Upgrade control plane.
Upgrade managed node groups.
Upgrade CoreDNS, kube-proxy, VPC CNI as appropriate.
Validate workloads.
```

### Takeaway summary

EKS upgrades are not just control plane upgrades. Add-ons, nodes, APIs, controllers, and workloads all matter.

---

## 23. CoreDNS add-on unhealthy after upgrade

### Interview freeze point

After upgrade, DNS breaks or CoreDNS pods are unavailable.

### Strong interview answer

> “I would check CoreDNS deployment, logs, add-on version compatibility, scheduling constraints, PDB, config map, and whether CoreDNS can reach upstream DNS.”

### Symptoms

- DNS failures after upgrade.
- CoreDNS pods Pending or CrashLoopBackOff.
- Cluster service lookup fails.
- External DNS fails.
- Add-on update failed.
- CoreDNS config overwritten.

### Diagnostic commands

```bash
kubectl get deployment coredns -n kube-system
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system deployment/coredns
kubectl get configmap coredns -n kube-system -o yaml

aws eks describe-addon \
  --cluster-name my-cluster \
  --addon-name coredns
```

### Common causes

- Add-on version incompatible.
- CoreDNS cannot schedule due to taints/affinity.
- Resource requests too high.
- ConfigMap invalid.
- Upstream DNS unavailable.
- PDB blocks update.
- Custom changes conflict with managed add-on.
- Too few replicas.

### Resolution

- Roll back or update to compatible add-on version.
- Fix CoreDNS ConfigMap.
- Ensure CoreDNS schedules on available nodes.
- Scale replicas.
- Check upstream DNS.
- Save custom config before add-on updates.

### Takeaway summary

CoreDNS is critical infrastructure. Treat add-on updates carefully and validate DNS after changes.

---

## 24. VPC CNI add-on upgrade breaks networking

### Interview freeze point

After a CNI update, pods cannot get IPs or networking becomes unstable.

### Strong interview answer

> “I would check the aws-node DaemonSet, VPC CNI version, configuration variables, IAM permissions, IP allocation logs, node ENI capacity, and whether managed add-on settings overwrote custom config.”

### Symptoms

- Pods stuck ContainerCreating.
- IP allocation fails.
- Node networking unstable.
- `aws-node` CrashLoopBackOff.
- Custom networking broken.
- Security groups for pods stop working.

### Diagnostic commands

```bash
kubectl get daemonset aws-node -n kube-system
kubectl logs -n kube-system daemonset/aws-node

aws eks describe-addon \
  --cluster-name my-cluster \
  --addon-name vpc-cni
```

### Common causes

- Add-on version incompatible.
- IAM permissions missing.
- Custom env vars overwritten.
- Prefix delegation config changed.
- Security groups for pods config issue.
- Insufficient subnet IPs.
- DaemonSet not running on all nodes.
- Managed vs self-managed add-on confusion.

### Resolution

- Check add-on health.
- Restore required configuration values.
- Ensure IAM role/policy is correct.
- Roll back if necessary.
- Confirm subnet IP capacity.
- Test pod IP allocation.
- Document managed add-on configuration.

### Takeaway summary

VPC CNI controls pod networking. Upgrade it like production network infrastructure.

---

## 25. kube-proxy add-on issue

### Interview freeze point

Services behave strangely and cluster networking is inconsistent.

### Strong interview answer

> “I would check kube-proxy DaemonSet, version compatibility, node coverage, iptables/ipvs rules, and whether the add-on is managed or self-managed.”

### Symptoms

- ClusterIP services fail.
- NodePort behaves inconsistently.
- Some nodes route service traffic, others do not.
- kube-proxy pods CrashLoopBackOff.
- Service endpoints exist but traffic fails.
- Add-on update failed.

### Diagnostic commands

```bash
kubectl get daemonset kube-proxy -n kube-system
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide
kubectl logs -n kube-system daemonset/kube-proxy

aws eks describe-addon \
  --cluster-name my-cluster \
  --addon-name kube-proxy
```

### Common causes

- kube-proxy not running on nodes.
- Version skew.
- Bad ConfigMap.
- iptables issue.
- Managed/self-managed confusion.
- Node OS/kernel issue.
- NetworkPolicy/CNI interaction misunderstood.

### Resolution

- Restore kube-proxy DaemonSet.
- Update to compatible version.
- Fix configuration.
- Replace broken nodes if node networking is corrupt.
- Validate service routing with debug pods.
- Keep add-ons aligned with cluster version.

### Takeaway summary

kube-proxy is service routing infrastructure. If ClusterIP routing breaks, check kube-proxy early.

---

## 26. NetworkPolicy not working as expected

### Interview freeze point

Policies are applied, but traffic is not blocked or allowed as expected.

### Strong interview answer

> “I would check whether the cluster CNI supports network policy enforcement, whether policies select the intended pods, whether ingress and egress are both considered, and whether DNS or required dependencies are allowed.”

### Symptoms

- Traffic still allowed after policy.
- Traffic blocked unexpectedly.
- DNS breaks after adding egress policy.
- Only Deployment pods affected.
- Policy works in one cluster but not another.

### Diagnostic commands

```bash
kubectl get networkpolicy -A
kubectl describe networkpolicy my-policy -n app
kubectl get pods -n app --show-labels
```

### Common causes

- CNI does not enforce NetworkPolicy.
- Policy podSelector does not match pods.
- Namespace selector wrong.
- Egress policy blocks DNS.
- Ingress allowed but egress blocked.
- Default deny applied unexpectedly.
- Security groups confused with NetworkPolicy.
- VPC CNI network policy feature limitations misunderstood.

### Example default deny ingress

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

### Allow DNS egress example

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

NetworkPolicy depends on enforcement support and correct selectors. Always test with debug pods.

---

## 27. Security groups block cluster traffic

### Interview freeze point

Everything looks correct in Kubernetes, but traffic fails.

### Strong interview answer

> “I would check node security groups, cluster security group, load balancer security groups, security groups for pods if used, and whether required ports are allowed between the right sources and targets.”

### Symptoms

- ALB targets unhealthy.
- Nodes cannot join.
- Pods cannot reach AWS services.
- Webhook calls time out.
- DNS fails.
- Service works within node but not across nodes.
- Only certain subnets fail.

### Common EKS security group paths

```text
Worker node → control plane endpoint
Load balancer → node/pod target
Pod → database
Pod → AWS service endpoint
Node → DNS/NTP/registry
Webhook caller → admission webhook service
```

### Diagnostic commands

```bash
aws ec2 describe-security-groups --group-ids sg-...
kubectl describe svc/ingress -n app
kubectl describe node node-name
```

### Common causes

- ALB SG cannot reach pod/node port.
- Node SG blocks node-to-node traffic.
- Cluster endpoint SG blocks node.
- Private endpoint not reachable.
- Database SG does not allow pod/node SG.
- Security groups for pods not configured correctly.
- NACL blocks traffic.
- Ephemeral ports blocked.

### Resolution

- Identify source and destination.
- Confirm port/protocol.
- Update SG rules narrowly.
- Check NACLs and route tables.
- Use Reachability Analyzer if helpful.
- Document required traffic flows.

### Takeaway summary

Kubernetes may be correct while AWS security groups block traffic. Always trace source, destination, port, and protocol.

---

## 28. Private cluster cannot pull images or reach AWS APIs

### Interview freeze point

Private nodes have no public internet. Pods or nodes cannot reach ECR, STS, S3, CloudWatch, or other AWS APIs.

### Strong interview answer

> “I would check NAT gateways or VPC endpoints, route tables, security groups, DNS, and endpoint policies. Private EKS clusters need explicit egress paths to required AWS services.”

### Symptoms

- ImagePullBackOff from ECR.
- Pod AWS SDK calls timeout.
- Node bootstrap fails.
- Logs not delivered to CloudWatch.
- STS calls timeout.
- Works in public subnet but not private.

### Common required egress paths

```text
ECR API
ECR Docker registry
S3 for image layers and artifacts
STS for identity calls
CloudWatch Logs if used
EC2/EKS APIs for controllers
Secrets Manager/SSM/KMS if used
```

### Options

```text
NAT gateway
VPC interface endpoints
VPC gateway endpoint for S3
Proxy
```

### Common causes

- No NAT gateway.
- Missing VPC endpoints.
- Endpoint policy denies action.
- Private DNS disabled on endpoint.
- Security group blocks endpoint access.
- Route table missing.
- DNS resolution disabled.

### Resolution

- Add NAT or required VPC endpoints.
- Enable private DNS for interface endpoints where needed.
- Add S3 gateway endpoint.
- Configure endpoint security groups.
- Verify from node/pod with curl/aws CLI.
- Check CloudTrail and VPC Flow Logs.

### Takeaway summary

Private clusters need planned AWS API egress. No internet does not mean no dependencies.

---

## 29. OOMKilled or resource pressure on workloads

### Interview freeze point

Pods restart under load or nodes show memory pressure.

### Strong interview answer

> “I would check pod resource requests and limits, OOMKilled events, node allocatable capacity, application memory behavior, HPA settings, and whether limits are too low or requests are too low.”

### Symptoms

- Pod restarted with reason `OOMKilled`.
- Node memory pressure.
- App slow under load.
- HPA does not scale.
- Evictions.
- Java/Node/Python memory issues.

### Diagnostic commands

```bash
kubectl describe pod pod-name -n app
kubectl top pod -n app
kubectl top node
kubectl describe node node-name
```

### Example pod status

```text
Last State: Terminated
Reason: OOMKilled
Exit Code: 137
```

### Common causes

- Memory limit too low.
- Memory leak.
- Request too low causing overpacking.
- JVM not container-aware or not tuned.
- HPA scales on CPU while memory is bottleneck.
- Node too small.
- Bursty workload.
- No resource limits/requests policy.

### Resolution

- Tune application memory.
- Right-size requests and limits.
- Add HPA or KEDA if applicable.
- Use VPA recommendations carefully.
- Use larger nodes or spread workloads.
- Monitor memory and restarts.
- Add load tests.

### Takeaway summary

OOMKilled means the container exceeded its memory limit. Fix app behavior or right-size resources.

---

## 30. Poor EKS cluster design causes recurring incidents

### Interview freeze point

This tests senior-level EKS thinking.

### Strong interview answer

> “A production EKS cluster needs clear ownership of networking, IAM, node lifecycle, add-ons, ingress, storage, upgrades, autoscaling, observability, and security boundaries. Many incidents come from weak platform design, not one broken pod.”

### Symptoms

- Frequent node issues.
- Add-ons manually drift.
- No clear upgrade process.
- Developers have broad cluster-admin.
- Subnets run out of IPs.
- Load balancers inconsistent.
- Dashboards missing.
- Alerts noisy or absent.
- No runbooks.
- CI/CD deploys without guardrails.

### Production design checklist

```text
Private subnets for nodes
Subnet IP capacity planned
Managed node groups or Karpenter with guardrails
CoreDNS, kube-proxy, VPC CNI managed and versioned
IRSA or Pod Identity for pod AWS permissions
Least privilege Kubernetes RBAC
Ingress/load balancer standards
Storage classes defined
Cluster autoscaling tested
Observability and logging installed
Upgrade runbooks
Backup/restore for stateful workloads
Network policy/security group strategy
Cost and capacity monitoring
```

### Example platform guardrail

Namespace with resource quota:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: app-quota
  namespace: app
spec:
  hard:
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.memory: 80Gi
    pods: "100"
```

LimitRange:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: defaults
  namespace: app
spec:
  limits:
    - type: Container
      defaultRequest:
        cpu: 100m
        memory: 128Mi
      default:
        memory: 512Mi
```

### Takeaway summary

Senior EKS work is platform engineering: make the safe path easy, observable, and repeatable.

---

# Bonus: AWS EKS interview answer frameworks

## Framework 1: The pod will not start answer

Use this when asked:

> “A pod is not running in EKS. What do you do?”

```text
1. kubectl get pod.
2. kubectl describe pod.
3. Read events.
4. Check Pending vs ImagePull vs CrashLoop.
5. Check node scheduling.
6. Check image pull.
7. Check secrets/config.
8. Check logs and previous logs.
9. Check IAM/network/storage if relevant.
10. Fix and verify rollout.
```

Interview version:

> “I let the pod phase and events decide the path. Pending, ImagePullBackOff, and CrashLoopBackOff are different problems.”

---

## Framework 2: The node issue answer

Use this when asked:

> “EKS nodes are not joining or NotReady. What do you check?”

```text
1. Node group health.
2. EC2 instance state.
3. Node IAM role.
4. Cluster endpoint reachability.
5. Security groups.
6. Subnet routes/NAT/endpoints.
7. Bootstrap logs.
8. Kubelet logs.
9. CNI status.
10. Replace node if unhealthy.
```

Interview version:

> “Node issues usually sit at the boundary of EC2, IAM, networking, bootstrap, and kubelet.”

---

## Framework 3: The AWS permission from pod answer

Use this when asked:

> “A pod cannot access S3 or another AWS service.”

```text
1. Identify service account.
2. Check IRSA or Pod Identity.
3. Check IAM role trust.
4. Check IAM policy.
5. Test sts get-caller-identity inside pod.
6. Check CloudTrail AccessDenied.
7. Check region.
8. Check network path to AWS API.
9. Fix role/policy/association.
10. Restart pod and verify.
```

Interview version:

> “For AWS access from pods, I check identity first, then IAM permission, then network.”

---

## Framework 4: The EKS networking answer

Use this when asked:

> “Pods cannot communicate or services fail.”

```text
1. Check pod status.
2. Check service selector.
3. Check endpoints.
4. Test DNS.
5. Test direct pod IP and service DNS.
6. Check NetworkPolicy.
7. Check kube-proxy.
8. Check VPC CNI.
9. Check security groups/NACLs.
10. Check load balancer target health if external.
```

Interview version:

> “I start inside Kubernetes with service endpoints, then move outward to CNI, DNS, security groups, and load balancer health.”

---

## Framework 5: The EKS upgrade answer

Use this when asked:

> “How do you safely upgrade EKS?”

```text
1. Review target version and release notes.
2. Check deprecated APIs.
3. Check add-on compatibility.
4. Back up critical configs.
5. Upgrade control plane.
6. Upgrade CoreDNS/kube-proxy/VPC CNI.
7. Upgrade node groups.
8. Respect PDBs and capacity.
9. Validate workloads.
10. Monitor and keep rollback plan.
```

Interview version:

> “An EKS upgrade is control plane, add-ons, nodes, and workload compatibility—not just clicking upgrade.”

---

# Common EKS interview traps and better answers

## Trap 1: “If `kubectl` says Unauthorized, is it Kubernetes RBAC?”

Weak answer:

> “Yes.”

Better answer:

> “Maybe. First I check AWS identity and EKS access mapping, then Kubernetes RBAC. EKS access has both AWS and Kubernetes layers.”

---

## Trap 2: “Pending pod means the app is broken?”

Weak answer:

> “Yes.”

Better answer:

> “No. Pending usually means scheduling, resources, taints, affinity, PVC binding, or autoscaling.”

---

## Trap 3: “No external load balancer means Kubernetes service is wrong?”

Weak answer:

> “Yes.”

Better answer:

> “Maybe, but in EKS I also check AWS Load Balancer Controller, IAM permissions, subnet tags, annotations, security groups, and AWS quotas.”

---

## Trap 4: “Pod cannot access S3, so the network is broken?”

Weak answer:

> “Yes.”

Better answer:

> “Could be network, but I first check pod identity, IAM policy, trust relationship, and CloudTrail. Then I check NAT or VPC endpoints.”

---

## Trap 5: “EKS upgrades only upgrade the control plane?”

Weak answer:

> “Yes.”

Better answer:

> “No. Nodes, CoreDNS, kube-proxy, VPC CNI, controllers, CRDs, and workloads must be compatible too.”

---

## Trap 6: “Subnet size only matters for nodes?”

Weak answer:

> “Yes.”

Better answer:

> “With the AWS VPC CNI, pods also consume VPC IP capacity. Subnet IP exhaustion can stop pods from starting.”

---

## Trap 7: “Admin IAM permissions mean admin Kubernetes permissions?”

Weak answer:

> “Yes.”

Better answer:

> “No. AWS IAM admin and Kubernetes RBAC are different. A role must be mapped into the cluster and authorized.”

---

# AWS EKS interview quick-reference table

| Issue | Main symptom | First thing to check | Common fix |
|---|---|---|---|
| Cannot connect | Unauthorized/timeout | AWS identity/kubeconfig | Fix access/endpoint |
| RBAC forbidden | Can connect, cannot act | `kubectl auth can-i` | Fix RBAC/access mapping |
| Nodes not joining | No Ready nodes | Node group health | Fix IAM/network/bootstrap |
| Nodes NotReady | Node unhealthy | Node conditions | Fix CNI/kubelet/pressure |
| Pods Pending | Pods not scheduled | Pod events | Fix resources/taints/PVC |
| CrashLoopBackOff | App restarts | Logs previous | Fix app/config/probes |
| ImagePullBackOff | Cannot pull image | Pod events | Fix image/ECR/auth |
| Pod AWS access fail | AccessDenied/timeout | Pod identity | Fix IAM/network |
| IRSA fail | Wrong/no role | Trust policy | Fix OIDC/SA/trust |
| Pod Identity fail | No credentials | Association/agent | Fix agent/role |
| IP exhaustion | Pod IP assign fail | Subnet free IPs | Add IP capacity |
| Service networking fail | Connection fail | Endpoints | Fix selector/ports |
| DNS fail | Unknown host | CoreDNS | Fix CoreDNS/network |
| LB not created | External IP pending | Service events | Fix controller/IAM/tags |
| Ingress no ALB | No ALB/address | Controller logs | Fix ingress/IAM/tags |
| Target unhealthy | ALB 503 | Target health | Fix health check/SG |
| EBS PVC pending | Storage stuck | PVC events | Fix CSI/AZ/IAM |
| EFS mount fail | Mount timeout | CSI/logs/SG | Fix NFS/mount targets |
| Autoscaler no scale | Pending pods | Autoscaler logs | Fix tags/IAM/max |
| Karpenter no nodes | Pending pods | Karpenter logs | Fix NodePool/IAM/capacity |
| Node update fail | Upgrade stuck | Node group health | Fix PDB/capacity |
| Control plane upgrade | Upgrade blocked | APIs/add-ons | Plan upgrade |
| CoreDNS unhealthy | DNS broken | CoreDNS logs | Fix add-on/config |
| VPC CNI break | Networking broken | aws-node logs | Fix add-on/config |
| kube-proxy issue | ClusterIP broken | kube-proxy pods | Fix add-on/version |
| NetworkPolicy issue | Traffic wrong | Selectors/enforcement | Fix policy/CNI |
| Security group block | Timeout | SG source/dest | Fix SG/NACL |
| Private egress fail | AWS APIs timeout | NAT/endpoints | Add endpoints/NAT |
| OOM/resource issue | OOMKilled | Pod describe/top | Tune resources |
| Poor design | Recurring incidents | Platform guardrails | Standardize EKS ops |

---

# Strong closing takeaway

EKS interviews are not just Kubernetes command tests. They are boundary tests between Kubernetes, AWS IAM, EC2, VPC, load balancing, storage, DNS, and platform operations.

A weak answer sounds like:

> “I would restart the pod.”

A strong answer sounds like:

> “I would check the pod phase and events, then follow the evidence into scheduling, image pull, CNI, IAM, storage, DNS, load balancer, node health, or AWS infrastructure depending on what Kubernetes reports.”

EKS problems usually leave evidence in:

```text
kubectl describe pod
kubectl logs
kubectl get events
kubectl describe node
kube-system add-on logs
EKS cluster and node group health
AWS CloudTrail
EC2 instance state
VPC subnet IP capacity
Security groups and route tables
Load balancer target health
CSI driver logs
Autoscaler or Karpenter logs
```

When you freeze, return to this sequence:

```text
Pod → Event → Node → Add-on → IAM → Network → Storage → Load balancer → AWS logs → Fix → Verify
```

That sequence will carry you through most EKS interview questions.

---

# Final takeaway summaries

## The one-minute summary

EKS issues usually come from access mapping, Kubernetes RBAC, node bootstrap, node readiness, pod scheduling, image pulls, pod IAM, IRSA or Pod Identity, VPC CNI IP exhaustion, service selectors, CoreDNS, load balancers, ingress, storage CSI drivers, autoscaling, Karpenter, upgrades, add-ons, network policies, security groups, private subnet egress, resource pressure, and poor platform design. The best answer starts with Kubernetes events, then follows the evidence into AWS.

## The senior-engineer summary

A senior EKS engineer understands that EKS is a managed Kubernetes control plane connected to AWS infrastructure. They debug from both sides: Kubernetes objects and AWS resources. They know pods need IPs, nodes need IAM and network path, controllers need permissions, load balancers need subnet tags and security groups, storage is AZ-aware, and upgrades include add-ons and nodes. Seniority is shown by safe defaults, repeatable node lifecycle, least privilege IAM, observability, and upgrade discipline.

## The interview survival summary

When your mind goes blank, say:

> “I would first identify the failure domain: access, scheduling, node health, pod runtime, CNI networking, IAM, DNS, load balancer, storage, autoscaling, add-ons, or upgrade compatibility. Then I would inspect Kubernetes events and logs, verify AWS IAM and VPC resources, check relevant controller logs, apply the smallest safe fix, and verify with a known workload.”

That answer works across most AWS EKS interview scenarios.

---

# Sources checked

This kit was prepared with current AWS documentation in mind, especially Amazon EKS troubleshooting, IAM troubleshooting, EKS add-ons, add-on IAM/Pod Identity guidance, CoreDNS/VPC CNI/kube-proxy update guidance, network policy troubleshooting, and EKS upgrade best practices.
