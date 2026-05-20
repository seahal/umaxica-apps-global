# Security Invariants

These tests freeze security properties that were reviewed as "No issue found".
If product behavior or architecture intentionally changes, update this document
in the same change as the test and implementation update.

## Cookie Attributes

Production authentication, refresh, device, and session cookies must remain
secure, HTTP-only where secrets are stored, SameSite=Lax, and compatible with
the `__Host-` prefix. `__Host-` cookies must have no Domain attribute, must use
`Path=/`, and must be Secure.

## CSRF Protection

Surface base controllers must use `protect_from_forgery` with
`using: :header_or_legacy_token` and `with: :exception`. Controllers must not
introduce `skip_forgery_protection` or `with: :null_session`. State-changing
routes are enumerated from `Rails.application.routes` and checked for
null-session drift.

## Refresh Token Reuse

Refresh token reuse is treated as a compromised refresh token family. Reuse
detection revokes every token in the same family and leaves unrelated families
alone. Ordinary logout/current-session revoke must not be broadened into a
family revoke.

## Withdrawn Resource Refresh

Only active resources are refreshable. Closing, suspended, and terminated
resources must be rejected by the refreshability gate.

## Withdrawal Gate

Withdrawal-restricted resources are confined to the configuration edit and
withdrawal flow allowlist. Protected HTML routes redirect to configuration edit.
Protected JSON routes return `403` with `WITHDRAWAL_REQUIRED`. Controllers must
not skip the withdrawal gate without an explicit invariant allowlist.

## Forbidden Patterns

Production code must not add the forbidden patterns enforced by
`test/security/invariants/forbidden_patterns_invariant_test.rb`, including
`permit!`, CSRF bypasses, unsafe HTML helpers, thread-local request state,
ignored `rescue nil`, unsafe cross-host redirects, or direct
`Rails.logger.error` calls in authentication, audit, and security code.

Allowlist entries are allowed only for reviewed existing exceptions. Every
entry must include a reason and component responsibility. New exceptions should
be rare, should name the owning boundary, and should include a migration plan or
explicit responsibility in the reason.

## Recorder Sanitization

`Chronicle::Recorder` must remove or redact secret, OTP, token, refresh token,
access token, session id, cookie, authorization, and DPoP payloads, including
nested hashes/arrays and case variants. Raw IP and user-agent context keys are
reserved and must not be copied into recorder metadata.
