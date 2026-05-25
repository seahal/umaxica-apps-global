# Session Reset Policy

This document is `app` / `com` / `org` This article describes the current behavior of Rails session
ID rotation (`reset_session`) as a countermeasure against session fixation attacks, which is common
to all three surfaces. The background to the design decision See
`adr/session-reset-on-privilege-transition.md`.

## Purpose

The authentication entity of this application is JWT It is a cookie and is not included in the Rails
session. The Rails session maintains the flow state before authentication (OIDC/social state/nonce,
email cooldown, WebAuthn challenge, etc.) only. `reset_session` regenerates the session ID at the
time of privilege transition and prevents the session ID planted by an attacker from being reused as
authenticated (defense in depth + temporary state cleaning).

## Reset points

`reset_session` is limited to the following three privilege transition points and aggregates each
point into a single choke point that must be passed.

| Transition Point | Single Choke Point                                              | Placement                                          |
| ---------------- | --------------------------------------------------------------- | -------------------------------------------------- |
| sign in          | `Authentication::Base#establish_signed_in_session!` → `#log_in` | Inside `log_in` (existing/no detour possible)      |
| step-up complete | `Sign::VerificationStepUpLifecycle#consume_step_up_session!`    | After DB commit/Before `flash[:notice]` assignment |
| logout           | `Authentication::Logoutable#logout_current_session!`            | Existing (sample shape)                            |

Sign-up completion goes through a dedicated sign-in method (`establish_signed_in_session!`), so it
is covered by the same chokepoint.

For stale sign-out submissions after another tab has already completed logout, the browser no longer
has the access/refresh cookie state required for an authenticated logout request. The sign-out
controller lets `authenticate!` reject the request and redirect to sign-in without calling the token
revoke primitive, resetting the Rails session again, or writing a logout audit event. See
`docs/security/logout-sequence.md`.

## Ordering constraints

The placement order of `reset_session` upon completion of step-up is a safety requirement.

- WebAuthn challenge is `consume_step_up_session!` before calling `verify_passkey!` Since it has
  already been consumed, it will not be destroyed by reset.
- Since `return_to` / `scope` was made into a local variable before the DB transaction, it is
  retained even after reset.
- The step-up session is DB persistent (`rs.destroy!`) and is not affected by Rails session resets.
- `flash` is stored in the Rails session, so `reset_session` is `flash[:notice]` It must be placed
  **before** the assignment (if it is later, the success notification will disappear).

## Non-goals

The following routes are outside the scope of this policy. Both go through `log_in`, so
`reset_session` has already been reached and is safe from fixed attacks.

- org Social Login (`sign/org/auth/omniauth_callbacks_controller`) `log_in` Direct call (excluded
  from regular entry aggregation to maintain MFA judgment behavior of existing staff).
- OIDC Direct call to `log_in` for RP login and passkey registration login.
- AAL promotion without going through `consume_step_up_session!` (risk enforcement, self-promotion
  when registering credentials).

## Related

- `adr/session-reset-on-privilege-transition.md`
- `docs/security/step-up-mfa-status.md`
- `docs/security/sign-in-sequence.md`
