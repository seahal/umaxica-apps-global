# Rails-Internal Lifecycle and FDW Active Record Contract Audit

## Context

The host-infrastructure audit (`plans/project-umaxica-linux-host-data-platform-and-network-sidecar-audit.md`)
already retired `pg_cron` as a candidate owner of application lifecycle deletion and confirmed
`RetentionPurgeJob` + SolidQueue as the sole lifecycle owner. That audit could not go deeper into
the Rails-internal implementation because it was scoped to host/container infrastructure. This
follow-up audit stays entirely inside the Rails app to establish, with evidence: what lifecycle
logic already exists, whether it is consistent and safe, what test/coverage gaps remain, and
whether the `docker/fdw-poc/` scaffold implies a safe, read-only Active Record contract worth
building later. It is investigation-only — no lifecycle code, migrations, or FDW containers are
touched. The deliverable is one English audit document plus a structured final report.

## Ground truth gathered during exploration (to reuse, not re-derive)

**Lifecycle/retention domain** (multi-database Rails app, no single `db/migrate`):
- `app/models/concerns/retainable.rb` — canonical `Retainable` concern (`discarded_at`/`purged_at`,
  sentinel `Float::INFINITY`, `REGISTRY` used by `RetentionPurgeJob`'s allowlist).
- `app/models/concerns/retention_hold_state.rb` — legal-hold state (`HOLD_KINDS`, `active_at` scope).
- `app/models/concerns/withdrawable.rb`, `withdrawal_flow.rb` — withdrawal/suspension/termination
  state machine built on `purged_at`.
- `app/models/concerns/privacy_request_state.rb`, `privacy_request_due_date.rb`,
  `processor_erasure_notification_state.rb` — GDPR/CCPA erasure flow.
- `app/jobs/retention_purge_job.rb` — ordered `RETAINABLE_MODELS` allowlist, set-based `delete_all`,
  legal-hold check before Client/Visitor purge, anonymization via `WithdrawalPersonalDataAnonymizer`,
  cross-DB purge via `RetentionCrossDatabaseChildPurge` for Operator.
- `app/services/retention_cross_database_child_purge.rb` — explicit ordered cross-database deletes,
  intentionally skips chronicle/audit tables.
- `config/recurring.yml` — `retention_purge` every 15 min; separate TTL-keyed purge jobs
  (`*_ceremony_transaction_purge_job.rb`, `dpop_proof_state_purge_job.rb`) keyed on `expires_at`,
  distinct from `Retainable`'s `purged_at` mechanism — worth flagging as a real terminology split.
- ADR: `adr/retainable-concern-and-retention-purge.md`.
- Tests already exist: `test/jobs/retention_purge_job_test.rb`,
  `test/jobs/retention_purge_legal_hold_test.rb`,
  `test/services/retention_cross_database_child_purge_test.rb`,
  `test/models/concerns/retainable_test.rb`, plus per-ceremony purge job tests and
  `test/security/invariants/*lifecycle*`.
- Migrations of interest: rename-to-`discarded_at`/`purged_at` migrations (2026-05-18) across all
  `*_migrate` dirs, retention-order CHECK constraints (`chk_*_retention_order`, some added
  `NOT VALID`), partial indexes on `purged_at` (`WHERE purged_at < 'infinity'`) only in
  `app_zenith`/`org_zenith`/`com_zenith` structure dumps — chronicle/occurrences/caches/queues/tickets
  DBs have the columns but no matching CHECK/index in their structure.sql, a candidate gap to verify.

**Database functions**: only 3–5 `CREATE FUNCTION ... RETURNS trigger` per zenith DB, all
cardinality-limit triggers (`check_user_identity_emails_limit()` etc.) — unrelated to retention. No
triggers/views/materialized views tied to lifecycle columns anywhere. Supports a "no new DB function
needed" default finding, pending Phase 3/4 confirmation against the actual query predicates.

**FDW PoC** (`docker/fdw-poc/`): Supabase Wrappers `s3_fdw` on Postgres 16 (not 17, since Wrappers'
PG17 support is unconfirmed), read-only, no PK on foreign tables, three formats
(csv/jsonl/parquet) via `smoke/run_smoke_checks.sql`. Never executed end-to-end per the host audit.
`docker/pg-cron-poc/` is confirmed infra-only, runs against the `db` bootstrap database, unrelated to
Rails lifecycle — do not reopen.

**Test/coverage/lint commands** (`vp test --coverage` does NOT exist — do not use it):
- `bin/rails test` (plain) or `COVERAGE=true bin/rails test test/` (SimpleCov, gate = 95% line via
  `.simplecov`, no branch minimum set).
- `bin/ci` / `config/ci.rb` is the authoritative local full-CI script.
- Lint: `bin/rubocop` (wraps `.rubocop.yml`), `bundle exec erb_lint --lint-all`.
- CI workflow: `.github/workflows/ci.yml` (`test-rails`, `coverage`, `lint-js`, `lint-ruby`,
  `security`, `gitleaks`, `codeql`, `dependencyreview` jobs).
- Confirmed gap: no dedicated test file for `app/models/publishing/entry.rb` /
  `app/services/publishing_entry_serializer.rb` (both currently modified in the working tree) —
  note but do not fix in this audit.

## Execution steps

1. **Baseline** — run `pwd`, `git rev-parse --show-toplevel`, `git remote -v`,
   `git branch --show-current`, `git status --short`, `git log -n 10 --oneline --decorate`. Then run
   `bin/rails test` once and `COVERAGE=true bin/rails test test/` once (not `vp test --coverage`).
   Record counts/failures/coverage/runtime and any incidental file changes (watch for
   `pnpm-lock.yaml` — leave untouched, just record if it moves).

2. **Lifecycle domain mapping** — using the concern/model/job/service list above, build the required
   lifecycle table (operation, trigger, owner, model, table, connection, physical DB, field,
   scheduling, legal-hold behavior, cross-DB behavior, idempotency, tests, gap). Explicitly separate
   the 6 categories requested (event-driven discard vs. scheduled purge vs. ceremony/TTL expiry vs.
   withdrawal/erasure vs. legal-retention purge vs. cache/session/token expiry) rather than merging
   them because they share timestamp shapes. Flag the `expires_at`-keyed ceremony purge jobs as a
   second, parallel lifecycle mechanism distinct from `Retainable`.

3. **DB function/migration audit** — confirm no lifecycle-tied trigger/view exists (only cardinality
   triggers do); check the retention-order CHECK constraints and `purged_at` partial indexes present
   in `app_zenith`/`org_zenith`/`com_zenith` against actual query predicates
   (`RetentionPurgeJob`, `RetentionHoldState#active_at`); check whether chronicle/occurrences/
   caches/queues/tickets DBs need equivalent indexes given their own purge queries, or whether they
   don't run comparable range scans. Do not create migrations.

4. **Model/query safety audit** — check whether `Retainable`'s intentional omission of a generic
   `.active`/`.deletable` scope (documented in-code) creates any leak risk through `unscoped`, raw
   SQL, joins, or associations; check `WithdrawalFlow#active`, `RetentionHoldState#active_at`,
   `Withdrawable#withdrawn` scopes for consistency; check serializers/controllers for admin bypass
   paths.

5. **Test/coverage/lint audit** — build the app/com/org × behavior matrix from the test files listed
   above; run only `bin/rails test test/jobs/retention_purge_job_test.rb` and the other
   already-identified lifecycle test files (not the full suite again); run `bin/rubocop` scoped to
   touched-area files if feasible, else full `bin/rubocop` since it's already a bounded repo command.
   Record the 95% line-coverage gate status from step 1's coverage run.

6. **FDW Active Record contract** — using the `smoke/run_smoke_checks.sql` shape (no PK, read-only,
   3 formats), write the recommended read-only model contract (`self.table_name`,
   `self.primary_key` strategy given no stable PK, `readonly?` override blocking
   save/update/destroy/touch, no callbacks/associations across DBs, explicit connection). State
   Rails-vs-infrastructure ownership split per the audit's stated default (infra creates
   extension/server/mapping/table; Rails only reads). Do not run or configure the PoC containers.

