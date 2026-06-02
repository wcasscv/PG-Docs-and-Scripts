# Ansible: “I Know This Stuff, But in the Interview I Freeze” Kit

## Strong intro

You can use Ansible every week and still freeze when someone asks about it in an interview.

That does not mean you do not know Ansible. It usually means your knowledge is practical, not rehearsed. In real work, you read the playbook, run with `--check`, inspect inventory, look at the failed task, test against one host, fix the variable or module issue, and move forward. In an interview, you are expected to explain that same process clearly, quickly, and calmly.

This kit is built for that gap.

It gives you the top 20 Ansible issues interviewers commonly ask about, with symptoms, causes, diagnosis steps, resolutions, and examples. It is written for people who know the work but sometimes lose the words under pressure.

When you freeze, use this sentence:

> “I would first confirm whether the problem is inventory, connectivity, privilege escalation, variables, idempotency, module behavior, templating, dependencies, or execution order. Then I would reproduce on one host with verbose output before changing the playbook globally.”

That is a strong answer. It shows structure. It shows production judgment. It shows you know Ansible is not just YAML — it is automation that changes real systems.

---

## How to use this kit

For every Ansible issue, think in this pattern:

```text
Symptom → Scope → Evidence → Cause → Fix → Verify → Prevent
```

A good interview answer usually includes:

1. What failed.
2. Whether it failed on one host or many.
3. Whether the failure is in inventory, SSH, privilege, variables, module usage, or target state.
4. How you would reproduce safely.
5. What you would change.
6. How you would verify the change.
7. How you would avoid the issue next time.

Example:

> “If a playbook fails, I would not immediately edit random YAML. I would isolate the failed task, run against one host with `-vvv`, check inventory and variables, confirm SSH and privilege escalation, and verify whether the module is being used idempotently.”

That sounds like someone who has handled production automation.

---

# Top 20 Ansible issues and resolutions

---

## 1. Inventory host not found or wrong hosts targeted

### Interview freeze point

The interviewer asks:

> “Your Ansible playbook ran on the wrong hosts. What happened?”

This is a common production risk. A strong answer shows you understand inventory, host patterns, groups, and safety controls.

### Strong interview answer

> “I would first check the inventory source and host pattern. Then I would run `ansible-inventory --list` and `ansible-playbook --list-hosts` before execution. If the wrong hosts are targeted, the issue is usually inventory grouping, limit usage, dynamic inventory output, environment selection, or an overly broad host pattern.”

### Symptoms

- Playbook says “no hosts matched.”
- Playbook targets too many hosts.
- Playbook runs against production instead of staging.
- Host appears in the wrong group.
- Dynamic inventory returns unexpected hosts.
- `--limit` does not behave as expected.

### Common causes

- Wrong inventory file passed with `-i`.
- Incorrect group name.
- Typo in host pattern.
- Host belongs to multiple groups.
- Dynamic inventory plugin misconfigured.
- Environment variables point to wrong inventory.
- Bad use of `all`.
- Missing `--limit` in a risky operation.

### Diagnostic commands

List parsed inventory:

```bash
ansible-inventory -i inventory.yml --list
```

Graph groups:

```bash
ansible-inventory -i inventory.yml --graph
```

Preview target hosts:

```bash
ansible-playbook -i inventory.yml site.yml --list-hosts
```

Run against a limited group:

```bash
ansible-playbook -i inventory.yml site.yml --limit webservers
```

### Example problem

Inventory:

```yaml
all:
  children:
    web:
      hosts:
        web01:
        web02:
    prod:
      hosts:
        web01:
        db01:
```

Playbook:

```yaml
- name: Restart services
  hosts: prod
  tasks:
    - name: Restart nginx
      ansible.builtin.service:
        name: nginx
        state: restarted
```

This targets `web01` and `db01`. If `db01` does not run nginx, the playbook fails or does unnecessary work.

### Resolution

Use more precise groups:

```yaml
all:
  children:
    prod_web:
      hosts:
        web01:
        web02:
    prod_db:
      hosts:
        db01:
```

Playbook:

```yaml
- name: Restart web services
  hosts: prod_web
  tasks:
    - name: Restart nginx
      ansible.builtin.service:
        name: nginx
        state: restarted
```

### Safety practice

Before destructive or production-wide changes:

```bash
ansible-playbook -i prod.yml deploy.yml --list-hosts
ansible-playbook -i prod.yml deploy.yml --check --diff --limit web01
```

### Takeaway summary

Inventory mistakes are dangerous because Ansible does exactly what you ask. Always preview the target set before high-impact changes.

---

## 2. SSH connection failures

### Interview freeze point

The playbook fails before any task runs. Many candidates jump to playbook debugging, but the issue may be basic connectivity.

### Strong interview answer

> “If Ansible cannot connect, I would test SSH separately and then through Ansible using the ping module. I would check hostname resolution, SSH user, private key, port, firewall, bastion settings, known_hosts, and inventory variables like `ansible_user` and `ansible_ssh_private_key_file`.”

### Symptoms

- `UNREACHABLE`
- `Permission denied (publickey)`
- `Connection timed out`
- `No route to host`
- `Host key verification failed`
- `Failed to connect to the host via ssh`

### Diagnostic commands

Test SSH directly:

```bash
ssh -i ~/.ssh/app_key ubuntu@web01
```

Test Ansible connection:

```bash
ansible web01 -i inventory.yml -m ansible.builtin.ping -vvv
```

Check inventory variables:

```bash
ansible-inventory -i inventory.yml --host web01
```

### Example inventory

```yaml
all:
  hosts:
    web01:
      ansible_host: 10.0.1.15
      ansible_user: ubuntu
      ansible_ssh_private_key_file: ~/.ssh/app_key
      ansible_port: 22
```

### Common causes

- Wrong SSH user.
- Wrong key.
- Hostname does not resolve.
- SSH port blocked.
- Target host is down.
- Bastion/jump host missing.
- Host key changed.
- Python missing on managed host.
- Ansible control node cannot reach private network.

### Resolution examples

Specify SSH user:

```bash
ansible-playbook -i inventory.yml site.yml -u ubuntu
```

Set inventory variables:

```yaml
web01:
  ansible_host: 10.0.1.15
  ansible_user: ubuntu
  ansible_ssh_private_key_file: /home/jack/.ssh/app_key
```

Use jump host:

```yaml
web01:
  ansible_host: 10.0.1.15
  ansible_user: ubuntu
  ansible_ssh_common_args: '-o ProxyJump=bastion.example.com'
```

### Takeaway summary

Connection failures are usually not YAML problems. Prove SSH, identity, network path, and inventory variables first.

---

## 3. Privilege escalation problems

### Interview freeze point

The task connects successfully but fails with permission errors.

### Strong interview answer

> “If a task fails with permission denied, I would check whether the module requires root privileges and whether `become` is configured correctly. I would verify the remote user, sudo permissions, password requirements, and whether `become_user` is correct.”

### Symptoms

- `Permission denied`
- `sudo: a password is required`
- `Missing sudo password`
- Cannot write to `/etc`
- Cannot restart service
- Package install fails
- File ownership changes fail

### Example failure

```yaml
- name: Install nginx
  hosts: web
  tasks:
    - name: Install nginx
      ansible.builtin.apt:
        name: nginx
        state: present
```

This may fail if the remote user is not root.

### Resolution

Use `become`:

```yaml
- name: Install nginx
  hosts: web
  become: true
  tasks:
    - name: Install nginx
      ansible.builtin.apt:
        name: nginx
        state: present
```

Use specific become user:

```yaml
- name: Run app maintenance
  hosts: app
  become: true
  become_user: appuser
  tasks:
    - name: Run maintenance script
      ansible.builtin.command: /opt/app/bin/maintenance
```

### Inventory example

```yaml
web01:
  ansible_host: 10.0.1.15
  ansible_user: deploy
  ansible_become: true
  ansible_become_method: sudo
```

### Diagnostic command

```bash
ansible web -i inventory.yml -m ansible.builtin.command -a "whoami" -b
```

### Common causes

- Forgot `become: true`.
- Remote user has no sudo rights.
- Sudo requires a password but none was provided.
- Wrong `become_user`.
- Target command requires a login shell environment.
- `sudoers` restrictions block command.

### Takeaway summary

Permission problems usually come down to remote user, `become`, sudo policy, and target file ownership.

---

## 4. Python interpreter problems on managed nodes

### Interview freeze point

Ansible uses SSH, but many modules need Python on the target. This surprises people.

### Strong interview answer

> “Many Ansible modules execute Python on the managed node. If Python is missing or Ansible picks the wrong interpreter, modules can fail. I would check interpreter discovery, set `ansible_python_interpreter` if needed, or bootstrap Python using raw commands.”

### Symptoms

- Module fails before execution.
- `python: not found`
- `/usr/bin/python: No such file or directory`
- Module import errors.
- Works on one OS but not another.
- Minimal cloud image fails.

### Diagnostic command

```bash
ansible all -i inventory.yml -m ansible.builtin.setup -vvv
```

Check remote Python:

```bash
ansible all -i inventory.yml -m ansible.builtin.raw -a "which python3 || which python"
```

### Resolution: set interpreter

```yaml
all:
  vars:
    ansible_python_interpreter: /usr/bin/python3
```

Per host:

```yaml
web01:
  ansible_host: 10.0.1.15
  ansible_python_interpreter: /usr/bin/python3
```

### Bootstrap Python

For very minimal systems:

```yaml
- name: Bootstrap Python
  hosts: all
  gather_facts: false
  become: true
  tasks:
    - name: Install Python on Debian/Ubuntu
      ansible.builtin.raw: test -e /usr/bin/python3 || (apt-get update && apt-get install -y python3)
      changed_when: false
```

### Important note

The `raw` module does not require Python on the target. That makes it useful for bootstrapping.

### Takeaway summary

If Ansible cannot run normal modules, check the target Python interpreter before blaming the playbook.

---

## 5. YAML syntax and indentation errors

### Interview freeze point

YAML looks simple, but tiny indentation mistakes break playbooks.

### Strong interview answer

> “I would validate YAML syntax first, then Ansible playbook syntax. YAML is whitespace-sensitive, so indentation, list markers, quoting, and dictionary structure matter. I would use `ansible-playbook --syntax-check` and linting before running against hosts.”

### Symptoms

- `mapping values are not allowed here`
- `did not find expected key`
- `ERROR! conflicting action statements`
- Task is parsed differently than expected.
- Variable appears as string instead of list/dict.

### Diagnostic commands

Syntax check:

```bash
ansible-playbook site.yml --syntax-check
```

Lint:

```bash
ansible-lint site.yml
```

### Bad example

```yaml
- name: Install packages
  hosts: web
  tasks:
  - name: Install nginx
      ansible.builtin.apt:
        name: nginx
        state: present
```

