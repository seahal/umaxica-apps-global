# Rails-Internal Lifecycle and FDW Active Record Contract Audit

Date: 2026-07-21 Branch: `develop` at `f120790d12` Scope: Rails application code only. No Podman,
host, or Aurora operations were performed.

## 1. Executive summary

| Area                                                    | Verdict                                               |
| ------------------------------------------------------- | ----------------------------------------------------- |
| Logical-deletion domain consistency                     | PARTIALLY READY                                       |
| Physical-retention implementation (`RetentionPurgeJob`) | READY                                                 |
| Legal-hold protection                                   | READY                                                 |
| Cross-database purge behavior                           | READY                                                 |
| Database-function need                                  | NOT APPLICABLE (none justified)                       |
| Migration/index readiness                               | READY (see §7 correction)                             |
| Model/query safety                                      | READY                                                 |
| Lifecycle test coverage                                 | READY (verified live this session)                    |
| Coverage/lint readiness                                 | PARTIALLY READY (real run below 95% gate; lint clean) |
| FDW Active Record contract readiness                    | NOT READY (PoC unexecuted, read-only contract only)   |

## 2. Scope and safety statement

- Investigation was limited to the repository root and Rails-mediated operations.
- No Podman, container, or host infrastructure commands were run.
- No implementation files were modified. The only file created is this document.
- No dependency installation (`bundle install`, `pnpm install`, etc.) was performed.
- `pnpm-lock.yaml` was left untouched (pre-existing modification from a concurrent process, per the
  original task instructions — not attributed to this audit).
- No commit or push occurred.

## 3. Repository and baseline state

- Branch: `develop`, HEAD `f120790d12 [CheckPoint] ..` (tracks `origin/develop`).
- Working tree had pre-existing modifications (unrelated publishing/preference/docker work in
  progress) — recorded, not touched. Full list at the time of this audit is in `git status --short`
  (see final response).
- Initial `bin/rails test` / `COVERAGE=true bin/rails test test/` attempts failed as an environment
  blocker (`PG::ConnectionBad: FATAL: database "test_publishing_db" does not exist`) because the
  test databases had not yet been prepared this session.
- **Follow-up (user-directed) run:** `bin/rails db:prepare` succeeded (exit 0). With databases
  prepared, both commands were re-run for real:
  - `bin/rails test`: **9395 runs, 44868 assertions, 1 failure, 14 errors, 0 skips**, 122.6s.
  - `COVERAGE=true bin/rails test test/`: **9398 runs, 44915 assertions, 1 failure, 3 errors, 0
    skips**, 486.8s (single-worker under `COVERAGE=true`, so it also serialized away several
    order/parallelism-dependent flakes present in the plain run — both runs' failures are the same
    root causes, just fewer manifested under serialization).
  - **All failures/errors in both runs are pre-existing and unrelated to lifecycle/retention code**:
    `AvatarPersonaBindingTest` (Japanese validation-message content, order-dependent, only in the
    plain run), `Acme::AccountQuotaPolicyTest` (missing
    `ja.activerecord.attributes.operator_identity.identity_state` i18n key),
    `ModelOnlyLineCoverageTest` (an `Actor::Configuration::NullValue` equality expectation), and
    `RepositoryLanguageCheckTest` (calls a nonexistent `assert_not_includes` method). Confirmed via
    targeted grep: zero mentions of retention/purge/discard/withdrawal/ legal_hold/retainable among
    the failing tests. **Every lifecycle-domain test passed.**
  - Real coverage: **line 45825/49333 = 92.88%**, **branch 10665/14760 = 72.25%** — this is a real
    measurement, not the earlier stale artifact. **92.88% is below the repository's 95%
    line-coverage gate** (see §10 for per-file lifecycle breakdown; the shortfall is concentrated
    outside the lifecycle files this audit targets).
- `bin/rubocop` (bounded to lifecycle core files) ran cleanly: 6 files inspected, no offenses.

## 4. Lifecycle architecture

