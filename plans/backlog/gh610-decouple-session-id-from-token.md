# GH-610: Decouple Session Identifier Semantics from Token public_id

GitHub: #610

## Problem

Auth/session handling treats token row `public_id` as the session identifier (`sid`). This leaks
persistence-model details into JWT/OIDC semantics and blocks cleaner modeling for:

- RP sign-out vs session revoke vs global sign-out.
- Session lineage/family semantics.
- Future hard revoke using revoked `sid`/`jti`.
- Explicit OIDC `id_token` claim contracts.

## Proposed Direction

Introduce an explicit session identifier abstraction:

1. Add a dedicated session identifier field separate from token `public_id`.
2. Model session family/lineage explicitly and derive `sid` from that model.
3. Keep token `public_id` internal; expose only stable protocol-level identifiers in JWT/OIDC
   claims.

Current naming decision:

- `id` is the DB primary key.
- `public_id` is the token row public identifier used for UI/session-row operations.
- `oidc_sid` is the OIDC/JWT `sid` login-session identifier.
- `oidc_jti` is the OIDC/JWT access-token identifier for the current token row.

Align the runtime current-context API with the Actor decision:

- Expose the current login/session identifier as `Actor.authentication.login_public_id`.
- Deprecate direct `Actor.session`; the name is ambiguous with Rails session state.
- Deprecate direct `Actor.token`; if raw access-token claims are temporarily needed, keep that
  access behind `Actor.authentication.access_claims` and add typed readers for stable application
  needs.

## Acceptance Criteria

- A clear design decision is documented for what `sid` represents.
- Auth code no longer assumes token `public_id` is the protocol/session identifier.
- Revoke/refresh/logout flows use the explicit session identifier consistently.
- New application code reads the current login identifier from
  `Actor.authentication.login_public_id`, not `Actor.session`.
- Tests cover normal auth, refresh, revoke, and mismatch cases.

## Notes

Should be aligned with the in-progress OIDC/OAuth 2.1 session model work.

## Implementation Status (2026-05-19)

**Status: PARTIALLY IMPLEMENTED**

Implemented:

- Added nullable UUID `oidc_sid` and `oidc_jti` columns to `user_tokens`, `visitor_tokens`, and
  `staff_tokens`, with PostgreSQL `gen_random_uuid()` defaults for new rows.
- Access-token claim generation prefers `oidc_sid` for `sid` and `oidc_jti` for `jti`, while
  retaining token `public_id` fallback for existing tokens.
- Refresh rotation carries `oidc_sid` forward to the replacement token row and lets `oidc_jti`
  regenerate on the replacement row.
- Resolver/logout/session lookup accepts `oidc_sid` when it is UUID-shaped and keeps legacy
  `public_id` lookup for compatibility.
- Removed the legacy token-row `session_id` string columns and indexes.

Still open:

- Old rows are not backfilled; they intentionally keep using fallback until a separate operational
  backfill is approved.
- Direct `Actor.session` and `current_session_public_id` compatibility reads still exist.
- Some UI/session-row operations still use token `public_id` by design; only protocol `sid` has
  moved to `oidc_sid`.

## Improvement Points (2026-04-07 Review)

- Inventory every caller that reads or writes `sid` today before changing the contract. This issue
  touches tokens, revoke flows, and OIDC/OAuth semantics.
- Add a compatibility plan for old tokens or mixed-format sessions so rollout can happen without a
  flag day.
