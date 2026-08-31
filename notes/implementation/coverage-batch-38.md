# Coverage Batch 38 Implementation Notes

## Context

- Original plan/spec: raise `bin/rails test` line coverage and drive failures/errors to zero.
- Related decisions/docs/plans: `notes/implementation/coverage-batch-37.md`,
  `docs/operations/development-credential-provisioning.md`, `adr/unified-enforcement.md`.
- Implementation date: 2026-08-30.

## Coverage

- Starting Rails line coverage: 50,830 / 54,028 (94.0808%).
- Ending Rails line coverage: 51,410 / 53,783 (95.5896%). Delta +1.509 points.
- Starting branch coverage: 11,850 / 15,953 (74.2807%).
- Ending branch coverage: 12,092 / 15,885 (76.1221%). Delta +1.841 points.
- 252 relevant lines were removed as verified dead code (see "Dead code removed"); the covered count
  therefore moves less than the ratio does.
- `.simplecov` minimums raised from line 94 / branch 74 to line 95 / branch 75.
- The requested target was 97% line coverage; this batch reached 95.59%. See "Remaining gap".

Unlike batch 37 this batch is not test-only: the new tests reached endpoints that had never been
requested, and several of them raised before producing a response. Those defects are listed below.

## Defects found by the new tests

Each one was a live endpoint that failed on every request; none had a test.

1. `SignSettingsEmailRegistration#commit_settings_email_registration!` calls
   `on_email_registration_verified!`, added in `bbe1f552b`. Only
   `Base::App::Identity::Emails::RegistrationsController` gained an implementation, so the com and
   org settings-email verification raised `NoMethodError`. Fixed by giving the concern the same
   explicit no-op default its sibling `SignEmailRegistrationFlow` already carries. com and org
   deliberately keep the historical no-op rather than inheriting the app surface's
   `CredentialSecurityTransition`; extending session revocation to two more surfaces is a product
   decision, not a crash fix.
2. `Base::App::Identity::Telephones::RegistrationsController` defined `render_registration_new`,
   `render_registration_edit`, `registration_new_props` and `registration_edit_props` twice,
   verbatim. The first four definitions were shadowed; removed.
3. `Base::Com::Identity::ActivitiesController#index` never called `authorize!`, so
   `verify_private_action_authorized!` raised `ActionPolicy::UnauthorizedAction` on every request.
   app and org already authorize with their chronicle model; com now authorizes with
   `ClientChronicle`, which is the model `Base::Com::Identity::ActivityLog` reads and which
   `ClientChroniclePolicy` documents as covering visitor rows.
4. The six avatar social-graph endpoints (`follows`, `blocks`, `mutes` × create/destroy) called
   `authorize!(record, ..., user: actor_avatar)`. ActionPolicy takes the actor under `context:`, so
   every request raised `ArgumentError: unknown keyword: :user`.
5. `EnforcementCaseApplicable::END_REASONS` gained `verification_completed`, but the three
   `*_enforcement_cases` check constraints were never widened, so recovery completion raised
   `PG::CheckViolation`. Three migrations widen the constraint to the model's reason set.
6. `activerecord.attributes.*_enforcement_appeal.reason_code` / `.statement` were missing, so a
   rejected appeal raised `I18n::MissingTranslationData` instead of re-rendering the recovery page.
7. `Base::Com::Identity::Recovery::SessionsController#recovery_verified_email_status_ids` referenced
   `VisitorEmail::EDITABLE_SUBSCRIPTION_PREFERENCE_STATUS_IDS`, which does not exist; every
   corporate account-recovery attempt raised `NameError`. Now uses the existing
   `AuthMethodGuard::VISITOR_VERIFIED_EMAIL_STATUSES`, which carries the same two statuses.
8. `SignUpSessionState::KEY_GROUPS[:com][:sequence_id]` was `:sign_com_up_sequence_id`, a key no
   controller writes; every com controller uses `:auth_com_up_sequence_id`. `clear_all!` therefore
   left the real sequence id in the session after a cancelled or completed corporate sign-up.
