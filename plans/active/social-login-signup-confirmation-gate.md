# Social Login Signup Confirmation Gate

## Status

Active implementation plan.

## Purpose

Unknown app-surface Google and Apple social identities must not create durable app principal,
social identity, account, organization, or avatar records at provider callback time. They must enter
an explicit new-registration confirmation checkpoint first. Durable creation happens only after the
browser owner submits that checkpoint with an affirmative confirmation.

This plan applies only to the `app` surface social login/sign-up path:

- Google callback: `GET /auth/google_app/callback`
- Apple callback: `POST /auth/apple/callback`

`org` and `com` must remain outside this work.

## Current Verified Problems

- `SocialAuth::LoginHandler#login_new_identity` creates a `Client` and a provider identity during
  callback for unknown Google and Apple UIDs.
- `ClientAccount` creation is mostly deferred by `sign_up_entry`, but `Client` and
  `ClientGoogleIdentity` / `ClientAppleIdentity` are already durable before the user has confirmed
  the new registration.
- Existing linked identities are not always treated as login: the current sign-side branch treats
  linked identities with missing birthdate as social sign-up continuation.
- The current checkpoint page only asks for normal sign-up requirements such as birthdate. It does
  not explicitly say that the provider account is unregistered, that a new Umaxica Identity will be
  created, that later merge is unavailable, or that the user should cancel if this is wrong.
- Existing integration tests assert the old behavior by expecting unknown Google and Apple
  callbacks to create a `Client` and social identity immediately.

## Target Behavior

- If `provider + uid` is already linked, login wins regardless of whether the entry started from
  sign-in or sign-up.
- If `provider + uid` is unknown, callback creates only temporary signup-cycle evidence and routes
  to the signup confirmation checkpoint.
- Unknown callback alone creates no `Client`, no provider identity, no `ClientAccount`, no
  organization, and no avatar.
- The confirmation checkpoint must explicitly show provider-specific copy:
  - "This Google/Apple account is not registered."
  - "A new Umaxica Identity will be created."
  - "It cannot be merged into an existing account later."
  - "Cancel if this is not what you intended."
- The confirmation POST must require an explicit checkbox. Missing checkbox rejects without durable
  creation.
- Cancel must discard only the temporary signup cycle/evidence and redirect to the safe app entry.
- Identity merge must not be mentioned as available. Treat merge as permanently unavailable.

## Implementation Plan

### 1. Split social callback classification from durable creation

- Change `SocialAuthService` / `SocialAuth::LoginHandler` so unknown `provider + uid` returns a
  pending social signup result instead of calling `login_new_identity`.
- Keep existing linked-identity handling, but remove the `birthdate.blank?` fallback from the
  linked-identity login decision. Linked identity means login for this task.
- Keep provider identity lookup based only on normalized provider and UID. Do not use provider
  email as an account identity boundary.

### 2. Store pending social signup evidence without creating app principals

- Use the app ticket boundary for pending signup state. The `ClientSignUpFlow` must carry:
  - `entry_method`: `google` or `apple`
  - `social_provider`: `google` or `apple`
  - `step`: social callback/checkpoint progression
  - expiry and nonce through the existing sign-up cycle locator
  - a server-side reference to the verified provider assertion/result
  - a digest of the provider UID for provider/UID binding checks
- Do not store raw provider tokens in the ticket row. Reuse the existing social ceremony candidate
  cache or an equivalent short-lived server-side store for raw provider assertion material.
- The pending evidence must be single-use and expire with the sign-up cycle or earlier.
- If pending evidence is missing, expired, consumed, provider-mismatched, UID-mismatched, or not
  bound to the current session-owned sign-up cycle, reject generically and create nothing.

### 3. Add the explicit social confirmation checkpoint

- Extend the app sign-up checkpoint rendering for social entry methods.
- Render provider-specific confirmation text before the normal birthdate requirement.
- Add a required checkbox named for social signup confirmation, for example
  `confirm_new_social_identity`.
- Preserve the existing cancel button and route it through the signup cancellation path.
- The confirmation POST must include:
  - current checkpoint version
  - birthdate requirement input
  - `confirm_new_social_identity=1`
- Missing checkbox, stale checkpoint version, missing pending evidence, or expired cycle returns a
  safe failure response and creates no durable records.

### 4. Create durable records only inside final confirmation

- For social signup only, finalization must create the `Client`, assign birthdate, create the
  provider identity, and create `ClientAccount` in the same finalization path after the confirmation
  checkbox is accepted.
