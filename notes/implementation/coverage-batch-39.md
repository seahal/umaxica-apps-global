# Coverage Batch 39 Implementation Notes

## Context

- Original plan/spec: continue raising `bin/rails test` line coverage toward 97% and keep
  failures/errors at zero.
- Related decisions/docs/plans: `notes/implementation/coverage-batch-38.md`,
  `docs/operations/development-credential-provisioning.md`.
- Implementation date: 2026-08-31.

Batch 38 concluded that the remaining uncovered lines were an almost uniform spray of one- and
two-line branch fragments, and that writing more ceremony tests had collapsed to roughly six covered
lines per test file. That conclusion was right about the fragments and wrong about the cause. This
batch found a second population hiding inside the same numbers: **code no route can reach**. A
controller action with no route is uncovered for a reason no test can fix, and batch 38's "uncovered
fragment" census counted those lines as if a test could reach them.

## Coverage

- Starting Rails line coverage: 51,411 / 53,783 (95.5896%).
- Ending Rails line coverage: 51,188 / 53,146 (96.31%). Delta +0.72 points.
- Starting branch coverage: 12,094 / 15,885 (76.13%). Ending 12,141 / 15,703 (77.31%).
- The requested target is 97%; this batch reached 96.31%. 1,958 lines remain uncovered and 97%
  allows 1,594, so 364 more must be covered or removed.
- The gain comes from two sources in roughly equal measure: new tests for live-but-unreached code,
  and removal of code that is provably unreachable. Note that removing an unroutable controller
  moves the ratio far less than its file size suggests -- the class body and every `def` line are
  _covered_ at load time, so a 30-line dead controller typically contributes only three or four
  uncovered lines.

## What made the difference: three scans

Each scan is a small script run against the fresh `coverage/.resultset.json` plus a Rails runtime.
They are worth keeping; they found in one afternoon what a week of test-writing did not.

1. **Shadowed definitions.** For every fully-uncovered `def` in `app/`, compare the file it lives in
   against `klass.instance_method(name).source_location`. A mismatch means something else wins the
   method lookup and this copy can never run. This found `Auth::Com::Verification::BaseController`,
   which `prepend`s `SignComVerificationBase::Overrides` and then redefines the same twenty private
   methods underneath it. The prepended copies had diverged (wider verified-email status set, a
   `SolidQueue` writing-role wrapper, an alert the controller copy lacked), so the dead copies were
   also stale.

2. **Universally shadowed concern methods.** Same idea from the other side: for a concern method,
   check whether _every_ including controller resolves that name to some other owner. Excluding
   abstract `NotImplementedError` hooks, 18 such methods remain (65 lines); they are listed in "Not
   done" because each is three to seven lines and several are deliberate template-method defaults.

3. **Unroutable controllers and actions.** Build the set of `controller#action` pairs the router can
   produce, then subtract. A public controller method that no route reaches, on a class no routed
   subclass inherits, is dead by construction. This was by far the highest-yield scan: 23
   controllers with no route at all, and a further set of leftover actions on controllers that are
   otherwise live.

## Dead code removed

Superseded by a split that left the original behind:

- `#resend` on `Auth::App::Verification::EmailsController`,
  `Auth::Com::Verification::EmailsController` and `Auth::App::Sign::Up::TelephonesController`. The
  redelivery endpoints moved to dedicated `RedeliveriesController`s (their own file comments say
  so); the original actions kept their `before_action` entries but lost their routes.
  `load_registration_telephone` went with them. `otp_resend_rate_limited?` did not: the check-step
  OTP controller inherits from the sign-up telephones controller and still calls it, which the grep
  missed and the test suite caught.
- `#options` and `#verification` plus the `verify_settings_passkey_turnstile!` guard on all three
  `Auth::*::Settings::PasskeysController`s. Routes point at `settings/passkeys/options#create` and
  `settings/passkeys/verifications#create`, which are independent controllers with their own copies
  of the guard. The live copies are now tested (see below).
- 20 controllers with no route at all: the `Checkpoint::BirthdatesController`s superseded by
  `sign/up/check/<method>/birthdates`, the `Base::{Com,Org}::Oauth::UserInfoController`s superseded
  by `userinfos_controller.rb`, `Base::Com::Identity::SecretsController` and
  `Base::App::Identity::RecoverySecretsController` superseded by the `secret_credentials` resources,
  the `sign/up/check/*/cancellations` and `sign/in/check/cancellations` controllers, the two
  `support/*/sessions/emergency_revocations` controllers, and the three
  `Core::*::AccountsController`s superseded by `base/*/accounts`.

Never wired up at all:

- `SessionLimitPendingGuard` -- no includer anywhere, and it used Rails flash, which `AGENTS.md`
  forbids outright.
- `SignVerificationTotpActions` -- `Auth::App::Verification::TotpsController` is its only includer
  and defines `new`/`create` itself, so the concern's copies never ran.
  `action_policy_usage_test.rb` already recorded that the Inertia migration moved those actions into
  the controller.
