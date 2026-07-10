# Identity's DB responsibility reduction and SolidCache/SolidQueue maintenance

> **Status update (2026-05-19):** Obsolete. This plan was written for the retired identity-app /
> engine-era layout. Per `adr/split-into-regional-and-global-repos.md`, this repository is a single
> ordinary Rails app and must use the current surface-owned database naming model instead. Treat the
> paths and ownership rules below as historical only.

SolidCache / SolidQueue direction is now governed by `four-app-solid-cache-and-solid-queue.md`.

**Status:** Plan (2026-04-23)

## Context

`identity/` `config/database.yml` and `db/*_schema.rb` in Rails app has 8 DB connections remaining
(avatar, notification, publication, behavior, commerce, billing, message, search). these are:

- **avatar / notification / publication**: migrations_paths is already `engines/zenith/` and
  `engines/distributor/` and only the connection definition remains in identity
- **behavior / commerce / billing / message / search**: The model body is Exists in
  `engines/foundation/app/models/` (`BehaviorRecord` abstract class, etc.). identity `app/` It is
  not referenced at all from subordinates (`connects_to` zero has been confirmed)
- The 8 files under `identity/db/` are 883-byte empty stubs. Migration source is workspace root
  `/db/*_migrate/` or under the engine

For this `bin/rails db:migrate:reset` However, it also targets DBs that are not responsible for
identity, making it difficult to isolate the noise, time required, and communication failure in the
event of an error.

At the same time, identity would like to run SolidCache/SolidQueue as its own cache/job base as an
independent Rails app in the future, but currently:

- There is a gem in `Gemfile`, and `cache:` / `queue:` is connected to `database.yml`, but
- `config/cache.yml`, `config/queue.yml` are missing
- `cache_store` / `queue_adapter` is not set in `config/environments/*.rb`
- identity Locally `db/caches_migrate/`, `db/queues_migrate/` There is no directory (see workspace
  shared `../db/caches_migrate` etc.)

For reference, there is a fully working SolidCache/SolidQueue configuration in
`/home/jit/workspace/lib/`.

**Intended result:**

1. Leave only the DBs that should be owned by identity in `database.yml` and `db/`
2. The 8 DBs to be transferred are `identity/config/database.yml` and `identity/db/*_schema.rb`
   Delete from. Each Foundation/Zenith/Distributor app has its own `config/database.yml` It doesn't
   affect the data side because you still own them in
3. SolidCache/SolidQueue with single identity `db:migrate` (Starting the worker process is a
   separate task)

## Scope (DB held by identity)

> Superseded naming note: surface-owned databases now use the names accepted in
> `adr/surface-database-connection-naming.md`.

- **Retention**: `principal` / `token` / `operator` / `occurrence` / `com_preference` / `guest` /
  `activity` / `cache` / `queue` / `storage` / `cable`
- **Delete**: `avatar` / `notification` / `publication` / `behavior` / `commerce` / `billing` /
  `message` / `search` (including each `_replica`)

## Changes

### 1. Pruning `identity/config/database.yml`

Delete the following 8 pairs (16 blocks) from the `development:` section:

- `avatar` / `avatar_replica` (L213–223)
- `notification` / `notification_replica` (L114–124)
- `publication` / `publication_replica` (L81–91)
- `behavior` / `behavior_replica` (L180–190)
- `commerce` / `commerce_replica` (L59–69)
- `billing` / `billing_replica` (L92–102)
- `message` / `message_replica` (L103–113)
- `search` / `search_replica` (L48–58)

Delete the following from the `test: primary: migrations_paths:` array (L229–248):

- `../db/behavior_migrate`
- `../db/billing_migrate`
- `../db/commerces_migrate`
- `../db/messages_migrate`
- `../db/searches_migrate`
- `../engines/distributor/db/publications_migrate`
- `../engines/zenith/db/avatars_migrate`
- `../engines/zenith/db/notifications_migrate`

**Pending**: `../db/defaults_migrate`, `../db/documents_migrate`, `../db/finders_migrate` appears
only on the test side. Since there is no connection corresponding to development, it seems to be
virtually unused in identity, but since it may be a prerequisite when running tests, we will leave
it as is and reconsider its affiliation in a separate task.

### 2. orphan schema deletion for `identity/db/`

Delete the following 8 files:

- `identity/db/avatar_schema.rb`
- `identity/db/notification_schema.rb`
- `identity/db/publication_schema.rb`
- `identity/db/behavior_schema.rb`
- `identity/db/commerce_schema.rb`
- `identity/db/billing_schema.rb`
- `identity/db/message_schema.rb`
- `identity/db/search_schema.rb`

### 3. Create new `identity/config/cache.yml`

Copy `/home/jit/workspace/lib/config/cache.yml` as is. excerpt:

```yaml
development:
  encrypt: true
  store_options:
    max_age: <%= 1.week.to_i %>
    max_size: <%= 256.megabytes %>
    namespace: <%= Rails.env %>
# production / test section also matches lib/
```

When implementing, copy the entire text of `lib/config/cache.yml`.

### 4. Create new `identity/config/queue.yml`

Copy `/home/jit/workspace/lib/config/queue.yml` as is. excerpt:

```yaml
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: <%= ENV.fetch("JOB_CONCURRENCY", 1) %>
      polling_interval: 0.1
development:
  <<: *default
production:
  <<: *default
```