- After creation, bind the cycle to:
  - `principal_id`: new `Client` id
  - `pending_contact_type`: `social_identity`
  - `pending_contact_id`: new provider identity id
  - consumed pending evidence marker
- Then complete the existing sign-up finalization and sign-in handoff sequence.
- If creation fails at any point, leave the cycle non-completed and do not create a partial account.
  Any partial rows created inside the transaction must roll back.

### 5. Cancel and terminal cleanup

- Unknown social signup cancel before confirmation should terminate the cycle and delete/expire only
  temporary ticket/evidence state.
- Because no `Client` or provider identity exists before confirmation, `Sign::App::Up::SocialCancellation`
  must not require a pending actor for pre-confirmation social cycles.
- After durable confirmation, existing cleanup rules for completed sign-up must not delete the
  completed account because later sign-in/session issuance failed.

## Security And Failure Cases

- Existing state handling must remain replay-safe: OAuth callback state is consumed once and bound
  to provider.
- Sign-up cycle access must remain session-bound by `SignUp::CycleLocator` nonce.
- Pending social evidence must be provider-fixed and UID-fixed. A Google pending cycle cannot be
  consumed by Apple, and a different UID from the same provider cannot be substituted.
- Double-submit of the confirmation POST must not create duplicate `Client`, identity, or account
  rows. Use the cycle row lock and consumed pending evidence marker.
- Callback replay after state consumption must reject before any durable mutation.
- Confirmation replay after cycle completion must reject or follow the existing completed-cycle
  behavior without creating another account.
- Logs must not include provider tokens, cookies, authorization headers, full params, or raw UID.

## Tests To Add Or Update

Use Minitest. Prefer request/integration coverage for observable behavior.

- Google unknown callback:
  - callback alone creates no `Client`, no `ClientGoogleIdentity`, no `ClientAccount`, no avatar
    assignment, and redirects/renders signup confirmation checkpoint.
  - confirmation checkbox + valid birthdate creates exactly one `Client`, one active
    `ClientGoogleIdentity`, and one `ClientAccount`, then signs in through the existing handoff.
  - cancel creates nothing durable and returns to the safe app entry.
- Apple unknown callback:
  - same assertions as Google, using Apple POST callback.
- Existing linked identity:
  - Google login-entry and signup-entry both enter login and create no signup account.
  - Apple login-entry and signup-entry both enter login and create no signup account.
- Rejection and replay:
  - missing checkbox creates nothing.
  - double submit creates only one account or rejects the second submit without mutation.
  - expired sign-up cycle creates nothing.
  - expired/missing pending social evidence creates nothing.
  - provider swap creates nothing.
  - UID swap creates nothing.
  - OAuth state mismatch/replay creates nothing.
  - sign-up cycle nonce/session mismatch creates nothing.
- Regression:
  - grant-backed social link still commits only through acme completion.
  - established social login still follows acme-owned session issuance.
  - org/com social callback or provider routes remain unavailable/rejected.

Update tests that currently expect immediate creation:

- `test/integration/social_auth_login_test.rb`
- `test/integration/social_auth_app_flow_contract_test.rb`
- `test/integration/apple_social_flows_test.rb`

## Suggested Devcontainer Commands

Run the narrow social and sign-up slices first:

```bash
bin/rails test test/integration/social_auth_login_test.rb
bin/rails test test/integration/social_auth_app_flow_contract_test.rb
bin/rails test test/integration/apple_social_flows_test.rb
bin/rails test test/integration/social_auth_state_test.rb
bin/rails test test/integration/social_callback_guard_test.rb
bin/rails test test/controllers/sign/app/auth/omniauth_callbacks_controller_test.rb
bin/rails test test/controllers/sign/app/social/authentications_controller_test.rb
bin/rails test test/controllers/sign/app/up
```

Then run broader app social/sign-up coverage if the narrow slice passes:

```bash
bin/rails test test/integration/social_auth_link_test.rb
bin/rails test test/integration/social_auth_unlink_test.rb
bin/rails test test/services/sign/app/up/social_cancellation_test.rb
bin/rails test test/services/social_auth_service_test.rb
bin/rails test test/services/social_auth_service_extra_coverage_test.rb
```

Use `PARALLEL_WORKERS=1` for the narrow slice if fixture/database contention appears.

## Completion Report Required

The implementing agent must report:

- changed files;
- old and new state transitions;
- tests added or updated;
- exact test commands and results;
- any tests not run;
- whether unknown Google/Apple callback alone creates zero durable app identity/account/avatar
  records;
- whether confirmation POST is the only durable creation point.
