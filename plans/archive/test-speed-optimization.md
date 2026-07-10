# Test runtime profiling, Docker dev cache mounts, and `fixtures :all` audit

## Context

The test suite already has strong fundamentals:

- Parallel workers with `CpuWorkers.detect` and work-stealing
- PostgreSQL 18 unlogged tables on tmpfs (zero disk I/O)
- 15 sharded test databases (guest, principal, setting, search, token, symbol, mark, notification,
  cache, queue, storage, occurrence, chronicle, operator, avatar)
- `strict_loading_by_default = :raise` to catch N+1 immediately
- `test-prof` 1.6.1 bundled (`Gemfile:111`)
- 774 test files, 194 fixtures (~882 KB)

Pain points identified:

- Dev `docker compose build` lacks bundler / pnpm / apt cache mounts (only the `production-build`
  stage has them at `Dockerfile:84-89`).
- `test-prof` is bundled but no script surfaces its runners.
- Baseline test runtime is undocumented — no before/after target exists.
- `fixtures :all` (`test/test_helper.rb:121`) loads all 194 fixtures into every test class via
  inheritance.

**Outcome:** documented baseline, three concrete speedups (Docker cache mounts, `bin/test-profile`,
scoped fixtures for the worst offenders), and verification that `db:test:prepare` runs the 16 shards
in parallel.

## Root cause

1. **Dockerfile cache mounts only on `production-build`.** Each dev rebuild re-downloads gems, npm
   packages, and apt packages.
2. **`test-prof` is unwired** — no entry point makes it discoverable.
3. **Inherited `fixtures :all`** forces all 194 fixtures into every worker process, which is a
   constant per-worker startup cost across 16 shards.
4. **Rails 8 `db:test:prepare`** may iterate shards serially; with 16 DBs that compounds
   first-test-run cost.

## Files to modify or create

- `Dockerfile` — add `--mount=type=cache,target=/usr/local/bundle`,
  `--mount=type=cache,target=/root/.local/share/pnpm/store`, and
  `--mount=type=cache,target=/var/cache/apt,sharing=locked` to the dev stage.
- `compose.yaml` — verify `primary.healthcheck.start_period`; bump to `10s` if races appear during
  step 1 baseline.
- `bin/test-profile` (new, executable bash) — wraps `test-prof` env vars for `--stackprof`,
  `--eventprof`, `--rubyprof`, `--fixtures`.
