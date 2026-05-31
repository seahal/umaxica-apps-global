# Refresh Token Rotation

## Current Contract

Refresh tokens are stateful records. A successful refresh consumes the presented refresh token and
returns a newly issued token in the same family.

The active implementation is `Sign::RefreshTokenService`.

## Rotation Behavior

- Refresh token values use the `public_id.verifier` format.
- The verifier is stored only as a digest.
- Token row `public_id`, protocol `oidc_sid`, and protocol `oidc_jti` are separate identifiers.
  JWT/OIDC `sid` is issued from `oidc_sid`; JWT/OIDC `jti` is issued from the current token row's
  `oidc_jti`.
- Refresh runs on the writing role so row locking and updates hit the primary database.
- A valid refresh creates a new token row, increments `refresh_token_generation`, preserves
  `refresh_token_family_id`, preserves `oidc_sid`, lets the replacement row receive a fresh
  `oidc_jti`, and marks the previous row with `rotated_at`.
- Refreshed access tokens return to the default `AAL1` context; step-up / `AAL2` state is not sticky
  across refresh.

## Browser Transparent Refresh

Browser controllers may run `transparent_refresh_access_token` before authentication checks. This is
only a browser HTML recovery path for expired or missing access cookies; it is not a protocol token
endpoint.

Transparent refresh is allowed only when all of the following are true:

- the request is `GET` or `HEAD`;
- the negotiated request format is HTML;
- the access-token cookie is absent;
- the refresh-token cookie is present;
- the current request has not already attempted transparent refresh.

Transparent refresh must not run for state-changing methods, JSON requests, malformed HTML-like
`Accept` headers, requests that already carry an access-token cookie, or explicit token endpoints.
Token endpoints skip the callback and use their explicit refresh actions instead.

On successful transparent refresh, the refresh token rotates using the same
`Sign::RefreshTokenService` contract as explicit refresh, new auth cookies are issued, and the
current request is marked as refreshed. On failed exchange, auth cookies are cleared and the request
continues unauthenticated.

## Replay Behavior

Reusing an already-rotated refresh token is treated as compromise.

When replay is detected:

- the service raises `Sign::InvalidRefreshToken` with `refresh_token_reuse_detected`;
- all tokens for the same actor are revoked by setting `discarded_at`;
- `Sign::Risk::Emitter` emits `refresh_reuse_detected`;
- `Rails.logger` emits `authentication.refresh.reuse_detected`;
- raw refresh verifiers are never logged.

Revoked or expired tokens remain invalid but are not treated as replay compromise by themselves.

## Grace Window Decision

There is no Redis-backed JTI deduplication or short grace window today. Redis / Valkey backed
session-state is not part of the token-rotation design. The current security baseline is strict
one-time consume plus replay revocation.

Any future grace / overlap behavior must be DB-backed, must not weaken replay detection, and must
have tests for concurrent reuse, stale-token replay, binding mismatch, and revoked-token handling.
The active design work is tracked in `plans/active/token-rotation-concurrency-hardening.md`.

## Verification

Primary regression coverage:

- `test/services/sign/refresh_token_service_test.rb`
- `test/models/user_token_test.rb`
- `test/models/staff_token_test.rb`
- `test/controllers/concerns/authentication/transparent_refresh_test.rb`
- `test/controllers/sign/app/edge/v0/token/refreshes_controller_test.rb`
- `test/controllers/sign/org/edge/v0/token/refreshes_controller_test.rb`

Related decision record:

- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`
- `adr/cookie-domain-scope-by-surface.md` — authentication tokens are host-only; cross-subdomain SSO
  is carried by the apex-scoped preference refresh token.

Related behavior reference:

- `docs/security/cookie-domain-scope.md`
