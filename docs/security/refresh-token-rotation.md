# Refresh Token Rotation

## Current Contract

Refresh tokens are stateful records. A successful refresh consumes the presented refresh token and
returns a newly issued token in the same family.

The active implementation is `Sign::RefreshTokenService`.

## Rotation Behavior

- Refresh token values use the `public_id.verifier` format.
- The verifier is stored only as a digest.
- Refresh runs on the writing role so row locking and updates hit the primary database.
- A valid refresh creates a new token row, increments `refresh_token_generation`, preserves
  `refresh_token_family_id`, and marks the previous row with `rotated_at`.
- Refreshed access tokens return to the default AAL context; step-up state is not sticky across
  refresh.

## Replay Behavior

Reusing an already-rotated refresh token is treated as compromise.

When replay is detected:

- the service raises `Sign::InvalidRefreshToken` with `refresh_token_reuse_detected`;
- all tokens for the same actor are revoked by setting `lapses_at`;
- `Sign::Risk::Emitter` emits `refresh_reuse_detected`;
- `Rails.event` emits `authentication.refresh.reuse_detected`;
- raw refresh verifiers are never logged.

Revoked or expired tokens remain invalid but are not treated as replay compromise by themselves.

## Grace Window Decision

There is no Redis-backed JTI deduplication or short grace window today. The security baseline is
strict one-time consume plus family-wide replay revocation.

Do not add a grace window unless a measured client retry problem proves it is necessary. If one is
added later, it must not weaken replay detection or family-wide revocation, and it must have tests
for concurrent reuse, stale-token replay, and revoked-token handling.

## Verification

Primary regression coverage:

- `test/services/sign/refresh_token_service_test.rb`
- `test/models/user_token_test.rb`
- `test/models/staff_token_test.rb`
- `test/controllers/sign/app/edge/v0/token/refreshes_controller_test.rb`
- `test/controllers/sign/org/edge/v0/token/refreshes_controller_test.rb`

Related decision record:

- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`
