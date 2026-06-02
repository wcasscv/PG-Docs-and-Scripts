# Terraform: “I Know This Stuff, But in the Interview I Freeze” Kit

## Strong intro

You can use Terraform in real production work and still freeze when someone asks about it in an interview.

That freeze does not mean you lack skill. It usually means your knowledge lives in muscle memory: reading plans, checking state, fixing providers, reviewing modules, handling drift, and making safe changes under pressure. Interviews are different. They ask you to turn that lived experience into clean, structured answers.

This kit is built for that exact moment.

It covers 20 common Terraform issues interviewers ask about, with symptoms, causes, diagnostic steps, resolutions, and examples. It is designed for DevOps, SRE, platform, cloud, and infrastructure engineers who know the work but want stronger interview language.

When you freeze, start with this sentence:

> “I would first separate Terraform configuration problems from state problems, provider problems, cloud API problems, and real infrastructure drift. Then I would inspect the plan, state, variables, provider versions, backend, and recent changes before applying anything.”

That is a strong answer. It shows you understand Terraform is not just HCL. It is a state-driven workflow that can change live infrastructure.

---

## How to use this kit

For every Terraform issue, use this structure:

```text
Symptom → Scope → Evidence → Cause → Fix → Verify → Prevent
```

A strong interview answer usually covers:

1. What failed.
2. Whether the issue is code, state, provider, backend, dependency, permissions, or cloud-side drift.
3. What command or file you inspect first.
4. What safe fix you would make.
5. How you verify the result.
6. How you prevent repeat issues.

Example:

> “If Terraform wants to recreate a resource unexpectedly, I would inspect the plan carefully, identify the attribute causing replacement, check whether it is a ForceNew field, compare state with real infrastructure, and review recent provider or module changes before applying.”

That sounds like someone who has operated Terraform safely in production.

---

# Top 20 Terraform issues and resolutions

---

## 1. Terraform plan wants to destroy or recreate unexpected resources

### Interview freeze point

The interviewer asks:

> “Terraform plan shows it will destroy a production resource. What do you do?”

Many candidates say “do not apply,” but a stronger answer explains how to investigate.

### Strong interview answer

> “I would stop and inspect the plan. I would identify which resource is being destroyed or replaced, what attribute changed, whether that attribute forces replacement, and whether the change came from code, variables, provider behavior, state drift, or resource import/move issues. I would not apply until I understood the blast radius.”

### Symptoms

- Plan shows `-/+` replacement.
- Plan shows `destroy`.
- Plan wants to recreate a database, load balancer, disk, or cluster.
- A small config change causes a large plan.
- Resource address changed after refactor.
- Provider upgrade changes behavior.

### Diagnostic commands

Create a plan file:

```bash
terraform plan -out=tfplan
```

Show detailed plan:

```bash
terraform show tfplan
```

Show JSON plan for deeper analysis:

```bash
terraform show -json tfplan > tfplan.json
```

Inspect state:

```bash
terraform state list
terraform state show aws_instance.web
```

### Example problem

Before refactor:

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"
}
```

After refactor:

```hcl
resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = "t3.micro"
}
```

Terraform sees the old address removed and a new address added. It may plan to destroy `aws_instance.web` and create `aws_instance.app`.

### Resolution: use moved block

```hcl
moved {
  from = aws_instance.web
  to   = aws_instance.app
}
```

Then run:

```bash
terraform plan
```

### Resolution: state move for older workflows

```bash
terraform state mv aws_instance.web aws_instance.app
```

### Prevention

- Review plans carefully.
- Use `moved` blocks during refactors.
- Avoid renaming resources casually.
- Use separate workspaces or state files for environments.
- Protect critical resources using lifecycle settings where appropriate.

Example protection:

```hcl
resource "aws_db_instance" "prod" {
  identifier = "prod-db"

  lifecycle {
    prevent_destroy = true
  }
}
```

### Takeaway summary

Unexpected destroy plans are usually caused by address changes, ForceNew attributes, drift, or provider changes. Stop, inspect, and prove the cause before applying.

---

## 2. Terraform state drift

### Interview freeze point

The interviewer asks:

> “What is drift and how do you handle it?”

Many people define drift but do not explain safe resolution.

### Strong interview answer

> “Drift means real infrastructure no longer matches Terraform state or configuration. It often happens when someone changes resources manually, another automation tool changes them, or cloud defaults change. I would detect drift with refresh and plan, determine whether the manual change should be kept or reverted, then update code, import state, or apply Terraform to restore the intended state.”

### Symptoms

- Terraform plan shows changes even though code did not change.
- Cloud console shows different values than Terraform.
- A resource was manually modified.
- Terraform wants to undo a manual hotfix.
- Terraform cannot find a resource.
- Terraform state references a deleted object.

### Diagnostic commands

Refresh state and plan:

```bash
terraform plan -refresh=true
```

Refresh only:

```bash
terraform apply -refresh-only
```

Inspect state:

```bash
terraform state show aws_security_group.web
```

### Example drift

Terraform code:

```hcl
resource "aws_security_group_rule" "web_https" {
  type              = "ingress"
  security_group_id = aws_security_group.web.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/8"]
}
```

Someone manually adds `0.0.0.0/0` in the console. Terraform plan may show it wants to remove the manual rule if Terraform owns that rule.

### Resolution options

If manual change is wrong:

```bash
terraform apply
```

Terraform restores desired state.

If manual change is correct, update code:

```hcl
cidr_blocks = ["10.0.0.0/8", "203.0.113.0/24"]
```

Then:

```bash
terraform plan
terraform apply
```

If resource exists but is not in state:

```bash
terraform import aws_security_group.web sg-1234567890abcdef0
```

### Prevention

- Restrict manual console changes.
- Use CI/CD for Terraform applies.
- Run scheduled drift detection.
- Document emergency changes and reconcile them quickly.
- Use policy-as-code for high-risk resources.

### Takeaway summary

Drift is not always “bad.” Sometimes it is an emergency fix. The key is to reconcile reality, state, and code deliberately.

---

## 3. State file locking problems

### Interview freeze point

Terraform fails because state is locked. Candidates may not know when it is safe to unlock.

### Strong interview answer

> “State locking prevents concurrent writes to the same state. If a lock exists, I would first confirm whether another Terraform run is active. If not, I would inspect the backend lock and only force-unlock when I am sure the previous run is dead. Force-unlocking during an active apply can corrupt state.”

### Symptoms

- `Error acquiring the state lock`
- Pipeline stuck.
- Local run blocked by previous run.
- DynamoDB lock remains after failed run.
- Remote backend says state is locked.

### Example error

```text
Error: Error acquiring the state lock

