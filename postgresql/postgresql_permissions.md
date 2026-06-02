# PostgreSQL Permissions and Role Audit Cheat Sheet

Use this as a practical checklist for checking PostgreSQL users, roles, table permissions, object permissions, and role assignments.

> Run these queries as a PostgreSQL superuser, `rds_superuser`, database owner, or another account with enough catalog visibility.

---

## 1. List users, roles, and key role attributes

```sql
SELECT
    rolname AS role_name,
    rolsuper AS is_superuser,
    rolcreatedb AS can_create_db,
    rolcreaterole AS can_create_role,
    rolcanlogin AS can_login,
    rolreplication AS can_replicate,
    rolbypassrls AS bypasses_rls,
    rolvaliduntil AS password_valid_until
FROM pg_roles
ORDER BY rolname;
```

### What to look for

```text
can_login = true      means this role can log in like a user
rolsuper = true       means full superuser access
rolcreaterole = true  means role can create/modify roles
rolcreatedb = true    means role can create databases
```

---

## 2. List login users only

```sql
SELECT
    rolname AS user_name,
    rolsuper AS is_superuser,
    rolcreatedb AS can_create_db,
    rolcreaterole AS can_create_role,
    rolreplication AS can_replicate,
    rolbypassrls AS bypasses_rls,
    rolvaliduntil AS password_valid_until
FROM pg_roles
WHERE rolcanlogin = true
ORDER BY rolname;
```

---

## 3. List group roles only

```sql
SELECT
    rolname AS group_role,
    rolsuper AS is_superuser,
    rolcreatedb AS can_create_db,
    rolcreaterole AS can_create_role
FROM pg_roles
WHERE rolcanlogin = false
ORDER BY rolname;
```

---

## 4. Show which roles are assigned to which users

```sql
SELECT
    member_role.rolname AS member,
    parent_role.rolname AS granted_role,
    grantor_role.rolname AS granted_by,
    membership.admin_option AS has_admin_option
FROM pg_auth_members membership
JOIN pg_roles member_role
    ON membership.member = member_role.oid
JOIN pg_roles parent_role
    ON membership.roleid = parent_role.oid
JOIN pg_roles grantor_role
    ON membership.grantor = grantor_role.oid
ORDER BY member_role.rolname, parent_role.rolname;
```

### Example output

```text
member       | granted_role | granted_by | has_admin_option
-------------+--------------+------------+-----------------
app_user     | app_readonly | postgres   | false
deploy_user  | app_owner    | postgres   | true
```

---

## 5. Show role inheritance tree

This helps when roles are nested.

```sql
WITH RECURSIVE role_tree AS (
    SELECT
        member_role.rolname AS member,
        parent_role.rolname AS inherited_role,
        1 AS depth,
        member_role.rolname || ' -> ' || parent_role.rolname AS path
    FROM pg_auth_members membership
    JOIN pg_roles member_role
        ON membership.member = member_role.oid
    JOIN pg_roles parent_role
        ON membership.roleid = parent_role.oid

    UNION ALL

    SELECT
        role_tree.member,
        parent_role.rolname AS inherited_role,
        role_tree.depth + 1,
        role_tree.path || ' -> ' || parent_role.rolname
    FROM role_tree
    JOIN pg_roles current_role
        ON role_tree.inherited_role = current_role.rolname
    JOIN pg_auth_members membership
        ON membership.member = current_role.oid
    JOIN pg_roles parent_role
        ON membership.roleid = parent_role.oid
)
SELECT
    member,
    inherited_role,
    depth,
    path
FROM role_tree
ORDER BY member, depth, inherited_role;
```

---

## 6. Check database-level permissions

```sql
SELECT
    datname AS database_name,
    pg_catalog.pg_get_userbyid(datdba) AS owner,
    has_database_privilege(datname, 'CONNECT') AS current_user_can_connect,
    has_database_privilege(datname, 'CREATE') AS current_user_can_create,
    has_database_privilege(datname, 'TEMP') AS current_user_can_temp,
    datacl AS raw_acl
FROM pg_database
ORDER BY datname;
```

### Check database permissions for all roles

```sql
SELECT
    role.rolname AS role_name,
    db.datname AS database_name,
    has_database_privilege(role.rolname, db.datname, 'CONNECT') AS can_connect,
    has_database_privilege(role.rolname, db.datname, 'CREATE') AS can_create,
    has_database_privilege(role.rolname, db.datname, 'TEMP') AS can_create_temp
FROM pg_roles role
CROSS JOIN pg_database db
WHERE role.rolcanlogin = true
ORDER BY role.rolname, db.datname;
```

