# Preference-Domain Audit Completion Plan (branch: develop)

Scope: finish the in-flight preference audit. C1/H1/M1 already fixed in the working tree — do not
redo. This plan covers regression tests for contract gaps, remaining fixes (M2, GET-edit, logout
downgrade decision), doc/memo updates, and verification.

Pre-work (before any code): read harness rules `.agents/harnesses/rules/generic/testing.mdc`,
`generic/controllers.mdc`, `generic/no-silent-fallback.mdc`, `project/regression-guards.mdc`,
`project/value-object-boundaries.mdc`, plus `docs/operations/db-workflow.md` (multi-DB migration
workflow) and `docs/architecture/preference-behavior-contract.md`.

---

## Phase 0 — Decision points (need user input before Phase 2)

1. **Logout downgrade (Security gap 3).** After logout, adopted personalized values
   (theme/language/tz etc.) remain in token-side preference records and public JS-readable cookies
   (`PreferenceCore#delete_preference_cookie` is a keep-values no-op by design). Options:
   - (a) Accept keep-values: document in contract + memo as an accepted shared-browser tradeoff;
     test asserts current behavior.
   - (b) Downgrade on logout: on sign-out, re-bootstrap a fresh token-side preference (new
     App/Com/OrgPreference row + cookie) so DB-adopted values do not persist. Touches logout flow +
     PreferenceCore; larger blast radius.
   - Recommendation: (a) for this audit, file (b) as backlog, since contract currently says keep and
     C1/H1/M1 scope was correctness-only. Test either way.
2. **GET /preference/\*/edit creates missing child row** (violates "no GET state change"; documented
   in `test/integration/preference_get_edit_current_behavior_test.rb`). Options:
   - (a) Fix: render defaults lazily on GET (build unsaved/default value), create row only on
     PATCH/update. Preferred — restores contract.
   - (b) Accept as idempotent bootstrap write; amend contract to carve out an exception.
   - Recommendation: (a).
3. **M2 migration approval.** Align `app_preferences.status_id` DB default (currently 2 =
   LEGACY_NOTHING) with model default (0 = NOTHING)? Requires a reversible `change_column_default`
   migration on the app_setting DB. Non-destructive but needs approval per constraints. Also: unify
   `persist_self_replacement` (`update!` in AppPreference vs `update_column` in Com/Org) — pick one
   style (recommend `update_column` with rubocop disable on all three, matching Com/Org, since it's
   a post-create self-reference backfill and validations already ran; or `update!` everywhere if
   validation coverage is desired). Needs user pick.
4. **Scope of L1/L2.** Recommend: L1 (dead `user_preference_colortheme` alias in
   `app/models/client_preference.rb:59`) — delete now if truly unreferenced (grep confirms only the
   definition; verify views/tests). L2 (denormalized column retirement) — out of scope, already
   covered by `plans/backlog/legacy-preference-models-retirement-plan.md`.
5. **Doc language.** Repo policy (English for committed docs/memos) vs user preference (Japanese).
   Default: English for committed files; confirm.

## Phase 1 — Regression tests first (Critical/High contract gaps)

All Minitest, integration level, representative surface = app edge/web, plus parity assertions
across com/org where cheap (follow pattern of
`test/controllers/base/edge_v0_cookies_controller_parity_test.rb` and
`test/integration/preference_surface_alignment_test.rb`).

New/extended test files (extend `test/integration/preference_security_test.rb` where it fits,
otherwise new files):

1. `test/integration/preference_corrupt_cookie_test.rb` — garbage/corrupt preference refresh cookie
   and access JWT: request succeeds (no raise), DB rows unchanged, a fresh preference is
   bootstrapped; assert no silent overwrite of existing DB state.
2. `test/integration/preference_signin_conflict_test.rb` — signed-in user + conflicting anonymous
   cookie values: DB (resource mirror) canonical wins per `PreferenceAdoption#adopt_preference_for!`
   newer-side rule; assert rendered values and dual-write outcome. Include the updated_at
   tie/ordering cases.