Lock Info:
  ID:        12345678
  Path:      prod/terraform.tfstate
  Operation: OperationTypeApply
  Who:       ci-runner
```

### Diagnostic steps

- Check CI/CD system for running Terraform jobs.
- Ask whether another engineer is applying.
- Inspect backend lock table if using S3 and DynamoDB.
- Review timestamps.
- Confirm no active apply is running.

### Resolution

If the lock is stale:

```bash
terraform force-unlock 12345678
```

Then rerun plan:

```bash
terraform plan
```

### S3 backend example with DynamoDB lock

```hcl
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "prod/network/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### Prevention

- Use remote backend with locking.
- Run applies through a controlled pipeline.
- Avoid multiple people applying same state.
- Do not bypass locks.
- Use separate state files for unrelated stacks.
- Monitor failed or cancelled pipeline jobs.

### Takeaway summary

A locked state is a safety mechanism. Force-unlock only after proving the original run is not active.

---

## 4. Remote backend misconfiguration

### Interview freeze point

Terraform works locally but fails in CI, or two engineers have different state.

### Strong interview answer

> “If Terraform behaves differently between users or CI, I would check backend configuration first. A remote backend should store state centrally, support locking, use encryption, and be separated by environment or stack. Backend mistakes can cause duplicate infrastructure or unsafe changes.”

### Symptoms

- Terraform wants to create resources that already exist.
- Different users see different plans.
- CI cannot find state.
- Local state accidentally used.
- State path points to wrong environment.
- Backend init fails.

### Diagnostic commands

Initialize backend:

```bash
terraform init
```

Reconfigure backend:

```bash
terraform init -reconfigure
```

Migrate backend:

```bash
terraform init -migrate-state
```

Show current backend settings:

```bash
terraform providers
```

Check local files:

```bash
ls -la
cat .terraform/terraform.tfstate
```

### Bad pattern

Using local state for shared infrastructure:

```bash
terraform.tfstate
```

This can lead to two people managing the same infrastructure independently.

### Better pattern

```hcl
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "prod/app/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### Common causes

- Wrong backend key.
- Missing backend config in CI.
- Using local state by accident.
- Same backend key shared by multiple environments.
- Missing locking.
- Missing IAM permissions.
- Backend bucket was recreated.
- Backend region mismatch.

### Resolution

Reinitialize correctly:

```bash
terraform init -reconfigure
```

If moving from local to remote:

```bash
terraform init -migrate-state
```

### Prevention

- Use remote state for team-managed infrastructure.
- Keep environment state paths explicit.
- Use separate backend keys per stack and environment.
- Enable encryption and locking.
- Restrict state bucket access.
- Do not commit state files.

### Takeaway summary

Backend configuration controls where Terraform stores truth. If the backend is wrong, Terraform’s view of reality is wrong.

---

## 5. Provider version conflicts

### Interview freeze point

Everything worked yesterday. Today `terraform init` fails or the plan changes after provider upgrade.

### Strong interview answer

> “Provider versions matter because providers define resource behavior and schemas. I would check required provider constraints, lock file changes, module constraints, and recent provider upgrades. I would pin compatible versions, review changelogs for breaking changes, and upgrade deliberately.”

### Symptoms

- `terraform init` fails.
- Provider version constraints conflict.
- Plan changes after init.
- Resource arguments deprecated.
- New provider behavior causes replacement.
- CI and local use different provider versions.

### Diagnostic commands

Show providers:

```bash
terraform providers
```

Upgrade providers:

```bash
terraform init -upgrade
```

Check lock file:

```bash
cat .terraform.lock.hcl
```

### Example provider constraint

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### Bad pattern

```hcl
version = ">= 4.0"
```

This may allow unexpected major upgrades.

### Better pattern

```hcl
version = "~> 5.30"
```

This allows patch/minor updates within a safer range depending on version strategy.

### Module conflict example

Root module:

```hcl
version = "~> 5.0"
```

Child module:

```hcl
version = "~> 4.0"
```

Terraform cannot select one provider version that satisfies both.

### Resolution

- Align provider constraints across modules.
- Commit `.terraform.lock.hcl`.
- Upgrade providers in planned changes.
- Review provider release notes.
- Run plan in lower environments first.

### Prevention

- Pin provider versions.
- Use dependency update automation with review.
- Avoid broad version constraints.
- Test provider upgrades separately from infrastructure changes.

### Takeaway summary

Provider upgrades are code changes. Treat them with the same review and testing as application dependencies.

---

## 6. Module versioning and source issues

### Interview freeze point

The interviewer asks why a module changed behavior even though your root code did not.

### Strong interview answer

> “Modules should be versioned. If a module source points to a moving branch, the behavior can change without visible root code changes. I would pin module versions or Git refs, inspect module inputs and outputs, and update modules deliberately.”

### Symptoms

- Plan changes unexpectedly.
- CI pulls different module code than local.
- Module source cannot be downloaded.
- Module input variable missing.
- Output name changed.
- Module update causes resource replacement.

### Bad pattern

```hcl
module "vpc" {
  source = "git::https://github.com/company/terraform-vpc.git"
}
```

This may pull the default branch.

### Better pattern

```hcl
module "vpc" {
  source = "git::https://github.com/company/terraform-vpc.git?ref=v1.4.2"
}
```

Registry module example:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.0"

  name = "prod-vpc"
  cidr = "10.0.0.0/16"
}
```

