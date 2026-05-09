# Restoration A5: OAuth 2.1 Compliance Gap Items

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/notes/oauth2-1-compliance-gap.md`

## Goal

Close the residual OAuth 2.1 gaps listed in the note (PKCE required for confidential clients too,
removal of implicit flow remnants, redirect_uri exact match, no plaintext code challenge, etc.).

## Key surface

Authorize endpoint, client model, token endpoint validators.

## Verification

A compliance-style test suite that walks through each gap item with a positive and a negative case.

## Adaptation notes

Same as A3 — single-app, `id.*` issuer.

## Related

- `plans/backlog/restoration-a3-oidc-authn-hardening.md`
