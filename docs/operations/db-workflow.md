# Database Operations Workflow

This application uses approximately 25 PostgreSQL databases. Follow these development and test
environment rules to avoid schema-change incidents.

## Principles

1. **Do not use incremental `bin/rails db:migrate` on a branch with in-progress table-rename
   migrations.** Use `bin/rails db:migrate:reset` so every database is rebuilt from migrations.
2. **Do not write silent-skip helpers such as `rename_table_if_present`.** Use
   `rename_table_strict`, provided by `MigrationHelpers::SafeTableRename`.
3. **Run `bin/rails db:verify_no_schema_drift` before committing.** Confirm that applying migrations
   to clean databases produces the committed schema dumps.

## Why Incremental `db:migrate` Is Unsafe During Renames

`db:migrate` assumes that every earlier migration was applied correctly. A branch that renames
tables across roughly 25 databases frequently violates that assumption:

- After switching branches, some databases may reflect the new schema dump while others retain the
  old schema, causing a missing-table failure.
- Adding a `rename_table_if_present` silent skip to avoid the failure can record a successful
  migration against a partially renamed schema. The intermediate schema is then dumped, committed,
  and propagated to other environments.
- Fixtures use current table names and cannot load into a partially renamed database, causing broad
  test failures.

`bin/rails db:migrate:reset` performs drop, create, and migrate on every run, so intermediate state
does not accumulate.

## Commands

```bash
bin/rails db:migrate:reset
RAILS_ENV=test bin/rails db:migrate:reset

bin/rails db:verify_no_schema_drift
# Applies migrations to clean test databases and succeeds when the result matches
# the committed db/*_structure.sql files. Reports schema drift and exits 1 otherwise.
```

## Stop the Server Before Resetting Databases

The `app_setting` database initializes preference reference rows through
`insert_missing_fixed_ids!` on demand. If the server remains active during a reset, an incoming
request can arrive while databases are being dropped and recreated. Connection-pool checkout then
blocks until the socket timeout, approximately ten seconds, and produces a
`Rack::Timeout::RequestTimeoutException` with an HTTP 500 response.

```bash
# Correct procedure
# 1. Stop Puma, Foreman, and docker compose.
# 2. Reset the databases.
bin/rails db:migrate:reset
# 3. Restart the server. Startup pre-seeds all preference reference tables.
```

`config/initializers/preference_reference_defaults.rb` seeds every preference reference table in
`after_initialize`, so the first request after restart sees populated databases.

## Writing Table-Rename Migrations

```ruby
class RenameUsersToClients < ActiveRecord::Migration[8.2]
  def up
    rename_table_strict :users, :clients
  end

  def down
    rename_table_strict :clients, :users
  end
end
```

`rename_table_strict` behaves as follows:

| Old table | New table | Behavior |
|---|---|---|
| Present | Absent | Rename the table |
| Absent | Present | Skip as an idempotent rerun |
| Present | Present | **Raise** because the schema is partially renamed and requires manual resolution |
| Absent | Absent | **Raise** because the schema does not match the expected state |

The former `rename_table_if_present` silently skipped whenever either side was missing. That hid
partial renames and produced schema drift. `rename_table_strict` raises for every state requiring
manual resolution.

## Recommended Schema-Drift CI Check

Add the following step to the end of the `database-consistency` job in
`.github/workflows/integration.yml` when enabling schema-drift enforcement:

```yaml
- name: Verify no schema drift
  run: bin/rails db:verify_no_schema_drift
```

The check fails when the branch's committed schema dumps differ from applying migrations to clean
databases.
