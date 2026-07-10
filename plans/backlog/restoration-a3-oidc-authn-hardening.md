# Restoration A3: OIDC Authn Hardening Implementation Decisions

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/oidc-authn-hardening-implementation-decisions.md`
- `notes/oidc-authn-hardening-handoff.md`
- `notes/oidc-callback-integration-tests.md`

## Goal

Land the OIDC hardening decisions: PKCE S256 enforcement, `redirect_uri` exact-match, nonce /
`auth_time` / `acr` / `amr` / `sid` / `subject_type` claim handling.

## Key surface

Authorize endpoint, token endpoint, ID token builder, claim assemblers, callback validator. Fixtures
and integration tests for the callback path.

## Verification

OIDC callback integration tests (the ADR notes call them out specifically). All invalid-PKCE /
mismatched-redirect / replayed-code paths must reject with the correct error code.

## Adaptation notes

The issuer URL is now `https://id.<acme>` (not `sign.*`). Update issuer, discovery URL, JWKS URL
fixtures.

## Related

- `plans/backlog/restoration-g2-oidc-callback-integration-tests.md` — test coverage spin-out from
  the same ADR notes.