### Diagnostic commands

Initialize modules:

```bash
terraform init
```

Upgrade modules:

```bash
terraform init -upgrade
```

Inspect module source:

```bash
ls .terraform/modules
```

### Resolution

- Pin module versions.
- Use semantic versioning.
- Avoid tracking `main` for production.
- Review module changelogs.
- Test upgrades in non-prod.
- Use `moved` blocks inside modules when refactoring resources.

### Takeaway summary

Unpinned modules are hidden change risk. Pin module versions and upgrade deliberately.

---

## 7. Terraform state contains secrets

### Interview freeze point

Many candidates know not to print secrets, but forget Terraform state often stores sensitive values.

### Strong interview answer

> “Terraform state can contain secrets even if variables are marked sensitive. Sensitive hides CLI output; it does not remove values from state. I would protect state with encryption, access controls, remote backend security, secret rotation, and avoid storing secrets directly when possible.”

### Symptoms

- Secret appears in state.
- `terraform output` hides value but state contains it.
- State bucket has broad access.
- Database password managed in Terraform.
- Secret accidentally committed in local state.
- CI logs reveal sensitive values.

### Example

```hcl
variable "db_password" {
  type      = string
  sensitive = true
}
```

Resource:

```hcl
resource "aws_db_instance" "app" {
  identifier = "app-db"
  username   = "appuser"
  password   = var.db_password
}
```

The password may still be stored in state.

### Output example

```hcl
output "db_password" {
  value     = var.db_password
  sensitive = true
}
```

This hides CLI output but does not remove secret from state.

### Resolution

- Encrypt remote state.
- Restrict state access.
- Use cloud secret managers.
- Avoid outputs for secrets.
- Rotate leaked secrets.
- Avoid committing local state.
- Use separate state files to reduce blast radius.

### S3 backend security

```hcl
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "prod/app/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### Prevention

`.gitignore`:

```gitignore
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
!.terraform.lock.hcl
```

Note: Commit `.terraform.lock.hcl`, but do not commit state or `.terraform` directories.

### Takeaway summary

Sensitive variables hide display, not storage. Treat Terraform state as highly sensitive.

---

## 8. Resource import problems

### Interview freeze point

The infrastructure already exists, and the interviewer asks how to bring it under Terraform.

### Strong interview answer

> “I would write matching Terraform configuration first, then import the existing resource into the correct resource address. After import, I would run plan and adjust configuration until Terraform shows no unexpected changes. Import adds state; it does not automatically generate perfect configuration in most workflows.”

### Symptoms

- Resource exists but Terraform wants to create a duplicate.
- Import succeeds but plan wants to change many fields.
- Wrong resource address imported.
- Imported resource belongs in a module.
- Resource ID format is incorrect.
- State has object but code does not.

### Basic import

```bash
terraform import aws_security_group.web sg-1234567890abcdef0
```

Import into module:

```bash
terraform import module.network.aws_security_group.web sg-1234567890abcdef0
```

### Example configuration

```hcl
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Web security group"
  vpc_id      = var.vpc_id
}
```

Then import:

```bash
terraform import aws_security_group.web sg-1234567890abcdef0
```

Then run:

```bash
terraform plan
```

### Common causes of noisy plan after import

- Missing tags in code.
- Provider default values differ.
- Computed attributes included incorrectly.
- Lifecycle settings missing.
- Wrong resource type.
- Resource has manually configured fields.
- Module input values do not match real resource.

### Resolution

Adjust config until plan is clean or intentional:

```hcl
tags = {
  Environment = "prod"
  Owner       = "platform"
}
```

For attributes managed outside Terraform, consider:

```hcl
lifecycle {
  ignore_changes = [
    tags["LastPatched"]
  ]
}
```

Use `ignore_changes` carefully. It can hide real drift.

### Takeaway summary

Import is a reconciliation process: write config, import state, plan, adjust, repeat.

---

## 9. `count` and `for_each` address instability

### Interview freeze point

A resource gets recreated when a list changes. This is a classic Terraform issue.

### Strong interview answer

> “Using `count` with lists can cause address instability because resources are identified by numeric index. If the list order changes or an item is removed from the middle, Terraform may replace the wrong resources. I prefer `for_each` with stable keys for long-lived resources.”

### Symptoms

- Removing one item causes multiple replacements.
- Resource addresses shift from `[1]` to `[0]`.
- Plan destroys and recreates unexpected objects.
- Reordering a list causes changes.
- Hard to target one resource.

### Bad example with `count`

```hcl
variable "users" {
  type    = list(string)
  default = ["alice", "bob", "charlie"]
}

