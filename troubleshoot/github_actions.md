# GitHub Actions: “I Know This Stuff, But in the Interview I Freeze” Kit

> Also called “Git Actions” in conversation, but the product name is **GitHub Actions**.

## Strong intro

You can use GitHub Actions every week and still freeze in an interview.

That freeze usually does not mean you lack CI/CD experience. It means your knowledge is stored as practical habits: checking workflow run logs, fixing YAML indentation, reading job dependencies, adjusting permissions, debugging secrets, validating branch filters, solving cache misses, dealing with flaky tests, and asking, “Did this run on the event I think it ran on?”

In production, GitHub Actions is not just “a YAML file that runs tests.” It is a CI/CD runtime with event triggers, runners, tokens, permissions, environments, secrets, artifacts, caches, matrices, reusable workflows, deployment gates, and security boundaries.

A strong interview answer shows that you can troubleshoot safely, not just copy a workflow from a README.

This kit is built for the interview moment when you know the tool but need the words.

It covers 30 common GitHub Actions issues interviewers ask about, with symptoms, causes, fixes, examples, and interview-ready explanations. It is written for DevOps, platform, SRE, CI/CD, release, and software engineers who want calm, practical answers under pressure.

When you freeze, start with this sentence:

> “I would first identify whether the GitHub Actions issue is trigger logic, YAML syntax, runner availability, job dependencies, permissions, secrets, environment protection, caching, artifacts, matrix behavior, external service access, or flaky tests. Then I would inspect the workflow run, event payload, job logs, resolved expressions, token permissions, and recent workflow changes before changing anything.”

That answer sounds like someone who has operated CI/CD systems for real teams.

---

## How to use this kit

For every GitHub Actions issue, use this structure:

```text
Symptom → Event → Workflow file → Job log → Context/permissions → Cause → Fix → Verify
```

A strong GitHub Actions interview answer usually includes:

1. What failed.
2. Which event triggered or did not trigger the workflow.
3. Which job or step failed.
4. Whether the issue is YAML, runner, dependency, secret, permission, cache, artifact, or external API.
5. What evidence in logs or contexts proves the cause.
6. What minimal fix you apply.
7. How you prevent recurrence.

Example:

> “If a GitHub Actions workflow does not run, I would first check the trigger event, branch and path filters, workflow file location, repository Actions settings, and whether the event comes from a fork or bot. Then I would check the Actions tab and recent workflow changes.”

That is better than saying:

> “I would rerun it.”

Rerunning only helps if the problem is transient. Diagnosis proves ownership.

---

# Top 30 GitHub Actions issues and resolutions

---

## 1. Workflow does not trigger

### Interview freeze point

The interviewer asks:

> “A workflow did not run after a push. What do you check?”

A weak answer is “check the YAML.” A strong answer starts with event and filters.

### Strong interview answer

> “I would check whether the workflow file is in `.github/workflows`, whether the `on` event matches the activity, whether branch or path filters exclude the change, whether Actions are enabled for the repository, and whether the event came from a fork or context with restrictions.”

### Symptoms

- No workflow run appears.
- Push happened but Actions tab shows nothing.
- Pull request did not trigger CI.
- Tag push did not trigger release.
- Workflow works manually but not automatically.

### Common causes

- Workflow file not under `.github/workflows`.
- Wrong event name.
- Branch filter excludes branch.
- Path filter excludes changed files.
- YAML syntax invalid.
- Actions disabled at repository/org level.
- Pull request from fork has restrictions.
- Workflow file added on a branch not monitored.
- Using `pull_request` when `pull_request_target` was expected, or vice versa.
- Tag trigger not configured.

### Example: push only to main

```yaml
name: CI

on:
  push:
    branches:
      - main
```

This will not run on:

```text
feature/my-branch
```

### Fix: include feature branches

```yaml
on:
  push:
    branches:
      - main
      - "feature/**"
```

### Example: path filter excludes change

```yaml
on:
  push:
    paths:
      - "src/**"
```

A change only to `README.md` will not trigger.

### Debug checklist

```text
Is the file under .github/workflows?
Is the workflow on the branch?
Does the event match?
Do branches/tags filters match?
Do paths filters match?
Are Actions enabled?
Is the event from a fork?
```

### Takeaway summary

When a workflow does not trigger, start with the event, branch filters, path filters, workflow location, and repository settings.

---

## 2. YAML syntax error

### Interview freeze point

The workflow does not even parse.

### Strong interview answer

> “I would validate the workflow YAML structure. GitHub Actions YAML is indentation-sensitive, and small mistakes in `on`, `jobs`, `steps`, or expressions can prevent the workflow from loading.”

### Symptoms

- Workflow file shows syntax error.
- Actions tab says workflow is invalid.
- Job never starts.
- Error mentions mapping, indentation, or unexpected value.
- A key such as `steps` or `runs-on` is not recognized.

### Bad example

```yaml
name: CI

on: push

jobs:
build:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
```

`build` is not indented under `jobs`.

### Correct

```yaml
name: CI

on: push

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
```

### Common causes

- Wrong indentation.
- Tabs instead of spaces.
- Missing colon.
- Wrong nesting under `jobs`.
- `steps` not under job.
- `run` and `uses` mixed incorrectly.
- Expression syntax broken.
- YAML interprets a value unexpectedly.

### Safer pattern

Keep workflows small and validate changes in pull requests.

### Takeaway summary

GitHub Actions workflow files are YAML. Indentation and nesting are part of the program.

---

## 3. Job stuck waiting for runner

### Interview freeze point

The workflow starts, but the job does not run.

### Strong interview answer

> “I would check the `runs-on` label, runner availability, repository/org runner settings, self-hosted runner health, and whether the job requests labels that no runner has.”

### Symptoms

