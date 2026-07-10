# Token Rotation Concurrency Hardening

> **Updated by the current Identity Authority boundary:** Refresh and session-token rotation
> authority belong to `sign/id`; browser/request Preference token rotation also belongs to Sign.
> External RP/OIDC provider behavior must be classified separately as retained, delegated, or
> retired.

## Status

Archived during active-plan strictness cleanup on 2026-06-14. The implemented row-locking and
device-mismatch pieces are retained as current behavior, and the remaining DB-backed overlap-window
work is deferred to `plans/backlog/db-backed-token-refresh-overlap-window.md`.

Created 2026-05-19 to replace the older GH-558 Redis/JTI-deduplication direction.

Initial implementation started 2026-05-19:

- Auth and preference rotation now share digest-row locking and device-id matching primitives
  through `RefreshTokenShared`.
- Preference single-use token consumption now uses PostgreSQL row locking before marking a row used.
- Preference rotation rejects mismatched device ids before consuming the row.
- Preference access-token `jti` is enforced against the current DB row when the row has a `jti`.
- Security-intent tests now cover stale / missing preference `jti`, invalid auth verifier without
  actor revoke, current-token device mismatch without consumption, and rotated-token replay
  precedence over device mismatch.

Deferred:

- DB-backed overlap / grace window for legitimate parallel refresh is tracked separately in
  `plans/backlog/db-backed-token-refresh-overlap-window.md`.

## Context

The application has high request throughput. Auth and preference token refresh can arrive in
parallel from multiple tabs, retries, or overlapping endpoints. The security priority is:

1. Safety first.
2. Avoid abnormal user-visible failures in legitimate parallel flows.
3. Accept some throughput reduction, DB load, or latency if that keeps the system simple and safe.

Redis, Valkey, and other external session-state stores are out of scope for this problem. Session
and token concurrency must be handled with PostgreSQL-backed state and row-level atomicity.

## External Reference Shape

Large identity providers commonly combine refresh-token rotation with overlap / leeway behavior:

- RFC 9700 requires public-client refresh tokens to use sender-constraining or refresh-token
  rotation to detect replay. If a rotated token is reused and the server cannot know which party is
  legitimate, the active refresh token is revoked.
- Okta documents two relevant behaviors:
  - access-token refresh may return the same refresh token until the configured refresh-token
    lifetime boundary is crossed;
  - rotation can have a short grace period so clients can recover when the newly issued token
    response is lost.
- Auth0 documents a rotation overlap period for concurrency and retry tolerance. Only recent overlap
  is tolerated; older-generation reuse still triggers breach detection.

Sources:

- https://www.ietf.org/rfc/rfc9700.html#section-4.14
- https://developer.okta.com/docs/guides/refresh-tokens/main/
- https://auth0.com/docs/tokens/refresh-tokens/configure-refresh-token-rotation

## Decision Direction

Use a DB-only, safety-first rotation model:

1. Auth and preference refresh should share the same conceptual rotation service.
2. Differences between auth and preference should be configuration only:
   - token model;
   - TTL / idle lifetime;
   - cookie names;
   - payload builder;
   - revoke scope.
3. A refresh operation must be atomic through PostgreSQL row locks and one transaction.
4. Redis / Valkey / cache-backed JTI deduplication must not be introduced.
5. Do not rotate access-token `jti` on every ordinary access-token reissue. That creates
   self-inflicted invalidation under parallel traffic.
6. Rotate access-token `jti` only on clear security or generation boundaries:
   - refresh-token rotation;
   - logout / explicit revoke;
   - replay / compromise handling;
   - hard session invalidation.

## Target Behavior

### Auth Refresh

- A presented refresh token identifies a token row by digest / public id.
- The refresh path locks the current row on the writing role.
- If the token is current and rotation is not due, issue a new access token without creating a new
  refresh token row.
- If rotation is due, consume the current row and create the next row in the same transaction.
- The replacement preserves `oidc_sid` and receives a fresh `oidc_jti`.
- Existing access tokens remain valid until their normal short TTL unless a security boundary
  requires revocation.

### Legitimate Parallel Refresh

Use a short DB-backed overlap window, not Redis:

- If request A rotates token generation N to N+1 and request B presents generation N immediately
  after, B may receive the already-created successor token response only when all of these are true:
  - same token family;
  - same device / binding;
  - previous token points to the successor;
  - previous token was consumed inside the configured overlap window;
  - successor is still active and not revoked / compromised.
- If any condition fails, treat it as replay and revoke according to the configured policy.

This prevents normal retries from becoming user-visible errors without allowing older stolen tokens
to remain useful.

### Replay / Compromise

- Reuse outside the overlap window is compromise.
- Reuse by a different device / binding is compromise.
- Reuse of generation N-2 or older is compromise, even if generation N-1 is still inside overlap.
- Compromise must emit security telemetry and revoke the configured scope.

The auth path may keep the current actor-wide revoke policy unless a later decision narrows it to
family-wide revoke.

### Preference Refresh

Preference refresh should stop using weaker one-off single-use behavior and move to the shared
DB-locked rotation model.

- Preference refresh tokens remain lower priority than auth tokens, but the interface should not
  have a weaker concurrency contract.
- Preference access-token `jti` must be validated against the DB current row if it is used as a
  revocation or generation marker.
- Preference TTL can remain longer than auth TTL, but the rotation and replay semantics should match
  auth.

## Non-Goals

- No Redis, Valkey, Solid Cache, or external distributed lock.
- No client-side coordination requirement.
- No "rotate access-token jti on every request" design.
- No broad database placement change for preferences.
- No weakening of replay detection to improve UX.

## Implementation Phases

### Phase 1: Contract Tests

- Completed / started:
  - preference stale access-token `jti` rejection;
  - preference missing access-token `jti` rejection when the DB row has current `jti`;
  - preference legacy blank-DB-`jti` compatibility;
  - preference mismatched-device rotation rejection without consuming the token;
  - shared row-lock helper only selects unconsumed / unexpired rows;
  - auth invalid verifier does not revoke actor tokens;
  - auth rotated-token reuse is classified as replay before device mismatch.
- Add auth concurrency tests:
  - two simultaneous refresh attempts with the same token produce one rotation and one accepted
    overlap response, or one rotation and one deterministic replay if overlap is disabled;
  - older-generation reuse revokes;
  - binding mismatch revokes;
  - revoked token stays invalid.
- Add preference concurrency tests covering the same matrix.
- Add access-token `jti` tests:
  - auth stale `oidc_jti` fails after a security/generation boundary;
  - ordinary access-token reissue does not invalidate a concurrently issued access token unless a
    security boundary occurs;
  - preference `jti` is either enforced or explicitly not treated as revocation state.

### Phase 2: Shared DB-Only Rotation Service

- Partially done: common row-lock and device-id matching primitives are in `RefreshTokenShared`.
- Remaining: a fuller shared service can be considered after the overlap-window decision.
- Preserve existing cookie and payload boundaries.

### Phase 3: DB-Backed Overlap Window

- Deferred to `plans/backlog/db-backed-token-refresh-overlap-window.md`.
- Add minimal columns only if existing state is not enough:
  - consumed/rotated timestamp;
  - successor token id;
  - optional overlap expiration timestamp.
- Prefer existing `rotated_at`, `replaced_by_id`, `refresh_token_family_id`, and generation fields
  where possible.
- Overlap must be short and server-side only.
- Do not expose overlap state to the client.

### Phase 4: Preference Alignment

- Move preference rotation onto the same DB-locked contract.
- Keep preference TTL and cookie behavior separate.
- Validate or retire preference access-token `jti` semantics so it is not misleading.

### Phase 5: Documentation

- Update `docs/security/refresh-token-rotation.md` after behavior changes land.
- Record any accepted revoke-scope decision in ADR if actor-wide vs family-wide changes.

## Open Decisions

- Exact auth rotation boundary:
  - always rotate on refresh-token grant;
  - or rotate only after a refresh-token lifetime / idle boundary.
- Exact overlap duration. Initial recommendation: 5-30 seconds.
- Auth replay revoke scope: actor-wide current behavior vs family-wide provider-style behavior.
- Whether preference access-token TTL should remain 7 days after DB `jti` enforcement is clarified.

## Supersedes

- `plans/archive/gh558-refresh-token-rotation.md` is deprecated for implementation direction because
  it proposed Redis/JTI deduplication. Keep it only as historical context.