resource "aws_iam_user" "user" {
  count = length(var.users)
  name  = var.users[count.index]
}
```

If `alice` is removed, `bob` moves from index 1 to index 0. Terraform may treat this as replacement.

### Better example with `for_each`

```hcl
variable "users" {
  type = set(string)
  default = ["alice", "bob", "charlie"]
}

resource "aws_iam_user" "user" {
  for_each = var.users
  name     = each.key
}
```

Address becomes:

```text
aws_iam_user.user["alice"]
aws_iam_user.user["bob"]
aws_iam_user.user["charlie"]
```

### Better map example

```hcl
variable "instances" {
  type = map(object({
    instance_type = string
    ami_id        = string
  }))
}

resource "aws_instance" "app" {
  for_each = var.instances

  ami           = each.value.ami_id
  instance_type = each.value.instance_type

  tags = {
    Name = each.key
  }
}
```

### Resolution

When changing from `count` to `for_each`, use moved blocks:

```hcl
moved {
  from = aws_iam_user.user[0]
  to   = aws_iam_user.user["alice"]
}
```

### Takeaway summary

Use `for_each` with stable keys for long-lived resources. Use `count` mainly for simple optional resources.

---

## 10. Dependency ordering problems

### Interview freeze point

Terraform usually builds a dependency graph automatically, but sometimes dependencies are hidden.

### Strong interview answer

> “Terraform infers dependencies from references. If a resource must wait for another but there is no reference between them, Terraform may create or destroy in the wrong order. I would prefer explicit references through attributes, and use `depends_on` only when the dependency is real but not visible in the config.”

### Symptoms

- Resource creation fails because another resource is not ready.
- IAM policy attachment races with service creation.
- Kubernetes resource fails because cluster is not ready.
- Destroy order causes dependency errors.
- Null resource runs too early.

### Implicit dependency example

```hcl
resource "aws_instance" "web" {
  subnet_id = aws_subnet.public.id
}
```

Terraform knows the instance depends on the subnet.

### Hidden dependency example

```hcl
resource "aws_iam_role_policy_attachment" "app" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.app.arn
}

resource "aws_lambda_function" "app" {
  function_name = "app"
  role          = aws_iam_role.app.arn
}
```

The Lambda references the role, but may still need policy attachment to be complete before creation.

### Resolution: explicit depends_on

```hcl
resource "aws_lambda_function" "app" {
  function_name = "app"
  role          = aws_iam_role.app.arn

  depends_on = [
    aws_iam_role_policy_attachment.app
  ]
}
```

### Common causes

- Eventual consistency in cloud APIs.
- IAM propagation delay.
- Resource readiness not represented by API.
- Provisioners or external scripts.
- Cross-provider dependencies.
- Module output does not express full dependency.

### Caution

Do not overuse `depends_on`. Too many explicit dependencies make plans slower and harder to reason about.

### Takeaway summary

Terraform follows references. If the dependency is hidden from Terraform, make it visible.

---

## 11. Circular dependencies

### Interview freeze point

Terraform reports a cycle and candidates may not know how to break it.

### Strong interview answer

> “A cycle means Terraform cannot determine a valid create or destroy order because resources depend on each other. I would inspect the dependency chain, remove unnecessary references, split resources, use data sources carefully, or break the design into phases.”

### Symptoms

- `Error: Cycle`
- Two resources reference each other.
- Module outputs feed back into module inputs.
- Security groups reference each other inline.
- Resource cannot be planned.

### Example problem

```hcl
resource "aws_security_group" "app" {
  name = "app"

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.lb.id]
  }
}

resource "aws_security_group" "lb" {
  name = "lb"

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
}
```

### Resolution: split rules into separate resources

```hcl
resource "aws_security_group" "app" {
  name = "app"
}

resource "aws_security_group" "lb" {
  name = "lb"
}

