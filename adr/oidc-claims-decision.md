# OIDC Claims Decision Memo

## Status

Accepted as the current design direction.

## Decision

For OIDC-facing identity claims, the repository will use:

- `sub` as the stable subject identifier
- `subject_type` as the explicit category of subject
- `acr` as the current verification level
- `amr` as the methods actually used to establish the current authentication state

`act` is intentionally not used.

## `id_token` must claims

- `iss`
- `sub`
- `subject_type`
- `aud`
- `exp`
- `iat`
- `auth_time`
- `sid`
- `nonce`
- `acr`
- `amr`

## `id_token` should claims

- `jti`

## `subject_type`

Allowed values:

- `user`
- `staff`
- `customer`

## `acr`

Allowed product AAL boundaries are defined in `adr/authentication-assurance-level-boundaries.md`.
For the current OIDC token paths:

- post-login default is always `aal1`;
- even passkey login starts at `aal1`;
- `aal2` is granted only after explicit verification / step-up;
- refreshed access tokens downgrade to `aal1`;
- `aal3` is reserved and not currently emitted.

## `amr`

Allowed values:

- `email_otp`
- `passkey`
- `apple`
- `google`
- `passcode`
- `totp`

Rules:

- `amr` contains methods actually used
- `amr` does not contain the full set of methods available to the subject
- ordering should prefer primary sign-in method first, then later verification methods

Examples:

- `["email_otp"]`
- `["google"]`
- `["passkey"]`
- `["passcode"]`
- `["email_otp", "totp"]`
- `["google", "passkey"]`

## Difference from current implementation

At the time of writing, the repository already has partial foundations such as:

- `sid` in auth token claims
- refresh token rotation support
- verification/session state models

But the full OIDC claim contract above is not yet consistently implemented across all token paths.

Expected gaps include:

- no final `subject_type` claim rollout yet
- no final `nonce` contract consistently enforced across all OIDC callback/token paths yet
- `acr` / `amr` values not yet normalized to this memo everywhere
- `id_token`-specific behavior still needs to be aligned with these decisions

## Implementation follow-up

This memo should be treated as the design reference for the next implementation pass.