- Job says “Waiting for a runner to pick up this job.”
- GitHub-hosted runner starts slowly.
- Self-hosted runner never picks job.
- Job queued forever.
- Label mismatch.

### Example

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, docker]
```

This requires a self-hosted runner with all three labels:

```text
self-hosted
linux
docker
```

### Common causes

- Self-hosted runner offline.
- Label mismatch.
- Runner assigned to another repo/org.
- Runner busy.
- Runner group restrictions.
- GitHub-hosted runner capacity delay.
- Workflow requests unavailable OS.
- Self-hosted runner service stopped.
- Firewall/proxy blocks runner connection.

### Diagnostic checklist

```text
Repository → Settings → Actions → Runners
Runner online?
Labels match?
Runner group allows repo?
Runner logs clean?
Any organization policy blocking it?
```

### Self-hosted runner checks

```bash
sudo systemctl status actions.runner.*
journalctl -u actions.runner.* -n 100
```

### Fix

- Correct `runs-on` labels.
- Start or re-register self-hosted runner.
- Add required labels.
- Add runner capacity.
- Use GitHub-hosted runner if suitable.

### Takeaway summary

Queued jobs are often runner label, availability, or permission problems.

---

## 4. Step fails because command not found

### Interview freeze point

A command works locally but not in Actions.

### Strong interview answer

> “I would check the runner OS, installed tools, PATH, setup actions, shell, and whether the command exists in the GitHub-hosted runner image or needs installation.”

### Symptoms

- `command not found`
- `python: not found`
- `node: not found`
- `mvn: command not found`
- Works locally but fails in CI.
- Works on ubuntu but not windows.

### Bad assumption

```yaml
steps:
  - run: terraform version
```

If Terraform is not installed, this fails.

### Fix: install/setup tool

```yaml
steps:
  - uses: actions/checkout@v4

  - uses: hashicorp/setup-terraform@v3
    with:
      terraform_version: 1.8.5

  - run: terraform version
```

### Node example

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: "20"

- run: npm ci
```

### Python example

```yaml
- uses: actions/setup-python@v5
  with:
    python-version: "3.12"

- run: python -m pip install -r requirements.txt
```

### Common causes

- Tool not installed.
- Wrong shell.
- Wrong OS.
- PATH not updated.
- Installed in previous job, not current job.
- Self-hosted runner differs from GitHub-hosted runner.
- Version mismatch.

### Takeaway summary

Each job runs in its own runner environment. Install or set up tools explicitly.

---

## 5. Job dependency order wrong

### Interview freeze point

Deploy runs even though test should run first, or a job cannot access previous output.

### Strong interview answer

> “I would check job dependencies with `needs`. Jobs run in parallel by default unless dependencies are declared.”

### Bad example

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: npm test

  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh
```

`test` and `deploy` can run in parallel.

### Correct

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: npm test

  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh
```

### Multiple dependencies

```yaml
deploy:
  needs:
    - unit-tests
    - integration-tests
```

### Common causes

- Missing `needs`.
- Assuming job order follows file order.
- Skipped dependency causes downstream job to skip.
- Outputs not declared at job level.
- Using step output from another job incorrectly.

### Conditional deploy after success

```yaml
deploy:
  needs: test
  if: success()
```

### Takeaway summary

Jobs run in parallel by default. Use `needs` to define pipeline order.

---

## 6. Secret is empty or unavailable

### Interview freeze point

The workflow runs, but the secret value is blank.

### Strong interview answer

> “I would check whether the secret exists at repository, environment, or organization level, whether the workflow references the correct name, whether the job uses the environment that contains the secret, and whether the event has access to secrets.”

### Symptoms

- Auth fails.
- Secret appears empty.
- Works on push but not pull request from fork.
- Environment secret unavailable.
- Typo in secret name.
- Secret is masked in logs.

### Example

```yaml
steps:
  - run: echo "$API_TOKEN"
    env:
      API_TOKEN: ${{ secrets.API_TOKEN }}
```

Do not actually echo secrets in real workflows.

### Common causes

- Secret name typo.
- Secret defined in environment but job does not specify `environment`.
- Organization secret not shared with repo.
- Pull request from fork cannot access repository secrets in normal contexts.
- Secret not created in target repository.
- Reusable workflow secret not passed.
- Using `vars` when secret is needed.

### Environment secret example

```yaml
jobs:
  deploy:
    environment: production
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh
        env:
          API_TOKEN: ${{ secrets.API_TOKEN }}
```

### Reusable workflow secret pass

```yaml
jobs:
  call:
    uses: org/repo/.github/workflows/deploy.yml@main
    secrets:
      api_token: ${{ secrets.API_TOKEN }}
```

### Takeaway summary

Secret availability depends on name, scope, environment, event type, and whether it is passed to called workflows.

---

## 7. Secret leaked in logs

### Interview freeze point

This tests security maturity.

### Strong interview answer

> “If a secret appears in logs, I would treat it as compromised, rotate it, remove exposure, and fix the workflow pattern. Masking helps, but I would not rely on it as the only protection.”

### Symptoms

- Token visible in logs.
- Debug mode prints env.
- Script echoes command arguments.
- Secret appears in artifact.
- Secret included in generated config.
- Third-party action logs too much.

### Risky example

```yaml
- run: echo "Token is $API_TOKEN"
  env:
    API_TOKEN: ${{ secrets.API_TOKEN }}
```

### Better

Pass secret only to the command that needs it:

```yaml
- run: ./deploy.sh
  env:
    API_TOKEN: ${{ secrets.API_TOKEN }}
```

### Avoid shell tracing around secrets

```bash
set +x
```

### Common causes

- Echoing environment.
- `set -x`.
- Debug logs.
- Secret in command-line argument.
- Secret written to artifact.
- Third-party action prints input.
- Secret transformed so masking does not detect it.