The module indentation is wrong.

### Correct example

```yaml
- name: Install packages
  hosts: web
  tasks:
    - name: Install nginx
      ansible.builtin.apt:
        name: nginx
        state: present
```

### Another common problem

Bad:

```yaml
packages:
  - nginx
   - curl
```

Correct:

```yaml
packages:
  - nginx
  - curl
```

### Safer habits

- Use two spaces consistently.
- Use editor YAML plugins.
- Run syntax check before execution.
- Use `ansible-lint`.
- Keep tasks small and readable.

### Takeaway summary

YAML errors are cheap to catch early. Syntax check and lint before running automation against real hosts.

---

## 6. Variable precedence confusion

### Interview freeze point

The task uses a value you did not expect. The hard part is explaining where Ansible got it.

### Strong interview answer

> “Ansible variables can come from many places, and precedence matters. If a variable has the wrong value, I would inspect host vars, group vars, role defaults, role vars, play vars, extra vars, inventory vars, and facts. I would use debug and `ansible-inventory --host` to confirm the final value.”

### Symptoms

- Wrong package version installed.
- Template renders wrong value.
- Environment-specific value ignored.
- Role default does not apply.
- Extra vars override everything expected.
- Works in staging but not production.

### Diagnostic examples

Show host variables:

```bash
ansible-inventory -i inventory.yml --host web01
```

Debug a variable:

```yaml
- name: Show app version
  ansible.builtin.debug:
    var: app_version
```

Show type and value:

```yaml
- name: Show variable type
  ansible.builtin.debug:
    msg: "app_version={{ app_version }} type={{ app_version | type_debug }}"
```

### Common sources

- `defaults/main.yml`
- `vars/main.yml`
- `group_vars/all.yml`
- `group_vars/prod.yml`
- `host_vars/web01.yml`
- Play vars
- Registered vars
- Facts
- Extra vars using `-e`

### Example

Role default:

```yaml
# roles/app/defaults/main.yml
app_version: "1.0.0"
```

Production override:

```yaml
# group_vars/prod.yml
app_version: "1.2.3"
```

Command-line override:

```bash
ansible-playbook deploy.yml -e app_version=2.0.0
```

The extra var wins.

### Resolution

Make variable ownership clear:

```yaml
# group_vars/prod.yml
app_environment: prod
app_version: "1.2.3"
```

Use role defaults for safe defaults:

```yaml
# roles/app/defaults/main.yml
app_port: 8080
```

Avoid hiding critical values in too many places.

### Takeaway summary

When a variable surprises you, find its source. Variable precedence is often the root cause of “Ansible ignored my value.”

---

## 7. Undefined variables

### Interview freeze point

The playbook fails because a variable does not exist. Candidates often patch it quickly without discussing safety.

### Strong interview answer

> “For undefined variables, I would check whether the variable should be required or optional. Required variables should fail early with a clear message. Optional variables should use safe defaults. I would avoid hiding real configuration mistakes with careless defaults.”

### Symptoms

- `'my_var' is undefined`
- Template rendering fails.
- Conditional fails.
- Role works in one environment but not another.
- Missing group vars or host vars.

### Bad example

```yaml
- name: Deploy app
  ansible.builtin.template:
    src: app.conf.j2
    dest: /etc/app/app.conf
```

Template:

```jinja2
server_name={{ app_server_name }}
```

If `app_server_name` is missing, the task fails.

### Resolution option 1: define the variable

```yaml
# group_vars/prod.yml
app_server_name: app.example.com
```

### Resolution option 2: use default for optional value

```jinja2
log_level={{ app_log_level | default('INFO') }}
```

### Resolution option 3: fail early for required value

```yaml
- name: Ensure app_server_name is defined
  ansible.builtin.assert:
    that:
      - app_server_name is defined
      - app_server_name | length > 0
    fail_msg: "app_server_name must be defined for this environment."
```

### Resolution option 4: role argument validation

For roles, define expected arguments in metadata where appropriate.

### Takeaway summary

Use defaults for optional values. Use assertions for required values. Do not silently hide missing critical configuration.

---

## 8. Idempotency problems

### Interview freeze point

An interviewer asks:

> “What does idempotency mean in Ansible?”

Many people define it but struggle to show it.

### Strong interview answer

> “Idempotency means I can run the playbook multiple times and it only changes the system when the desired state is not already present. Good Ansible uses modules that understand state, avoids unnecessary commands, and reports changed status accurately.”

### Symptoms

- Task reports changed every run.
- Handlers restart services every run.
- Playbook causes unnecessary deploys.
- `--check` output is noisy.
- Automation is not trusted.
- Repeated runs make different changes.

### Bad example

```yaml
- name: Restart nginx
  ansible.builtin.command: systemctl restart nginx
```

This always runs and may always show changed.

### Better example

```yaml
- name: Ensure nginx is running
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: true
```

### Bad file example

```yaml
- name: Add config line
  ansible.builtin.shell: echo "Port 8080" >> /etc/app.conf
```

This appends the line every run.

### Better example

```yaml
- name: Set app port
  ansible.builtin.lineinfile:
    path: /etc/app.conf
    regexp: '^Port '
    line: 'Port 8080'
```

### Use `changed_when` when needed

```yaml
- name: Check app status
  ansible.builtin.command: /opt/app/bin/status
  register: app_status
  changed_when: false
```

### Takeaway summary

Idempotency is what makes Ansible safe to re-run. Prefer state-aware modules over raw commands.

---

## 9. Misuse of shell and command modules