9. `SignSettingsPasskeyRegistration#start_passkey_ceremony!` declared underscore-prefixed keywords
   (`_surface:`), which are part of the caller contract;
   `Auth::Com::Settings::PasskeysController#new` spelled them without prefixes and raised
   `ArgumentError`. The keywords now match the sibling `finish_passkey_ceremony!`, and the app and
   org callers were updated.
10. `Auth::Com::Settings::PasskeysController#new` never called `authorize!`; app and org both do.
11. `Base::App::Identity::SecretsController` declared `step_up only: %i(new create)` with no scope
    and no `verification_scope`, so `require_verification!(nil)` raised `NoMethodError` for any
    actor with a configured step-up method. The scope is now named, matching com and org.
12. The same controller called `start_secret_credential_ceremony!` /
    `reset_secret_credential_ceremony_session!` without including
    `SignSettingsSecretCredentialRegistration`.
13. Neither `ClientTokenPolicy`, `VisitorTokenPolicy` nor `OperatorTokenPolicy` defined `show?`, so
    the routed session-detail page raised on all three surfaces. `show?` is bound to the owner, like
    `destroy?`.
14. `ComSignUpCheckpointPage#sign_up_checkpoint_cancellation_props` built
    `auth_com_sign_up_check_<entry_method>_path`. No such route helper exists -- every check path
    names its step -- so the corporate sign-up checkpoint page raised `NoMethodError` whenever it
    rendered. It now takes the first missing requirement as the step and returns nil when none is
    missing, exactly as `AppSignUpCheckpointPage` does.
15. `Base::App::Identity::Emails::RedeliveriesController#create` never called `authorize!`, so
    `verify_private_action_authorized!` raised on every passcode redelivery. It now authorizes with
    the same `ClientEmail, to: :create?` rule the registrations controller uses.

## Dead code removed

Removed on explicit authorization after the reachability of each method was checked against
`PasskeySignInFlow`, which is the only caller of these hooks.

- The three `Auth::*::Sign::In::PasskeysController` entry pages carried a full copy of the passkey
  sign-in flow -- both `only: :options` / `only: :verification` rate limits, the identifier hooks
  and the login-completion hooks -- although the router maps only `#new` to them. `#options` and
  `#verification` live in the `Passkey::Options` and `Passkey::Verifications` controllers. The entry
  pages now carry `#new` and its props and nothing else.
- `AuthCredentialTimingProtectionContractTest` pinned those three entry pages as carriers of
  `MinimumResponseBudget`. They no longer perform any credential lookup, so a timing oracle has
  nothing to read; the three were dropped from the invariant with the reasoning written into the
  test. The controllers that do the credential work -- both `Passkey::*` pairs on all three surfaces
  and the secret-credential controllers -- are still required to carry the budget.
- The `Passkey::Options` and `Passkey::Verifications` controllers each carried the other's hooks.
  `#options` calls `before_passkey_options_request!`, the identifier hooks and
  `find_active_passkey_actor`; `#verification` calls `allow_passkey_sign_in?`,
  `perform_passkey_sign_in` and the login-result hooks. Each controller now defines only the hooks
  its own routed action reaches; the concern's `NotImplementedError` defaults cover the rest, so a
  future miswiring fails loudly instead of running a mirrored copy.

Total: 252 relevant lines. All 327 tests across the passkey sign-in, settings-passkey and
controller-inheritance invariants pass afterwards.

## Decisions Made During Implementation

- Decision:
  `Base::App::Identity::Telephones::RegistrationsController#handle_registration_update_status` keeps
  its `:session_expired` branch even though `valid_registration_session?` already rejects an expired
  OTP one line earlier, so the branch is unreachable through the routed flow.
  - Why: it is a defensive re-check inside the shared helper, not dead duplication.
- Decision: the com/org OAuth authorize endpoints answer 422 for an anonymous ceremony start in this
  environment, where the app surface redirects. The reconstructed local env may not carry the jump
  gateway allowlist CI uses, so this is recorded as unverified rather than asserted either way.
  - Follow-up needed: confirm against CI before treating it as a defect.