### Resolution

```text
Rotate leaked secret.
Remove secret from logs/artifacts if possible.
Reduce secret scope.
Use environment protection.
Review third-party actions.
Avoid printing env.
```

### Takeaway summary

If a secret is exposed, rotate it. Then fix the workflow so the secret is not printed or stored.

---

## 8. `GITHUB_TOKEN` permission denied

### Interview freeze point

The workflow tries to comment, push, create release, upload package, or access APIs and gets denied.

### Strong interview answer

> “I would check the `GITHUB_TOKEN` permissions at workflow or job level, repository settings, organization policy, event type, and whether the action needs a personal access token or GitHub App token instead.”

### Symptoms

- `Resource not accessible by integration`
- 403 from GitHub API.
- Cannot push tag.
- Cannot create release.
- Cannot comment on PR.
- Cannot upload package.
- Works locally with PAT but not Actions.

### Minimal permissions example

```yaml
permissions:
  contents: read
```

If a job needs to push:

```yaml
permissions:
  contents: write
```

Pull request comments:

```yaml
permissions:
  pull-requests: write
```

OIDC cloud auth:

```yaml
permissions:
  id-token: write
  contents: read
```

### Job-level permissions

```yaml
jobs:
  release:
    permissions:
      contents: write
    runs-on: ubuntu-latest
    steps:
      - run: gh release create v1.0.0
        env:
          GH_TOKEN: ${{ github.token }}
```

### Common causes

- Default token permissions are read-only.
- Workflow sets restrictive permissions globally.
- Job-level permissions override expectations.
- Fork pull request security restrictions.
- Organization policy restricts token.
- Action requires broader scope.
- Need GitHub App token or PAT for cross-repo access.

### Takeaway summary

Use least privilege, but grant the exact `GITHUB_TOKEN` permissions the job needs.

---

## 9. Checkout has wrong branch or missing history

### Interview freeze point

The job checks out code, but not the ref or history expected.

### Strong interview answer

> “I would check the event ref, checkout configuration, fetch depth, tags, submodules, and whether the workflow is running on a pull request merge ref or the branch head.”

### Common checkout

```yaml
- uses: actions/checkout@v4
```

By default, checkout may use limited history.

### Need full history

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0
```

### Need tags

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0
    fetch-tags: true
```

### Pull request head ref

```yaml
- uses: actions/checkout@v4
  with:
    ref: ${{ github.head_ref }}
```

### Symptoms

- Version calculation wrong.
- Git tags missing.
- Changelog generator fails.
- Diff command fails.
- Submodules missing.
- Deploy uses merge commit instead of branch commit.

### Common causes

- Shallow clone.
- PR merge ref confusion.
- Tag not fetched.
- Submodule not enabled.
- LFS not enabled.
- Wrong repository checked out.
- Matrix job uses same checkout assumption.

### Takeaway summary

`actions/checkout` is configurable. Check ref, fetch depth, tags, submodules, and PR behavior.

---

## 10. Cache miss or stale cache

### Interview freeze point

The workflow is slow or uses stale dependencies.

### Strong interview answer

> “I would check the cache key, restore keys, dependency lock file, OS, language version, and whether the cache path is correct. A good cache key changes when dependencies change.”

### Node cache example

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: "20"
    cache: "npm"

- run: npm ci
```

Manual cache example

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: npm-${{ runner.os }}-${{ hashFiles('package-lock.json') }}
    restore-keys: |
      npm-${{ runner.os }}-
```

### Common causes

- Cache path wrong.
- Key too broad, causing stale cache.
- Key too narrow, causing constant misses.
- Lock file missing.
- OS or language version not included.
- Cache not saved because job failed before save.
- Dependency manager already has built-in setup action cache.

### Bad key

```yaml
key: npm-cache
```

This may become stale.

### Better key

```yaml
key: npm-${{ runner.os }}-${{ hashFiles('package-lock.json') }}
```

### Takeaway summary

Cache keys should reflect dependency inputs. Wrong keys cause slow builds or stale dependencies.

---

## 11. Artifact missing between jobs

### Interview freeze point

A build job creates a file, but the deploy job cannot find it.

### Strong interview answer

> “Each job runs on a fresh runner. Files do not automatically persist between jobs. I would upload artifacts in one job and download them in the dependent job.”

### Bad assumption

```yaml
jobs:
  build:
    steps:
      - run: npm run build

  deploy:
    needs: build
    steps:
      - run: ls dist
```

`dist` is not present in the deploy job.

### Correct

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run build
      - uses: actions/upload-artifact@v4
        with:
          name: app-dist
          path: dist/

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: app-dist
          path: dist/
      - run: ls dist
```

### Common causes

- Expecting workspace to persist across jobs.
- Artifact path wrong.
- Artifact name mismatch.
- Build output generated in another directory.
- Upload step skipped.
- Retention expired.
- Hidden files not included as expected.

### Takeaway summary

Use artifacts to move files between jobs. Jobs do not share local filesystem state.

---

## 12. Matrix build behaves unexpectedly

### Interview freeze point

Matrix expands into jobs you did not expect, or one failure cancels too much.

### Strong interview answer

> “I would inspect the matrix expansion, include/exclude rules, fail-fast behavior, and whether outputs from matrix jobs are being used correctly.”

### Example matrix

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest]
    python-version: ["3.11", "3.12"]
```

This creates 4 jobs.

### Exclude combination

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest]
    python-version: ["3.11", "3.12"]
    exclude:
      - os: windows-latest
        python-version: "3.11"
```

### Disable fail-fast

```yaml
strategy:
  fail-fast: false
  matrix:
    python-version: ["3.11", "3.12"]