### Interview freeze point

You know `shell` and `command`, but the interviewer wants to know when not to use them.

### Strong interview answer

> “I prefer purpose-built modules first. I use `command` when I do not need shell features, and `shell` only when I need shell expansion, pipes, redirects, or environment behavior. If I must use them, I control idempotency with `creates`, `removes`, `changed_when`, or conditions.”

### Difference

`command` does not use a shell:

```yaml
- name: Run command
  ansible.builtin.command: uptime
```

`shell` uses a shell:

```yaml
- name: Run shell pipeline
  ansible.builtin.shell: ps aux | grep nginx
```

### Bad example

```yaml
- name: Install package
  ansible.builtin.shell: apt-get install -y nginx
```

Better:

```yaml
- name: Install package
  ansible.builtin.apt:
    name: nginx
    state: present
```

### Idempotent command example

```yaml
- name: Initialize app database
  ansible.builtin.command: /opt/app/bin/init-db
  args:
    creates: /var/lib/app/.db_initialized
```

### Safe status check

```yaml
- name: Check cluster status
  ansible.builtin.command: /opt/cluster/bin/status
  register: cluster_status
  changed_when: false
  failed_when: cluster_status.rc not in [0, 1]
```

### Common mistakes

- Using shell when a module exists.
- Forgetting idempotency.
- Not handling return codes.
- Unsafe variable interpolation.
- Commands depend on interactive shell profile.
- Using pipes where module output would be safer.

### Takeaway summary

Use `shell` and `command` carefully. They are escape hatches, not the default way to manage systems.

---

## 10. Handler not running or running unexpectedly

### Interview freeze point

Handlers are simple until they are not. Many production issues come from missed notifications or excessive restarts.

### Strong interview answer

> “Handlers run when notified by changed tasks, usually at the end of a play. If a handler does not run, I would check whether the notifying task actually changed, whether the handler name matches, and whether the play failed before handlers executed. If it runs unexpectedly, I would check idempotency of the notifying task.”

### Symptoms

- Service does not restart after config change.
- Service restarts every playbook run.
- Handler name typo.
- Handler not triggered because task reports unchanged.
- Play fails before handler runs.
- Multiple changes trigger one handler.

### Example

```yaml
- name: Deploy nginx config
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: Restart nginx

handlers:
  - name: Restart nginx
    ansible.builtin.service:
      name: nginx
      state: restarted
```

### Common problem: task always changed

```yaml
- name: Render timestamp
  ansible.builtin.template:
    src: build-info.j2
    dest: /etc/app/build-info
  notify: Restart app
```

If the template includes a changing timestamp, the handler restarts every run.

### Resolution

Remove changing content from config templates, or control change detection.

Force handlers before a risky step:

```yaml
- name: Flush handlers before validation
  ansible.builtin.meta: flush_handlers
```

### Handler listen pattern

```yaml
handlers:
  - name: Restart nginx service
    ansible.builtin.service:
      name: nginx
      state: restarted
    listen: restart web
```

Task:

```yaml
notify: restart web
```

### Takeaway summary

Handlers depend on changed status. If handlers misbehave, inspect idempotency and notifications first.

---

## 11. Check mode and diff mode misunderstandings

### Interview freeze point

An interviewer asks how you safely test a playbook. Saying “use check mode” is not enough.

### Strong interview answer

> “I use check mode and diff mode to preview changes, but I do not blindly trust them. Some modules support check mode well, some partially, and commands or shell tasks may not predict changes. I would test against a limited host first and verify module behavior.”

### Commands

Preview changes:

```bash
ansible-playbook -i inventory.yml site.yml --check
```

Show diffs:

```bash
ansible-playbook -i inventory.yml site.yml --check --diff
```

Limit blast radius:

```bash
ansible-playbook -i prod.yml site.yml --check --diff --limit web01
```

### Example where check mode helps

```yaml
- name: Render app config
  ansible.builtin.template:
    src: app.conf.j2
    dest: /etc/app/app.conf
```

`--diff` can show file changes.

### Example where check mode may not help

```yaml
- name: Run migration
  ansible.builtin.command: /opt/app/bin/migrate
```

Ansible cannot always know what this command would change.

### Resolution

Skip unsafe tasks in check mode:

```yaml
- name: Run migration
  ansible.builtin.command: /opt/app/bin/migrate
  when: not ansible_check_mode
```

Provide check-mode-safe validation:

```yaml
- name: Show migration command that would run
  ansible.builtin.debug:
    msg: "Would run migration"
  when: ansible_check_mode
```

### Takeaway summary

Check mode is a safety tool, not a guarantee. Use it with `--diff`, `--limit`, and module awareness.

---

## 12. Jinja2 template rendering errors

### Interview freeze point

Templates combine variables, filters, loops, and conditionals. Failures can be noisy.

### Strong interview answer

> “For template errors, I would check variable existence, data type, loop structure, filters, and quoting. I would render with known variables, debug the data structure, and use defaults or assertions where appropriate.”

### Symptoms

- Template fails to render.
- Output has wrong values.
- List renders as Python-like structure.
- Missing newline causes config error.
- Undefined variable in template.
- Wrong indentation in generated YAML/JSON.

### Example template

```jinja2
server {
  listen {{ app_port | default(8080) }};
  server_name {{ app_server_name }};
}
```

If `app_server_name` is undefined, rendering fails.

### Debug variables

