# Hostile Review — PostgreSQL Time-Range Partition Maintenance Design

> Scope: adversarial architecture + operations review only. No implementation, no migrations. Roles
> applied: PostgreSQL partitioning expert, SRE, DBA, Rails architect, security reviewer, incident
> responder. Target data class: authentication, audit, ceremony, security-event. Assume Rails 8,
> PostgreSQL 16+, external scheduler, monthly RANGE partitions.

## Context

The proposal maintains monthly RANGE partitions, enforces retention by physically dropping expired
partitions, pre-creates 12 months ahead, optionally keeps a DEFAULT partition, and runs serially
from an external scheduler via `rails db:partitions:maintain` under an advisory lock.

This review exists because the design is being aimed at the **most consequential data in the
system** (auth/audit/security/ceremony). The bar is not "does it usually work" — it is "does it
lose, mis-bucket, or expose security evidence under failure, and does it stall logins during
business hours." Against that bar, the design has several disqualifying gaps as written.

Repo grounding (this is not a greenfield app):

- The app runs **~20 logical databases** across `app`/`com`/`org` surfaces (`*_principal`,
  `*_signal`, `*_ticket`, `*_zenith`, `occurrence`, `chronicle`, ...). A single task + single
  advisory lock does not model this fan-out.
- `config.active_record.schema_format = :sql` with committed `db/*_structure.sql` and a
  **`db:verify_no_schema_drift`** gate (`lib/tasks/schema_drift_check.rake`). Runtime- created
  partitions collide with this directly.
- The repo's _existing_ partitioning intent is **HASH** (users/staffs/tokens for scale —
  `plans/backlog/database-improvements.md`, `plans/archive/gh586-...`), **not** time-RANGE. The two
  have different trade-offs; do not let this design quietly satisfy that backlog.

---

## 1. Executive Summary

The design is **sound as a retention mechanism and dangerous as written for this data class.**
Partitioning by month so you can `DROP` instead of `DELETE` is the correct instinct. But the
proposal:

1. **Conflates two unrelated goals** — cheap retention (DROP) and query performance (pruning) — and
   is only justified by the first. The costs (loss of cross-partition unique constraints, lock
   fan-out, DEFAULT foot-guns) are paid **whether or not** reads ever benefit. Nobody has shown the
   hot read paths filter on the time key.
2. **Breaks unique constraints that are security-critical.** PostgreSQL has no global indexes; a
   unique index on a partitioned table _must include the partition key_. So `UNIQUE(jti)`,
   `UNIQUE(token_hash)`, `UNIQUE(session_id)` become impossible without adding `created_at`, which
   **destroys the uniqueness guarantee** (same jti in two months passes). For auth/security tables
   this is a correctness and security defect, not a performance footnote.
3. **Treats DROP as the cleanup primitive for audit/security evidence with no archive and no
   grace.** A retention misconfig or a maintenance bug **permanently destroys evidence** —
   potentially mid-incident.
4. **Ignores DDL lock blast radius.** DROP/ATTACH/non-concurrent DETACH take `ACCESS EXCLUSIVE` on
   the **parent**, stalling _all_ writes (logins) during the operation. A populated DEFAULT turns
   ATTACH into a full-scan-under-exclusive-lock outage.
5. **Has a timezone boundary bug waiting to happen** (JST app, UTC boundaries) that can drop or
   mis-bucket data hours early — a compliance and evidence problem.
6. **Underspecifies the multi-DB fan-out and pooler interaction**, where a single advisory lock is
   both insufficient (N databases) and unreliable (pgbouncer transaction pooling breaks session
   advisory locks).

Verdict up front: **do not ship as described.** It is salvageable, but only after the critical flaws
below are closed.

---

## 2. Critical Flaws (block production)

### C1. Unique constraints on security tables become unenforceable

No global indexes in PostgreSQL. Every unique index is per-partition and **must include the
partition key**. Consequence for this data class:

- `jti`, `token_hash`, `session_id`, idempotency keys cannot be globally unique once the table is
  range-partitioned on `created_at`.
- The only "fix" — `UNIQUE(created_at, jti)` — permits the _same_ jti in two months. For
  replay/forgery defense that is a **security hole**, not a tradeoff.