```

### Common causes

- Matrix creates Cartesian product.
- Include/exclude misunderstood.
- Fail-fast cancels other jobs.
- One OS lacks tool.
- Step assumes Linux shell on Windows.
- Artifact names collide across matrix jobs.
- Cache key missing matrix values.

### Artifact naming in matrix

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: test-results-${{ matrix.os }}-${{ matrix.python-version }}
    path: results/
```

### Takeaway summary

Matrix jobs multiply combinations. Include matrix values in cache keys, artifact names, and OS-specific logic.

---

## 13. `if` condition does not work as expected

### Interview freeze point

A step runs when it should not, or skips when it should run.

### Strong interview answer

> “I would check expression syntax, context availability, event type, string comparison, job status functions, and whether the `if` is on a step or job.”

### Example

```yaml
if: github.ref == 'refs/heads/main'
```

Deploy only on main:

```yaml
jobs:
  deploy:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
```

### Step condition

```yaml
- name: Publish
  if: success() && github.ref == 'refs/heads/main'
  run: ./publish.sh
```

### Common causes

- Wrong ref format.
- Using branch name where full ref is expected.
- Context unavailable at that level.
- Comparing boolean as string.
- `if` on step but job still starts.
- Previous step failure prevents later step unless `always()` used.
- Pull request refs differ from push refs.

### Debug context safely

```yaml
- name: Show ref
  run: |
    echo "ref=${{ github.ref }}"
    echo "event=${{ github.event_name }}"
```

Avoid dumping entire context if it may contain sensitive data.

### Takeaway summary

Conditions depend on event context and scope. Print safe context values to confirm assumptions.

---

## 14. Environment protection blocks deployment

### Interview freeze point

The deploy job waits for approval or cannot access environment secrets.

### Strong interview answer

> “I would check the job’s `environment`, required reviewers, wait timers, branch restrictions, and whether secrets are environment-scoped.”

### Example

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - run: ./deploy.sh
```

### Symptoms

- Job waits for approval.
- Job says waiting on environment.
- Secret unavailable.
- Deployment blocked by branch policy.
- Reviewer cannot approve.

### Common causes

- Environment requires approval.
- Branch not allowed to deploy to environment.
- Required reviewers missing.
- Environment secret exists but job does not declare environment.
- User lacks permission.
- Deployment protection rule blocks job.

### Resolution

- Set correct `environment`.
- Approve deployment.
- Adjust environment rules carefully.
- Put deployment secrets in the right environment.
- Use separate environments for staging/prod.
- Document approval flow.

### Takeaway summary

GitHub Environments are deployment control points. They can gate jobs and scope secrets.

---

## 15. Reusable workflow input or secret missing

### Interview freeze point

A reusable workflow works directly but fails when called.

### Strong interview answer

> “I would check the called workflow’s `workflow_call` inputs and secrets, then verify the caller passes matching names and types. Secrets are not automatically passed unless configured.”

### Called workflow

```yaml
name: Deploy

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
    secrets:
      deploy_token:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh ${{ inputs.environment }}
        env:
          DEPLOY_TOKEN: ${{ secrets.deploy_token }}
```

### Caller workflow

```yaml
jobs:
  deploy:
    uses: org/repo/.github/workflows/deploy.yml@main
    with:
      environment: production
    secrets:
      deploy_token: ${{ secrets.DEPLOY_TOKEN }}
```

### Common causes

- Input name mismatch.
- Secret name mismatch.
- Required input missing.
- Wrong input type.
- Caller references wrong workflow path/ref.
- Environment secrets expected but not passed.
- Nested reusable workflow does not pass secret again.

### Takeaway summary

Reusable workflows have an explicit contract. Inputs and secrets must be declared and passed correctly.

---

## 16. Workflow permissions too broad

### Interview freeze point

The workflow works, but security posture is weak.

### Strong interview answer

> “I would apply least privilege permissions. The default token should have only what the workflow needs, and high-risk jobs like deployment or package publishing should be separated and protected.”

### Risky

```yaml
permissions: write-all
```

### Better

```yaml
permissions:
  contents: read
```

Deploy job:

```yaml
jobs:
  deploy:
    permissions:
      contents: read
      id-token: write
```

Release job:

```yaml
jobs:
  release:
    permissions:
      contents: write
```

### Common risks

- `write-all` globally.
- Secrets available to too many jobs.
- Third-party actions with write token.
- Pull request workflows with write access.
- Deployment and test jobs share same permissions.
- No environment protection.

### Safer design

```text
Build/test job: read-only
Deploy job: minimal deploy permissions
Release job: contents write only
Cloud auth: OIDC id-token write
```

### Takeaway summary

Permissions should be job-scoped and minimal. Do not give every job deployment power.

---

## 17. Pull request from fork cannot access secrets

### Interview freeze point

CI passes on internal branches but fails on fork PRs.

### Strong interview answer

> “I would remember that secrets are restricted for forked pull requests for security. I would design fork PR workflows to run untrusted tests without secrets, and keep secret-using jobs behind trusted events or approvals.”

### Symptoms

- Secret empty on fork PR.
- Deploy step fails on contributor PR.
- Integration tests needing secrets fail.
- Maintainer PR works but external fork fails.

### Common causes

- Fork PR security restrictions.
- Using `pull_request` event with secrets.
- Running untrusted code with sensitive token would be unsafe.
- Integration tests require external credentials.

### Safer workflow split

```yaml
on:
  pull_request:

jobs:
  test:
    permissions:
      contents: read
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm test
```

Secret-dependent deploy only on push to main:

```yaml
on:
  push:
    branches: [main]
