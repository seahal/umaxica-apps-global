# Fix `rails test` DB write failures + dev/test speedups (tmpfs WAL exhaustion)

## Context

Repeated `rails test` runs eventually fail with DB write errors, and test runs feel slow.
Host-side investigation (podman compose / exec / journal) established the causal chain:

1. **Primary's 64G tmpfs fills up** — 2,387 "No space left on device" errors in primary logs.
   Once full, every write in tests fails ("db に書き込めない").
2. **What fills it: WAL retained by an inactive replication slot.** Primary init creates
   `replication_slot_slave1`; `pg_replication_slots` shows it `active = f`, and
   `docker/psql-pub/postgresql.conf` has no `max_slot_wal_keep_size` → all test-run WAL is
   retained forever on the RAM-backed tmpfs.
3. **Why the slot is orphaned: silent fallback.** `docker/psql-sub/entrypoint.sh` runs
   `pg_basebackup ... || :`. On failure (observed twice: primary already full; primary
   restarted mid-backup) the empty PGDATA falls through to a fresh `initdb` — the "replica"
   boots as an **independent writable PG** (verified: no `standby.signal`). It never streams,
   the slot never advances. Violates the repo no-silent-fallback rule.
4. Container restarts wipe tmpfs → works for a few runs → repeats. Each wipe also forces a
   full rebuild of 54 test DBs, part of the perceived slowness.

Answers to open questions:
- **Replica is NOT working as a reader right now** — it's a stale standalone PG; dev reads
  route to it and see stale data. Tests don't touch it at all: `POSTGRESQL_TEST_HOST` is
  unset so `test_host` = `POSTGRESQL_HOST` = `primary`; all 54 test DBs (writer + reader)
  live on primary.
- **PostgreSQL is not writing to SSD.** `findmnt` confirms a real tmpfs (RAM) mount, and
  `fsync=off`, `synchronous_commit=off`, `full_page_writes=off` are already set. The SSD
  writes are on the **Rails side**: the devcontainer override (`.devcontainer/compose.override.yml`)
  deliberately resets the tmpfs list so `workspace/tmp` and `workspace/log` fall back to the
  ZFS bind mount (past "lost state / sporadic write failures"). So bootsnap cache, tmp/cache,
  and test/dev logs hit ZFS on every run.

User direction: this is dev-only and periodically volatile — prefer speed over integrity.

## Changes

### 1. `docker/psql-sub/entrypoint.sh` — fail loudly instead of initdb fallback

- Remove `|| :` on `pg_basebackup`; with `set -e` the container exits and compose
  (`restart: unless-stopped`) retries, instead of silently booting a standalone primary.
- Bounded retry loop around basebackup (clear `$PGDATA` between attempts, re-check primary
  readiness), `exit 1` with a clear log line after N attempts.
- Guard: if `$PGDATA` is non-empty but lacks `standby.signal`, log and exit — never serve a
  stale standalone copy again.

### 2. `docker/psql-pub/postgresql.conf` — bound WAL retention

- `max_slot_wal_keep_size = 4GB` (matches `max_wal_size`). An inactive/lagging slot then
  costs at most ~4GB of tmpfs; PG invalidates the slot instead of filling the disk. The
  replica re-clones via pg_basebackup on its next start, so losing the slot is fine in dev.

### 3. Speed: move Rails test-run write paths off ZFS (test env only)

The override comment says tmpfs for the whole `workspace/tmp` / `workspace/log` caused lost
state, so instead redirect only the hot test paths to `/tmp` (which IS tmpfs in core):

- `config/environments/test.rb`: point the log to tmpfs —
  `config.paths["log"] = "/tmp/rails-test/test.log"` (16 parallel workers currently append
  to ZFS-backed `log/test.log`).
- Same file: bootsnap/cache scratch — set `config.cache_store` already memory? verify; and
  `ENV["BOOTSNAP_CACHE_DIR"] ||= "/tmp/bootsnap"` for test in `config/boot.rb` guarded to
  test env only (keeps dev behavior unchanged). If a guard in boot.rb is too intrusive, set
  it via `test/test_helper.rb` is too late — prefer boot.rb with `RAILS_ENV == "test"` check.

### 4. Speed: measure, then tune knobs with evidence

After 1–3 land, run `bin/rails test` twice inside core (`podman compose exec core ...`),
timing db:test:prepare vs test execution. Only if DB time still dominates, consider:
- raising `PARALLEL_WORKERS` above the default 16 (core has 32 CPUs),
- `autovacuum = off` on primary (dev DBs are volatile; vacuum churn is wasted work between
  wipes) — acceptable per user's speed-over-integrity direction.

### 5. One-time recovery of the running environment (needs user OK — wipes dev data)

- `podman compose build replica && podman compose up -d --force-recreate primary replica`
  (tmpfs data including dev DBs is lost; test DBs rebuilt by next `db:test:prepare`).

## Verification

1. Slot streams: `psql -c "select active, wal_status from pg_replication_slots"` → `t`;
   replica has `standby.signal`; `show max_slot_wal_keep_size` → 4GB.
2. Run `bin/rails test` several times; between runs check
   `df -h /var/lib/postgresql/data` and `du -sh .../pg_wal` on primary — WAL bounded ≤ ~4GB,
   no new "No space left on device" in `podman logs global-devcontainer-primary`.
3. Kill/restart primary while replica is cloning → replica retries/exits; never comes up
   writable without `standby.signal`.
4. Speed: record wall-clock of `bin/rails test` before/after change 3; confirm test.log now
   appears under /tmp inside core and nothing new is written to ZFS `log/` during tests.
