# AWS: “I Know This Stuff, But in the Interview I Freeze” Kit

## Strong intro

You can know AWS well and still freeze in an interview.

That freeze usually does not mean you lack experience. It means your knowledge is stored as real work: checking IAM policies, reading CloudTrail, testing security groups, reviewing route tables, debugging private DNS, inspecting load balancer health, looking at CloudWatch metrics, fixing ECS or EKS deployments, and recovering from failed infrastructure changes.

In production, you do not solve AWS problems by reciting service names. You solve them by isolating the layer: identity, network, DNS, compute, storage, database, deployment, observability, or cost. Then you use evidence.

This kit is built for that exact interview moment.

It covers 30 common AWS issues interviewers ask about, with symptoms, causes, diagnostic steps, fixes, and examples. It is written for people who know the work but want stronger interview language under pressure.

When you freeze, start with this sentence:

> “I would first identify whether the problem is identity, networking, DNS, compute, storage, database, deployment, scaling, observability, or quota related. Then I would check AWS evidence — CloudTrail, CloudWatch metrics and logs, VPC flow logs, route tables, security groups, IAM policy evaluation, health checks, and recent deployments — before changing anything.”

That answer already sounds like someone who can be trusted with production.

---

## How to use this kit

For every AWS issue, use this structure:

```text
Symptom → Scope → Evidence → Cause → Fix → Verify → Prevent
```

A strong AWS interview answer usually includes:

1. What the user or system sees.
2. Which AWS service is involved.
3. Whether the issue is identity, network, DNS, compute, database, storage, deployment, or quota related.
4. Which AWS tool you check first.
5. What evidence proves the cause.
6. What safe change you make.
7. How you verify the fix.

Example:

> “If an EC2 instance cannot connect to an RDS database, I would not assume RDS is down. I would check DNS resolution, route tables, security groups, NACLs, RDS subnet groups, database status, credentials, and CloudWatch metrics. I would test from the source subnet because network problems must be checked from the actual path.”

That is a production-grade answer.

---

# Top 30 AWS issues and resolutions

---

## 1. IAM access denied

### Interview freeze point

The interviewer asks:

> “A user or application gets AccessDenied in AWS. What do you check?”

A weak answer is “attach AdministratorAccess.” A strong answer shows least privilege and policy evaluation.

### Strong interview answer

> “I would identify the principal, the exact action, the resource ARN, and the request context. Then I would check identity policies, resource policies, permission boundaries, service control policies, session policies, role trust policy, and explicit denies. In AWS, an explicit deny always wins.”

### Symptoms

- `AccessDenied`
- `UnauthorizedOperation`
- Application cannot call AWS API.
- User can list resources but cannot modify them.
- Role works in one account but not another.
- CI/CD pipeline fails with permission error.

### Diagnostic commands

Check current identity:

```bash
aws sts get-caller-identity
```

Simulate policy:

```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/app-role \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::my-bucket/path/file.txt
```

Check attached role policies:

```bash
aws iam list-attached-role-policies --role-name app-role
aws iam list-role-policies --role-name app-role
```

### Common causes

- Wrong AWS account.
- Wrong role assumed.
- Missing action permission.
- Wrong resource ARN.
- Resource policy denies access.
- Service Control Policy blocks action.
- Permission boundary limits role.
- Trust policy prevents assuming role.
- Session policy reduces permissions.
- Explicit deny exists.
- KMS key policy missing permissions.

### Example bad policy

```json
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::my-bucket"
}
```

For object access, the resource should include `/*`.

### Correct policy

```json
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::my-bucket/*"
}
```

### Resolution

Attach least-privilege access:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadAppObjects",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::my-bucket/app/*"
    }
  ]
}
```

### Verify

```bash
aws sts get-caller-identity
aws s3 cp s3://my-bucket/app/config.json -
```

### Takeaway summary

AWS authorization is principal, action, resource, and context. Check all policy layers before adding broad permissions.

---

## 2. Role cannot be assumed

### Interview freeze point

A role has permissions, but the application or user cannot assume it.

### Strong interview answer

> “I would separate the role permissions policy from the role trust policy. The trust policy controls who can assume the role. The permissions policy controls what the role can do after it is assumed.”

### Symptoms

- `AccessDenied` on `sts:AssumeRole`
- Cross-account access fails.
- CI/CD cannot assume deploy role.
- EC2 or Lambda cannot use expected role.
- SSO user cannot assume target role.

### Diagnostic commands

```bash
aws iam get-role --role-name deploy-role
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/deploy-role \
  --role-session-name test-session
```

### Common causes

- Trust policy missing principal.
- Caller lacks `sts:AssumeRole`.
- External ID mismatch.
- MFA condition required but not provided.
- Wrong account ID.
- Role ARN typo.
- Service principal wrong.
- OIDC trust condition mismatch.
- Permission boundary or SCP blocks action.

### Example trust policy for cross-account role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::111111111111:role/ci-role"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

Caller also needs:

```json
{
  "Effect": "Allow",
  "Action": "sts:AssumeRole",
  "Resource": "arn:aws:iam::123456789012:role/deploy-role"
}
```

### Example trust policy for EC2

```json
{
  "Effect": "Allow",
  "Principal": {
    "Service": "ec2.amazonaws.com"
  },
  "Action": "sts:AssumeRole"
}
```

### Takeaway summary

Assuming a role requires permission on both sides: the caller must be allowed to assume, and the role must trust the caller.

---

## 3. Wrong AWS account or region

### Interview freeze point

The resource exists, but CLI says it does not.

### Strong interview answer

> “I would first confirm the AWS identity, account ID, profile, and region. Many AWS issues are caused by running commands against the wrong account or region.”

### Symptoms

- Resource not found.
- CLI and console disagree.
- Deployment went to wrong account.
- IAM permissions look wrong.
- Terraform or CloudFormation creates duplicate resources.
- Pipeline deploys to dev instead of prod.

### Diagnostic commands

```bash
aws sts get-caller-identity
aws configure list
echo $AWS_PROFILE
echo $AWS_REGION
```

List regions for EC2 resources:

```bash
aws ec2 describe-instances --region eu-west-1
aws ec2 describe-instances --region us-east-1
```

### Common causes

- Wrong CLI profile.
- Wrong default region.
- Environment variables override profile.
- CI/CD role points to wrong account.
- SSO session uses different account.
- Terraform provider has wrong region.
- Console region selector wrong.

### Resolution

Set profile explicitly:

```bash
export AWS_PROFILE=prod-admin
export AWS_REGION=eu-west-1
```

Use CLI flags:

```bash
aws s3 ls --profile prod-admin --region eu-west-1
```

Terraform provider:

```hcl
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}
```

### Prevention

- Print identity in deployment pipelines.
- Use separate accounts for environments.
- Use clear naming conventions.
- Require production approvals.
- Avoid relying on local defaults.

### Takeaway summary

Before debugging AWS resources, confirm who you are, where you are, and which region you are targeting.

---

## 4. Security group blocks traffic

### Interview freeze point

A service is down, but the instance is healthy. The network path is blocked.

### Strong interview answer

> “I would check the source, destination, port, protocol, and direction. Security groups are stateful and attached to network interfaces. I would verify inbound rules on the destination and outbound rules on the source.”

### Symptoms

- Connection timeout.
- Load balancer health check fails.
- EC2 cannot reach RDS.
- App works locally on instance but not remotely.
- One instance can connect but another cannot.

### Diagnostic commands

Describe security group:

```bash
aws ec2 describe-security-groups \
  --group-ids sg-1234567890abcdef0
