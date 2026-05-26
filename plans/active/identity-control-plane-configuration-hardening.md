# Identity Control Plane Configuration Hardening

## Summary

`/configuration` is being moved from a collection of account-setting CRUD pages toward an identity
control plane. This plan intentionally does not include a full "is my account safe?" dashboard in
the current slice. The immediate work is to harden credential write boundaries, audit integration,
return-target handling, and future MFA reset state contracts without forcing a full UI rewrite.

## Key Decisions

- Keep Rails resourceful routes where practical, but do not let CRUD shape weaken security
  boundaries. WebAuthn credential persistence must happen only after server-side verification.
- Replace controller-local Chronicle writes with one `IdentityAudit.record!` entry point.
- Stop storing raw recovery/passcode material in the Rails session as the long-term design. Use a
  one-time reveal boundary that is actor-bound, session-bound, expiring, auditable, and consumed on
  display.
- Treat MFA reset as a persisted recovery request state machine, not as a controller-local flag and
  not as a step-up bypass.
- Keep session revoke strictness as TBC. Future security-level controls may decide whether single
  or other-session revoke requires fresh AAL2.

## Implementation Changes

- Add `IdentityAudit.record!` and migrate touched app configuration credential/session audit writes
  to it.
- Make `Sign::App::Configuration::PasskeysController#create` a non-persistence boundary for the
  Rails CRUD route; `verification` is the canonical WebAuthn write path.
- Remove touched legacy Base64 return-target fallback and use signed return-target verification
  only.
- Define a stable posture/read-model boundary before adding `/configuration/security`,
  `/configuration/profile`, and `/configuration/audit` aggregate views.
- Add MFA reset presenter/component states before enabling the controller workflow.

## Test Plan

- Run the focused configuration controller tests first:
  `bin/rails test test/controllers/sign/app/configuration/passkeys_controller_test.rb test/controllers/sign/app/configuration/sessions_controller_test.rb test/controllers/sign/app/configuration/mfa/resets_controller_test.rb test/controllers/sign/app/configuration/birthdates_controller_test.rb test/controllers/sign/app/configuration/activities_controller_test.rb`.
- Add service tests for `IdentityAudit.record!`.
- Add controller regression coverage that passkey `create` does not persist credential material.
- Add one-time reveal tests before replacing `session[:recovery_secret_raw]`.
- Track existing unrelated failures separately: current focused run showed fixture/preference
  lookup errors through `OmniAuthCorporateGuard`, one missing `jwt_access_token_for` helper, and
  Prosopite N+1 reports in revoke-all logout.

## Assumptions

- The current slice excludes the account safety dashboard and strict session revoke policy.
- Existing `passkeys`, `secrets`, `totps`, `sessions`, and `activities` detail routes remain.
- New aggregate routes should layer above existing detail routes rather than force an immediate URL
  migration.