- **Action:** any table with a cross-row global uniqueness invariant on a non-time column is a
  **non-candidate** for time-range partitioning. Audit _event_ logs (append-only, no uniqueness) are
  candidates; token/session/credential tables generally are **not**.

### C2. DROP as the retention primitive destroys evidence irreversibly

Direct `DROP TABLE events_YYYY_MM` is unrecoverable. For audit/security/ceremony data:

- A wrong retention value, an off-by-one in month math, or a TZ bug deletes evidence **forever**,
  possibly during an active breach investigation.
- **Action:** two-phase removal — `DETACH` (CONCURRENTLY on 14+) → export/archive to cold storage
  (`COPY`/`pg_dump`) → `DROP` only after a grace window. Never drop security data without an archive
  and a delay.

### C3. DDL lock blast radius stalls the write path

`DROP`, non-concurrent `DETACH`, and `ATTACH` all take `ACCESS EXCLUSIVE` on the **parent** (briefly
for DROP/ATTACH to rewrite the partition descriptor; ATTACH also validates).

- With a **populated DEFAULT**, `ATTACH` of a new partition must scan the entire default under
  `ACCESS EXCLUSIVE` to prove no rows belong to the new range → a write outage proportional to
  default size. On a busy `signal`/`ticket`/auth DB this stalls logins.
- A `DROP`/`DETACH` queued behind a long-running read waits, and while it waits it blocks _every_
  new query on the parent (lock queue). No `lock_timeout` is specified.
- **Action:** `SET lock_timeout` + `statement_timeout` on every maintenance DDL; prefer
  `DETACH CONCURRENTLY`; never run ATTACH against a populated DEFAULT (see C4).

### C4. The DEFAULT partition is a foot-gun for this workload

It trades a loud failure (INSERT can't route) for a silent one (rows pile into default):

- **Hides the missing-partition bug** until ATTACH blocks for minutes (C3).
- **Has no retention story** — dropping monthly partitions never drains the default, so it grows
  unbounded **and** holds data past retention → _over_-retention compliance breach, the opposite
  failure from data loss.
- Every range query that _might_ overlap must scan it; it cannot be pruned away.
- **Action:** for high-volume security/audit data, **prefer NO default** + guaranteed look-ahead + a
  loud page if an INSERT ever fails to route. If a default is kept, alert at **rows > 0** and treat
  any occupancy as an incident; never ATTACH while it is populated.

### C5. Timezone boundary mis-bucketing / early deletion (JST app)

Range bounds like `'2026-06-01'` are interpreted in the session `TimeZone`. If the partition key is
`timestamptz` and maintenance runs in UTC while the business thinks in JST, a row at
`2026-06-01 08:00 JST` (= `2026-05-31 23:00 UTC`) lands in the **May** partition. "Drop May" then
deletes data the business considers June 1 — **evidence destroyed early** and a retention-compliance
violation.

- **Action:** fix the key type (`timestamptz`) and pin a single canonical zone for _both_ boundaries
  and retention math (recommend UTC end-to-end, documented), and assert it in the task. No DST in
  Japan removes one hazard but not this one.

### C6. Schema-drift gate vs runtime-created partitions (repo-specific)

`schema_format = :sql` + committed `db/*_structure.sql` + `db:verify_no_schema_drift` (compares
committed dumps to migrations-from-clean-DB). Partitions created at runtime exist in a real DB's
dump but **not** in migrations → permanent drift, or developers exclude partitions from the dump and
lose schema fidelity. Either way the CI gate is defeated or lies.

- **Action:** decide explicitly how partitions are represented: keep the _parent_ + template in
  migrations, and **exclude leaf partitions** from drift comparison with a documented, tested filter
  — not an ad-hoc dump hack.

---

## 3. High-Risk Issues

### H1. Cross-partition queries cause lock fan-out → `out of shared memory`

A query that does **not** filter on the partition key opens **every** partition, each taking an
`AccessShareLock`. With many months × many tables × the app's ~20 DBs, this exhausts
`max_locks_per_transaction` and produces `out of shared memory` errors that cascade across a
surface. Audit lookups are frequently by `actor`/`event_type`, **not** by time — so this is likely,
not theoretical.

- **Action:** prove the hot read paths filter on the time key. If they don't, the table gets the
  _costs_ of partitioning with **none** of the pruning benefit — reconsider.

### H2. Look-ahead must be gap-filling and idempotent, or missed runs become outages

If "+12 months" means "create next month" per run rather than "ensure all months in [now, now+12]
exist," a few missed scheduler runs erode the buffer; with no default the first uncovered INSERT
fails (`no partition of relation ... found for row`).

- **Action:** each run reconciles the _entire_ target window (create all missing), so any number of
  missed runs self-heals on the next success.

### H3. Advisory lock is per-DB and pooler-fragile

`pg_advisory_lock` is scoped to **one database** and bound to a **backend connection**:

- The app has ~20 DBs → one lock does not serialize maintenance across them. Need a lock per target
  DB (or a coordinator DB).
- **pgbouncer in transaction pooling mode breaks session advisory locks** — the lock sits on a
  backend the pooler can reassign. If maintenance goes through the pooler, the lock is unreliable.
- **Action:** run maintenance on a **dedicated direct connection** (bypass the pooler), take a
  session advisory lock **per database**, ensure release on all paths, and set K8s CronJob
  `concurrencyPolicy: Forbid` / scheduler dedup as defense in depth.

### H4. Scheduler missed-execution is the #1 silent failure, and there's no dead-man's switch

External cron failing silently is the classic outage. The design lists "emit alerts" on success but
nothing detects **absence** of success.

- **Action:** heartbeat / dead-man's-switch (Healthchecks.io / Dead Man's Snitch / Prometheus
  Pushgateway) that pages if no successful run in > interval.