---

## 7. Check schema ownership and privileges

```sql
SELECT
    nspname AS schema_name,
    pg_catalog.pg_get_userbyid(nspowner) AS owner,
    nspacl AS raw_acl
FROM pg_namespace
WHERE nspname NOT LIKE 'pg_%'
  AND nspname <> 'information_schema'
ORDER BY nspname;
```

### Check schema permissions for all login users

```sql
SELECT
    role.rolname AS role_name,
    schema.nspname AS schema_name,
    has_schema_privilege(role.rolname, schema.nspname, 'USAGE') AS can_use_schema,
    has_schema_privilege(role.rolname, schema.nspname, 'CREATE') AS can_create_in_schema
FROM pg_roles role
CROSS JOIN pg_namespace schema
WHERE role.rolcanlogin = true
  AND schema.nspname NOT LIKE 'pg_%'
  AND schema.nspname <> 'information_schema'
ORDER BY role.rolname, schema.nspname;
```

### What to look for

```text
USAGE on schema   required to access objects inside the schema
CREATE on schema  allows creating objects in that schema
```

---

## 8. Check table and view permissions

```sql
SELECT
    grantee,
    table_schema,
    table_name,
    privilege_type,
    is_grantable
FROM information_schema.role_table_grants
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_schema, table_name, grantee, privilege_type;
```

### Check table permissions for all login users

```sql
SELECT
    role.rolname AS role_name,
    table_info.schemaname AS schema_name,
    table_info.tablename AS table_name,
    has_table_privilege(role.rolname, quote_ident(table_info.schemaname) || '.' || quote_ident(table_info.tablename), 'SELECT') AS can_select,
    has_table_privilege(role.rolname, quote_ident(table_info.schemaname) || '.' || quote_ident(table_info.tablename), 'INSERT') AS can_insert,
    has_table_privilege(role.rolname, quote_ident(table_info.schemaname) || '.' || quote_ident(table_info.tablename), 'UPDATE') AS can_update,
    has_table_privilege(role.rolname, quote_ident(table_info.schemaname) || '.' || quote_ident(table_info.tablename), 'DELETE') AS can_delete,
    has_table_privilege(role.rolname, quote_ident(table_info.schemaname) || '.' || quote_ident(table_info.tablename), 'TRUNCATE') AS can_truncate,
    has_table_privilege(role.rolname, quote_ident(table_info.schemaname) || '.' || quote_ident(table_info.tablename), 'REFERENCES') AS can_reference,
    has_table_privilege(role.rolname, quote_ident(table_info.schemaname) || '.' || quote_ident(table_info.tablename), 'TRIGGER') AS can_trigger
FROM pg_roles role
CROSS JOIN pg_tables table_info
WHERE role.rolcanlogin = true
  AND table_info.schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY role.rolname, table_info.schemaname, table_info.tablename;
```

---

## 9. Check table owners

```sql
SELECT
    schemaname AS schema_name,
    tablename AS table_name,
    tableowner AS owner
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schemaname, tablename;
```

---

## 10. Check column-level permissions

```sql
SELECT
    grantee,
    table_schema,
    table_name,
    column_name,
    privilege_type,
    is_grantable
FROM information_schema.column_privileges
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_schema, table_name, column_name, grantee, privilege_type;
```

---

## 11. Check sequence permissions

Sequences often matter for `INSERT` permissions because serial or identity columns may require sequence access.

```sql
SELECT
    sequence_schema,
    sequence_name,
    grantee,
    privilege_type,
    is_grantable
FROM information_schema.role_usage_grants
WHERE object_type = 'SEQUENCE'
ORDER BY sequence_schema, sequence_name, grantee, privilege_type;
```

### Check sequence privileges for all login users

