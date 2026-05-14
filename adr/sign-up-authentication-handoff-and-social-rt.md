# Sign Up Authentication Handoff and Social Return-To Handling (2026-05-13)

## Status

Accepted

## Context

The sign surfaces currently have different registration and post-authentication behavior:

- `app` supports social authentication with Google and Apple.
- `com` does not use social authentication and should remain email/telephone only.
- Sign In has an established post-authentication sequence: MFA when required, session-limit
  handling, checkpoint, dashboard, and optional `rt` continuation.
- Sign Up currently has credential-specific completion paths, especially for telephone signup.

The app social flow already stores OAuth intent and callback context in server-side session before
redirecting to the provider. It does not currently preserve `rt`, but the existing session context
means this can be added without embedding application redirect state into OAuth `state`.

Telephone Sign Up has a separate problem. OTP verification and required passkey/MFA setup must not
be treated as a completed Sign In sequence. If a telephone record is marked as verified before
required Sign Up setup is complete, an abandoned or failed setup can leave the phone number in a
state that blocks later registration attempts.

## Decision

We will keep social authentication scoped to `app` and will not introduce social login or social
signup to `com`.

For `app` social sign in/up, `rt` may be preserved across the OAuth round trip by storing sanitized
return-to context in the server-side social auth session. OAuth `state` remains dedicated to
provider callback integrity and CSRF protection.

Telephone Sign Up must not use `/sign/in/checkpoint` to represent incomplete registration state.
Sign Up needs its own pending registration checkpoint, such as `/sign/up/checkpoint`, for flows
where OTP verification has succeeded but required passkey/MFA setup has not yet completed.

Telephone registration is finalized only after all required Sign Up setup succeeds. Finalization
includes telephone status transition, user/customer account creation, audit writing, login session
creation, welcome/checkpoint handling, and `rt` continuation.

Pending telephone registration must be resumable or cleanup-able. Expired, abandoned, or failed
pending registration state must release the phone number so the same person can retry registration
without being forced into a broken Sign In path.

## Consequences

- `app` social auth can share the Sign In post-authentication sequence while preserving `rt`.
- `com` remains simpler and does not gain social auth routes, models, callbacks, or provider
  configuration.
- Sign Up registration state is not conflated with Sign In checkpoint state.
- Telephone Sign Up requires a dedicated pending-registration checkpoint and cleanup policy before
  the current telephone/passkey path is refactored.
- Existing Sign In checkpoint behavior remains unchanged.

## Future Test Expectations

- App social sign in/up preserves `rt` after Google and Apple callbacks and continues through the
  normal checkpoint/dashboard sequence.
- Social callback failure clears stored social `rt` together with other social auth session state.
- App telephone signup interruption before passkey completion does not permanently block
  re-registration of the same number.
- App telephone signup finalizes telephone status, account creation, audit, login, and redirect
  sequence only after required passkey setup succeeds.
- Com telephone signup remains covered separately and does not introduce social auth behavior.