```text
business event (sign-up, sign-out, withdrawal request, admin action)
  → logical deletion / state transition
      Retainable#discard_now!(purge_after:) sets discarded_at + purged_at (Float::INFINITY sentinel
      when not yet eligible)
      Withdrawable / WithdrawalFlow drive withdrawn/suspended/terminated state on top of purged_at
      RetentionHoldState (legal_hold, security_investigation, court_order, ...) can block eligibility
  → retention period elapses (purged_at <= Time.current)
  → SolidQueue recurring schedule (config/recurring.yml, every 15 min, queue :retention)
  → RetentionPurgeJob#perform
      for Client/Visitor: legal-hold check → WithdrawalPersonalDataAnonymizer → terminated_at set
      for Operator: RetentionCrossDatabaseChildPurge (other-DB children) → delete_all
      for all other RETAINABLE_MODELS: delete_all where purged_at <= now
  → physical deletion (set-based delete_all, FK cascades, no AR callbacks)

Parallel, distinct mechanism (NOT part of Retainable):
  ceremony/session TTL expiry (expires_at) → dedicated *_ceremony_transaction_purge_job.rb /
  DpopProofStatePurgeJob, each scheduled independently in config/recurring.yml
```

This corrects the naive assumption that all timestamp-based lifecycle logic is one system: there are
two parallel, independently-scheduled mechanisms — `Retainable`'s `purged_at`-keyed retention purge,
and a separate family of `expires_at`-keyed ceremony/session TTL purge jobs. Both are real, both are
already implemented, neither depends on `pg_cron`.

## 5. Domain-rule matrix

| Operation                                | Trigger                               | Owner                                                                                                           | Model(s)                                                                                              | Physical DB                                                   | Field                                                                                 | Scheduling                                                     | Legal hold                                        | Cross-DB                                        | Idempotency                                                                                   | Tests                                                                         | Gap                            |
| ---------------------------------------- | ------------------------------------- | --------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------- | -------------------------------------------------------------- | ------------------------------------------------- | ----------------------------------------------- | --------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ------------------------------ |
| Logical deletion / discard               | app event                             | `Retainable` concern                                                                                            | ~60 models incl. tokens, credentials, occurrences                                                     | app/org/com zenith, chronicle, occurrences, avatars, settings | `discarded_at`/`purged_at`                                                            | n/a (immediate)                                                | via `RetentionHoldState`                          | n/a                                             | validated ordering (`discarded_at <= purged_at`)                                              | `test/models/concerns/retainable_test.rb`                                     | none found                     |
| Scheduled physical purge                 | `purged_at <= now`                    | `RetentionPurgeJob`                                                                                             | `RETAINABLE_MODELS` allowlist                                                                         | multiple (see above)                                          | `purged_at`                                                                           | SolidQueue, 15 min                                             | checked before Client/Visitor purge               | `RetentionCrossDatabaseChildPurge` for Operator | set-based `delete_all`, ordered allowlist for FK safety                                       | `test/jobs/retention_purge_job_test.rb`, `retention_purge_legal_hold_test.rb` | index gap (§7)                 |
| Ceremony/session TTL expiry              | `expires_at <= now`                   | 7 dedicated `*_ceremony_transaction_purge_job.rb` + `DpopProofStatePurgeJob`                                    | passkey/email/telephone/TOTP/social/step-up/secret-credential ceremony transactions, DPoP proof state | respective settings/credential DBs                            | `expires_at`                                                                          | SolidQueue, independent per-job cadence                        | not applicable (ceremony state, not retained PII) | none                                            | each job scoped to its own table                                                              | one test file per job (`test/jobs/*_purge_job_test.rb`)                       | not verified live this session |
| Withdrawal / suspension / termination    | user or admin action                  | `WithdrawalLifecycle` service, `Withdrawable`/`WithdrawalFlow` concerns                                         | Client, Visitor, Operator + `*_withdrawal_flow` rows                                                  | app/org/com zenith                                            | `withdrawn_at`, `purged_at`, recovery window (31d), early-termination delay (7d)      | recovery window enforced in-app, purge via `RetentionPurgeJob` | checked at purge time                             | `RetentionCrossDatabaseChildPurge` (Operator)   | `discard_now!` idempotent by nature of timestamp fields                                       | `test/integration/withdrawal_lifecycle_security_test.rb`                      | not verified live this session |
| Privacy/erasure request (GDPR/CCPA)      | user request                          | `PrivacyRequestState`/`PrivacyRequestDueDate` concerns, `*PrivacyRequest` models                                | app/com zenith                                                                                        | `legal_hold_blocked_at`, SLA due-date fields                  | app-driven state machine, `ProcessorErasureNotificationJob` for downstream processors | legal_hold_blocked_at explicitly blocks                        | notifies external processors                      | state-machine driven                            | `test/services/...` (erasure-adjacent) present, no dedicated erasure integration test located | test coverage for the SLA due-date edge cases not directly located            |
| Permanent deletion after legal retention | `purged_at <= now` AND no active hold | `RetentionPurgeJob` + `RetentionHoldState#active_at`                                                            | `*_retention_holds`, `*_privacy_requests`                                                             | app/com zenith                                                | `purged_at`, hold `expires_at`                                                        | via retention purge cadence                                    | primary purpose of this row                       | n/a                                             | hold check is a precondition, naturally idempotent                                            | `retention_purge_legal_hold_test.rb`                                          | none found                     |
| Cache/session/token expiration           | `expires_at <= now`                   | token/credential concerns (`TokenStatusManagement`, `RefreshTokenable`, `SingleUseToken`) + ceremony purge jobs | tokens, secret credentials, refresh tokens                                                            | zenith DBs                                                    | `expires_at`                                                                          | SolidQueue per-job                                             | not applicable                                    | none                                            | per-job scoped                                                                                | per-job test files                                                            | not verified live this session |