When implementing, copy the entire text of `lib/config/queue.yml`.

### 5. cache/queue wiring for `identity/config/environments/*.rb`

Wire the relevant part of `lib/config/environments/production.rb` (L76–80) to the reference:

- **development.rb**: `config.cache_store = :memory_store` to `:solid_cache_store` Changed to.
  `config.active_job.queue_adapter = :solid_queue` and Added
  `config.solid_queue.connects_to = { database: { writing: :queue } }`
- **production.rb**: Added the same 3 lines above. lib is production and `null_store` However, since
  identity runs as a standalone application, `:solid_cache_store` is the default. Any differences in
  policy from lib should be clearly stated in the commit message/review.
- **test.rb**: Leave `:null_store` unchanged

### 6. Migration placement (judgment required)

`cache:` / `queue:` entries of `identity/config/database.yml` are currently Referring to
`migrations_paths: ../db/caches_migrate` / `../db/queues_migrate` (workspace shared).

Choices:

- **A**: Refer to the workspace share as is. Don't put a copy on the identity side. Minimal changes.
- **B**: `identity/db/caches_migrate/` and `identity/db/queues_migrate/` Create
  `lib/db/caches_migrate/` / `lib/db/queues_migrate/` Copy the migration of `migrations_paths`
  Switch within identity. It will work even if identity becomes a completely independent repository
  structure in the future.

The decision will be made at the beginning of implementation. **Default recommendation is A** (to
minimize changes).

## Critical Files

- `/home/jit/workspace/identity/config/database.yml` (editor)
- `/home/jit/workspace/identity/db/*_schema.rb` (8 files deleted)
- `/home/jit/workspace/identity/config/cache.yml` (new)
- `/home/jit/workspace/identity/config/queue.yml` (new)
- `/home/jit/workspace/identity/config/environments/development.rb` (editor)
- `/home/jit/workspace/identity/config/environments/production.rb` (editor)

## Reference Files (copy source/verification source)

- `/home/jit/workspace/lib/config/cache.yml`
- `/home/jit/workspace/lib/config/queue.yml`
- `/home/jit/workspace/lib/config/environments/production.rb` (L76–80)
- `/home/jit/workspace/lib/db/caches_migrate/`
- `/home/jit/workspace/lib/db/queues_migrate/`
- `/home/jit/workspace/foundation/config/database.yml` (existing as connection destination for
  behavior/commerce/billing/message/search)
- `/home/jit/workspace/engines/foundation/app/models/*behavior*.rb` (for behavior model owner
  confirmation)

## Out of Scope (separate task)

- Foundation / Zenith / Distributor `database.yml` for each app Pruning (each has a non-responsible
  DB, but only identity this time)
- SolidQueue worker process startup (addition to `bin/dev` / `Procfile.dev`)
- Reconsidering the affiliation of `defaults_migrate` / `documents_migrate` / `finders_migrate`
- Examining whether `guest` / `activity` really owns identity (this time it will be left
  temporarily)

## Verification

### static validation

1. `grep -E "(avatar|notification|publication|behavior|commerce|billing|message|search):" /home/jit/workspace/identity/config/database.yml`
   → Must be 0 items
2. `ls /home/jit/workspace/identity/db/*_schema.rb` → There are no 8 files to be deleted
3. `test -f /home/jit/workspace/identity/config/cache.yml && test -f /home/jit/workspace/identity/config/queue.yml`
   → to exist

### Command validation

In the identity app directory:

```bash
cd /home/jit/workspace/identity
bundle exec rails runner 'p ActiveRecord::Base.configurations.configs_for(env_name: "development").map(&:name)'
# => Must not contain the connection name to be pruned. Only the items to be retained will appear.

bundle exec rails db:migrate:reset
# => Errors will be reduced compared to before pruning, and only DB owned by identity will be used by drop/create/migrate

bundle exec rails runner 'Rails.cache.write("k", "v"); p Rails.cache.read("k")'
# => "v" appears (SolidCache is valid)

bundle exec rails runner 'p Rails.application.config.active_job.queue_adapter'
# => :solid_queue

bundle exec rubocop config/ db/
bundle exec erb_lint .
```

### Regression confirmation

```bash
cd /home/jit/workspace/identity
bundle exec rails test
```

`connects_to` means there are currently zero tests referencing the deleted connection. Confirmed by
exploration. However, `migrations_paths` in the test section Since we remove 8 passes from
`test_identity_db` those tables no longer exist. `bundle exec rails test` may fail if the identity
test references a table such as Foundation. Pay close attention to the execution results.

## Risks

- **Reduction of migrations_paths in test section**: Currently, we have not confirmed that identity
  tests are going through Foundation tables. Is there any fixture loading or raw SQL remaining?
  Final check with `bundle exec rails test`
- **Enable SolidCache in development**: Communication to `cache` DB is required. Docker `rails c`
  tends to fail in an environment where compose has not been started. lib production is `null_store`
  In the commit message, clearly state that the policy is different from the one selected.
- **Foundation/Zenith/Distributor database.yml for each app remains intact**: The DB data itself is
  not lost because the connection disconnected from identity is alive in another app. However, the
  same work will be repeated when pruning each app in the future (separate task)
