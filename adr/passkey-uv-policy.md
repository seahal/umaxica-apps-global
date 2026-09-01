# Centralize Passkey User Verification Policy in a Purpose-Specific Closed Registry

## Status

Partially superseded (2026-08-31)

The purpose-specific UV registry remains accepted. Only the historical implication that a UV
ceremony is automatically AAL2-equivalent is superseded by the independent step-up and
achieved-assurance policy in `docs/security/authentication-assurance-levels.md`.

## Context

WebAuthn `userVerification` previously accepted arbitrary strings, including `"preferred"` and
`"discouraged"`, in individual controllers. This allowed direct sign-in to accept assertions without
user verification (UV). The redesign changed every ceremony to `required`, and a static regression
test prohibited `preferred` and `discouraged`. The value nevertheless remained a string constant
inside the verifiers, with no place to express the requirement that ordinary sign-in stay strict
while step-up may eventually use a different policy.

The confirmed requirements are:

- Direct sign-in requires the same device-side identity verification as registration.
- Step-up must not automatically inherit direct sign-in policy without an explicit decision.

## Decision

- Introduce `Webauthn::UvPolicy`, a closed registry with entries for `registration`,
  `direct_sign_in`, `mfa_challenge`, `ordinary_step_up`, and `high_risk_step_up`. **Every purpose is
  currently `required`**, so behavior does not change.
- `RegistrationVerifier` and `AssertionVerifier` accept `purpose:` and use `UvPolicy` to resolve
  both the client option and server-side enforcement: `user_verification: true` plus explicit
  `user_verified?` and `user_present?` checks. Call sites must not supply UV strings directly; a
  static regression test enforces this boundary.
- A future relaxation may change only the `ordinary_step_up` registry entry. A ceremony without UV
  must not be recorded as AAL2-equivalent, and the change must update this ADR and
  `docs/security/webauthn-security-invariants.md`.

## Consequences

- UV guarantees for direct sign-in, MFA, step-up, and registration are centralized, making a policy
  change an intentional one-location diff.
- A future lower-friction step-up policy can be implemented without affecting sign-in.
- Verification: `test/services/webauthn/verifier_uv_policy_test.rb` rejects UV=false for every
  purpose using a real-cryptography fake client, and
  `test/unit/security/webauthn_invariants_test.rb` provides static guards.