### H5. Multi-DB partial failure leaves inconsistent retention state

No cross-DB transaction. A run that succeeds on `app_signal` but fails on `org_signal` leaves
surfaces in divergent retention/coverage states with no atomic rollback.

- **Action:** per-DB status reporting, idempotent re-runs, and an aggregate health check that flags
  divergence across surfaces.

---

## 4. Medium-Risk Issues

- **M1. Autovacuum / wraparound per partition.** Each partition is a separate table for autovacuum
  and `relfrozenxid`. Many partitions = many objects to keep below wraparound; cold old partitions
  can age toward `autovacuum_freeze_max_age` unnoticed. Monitor txid age per partition; a
  detached-but-not-frozen orphan is a wraparound risk.
- **M2. Planner statistics.** Parent has no rows; pruning and plan quality depend on per-partition
  stats and on predicates being sargable on the key. `WHERE date_trunc('day', ts) = ...` does
  **not** prune. Generic/prepared plans can degrade pruning (`plan_cache_mode`).
- **M3. Foreign keys.** FKs _into_ a partitioned table require the referenced key to include the
  partition column; FKs _out_ fan out per partition. Any relation pointing at a partitioned auth
  table needs review.
- **M4. DETACH CONCURRENTLY caveats.** Cannot run inside a transaction block; a failure can leave a
  partition in "detach pending" state needing `FINALIZE`. The task must handle and alert on that
  state.
- **M5. Detached-but-not-dropped disk leak.** A two-phase flow that detaches but fails to drop leaks
  storage silently. Monitor for orphaned detached partitions.
- **M6. Backup/restore & logical replication.** PITR/restore can resurrect data believed deleted
  (compliance). Logical replication of partitioned sets needs `publish_via_partition_root`
  decisions. Out of band but must be documented.
- **M7. `lib/` autoload.** In Rails 8 (zeitwerk) `lib/` is **not** autoloaded by default. Logic
  under `lib/maintenance` won't load unless required or path-added → `uninitialized constant` at
  runtime, or accidental double-load. (Existing repo pattern:
  `lib/migration_helpers_safe_table_rename.rb` + `lib/migration_helpers/`, explicitly required.)

---

## 5. Answers To The Posed Questions (condensed)