resource "aws_security_group_rule" "app_from_lb" {
  type                     = "ingress"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.lb.id
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "lb_from_app" {
  type                     = "ingress"
  security_group_id        = aws_security_group.lb.id
  source_security_group_id = aws_security_group.app.id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
}
```

### Other fixes

- Remove unnecessary output-input loops.
- Split into two apply phases only when truly needed.
- Use data sources only for already-existing resources.
- Avoid modules depending on each other both ways.

### Takeaway summary

A dependency cycle is a design problem. Break the loop by separating resources or removing unnecessary references.

---

## 12. `lifecycle ignore_changes` misuse

### Interview freeze point

`ignore_changes` can solve noise, but it can also hide real problems.

### Strong interview answer

> “I use `ignore_changes` only when a field is intentionally managed outside Terraform or changes automatically. It should not be used to silence plan noise without understanding the cause. Overuse can hide drift and security issues.”

### Symptoms

- Terraform constantly wants to change tags or metadata.
- Cloud service modifies an attribute after creation.
- Another controller manages part of the resource.
- Plan noise causes confusion.
- `ignore_changes` hides important drift.

### Example use case

An external patching system updates a tag:

```hcl
resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  tags = {
    Name        = "app"
    Environment = "prod"
  }

  lifecycle {
    ignore_changes = [
      tags["LastPatched"]
    ]
  }
}
```

### Dangerous example

```hcl
lifecycle {
  ignore_changes = all
}
```

This can make Terraform stop managing meaningful changes.

### Better approach

- Understand why drift exists.
- Decide ownership of each field.
- Ignore only the specific field.
- Document the reason.
- Monitor ignored fields elsewhere if important.

### Common legitimate uses

- Auto-generated metadata.
- Controller-managed annotations.
- External autoscaling desired capacity.
- Fields changed by cloud provider after creation.
- Temporary migration period.

### Takeaway summary

`ignore_changes` is a scalpel, not duct tape. Use it narrowly and intentionally.

---

## 13. Provider authentication and permissions failures

### Interview freeze point

Terraform plan or apply fails because the cloud provider rejects the request.

### Strong interview answer

> “I would verify which identity Terraform is using, whether credentials are loaded correctly, and whether that identity has permissions for plan and apply. I would check environment variables, provider config, assumed roles, CI secrets, and cloud audit logs.”

### Symptoms

- `AccessDenied`
- `Unauthorized`
- `InvalidClientTokenId`
- `ExpiredToken`
- `permission denied`
- Works locally but fails in CI.
- Plan works but apply fails.
- Provider cannot refresh state.

### AWS example provider

```hcl
provider "aws" {
  region = "eu-west-1"

  assume_role {
    role_arn = "arn:aws:iam::123456789012:role/terraform-deploy"
  }
}
```

### Diagnostic commands

Check AWS identity:

```bash
aws sts get-caller-identity
```

Run Terraform with environment variables:

```bash
AWS_PROFILE=prod terraform plan
```

Enable Terraform logging when needed:

```bash
TF_LOG=DEBUG terraform plan
```

Use logs carefully because they may expose sensitive values.

### Common causes

- Wrong cloud profile.
- Expired temporary credentials.
- Missing assume role permission.
- CI secret not set.
- Provider region wrong.
- State backend permissions missing.
- Apply needs permissions that plan did not.
- Service control policy blocks action.

### Resolution

- Fix provider credentials.
- Use least-privilege Terraform role.
- Separate read-only plan permissions from apply permissions if desired.
- Store CI secrets securely.
- Use OIDC federation where possible.
- Check cloud audit logs for denied actions.

### Takeaway summary

Always know which identity Terraform is using. Many Terraform failures are actually IAM failures.

---

## 14. Environment separation mistakes

### Interview freeze point

The interviewer asks how you avoid applying dev changes to prod.

### Strong interview answer

> “I would separate environments through clear backend state paths, variables, accounts/subscriptions/projects, and pipeline controls. I would avoid relying only on workspaces for hard isolation when account-level separation is needed.”

### Symptoms

- Dev change targets prod.
- Prod and staging share state.
- Same resource names conflict.
- Wrong variable file used.
- Workspace confusion.
- CI applies to wrong environment.

### Basic environment layout

```text
infra/
  envs/
    dev/
      main.tf
      backend.tf
      terraform.tfvars
    staging/
      main.tf
      backend.tf
      terraform.tfvars
    prod/
      main.tf
      backend.tf
      terraform.tfvars
  modules/
    network/
    app/
```

### Backend example for prod

```hcl
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "prod/app/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### Variable file usage

```bash
terraform plan -var-file=prod.tfvars
```

### Workspace example

```bash
terraform workspace list
terraform workspace select prod
```

### Caution on workspaces

Workspaces can be useful, but they may not be enough isolation for production. Separate cloud accounts or projects are stronger.

### Prevention

- Use separate cloud accounts/projects for prod.
- Use separate backend keys per environment.
- Use pipeline approvals for prod.
- Make environment visible in resource names and tags.
- Avoid manual local prod applies.
- Use policy checks.

### Takeaway summary

Environment separation is about blast-radius control. State, credentials, variables, and pipelines must all point to the right place.

---

## 15. Variable validation and type problems

### Interview freeze point

Terraform accepts bad input and fails later, or creates the wrong infrastructure.

### Strong interview answer

> “I would use strong variable types and validation blocks so invalid input fails early. This prevents bad infrastructure changes caused by typoed environments, malformed CIDRs, wrong instance sizes, or missing required values.”

### Symptoms

- Plan fails deep in a module.
- Wrong resource size used.
- CIDR invalid.
- String passed where list expected.
- Boolean passed as string.
- Typo like `prd` instead of `prod`.
- Optional value missing.

### Bad variable

```hcl
variable "environment" {
  type = string
}
```

This accepts anything.

### Better variable with validation

```hcl
variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}
```

### Object variable

```hcl
variable "app" {
  type = object({
    name          = string
    instance_type = string
    desired_count = number
  })
}
```

### CIDR validation