- `docs/testing/profiling.md` (new) — baseline numbers, workflow, before / after sections.
- `lib/tasks/db_test_parallel.rake` (new, only if Rails 8's built-in is serial) — fork-per-shard
  runner.
- `test/test_helper.rb` — keep `fixtures :all` as the global default; document opt-out per class via
  comment.
- Top 10 slowest test files identified in step 1 — replace inherited `fixtures :all` with scoped
  lists (e.g. `fixtures :users, :user_emails`).
- `config/environments/test.rb` (or a CI startup hook) — assert `ENV["CI"]` is set in CI so
  `eager_load` activates.

## Implementation steps

1. **Capture baseline.**

   ```bash
   time bin/rails test 2>&1 | tee tmp/test-baseline.log
   time RAILS_ENV=test bin/rails db:test:prepare 2>&1 | tee tmp/db-prepare-baseline.log
   ```

   Record total wall-clock, slowest 25 tests, and `db:test:prepare` time in
   `docs/testing/profiling.md` under `## Baseline (YYYY-MM-DD, $(git rev-parse --short HEAD))`.

2. **Dockerfile dev cache mounts.** Add to dev-stage `RUN` blocks (apt and pnpm install steps):

   ```dockerfile
   RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
       --mount=type=cache,target=/var/lib/apt,sharing=locked \
       apt-get update && apt-get install -y --no-install-recommends ...

   RUN --mount=type=cache,target=/root/.npm \
       --mount=type=cache,target=/root/.local/share/pnpm/store \
       npm install -g pnpm@11.0.8
   ```

   For bundler — only useful if dev stage runs `bundle install`. If it does, add
   `--mount=type=cache,target=/usr/local/bundle`. If `bundle install` runs at container start
   instead, leave a comment in the Dockerfile pointing to the entrypoint.

3. **`bin/test-profile` script.** Bash wrapper:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   case "${1:-}" in
     --stackprof)  shift; TEST_STACK_PROF=1 exec bin/rails test "$@" ;;
     --eventprof)  shift; EVENT_PROF="${EVENT_PROF:-sql.active_record}" exec bin/rails test "$@" ;;
     --rubyprof)   shift; TEST_RUBY_PROF=1 exec bin/rails test "$@" ;;
     --fixtures)   shift; FPROF=1 exec bin/rails test "$@" ;;
     *)            echo "usage: bin/test-profile {--stackprof|--eventprof|--rubyprof|--fixtures} [test args]"; exit 64 ;;
   esac
   ```

   `chmod +x bin/test-profile`. Document each mode in `docs/testing/profiling.md` with example
   output paths (`tmp/test_prof_reports/`).

4. **`fixtures :all` audit.**
   - Run `bin/test-profile --fixtures` (or stackprof) on the slowest 10 test classes from step 1.
     test-prof's `FactoryProf`-equivalent for fixtures will show which fixtures are loaded but
     unused.
   - For each top offender, override the inherited `fixtures :all` with a scoped list. Run
     `bin/rails test <file>` after each change to ensure no missing-fixture errors.
   - Cap at 10 files — keep blast radius small.

5. **Parallel `db:test:prepare`.**
   - Inspect Rails 8 source to confirm whether `db:test:prepare` iterates shards serially. If
     serial, add `lib/tasks/db_test_parallel.rake`:

     ```ruby
     namespace :db do
       namespace :test do
         desc "Prepare test databases in parallel across shards"
         task prepare_parallel: :environment do
           shards = ActiveRecord::Base.connects_to_shards.keys # adjust to project's shard registry
           Parallel.each(shards, in_processes: shards.size) do |shard|
             system!({ "RAILS_TEST_SHARD" => shard.to_s }, "bin/rails db:test:prepare")
           end
         end
       end
     end
     ```

   - Wire into `bin/setup` and CI before `bin/rails test`.

6. **CI eager_load assertion.** `config.eager_load = ENV["CI"].present?`. In
   `config/environments/test.rb` or a CI startup script, assert:

   ```ruby
   if ENV["CI"].nil? && ENV["FORCE_EAGER_LOAD"].nil?
     # OK — local dev
   elsif ENV["CI"].present? && !Rails.application.config.eager_load
     abort("CI must run with eager_load=true; ensure ENV['CI'] is exported")
   end
   ```

7. **`compose.yaml` healthcheck.** If step 1 logs show `psql: connection refused` or transient
   `PG::ConnectionBad` during container startup, bump `primary.healthcheck.start_period` to `10s`.
   Keep `core.depends_on.primary.condition: service_healthy`.

8. **Re-measure.** Repeat step 1, append `## After (YYYY-MM-DD)` section to
   `docs/testing/profiling.md`. Target: ≥15% wall-clock reduction. If not achieved, document why and
   what the next bottleneck is.

## Verification

- `bin/rails test` — green; total time recorded and compared to baseline.
- `bin/test-profile --eventprof sql.active_record` — produces a report; top SQL is documented.
- `docker compose build core` (after step 2) — second build shows `CACHED` lines for bundler / pnpm
  / apt steps.
- `bin/rails db:test:prepare` (or `:prepare_parallel`) runs the 16 shards; with
  `RAILS_LOG_LEVEL=debug` confirm parallel connections appear.
- CI run logs include a line confirming `eager_load=true`.

## Out of scope

- Switching to FactoryBot (rejected by project convention; fixtures are authoritative).
- Switching to SQLite for tests (multi-DB sharding requires PostgreSQL).
- Adding Capybara / Playwright system tests (deferred per
  `plans/backlog/gh576-automated-test-stack.md`).
- Reducing `parallelize(workers:)` count (already optimal via `CpuWorkers.detect`).
- Replacing tmpfs with persistent volumes (production-only consideration).