```

### Warning about `pull_request_target`

`pull_request_target` has access to base repository context and can be dangerous if it checks out and runs untrusted PR code. Use it carefully.

### Takeaway summary

Do not expose secrets to untrusted fork code. Split safe PR checks from trusted deploy workflows.

---

## 18. Third-party action security risk

### Interview freeze point

The workflow uses actions from the Marketplace. How do you trust them?

### Strong interview answer

> “I would pin third-party actions, prefer trusted maintainers, review permissions and inputs, and avoid giving untrusted actions broad token or secret access.”

### Risky

```yaml
- uses: some-user/some-action@main
```

`main` can change.

### Better

Pin to version tag:

```yaml
- uses: actions/checkout@v4
```

More strict: pin to commit SHA.

```yaml
- uses: some-user/some-action@a1b2c3d4e5f6...
```

### Common risks

- Action compromised.
- Mutable tag changes behavior.
- Action logs secrets.
- Action runs with write token.
- Action has access to workspace and secrets.
- Supply chain attack.

### Safer practices

```text
Use official/trusted actions where possible.
Pin versions or SHAs.
Limit token permissions.
Do not pass secrets unless needed.
Review action source.
Use organization allowlists.
```

### Takeaway summary

Actions are code execution. Treat third-party actions like dependencies with CI/CD privileges.

---

## 19. Deployment runs from wrong branch or tag

### Interview freeze point

A production deploy happens from an unintended ref.

### Strong interview answer

> “I would check event triggers, branch filters, tag filters, environment branch protection, and job-level `if` conditions. Production deployment should be tightly scoped.”

### Risky

```yaml
on: push

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy-prod.sh
```

This runs on every push.

### Better

```yaml
on:
  push:
    branches:
      - main

jobs:
  deploy:
    environment: production
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy-prod.sh
```

### Tag release

```yaml
on:
  push:
    tags:
      - "v*.*.*"
```

### Common causes

- Broad `on: push`.
- Missing branch filter.
- Manual dispatch used with wrong ref.
- Tag pattern too broad.
- Environment allows all branches.
- Reusable workflow called from unsafe caller.

### Takeaway summary

Deployment triggers should be narrow, explicit, and protected by environments.

---

## 20. Manual `workflow_dispatch` uses wrong inputs

### Interview freeze point

A manually triggered workflow deploys the wrong environment or version.

### Strong interview answer

> “I would define explicit typed inputs, validate them, restrict environments, and log the selected inputs safely at the start of the workflow.”

### Example

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: "Target environment"
        required: true
        type: choice
        options:
          - staging
          - production
      version:
        description: "Version to deploy"
        required: true
        type: string
```

Use input:

```yaml
jobs:
  deploy:
    environment: ${{ inputs.environment }}
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh "${{ inputs.version }}"
```

### Common causes

- Free-text environment names.
- No input validation.
- Running workflow from wrong branch.
- Version input typo.
- Production not protected.
- No audit output.

### Safer pattern

```yaml
environment: ${{ inputs.environment }}
```

This can connect manual deploy to environment approvals.

### Takeaway summary

Manual workflows need guardrails. Use typed inputs, choices, environment protection, and clear validation.

---

## 21. Concurrency problem causes overlapping deploys

### Interview freeze point

Two deploys run at the same time and break each other.

### Strong interview answer

> “I would use concurrency groups to prevent overlapping runs for the same branch, environment, or deployment target.”

### Example

```yaml
concurrency:
  group: deploy-production
  cancel-in-progress: false
```

Per branch:

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
```

Per environment:

```yaml
concurrency:
  group: deploy-${{ inputs.environment }}
  cancel-in-progress: false
```

### Symptoms

- Two deploys overlap.
- Old build deploys after new build.
- Race condition in environment.
- Infrastructure lock conflict.
- Database migration runs twice.

### Common causes

- No concurrency group.
- Group too broad, blocks unrelated jobs.
- Group too narrow, allows same target deploy.
- `cancel-in-progress` wrong.
- Manual dispatch overlaps push deploy.

### Rule of thumb

```text
CI on same branch: cancel older runs.
Production deploy: usually do not overlap; do not auto-cancel unless safe.
```

### Takeaway summary

Use concurrency to control race conditions, especially deployments and long-running workflows.

---

## 22. Artifact or cache name collision in matrix jobs

### Interview freeze point

Matrix jobs overwrite or mix outputs.

### Strong interview answer

> “I would include matrix values in artifact names and cache keys so each job has separate outputs where needed.”

### Bad

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: test-results
    path: results/
```

Every matrix job uses the same artifact name.

### Better

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: test-results-${{ matrix.os }}-${{ matrix.node-version }}
    path: results/
```

Cache key:

```yaml
key: npm-${{ runner.os }}-${{ matrix.node-version }}-${{ hashFiles('package-lock.json') }}
```

### Common causes

- Same artifact name across matrix.
- Same cache key across OS/language versions.
- Same build output path uploaded.
- Download step expects one artifact but many exist.
- Deploy job grabs wrong artifact.

### Takeaway summary

Matrix jobs need unique artifact names and cache keys when outputs differ.

---

## 23. Test is flaky only in Actions

### Interview freeze point

The code passes locally but fails randomly in CI.

### Strong interview answer

> “I would collect failure patterns, compare runner OS and versions, check timing, parallelism, external dependencies, timezone, locale, network calls, and resource limits. I would avoid normalizing reruns as the fix.”

### Symptoms

- Random failures.
- Passes on rerun.
- Fails only on CI.
- Timeouts.
- Tests depend on order.
- External API calls fail.

### Common causes

- Race condition.
- Timing-based test.
- Test order dependency.
- Missing service readiness.
- Different timezone/locale.
- Parallel tests share state.
- Network dependency.
- Resource limits.
- Random data not seeded.

### Debug additions

```yaml
- run: date
- run: env | sort
- run: node --version
- run: python --version
```

### Service readiness example

```yaml
services:
  postgres:
    image: postgres:16
    env:
      POSTGRES_PASSWORD: postgres
    ports:
      - 5432:5432
    options: >-
      --health-cmd pg_isready
      --health-interval 10s
      --health-timeout 5s
      --health-retries 5