1. **Monthly the right default?** Acceptable when retention is in whole months _and_ hot reads
   filter on the time key. Prefer **weekly** when retention granularity is sub-monthly (e.g.
   14/30-day legal max — monthly buckets force keeping up to ~2 months), when a single month
   partition is too large/hot for vacuum and index maintenance, or under very high ingest. **Avoid
   partitioning entirely** for small tables (< a few GB), tables not queried by the time key, and
   any table needing a global unique constraint on a non-time column (most token/session/credential
   tables — see C1).
2. **PG surprises overlooked:** no global indexes; unique must include the key (C1); FK constraints
   (M3); per-partition autovacuum/wraparound (M1); pruning only on sargable key predicates and
   weaker under generic plans (M2); cross-partition lock fan-out (H1); ATTACH/DETACH/DROP
   `ACCESS EXCLUSIVE` on parent + DEFAULT scan-under-lock (C3/C4).
3. **Operational failure modes:** silent missed runs (H4); non-gap-filling look-ahead (H2); year
   boundary off-by-one (use exclusive upper bound `TO '2027-01-01'`); **leap year is a non-issue for
   monthly range only if you do month arithmetic, never day/30-day math**; TZ mis-bucketing (C5);
   concurrent runs / pooler-broken locks (H3).
4. **DEFAULT advisable?** Generally **no** for this workload (C4). Benefit: ingest availability when
   a partition is missing. Risks: hidden bugs, ATTACH outage, no retention story, unbounded growth,
   over-retention breach. If kept: alert at rows > 0, never ATTACH while populated, and have a
   tested drain procedure (INSERT…SELECT into the right partition then DELETE under a window) before
   creating the missing partition.
5. **Future-creation failure:** do **not** silently continue, and do **not** proceed to DROP while
   coverage is unknown. Severity is a **function of remaining runway** — warn with 12-month buffer,
   escalate to critical as look-ahead shrinks (e.g. < 2 months).
6. **Expired-removal failure:** lower availability urgency (data merely retained) but a
   **compliance** problem (over-retention; APPI/GDPR erasure). Alert, track against an SLA, retry
   idempotently; never block ingest. Watch for DROP blocked by a long query (needs `lock_timeout`).
7. **Drop vs detach:** **detach (concurrently) → archive → drop after grace.** Direct drop of
   security/audit data with no archive is reckless (C2). Detach also decouples the drop's lock
   impact from the parent.
8. **Advisory locking sufficient?** Necessary, not sufficient. Per-DB scope, session-bound,
   pooler-fragile (H3). Use a dedicated direct connection, one session lock per target DB,
   guaranteed release, `lock_timeout` on DDL, and scheduler-level dedup. Remaining races:
   ATTACH-vs-writes on a populated default, DROP-vs-long-query (mitigate with `lock_timeout`
   - `DETACH CONCURRENTLY`).
9. **`lib/maintenance` home?** Workable but mind zeitwerk: `lib/` isn't autoloaded in Rails 8 (M7).
   Keep the rake task thin in `lib/tasks/partitions.rake`; put logic in an explicitly-required
   module mirroring the existing `lib/migration_helpers` pattern. Don't place ops-only code in
   `app/` (it would eager-load into web processes in prod).
10. **Single task vs many?** Provide **both**: composable subtasks (`db:partitions:create_ahead`,
    `:drop_expired`, `:verify`, `:status`) for 3am incident use, plus an **orchestrator** the
    scheduler calls that runs phases in order with per-phase observability and continue/abort
    decisions. Avoid one opaque monolith you can't run a single phase of during an incident.
11. **Monitoring required:** months-of-coverage-ahead (alert < N); **default occupancy rows > 0 →
    page**; future partition count vs target; oldest-partition age within retention **and** not
    exceeding legal max; **scheduler heartbeat / dead-man's switch** (H4); per-partition size/skew,
    autovacuum lag, txid age; DDL `lock_timeout` aborts; detached-not-dropped orphans — **across all
    ~20 databases**.
12. **Disaster scenarios remaining:** retention misconfig drops evidence mid-incident (C2); TZ early
    deletion / mis-bucket (C5); ATTACH-on-populated-default write outage (C3/C4); cross-partition
    lock storm → `out of shared memory` (H1); duplicate jti/token across months → replay/forgery
    (C1); pgbouncer-broken lock → concurrent maintenance corrupts ATTACH state (H3); schema-drift CI
    defeated (C6); multi-DB partial-failure divergence (H5); PITR resurrecting "deleted" data (M6).