3. `test/integration/preference_logout_downgrade_test.rb` — after sign-out: auth transport cookies
   (`__Host-*`) cleared, public option cookies (ct/language/tz/...) persist, no next-user leak of
   resource-side data. Assertion set depends on Decision 1.
4. Extend `test/integration/preference_security_test.rb` — cross-surface inertness at HTTP level:
   app-issued preference cookie/JWT presented to com/org host is ignored (fresh bootstrap, no error,
   no state read).
5. `test/integration/preference_concurrent_sync_test.rb` — duplicate-canonical prevention: simulate
   login-sync racing a PATCH (two sequential requests emulating interleave; true parallelism is
   impractical in Minitest — assert idempotency/uniqueness invariants: unique jti/public_id indexes,
   `with_dual_write_transaction` leaves exactly one canonical row). Keep as invariant test, note
   limitation.
6. `test/integration/preference_read_symmetry_test.rb` — same option set renders identically
   anonymous (token side) vs signed-in (resource side) for a representative option (theme +
   language).

Risk note: run each new file immediately after writing; do not chase the 5 pre-existing failures
here (Phase 4).

## Phase 2 — Implementation fixes

### 2a. M2 (pending Decision 3)

- Migration: `db/app_settings_migrate/2026XXXX_change_app_preferences_status_id_default.rb` —
  `change_column_default :app_preferences, :status_id, from: 2, to: 0` (reversible via from/to).
  Follow `docs/operations/db-workflow.md` for the app_setting DB (structure.sql / initial_schemas
  regeneration per workflow). No data backfill (existing rows keep their status).
- Code: unify `persist_self_replacement` across `app/models/app_preference.rb` (:164),
  `app/models/com_preference.rb` (:153), `app/models/org_preference.rb` (:156) per chosen style.
  Add/extend model tests asserting replaced_by_id self-backfill and default status.
- Risk: default change affects only raw SQL inserts outside AR (model attribute default already 0);
  low. Verify no seed/fixture depends on default 2 (`grep status_id test/fixtures db/seeds.rb`).

### 2b. GET-edit fix (pending Decision 2, assuming option a)

- Locate the child-row-creating path: shared concern (`PreferenceCore` /
  `PreferenceWebCookieEndpoint` / `BasePreferenceScreenDispatch`) `edit` actions calling
  find_or_create-style helpers. Change edit/show to build a default in-memory value (`Model.new`
  with default option or plain default name) and move row creation into the update/PATCH path (which
  already dual-writes via `PreferenceResourceSync`).
- Update `test/integration/preference_get_edit_current_behavior_test.rb` to assert the NEW behavior
  (GET creates no rows) — rename to `preference_get_edit_no_state_change_test.rb` in spirit (keep
  filename change minimal if regression-guards rule prefers stable names).
- Check `preference_bootstrap_idempotency_test.rb` still passes: parent preference bootstrap on GET
  (cookie issuance) is a separate, contract-permitted concern — only child option rows must stop
  being created.
- Risk: views may assume a persisted record (form URLs, dom_id); keep changes in the shared concern
  so all surfaces move together; parity tests from Phase 1 guard this.

### 2c. Logout downgrade (pending Decision 1)

- Option (a): no code change; contract + memo wording only; Phase 1 test asserts keep-values
  explicitly with a comment referencing the contract section.
- Option (b): in sign-out flow, call a new `PreferenceCore#rebootstrap_preference!` that issues a
  fresh token-side row/cookie (reuse existing bootstrap path); do NOT touch resource-side rows.
  Update contract. Higher risk: every surface's logout, DBSC session binding, cookie parity tests.

### 2d. L1 (pending Decision 4)

- Remove `has_one :user_preference_colortheme` alias at `app/models/client_preference.rb:59` after
  grepping app/test/views for usage. No migration.

