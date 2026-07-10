# Restoration G2: OIDC Callback Integration Tests

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `notes/oidc-callback-integration-tests.md`

## Goal

Add the integration test set the note specifies (PKCE positive, PKCE-missing, redirect_uri mismatch,
replayed code, expired code, AAL acceptance, claim assembly).

## Key surface

`test/integration/oidc/...`.

## Verification

Each scenario has a test that fails on regression.

## Related

- `plans/backlog/restoration-a3-oidc-authn-hardening.md` — the implementation side that these tests
  cover.
