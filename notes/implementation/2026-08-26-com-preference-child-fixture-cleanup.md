# Com Preference Child Fixture Cleanup Implementation Notes

## Context

- Original plan/spec: none. Task was "run `bin/rails test`", which surfaced 249 errors.
- Related decisions/docs/plans: `test/support/parallel_test_database_cloner.rb` (clone rebuild
  policy), `test/fixtures/app_preference_*.yml` (reference state for a complete surface).
- Implementation date: 2026-08-26

## Problem

`bin/rails test` reported `10293 runs, 0 failures, 249 errors`. Every error was the same
`RuntimeError` raised from `ActiveRecord::FixtureSet.check_all_foreign_keys_valid!` during
`before_setup`, not from any test body:

```
PG::ForeignKeyViolation: insert or update on table "com_preference_motions"
  violates foreign key constraint "fk_rails_88bbe39690"
DETAIL: Key (preference_id)=(980190966) is not present in table "com_preferences".
```

`test_com_setting_db_9` held one orphan `com_preference_motions` row. Its `preference_id` was not a
fixture identifier (`ActiveRecord::FixtureSet.identify("one")` is `980190962`); it was a value from
the `com_preferences` sequence after fixtures reset it, so the parent was a record some test
created. Once that clone was poisoned, every test that parallel worker 9 picked up failed in fixture
setup, which is why the error count was large and the failure count was zero.

Two properties combined to make it persist:

- `com_preference_motions` had no fixture file, so fixture loading never deleted its rows, while
  `com_preferences` (a fixture table) was deleted and reinserted. Fixture insertion runs inside
  `disable_referential_integrity`, so deleting the parent left the child behind instead of erroring.
- `ParallelTestDatabaseCloner` rebuilds worker clones only when the schema SHA changes
  (`test/support/parallel_test_database_cloner.rb:44-51`), so the orphan survived across runs.

## Decisions Made During Implementation

- Decision: add empty fixture files for every `com_preferences` child value table that lacked one
  (`adult_content_gates`, `currencies`, `date_formats`, `densities`, `motions`, `page_sizes`,
  `time_formats`), plus `org_preference_adult_content_gates`.
  - Why: `app` already has a fixture file for all twelve of its child value tables, and
    `test/fixtures/org_preference_motions.yml` states the reason in its own comment — an empty
    fixture keeps the table under fixture cleanup. `com` was the incomplete surface. Fixing only
    `com_preference_motions` would leave six sibling tables hanging off the same parent record with
    the identical defect.
  - Alternatives considered: (a) delete the orphan row only — restores green but the leak recurs;
    (b) make the cloner detect data pollution — its own comment rejects per-clone data scans on cost
    grounds, and it would paper over the leak rather than clean it.
  - Follow-up needed: the write that committed a `ComPreferenceMotion` outside its test transaction
    was not identified. `client`, `operator`, and `visitor` have the same gap across their whole
    preference family; `visitor` additionally has no `visitor_preferences.yml`, so its children have
    no fixture-managed parent to orphan from.

- Decision: delete the existing orphan row from `test_com_setting_db_9` directly.
  - Why: the new empty fixture removes it on the next fixture load anyway, but the clone is not
    rebuilt on this change (schema SHA is unchanged), so clearing it made the verifying run measure
    the fixture change rather than a cleanup side effect.
  - Alternatives considered: dropping the clone and letting it re-template; unnecessary once the
    fixture file exists.

## Deviations From Plan

- Change: reverted an unrelated `pnpm-lock.yaml` modification that appeared during the test runs.
  - Why: it was not part of this task and was not present when the session started.
  - Risk: none to this change, but see the follow-up below — it comes back on every test run.
  - Follow-up: the uncommitted `test/test_helper.rb` Vite build step invokes pnpm during test boot,
    and `pnpm exec` (pnpm 11.22.0) rewrites `pnpm-lock.yaml`, dropping the `vite` and `vitest`
    catalog entries and inlining their specifiers. Reproduced standalone with
    `pnpm exec vite build --mode test`, so it is a lockfile/`pnpm-workspace.yaml` `overrides`
    inconsistency surfaced by the new pnpm invocation, not caused by it. `bin/rails test` currently
    dirties a tracked file on every run. Needs a decision: regenerate and commit the lock, or stop
    routing the test build through `pnpm exec`.

## Review Notes

- Tests run: `bin/rails test` (full suite, 12 parallel workers) —
  `10293 runs, 58501 assertions, 0 failures, 0 errors, 1 skips`, exit 0. Also
  `bin/rails test test/services/sign_up_session_state_test.rb` (14 runs, 0 failures) as a targeted
  check that the new fixture files load.
- Tests not run: `pnpm test`. No JavaScript changed.
- Documentation promotion needed: none. The rationale for empty fixtures already lives in the
  fixture files' own comments.
