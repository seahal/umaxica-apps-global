# GH-573: Add DPoP (RFC 9449) Proof-of-Possession for JWT Auth Access Tokens

GitHub: #573

## Summary

Add DPoP support to bind access tokens to a client-generated key pair, requiring proof-of-possession
on every request.

## Scope

- **Authorization header API access only** — cookie-based flows continue using DBSC.
- **Opt-in** — activated when client sends `Authorization: DPoP <token>` + `DPoP` header.
- **No database migrations** — DPoP state lives in JWT `cnf.jkt` claim + Redis (nonce/JTI replay).

## Design

- Client generates ES256/ES384 key pair.
- Token issuance: Client sends DPoP proof JWT, server binds token via `cnf.jkt` claim.
- Resource request: Client sends `Authorization: DPoP <token>` + fresh proof with `ath` hash.
- Server validates: proof signature, thumbprint match, `ath` match, method/URI match, JTI replay.

## Key Decisions

- Token with `cnf.jkt` sent as `Bearer` is rejected (prevents stolen token reuse).
- ES256 and ES384 only (no RSA).
- Time-limited nonces (5min TTL in Redis).
- JTI replay prevention via Redis `SET NX EX`.

## Implementation Phases

### Phase 1: Core Infrastructure (new files, no behavioral change)

- `lib/jit/security/jwt/thumbprint_calculator.rb`
- `app/services/dpop/jti_replay_guard.rb`
- `app/services/dpop/nonce_service.rb`
- `app/services/dpop/proof_validator.rb`
- `app/services/dpop/request_verifier.rb`

### Phase 2: Token Issuance Integration

### Phase 3: Resource Request Enforcement

## Implementation Status (2026-04-07)

**Status: NOT STARTED**

No references to "dpop" or "DPoP" found in app/services/ or lib/.

## Improvement Points (2026-04-07 Review)

- Define the exact protocol contract first: supported proof algorithms, nonce policy, replay store,
  and which endpoints require DPoP.
- Split issuance work from protected-resource enforcement. Those phases have different rollout risk
  and should not share one acceptance gate.
