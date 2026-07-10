# GH-573: DPoP Controller Integration (Phase 2 + 3)

GitHub: #573

## Status

**Implemented 2026-05-10.** Phase 1 (core infrastructure), Phase 2 token issuance integration, and
the first Phase 3 protected resource enforcement path are complete.

The earlier draft claimed "NOT STARTED" (2026-04-07). That status was inaccurate — the services and
tests under `app/services/dpop/` and `test/services/dpop/` already exist and pass. What is missing
is the wiring into request handling.

## Goal

Wire the existing DPoP service layer into controllers and middleware so that DPoP-bound tokens are
issued and resource requests are enforced. Cookie-based flows continue using DBSC; this plan only
covers `Authorization: DPoP <token>` API access.

## Current State (verified 2026-05-10)

### Implemented

- `app/services/dpop/proof_validator.rb` — RFC 9449 §4.3 proof JWT validation (ES256/ES384).
- `app/services/dpop/request_verifier.rb` — per-request orchestrator.
- `app/services/dpop/jti_replay_guard.rb` — Redis-backed JTI replay detection.
- `app/services/dpop/nonce_service.rb` — nonce issuance and verification.
- DB columns: `dpop_jkt`, `session_id` on `user_tokens`, `staff_tokens`, `customer_tokens` (3
  migrations dated 2026-05-07).
- Tests:
  `test/services/dpop/{proof_validator,request_verifier,jti_replay_guard,nonce_service}_test.rb`.
- Architecture doc: `docs/architecture/dpop.md`.
- OIDC token issuance controllers forward the `DPoP` header and request metadata into
  `Oidc::TokenExchangeService`.
- Login token issuance validates present DPoP proof headers, stores the proof JWK thumbprint in
  `*_tokens.dpop_jkt`, and embeds it in the JWT `cnf.jkt` claim.
- `Auth::CurrentResourceResolver` enforces DPoP-bound access tokens for Authorization-header
  resource requests.
- `sign/app/edge/v0/token/check` and `sign/org/edge/v0/token/check` reject DPoP-bound tokens
  presented as Bearer and return a fresh `DPoP-Nonce` on DPoP failures.

## Phase 2: Token Issuance Integration

When a client requests a token using a DPoP proof header, the issued access token must carry
`cnf.jkt` set to the proof-key thumbprint. Without this binding, Phase 3 enforcement has nothing to
compare against.

Completed steps:

1. Identify the token-issuance code paths (`UserToken`, `OperatorToken`, `CustomerToken` issuers).
2. Add a controller hook that, when the `DPoP` header is present:
   - Validates the proof via `Dpop::ProofValidator` for `htm` / `htu` / `iat` matching the issuance
     endpoint.
   - Computes the JWK thumbprint via the existing thumbprint calculator.
   - Persists/embeds the thumbprint into the issued token's `cnf.jkt` claim and the corresponding
     `*_tokens.dpop_jkt` column.
3. Maintain backwards compatibility: requests without a `DPoP` header continue to issue un-bound
   (Bearer) tokens during rollout.

## Phase 3: Resource Request Enforcement

Completed steps:

1. Add a `before_action` (or middleware) on protected API controllers that:
   - Detects `Authorization: DPoP <token>`.
   - Runs `Dpop::RequestVerifier` to validate the proof against the request `htm` / `htu` / `ath`
     and the JTI replay store.
   - Compares the proof key thumbprint against the token's `cnf.jkt` claim.
2. Reject `cnf.jkt`-bound tokens presented as `Bearer` with `401 invalid_token`.
3. Issue nonces (`DPoP-Nonce` response header) per `Dpop::NonceService`.
4. First opt-in endpoints are the app and org `/edge/v0/token/check` APIs. Additional protected
   Authorization-header APIs should use the same authentication resolver path before accepting
   DPoP-bound tokens.

## Rollout Strategy

- Stage 1 — **shadow mode**: skipped for the first narrow opt-in endpoints because controller tests
  cover valid and invalid DPoP-bound access.
- Stage 2 — **enforce**: active for DPoP-bound Authorization-header requests handled through
  `Auth::CurrentResourceResolver`.
- Stage 3 — **mandatory**: for specifically chosen endpoints, require DPoP (no fallback to Bearer).
  Out of scope for the first ship.

## Critical Files

- Existing services: `app/services/dpop/*.rb`
- Existing tests: `test/services/dpop/*_test.rb`
- Token issuance:
  - `app/controllers/concerns/authentication/base.rb`
  - `app/controllers/sign/app/tokens_controller.rb`
  - `app/controllers/sign/org/tokens_controller.rb`
  - `app/controllers/sign/com/tokens_controller.rb`
  - `app/services/oidc/token_exchange_service.rb`
- Resource enforcement:
  - `app/services/auth/current_resource_resolver.rb`
  - `app/controllers/sign/app/edge/v0/token/checks_controller.rb`
  - `app/controllers/sign/org/edge/v0/token/checks_controller.rb`

## Open Issues

- How to surface the shadow-mode logs (Rails.event sink, OTel span attribute, both).
- Coexistence of DPoP with refresh-token rotation (`plans/backlog/gh558-refresh-token-rotation.md`).
- Expanding enforcement to additional protected Authorization-header endpoints beyond the current
  app/org token check APIs.

## Verification

- All existing `test/services/dpop/*_test.rb` continue to pass.
- New controller/middleware tests:
  - Valid DPoP proof + DPoP-bound token → 200.
  - Same token presented as Bearer → 401.
  - Missing proof → 401 with fresh `DPoP-Nonce` response header.
  - Wrong `ath` → 401 with fresh `DPoP-Nonce` response header.
- Manual dev verification: hit a protected endpoint with `Authorization: DPoP <token>` and a
  matching proof header → success. Strip the `DPoP` header → 401.

2026-05-10 verification:

- `bin/rails test test/controllers/concerns/authentication/base_coverage_test.rb test/controllers/sign/app/edge/v0/token/checks_controller_test.rb test/controllers/sign/org/edge/v0/token/checks_controller_test.rb test/controllers/sign/app/tokens_controller_test.rb test/controllers/sign/org/tokens_controller_test.rb test/controllers/sign/com/tokens_controller_test.rb test/services/oidc/token_exchange_service_test.rb`
  passed: 84 runs, 317 assertions.

## Related

- `plans/active/gh533-encryption-blind-index-rotation.md` — independent.
- `plans/backlog/gh558-refresh-token-rotation.md` — adjacent to token issuance.
- `plans/backlog/gh625-dbsc-null-key-bypass.md` — DBSC side, complete.
- `docs/architecture/dpop.md` — design reference.
