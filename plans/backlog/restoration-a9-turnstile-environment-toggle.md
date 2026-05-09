# Restoration A9: Turnstile Environment Toggle

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/turnstile-environment-toggle.md`

## Goal

Cloudflare Turnstile is environment-toggleable (enabled in prod, off / mocked in test and dev) so
that test runs do not depend on Cloudflare and dev does not require live keys.

## Key surface

Turnstile verifier service, an env-driven configuration shim, the controllers that gate on Turnstile
(sign-in, recovery, etc.).

## Verification

Tests run without Turnstile keys; explicit test that the production-mode verifier rejects an empty
token.