```

Check instance SGs:

```bash
aws ec2 describe-instances \
  --instance-ids i-1234567890abcdef0 \
  --query "Reservations[].Instances[].SecurityGroups"
```

Test from source:

```bash
nc -vz db.example.us-east-1.rds.amazonaws.com 5432
curl -v http://10.0.2.15:8080/health
```

### Common causes

- Destination inbound rule missing.
- Source outbound restricted.
- Wrong source CIDR.
- Wrong source security group.
- Wrong port.
- Service listens on different port.
- Load balancer SG not allowed.
- RDS SG allows office IP but not app SG.

### Example: allow EC2 app SG to RDS

RDS security group inbound rule:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-rds123 \
  --protocol tcp \
  --port 5432 \
  --source-group sg-app123
```

### Good pattern

For app-to-database access, prefer source security group references over broad CIDRs:

```text
Source: sg-app
Port: 5432
Destination: sg-db
```

### Takeaway summary

Security groups are stateful firewalls. Check the actual source, destination, protocol, port, and attached ENIs.

---

## 5. NACL blocks traffic

### Interview freeze point

Security groups look correct, but traffic still fails.

### Strong interview answer

> “If security groups are correct, I would check Network ACLs. NACLs are stateless and apply at subnet level, so both inbound and outbound rules must allow the traffic, including ephemeral return ports.”

### Symptoms

- Intermittent or one-way connectivity.
- Security groups allow traffic but connection times out.
- Subnet-level traffic blocked.
- Return traffic fails.
- Flow logs show REJECT.

### Diagnostic commands

```bash
aws ec2 describe-network-acls \
  --filters Name=association.subnet-id,Values=subnet-123456
```

Check VPC Flow Logs if enabled:

```text
REJECT records indicate network filtering.
```

### Common causes

- Inbound port allowed but outbound ephemeral ports blocked.
- Rules evaluated in numeric order.
- Explicit deny before allow.
- NACL attached to wrong subnet.
- Return traffic not allowed.
- Ephemeral port range too narrow.

### Example

Allow inbound HTTPS:

```text
Inbound: allow TCP 443 from client CIDR
```

But also allow outbound ephemeral response traffic:

```text
Outbound: allow TCP 1024-65535 to client CIDR
```

For client subnet, allow outbound 443 and inbound ephemeral response.

### Resolution

Add both directions carefully:

```bash
aws ec2 create-network-acl-entry \
  --network-acl-id acl-123456 \
  --ingress \
  --rule-number 100 \
  --protocol 6 \
  --port-range From=443,To=443 \
  --cidr-block 203.0.113.0/24 \
  --rule-action allow
```

### Takeaway summary

NACLs are stateless. If NACLs are involved, think in both directions and include ephemeral ports.

---

## 6. Route table or internet gateway issue

### Interview freeze point

The instance has a public IP but cannot reach the internet.

### Strong interview answer

> “I would check subnet route table association, route to the internet gateway, public IP assignment, security group egress, NACLs, and whether the instance is actually in a public subnet.”

### Symptoms

- EC2 cannot reach internet.
- SSH to public IP fails.
- Public IP exists but no connectivity.
- Private subnet accidentally used.
- NAT expected but missing.

### Diagnostic commands

Describe subnet route table:

```bash
aws ec2 describe-route-tables \
  --filters Name=association.subnet-id,Values=subnet-123456
```

Check internet gateway:

```bash
aws ec2 describe-internet-gateways \
  --filters Name=attachment.vpc-id,Values=vpc-123456
```

Check instance public IP:

```bash
aws ec2 describe-instances \
  --instance-ids i-1234567890abcdef0 \
  --query "Reservations[].Instances[].PublicIpAddress"
```

### Public subnet requirements

A subnet is public when:

```text
Route table has 0.0.0.0/0 → Internet Gateway
Instance has public IPv4 or reachable public endpoint
Security group and NACL allow traffic
```

### Example route

```bash
aws ec2 create-route \
  --route-table-id rtb-123456 \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id igw-123456
```

### Common causes

- No route to IGW.
- Subnet associated with wrong route table.
- Internet gateway not attached.
- Instance has no public IP.
- Security group blocks egress or ingress.
- NACL blocks traffic.
- OS firewall blocks traffic.

### Takeaway summary

A public IP alone does not make a subnet public. You need the route, gateway, and firewall path.

---

## 7. NAT Gateway or private subnet egress failure

### Interview freeze point

Private instances cannot reach the internet for updates or APIs.

### Strong interview answer

> “For private subnet egress, I would check the route table points `0.0.0.0/0` to a NAT Gateway, the NAT Gateway is in a public subnet, the public subnet routes to an internet gateway, and security groups/NACLs allow traffic.”

### Symptoms

- Private EC2 cannot `yum update` or `apt update`.
- ECS tasks cannot pull images.
- Lambda in VPC cannot reach public AWS APIs.
- Outbound internet fails from private subnet.
- NAT Gateway metrics show errors.

### Diagnostic commands

Check private subnet route:

```bash
aws ec2 describe-route-tables \
  --filters Name=association.subnet-id,Values=subnet-private123
```

Check NAT Gateway:

```bash
aws ec2 describe-nat-gateways \
  --filter Name=nat-gateway-id,Values=nat-123456
```

### Correct route pattern

Private subnet:

```text
0.0.0.0/0 → nat-xxxxxxxx
```

NAT Gateway subnet:

```text
0.0.0.0/0 → igw-xxxxxxxx
```

### Common causes

- Private subnet route missing.
- NAT Gateway in private subnet.
- NAT Gateway failed or deleted.
- Public subnet route missing IGW.
- NACL blocks ephemeral traffic.
- Security group egress restricted.
- NAT Gateway in different AZ causing resilience/cost issue.
- No VPC endpoint for AWS private service access.

### Resolution

Create route from private subnet route table to NAT Gateway:

```bash
aws ec2 create-route \
  --route-table-id rtb-private123 \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id nat-123456
```

### Cost/performance note

For heavy AWS service traffic, use VPC endpoints where appropriate to reduce NAT dependency.

### Takeaway summary

Private subnet internet egress needs a complete chain: private route → NAT Gateway → public subnet route → internet gateway.

---

## 8. VPC endpoint or PrivateLink DNS issue

### Interview freeze point

A VPC endpoint exists, but applications still use public routes or fail.

### Strong interview answer

> “I would check endpoint type, endpoint policy, security group if it is an interface endpoint, route table association if it is a gateway endpoint, and private DNS. For interface endpoints, DNS must resolve to private endpoint IPs.”

### Symptoms

- App cannot reach S3, DynamoDB, STS, ECR, Secrets Manager, or another AWS service privately.
- Traffic still goes through NAT.
- DNS resolves public IP.
- Endpoint exists but access denied.
- Endpoint policy blocks action.

### Diagnostic commands

List endpoints:

```bash
aws ec2 describe-vpc-endpoints \
  --filters Name=vpc-id,Values=vpc-123456
```

DNS test from instance:

```bash
nslookup secretsmanager.eu-west-1.amazonaws.com
```

Check route tables for gateway endpoint:

```bash
aws ec2 describe-route-tables \
  --filters Name=vpc-id,Values=vpc-123456
```

### Gateway endpoint example for S3