```hcl
variable "vpc_cidr" {
  type = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}
```

### Optional fields example

```hcl
variable "tags" {
  type    = map(string)
  default = {}
}
```

### Takeaway summary

Good variable typing catches mistakes before Terraform talks to the cloud API.

---

## 16. Plan/apply differences and unknown values

### Interview freeze point

Terraform says “known after apply,” and the interviewer asks what that means.

### Strong interview answer

> “Terraform plan can only know values available before creation. Some values are unknown until the provider creates or reads the resource. If those unknowns drive counts, keys, or dependencies, planning can fail or become unstable. I would design modules so resource addresses use known stable values.”

### Symptoms

- `known after apply`
- `Invalid for_each argument`
- `Invalid count argument`
- Plan cannot determine number of resources.
- Values are computed by provider.
- Apply result differs from expected.

### Example problem

```hcl
resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = "t3.micro"
}

resource "aws_security_group_rule" "rule" {
  for_each = toset(aws_instance.app.*.private_ip)

  type        = "ingress"
  from_port   = 8080
  to_port     = 8080
  protocol    = "tcp"
  cidr_blocks = ["${each.key}/32"]
}
```

Private IP may be unknown until apply, making it unsafe as a `for_each` key.

### Better design

Use stable input keys:

```hcl
variable "instances" {
  type = map(object({
    subnet_id = string
  }))
}

resource "aws_instance" "app" {
  for_each = var.instances

  ami           = var.ami_id
  instance_type = "t3.micro"
  subnet_id     = each.value.subnet_id
}

resource "aws_security_group_rule" "rule" {
  for_each = var.instances

  type        = "ingress"
  from_port   = 8080
  to_port     = 8080
  protocol    = "tcp"
  cidr_blocks = ["10.0.0.0/8"]
}
```

### Resolution

- Do not use unknown computed values as `for_each` keys.
- Use input maps with stable keys.
- Use data sources for existing known resources.
- Split applies only as a last resort.
- Avoid designs where resource count depends on provider-computed outputs.

### Takeaway summary

Terraform needs stable addresses during planning. Use known inputs for `for_each` keys and resource counts.

---

## 17. Data source failures

### Interview freeze point

A data source fails and the candidate treats it like a resource.

### Strong interview answer

> “Data sources read existing infrastructure. If a data source fails, I would check whether the object exists, whether filters are too broad or too narrow, whether the provider region/account is correct, and whether permissions allow reading it.”

### Symptoms

- Data source returns no results.
- Data source returns multiple results.
- Works in one region but not another.
- Works locally but not CI.
- Plan fails before resources are created.
- Data source depends on a resource being created in same apply.

### Example data source

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
```

Use it:

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
}
```

### Common causes

- Wrong region.
- Wrong account.
- Missing read permissions.
- Filter returns no match.
- Filter returns more than one match where only one expected.
- Object not created yet.
- Using data source for something Terraform should manage as a resource.

### Resolution

- Tighten filters.
- Confirm provider region/account.
- Add required read permissions.
- Use resource references instead of data source for resources managed in same config.
- Make data source lookup deterministic.

### Bad pattern

```hcl
data "aws_security_group" "app" {
  name = "app-sg"
}
```

If multiple security groups share this name, lookup may fail or select unexpectedly.

Better:

```hcl
data "aws_security_group" "app" {
  id = var.app_security_group_id
}
```

### Takeaway summary

Data sources are reads, not ownership. Use precise filters and correct provider context.

---

## 18. Terraform formatting, validation, and linting issues

### Interview freeze point

This sounds simple, but it tests whether you work cleanly in teams.

### Strong interview answer

> “I would use `terraform fmt`, `terraform validate`, and lint/security tools in CI. Formatting keeps code readable, validation catches syntax and provider schema issues, and policy/security tools catch risky patterns before apply.”

### Basic commands

Format code:

```bash
terraform fmt -recursive
```

Check formatting:

```bash
terraform fmt -check -recursive
```

Validate:

```bash
terraform validate
```

Initialize first:

```bash
terraform init
terraform validate
```

### Example CI flow

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

For plan in CI:

```bash
terraform init
terraform plan -out=tfplan
```

### Common tools

- `terraform fmt`
- `terraform validate`
- `tflint`
- `tfsec`
- `checkov`
- Open Policy Agent
- Sentinel in Terraform Cloud/Enterprise

### Example validation problem

```hcl
resource "aws_instance" "web" {
  ami = var.ami_id
  instance_type = "t3.micro"
  unknown_arg = true
}
```

`terraform validate` can catch unsupported arguments.

### Prevention

- Run checks locally before PR.
- Enforce checks in CI.
- Review plan output in pull requests.
- Add security scanning for public exposure, encryption, and IAM risks.
- Keep modules documented.

### Takeaway summary

Terraform quality gates reduce review noise and prevent simple mistakes from reaching production.

---

## 19. Long-running applies and partial failures

### Interview freeze point

An apply fails halfway. The candidate must explain how to recover safely.

### Strong interview answer

> “If apply partially fails, I would not rerun blindly. I would inspect what was created, refresh state, review the new plan, and determine whether Terraform state matches real infrastructure. Then I would fix the root cause and reapply, import missing resources, or remove bad state entries only if needed.”

### Symptoms