- `UserWithdrawalFinalizeJob` -- never enqueued, never scheduled, and its body calls
  `User.finalize_scheduled_withdrawals!` on a `User` class this application does not have. It would
  have raised `NameError` if anything had ever run it.
- `ExternalAuthentication::AppleCredentialRevocationPort` -- a `NotImplementedError` port with no
  implementation, no includer and no caller.

Unreferenced members of live classes:

- `WithdrawalLifecycle`: the `except_public_id:` parameter of `revoke_sessions` (never passed),
  `exclude_session_identifier`, `uuid_identifier?` and `exclude_fresh_withdrawal_step_up_sessions`
  (never called).
- `SignInStateMachine`: `TERMINAL_RESULT_STATUSES` with its only two readers, `terminal_status?` and
  `http_status_for`.
- `CoreBrowserCredentialContract`: `OIDC_COOKIE`, `REFRESH_PATH`, and the three
  `*_cookie_deletion_options` methods.
- `SocialAuthLoginHandler#build_identity_for_user`, `JitSecurityJwtJwksService#public_keys_for`.
- The `Auth::Com::Verification::BaseController` private block described under scan 1.

## Defects fixed

- **`sign.withdrawal.errors.*` translations were missing.** `Sign::InvalidWithdrawalStateError`,
  `Sign::WithdrawalDeletionError` and `Sign::WithdrawalRecoveryNotAvailableError` all pass an i18n
  key to `ApplicationError#initialize`, which calls `I18n.t`. None of the three keys existed.
  Raising any of them raised `I18n::MissingTranslationData` instead, in place of the error the
  caller asked for; the existing tests hid this by stubbing `I18n.t`. Added
  `errors.deletion_failed`, `errors.invalid_state` and `errors.recovery_not_available` under
  `sign.withdrawal` in `ja.yml` and `en.yml`.

## Defects fixed (continued)

- **The three `.../removal` compatibility endpoints raised on every authenticated request.**
  `Auth::{App,Com,Org}::Settings::RemovalsController#create` is declared
  `AUTHENTICATION_MODE = :private` but never called `authorize!`, so
  `verify_private_action_authorized!` raised `ActionPolicy::UnauthorizedAction`.
  `ActionPolicyUsageTest` allowlists these three actions as "protected by ceremony state rather than
  a durable domain record policy", but that allowlist only silences the static scan -- the runtime
  `verify_authorized` check is unconditional for a private action. Each now authorizes its own actor
  with `show?`, which all three actor policies define as `owner?`. Pinned by
  `test/controllers/auth/settings_removal_compatibility_test.rb`.
- **A failed Turnstile challenge on secret-credential creation returned 500, not 422.**
  `SignSettingsSecretCredentialTurnstileGuard` answered with `render :new`, but both including
  controllers are Inertia-only and have no `app/views/base/{com,org}/identity/secret_credentials`
  directory, so it raised `ActionView::MissingTemplate` (confirmed by temporarily restoring the old
  line and re-running). The guard now delegates the re-render to the surface. Its `update`,
  `destroy` and `else` branches were dead -- both controllers guard `create` only -- and went with
  the fix, along with the now-unused `secret_credential_turnstile_failure_redirect_path`.
- **`SignAuthorityRedirect` matched namespaces that no longer exist.** `sign_authority_host` and
  `base_authority_host` selected a host by matching the controller against `Sign::` / `Acme::`.
  Those namespaces were renamed to `Auth::` / `Base::`, so no branch ever matched and every call
  fell through to `request.host`. The sibling `SignAcmeAuthorityRedirect` had been updated for the
  rename; this one had not. Every remaining caller is a removals controller redirecting within its
  own surface, which is `request.host`, so the selection is now written out directly instead of
  being kept as branches that cannot be taken. `redirect_to_base_authority!`, `base_authority_host`,
  `redirect_to_acme_authority!` and `acme_authority_host` were dead here (the live copies are in
  `SignAcmeAuthorityRedirect`) and were removed, together with two `include ::SignAuthorityRedirect`
  lines in controllers that call nothing from it.

## Pre-existing violations found but not fixed

- `SignEmailOtpRedeliveryEndpoint#resend_email_otp_redelivery` and
  `require_email_nonce_for_redelivery!` pass `alert:` / `notice:` to `redirect_to`, which sets Rails
  flash. `AGENTS.md` forbids flash. Fixing it means replacing the redelivery feedback mechanism,
  which is a UX contract change rather than a coverage change.
- `Auth::{App,Com,Org}::RootsController#index` and their `root_landing_props` are unreachable:
  `redirect_root_to_sign_in` canonicalizes an allowlisted `ri` and `PreferenceGlobal#set_region`
  normalizes anything else, so both GET paths redirect before the action body runs. The action
  cannot simply be deleted -- the route names it -- so it stays as a fallback.

## Tests added

Service-level, no HTTP setup required:

- `test/services/oidc_refresh_token_issuer_surface_test.rb` -- staff and visitor refresh-token
  rotation and replay. `OidcRefreshTokenIssuer` dispatches on the parent token class in three places
  (usage lookup, risk-event actor key, connection touch) and only the client surface was pinned.
- `test/services/oidc_token_revoker_surface_lookup_test.rb` -- the same for revocation, including
  the assertion that a revocation authenticated as a visitor client cannot reach a staff usage row,
  and the sid fallback that revokes an access token bound to a browser session. The existing
  `OidcTokenRevokerCoverageTest` stubs those lookups away.
- `WithdrawalLifecycle`: every actor-class dispatch names the actor class it cannot serve.
- `SignOtpCeremony`: `verify!` refuses a destination the ticket is not bound to without consuming
  the real OTP; `issue!` refuses a channel the ticket is not waiting on.
- `RecoveryPasscodeTopUp`: a credential class with no recovery kind tops up nothing (this is the
  staff case -- `OperatorSecretCredentialKind` has no `RECOVERY`), and an unknown credential class
  is refused by name.

Controller-level:

- `BaseOauthAuthorizationSurfacesTest` gained the OIDC `login_challenge` resume path for com and
  org: resumed exactly once, refused when no sign-in has completed, refused when expired. Both
  `resume_authorization!` methods were entirely unexecuted before this.
- Turnstile failure on the com and org settings-passkey options endpoints, in both the JSON and the
  document shape.

## Not done

- The 18 universally shadowed concern methods (65 lines). Each is small and several read as
  intentional template-method defaults; removing them is a readability judgement, not a correctness
  one.
- `Auth::{App,Com,Org}::Sign::In::Session::CancellationsController` are unroutable, but
  `test/controllers/auth/in/session_cancellations_controller_test.rb` instantiates them directly.
  Deleting them means deleting that test. Left for a decision rather than taken unilaterally.
- A second opinion supplied a list of services referenced only from tests (`OutageService`,
  `TokenEmergencyService`, `AnalyticsConsentGuard`, `AvatarLifecycle::Transition`,
  `OidcJwksService`, `AppleClientSecretProvider`). All six check out as production-unreferenced in
  this worktree, but each has a dedicated test, so deleting them removes mostly-covered lines and is
  a product decision rather than a coverage one. Several other entries on that list --
  `AdministrativeAccessLock`, `DpopJtiReplayGuard`, `ExternalAuthenticationSignupUseCase`,
  `AccountStanding`, `SocialAuthSignupFinalizer`, `Publishing::ArchivedTaxonomyAssignmentError`,
  `ChronicleApplicationService`, `OidcClientStoresStaticClientStore`,
  `StepUpRequirement#aal_supported?` and `#method_allowed?` -- are live here and must not be
  removed.

## Verification

- `COVERAGE=true bin/rails test test/`: 10,666 runs, 59,815 assertions, 6 failures, 1 error, 1 skip.
  All seven failures/errors are the credential-blocked file described below.
- `bin/rails test test/` (parallel) run after each deletion group;
  `bin/rails test test/controllers test/services` run mid-batch. RuboCop clean over all 84 changed
  Ruby files.
- Not run: Vitest and the other frontend gates; this batch is Rails-only.

## Where the remaining 2,137 lines are

Counting only methods whose body is _entirely_ unexecuted: **559 methods, 1,007 lines**. The other
~1,130 lines are branch fragments inside methods the suite already walks. The largest live untested
methods are concentrated in `AuthenticationSequenceGate` (the OIDC-handoff sign-in promotion path:
`complete_sign_in_flow_after_session_result!`,
`promote_current_session_limit_cycle_for_oidc_handoff!`, `advance_oidc_session_promotion!`,
`bind_session_and_register_oidc!`, `advance_cycle_to_checkpoint_after_active_session!` -- 52 lines
between them), `SignOidcLogout`, `SignSocialAuthenticationEndpoint`, and
`Base::App::Social::Authentication::CompletionsController`.

The org session-revocation endpoints (`Base::Org::Identity::Revocations::{Alls,Others}Controller`)
are live and untested, but `test/integration/identity_session_revocation_test.rb` already documents
why: an org HTML request without an OIDC RP browser session is answered by the SSO initiator before
the controller under test runs. Covering them needs an org RP browser session, not another request
test.

## Review Notes

- Known failing: the same seven tests in
  `test/controllers/auth/app/settings/passkeys_controller_test.rb` as batch 38. That file deletes
  `WEBAUTHN_APP_RP_ID` / `WEBAUTHN_APP_ORIGIN` in `setup`, so the values must come from
  `config/credentials/test.yml.enc`, which needs the `test.key` issued out of band. Environmental,
  not a code defect.
- Known skipped: one test in `test/integration/oidc_rp_browser_flow_test.rb`, pre-existing and tied
  to issue #846.
- `ControllerInheritanceInvariantTest` failed after the deletions because two `KNOWN_VIOLATIONS`
  entries pointed at deleted files; the test says to remove them, and they were removed.