```sql
SELECT
    role.rolname AS role_name,
    seq.sequence_schema,
    seq.sequence_name,
    has_sequence_privilege(
        role.rolname,
        quote_ident(seq.sequence_schema) || '.' || quote_ident(seq.sequence_name),
        'USAGE'
    ) AS can_use,
    has_sequence_privilege(
        role.rolname,
        quote_ident(seq.sequence_schema) || '.' || quote_ident(seq.sequence_name),
        'SELECT'
    ) AS can_select,
    has_sequence_privilege(
        role.rolname,
        quote_ident(seq.sequence_schema) || '.' || quote_ident(seq.sequence_name),
        'UPDATE'
    ) AS can_update
FROM pg_roles role
CROSS JOIN information_schema.sequences seq
WHERE role.rolcanlogin = true
  AND seq.sequence_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY role.rolname, seq.sequence_schema, seq.sequence_name;
```

---

## 12. Check function and procedure permissions

```sql
SELECT
    routine_schema,
    routine_name,
    routine_type,
    grantee,
    privilege_type,
    is_grantable
FROM information_schema.routine_privileges
WHERE routine_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY routine_schema, routine_name, grantee, privilege_type;
```

### Check execute permission on functions

```sql
SELECT
    role.rolname AS role_name,
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    has_function_privilege(role.rolname, p.oid, 'EXECUTE') AS can_execute
FROM pg_roles role
CROSS JOIN pg_proc p
JOIN pg_namespace n
    ON p.pronamespace = n.oid
WHERE role.rolcanlogin = true
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY role.rolname, n.nspname, p.proname;
```

---

## 13. Check object-level ACLs directly from PostgreSQL catalogs

This shows raw ACLs on tables, views, materialized views, sequences, and foreign tables.

```sql
SELECT
    n.nspname AS schema_name,
    c.relname AS object_name,
    CASE c.relkind
        WHEN 'r' THEN 'table'
        WHEN 'v' THEN 'view'
        WHEN 'm' THEN 'materialized_view'
        WHEN 'S' THEN 'sequence'
        WHEN 'f' THEN 'foreign_table'
        WHEN 'p' THEN 'partitioned_table'
        ELSE c.relkind::text
    END AS object_type,
    pg_catalog.pg_get_userbyid(c.relowner) AS owner,
    c.relacl AS raw_acl
FROM pg_class c
JOIN pg_namespace n
    ON n.oid = c.relnamespace
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
  AND c.relkind IN ('r', 'v', 'm', 'S', 'f', 'p')
ORDER BY n.nspname, c.relname;
```

---

## 14. Expand ACLs into readable rows

This turns raw ACL arrays into one row per grant.

```sql
SELECT
    n.nspname AS schema_name,
    c.relname AS object_name,
    CASE c.relkind
        WHEN 'r' THEN 'table'
        WHEN 'v' THEN 'view'
        WHEN 'm' THEN 'materialized_view'
        WHEN 'S' THEN 'sequence'
        WHEN 'f' THEN 'foreign_table'
        WHEN 'p' THEN 'partitioned_table'
        ELSE c.relkind::text
    END AS object_type,
    grant_info.grantee::regrole AS grantee,
    grant_info.grantor::regrole AS grantor,
    grant_info.privilege_type,
    grant_info.is_grantable
FROM pg_class c
JOIN pg_namespace n
    ON n.oid = c.relnamespace
CROSS JOIN LATERAL aclexplode(c.relacl) AS grant_info
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
  AND c.relkind IN ('r', 'v', 'm', 'S', 'f', 'p')
ORDER BY n.nspname, c.relname, grantee, privilege_type;
```

---

## 15. Check default privileges

Default privileges control permissions automatically granted on future objects.

```sql
SELECT
    defaclrole::regrole AS owner_role,
    defaclnamespace::regnamespace AS schema_name,
    CASE defaclobjtype
        WHEN 'r' THEN 'tables'
        WHEN 'S' THEN 'sequences'
        WHEN 'f' THEN 'functions'
        WHEN 'T' THEN 'types'
        WHEN 'n' THEN 'schemas'
        ELSE defaclobjtype::text
    END AS object_type,
    defaclacl AS raw_default_acl
FROM pg_default_acl
ORDER BY owner_role, schema_name, object_type;
```

### Expand default privileges into readable rows

```sql
SELECT
    d.defaclrole::regrole AS owner_role,
    d.defaclnamespace::regnamespace AS schema_name,
    CASE d.defaclobjtype
        WHEN 'r' THEN 'tables'
        WHEN 'S' THEN 'sequences'
        WHEN 'f' THEN 'functions'
        WHEN 'T' THEN 'types'
        WHEN 'n' THEN 'schemas'
        ELSE d.defaclobjtype::text
    END AS object_type,
    grant_info.grantee::regrole AS grantee,
    grant_info.grantor::regrole AS grantor,
    grant_info.privilege_type,
    grant_info.is_grantable
FROM pg_default_acl d
CROSS JOIN LATERAL aclexplode(d.defaclacl) AS grant_info
ORDER BY owner_role, schema_name, object_type, grantee, privilege_type;
```