- Apply fails after creating some resources.
- Cloud resource exists but state does not.
- State contains resource but cloud resource failed.
- Retry wants to create duplicates.
- Timeout during creation.
- Provider API error mid-apply.

### Diagnostic commands

Refresh and inspect:

```bash
terraform plan -refresh=true
terraform state list
terraform state show aws_instance.web
```

Check real cloud resource using provider CLI or console.

### Common causes

- Cloud API timeout.
- Permission denied after partial creation.
- Quota exceeded.
- Dependency not ready.
- Resource created but provider failed to read it.
- Network interruption.
- CI job cancelled.

### Resolution options

If state is correct and resource exists:

```bash
terraform plan
terraform apply
```

If resource exists but is missing from state:

```bash
terraform import aws_instance.web i-1234567890abcdef0
```

If state has an object that should not be managed:

```bash
terraform state rm aws_instance.web
```

Be careful: `state rm` only removes from Terraform state. It does not delete the real resource.

If the resource must be destroyed:

```bash
terraform destroy -target=aws_instance.web
```

Use `-target` carefully and only for recovery/surgical operations.

### Prevention

- Use remote state and locking.
- Keep applies in CI with timeouts set appropriately.
- Split very large stacks.
- Monitor quotas before large changes.
- Use smaller blast-radius modules/states.
- Avoid cancelling applies casually.

### Takeaway summary

A partial apply is a reconciliation problem. Compare code, state, and real infrastructure before retrying.

---

## 20. Poor state and stack design

### Interview freeze point

Terraform is slow, plans are huge, and every change touches too much. This tests architecture, not syntax.

### Strong interview answer

> “I would design Terraform state around blast radius, ownership, lifecycle, and dependency boundaries. A single huge state file can make plans slow and risky. Too many tiny states can create dependency complexity. The goal is clear ownership and safe change scope.”

### Symptoms

- Plan takes too long.
- One small change touches hundreds of resources.
- Teams block each other.
- State lock contention is frequent.
- Hard to review plans.
- Large blast radius.
- Cross-stack dependencies are messy.
- Applies fail because unrelated resources are included.

### Bad pattern

One state for everything:

```text
global-prod.tfstate
```

Contains:

```text
network
databases
kubernetes
apps
iam
monitoring
dns
```

A small app change now shares state with critical networking and databases.

### Better pattern

Split by lifecycle and ownership:

```text
prod/network/terraform.tfstate
prod/security/terraform.tfstate
prod/databases/terraform.tfstate
prod/kubernetes/terraform.tfstate
prod/apps/payments/terraform.tfstate
prod/apps/orders/terraform.tfstate
```

### Remote state data example

Network stack output:

```hcl
output "vpc_id" {
  value = aws_vpc.main.id
}
```

App stack reads it:

```hcl
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "company-terraform-state"
    key    = "prod/network/terraform.tfstate"
    region = "eu-west-1"
  }
}

resource "aws_security_group" "app" {
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
}
```

### Caution

Remote state can expose sensitive outputs and creates coupling. Publish only needed outputs and secure access.

### Design rules

Split state by:

- Environment.
- Ownership team.
- Lifecycle.
- Blast radius.
- Apply frequency.
- Dependency direction.
- Security boundary.

Avoid splitting so much that every apply needs many remote states.

### Takeaway summary

Good Terraform design is about safe ownership boundaries. State layout is an architecture decision.

---

# Bonus: Terraform interview answer frameworks

## Framework 1: The scary plan answer

Use this when asked:

> “Terraform wants to destroy something important. What do you do?”

```text
1. Stop. Do not apply.
2. Save and inspect the plan.
3. Identify resource address and action.
4. Find the attribute causing replacement.
5. Check whether resource address changed.
6. Check state and real infrastructure.
7. Check provider/module/version changes.
8. Use moved/import/state repair if needed.
9. Re-run plan.
10. Apply only when the plan is understood.
```

Interview version:

> “I would not approve a destroy or replacement until I know exactly why Terraform wants it. The plan is evidence, not a formality.”

---

## Framework 2: The drift answer

Use this when asked:

> “Someone changed infrastructure manually. What now?”

```text
1. Detect drift with plan or refresh-only.
2. Decide whether manual change is desired.
3. If undesired, apply Terraform to revert.
4. If desired, update Terraform code.
5. If resource is missing from state, import it.
6. If state references a deleted resource, repair state.
7. Add controls to prevent repeat manual drift.
```

Interview version:

> “I would not blindly undo the manual change. I would first determine whether it was an emergency fix that should become code.”

---

## Framework 3: The state answer

Use this when asked:

> “How do you manage Terraform state safely?”

```text
1. Use remote backend.
2. Enable locking.
3. Encrypt state.
4. Restrict access.
5. Separate state by environment and blast radius.
6. Do not commit state to Git.
7. Treat state as sensitive.
8. Back up state.
9. Use import, moved blocks, and state commands carefully.
10. Avoid manual edits unless absolutely necessary.
```

Interview version:

> “Terraform state is a source of truth and often contains secrets. I protect it like production data.”

---

## Framework 4: The module answer

Use this when asked:

> “How do you write reusable Terraform modules?”

```text
1. Keep module purpose focused.
2. Use typed variables and validation.
3. Provide clear outputs.
4. Pin provider assumptions.
5. Avoid hidden dependencies.
6. Avoid hardcoded environment values.
7. Document inputs, outputs, and examples.
8. Version modules.
9. Test modules.
10. Use moved blocks for safe refactors.
```