```bash
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-123456 \
  --service-name com.amazonaws.eu-west-1.s3 \
  --route-table-ids rtb-private123 \
  --vpc-endpoint-type Gateway
```

### Interface endpoint example

```bash
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-123456 \
  --service-name com.amazonaws.eu-west-1.secretsmanager \
  --vpc-endpoint-type Interface \
  --subnet-ids subnet-a subnet-b \
  --security-group-ids sg-endpoint \
  --private-dns-enabled
```

### Common causes

- Private DNS disabled.
- Endpoint SG blocks traffic.
- Endpoint policy denies request.
- Route table not associated for gateway endpoint.
- Wrong region endpoint.
- NACL blocks traffic.
- Application uses hardcoded public endpoint.
- Missing ECR API or ECR DKR endpoint for private image pulls.

### Takeaway summary

VPC endpoints need DNS, policy, routing, and security group alignment. Endpoint existence alone is not enough.

---

## 9. DNS or Route 53 resolution failure

### Interview freeze point

Everything works by IP, but not by name.

### Strong interview answer

> “I would test DNS from the source environment, check whether the name is public or private, verify Route 53 hosted zone records, VPC association for private zones, resolver rules, TTL, and split-horizon DNS.”

### Symptoms

- `no such host`
- App connects by IP but not hostname.
- Private DNS works in one VPC but not another.
- Public DNS record wrong.
- On-prem cannot resolve private hosted zone.
- Recent DNS change not visible yet.

### Diagnostic commands

```bash
dig api.example.com
nslookup api.example.com
dig @8.8.8.8 api.example.com
```

Check hosted zones:

```bash
aws route53 list-hosted-zones
aws route53 list-resource-record-sets --hosted-zone-id Z123456
```

Check private hosted zone VPC associations:

```bash
aws route53 get-hosted-zone --id Z123456
```

### Common causes

- Wrong hosted zone.
- Record missing or wrong type.
- Private hosted zone not associated with VPC.
- Split-horizon record conflict.
- TTL caching old value.
- Resolver inbound/outbound endpoints misconfigured.
- Security group blocks DNS to resolver.
- Client uses custom DNS server that cannot resolve Route 53 private zone.

### Example private hosted zone association

```bash
aws route53 associate-vpc-with-hosted-zone \
  --hosted-zone-id Z123456 \
  --vpc VPCRegion=eu-west-1,VPCId=vpc-123456
```

### Takeaway summary

DNS problems require testing from the source path. Public and private DNS can resolve differently.

---

## 10. Application Load Balancer target unhealthy

### Interview freeze point

The load balancer exists but returns 502/503 or no traffic reaches targets.

### Strong interview answer

> “I would check target group health, health check path, port, protocol, matcher, security groups, target registration, application listener, and whether the app responds from the load balancer path.”

### Symptoms

- ALB returns 502 or 503.
- Target group has unhealthy targets.
- Service works directly but not through ALB.
- Deployment never receives traffic.
- Health checks fail.

### Diagnostic commands

```bash
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:...
```

Describe target group:

```bash
aws elbv2 describe-target-groups \
  --target-group-arns arn:aws:elasticloadbalancing:...
```

Check security groups:

```bash
aws ec2 describe-security-groups --group-ids sg-alb sg-app
```

### Common causes

- Health check path wrong.
- App listens on different port.
- Target SG does not allow ALB SG.
- App returns 301/302/401/500 to health check.
- Target not registered.
- Wrong target type: instance vs IP.
- Container port mismatch.
- NACL blocks traffic.
- App binds to localhost only.

### Example health check expectation

If health check path is:

```text
/health
```

Then target must return acceptable status, often 200.

### Resolution: allow ALB to app target

```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-app \
  --protocol tcp \
  --port 8080 \
  --source-group sg-alb
```

### ECS target group note

For ECS with `awsvpc` networking, target type is usually `ip`.

### Takeaway summary

ALB issues usually come down to target health: path, port, security group, app response, and registration.

---

## 11. CloudFront serving stale or wrong content

### Interview freeze point

The app was updated, but users still see old content.

### Strong interview answer

> “I would check CloudFront cache behavior, TTLs, cache key, origin response headers, invalidations, origin path, and whether the request is hitting the expected distribution and behavior.”

### Symptoms

- Old assets still served.
- One path works, another stale.
- Headers differ from origin.
- Different users see different content.
- Invalidation did not appear to work.
- Wrong origin receives traffic.

### Diagnostic commands

Check response headers:

```bash
curl -I https://www.example.com/app.js
```

Look for:

```text
X-Cache: Hit from cloudfront
Age: 12345
```

Create invalidation:

```bash
aws cloudfront create-invalidation \
  --distribution-id E1234567890 \
  --paths "/app.js" "/index.html"
```

### Common causes

- TTL too high.
- Cache key missing header/query/cookie needed by app.
- Origin sends cacheable headers.
- Invalidation path wrong.
- Browser cache, not CloudFront cache.
- Multiple distributions.
- Wrong origin path.
- Behavior order mismatch.

### Resolution options

- Use versioned asset filenames.
- Invalidate changed paths.
- Adjust cache policy.
- Adjust origin `Cache-Control`.
- Confirm behavior order.
- Use separate caching rules for HTML and static assets.

### Example static asset strategy

```text
/app.9f3a1c.js → cache long
/index.html → cache short or invalidate on deploy
```

### Takeaway summary

CloudFront problems are usually TTL, cache key, invalidation, origin headers, or behavior matching.

---

## 12. S3 access denied

### Interview freeze point

S3 access can be blocked by IAM, bucket policy, ACLs, KMS, public access block, VPC endpoint policy, or object ownership.

### Strong interview answer

> “I would check the caller identity, IAM policy, bucket policy, object ARN, public access block, object ownership, KMS key policy, and VPC endpoint policy. S3 access denied often involves more than one policy layer.”

### Symptoms

- `AccessDenied`
- Upload succeeds but download fails.
- List bucket works but GetObject fails.
- Works from one role but not another.
- App cannot read encrypted object.
- Public website access fails.

### Diagnostic commands

```bash
aws sts get-caller-identity

aws s3api get-bucket-policy --bucket my-bucket
aws s3api get-public-access-block --bucket my-bucket
aws s3api get-bucket-ownership-controls --bucket my-bucket
```

Test object:

```bash
aws s3 cp s3://my-bucket/path/file.txt -
```

### Common causes

- Missing `s3:GetObject` on `bucket/*`.
- Missing `s3:ListBucket` on bucket ARN.
- Bucket policy explicit deny.
- KMS key policy does not allow decrypt.
- Public access block prevents public policy.
- Object owned by another account.
- VPC endpoint policy denies request.
- Condition requires specific source VPC or encryption.