---

## 16. Check Row Level Security policies

Table privileges may say a user can `SELECT`, but RLS may still filter or block rows.

```sql
SELECT
    schemaname AS schema_name,
    tablename AS table_name,
    policyname AS policy_name,
    permissive,
    roles,
    cmd AS command,
    qual AS using_expression,
    with_check AS with_check_expression
FROM pg_policies
ORDER BY schemaname, tablename, policyname;
```

### Check which tables have RLS enabled

```sql
SELECT
    n.nspname AS schema_name,
    c.relname AS table_name,
    c.relrowsecurity AS rls_enabled,
    c.relforcerowsecurity AS rls_forced
FROM pg_class c
JOIN pg_namespace n
    ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'p')
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY n.nspname, c.relname;
```

---

## 17. Check privileges for one specific user

Replace `app_user` with the user or role you want to audit.

```sql
SELECT
    'database' AS object_type,
    datname AS object_name,
    has_database_privilege('app_user', datname, 'CONNECT') AS can_connect,
    has_database_privilege('app_user', datname, 'CREATE') AS can_create,
    has_database_privilege('app_user', datname, 'TEMP') AS can_temp
FROM pg_database
ORDER BY datname;
```

```sql
SELECT
    table_schema,
    table_name,
    has_table_privilege('app_user', quote_ident(table_schema) || '.' || quote_ident(table_name), 'SELECT') AS can_select,
    has_table_privilege('app_user', quote_ident(table_schema) || '.' || quote_ident(table_name), 'INSERT') AS can_insert,
    has_table_privilege('app_user', quote_ident(table_schema) || '.' || quote_ident(table_name), 'UPDATE') AS can_update,
    has_table_privilege('app_user', quote_ident(table_schema) || '.' || quote_ident(table_name), 'DELETE') AS can_delete
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
  AND table_type IN ('BASE TABLE', 'VIEW')
ORDER BY table_schema, table_name;
```

---

## 18. Check privileges for one specific table

Replace `public.orders` with your target table.

```sql
SELECT
    grantee,
    privilege_type,
    is_grantable
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name = 'orders'
ORDER BY grantee, privilege_type;
```

### Check all login users against one table

```sql
SELECT
    role.rolname AS role_name,
    has_table_privilege(role.rolname, 'public.orders', 'SELECT') AS can_select,
    has_table_privilege(role.rolname, 'public.orders', 'INSERT') AS can_insert,
    has_table_privilege(role.rolname, 'public.orders', 'UPDATE') AS can_update,
    has_table_privilege(role.rolname, 'public.orders', 'DELETE') AS can_delete,
    has_table_privilege(role.rolname, 'public.orders', 'TRUNCATE') AS can_truncate,
    has_table_privilege(role.rolname, 'public.orders', 'REFERENCES') AS can_reference,
    has_table_privilege(role.rolname, 'public.orders', 'TRIGGER') AS can_trigger
FROM pg_roles role
WHERE role.rolcanlogin = true
ORDER BY role.rolname;
```

---

## 19. Useful psql slash commands

These are fast interactive commands.

```psql
\du
```

Lists users and roles.

```psql
\du+
```

Lists users and roles with extra details.

```psql
\dp
```

Lists table, view, and sequence privileges.

```psql
\dp public.*
```

Lists privileges for objects in the `public` schema.

```psql
\dn+
```

Lists schemas and schema privileges.

```psql
\l+
```

Lists databases and database privileges.

```psql
\df+
```

Lists functions with details.

```psql
\ddp
```

Lists default privileges.

---

## 20. Common permission meanings

### Database privileges

```text
CONNECT  can connect to the database
CREATE   can create schemas in the database
TEMP     can create temporary tables
```

### Schema privileges

```text
USAGE    can access objects inside the schema
CREATE   can create objects inside the schema
```

### Table privileges

```text
SELECT      read rows
INSERT      insert rows
UPDATE      update rows
DELETE      delete rows
TRUNCATE    truncate table
REFERENCES  create foreign keys referencing table
TRIGGER     create triggers on table
```