- Observation, not fixed:
  `Auth::App::Up::TelephonesControllerTest#test_resend_cooldown_is_30_seconds` failed once in a full
  parallel run and did not reproduce -- not in isolation across three seeds, not paired with either
  file added in the same batch, and not in the immediately following full parallel run. Adding tests
  reshuffles the per-worker distribution, which is what surfaced it. It reads as pre-existing
  cross-worker flakiness in that file rather than a regression, but it is recorded here because a
  test that fails once in a while is worth a look.

## Deviations From Plan

- Change: this batch modifies application code, migrations and locale files; batches 34-37 were
  test-only.
  - Why: the new tests exposed fifteen defects, most of them endpoints that raise on every request.
  - Risk: the three migrations alter check constraints. Each drops and re-adds one constraint under
    `disable_ddl_transaction!`; the new predicate is a strict superset of the old one, so no
    existing row can violate it and the re-add is validated immediately.

## Remaining gap to 97%

At 95.59% there are 2,373 uncovered lines; 97% needs 760 more covered lines. The shape of what is
left, not its size, is what makes that a separate programme of work.

Measured over the whole tree, the 2,373 uncovered lines form **1,866 separate fragments across 530
files**, and the distribution is almost entirely singletons:

| fragment size | fragments | lines |
| ------------: | --------: | ----: |
|        1 line |     1,503 | 1,503 |
|       2 lines |       263 |   526 |
|       3 lines |        68 |   204 |
|       4 lines |        24 |    96 |
|       5 lines |         5 |    25 |
|       6 lines |         2 |    12 |
|       7 lines |         1 |     7 |

The largest contiguous uncovered block anywhere in the application is seven lines
(`SignOidcLogout#oidc_logout_completion_redirect_url`, the palm-origin rewrite). Only three files
hold a block of six lines or more. There is no remaining place where one test unlocks a method or an
action; every fragment is a distinct branch condition inside code the existing tests already walk --
a `rescue`, an `else`, a guard clause, a surface-specific hook. Reaching 760 more covered lines
means constructing on the order of 600 separate scenarios at an average of 1.27 lines each.

That is visible in this batch's own throughput. The first nine test files added about 200 covered
lines, because they reached controllers with no tests at all. The last fifteen added about 90, and
the final four added 23 -- roughly six lines per file -- even where the file targeted was one of the
largest by uncovered count. The easy ground is gone, and the arithmetic does not improve with more
of the same effort.

Two levers were used and are now spent:

- Dead-code removal took 252 relevant lines out of the denominator, worth about 0.25 points. A scan
  for further provably dead code (fully uncovered controller methods whose name appears nowhere else
  in `app/`, `lib/`, `config/`, `test/` or the ERB templates) returns zero candidates; everything
  that remains is a live override of a concern hook.
- The credential-blocked tests below would add roughly 30-50 covered lines in CI that cannot be
  measured here, so the CI figure for this branch is slightly above 95.59%.

What is left, by area: about 1,000 lines in `app/controllers/concerns` (deep sign-in state-machine,
OIDC end-session, social-callback and refresh-token error branches), about 1,000 in per-surface
controllers where one surface is exercised and its siblings are not, and about 370 outside
`app/controllers` spread over 149 files at one to twelve lines each.

## Review Notes

- Tests run: every new and edited test file individually; `test/controllers/auth`, `test/services`,
  `test/policies`, `test/controllers/base`; and after the dead-code removal the 327 tests across the
  passkey sign-in, settings-passkey, credential-timing and controller-inheritance invariants. Nine
  full `COVERAGE=true bin/rails test test/` runs. The final run is 10,631 runs / 59,802 assertions.
  RuboCop is clean over all 72 changed Ruby files.
- Tests not run: Vitest and the other frontend gates; this batch is Rails-only.
- Known failing: seven tests in `test/controllers/auth/app/settings/passkeys_controller_test.rb`.
  That file deletes `WEBAUTHN_APP_RP_ID` / `WEBAUTHN_APP_ORIGIN` in `setup` so the values must come
  from `config/credentials/test.yml.enc`, which needs the `test.key` issued out of band
  (`docs/operations/development-credential-provisioning.md`). Restoring the two environment values
  makes all 27 tests in that file pass, so the failure is environmental, not a code defect.
- Documentation promotion needed: none.