```

### Takeaway summary

A flaky CI test is a reliability bug. Find the pattern and fix the cause, not just rerun.

---

## 24. Service container not ready

### Interview freeze point

A job starts tests before PostgreSQL, Redis, or another service is ready.

### Strong interview answer

> “I would check the service container health check, ports, network name, credentials, and whether the test waits for readiness.”

### Example service

```yaml
services:
  postgres:
    image: postgres:16
    env:
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: app
    ports:
      - 5432:5432
    options: >-
      --health-cmd "pg_isready -U postgres"
      --health-interval 10s
      --health-timeout 5s
      --health-retries 5
```

### Test env

```yaml
env:
  DATABASE_URL: postgres://postgres:postgres@localhost:5432/app
```

### Common causes

- Service not ready.
- Wrong port.
- Wrong hostname.
- Health check missing.
- Credentials mismatch.
- Tests start immediately.
- Container image changed.
- Network difference between job container and runner host.

### If job runs in a container

Hostname may be service name:

```text
postgres
```

not `localhost`.

### Takeaway summary

Starting a service container is not the same as readiness. Use health checks and correct hostnames.

---

## 25. Docker build fails in Actions

### Interview freeze point

Docker builds locally but fails in GitHub Actions.

### Strong interview answer

> “I would check build context, Dockerfile path, `.dockerignore`, secrets, platform architecture, registry login, and whether Buildx is needed for multi-platform builds.”

### Basic build

```yaml
- uses: actions/checkout@v4

- run: docker build -t myapp:${{ github.sha }} .
```

### Buildx example

```yaml
- uses: docker/setup-buildx-action@v3

- uses: docker/build-push-action@v6
  with:
    context: .
    push: false
    tags: myapp:${{ github.sha }}
```

### Common causes

- Wrong build context.
- File excluded by `.dockerignore`.
- Secret missing.
- Dockerfile path wrong.
- Multi-arch build not configured.
- Registry login missing.
- Docker layer cache not set.
- Build uses local-only files.

### Registry login

```yaml
- uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

### Takeaway summary

Docker build failures in Actions are usually context, file path, registry auth, secrets, or platform issues.

---

## 26. Package publish fails

### Interview freeze point

Build passes, but publishing to npm, PyPI, GitHub Packages, or container registry fails.

### Strong interview answer

> “I would check package registry credentials, token permissions, package name/version, whether the version already exists, repository package permissions, and whether the workflow runs only on trusted refs.”

### Symptoms

- 403 or 401 from registry.
- Version already exists.
- Package upload denied.
- Works locally with personal token.
- GitHub Packages permission denied.
- npm provenance or auth issue.

### npm example

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: "20"
    registry-url: "https://registry.npmjs.org"

- run: npm publish
  env:
    NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### Python PyPI example

```yaml
- name: Publish package
  uses: pypa/gh-action-pypi-publish@release/v1
```

### Common causes

- Token missing or wrong scope.
- Version already published.
- Package name unavailable.
- Publishing from PR/fork.
- Registry URL wrong.
- `GITHUB_TOKEN` lacks package permission.
- Tag trigger wrong.

### Takeaway summary

Publishing needs correct token, registry, package version, and trusted release trigger.

---

## 27. OIDC cloud authentication fails

### Interview freeze point

The workflow should authenticate to AWS/Azure/GCP without long-lived secrets, but it fails.

### Strong interview answer

> “I would check that `id-token: write` is granted, the cloud trust policy matches repository, branch, environment, and audience claims, and the workflow is running from the expected ref.”

### Required permission

```yaml
permissions:
  id-token: write
  contents: read
```

### AWS example

```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::123456789012:role/github-actions-deploy
    aws-region: eu-west-1
```

### Common causes

- Missing `id-token: write`.
- Cloud trust policy too strict or wrong.
- Branch/ref mismatch.
- Environment claim mismatch.
- Wrong audience.
- Wrong repository or org in trust policy.
- Action version mismatch.
- Clock/time issue rarely.

### Debug safely

Print non-sensitive context:

```yaml
- run: |
    echo "repo=${{ github.repository }}"
    echo "ref=${{ github.ref }}"
    echo "workflow=${{ github.workflow }}"
```

### Takeaway summary

OIDC failures are usually permissions or cloud trust policy claim mismatches.

---

## 28. Workflow runs but uses wrong environment variables

### Interview freeze point

A value exists, but the job sees the wrong one.

### Strong interview answer

> “I would check the difference between `env`, `vars`, `secrets`, shell variables, step outputs, and GitHub contexts. I would also check precedence between workflow, job, and step-level environment variables.”

### Example levels

```yaml
env:
  APP_ENV: global

jobs:
  build:
    env:
      APP_ENV: job
    runs-on: ubuntu-latest
    steps:
      - run: echo "$APP_ENV"
        env:
          APP_ENV: step
```

The step prints:

```text
step
```

### Use vars

```yaml
env:
  REGION: ${{ vars.AWS_REGION }}
```

Use secrets

```yaml
env:
  API_TOKEN: ${{ secrets.API_TOKEN }}
```

### Common causes

- Step env overrides job env.
- Job env overrides workflow env.
- Secret name differs from variable name.
- Shell variable not exported.
- Writing to `$GITHUB_ENV` affects later steps only.
- Expecting env from one job in another job.
- Matrix value overrides expectation.

### Set env for later steps

