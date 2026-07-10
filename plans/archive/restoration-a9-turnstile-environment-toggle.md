# Superseded: Restoration A9: Turnstile Environment Toggle

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Status

Discarded 2026-05-11. The app-level Turnstile toggle is no longer needed because test and dev can be
handled by environment-specific Turnstile credentials, and dev still needs live Turnstile behavior.

## Source

- `adr/turnstile-environment-toggle.md`

## Historical Goal

Cloudflare Turnstile was previously proposed as environment-toggleable (enabled in prod, off /
mocked in test and dev) so that tests would not depend on Cloudflare and development would not
require live keys.

## Historical Key Surface

Turnstile verifier service, an env-driven configuration shim, the controllers that gate on Turnstile
(sign-in, recovery, etc.).

## Historical Verification

Tests run without Turnstile keys; explicit test that the production-mode verifier rejects an empty
token.

## Note

This note is retained for traceability only. Do not implement the discarded toggle plan.
