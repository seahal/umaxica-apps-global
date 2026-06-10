# Sign namespace migration — partial completion (2026-06-10)

Handoff note for the in-flight migration that moves sign controllers under
`sign/<surface>/sign/{up,in,out}/...` to match the `/sign/...` URL prefix (ADR
`sign-prefix-routing.md`). Routes were committed ahead of controller implementations, leaving
several route → controller and route-helper gaps.

## What was completed in this change

- **App sign-up check controllers**: created the 3 missing cancellation controllers
  `sign/app/sign/up/check/{apple,google,telephone}/cancellations` (the email one already existed).
  All inherit their provider's old `BirthdatesController` and call
  `SignUpExplicitStepControllerSupport#cancel_from_explicit_step`. The 11 previously-untracked
  `sign/app/sign/up/check/*` wrappers are part of the same unit.
- **Com sign-up check controllers**: created the entire `sign/com/sign/up/check/{email,telephone}/*`
  tree (8 controllers) as thin subclasses of the old `sign/com/up/check/*` controllers. com is
  social-free by design (email/telephone only) per
  `plans/active/sign-up-state-machine-implementation-plan.md`.
- **Com route-helper sweep**: the old `sign/com/up/*` controllers (which the new wrappers inherit)
  still referenced removed `sign_com_up_*_path` helpers. Applied a helper-only rename
  `sign_com_up_X_path/_url` → `sign_com_sign_up_X_path/_url` across 9 files. Non-helper tokens were
  deliberately preserved (notably the session key `:sign_com_up_sequence_id`, plus
  `sign_com_up_email_flow_state`, `sign_com_up_passcode_raw`,
  `sign_com_up_existing_visitor_email_*`, `sign_com_up_pending_visitor_id`). This mirrors the
  already-applied app sweep (`sign_app_up_*` → `sign_app_sign_up_*`).

Verified: `bin/rails zeitwerk:check` passes; a route-walk (`Rails.application.routes`) confirms
every `sign/.../sign/up/check/...` route now resolves to an existing controller + action.

## Known remaining gaps (NOT addressed here)

1. **Missing `sign_<surface>_sign_up_check_path` route (app and com).**
   `sign/{app,com}/up/guards_controller.rb` and
   `.../up/checkpoint/{passcodes, passkeys}_controller.rb` reference a bare sign-up `check` helper,
   but no such route exists on any surface (only the nested `..._check_email_otp` etc. and the
   sign-in `..._sign_in_check`). Currently only reached in dead/overridden code paths, so it does
   not 500 today. App has the same dangling reference (`sign_app_sign_up_check_path`). Left as-is
   per owner decision (record only); needs either a route addition or removal of the references. The
   sign-side `Sign::*::Social::AuthenticationsController#continue` provider-validation branch +
   `sign.app.social.sessions.invalid_provider` use are likewise dead on the sign surface now that
   entry moved to per-provider `connection_attempts` (acme still uses `continue`); cleanup
   candidate.

2. **Other route → missing-controller gaps from the same migration**, outside the sign-up scope and
   untouched here: `sign/{app,com,org}/oauth/user_infos#show`,
   `sign/{app,com,org}/settings/removal_attempts#create`,
   `sign/{app,com}/settings/rotation_attempts#create`,
   `sign/app/settings/emails/redeliveries#create`,
   `sign/{app,com}/verification/redeliveries#create`. These controllers do not exist; the routes
   will raise on request.

3. **Broad pre-existing test-suite breakage.** `bin/rails test test/controllers/sign` shows ~33
   failures / ~329 errors on a clean baseline (confirmed by stashing this change — they pre-date
   it). Cause: many sign test files still use pre-rename helpers (`sign_app_in_*`, `sign_com_in_*`,
   `sign_app_up_*`). The test files need the same helper sweep applied to the controllers/views.
   Examples: `test/controllers/sign/app/in/challenges_controller_test.rb`,
   `test/controllers/sign/com/in/emails_controller_test.rb`,
   `test/controllers/sign/app/in/checkpoints_controller_test.rb`.

## Verified-green tests touched by this change

`test/controllers/sign/app/social/authentications_controller_test.rb`,
`test/integration/social_auth_app_flow_contract_test.rb`,
`test/controllers/sign/app/sign_ups_controller_test.rb` — 34 runs, 0 failures. The vacuous
"unsupported provider" test (posted to the google endpoint, so it no longer exercised provider
validation) was removed; a debug `Rails.logger.debug(response.body)` line was removed from the
sign_ups test.