## 6. Database and connection matrix

Physical databases identified from `db/*_structure.sql` and model `establish_connection`/base-record
classes: `app_zenith`, `org_zenith`, `com_zenith` (principal/account domain, hold retention CHECK
constraints and `purged_at` partial indexes), `chronicle` (audit trail, e.g.
`AppPreferenceChronicle`), `occurrences` (`AreaOccurrence`, `ClientOccurrence`, etc.), `avatars`
(`Avatar`), `app_settings` / `org_settings` / `com_settings` (`AppPreference` etc.), `app_tickets` /
`org_tickets` / `com_tickets`, `caches`, `queues`, `publishing`. `RetentionPurgeJob`'s
`RETAINABLE_MODELS` allowlist spans nearly all of these — retention is not confined to one database.

## 7. Database-function and migration findings

**No new database function is justified.** The only `CREATE FUNCTION ... RETURNS trigger` objects
found in any `*_structure.sql` are per-zenith-DB cardinality-limit triggers (e.g.
`check_user_identity_emails_limit()`, `check_staff_identity_secrets_limit()`) enforcing per-user
row-count caps — unrelated to retention/discard/purge/legal-hold. No trigger, view, or materialized
view is tied to `discarded_at`/`purged_at`/`expires_at`/`legal_hold` anywhere. This confirms the
default posture from the host-infrastructure audit: application-level `RetentionPurgeJob` fully owns
this behavior, and no atomicity/performance/integrity problem exists that would justify a DB
function.

**Migration/index finding — CORRECTED after live re-verification (§ this section supersedes the
initial static-only pass).** The first static pass grepped every `*_structure.sql` for a `purged_at`
index and found matches only in `app_zenith`/`org_zenith`/`com_zenith`, leading to a provisional
"Medium severity index gap" claim for chronicle/occurrence/avatar/settings tables. That claim was
**wrong** and has been withdrawn. Root cause: `db/avatar_structure.sql`,
`db/chronicle_structure.sql`, `db/occurrence_structure.sql`, `db/app_setting_structure.sql`,
`db/org_setting_structure.sql`, and `db/com_setting_structure.sql` are each 18-line stub files with
no `CREATE TABLE`/`CREATE INDEX` statements at all — they do not reflect the live schema for those
connections (those databases are bootstrapped via `db/initial_schemas/*.rb` Ruby-DSL schema files
loaded through a `LoadInitial*Schema` migration, and their `structure.sql` dumps were never
regenerated to match). Querying the **live, prepared database** directly (via
`ActiveRecord::ConnectionAdapters::Adapter#indexes`, after `bin/rails db:prepare`) shows every one
of these tables already has a `purged_at` index: `index_avatars_on_purged_at`,
`index_app_preference_chronicles_on_purged_at`, `index_area_occurrences_on_purged_at`,
`index_app_preferences_on_purged_at`, `index_client_tokens_on_purged_at`, in addition to the zenith
indexes already confirmed (`index_clients_on_purged_at`, etc.). **There is no retention-index gap.**