```yaml
- name: Show app config variables
  ansible.builtin.debug:
    msg:
      app_port: "{{ app_port | default('undefined') }}"
      app_server_name: "{{ app_server_name | default('undefined') }}"
```

### Loop example

Variables:

```yaml
app_upstreams:
  - name: app01
    host: 10.0.1.10
    port: 8080
  - name: app02
    host: 10.0.1.11
    port: 8080
```

Template:

```jinja2
{% for upstream in app_upstreams %}
server {{ upstream.host }}:{{ upstream.port }};
{% endfor %}
```

### Safer JSON/YAML rendering

Use filters:

```jinja2
{{ app_config | to_nice_yaml }}
```

or:

```jinja2
{{ app_config | to_nice_json }}
```

### Validate config after template

```yaml
- name: Deploy nginx config
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    validate: 'nginx -t -c %s'
  notify: Restart nginx
```

### Takeaway summary

Template problems are usually variable, type, or formatting problems. Debug the data before blaming Jinja.

---

## 13. Facts missing, stale, or too slow

### Interview freeze point

Ansible facts are useful, but gathering them can be slow or unavailable.

### Strong interview answer

> “Facts come from the setup module and describe the target host. If facts are missing, I would check whether `gather_facts` is disabled or Python is unavailable. If facts are slow, I would gather only needed subsets, cache facts, or disable facts for plays that do not need them.”

### Symptoms

- `ansible_facts` variable missing.
- Playbook slow at start.
- Facts differ from expected host state.
- Minimal hosts fail during fact gathering.
- Conditional based on OS fails.

### Example

```yaml
- name: Install package based on OS
  hosts: all
  gather_facts: true
  tasks:
    - name: Install package on Debian
      ansible.builtin.apt:
        name: nginx
        state: present
      when: ansible_facts['os_family'] == 'Debian'
```

### Disable facts when not needed

```yaml
- name: Simple command play
  hosts: all
  gather_facts: false
  tasks:
    - name: Check uptime
      ansible.builtin.command: uptime
      changed_when: false
```

### Gather selected facts

```yaml
- name: Gather minimal facts
  ansible.builtin.setup:
    gather_subset:
      - min
```

### Cache facts example

In `ansible.cfg`:

```ini
[defaults]
fact_caching=jsonfile
fact_caching_connection=.ansible_facts_cache
fact_caching_timeout=3600
```

### Takeaway summary

Facts are powerful, but they have cost. Gather only what you need and cache when it helps.

---

## 14. Role structure and dependency problems

### Interview freeze point

A playbook works as one file, but becomes messy as it grows. Interviewers ask about roles to test maintainability.

### Strong interview answer

> “Roles organize reusable automation into defaults, vars, tasks, handlers, templates, files, and metadata. If role behavior is confusing, I would check variable defaults, role dependencies, task inclusion order, and whether the role is doing too much.”

### Common role structure

```text
roles/
  nginx/
    defaults/
      main.yml
    vars/
      main.yml
    tasks/
      main.yml
    handlers/
      main.yml
    templates/
      nginx.conf.j2
    files/
    meta/
      main.yml
```

### Example playbook

```yaml
- name: Configure web servers
  hosts: web
  become: true
  roles:
    - nginx
```

### Role default

```yaml
# roles/nginx/defaults/main.yml
nginx_port: 80
```

### Role task

```yaml
# roles/nginx/tasks/main.yml
- name: Install nginx
  ansible.builtin.package:
    name: nginx
    state: present

- name: Deploy nginx config
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: Restart nginx
```

### Handler

```yaml
# roles/nginx/handlers/main.yml
- name: Restart nginx
  ansible.builtin.service:
    name: nginx
    state: restarted
```

### Common problems

- Role has hidden variables.
- Defaults and vars are confused.
- Role is not reusable.
- Tasks depend on external state not documented.
- Handlers name collision.
- Dependencies create unexpected order.
- Role does too many unrelated things.

### Resolution

- Put overridable values in `defaults`.
- Use `vars` sparingly.
- Keep roles focused.
- Document required variables.
- Use assertions for required inputs.
- Use tags for targeted execution.
- Prefer collections for shared automation.

### Takeaway summary

Roles are for reuse and clarity. A good role has clear inputs, predictable outputs, and minimal hidden behavior.

---

## 15. Tags not working as expected

### Interview freeze point

Tags are useful for partial runs, but can create surprises when setup tasks are skipped.

### Strong interview answer

> “Tags control which tasks run, but they can skip dependencies if not designed carefully. If a tagged run fails, I would check whether required variables, facts, templates, or setup tasks were skipped. I would use tags deliberately and avoid making partial runs unsafe.”

### Example

```yaml
- name: Install nginx
  ansible.builtin.package:
    name: nginx
    state: present
  tags:
    - install

- name: Deploy nginx config
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  tags:
    - config
```

Run only config:

```bash
ansible-playbook site.yml --tags config
```

This may fail if nginx is not installed or directories do not exist.

### Common issues

- Required setup skipped.
- Handlers not included.
- Facts not gathered.
- Tags too broad.
- Tags too narrow.
- Role-level tags not understood.
- `always` tag misused.

### Useful tags

```yaml
- name: Always validate required vars
  ansible.builtin.assert:
    that:
      - app_port is defined
  tags:
    - always
```

Skip tags:

```bash
ansible-playbook site.yml --skip-tags dangerous
```

List tags:

```bash
ansible-playbook site.yml --list-tags
```

List tasks:

```bash
ansible-playbook site.yml --list-tasks
```

### Resolution

Design partial runs intentionally:

```yaml
tags:
  - nginx
  - nginx_config
```

Make setup dependencies clear and safe.

### Takeaway summary

Tags are not dependency management. They are execution filters. Design them carefully.

---

## 16. Loops, conditionals, and registered variables

### Interview freeze point

Tasks work without loops, then fail once loops and registered results are added.

### Strong interview answer

> “With loops, registered variables have a `results` list. I would inspect the registered structure with debug before writing conditions. Many loop problems come from assuming the result shape is the same as a non-loop task.”

### Example loop

```yaml
- name: Install packages
  ansible.builtin.package:
    name: "{{ item }}"
    state: present
  loop:
    - nginx
    - curl
    - git
```

### Register loop result

```yaml
- name: Check services
  ansible.builtin.command: systemctl is-active {{ item }}
  loop:
    - nginx
    - ssh
  register: service_checks
  changed_when: false
  failed_when: false
```

Debug:

```yaml
- name: Show service check results
  ansible.builtin.debug:
    var: service_checks
```

Access results:

```yaml
- name: Show inactive services
  ansible.builtin.debug:
    msg: "{{ item.item }} is not active"
  loop: "{{ service_checks.results }}"
  when: item.rc != 0
```

### Common mistakes

- Using `service_checks.rc` after a loop.
- Not using `service_checks.results`.
- Condition references wrong variable level.
- Looping over a string instead of list.
- Type mismatch in condition.
- Forgetting `failed_when: false` for checks.

### Safer conditional example

```yaml
when:
  - app_enabled | bool
  - app_port | int > 0
```

### Takeaway summary

When loops behave strangely, debug the registered variable. The result shape tells you how to write the condition.

---

## 17. File copy, template, and permissions issues

### Interview freeze point

The file exists, but the app cannot read it, or every run changes it.

### Strong interview answer

> “For file deployment issues, I would check source path, destination path, ownership, mode, SELinux context, line endings, template variables, and whether the task is idempotent. I would also validate configuration before restarting services.”

### Common modules

Copy static file:

```yaml
- name: Copy static file
  ansible.builtin.copy:
    src: files/app.conf
    dest: /etc/app/app.conf
    owner: root
    group: root
    mode: '0644'
```

Template dynamic file:

```yaml
- name: Render app config
  ansible.builtin.template:
    src: app.conf.j2
    dest: /etc/app/app.conf
    owner: root
    group: root
    mode: '0644'
```

Create directory:

```yaml
- name: Create app directory
  ansible.builtin.file:
    path: /etc/app
    state: directory
    owner: root
    group: root
    mode: '0755'
```

### Common causes

- Wrong relative source path.
- Destination directory missing.
- Wrong owner/group.
- Mode not quoted.
- SELinux context wrong.
- Template changes every run.
- Config not validated.
- Handler restarts service with bad config.

### Validate before applying

```yaml
- name: Deploy sudoers file safely
  ansible.builtin.copy:
    src: sudoers_app
    dest: /etc/sudoers.d/app
    owner: root
    group: root
    mode: '0440'
    validate: 'visudo -cf %s'
```

### Validate template

```yaml
- name: Deploy nginx config safely
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    validate: 'nginx -t -c %s'
  notify: Restart nginx
```

### Takeaway summary

File deployment is not just content. Ownership, mode, validation, and service impact matter.

---

## 18. Package manager and OS family differences

### Interview freeze point

A playbook works on Ubuntu but fails on RHEL. This tests portability.

### Strong interview answer

> “I would avoid hardcoding OS-specific package managers when portability matters. I would use the generic `package` module where possible, branch by `ansible_facts['os_family']` when needed, and keep OS-specific variables in group vars or vars files.”

### Symptoms

- `apt` fails on RHEL.
- `yum` fails on Ubuntu.
- Package names differ.
- Service names differ.
- Repo setup differs.
- Python package dependencies differ.

### Portable package task

```yaml
- name: Install nginx
  ansible.builtin.package:
    name: "{{ nginx_package_name }}"
    state: present
```

Variables:

```yaml
# group_vars/debian.yml
nginx_package_name: nginx
```

```yaml
# group_vars/redhat.yml
nginx_package_name: nginx
```

Sometimes names differ:

```yaml
# group_vars/debian.yml
web_package: apache2
web_service: apache2
```

```yaml
# group_vars/redhat.yml
web_package: httpd
web_service: httpd
```

Task:

```yaml
- name: Install web package
  ansible.builtin.package:
    name: "{{ web_package }}"
    state: present

- name: Start web service
  ansible.builtin.service:
    name: "{{ web_service }}"
    state: started
    enabled: true
```

### Conditional example

```yaml
- name: Update apt cache
  ansible.builtin.apt:
    update_cache: true
  when: ansible_facts['os_family'] == 'Debian'

- name: Ensure yum cache is current
  ansible.builtin.yum:
    update_cache: true
  when: ansible_facts['os_family'] == 'RedHat'
```

### Takeaway summary

Portable Ansible separates intent from OS-specific implementation.

---

## 19. Secrets handling and Ansible Vault mistakes

### Interview freeze point

Secrets in automation are high risk. The interviewer wants to hear safe handling, not just “use Vault.”

### Strong interview answer

> “Secrets should not be stored in plain text. I would use Ansible Vault or an external secrets manager, avoid printing secrets in logs, use `no_log` for sensitive tasks, and control who can decrypt or rotate secrets.”

### Symptoms

