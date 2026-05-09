# GH-573: DPoP Controller Integration (Phase 2 + 3)

GitHub: #573

## Status

**Active.** Phase 1 (core infrastructure) is complete; this plan scopes Phases 2 and 3.

The earlier draft claimed "NOT STARTED" (2026-04-07). That status was inaccurate — the services and
tests under `app/services/dpop/` and `test/services/dpop/` already exist and pass. What is missing
is the wiring into request handling.

## Goal

Wire the existing DPoP service layer into controllers and middleware so that DPoP-bound tokens are
issued and resource requests are enforced. Cookie-based flows continue using DBSC; this plan only
covers `Authorization: DPoP <token>` API access.

## Current State (verified 2026-05-09)

### Already implemented

- `app/services/dpop/proof_validator.rb` — RFC 9449 §4.3 proof JWT validation (ES256/ES384).
- `app/services/dpop/request_verifier.rb` — per-request orchestrator.
- `app/services/dpop/jti_replay_guard.rb` — Redis-backed JTI replay detection.
- `app/services/dpop/nonce_service.rb` — nonce issuance and verification.
- DB columns: `dpop_jkt`, `session_id` on `user_tokens`, `staff_tokens`, `customer_tokens` (3
  migrations dated 2026-05-07).
- Tests:
  `test/services/dpop/{proof_validator,request_verifier,jti_replay_guard,nonce_service}_test.rb`.
- Architecture doc: `docs/architecture/dpop.md`.

### Missing — this plan's scope

- Zero references to DPoP in `app/controllers/` or `app/middleware/` (`grep` confirmed).
- No token issuance step that requires DPoP proof and binds `cnf.jkt` into the access token.
- No resource-endpoint check that runs `Dpop::RequestVerifier`.
- No rejection of `cnf.jkt`-bound tokens presented as `Bearer` (token-theft mitigation).

## Phase 2: Token Issuance Integration

When a client requests a token using a DPoP proof header, the issued access token must carry
`cnf.jkt` set to the proof-key thumbprint. Without this binding, Phase 3 enforcement has nothing to
compare against.

Steps:

1. Identify the token-issuance code paths (`UserToken`, `StaffToken`, `CustomerToken` issuers).
2. Add a controller hook that, when the `DPoP` header is present:
   - Validates the proof via `Dpop::ProofValidator` for `htm` / `htu` / `iat` matching the issuance
     endpoint.
   - Computes the JWK thumbprint via the existing thumbprint calculator.
   - Persists/embeds the thumbprint into the issued token's `cnf.jkt` claim and the corresponding
     `*_tokens.dpop_jkt` column.
3. Maintain backwards compatibility: requests without a `DPoP` header continue to issue un-bound
   (Bearer) tokens during rollout.

## Phase 3: Resource Request Enforcement

Steps:

1. Add a `before_action` (or middleware) on protected API controllers that:
   - Detects `Authorization: DPoP <token>`.
   - Runs `Dpop::RequestVerifier` to validate the proof against the request `htm` / `htu` / `ath`
     and the JTI replay store.
   - Compares the proof key thumbprint against the token's `cnf.jkt` claim.
2. Reject `cnf.jkt`-bound tokens presented as `Bearer` with `401 invalid_token`.
3. Issue nonces (`DPoP-Nonce` response header) per `Dpop::NonceService`.
4. Define which endpoints opt in. Start with the most sensitive Authorization-header API endpoints;
   expand from there.

## Rollout Strategy

- Stage 1 — **shadow mode**: verify proofs, log mismatches via `Rails.event`, but do not reject.
  Confirm legitimate clients are unaffected.
- Stage 2 — **enforce**: reject invalid proofs with `401`. Keep the shadow log live so any late
  breakage is visible.
- Stage 3 — **mandatory**: for specifically chosen endpoints, require DPoP (no fallback to Bearer).
  Out of scope for the first ship.

## Critical Files

- Existing services: `app/services/dpop/*.rb`
- Existing tests: `test/services/dpop/*_test.rb`
- Token-issuance controllers: to be identified during Phase 2 work (likely under
  `app/controllers/concerns/authentication/base/` and OIDC token endpoints).
- Resource controllers: API endpoints that accept Bearer today.

## Open Issues

- Which protected endpoints opt into DPoP first. The principle "cookie flows use DBSC,
  Authorization-header API uses DPoP" gives the boundary, but not the per-endpoint list.
- How to surface the shadow-mode logs (Rails.event sink, OTel span attribute, both).
- Coexistence of DPoP with refresh-token rotation (`plans/backlog/gh558-refresh-token-rotation.md`).

## Verification

- All existing `test/services/dpop/*_test.rb` continue to pass.
- New controller/middleware tests:
  - Valid DPoP proof + DPoP-bound token → 200.
  - Same token presented as Bearer → 401.
  - Replayed JTI → 401.
  - Missing/expired nonce → 401 with fresh `DPoP-Nonce` response header.
- Manual dev verification: hit a protected endpoint with `Authorization: DPoP <token>` and a
  matching proof header → success. Strip the `DPoP` header → 401.

## Related

- `plans/active/gh533-encryption-blind-index-rotation.md` — independent.
- `plans/backlog/gh558-refresh-token-rotation.md` — adjacent to token issuance.
- `plans/backlog/gh625-dbsc-null-key-bypass.md` — DBSC side, complete.
- `docs/architecture/dpop.md` — design reference.