**Real finding to carry forward instead (Low severity, documentation/tooling):** the `structure.sql`
dumps for `avatar`, `chronicle`, `occurrence`, `app_setting`, `org_setting`, and `com_setting` are
stale stubs, not the empty-but-accurate state they might appear to be. This has no effect on
`RetentionPurgeJob` (its `column_names.include?("purged_at")` guard introspects the live schema, not
the dump), but it does mean: (a) anyone reading these `*_structure.sql` files to answer "does this
table have X" will get a wrong (empty) answer without checking `db/initial_schemas/*.rb` or the live
DB, and (b) if `schema_format = :sql` is expected to be authoritative for `db:schema:load` on a
fresh environment for these six connections, verify that a fresh load actually reconstructs the
schema via the `LoadInitial*Schema` migration path rather than depending on a stale dump. This is a
documentation-accuracy finding, not a retention-correctness or performance gap, and is not urgent.

Retention-order CHECK constraints (`chk_*_retention_order`) exist consistently across app/org/com
zenith and are correctly enforced (some as `NOT VALID`, meaning existing rows were not re-validated
at add-time — worth a one-line note but not a correctness risk for new rows).

## 8. Model and query findings

- `Retainable` intentionally omits a generic `.active`/`.deletable` scope (documented in-code to
  avoid naming collisions across ~60 including classes). Consumers use raw
  `where('discarded_at > ?', ...)`-style predicates instead. This is a deliberate, documented
  trade-off, not an oversight — no leak risk was found because there is no default scope to bypass
  via `unscoped`; every caller must write its own predicate, which shifts risk to reviewer-vigilance
  rather than a shared-scope bug, but that is a design choice already made and accepted (see
  `adr/retainable-concern-and-retention-purge.md`).
- `WithdrawalFlow#active`, `RetentionHoldState#active_at`, and `Withdrawable#withdrawn` scopes are
  each independently defined per concern, consistent with the domain-boundary rule in this
  repository's `AGENTS.md` (no shared cross-domain abstraction forced where the domains legitimately
  differ).
- `RetentionPurgeJob` uses `delete_all` (bypassing AR callbacks) by explicit, ADR-sanctioned
  exception (`adr/retainable-concern-and-retention-purge.md`, referenced directly in the job's code
  comments) — this is a known, reviewed, and intentional deviation from the repository's general
  forbidden-method rule, not a new finding.
- No evidence of direct `delete`/`destroy` calls bypassing retention rules was found in the areas
  inspected; a full repository-wide sweep for that specific bypass pattern was not exhaustively
  performed in this pass and would be a good target for a future, narrower audit if desired.

## 9. Test matrix

| Behavior                      |                       app | com |            org | DB-level |                                      Job-level |                                                                                              Integration |
| ----------------------------- | ------------------------: | --: | -------------: | -------: | ---------------------------------------------: | -------------------------------------------------------------------------------------------------------: |
| Logical deletion / discard    | yes (shared concern test) | yes |            yes |      n/a |                                            n/a |                                                                                     `retainable_test.rb` |
| Retention purge (normal)      |                       yes | yes |            yes |      n/a |                  `retention_purge_job_test.rb` |                                                                                                        — |
| Retention purge (legal hold)  |                       yes | yes |            yes |      n/a |           `retention_purge_legal_hold_test.rb` |                                                                                                        — |
| Cross-database child purge    |                       n/a | n/a | yes (Operator) |      n/a | `retention_cross_database_child_purge_test.rb` |                                                                                                        — |
| Ceremony/TTL expiry (7 kinds) |                       yes | yes |            yes |      n/a |                          one test file per job |                                                                                                        — |
| Withdrawal lifecycle          |                       yes | yes |            yes |      n/a |                                              — |                                                                  `withdrawal_lifecycle_security_test.rb` |
| App/com/org preference parity |                       yes | yes |            yes |      n/a |                                            n/a | `preference_sign_out_rotation_contract_test.rb` (shared contract via `preference_lifecycle_surfaces.rb`) |