7. **Write the audit document** to
   `plans/project-umaxica-rails-lifecycle-and-fdw-active-record-contract-audit.md` (create new,
   since no equivalent file exists yet) following the 17-section structure the user specified
   (executive summary with READY/PARTIALLY READY/NOT READY/BLOCKED/NOT APPLICABLE verdicts per area,
   scope/safety statement, baseline, lifecycle architecture diagram, domain-rule matrix, DB/connection
   matrix, DB-function/migration findings, model/query findings, test matrix, coverage/lint findings,
   FDW SQL contract summary, Active Record FDW contract, FDW migration/schema strategy, FDW test
   strategy, findings ranked by severity, recommended future phases C-1..C-4 stated but not executed,
   no-change conclusion where applicable).

8. **Final response** — answer the 14 required items (document path, verdict table, top 5 findings,
   correctness-gap verdict, DB-function-justified verdict, migration/index verdict, missing tests,
   coverage numbers, lint result, FDW contract recommendation, Rails-vs-infra split, exact files
   changed, `git status --short`, focused diff of the one new/updated document) plus the explicit
   safety confirmations (no podman/host commands, no extension created, no scheduler added,
   `RetentionPurgeJob`/SolidQueue untouched, `docker/fdw-poc/` read-only, no dependency installs,
   `pnpm-lock.yaml` untouched, no commit/push).

## Verification

- `bin/rails test` and `COVERAGE=true bin/rails test test/` run once each in Phase 1 only.
- Targeted lifecycle test files run once in Phase 5, not the full suite again.
- `bin/rubocop` run once in Phase 6.
- No writes anywhere except the single new audit document under `plans/`.