### Correct list and read policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::my-bucket"
    },
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-bucket/app/*"
    }
  ]
}
```

### KMS encrypted object requirement

Also allow:

```json
{
  "Effect": "Allow",
  "Action": "kms:Decrypt",
  "Resource": "arn:aws:kms:eu-west-1:123456789012:key/key-id"
}
```

### Takeaway summary

S3 AccessDenied is usually IAM plus bucket policy plus KMS plus public access settings. Check all policy layers.

---

## 13. S3 static website or public access issue

### Interview freeze point

The bucket has files, but the website does not load.

### Strong interview answer

> “I would check whether the design uses S3 static website hosting directly or CloudFront with S3 origin. Then I would check public access block, bucket policy, index document, object keys, CloudFront origin access, and DNS.”

### Symptoms

- 403 AccessDenied.
- 404 NoSuchKey.
- Website endpoint fails.
- CloudFront returns AccessDenied.
- Index page not found.
- Public bucket policy does not work.

### Diagnostic commands

```bash
aws s3api get-bucket-website --bucket my-site-bucket
aws s3api get-public-access-block --bucket my-site-bucket
aws s3api get-bucket-policy --bucket my-site-bucket
```

### Common causes

- Static website hosting not enabled.
- Index document missing.
- Public access block enabled.
- Bucket policy missing.
- Using REST endpoint instead of website endpoint for website hosting.
- CloudFront OAC/OAI misconfigured.
- Object key case mismatch.
- DNS points wrong target.

### Public website bucket policy example

Use only when public static website hosting is intended:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadWebsite",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-site-bucket/*"
    }
  ]
}
```

### CloudFront safer pattern

Prefer CloudFront with Origin Access Control for many production cases, keeping S3 bucket private.

### Takeaway summary

S3 website failures are usually public access block, bucket policy, index document, endpoint type, or CloudFront origin access.

---

## 14. KMS key access failure

### Interview freeze point

The IAM role has S3 or Secrets Manager access, but encrypted data still fails.

### Strong interview answer

> “For KMS-encrypted resources, IAM permission to the service is not enough. The principal must also be allowed by KMS key policy or grants to use the key. I would check key policy, IAM policy, encryption context, and cross-account access.”

### Symptoms

- `KMS.AccessDeniedException`
- S3 object access denied only for encrypted objects.
- Lambda cannot decrypt environment variables.
- EBS snapshot copy fails.
- Secrets Manager access denied due to KMS.
- Cross-account decrypt fails.

### Diagnostic commands

```bash
aws kms describe-key --key-id <key-id>
aws kms get-key-policy --key-id <key-id> --policy-name default
```

Test decrypt indirectly through the service, or with a controlled KMS test if appropriate.

### Common causes

- Key policy does not trust principal.
- IAM policy missing `kms:Decrypt`.
- Key disabled.
- Wrong key ARN or alias.
- Cross-account key policy incomplete.
- SCP denies KMS action.
- Encryption context condition mismatch.
- Resource uses AWS-managed key that cannot be shared cross-account.

### Example IAM permission

```json
{
  "Effect": "Allow",
  "Action": [
    "kms:Decrypt",
    "kms:DescribeKey"
  ],
  "Resource": "arn:aws:kms:eu-west-1:123456789012:key/abcd-1234"
}
```

### Key policy statement

```json
{
  "Sid": "AllowAppRoleDecrypt",
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::123456789012:role/app-role"
  },
  "Action": [
    "kms:Decrypt",
    "kms:DescribeKey"
  ],
  "Resource": "*"
}
```

### Takeaway summary

Encrypted AWS resources often require two permissions: service access and KMS key access.

---

## 15. RDS connectivity failure

### Interview freeze point

RDS is available, but the application cannot connect.

### Strong interview answer

> “I would check DNS, port, RDS status, security groups, subnet routing, NACLs, public accessibility, parameter group if relevant, database credentials, and CloudWatch metrics. Most RDS connection issues are network path or authentication.”

### Symptoms

- Connection timeout.
- Authentication failed.
- Could not resolve host.
- Works from bastion but not app.
- RDS endpoint reachable from one subnet but not another.
- App started failing after SG change.

### Diagnostic commands

Check RDS:

```bash
aws rds describe-db-instances \
  --db-instance-identifier mydb
```

Test from app host:

```bash
nc -vz mydb.abc123.eu-west-1.rds.amazonaws.com 5432
```

Postgres example:

```bash
psql -h mydb.abc123.eu-west-1.rds.amazonaws.com -U appuser -d appdb
```

MySQL example:

```bash
mysql -h mydb.abc123.eu-west-1.rds.amazonaws.com -u appuser -p
```

### Common causes

- RDS SG does not allow app SG.
- Wrong port.
- RDS in private subnet with no route from client.
- Public accessibility disabled.
- NACL blocks traffic.
- DNS issue.
- Wrong username/password.
- Database max connections reached.
- RDS instance down or modifying.
- SSL requirement mismatch.

### Resolution: allow app SG

```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-rds \
  --protocol tcp \
  --port 5432 \
  --source-group sg-app
```

### Takeaway summary

RDS connectivity is usually security group, subnet path, DNS, port, credentials, or database capacity.

---

## 16. RDS high CPU or slow queries

### Interview freeze point

The database is slow, but the cause could be SQL, connections, storage, or instance size.

### Strong interview answer

> “I would check CloudWatch metrics, Performance Insights if enabled, top SQL, CPU, memory, connections, read/write IOPS, storage latency, locks, and recent deployments. I would not resize before identifying whether the issue is workload or capacity.”

### Symptoms

- Application latency.
- RDS CPU high.
- Connections high.
- Storage latency high.
- Read/write IOPS saturated.
- Lock waits.
- Slow queries.

### Diagnostic checks

CloudWatch metrics:

```text
CPUUtilization
DatabaseConnections
FreeableMemory
ReadLatency
WriteLatency
ReadIOPS
WriteIOPS
FreeStorageSpace
DiskQueueDepth
```

AWS CLI:

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=mydb \
  --start-time 2026-05-02T00:00:00Z \
  --end-time 2026-05-02T01:00:00Z \
  --period 300 \
  --statistics Average
```

### Common causes

- Bad query plan.
- Missing index.
- Connection storm.
- Long transactions.
- Locks.
- Storage IOPS limit.
- Instance undersized.
- Batch job.
- Autovacuum or maintenance issue.
- Read traffic should use replica.

### Resolution options

- Tune SQL and indexes.
- Use connection pooling.
- Add read replica for read-heavy workload.
- Increase instance size if capacity-bound.
- Move batch jobs.
- Tune parameter group carefully.
- Enable Performance Insights.
- Add alarms.

### Takeaway summary

RDS performance troubleshooting starts with metrics and top SQL, not immediate resizing.

---

## 17. Lambda timeout or cold start issue

### Interview freeze point

Lambda fails intermittently or is slow.

### Strong interview answer

> “I would check duration, timeout setting, memory size, initialization time, VPC configuration, dependency calls, concurrency, retries, and logs. Lambda performance problems often come from downstream services, cold starts, or VPC/network access.”

### Symptoms

- `Task timed out`
- High latency after idle period.
- Function works sometimes.
- API Gateway returns 504.
- Lambda cannot reach internet.
- Logs show long init duration.

### Diagnostic commands

View logs:

```bash
aws logs tail /aws/lambda/my-function --follow
```

Get config:

```bash
aws lambda get-function-configuration \
  --function-name my-function
```

### Common causes

- Timeout too low.
- Memory too low, causing slow CPU.
- Large package or slow initialization.
- VPC Lambda lacks NAT or VPC endpoints.
- Downstream API slow.
- Database connection setup every invocation.
- Concurrency throttling.
- Retry storm.
- DNS or security group issue.

### Resolution examples

Increase timeout and memory:

```bash
aws lambda update-function-configuration \
  --function-name my-function \
  --timeout 30 \
  --memory-size 1024
```

For VPC Lambda needing AWS APIs, add NAT Gateway or VPC endpoints.

### Code pattern

Reuse clients outside handler:

```python
import boto3

s3 = boto3.client("s3")

def handler(event, context):
    return s3.list_buckets()
```

### Takeaway summary

Lambda timeout issues are usually runtime duration, cold start, network path, downstream dependencies, or concurrency.

---

## 18. Lambda cannot access VPC resource or internet

### Interview freeze point

Adding Lambda to a VPC can break internet access.

### Strong interview answer

> “When Lambda is attached to a VPC, it uses ENIs in selected subnets. I would check subnet routes, security groups, NACLs, NAT Gateway for internet, VPC endpoints for AWS APIs, and whether the target resource allows the Lambda security group.”

### Symptoms

- Lambda cannot reach RDS.
- Lambda cannot call public APIs.
- Lambda cannot call Secrets Manager or S3.
- Timeout with no clear error.
- Works outside VPC but fails inside VPC.

### Diagnostic checks

Lambda config:

```bash
aws lambda get-function-configuration \
  --function-name my-function \
  --query "VpcConfig"
```

Check subnet route tables:

```bash
aws ec2 describe-route-tables \
  --filters Name=association.subnet-id,Values=subnet-123456
```

### Common causes

- Lambda subnet has no NAT route for internet.
- Security group does not allow outbound.
- Target SG does not allow Lambda SG.
- NACL blocks traffic.
- No VPC endpoint for private AWS service access.
- DNS resolution disabled in VPC.
- Lambda placed in wrong subnet.

### Resolution

For RDS, allow Lambda SG on DB SG:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-rds \
  --protocol tcp \
  --port 5432 \
  --source-group sg-lambda
```

For internet access from private subnets:

```text
Lambda subnet route table:
0.0.0.0/0 → NAT Gateway
```

For private AWS API access, create interface endpoints.

### Takeaway summary

VPC Lambda networking follows normal VPC rules. Private subnet internet access needs NAT or endpoints.

---

## 19. ECS task fails to start

### Interview freeze point

The service desired count is set, but tasks keep stopping or never start.

### Strong interview answer

> “I would check ECS service events, stopped task reason, container logs, image pull, task execution role, task role, CPU/memory, network configuration, target group health, and secrets injection.”

### Symptoms

- ECS service cannot maintain desired count.
- Tasks stop immediately.
- `CannotPullContainerError`
- `ResourceInitializationError`
- Target group unhealthy.
- Secrets or logs fail.

### Diagnostic commands

```bash
aws ecs describe-services \
  --cluster my-cluster \
  --services my-service

aws ecs list-tasks \
  --cluster my-cluster \
  --service-name my-service

aws ecs describe-tasks \
  --cluster my-cluster \
  --tasks <task-arn>
```

### Common causes

- Image not found or no ECR permission.
- Task execution role missing permissions.
- Secrets Manager or SSM parameter access denied.
- Log group missing or permission denied.
- CPU/memory mismatch.
- Container exits due to config.
- Security group blocks health check.
- Wrong container port.
- Fargate subnet lacks egress.

### Task execution role permissions

Needed for pulling images and writing logs, commonly through managed policy:

```text
AmazonECSTaskExecutionRolePolicy
```

### Example task definition snippet

```json
{
  "containerDefinitions": [
    {
      "name": "api",
      "image": "123456789012.dkr.ecr.eu-west-1.amazonaws.com/api:1.2.3",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "essential": true
    }
  ]
}
```

### Takeaway summary

ECS startup failures are usually image pull, IAM roles, network egress, logs, secrets, container config, or health checks.

---

## 20. EKS pod scheduling or networking issue

### Interview freeze point

The app is on EKS, so the issue can be Kubernetes or AWS.

### Strong interview answer

> “I would check Kubernetes pod events first, then AWS-specific layers such as node group capacity, IAM roles for service accounts, VPC CNI IP exhaustion, security groups, route tables, and load balancer controller events.”

### Symptoms

- Pods stuck Pending.
- Pods cannot reach AWS services.
- LoadBalancer service not provisioned.
- Pod IP exhaustion.
- ImagePullBackOff from ECR.
- Ingress not created.

### Diagnostic commands

```bash
kubectl describe pod <pod> -n <namespace>
kubectl get nodes
kubectl get events -A --sort-by=.lastTimestamp
kubectl -n kube-system get pods
kubectl -n kube-system logs daemonset/aws-node
```

AWS checks:

```bash
aws eks describe-cluster --name my-cluster
aws eks describe-nodegroup --cluster-name my-cluster --nodegroup-name my-ng
```

### Common causes

- Node group capacity too low.
- Pod resource requests too high.
- VPC CNI lacks available subnet IPs.
- IRSA trust policy wrong.
- ECR pull permission missing.
- Security group blocks traffic.
- AWS Load Balancer Controller missing permission.
- Subnet tags missing for load balancer discovery.

### Resolution examples

Scale node group:

```bash
aws eks update-nodegroup-config \
  --cluster-name my-cluster \
  --nodegroup-name my-ng \
  --scaling-config minSize=2,maxSize=6,desiredSize=3
```

Check subnet IP availability:

```bash
aws ec2 describe-subnets \
  --subnet-ids subnet-123456 \
  --query "Subnets[].AvailableIpAddressCount"
```

### Takeaway summary

EKS troubleshooting is Kubernetes plus AWS: pod events, node capacity, VPC CNI, IAM, subnets, and controllers.

---

## 21. EKS IRSA permission failure

### Interview freeze point

The pod should access AWS using a service account, but it gets AccessDenied.

### Strong interview answer

> “I would check the Kubernetes service account annotation, IAM role trust policy, OIDC provider, audience and subject conditions, and the IAM permissions attached to the role. IRSA requires both correct Kubernetes identity and AWS trust.”

### Symptoms

- Pod gets AWS AccessDenied.
- Pod uses node role instead of intended role.
- Web identity token error.
- Service account annotation missing.
- Works on EC2 but not in pod.

### Diagnostic commands

Check service account:

```bash
kubectl get serviceaccount app-sa -n app -o yaml
```

Check pod service account:

```bash
kubectl get pod mypod -n app -o jsonpath='{.spec.serviceAccountName}'
```

Check cluster OIDC:

```bash
aws eks describe-cluster \
  --name my-cluster \
  --query "cluster.identity.oidc.issuer"
```

### Service account annotation

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: app
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/app-irsa-role
```

### Trust policy example

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLE"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLE:sub": "system:serviceaccount:app:app-sa",
      "oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLE:aud": "sts.amazonaws.com"
    }
  }
}
```

### Takeaway summary

IRSA failures are usually annotation, service account mismatch, OIDC provider, trust policy condition, or role permissions.

---

## 22. Auto Scaling Group not scaling

### Interview freeze point

The application needs more instances, but capacity does not increase.

### Strong interview answer

> “I would check scaling policies, CloudWatch alarms, desired/min/max capacity, health checks, launch template, subnet capacity, instance quotas, and whether instances fail to launch.”

### Symptoms

- ASG does not scale out.
- Desired capacity changes but instances fail.
- Instances launch then terminate.
- CloudWatch alarm not firing.
- Max capacity reached.
- No capacity in AZ.

### Diagnostic commands

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names my-asg

aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name my-asg
```

Check alarms:

```bash
aws cloudwatch describe-alarms
```

### Common causes

- Max size reached.
- Scaling policy not attached.
- Alarm threshold not crossed.
- Launch template invalid.
- AMI missing or not accessible.
- Instance type unavailable.
- Subnet has no IPs.
- Service quota reached.
- Health check grace period too short.
- Instances fail user data.

### Resolution

Update ASG capacity:

```bash
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name my-asg \
  --min-size 2 \
  --max-size 10 \
  --desired-capacity 4
```

Check failed launch activity:

```text
aws autoscaling describe-scaling-activities
```

### Takeaway summary

ASG scaling issues are often policy, alarm, capacity limit, launch template, subnet IP, or health check problems.

---

## 23. EC2 instance status checks failing

### Interview freeze point

An instance is running, but status checks fail.

### Strong interview answer

> “I would distinguish system status checks from instance status checks. System checks indicate AWS infrastructure issues. Instance checks usually indicate OS, boot, networking, filesystem, or resource exhaustion inside the instance.”

### Symptoms

- EC2 status check failed.
- Instance unreachable.
- App down.
- SSH fails.
- System or instance check failure.

### Diagnostic commands

```bash
aws ec2 describe-instance-status \
  --instance-ids i-1234567890abcdef0 \
  --include-all-instances
```

Get console output:

```bash
aws ec2 get-console-output \
  --instance-id i-1234567890abcdef0 \
  --latest
```

### Common causes

System status check:

- Underlying host issue.
- AWS hardware/network issue.

Instance status check:

- OS boot failure.
- Full disk.
- Bad fstab.
- Network config broken.
- Kernel panic.
- Exhausted memory.
- Firewall blocks health checks.
- Failed user data.

### Resolution options

System check:

```bash
aws ec2 stop-instances --instance-ids i-123456
aws ec2 start-instances --instance-ids i-123456
```

For EBS-backed instances, stop/start may move the instance to healthy hardware.

Instance check:

- Use EC2 serial console if enabled.
- Detach root volume and repair from another instance.
- Restore from AMI/snapshot.
- Replace via Auto Scaling Group.

### Takeaway summary

System status check is AWS host side. Instance status check is usually guest OS side.

---

## 24. CloudFormation stack stuck or rollback failed

### Interview freeze point

A deployment fails, but the stack is stuck in rollback.

### Strong interview answer

> “I would inspect stack events from newest to oldest to find the first failing resource. Then I would decide whether to fix and update, continue rollback, or retain resources. CloudFormation top-level errors are often less useful than resource events.”

### Symptoms

- Stack in `ROLLBACK_IN_PROGRESS`.
- Stack in `UPDATE_ROLLBACK_FAILED`.
- Resource failed to create.
- Replacement failed.
- Dependency failed.
- Stack cannot be deleted.

### Diagnostic commands

```bash
aws cloudformation describe-stack-events \
  --stack-name my-stack
```

Describe stack:

```bash
aws cloudformation describe-stacks \
  --stack-name my-stack
```

Continue rollback:

```bash
aws cloudformation continue-update-rollback \
  --stack-name my-stack
```

### Common causes

- IAM permission missing.
- Resource already exists.
- Quota exceeded.
- Security group or subnet missing.
- Custom resource failed.
- Deletion protection enabled.
- RDS/S3 bucket not empty.
- Immutable property changed.
- Timeout waiting for stabilization.

### Resolution

- Read first failing resource event.
- Fix IAM/policy/quota.
- Import or rename existing resource.
- Empty bucket if deletion intended.
- Disable deletion protection if safe.
- Continue rollback.
- Use change sets before updates.

### Change set example

```bash
aws cloudformation create-change-set \
  --stack-name my-stack \
  --template-body file://template.yaml \
  --change-set-name preview-change \
  --capabilities CAPABILITY_NAMED_IAM
```

### Takeaway summary

For CloudFormation, stack events are the truth. Find the first failing resource.

---

## 25. Terraform on AWS state or drift issue

### Interview freeze point

Terraform wants to recreate AWS resources or cannot find them.

### Strong interview answer

> “I would compare Terraform code, state, and real AWS resources. Then I would check provider region/account, remote backend, state locking, drift, resource address changes, and recent provider or module updates.”

### Symptoms

- Terraform wants to destroy or recreate resources.
- Existing AWS resource would be duplicated.
- State lock error.
- Plan differs between local and CI.
- Resource manually changed in AWS console.
- Terraform cannot find resource.

### Diagnostic commands

```bash
terraform plan
terraform state list
terraform state show aws_instance.web
aws sts get-caller-identity
```

### Common causes

- Wrong AWS account or region.
- Remote state backend wrong.
- Resource renamed without moved block.
- Manual drift.
- Provider upgrade.
- Module source changed.
- Resource imported incorrectly.
- State lock from failed run.

### Resolution examples

Import existing resource:

```bash
terraform import aws_s3_bucket.app my-existing-bucket
```

Move state after rename:

```bash
terraform state mv aws_instance.web aws_instance.app
```

Use moved block:

```hcl
moved {
  from = aws_instance.web
  to   = aws_instance.app
}
```

### Takeaway summary

Terraform AWS problems usually involve code, state, provider context, backend, or real-world drift.

---

## 26. CloudWatch logs missing

### Interview freeze point

The app failed, but there are no logs.

### Strong interview answer

> “I would check whether logs are being emitted, whether the agent or service integration is configured, whether IAM allows log writes, whether log group and stream exist, and whether retention or query time range is correct.”

### Symptoms

- No application logs in CloudWatch.
- ECS task fails but no logs.
- Lambda logs missing.
- EC2 app logs local only.
- Query returns no results.
- Log group not created.

### Diagnostic commands

List log groups:

```bash
aws logs describe-log-groups
```

Tail logs:

```bash
aws logs tail /aws/lambda/my-function --follow
```

Check ECS task definition log config:

```bash
aws ecs describe-task-definition \
  --task-definition my-task
```

### Common causes

- CloudWatch agent not installed or running.
- IAM role lacks `logs:PutLogEvents`.
- Log group not created and role cannot create it.
- Wrong region.
- App writes to file but agent not configured.
- ECS awslogs driver missing.
- Lambda never invoked.
- Retention deleted logs.
- Query time range wrong.

### ECS log configuration example

```json
"logConfiguration": {
  "logDriver": "awslogs",
  "options": {
    "awslogs-group": "/ecs/api",
    "awslogs-region": "eu-west-1",
    "awslogs-stream-prefix": "ecs"
  }
}
```

### Takeaway summary

Missing logs are usually configuration, IAM, region, log driver, or agent issues.

---

## 27. CloudWatch alarm not firing

### Interview freeze point

Monitoring exists, but the team did not get alerted.

### Strong interview answer

> “I would check the metric namespace, dimensions, statistic, period, evaluation periods, threshold, missing data behavior, alarm state, and SNS or notification target.”

### Symptoms

- Incident happened but no alarm.
- Alarm stays OK.
- Alarm shows insufficient data.
- SNS notification not received.
- Wrong resource dimension.
- Alarm fires too late.

### Diagnostic commands

Describe alarm:

```bash
aws cloudwatch describe-alarms \
  --alarm-names HighCPU
```

Get metric data:

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-123456 \
  --start-time 2026-05-02T00:00:00Z \
  --end-time 2026-05-02T01:00:00Z \
  --period 300 \
  --statistics Average
```

Test SNS subscription:

```bash
aws sns publish \
  --topic-arn arn:aws:sns:eu-west-1:123456789012:alerts \
  --message "test alert"
```

### Common causes

- Wrong dimension.
- Wrong region.
- Metric not emitted.
- Threshold too high.
- Period too long.
- Missing data treated as not breaching.
- SNS subscription not confirmed.
- Action disabled.
- Composite alarm suppresses action.
- Alarm watches average when max would catch issue.

### Takeaway summary

An alarm needs correct metric data, correct threshold logic, and a working notification path.

---

## 28. CloudTrail missing event or unclear audit trail

### Interview freeze point

Someone changed production, but you cannot find who did it.

### Strong interview answer

> “I would check CloudTrail event history, organization trails, region, event name, resource name, user identity, assumed role session, and whether data events were enabled if the action was S3 object-level or Lambda data activity.”

### Symptoms

- Cannot find who changed a resource.
- CloudTrail event missing.
- S3 object access not logged.
- Event shows assumed role but not human clearly.
- Wrong region searched.
- Trail not delivering.

### Diagnostic commands

Lookup event:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=my-resource
```

Search by event name:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AuthorizeSecurityGroupIngress
```

Check trails:

```bash
aws cloudtrail describe-trails
aws cloudtrail get-trail-status --name my-org-trail
```

### Common causes

- Looking in wrong region.
- Event older than Event History retention.
- Organization trail not configured.
- Data events not enabled.
- Assumed role session name not meaningful.
- Trail delivery failed.
- Logs stored in central account.
- CloudTrail Lake or S3 query needed.

### Resolution

- Enable organization trail.
- Send logs to central S3/SIEM.
- Enable data events for critical S3 buckets or Lambda.
- Enforce meaningful role session names.
- Protect CloudTrail bucket with strict policy.

### Takeaway summary

CloudTrail is the audit source, but management events and data events are different. Search region, event type, and identity carefully.

---

## 29. Cost spike or unexpected AWS bill

### Interview freeze point

Cost issues test operational maturity, not just technical skill.

### Strong interview answer

> “I would identify the account, service, region, usage type, and resource driving the cost increase. Then I would correlate with recent deployments, scaling events, data transfer, NAT Gateway usage, logs, snapshots, idle compute, and premium services. I would fix the driver and add budgets, tags, and alerts.”

### Symptoms

- Budget alert fired.
- NAT Gateway cost high.
- CloudWatch Logs ingestion high.
- Data transfer cost increased.
- Unused EBS volumes.
- Old snapshots.
- RDS or EC2 oversized.
- EKS nodes scaled up.

### Diagnostic commands

List unattached EBS volumes:

```bash
aws ec2 describe-volumes \
  --filters Name=status,Values=available \
  --query "Volumes[].{VolumeId:VolumeId,Size:Size,Type:VolumeType,AZ:AvailabilityZone}"
```

List snapshots owned by account:

```bash
aws ec2 describe-snapshots \
  --owner-ids self \
  --query "Snapshots[].{SnapshotId:SnapshotId,VolumeSize:VolumeSize,StartTime:StartTime}"
```

Check NAT Gateway bytes in CloudWatch:

```text
AWS/NATGateway
BytesOutToDestination
BytesInFromSource
```

### Common causes

- Idle EC2 instances.
- Unattached EBS volumes.
- Old snapshots.
- NAT Gateway data processing.
- Cross-AZ data transfer.
- CloudWatch Logs ingestion/retention.
- Load balancer left running.
- RDS Multi-AZ or large instance.
- EKS node overprovisioning.
- S3 versioning without lifecycle.
- Data egress.

### Resolution

- Stop or terminate idle compute.
- Delete unattached volumes after validation.
- Add S3 lifecycle policies.
- Add CloudWatch log retention.
- Right-size EC2/RDS.
- Use VPC endpoints to reduce NAT traffic.
- Add budgets and anomaly detection.
- Enforce cost allocation tags.

### Log retention example

```bash
aws logs put-retention-policy \
  --log-group-name /ecs/api \
  --retention-in-days 30
```

### Takeaway summary

Cost spikes are incidents. Find the service, usage type, resource, and recent change.

---

## 30. AWS service quota or regional capacity issue

### Interview freeze point

The deployment fails even though configuration and permissions are correct.

### Strong interview answer

> “I would check service quotas, regional limits, subnet IP capacity, instance type availability, and account-level restrictions. Capacity and quota issues are real operational constraints.”

### Symptoms

- Cannot launch more EC2 instances.
- ASG cannot scale.
- EIP allocation fails.
- Lambda concurrency throttled.
- ENI limit reached.
- NAT Gateway or ALB limit reached.
- EKS pods cannot get IPs.
- RDS instance creation fails.

### Diagnostic commands

List service quotas:

```bash
aws service-quotas list-service-quotas \
  --service-code ec2
```

Check EC2 instance limits:

```bash
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A
```

Check subnet available IPs:

```bash
aws ec2 describe-subnets \
  --subnet-ids subnet-123456 \
  --query "Subnets[].AvailableIpAddressCount"
```

### Common causes

- EC2 vCPU quota reached.
- Elastic IP quota reached.
- Lambda concurrency limit.
- ENI limits.
- Subnet IP exhaustion.
- Specific instance type unavailable in AZ.
- RDS quota.
- Load balancer quota.
- CloudFormation stack limit.
- IAM role/policy limits.

### Resolution

- Request quota increase.
- Use different instance family or AZ.
- Increase subnet size or add subnets.
- Release unused EIPs.
- Reduce idle resources.
- Use reserved concurrency intentionally.
- Split workloads across accounts or regions when appropriate.

### Takeaway summary

Not every AWS failure is bad code. Quotas, IP exhaustion, and regional capacity can block correct deployments.

---

# Bonus: AWS interview answer frameworks

## Framework 1: The AWS outage answer

Use this when asked:

> “An AWS-hosted application is down. What do you do?”

```text
1. Confirm user-facing symptom.
2. Check blast radius: one instance, one AZ, one region, one service, or global.
3. Check recent deployments and CloudTrail.
4. Check CloudWatch metrics and logs.
5. Check load balancer target health.
6. Check DNS and Route 53.
7. Check security groups, NACLs, and routes.
8. Check IAM and secrets if dependencies fail.
9. Check service health and quotas.
10. Apply safest rollback or fix and verify.
```

Interview version:

> “I would avoid guessing. I would follow the request path from DNS to load balancer to target to dependency, checking AWS evidence at each layer.”

---

## Framework 2: The AWS networking answer

Use this when asked:

> “An EC2 instance cannot connect to another service. How do you troubleshoot?”

```text
1. Identify source and destination.
2. Test DNS resolution.
3. Check source route table.
4. Check destination route table where relevant.
5. Check security groups.
6. Check NACLs.
7. Check public/private subnet path.
8. Check NAT, IGW, TGW, peering, or endpoint.
9. Check service firewall or app listener.
10. Use VPC Flow Logs where available.
```

Interview version:

> “I follow the packet: DNS, route, security group, NACL, target listener, and return path.”

---

## Framework 3: The AWS identity answer

Use this when asked:

> “Something gets AccessDenied. What do you check?”

```text
1. Confirm caller identity with STS.
2. Identify exact API action.
3. Identify resource ARN.
4. Check identity policy.
5. Check resource policy.
6. Check permission boundary.
7. Check SCP.
8. Check session policy.
9. Check KMS key policy if encryption is involved.
10. Look for explicit deny.
```

Interview version:

> “In AWS, explicit deny wins. I check every policy layer before adding broader access.”

---

## Framework 4: The AWS deployment failure answer

Use this when asked:

> “An AWS deployment failed. What do you do?”

```text
1. Read exact error.
2. Check deployment tool events.
3. Identify failed resource.
4. Check IAM permissions.
5. Check quota/capacity.
6. Check region/account.
7. Check dependencies.
8. Check immutable property changes.
9. Fix root cause.
10. Redeploy safely or roll back.
```

Interview version:

> “I inspect the failed resource event, not just the top-level deployment failure.”

---

## Framework 5: The AWS cost incident answer

Use this when asked:

> “AWS cost spiked. How do you investigate?”

```text
1. Identify account.
2. Identify service.
3. Identify region.
4. Identify usage type.
5. Identify resource or tag.
6. Correlate with recent deployments.
7. Check data transfer, NAT, logs, snapshots, idle compute.
8. Stop the waste safely.
9. Add budgets and anomaly alerts.
10. Add lifecycle, tagging, and guardrails.
```

Interview version:

> “I treat cost spikes like incidents: find the metric, find the resource, stop the bleeding, then prevent recurrence.”

---

# Common AWS interview traps and better answers

## Trap 1: “Can we just give AdministratorAccess?”

Weak answer:

> “Yes, that will fix it.”

Better answer:

> “It may fix the symptom but creates risk. I would identify the exact action, resource, and policy layer, then grant least privilege.”

---

## Trap 2: “The instance has a public IP, so it is public, right?”

Weak answer:

> “Yes.”

Better answer:

> “Not necessarily. It also needs a route to an internet gateway, security group/NACL allowance, and a listening service.”

---

## Trap 3: “Security groups allow it, so networking is fine?”

Weak answer:

> “Yes.”

Better answer:

> “Not always. I would also check NACLs, route tables, DNS, target listener, and return path.”

---

## Trap 4: “S3 bucket policy allows access, so it should work?”

Weak answer:

> “Yes.”

Better answer:

> “Maybe. I would also check IAM, public access block, object ownership, KMS key policy, and VPC endpoint policy.”

---

## Trap 5: “CloudWatch alarm did not fire, so the metric was fine?”

Weak answer:

> “Yes.”

Better answer:

> “Not necessarily. The alarm may have the wrong dimension, statistic, threshold, period, missing data behavior, or notification target.”

---

## Trap 6: “Lambda in a VPC can still reach the internet by default?”

Weak answer:

> “Yes.”

Better answer:

> “No. A VPC-attached Lambda in private subnets needs NAT or VPC endpoints for outbound access.”

---

## Trap 7: “CloudFormation failed, so the template is broken?”

Weak answer:

> “Yes.”

Better answer:

> “Maybe, but it could be IAM, quota, existing resource conflict, rollback issue, dependency, or immutable property. I would inspect stack events.”

---

# AWS interview quick-reference table

| Issue | Main symptom | First thing to check | Common fix |
|---|---|---|---|
| IAM denied | AccessDenied | STS identity and policy layers | Least-privilege policy fix |
| Cannot assume role | STS AssumeRole denied | Trust policy and caller permission | Fix trust/caller policy |
| Wrong account/region | Resource not found | `aws sts get-caller-identity` | Set profile/region explicitly |
| SG blocks traffic | Connection timeout | Source/destination SGs | Add precise SG rule |
| NACL blocks traffic | SG correct but traffic fails | Subnet NACLs | Allow both directions/ephemeral |
| Route/IGW issue | Public access fails | Route table and IGW | Fix public subnet route |
| NAT failure | Private egress fails | Private route to NAT | Fix NAT/subnet/route |
| VPC endpoint issue | Private AWS API fails | Endpoint DNS/policy/SG | Fix endpoint config |
| DNS issue | Name does not resolve | Route 53 zone/path | Fix record/VPC association |
| ALB unhealthy | 502/503 | Target health | Fix health check/SG/port |
| CloudFront stale | Old content served | Cache headers/TTL | Invalidate/version assets |
| S3 denied | AccessDenied | IAM/bucket/KMS/pab | Fix policy/KMS/access block |
| S3 website fail | 403/404 | Website config/policy | Fix index/public/CloudFront |
| KMS denied | Encrypted access fails | Key policy | Add KMS permission |
| RDS connectivity | DB timeout | SG/DNS/port | Allow app SG/fix path |
| RDS slow | High latency | Metrics/top SQL | Tune SQL/capacity |
| Lambda timeout | Task timed out | Logs/duration/network | Tune timeout/memory/deps |
| Lambda VPC issue | No internet/private access | Routes/NAT/endpoints | Add NAT/endpoints/SG |
| ECS task fails | Task stopped | Service events/stopped reason | Fix image/IAM/config/network |
| EKS issue | Pod/network fail | Pod events/AWS CNI | Fix capacity/IAM/CNI |
| IRSA denied | Pod AWS AccessDenied | SA annotation/trust | Fix OIDC trust/role |
| ASG not scaling | Capacity static | Scaling activities | Fix max/alarm/template/quota |
| EC2 status fail | Instance unhealthy | System vs instance check | Repair/replace/reboot |
| CloudFormation stuck | Rollback failed | Stack events | Fix failed resource |
| Terraform AWS drift | Bad plan/state | Code/state/AWS reality | Import/move/reconcile |
| Logs missing | No CloudWatch logs | Agent/log config/IAM | Configure logs/permissions |
| Alarm not firing | No alert | Metric/dimensions/SNS | Fix alarm/action |
| CloudTrail gap | Cannot find event | Region/event type/trail | Enable org/data events |
| Cost spike | Bill increased | Service/usage/resource | Stop waste/add guardrails |
| Quota issue | Deploy/scale fails | Service quotas/subnet IPs | Request quota/change design |

---

# Strong closing takeaway

AWS interviews are not just service-name tests. They are judgment tests.

A weak answer sounds like:

> “I would check AWS.”

A strong answer sounds like:

> “I would identify the failing path, confirm account and region, check identity, DNS, network routing, security controls, service health, logs, metrics, recent changes, and quotas. Then I would apply the smallest safe fix and verify from the same path the workload uses.”

AWS failures usually leave evidence somewhere: CloudTrail, CloudWatch, VPC Flow Logs, load balancer target health, stack events, service events, IAM simulation, or service metrics.

When you freeze, return to this sequence:

```text
Account → Region → Identity → DNS → Network → Security → Service health → Logs → Metrics → Recent change → Fix → Verify
```

That sequence will carry you through most AWS interview questions.

---

# Final takeaway summaries

## The one-minute summary

AWS issues usually come from IAM, wrong account or region, security groups, NACLs, route tables, NAT, DNS, load balancer health, S3 policies, KMS keys, RDS connectivity, Lambda networking, ECS/EKS configuration, autoscaling, CloudFormation, Terraform state, CloudWatch, CloudTrail, cost, or quotas. The best answer starts by identifying the failing path and checking evidence.

## The senior-engineer summary

A senior AWS engineer understands that cloud problems are cross-layer. S3 AccessDenied may be IAM, bucket policy, public access block, KMS, or endpoint policy. EC2 connectivity may be route table, security group, NACL, DNS, OS firewall, or app listener. Lambda failures may be timeout, memory, VPC routing, concurrency, or dependency latency. Seniority is shown by isolating the layer, proving the cause, and making a safe minimal fix.

## The interview survival summary

When your mind goes blank, say:

> “I would first confirm the AWS account, region, principal, resource, and exact error. Then I would check IAM, DNS, route tables, security groups, NACLs, service configuration, logs, metrics, recent deployments, and quotas. I would prove the cause, make the smallest safe change, and verify from the same path the user or workload uses.”

That answer works across most AWS interview scenarios.