### 2e. Maintainability check (assess-only unless trivial)

- Sweep controllers under `app/controllers/*/edge/v0/` and web preference controllers for logic not
  delegated to shared concerns (diff against
  `PreferenceWebCookieEndpoint`/`PreferenceWebThemeEndpoint`). If divergence found, consolidate only
  if small; otherwise record in memo as backlog. No speculative refactor of PreferenceCore.

## Phase 3 — Documentation

1. `docs/architecture/preference-behavior-contract.md` (already git-modified): verify the
   state-transition table covers all 10 As-Is states requested; add rows for corrupt-cookie
   recovery, logout keep-vs-downgrade decision outcome, GET-edit no-state-change; keep English.
2. `memos/2026-07-02-preference-audit.md`: mark M2/L1 resolved (or deferred), record decisions 1–4
   with rationale, note L2 deferred to backlog plan, list the 5 pre-existing failures disposition.
3. Final audit report: `memos/2026-07-02-preference-audit-report.md` (dated flat file). Language per
   Decision 5 (default English). Contents: findings table (C1/H1/M1/M2/L1/L2 + GET-edit + logout),
   fixes, tests added, open items.

## Phase 4 — Pre-existing failures triage

5 failures on develop: `test/controllers/concerns/preference/adoption_test.rb` (2),
`jwt_and_color_theme_test.rb` (2), `no_implicit_callbacks_test.rb` (1). Triage after Phase 2: rerun;
classify each as (i) fixed incidentally by M2/GET-edit changes, (ii) genuinely broken assertion
worth a scoped fix, or (iii) out-of-scope — then either fix (small) or document in memo/report as
pre-existing with failure output. Do not let them block the audit deliverable.

## Phase 5 — Verification (narrowest first)

```
# per-fix
bin/rails test test/controllers/concerns/preference/web_cookie_endpoint_test.rb
bin/rails test test/controllers/base/edge_v0_cookies_controller_parity_test.rb
bin/rails test test/integration/preference_get_edit_current_behavior_test.rb
bin/rails test test/integration/preference_corrupt_cookie_test.rb \
               test/integration/preference_signin_conflict_test.rb \
               test/integration/preference_logout_downgrade_test.rb \
               test/integration/preference_concurrent_sync_test.rb \
               test/integration/preference_read_symmetry_test.rb
bin/rails test test/integration/preference_security_test.rb test/integration/preference_surface_alignment_test.rb test/integration/preference_bootstrap_idempotency_test.rb
bin/rails test test/models/app_preference_test.rb test/models/com_preference_test.rb test/models/org_preference_test.rb   # if present
# domain sweep
bin/rails test test/integration/ test/controllers/concerns/preference/
# migration round-trip (app_setting DB, per docs/operations/db-workflow.md)
bin/rails db:migrate && bin/rails db:rollback STEP=1 && bin/rails db:migrate   # scoped to app_settings per workflow doc
# full suite last; expect only the documented pre-existing failures (or their fixes)
bin/rails test
```

## Ordering summary

1. Read harness rules + db-workflow doc.
2. Get decisions 1–5 from user.
3. Phase 1 tests (red where they expose the GET-edit violation, green for already-fixed C1/H1/M1
   behavior).
4. Phase 2 fixes (M2 migration+model, GET-edit, L1, optional logout).
5. Phase 3 docs + report.
6. Phase 4 triage, Phase 5 verification.

### Critical Files for Implementation

- /home/global/workspace/app/controllers/concerns/preference_core.rb
- /home/global/workspace/app/controllers/concerns/preference_web_cookie_endpoint.rb
- /home/global/workspace/app/models/app_preference.rb (plus com/org_preference.rb — M2)
- /home/global/workspace/test/integration/preference_security_test.rb (pattern base for new tests)
- /home/global/workspace/docs/architecture/preference-behavior-contract.md