---

## 6. Recommended Design Changes

1. **Classify every candidate table first.** Append-only, time-keyed, no global-unique → eligible.
   Token/session/credential/anything with a non-time unique invariant → **not** eligible for
   time-range partitioning (C1). Document the eligibility decision per table.
2. **Justify by read pattern, not just retention.** If hot reads don't filter on the time key,
   accept that partitioning is _purely_ a retention tool and re-evaluate whether the costs are worth
   it vs. a batched `DELETE` with index on `deletable_at` (the repo already has
   `deletable_at`/`shreddable_at` lifecycle columns — gh586).
3. **Two-phase removal with archive + grace** (C2/H/7). Detach-concurrently → export → drop after
   window. Never direct-drop security data.
4. **Drop the DEFAULT** for high-volume security/audit; rely on guaranteed gap-filling look-ahead +
   loud INSERT-route failure paging (C4/H2). If retained, monitor rows>0 as an incident.
5. **Pin timezone (UTC) for key, boundaries, and retention math; assert it in the task** (C5).
6. **Per-DB session advisory lock on a dedicated direct (non-pooled) connection**, with
   `lock_timeout`/`statement_timeout` on all DDL and scheduler `concurrencyPolicy: Forbid` (H3/C3).
7. **Orchestrator + composable subtasks**, idempotent, gap-filling, with per-phase alerting; abort
   before DROP if coverage validation fails (H2/Q5/Q10).
8. **Heartbeat / dead-man's-switch** for missed runs; alert on absence of success (H4).
9. **Resolve the structure.sql/drift story explicitly** — parent+template in migrations, leaf
   partitions excluded from drift via a documented tested filter (C6).
10. **Severity by runway:** creation-failure warn→critical as look-ahead shrinks; removal-failure
    tracked against a compliance SLA (Q5/Q6).
11. **Do not let this design silently satisfy the HASH-partitioning backlog** — different goal,
    different trade-offs (gh586 / database-improvements).

---

## 7. Operational Checklist

- [ ] Per-table eligibility decision recorded (global-unique check, read-pattern check).
- [ ] Key is `timestamptz`; boundaries + retention math pinned to UTC and asserted.
- [ ] Look-ahead reconciles the full [now, now+N] window every run (gap-filling, idempotent).
- [ ] DROP replaced by detach-concurrently → archive → drop-after-grace for security data.
- [ ] No DEFAULT (or default-occupancy alerts at rows>0 + never-ATTACH-while-populated).
- [ ] `lock_timeout` + `statement_timeout` on every DDL; DETACH CONCURRENTLY handled incl.
      pending/FINALIZE state.
- [ ] Maintenance runs on a dedicated direct connection; per-DB session advisory lock; release on
      all paths; scheduler dedup (`Forbid`).
- [ ] Heartbeat monitor pages on missed/failed runs.
- [ ] Coverage, default occupancy, oldest/newest partition age, per-partition vacuum/txid, orphaned
      detached partitions — monitored across all ~20 DBs.
- [ ] structure.sql/drift handling decided, documented, and CI-verified.
- [ ] Abort-before-DROP guard when coverage validation fails.
- [ ] Restore/PITR runbook accounts for resurrected "deleted" data (compliance).

---

## 8. Final Verdict

**Reject as written; the core idea is right but the execution is unsafe for auth/audit/
security/ceremony data.** Range partitioning for _retention by DROP_ is the correct pattern for
append-only time-keyed event logs. It is the wrong pattern for any table with a global uniqueness
invariant (tokens/sessions/credentials), and the proposal as specified will, in production: silently
miss runs, stall the write path during ATTACH/DROP, mis-bucket or early-delete evidence across the
JST/UTC boundary, defeat the schema-drift gate, and — worst — destroy security evidence irreversibly
on any retention or month-math error. Close C1–C6 and H1–H5 before any table is partitioned, and
split eligible (event-log) tables from ineligible (credential) tables explicitly.