```yaml
- run: echo "VERSION=1.2.3" >> "$GITHUB_ENV"

- run: echo "$VERSION"
```

### Takeaway summary

Know the difference between `env`, `vars`, `secrets`, contexts, and step outputs. Scope matters.

---

## 29. Step output not available in another job

### Interview freeze point

A job computes a version, but the deploy job cannot read it.

### Strong interview answer

> “Step outputs are local to a job unless promoted to job outputs. To pass values between jobs, define job outputs and access them through `needs`.”

### Step output

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.version }}
    steps:
      - id: version
        run: echo "version=1.2.3" >> "$GITHUB_OUTPUT"
```

Use in another job:

```yaml
  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying ${{ needs.build.outputs.version }}"
```

### Common causes

- Missing step `id`.
- Writing to old output syntax.
- Not mapping step output to job output.
- Missing `needs`.
- Output name typo.
- Multiline output formatting issue.
- Trying to pass secrets via outputs.

### Takeaway summary

Step outputs stay in the job. Use job outputs plus `needs` to pass values between jobs.

---

## 30. Poor workflow design becomes hard to maintain

### Interview freeze point

This tests senior-level CI/CD thinking.

### Strong interview answer

> “I would design GitHub Actions workflows to be small, secure, reusable, observable, and environment-aware. Poor workflows become fragile when they mix CI, release, deploy, secrets, and many conditions in one large file.”

### Symptoms

- One huge workflow file.
- Copy-pasted jobs across repos.
- Secrets available everywhere.
- Hard to tell what deploys.
- Flaky or slow builds.
- No permissions block.
- No concurrency control.
- No reusable workflow strategy.
- No artifact boundaries.
- No environment protection.

### Better design principles

```text
Separate CI and deployment when useful.
Use reusable workflows for common patterns.
Use composite actions for repeated step logic.
Set minimal permissions.
Use environments for deployment gates.
Use concurrency for deploy safety.
Pin third-party actions.
Cache dependencies carefully.
Name jobs and steps clearly.
Keep secrets scoped.
```

### Example structure

```text
.github/workflows/
  ci.yml
  release.yml
  deploy.yml
  reusable-test.yml
```

### Reusable workflow call

```yaml
jobs:
  test:
    uses: org/platform/.github/workflows/node-test.yml@v1
    with:
      node-version: "20"
