# OIDC Token Endpoint Surface Isolation Implementation Notes

## Context

- Original plan/spec: GitHub issue #843, "OIDC: authorization code redemption is not scoped to the
  request surface".
- Related decisions/docs/plans: `.agents/harnesses/rules/project/surfaces.mdc`,
  `adr/acme-sign-core-base-port-boundary.md`, `adr/acme-session-and-token-authority.md`,
  `docs/security/oidc-discovery-profile.md`,
  `.agents/harnesses/rules/generic/no-silent-fallback.mdc`.
- Implementation date: 2026-08-28.

## Decisions Made During Implementation

- Decision: the endpoint surface is carried as `resource_type` (`"client"` / `"visitor"` /
  `"operator"`), declared as `OAUTH_RESOURCE_TYPE` on each concrete token controller and read by
  `BaseOauthTokenEndpoint`.
  - Why: `resource_type` is already the canonical surface vocabulary across `OidcIssuer`,
    `OidcClientRegistry`, `OidcSubject`, `DpopProofValidator`, and the issuance-side
    `OidcAuthorizationCodeIssuer::CLIENT_CODE_TARGETS`. No new vocabulary was introduced.
  - Alternatives considered: deriving the surface from the request host inside the coordinator, or
    from the controller module name. Both were rejected: the host is already consumed by the routing
    constraint, and re-parsing it deep in service code hides the boundary from the endpoint reader.
  - Follow-up needed: none.

- Decision: `OidcTokenExchangeCoordinator#initialize` takes `resource_type:` as a required keyword
  with no default, and `#code_lookup_target` raises `ArgumentError` on an unrecognized value.
  - Why: `no-silent-fallback` requires explicit required inputs and exhaustive branching over a
    known finite set. A default would let a future caller silently reinstate cross-surface search.
  - Alternatives considered: an optional argument defaulting to the previous fan-out, for caller
    compatibility. Rejected — that is precisely the defect.
  - Follow-up needed: none.

- Decision: `OidcRefreshTokenIssuer#find_usage` was left unchanged.
  - Why: it has the same unscoped three-database shape, but
    `grep -rn OidcRefreshTokenIssuer app/ lib/ config/` returns only its own class definition —
    there is no production caller, and `/oauth/token` accepts only the `authorization_code` grant
    (`#valid_grant_type?`), so no endpoint boundary exists to thread a surface through. The live
    browser refresh path (`Base::*::Edge::V0::Token::RefreshesController`) is already surface-scoped
    through `authentication_{client,operator,visitor}.rb`.
  - Alternatives considered: scoping it speculatively by inventing a surface parameter. Rejected as
    a speculative abstraction with no caller to define the correct value.
  - Follow-up needed: yes — if `OidcRefreshTokenIssuer` is ever wired to an endpoint, it must
    receive the endpoint's `resource_type` before use, and its hardcoded
    `ClientToken.parse_refresh_token` (used for all three surfaces' tokens) must be resolved per
    surface at the same time.

## Deviations From Plan

- Change: none of substance. The plan's open question about client authentication in the integration
  test resolved to `private_key_jwt`: `core-next-rp` is the only registered client with all three
  realms, and no client has a resolvable secret in the test environment, so the test mints a real
  client assertion per request via the receiving endpoint's own URL.
  - Why: the assertion is minted for whichever endpoint the request is sent to, so client
    authentication legitimately succeeds in the mismatch cases too. Only the surface scoping of the
    authorization-code lookup can reject them, which is what the test is meant to prove.
  - Risk: none identified; no security control was relaxed.
  - Follow-up: none.

## Review Notes

- Regression guard: the six cross-surface cases were confirmed to fail against the previous
  implementation. With `#find_code` temporarily restored to the three-database fan-out, all six
  wrong-surface redemptions returned `200 OK` with a full token response, and the new test file
  reported 7 failures; the three matching-surface cases still passed. The fan-out was then restored
  to the scoped lookup.
- Tests run: `test/services/oidc/token_exchange_service_test.rb` (61 runs);
  `test/controllers/base/oauth_token_surface_isolation_test.rb` (10 runs, new);
  `test/controllers/base/oauth_oidc_authority_test.rb` and
  `test/controllers/base/oauth_token_rate_limit_test.rb` (34 runs);
  `test/services/oidc_token_exchange_boundary_test.rb`,
  `test/security/invariants/refresh_token_reuse_invariant_test.rb`,
  `test/services/oidc_refresh_token_issuer_result_test.rb` (8 runs); `test/services/oidc` +
  `test/controllers/base` (617 runs); `test/services/oidc_*_test.rb` + `test/security` (173 runs).
  All passed with no skips.
- Tests not run: the full `bin/rails test` suite.
- Documentation promotion needed: none. `docs/security/oidc-discovery-profile.md` states that key
  selection is by surface (host); that statement describes issuance/discovery and is unaffected, so
  it was not edited. No new ADR: this implements the already-accepted boundary in
  `.agents/harnesses/rules/project/surfaces.mdc`.

## Defects Found And Not Fixed (out of scope for #843)

Reported separately rather than fixed opportunistically:

- `OidcTokenExchangeCoordinator#validate_code` returns `invalid_request` for `redirect_uri` and
  `client_id` mismatches where RFC 6749 §5.2 requires `invalid_grant`. Because an unknown code
  returns `invalid_grant`, the two are distinguishable, which is a code-existence oracle.
- The token endpoint returns `400` for `invalid_client`; RFC 6749 §5.2 requires `401` with
  `WWW-Authenticate`.
- `error_description` echoes internal lifecycle state (`already consumed`, `revoked`,
  `root session actor mismatch`) to the client.