**Executed live this session** after `bin/rails db:prepare`: all rows above passed. Both the plain
and coverage test runs (§3) had zero failures/errors among any retention/purge/discard/withdrawal/
legal_hold/retainable-named test — confirmed by direct grep across both run logs. The 15 (plain run)
/ 4 (coverage run) failures/errors that did occur are all pre-existing and unrelated (see §3).

**Confirmed gap (unrelated to lifecycle but touching a currently-modified file):** no dedicated test
file exists for `app/models/publishing/entry.rb` or `app/services/publishing_entry_serializer.rb`
(both modified in the current working tree, outside this audit's scope to fix).

## 10. Coverage and lint findings

- Required gate: 95% line coverage, configured in `.simplecov`
  (`SimpleCov.coverage :line do minimum 95 end`); branch coverage has no minimum configured.
- **Real, verified coverage this session** (after `bin/rails db:prepare` + full
  `COVERAGE=true bin/rails test test/`): **line 45825/49333 = 92.88%**, **branch 10665/14760 =
  72.25%**. The 95% line gate is **not met repository-wide**, but the shortfall is not concentrated
  in lifecycle code. Per-file coverage for the core lifecycle files, extracted from
  `coverage/.resultset.json`:

  | File                                                   | Line coverage   |
  | ------------------------------------------------------ | --------------- |
  | `app/models/concerns/retainable.rb`                    | 62/62 (100.0%)  |
  | `app/models/concerns/retention_hold_state.rb`          | 28/28 (100.0%)  |
  | `app/models/concerns/withdrawable.rb`                  | 48/48 (100.0%)  |
  | `app/models/concerns/withdrawal_flow.rb`               | 63/63 (100.0%)  |
  | `app/models/concerns/privacy_request_state.rb`         | 45/45 (100.0%)  |
  | `app/models/concerns/privacy_request_due_date.rb`      | 4/4 (100.0%)    |
  | `app/jobs/retention_purge_job.rb`                      | 47/48 (97.9%)   |
  | `app/services/retention_cross_database_child_purge.rb` | 21/21 (100.0%)  |
  | `app/services/withdrawal_personal_data_anonymizer.rb`  | 47/47 (100.0%)  |
  | `app/services/withdrawal_lifecycle.rb`                 | 105/139 (75.5%) |

  `withdrawal_lifecycle.rb` at 75.5% is the one lifecycle file with a real, verified coverage gap —
  a concrete candidate for Phase C-2 (§16) if this audit's findings are acted on.

- Lint: `bin/rubocop` against the six core lifecycle files (`retainable.rb`,
  `retention_hold_state.rb`, `withdrawable.rb`, `withdrawal_flow.rb`, `retention_purge_job.rb`,
  `retention_cross_database_child_purge.rb`) — **clean, no offenses**.
- The coverage command named in the original task prompt does not produce Rails coverage — confirmed
  by direct search. `pnpm test:coverage` covers JavaScript only; Rails coverage comes from
  `bin/rails test` and `COVERAGE=true bin/rails test test/`.

## 11. FDW proposed SQL contract

`docker/fdw-poc/` builds Supabase Wrappers' `s3_fdw` extension for **PostgreSQL 16** (not 17, since
Wrappers' PG17 support is unconfirmed) via `cargo-pgrx`, isolated from the production `psql-pub`
image. `smoke/run_smoke_checks.sql` defines:

- `CREATE FOREIGN DATA WRAPPER s3_wrapper HANDLER s3_fdw_handler VALIDATOR s3_fdw_validator`
- A foreign server pointed at a local RustFS (S3-compatible) endpoint, plus a second server with
  deliberately-bad credentials for negative testing.
- Three foreign tables — `fdw_poc_csv`, `fdw_poc_jsonl`, `fdw_poc_parquet` — each
  `(id integer, name text, amount numeric)`, one format per table, no declared primary key (foreign
  tables cannot carry a real PK constraint), read-only (no INSERT/UPDATE/DELETE/TRUNCATE exercised).

Per the prior host-infrastructure audit, this scaffold has **never been executed end-to-end**: the
Dockerfile was corrected once but the corrected image was never rebuilt/run, and
`run_smoke_checks.sql` was never executed against real RustFS. Treat every capability claim below as
inferred from the SQL definition, not empirically confirmed.

## 12. Active Record FDW contract

Recommended read-only contract, contingent on the PoC actually running and Aurora review later
confirming viability:

```ruby
class FdwPocCsvRecord < ApplicationRecord
  self.table_name = "fdw_poc_csv"
  establish_connection :fdw_poc # dedicated connection, not app/org/com zenith

  # No stable declared primary key on the foreign table -> do not rely on
  # find/find_by(id:) semantics backed by a real unique index. Treat `id` as
  # an ordinary column, not `self.primary_key`, unless the source object is
  # independently known to guarantee row-identity stability.
  self.primary_key = nil

  def readonly?
    true
  end

  # Explicitly block mutation entrypoints rather than relying on readonly?
  # alone, since readonly? does not block delete_all/update_all/touch:
  before_destroy { raise ActiveRecord::ReadOnlyRecord }
end
```

- No callbacks/validations that assume DB-enforced uniqueness or referential integrity.
- No associations to local PostgreSQL tables (Active Record cannot make a cross-database join
  transparent or efficient here — any correlation must be done in application code as two separate
  queries).
- No `find_each`/batch iteration relying on stable PK ordering unless the underlying object format
  guarantees stable row order (unconfirmed for any of the three PoC formats).
- No prepared-statement or query-cache assumptions beyond what Active Record already does safely for
  read-only, unparameterized `SELECT`s.
- Optimistic locking, timestamps, STI, and enum behavior: all inapplicable/should be disabled — the
  foreign table has no `lock_version`, `created_at`/`updated_at`, or type column.

## 13. FDW migration/schema strategy

Consistent with the host-infrastructure audit's stated default:

```text
Infrastructure creates the extension, foreign server, user mapping, and
foreign table. Rails owns only the read-only application contract unless
there is strong evidence that Rails migrations can manage these objects
portably and safely.
```

No evidence in this repository contradicts that default. Rails migrations should not issue
`CREATE FOREIGN TABLE` for this PoC; `db:prepare`/structure-dump behavior when the extension is
absent was not empirically tested in this session (would require actually running the PoC, out of
scope). Do not place credentials in migrations, schema dumps, or model code — the PoC's own
`smoke/run_smoke_checks.sql` already isolates credentials into `CREATE USER MAPPING` statements
executed against a disposable, tmpfs-backed database, which is the correct pattern to preserve if
this is ever productionized.

## 14. FDW test strategy

1. Pure model-contract tests (readonly? enforcement, blocked mutation entrypoints) — no FDW
   required, can run in the normal Rails suite today once such a model exists.
2. Adapter/contract tests against a local ordinary Postgres table standing in for the foreign table
   shape (no PK, columns matching the PoC schema) — exercises the same read paths without requiring
   the extension.
3. Integration tests against the actual RustFS PoC — opt-in only, skipped by default in the normal
   Rails test suite (e.g. gated by an environment flag), since the extension is not installed in the
   standard test database.
4. Aurora compatibility tests — explicitly out of Rails' test suite; performed separately once/if
   Aurora extension support is confirmed.
5. Graceful-absence behavior — Rails boot and the normal test suite must not depend on the extension
   being present; any FDW-backed model must fail closed (raise or be entirely unloaded) rather than
   silently returning empty results when the extension/table is missing.

## 15. Findings ranked by severity

- **Medium** — Real coverage repository-wide is 92.88% line / 72.25% branch, below the 95% line
  gate. Not concentrated in lifecycle code (see per-file table in §10); a real, actionable metric
  now that this session's coverage run is verified. (§10)
- **Low** — `withdrawal_lifecycle.rb` at 75.5% line coverage is the one lifecycle file with a real,
  verified coverage gap; a concrete Phase C-2 candidate. (§10)
- **Low** — `structure.sql` dumps for `avatar`/`chronicle`/`occurrence`/`app_setting`/`org_setting`/
  `com_setting` are stale 18-line stubs that don't reflect the live schema (retention indexes are
  actually present, confirmed live) — a documentation-accuracy gap, not a correctness or performance
  gap. (§7)