```

### Takeaway summary

Good Actions design is not just green builds. It is secure, repeatable, understandable CI/CD.

---

# Bonus: GitHub Actions interview answer frameworks

## Framework 1: The workflow did not run answer

Use this when asked:

> “A GitHub Actions workflow did not trigger. What do you check?”

```text
1. Workflow file location.
2. YAML validity.
3. Event type.
4. Branch filters.
5. Path filters.
6. Tag filters.
7. Repository/org Actions settings.
8. Fork/security restrictions.
9. Workflow file exists on the relevant branch.
10. Actions tab and audit history.
```

Interview version:

> “I start with the event and filters before debugging jobs that never started.”

---

## Framework 2: The failed job answer

Use this when asked:

> “A GitHub Actions job failed. How do you troubleshoot?”

```text
1. Open the failed run.
2. Identify failed job and step.
3. Read the exact command and exit code.
4. Check runner OS and tool versions.
5. Check secrets and env vars.
6. Check permissions.
7. Check external services.
8. Reproduce locally or in a debug branch.
9. Apply smallest fix.
10. Add guardrails or tests.
```

Interview version:

> “I debug the failed step first, then decide whether it is code, environment, permissions, or external dependency.”

---

## Framework 3: The secrets and permissions answer

Use this when asked:

> “A workflow cannot access a secret or gets permission denied.”

```text
1. Check secret name.
2. Check secret scope.
3. Check environment declaration.
4. Check event type and fork restrictions.
5. Check reusable workflow secret passing.
6. Check GITHUB_TOKEN permissions.
7. Check org policies.
8. Avoid printing secrets.
9. Rotate if exposed.
10. Use least privilege.
```

Interview version:

> “Secrets and permissions are scoped. I check where the secret lives and what the event/job is allowed to access.”

---

## Framework 4: The deployment safety answer

Use this when asked:

> “How do you make GitHub Actions deployments safe?”

```text
1. Narrow branch/tag triggers.
2. Use protected environments.
3. Require approvals for production.
4. Use concurrency groups.
5. Use minimal permissions.
6. Use OIDC instead of long-lived cloud keys where possible.
7. Build once and deploy immutable artifact.
8. Keep logs and artifacts.
9. Roll back with known version.
10. Monitor after deploy.
```

Interview version:

> “A safe deploy workflow controls who can deploy, what ref can deploy, what credentials are available, and whether deploys can overlap.”

---

## Framework 5: The workflow design answer

Use this when asked:

> “What makes a good GitHub Actions workflow?”

```text
1. Clear triggers.
2. Small jobs with clear names.
3. Explicit dependencies.
4. Minimal token permissions.
5. Scoped secrets.
6. Good cache keys.
7. Artifacts between jobs.
8. Reusable workflows where helpful.
9. Environment protection.
10. Logs that explain failure.
```

Interview version:

> “A good workflow is secure, predictable, easy to debug, and does not surprise the release process.”

---

# Common GitHub Actions interview traps and better answers

## Trap 1: “The workflow file exists, so it should run?”

Weak answer:

> “Yes.”

Better answer:

> “Not necessarily. It must be in `.github/workflows`, have valid YAML, and match the event, branch, path, or tag filters.”

---

## Trap 2: “Jobs run in the order written?”

Weak answer:

> “Yes.”

Better answer:

> “No. Jobs run in parallel unless connected with `needs`.”

---

## Trap 3: “Secrets are always available?”

Weak answer:

> “Yes.”

Better answer:

> “No. Secret access depends on scope, environment, event type, fork restrictions, and reusable workflow passing.”

---

## Trap 4: “`GITHUB_TOKEN` can do everything?”

Weak answer:

> “Yes.”

Better answer:

> “No. It has scoped permissions. I set the minimum permissions needed at workflow or job level.”

---

## Trap 5: “Cache and artifact are the same?”

Weak answer:

> “Yes.”

Better answer:

> “No. Cache speeds up repeated dependency downloads. Artifacts move build outputs or logs between jobs and preserve them after a run.”

---

## Trap 6: “Third-party actions are safe because they are in Marketplace?”

Weak answer:

> “Yes.”

Better answer:

> “No. Actions are code execution. I prefer trusted actions, pinned versions, minimal permissions, and limited secret exposure.”

---

## Trap 7: “Fork PRs should get all secrets so tests pass?”

Weak answer:

> “Yes.”

Better answer:

> “No. Fork PRs are untrusted code. I would run safe tests without secrets and keep secret-dependent jobs on trusted events.”

---

# GitHub Actions quick-reference table

| Issue | Main symptom | First thing to check | Common fix |
|---|---|---|---|
| Workflow not triggered | No run appears | Event/filters/path | Fix `on` config |
| YAML invalid | Workflow not parsed | Indentation/nesting | Fix YAML |
| Runner waiting | Job queued | `runs-on` labels | Fix runner/labels |
| Command missing | Step fails | Tool availability | Setup/install tool |
| Job order wrong | Deploy too early | `needs` | Add dependencies |
| Secret empty | Auth fails | Secret scope/name | Fix secret/env |
| Secret leak | Token in logs | Logs/artifacts | Rotate and stop printing |
| Token denied | 403 | Permissions block | Grant minimal permission |
| Checkout wrong | Wrong ref/history | checkout config | Set ref/fetch-depth |
| Cache miss/stale | Slow/wrong deps | Cache key/path | Improve key |
| Artifact missing | File not found | Upload/download | Use artifacts |
| Matrix surprise | Too many/wrong jobs | Matrix expansion | Include/exclude/fail-fast |
| Bad condition | Step skipped/runs | Context/ref | Fix `if` |
| Environment blocked | Waiting approval | Environment rules | Approve/fix env |
| Reusable input missing | Called workflow fails | `workflow_call` | Pass inputs/secrets |
| Permissions broad | Security risk | `permissions` | Least privilege |
| Fork secret issue | Secret unavailable | Event source | Split trusted/untrusted |
| Third-party risk | Supply chain risk | Action source/ref | Pin/restrict |
| Wrong deploy ref | Bad deployment | Branch/tag filters | Narrow triggers |
| Manual input wrong | Bad env/version | Inputs | Use typed choices |
| Overlap deploys | Race condition | Concurrency | Add group |
| Matrix artifact conflict | Mixed outputs | Artifact name | Include matrix values |
| Flaky tests | Random fail | Pattern/logs | Fix root cause |
| Service not ready | DB/Redis fail | Health check | Add readiness |
| Docker build fail | Build error | Context/auth | Fix build config |
| Publish fail | Registry denied | Token/version | Fix auth/version |
| OIDC fail | Cloud auth denied | id-token/trust | Fix permissions/claims |
| Wrong env var | Bad config | Env scope | Fix env/vars/secrets |
| Output missing | Value unavailable | Job outputs | Use `needs` outputs |
| Poor design | Hard to maintain | Workflow structure | Split/reuse/secure |

---

# Strong closing takeaway

GitHub Actions interviews are not just about writing YAML. They are about showing that you understand event-driven CI/CD, runner environments, secrets, permissions, artifacts, caches, deployment gates, and secure automation.

A weak answer sounds like:

> “I would rerun the workflow.”

A strong answer sounds like:

> “I would check whether the workflow triggered on the expected event, inspect the failed job and step logs, verify runner environment, permissions, secrets, cache/artifacts, and then apply the smallest fix with a guardrail.”

GitHub Actions problems usually leave evidence in:

```text
Actions run history
Workflow trigger event
Branch/path/tag filters
Job and step logs
Runner labels
Resolved contexts
GITHUB_TOKEN permissions
Secrets and environment scopes
Cache keys
Artifact names
Reusable workflow inputs
```

When you freeze, return to this sequence:

```text
Event → Workflow YAML → Job → Step → Runner → Context → Secrets → Permissions → Artifacts/cache → Fix → Verify
```

That sequence will carry you through most GitHub Actions interview questions.

---

# Final takeaway summaries

## The one-minute summary

GitHub Actions issues usually come from trigger filters, YAML syntax, runner labels, missing tools, job dependency mistakes, secrets, token permissions, checkout configuration, cache keys, artifacts, matrix expansion, conditions, environments, reusable workflows, fork restrictions, third-party action risk, deployment triggers, concurrency, service readiness, Docker builds, package publishing, OIDC, environment variable scope, job outputs, and poor workflow design. The best answer starts with the event, workflow file, failed job log, and permissions.

## The senior-engineer summary

A senior GitHub Actions engineer understands that CI/CD is production infrastructure. They design workflows with clear triggers, minimal permissions, scoped secrets, protected environments, concurrency controls, reproducible builds, trusted actions, useful artifacts, and clean reusable patterns. Seniority is shown by secure defaults, easy debugging, and safe deployments.

## The interview survival summary

When your mind goes blank, say:

> “I would first check whether the workflow ran on the expected event and ref. Then I would inspect the failed job and step, confirm the runner environment, check secrets and token permissions, review cache/artifact behavior, and verify any reusable workflow inputs or deployment environment rules. I would fix the proven cause and add a guardrail so the failure does not repeat.”

That answer works across most GitHub Actions interview scenarios.
