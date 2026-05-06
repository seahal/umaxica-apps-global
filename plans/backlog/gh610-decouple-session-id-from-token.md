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

## Acceptance Criteria

- A clear design decision is documented for what `sid` represents.
- Auth code no longer assumes token `public_id` is the protocol/session identifier.
- Revoke/refresh/logout flows use the explicit session identifier consistently.
- Tests cover normal auth, refresh, revoke, and mismatch cases.

## Notes

Should be aligned with the in-progress OIDC/OAuth 2.1 session model work.

## Implementation Status (2026-04-07)

**Status: NOT STARTED**

`sid` is still derived from token `public_id`:

- `auth/token_claims.rb` line 37: `sid` set to `session_public_id`.
- `oidc/token_exchange_service.rb` line 97: tokens created with
  `session_public_id: token_record.public_id`.

## Improvement Points (2026-04-07 Review)

- Inventory every caller that reads or writes `sid` today before changing the contract. This issue
  touches tokens, revoke flows, and OIDC/OAuth semantics.
- Add a compatibility plan for old tokens or mixed-format sessions so rollout can happen without a
  flag day.