Interview version:

> “A good module has a narrow purpose, clear inputs, stable outputs, and predictable behavior across environments.”

---

# Common Terraform interview traps and better answers

## Trap 1: “Would you just apply the plan?”

Weak answer:

> “Yes, if the plan looks okay.”

Better answer:

> “I would review resource actions carefully, especially destroys and replacements. I would check what changed, why it changed, and whether the blast radius is acceptable.”

---

## Trap 2: “Can we fix this by editing the state file?”

Weak answer:

> “Yes, just edit the state.”

Better answer:

> “Manual state editing is a last resort. I would prefer `terraform import`, `terraform state mv`, `terraform state rm`, or `moved` blocks. Direct state edits are risky.”

---

## Trap 3: “Should we use `ignore_changes`?”

Weak answer:

> “Yes, it removes plan noise.”

Better answer:

> “Only if that field is intentionally managed outside Terraform. Otherwise, `ignore_changes` can hide real drift and security issues.”

---

## Trap 4: “Can we use one state file for everything?”

Weak answer:

> “Yes, it is simpler.”

Better answer:

> “It may be simpler at first, but it increases blast radius, lock contention, and plan size. I would split state by lifecycle, ownership, environment, and risk.”

---

## Trap 5: “Are sensitive variables enough to protect secrets?”

Weak answer:

> “Yes, they hide secrets.”

Better answer:

> “They hide secrets from CLI output, but secrets can still exist in state. State must be encrypted and access-controlled.”

---

# Terraform interview quick-reference table

| Issue | Main symptom | First thing to check | Common fix |
|---|---|---|---|
| Unexpected destroy | Plan shows destroy/recreate | Resource action and changed attribute | Moved block, config fix, state repair |
| Drift | Plan changes without code change | Refresh and real infrastructure | Reconcile code/state/reality |
| State lock | Cannot acquire lock | Active runs and backend lock | Wait or force-unlock safely |
| Backend issue | Different plans per user | Backend config and state path | Reconfigure or migrate backend |
| Provider conflict | Init fails or plan changes | Provider constraints and lock file | Pin/align provider versions |
| Module source issue | Unexpected module behavior | Module source/ref/version | Pin and upgrade deliberately |
| Secrets in state | Sensitive data risk | State backend and outputs | Encrypt, restrict, rotate |
| Import issue | Existing resource duplicated | Config and import address | Import then adjust config |
| Count instability | List change causes replacement | Resource addresses | Use `for_each` with stable keys |
| Dependency issue | Resource created too early | Graph references | Add real references or `depends_on` |
| Circular dependency | `Error: Cycle` | Dependency chain | Split resources/remove loop |
| Ignore misuse | Drift hidden | Lifecycle block | Narrow or remove ignore |
| Auth failure | Access denied | Provider identity | Fix credentials/IAM |
| Env mix-up | Dev/prod confusion | Backend, vars, credentials | Separate envs/accounts/states |
| Type issue | Bad input accepted | Variable types | Add validation and object types |
| Unknown values | Invalid count/for_each | Computed values | Use stable known keys |
| Data source fail | Lookup fails | Filters/account/region | Use precise filters |
| Validation issue | Syntax/schema errors | `fmt`, `validate`, lint | Add CI quality gates |
| Partial apply | Half-created infra | State vs real resources | Import/repair/reapply safely |
| Poor state design | Huge risky plans | State boundaries | Split by lifecycle/blast radius |

---

# Strong closing takeaway

Terraform interviews are not just about knowing HCL. They are about showing that you can safely manage infrastructure as code.

A weak answer sounds like:

> “I would run apply.”

A strong answer sounds like:

> “I would inspect the plan, check the state, understand the provider behavior, confirm the backend and credentials, reduce blast radius, and only apply once the change is clear and safe.”

Terraform is powerful because it is declarative, state-driven, and repeatable. It is dangerous for the same reasons. It will faithfully execute the difference between code, state, and reality — even when that difference is not what you intended.

When you freeze, return to this:

```text
Code → Variables → Providers → State → Backend → Plan → Cloud reality → Safe apply
```

That sequence will carry you through most Terraform interview questions.

---

# Final takeaway summaries

## The one-minute summary

Terraform problems usually come from configuration, state, provider versions, backend setup, drift, credentials, modules, dependencies, or environment separation. The best interview answer starts with the plan and state. Do not guess. Inspect what Terraform thinks exists, what the code says should exist, and what the cloud actually has.

## The senior-engineer summary

A senior Terraform user understands trade-offs. One state file is simple but risky. Many state files reduce blast radius but increase dependency management. `ignore_changes` reduces noise but can hide drift. Provider upgrades bring fixes but can change behavior. Sensitive variables hide output but not state. Seniority is shown by safe state handling, clean module design, cautious applies, and strong review of plans.

## The interview survival summary

When your mind goes blank, say:

> “I would first inspect the plan and identify exactly what Terraform wants to change. Then I would check whether the cause is configuration, variables, provider versions, state, backend, permissions, or real infrastructure drift. I would make the smallest safe correction, rerun plan, and only apply once the result is understood.”

That answer works across most Terraform interview scenarios.