- Password committed to Git.
- Secret appears in CI logs.
- Playbook prompts for missing vault password.
- Wrong vault password used.
- Secrets duplicated across environments.
- Sensitive output shown in failed task.

### Create encrypted file

```bash
ansible-vault create group_vars/prod/vault.yml
```

Edit encrypted file:

```bash
ansible-vault edit group_vars/prod/vault.yml
```

Run playbook with vault prompt:

```bash
ansible-playbook -i prod.yml site.yml --ask-vault-pass
```

Use vault password file carefully:

```bash
ansible-playbook -i prod.yml site.yml --vault-password-file ~/.vault_pass
```

### Example vault variable pattern

Encrypted file:

```yaml
vault_db_password: "super-secret-password"
```

Plain variable mapping:

```yaml
db_user: app_user
db_password: "{{ vault_db_password }}"
```

### Avoid logging secrets

```yaml
- name: Create database user
  community.postgresql.postgresql_user:
    name: "{{ db_user }}"
    password: "{{ db_password }}"
  no_log: true
```

### Common mistakes

- Storing vault password file in Git.
- Forgetting `no_log`.
- Using same secret across all environments.
- Making vault file unreadable by automation pipeline.
- Printing registered secret output.
- Not rotating leaked secrets.

### Takeaway summary

Vault protects secrets at rest. `no_log`, access control, and rotation protect secrets during real automation.

---

## 20. Performance, scale, and rollout control problems

### Interview freeze point

The playbook works on five hosts but struggles on five hundred.

### Strong interview answer

> “At scale, I would control concurrency, batching, fact gathering, SSH settings, strategy, and task design. I would use `serial` for safe rollouts, `forks` for parallelism, `throttle` for sensitive tasks, and `async` for long-running operations when appropriate.”

### Symptoms

- Playbook takes too long.
- Too many SSH connections.
- Load balancer sees too many hosts restart at once.
- Package repo overloaded.
- Database migration runs from every host.
- One slow host blocks rollout.
- Control node CPU high.

### Control parallelism

In `ansible.cfg`:

```ini
[defaults]
forks = 20
```

Command line:

```bash
ansible-playbook site.yml --forks 20
```

### Rolling deployment

```yaml
- name: Rolling web deployment
  hosts: web
  serial: 2
  tasks:
    - name: Deploy app
      ansible.builtin.copy:
        src: app.tar.gz
        dest: /opt/app/app.tar.gz

    - name: Restart app
      ansible.builtin.service:
        name: app
        state: restarted
```

### Run task once

```yaml
- name: Run database migration once
  ansible.builtin.command: /opt/app/bin/migrate
  run_once: true
  delegate_to: "{{ groups['app'][0] }}"
```

### Throttle sensitive task

```yaml
- name: Restart app slowly
  ansible.builtin.service:
    name: app
    state: restarted
  throttle: 1
```

### Async task

```yaml
- name: Start long-running job
  ansible.builtin.command: /opt/app/bin/reindex
  async: 3600
  poll: 0
  register: reindex_job
```

### Common fixes

- Disable facts when not needed.
- Cache facts.
- Use `serial` for rolling changes.
- Use `forks` carefully.
- Avoid unnecessary shell commands.
- Reduce template work.
- Use `run_once` for global tasks.
- Use `delegate_to` for control tasks.
- Avoid restarting all hosts at once.

### Takeaway summary

Ansible at scale needs rollout control. Safe automation is not only correct — it is paced.

---

# Bonus: interview answer frameworks

## Framework 1: The failed playbook answer

Use this when asked:

> “An Ansible playbook failed. How do you troubleshoot it?”

```text
1. Read the failed task and error.
2. Check whether the host is unreachable or the task failed.
3. Re-run with `-vvv` against one host.
4. Confirm inventory and host variables.
5. Check SSH connectivity and privilege escalation.
6. Debug variables and templates.
7. Validate module arguments.
8. Confirm target system state.
9. Apply the smallest fix.
10. Re-run with `--check`, `--diff`, and `--limit` where useful.
```

Interview answer:

> “I separate unreachable hosts from failed tasks. If unreachable, I troubleshoot SSH, inventory, and network. If the task failed, I inspect the module error, variables, privilege escalation, and target state. I reproduce on one host before changing the playbook broadly.”

---

## Framework 2: The safe production run answer

Use this when asked:

> “How do you safely run Ansible in production?”

```text
1. Review inventory and host pattern.
2. Preview hosts with `--list-hosts`.
3. Run syntax check and lint.
4. Use `--check --diff` where supported.
5. Limit to one host first.
6. Use `serial` for rolling changes.
7. Use handlers and validation.
8. Protect secrets.
9. Monitor results.
10. Roll back or stop if health checks fail.
```

Interview answer:

> “Before production, I confirm the target set, run syntax checks, use check and diff mode when useful, test with `--limit` on one host, and roll out with `serial`. I also validate configs before restarting services.”

---

## Framework 3: The idempotency answer

Use this when asked:

> “How do you make Ansible idempotent?”

```text
1. Prefer state-aware modules.
2. Avoid raw shell unless needed.
3. Use `creates` and `removes` for commands.
4. Use `changed_when` for status checks.
5. Use `failed_when` for expected return codes.
6. Avoid changing timestamps in templates.
7. Let handlers run only when real changes occur.
8. Re-run the playbook and expect no changes.
```

Interview answer:

> “I prove idempotency by running the playbook twice. The second run should report no changes unless the system drifted.”

---

## Framework 4: The variable debugging answer

Use this when asked:

> “Ansible is using the wrong variable. What do you check?”

```text
1. Print the variable with debug.
2. Show its type with `type_debug`.
3. Inspect host vars with `ansible-inventory --host`.
4. Check group vars and host vars.
5. Check role defaults and role vars.
6. Check play vars and registered vars.
7. Check extra vars.
8. Remove duplicate/conflicting definitions.
```

Interview answer:

> “I would find where the variable is coming from rather than just overriding it again. Extra vars, host vars, group vars, role vars, and defaults all have different precedence.”

---

# Common Ansible interview traps and better answers

## Trap 1: “Would you just run the playbook again?”

Weak answer:

> “Yes, Ansible is idempotent.”

Better answer:

> “Only if the playbook is actually idempotent. I would inspect the failed task, confirm whether partial changes occurred, and re-run safely against a limited target if needed.”

---

## Trap 2: “Why not use shell for everything?”

Weak answer:

> “Shell is easier.”

Better answer:

> “Shell is useful, but purpose-built modules are safer because they understand state and idempotency. I use shell only when I need shell features or no module exists.”

---

## Trap 3: “Is check mode enough for production safety?”

Weak answer:

> “Yes.”

Better answer:

> “No. Check mode is useful, but support varies by module. I combine it with `--diff`, `--limit`, syntax checks, validation commands, and rolling deployment controls.”

---

## Trap 4: “Can extra vars fix this?”

Weak answer:

> “Yes, pass `-e`.”

Better answer:

> “Extra vars override many other values, so they are powerful but risky. I would use them intentionally, not as a permanent fix for unclear variable ownership.”

---

## Trap 5: “Can we restart all hosts at once?”

Weak answer:

> “Yes, Ansible can do it.”

Better answer:

> “Technically yes, but operationally risky. I would use `serial`, health checks, and load balancer draining for production rollouts.”

---

# Ansible interview quick-reference table

| Issue | Main symptom | First thing to check | Common fix |
|---|---|---|---|
| Wrong inventory target | Wrong hosts changed | `--list-hosts`, inventory graph | Fix groups, use `--limit` |
| SSH failure | `UNREACHABLE` | SSH directly, `-vvv` | Fix user, key, host, port |
| Privilege issue | Permission denied | `become`, sudo rights | Add `become`, fix sudo |
| Python missing | Module cannot run | Interpreter discovery | Set interpreter, bootstrap Python |
| YAML error | Syntax failure | `--syntax-check` | Fix indentation/structure |
| Variable precedence | Wrong value used | Debug var, inventory host view | Clarify variable source |
| Undefined variable | Template/task fails | Required vs optional var | Define, default, or assert |
| Idempotency issue | Changed every run | Task/module behavior | Use state modules, `changed_when` |
| Shell misuse | Unsafe/non-idempotent tasks | Module availability | Use module or guard command |
| Handler issue | Service not restarted or always restarted | Changed status and notify | Fix idempotency/handler names |
| Check mode issue | Preview inaccurate | Module check support | Use limit, diff, validation |
| Template issue | Bad config rendered | Variables and types | Debug data, validate template |
| Facts issue | Missing/slow facts | `gather_facts`, setup | Gather subset/cache/disable |
| Role issue | Confusing reuse | Role structure and defaults | Clear inputs and focused roles |
| Tags issue | Partial run breaks | `--list-tags`, dependencies | Design safe tags |
| Loop/register issue | Condition fails | Registered result shape | Use `.results`, debug |
| File permission issue | App cannot read file | Owner, group, mode, SELinux | Set file attributes, validate |
| OS differences | Works on one distro only | Facts and package names | Use vars and generic modules |
| Secret leak | Password exposed | Vault and logs | Vault, `no_log`, rotate |
| Scale issue | Slow/risky rollout | Forks, serial, facts | Use batching and control |

---

# Strong closing takeaway

Ansible interviews are not just YAML tests. They are production judgment tests.

The interviewer wants to know whether you can automate safely, debug calmly, avoid blast radius, and write playbooks that can be trusted repeatedly.

A weak answer sounds like:

> “I would run the playbook.”

A strong answer sounds like:

> “I would preview the target hosts, run syntax checks, test against one host, verify variables and privileges, use idempotent modules, validate configs before restart, and roll out gradually with `serial`.”

That is the voice of someone who understands automation risk.

When you freeze, return to this:

```text
Inventory → Connection → Privilege → Variables → Idempotency → Module behavior → Target state → Safe rollout
```

That sequence will carry you through most Ansible interview questions.

---

# Final takeaway summaries

## The one-minute summary

Ansible problems usually come from inventory, SSH connectivity, privilege escalation, Python on targets, YAML syntax, variables, idempotency, templates, handlers, secrets, OS differences, or rollout scale. The best interview answer starts by narrowing the failure: unreachable host or failed task, one host or many, playbook issue or target state issue.

## The senior-engineer summary

A senior Ansible user does not just make playbooks pass. They make automation safe to repeat. They preview hosts, reduce blast radius, use idempotent modules, protect secrets, validate configuration before service restarts, and roll out changes gradually. They understand that Ansible can break many systems quickly if inventory, variables, or tags are wrong.

## The interview survival summary

When your mind goes blank, say:

> “I would first check the target hosts, connectivity, privilege escalation, variables, and failed task output. Then I would reproduce on one host with verbose logging, confirm idempotency, apply the smallest fix, and re-run safely with `--check`, `--diff`, and `--limit` where appropriate.”

That answer works across most Ansible interview scenarios.