### Sequence privileges

```text
USAGE   allows nextval()
SELECT  allows currval()
UPDATE  allows setval()
```

### Function privileges

```text
EXECUTE  can execute the function or procedure
```

---

## 21. Quick all-in-one audit query

This gives a compact table-level permission matrix for login users.

```sql
SELECT
    role.rolname AS role_name,
    table_info.table_schema,
    table_info.table_name,
    has_schema_privilege(role.rolname, table_info.table_schema, 'USAGE') AS schema_usage,
    has_table_privilege(role.rolname, quote_ident(table_info.table_schema) || '.' || quote_ident(table_info.table_name), 'SELECT') AS select,
    has_table_privilege(role.rolname, quote_ident(table_info.table_schema) || '.' || quote_ident(table_info.table_name), 'INSERT') AS insert,
    has_table_privilege(role.rolname, quote_ident(table_info.table_schema) || '.' || quote_ident(table_info.table_name), 'UPDATE') AS update,
    has_table_privilege(role.rolname, quote_ident(table_info.table_schema) || '.' || quote_ident(table_info.table_name), 'DELETE') AS delete
FROM pg_roles role
CROSS JOIN information_schema.tables table_info
WHERE role.rolcanlogin = true
  AND table_info.table_schema NOT IN ('pg_catalog', 'information_schema')
  AND table_info.table_type IN ('BASE TABLE', 'VIEW')
ORDER BY role.rolname, table_info.table_schema, table_info.table_name;
```

---

## 22. Quick user-to-role assignment report

```sql
SELECT
    user_role.rolname AS user_name,
    assigned_role.rolname AS assigned_role,
    membership.admin_option
FROM pg_auth_members membership
JOIN pg_roles user_role
    ON membership.member = user_role.oid
JOIN pg_roles assigned_role
    ON membership.roleid = assigned_role.oid
WHERE user_role.rolcanlogin = true
ORDER BY user_role.rolname, assigned_role.rolname;
```

---

## 23. Quick owner report for schemas, tables, sequences, views, and functions

```sql
SELECT
    'schema' AS object_type,
    n.nspname AS schema_name,
    n.nspname AS object_name,
    pg_get_userbyid(n.nspowner) AS owner
FROM pg_namespace n
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'

UNION ALL

SELECT
    CASE c.relkind
        WHEN 'r' THEN 'table'
        WHEN 'v' THEN 'view'
        WHEN 'm' THEN 'materialized_view'
        WHEN 'S' THEN 'sequence'
        WHEN 'f' THEN 'foreign_table'
        WHEN 'p' THEN 'partitioned_table'
        ELSE c.relkind::text
    END AS object_type,
    n.nspname AS schema_name,
    c.relname AS object_name,
    pg_get_userbyid(c.relowner) AS owner
FROM pg_class c
JOIN pg_namespace n
    ON n.oid = c.relnamespace
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
  AND c.relkind IN ('r', 'v', 'm', 'S', 'f', 'p')

UNION ALL

SELECT
    'function' AS object_type,
    n.nspname AS schema_name,
    p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')' AS object_name,
    pg_get_userbyid(p.proowner) AS owner
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')

ORDER BY object_type, schema_name, object_name;
```

---

## 24. Recommended audit flow

```text
1. List login users.
2. List non-login group roles.
3. Check role memberships.
4. Check database permissions.
5. Check schema permissions.
6. Check table, view, sequence, and function permissions.
7. Check object owners.
8. Check default privileges.
9. Check RLS policies.
10. Test one target user with has_*_privilege functions.
```

---

## 25. Example command to save output from psql

```bash
psql "$DATABASE_DSN" \
  -P pager=off \
  -c "SELECT rolname, rolcanlogin, rolsuper, rolcreatedb, rolcreaterole FROM pg_roles ORDER BY rolname;" \
  -o postgres_roles_audit.txt
```

### Save query output as Markdown-like aligned text

```bash
psql "$DATABASE_DSN" \
  -P pager=off \
  -P border=2 \
  -P format=aligned \
  -f postgres_permissions_audit.sql \
  -o postgres_permissions_audit_output.txt
```

### Save query output as CSV

```bash
psql "$DATABASE_DSN" \
  --csv \
  -f postgres_permissions_audit.sql \
  -o postgres_permissions_audit_output.csv
```