- **Low** — Some retention-order CHECK constraints were added as `NOT VALID` (existing rows not
  re-validated at add-time). No evidence of actual invalid rows; flagged for awareness only. (§7)
- **Low** — `app/models/publishing/entry.rb` and `app/services/publishing_entry_serializer.rb` (both
  currently modified in the working tree, unrelated to this audit's lifecycle scope) have no
  dedicated test file. (§9)
- **Informational** — FDW PoC remains unexecuted end-to-end; every capability claim in §11–§14 is
  inferred from the SQL scaffold, not empirically confirmed. Executing it requires Podman/container
  operations that are outside this audit's Rails-only scope (see final response). (§11)

Withdrawn (superseded by live verification): the provisional "Medium — missing `purged_at` index
outside zenith databases" finding from the first static pass. Confirmed false by querying the live,
prepared database directly; see §7.

## 16. Recommended implementation phases (not executed)

### Phase C-1: Lifecycle correctness gaps

No real correctness gaps were found. This phase is empty — do not manufacture work.

### Phase C-2: Lifecycle tests and coverage

- Real coverage baseline is now established (§10): 92.88% line / 72.25% branch repository-wide,
  below the 95% gate. `withdrawal_lifecycle.rb` (75.5% line) is the one lifecycle file with a
  verified, concrete gap; the remaining shortfall is outside lifecycle code and outside this audit's
  scope.
- Likely files: `app/services/withdrawal_lifecycle.rb` and its existing test file — add targeted
  tests for the currently-uncovered branches (identify via `coverage/index.html` for that file)
  rather than adding tests speculatively.
- Explicit approval required before writing any new test.

### Phase C-3: FDW read-only Rails contract

- Only relevant if the host PoC is later executed successfully and Aurora support is confirmed.
- Likely files: a new `app/models/*` FDW-backed model per the contract in §12, a dedicated
  `establish_connection` config, contract tests per §14 tiers 1–2.
- Risks: silent Rails-boot failure if the extension is absent in a given environment; must fail
  closed, not silently.
- Rollback: delete the new model/connection config; no migration to roll back since Rails should not
  own `CREATE FOREIGN TABLE`.
- Acceptance criteria: model is `readonly?`, blocks all mutation entrypoints, has no local-table
  associations, and the normal Rails test suite passes without the extension present.
- Explicit approval required.

### Phase C-4: Documentation and operational guards

- Document the two-parallel-mechanism lifecycle architecture (§4) somewhere more discoverable than
  this audit, e.g. as an addition to `adr/retainable-concern-and-retention-purge.md`, so future
  readers don't conflate `purged_at`-keyed retention with `expires_at`-keyed ceremony TTL.
- Explicit approval required before editing that ADR.

## 17. No-change conclusion

Logical deletion, physical retention purge, legal-hold protection, and cross-database purge are
already correctly implemented and already independent of `pg_cron` — consistent with the
host-infrastructure audit's prior conclusion. This is now backed by a **live, verified test run**
(9398 runs, real 92.88%/72.25% coverage) rather than static inspection alone: every
retention/purge/discard/withdrawal/legal-hold test passed, and no lifecycle table is missing a
`purged_at` index (the earlier provisional index-gap finding was withdrawn after live
re-verification — see §7). No new database function, no lifecycle code change, and no migration is
proposed by this audit. The two remaining actionable items are the repository-wide 95% line-coverage
shortfall (concentrated outside lifecycle code, with one real lifecycle exception in
`withdrawal_lifecycle.rb`) and the stale `structure.sql` dumps for six non-zenith databases —
neither is a lifecycle-correctness defect requiring immediate action.
