# Restoration H1: `TRUSTED_ORIGINS` for `localhost` (Audit Critical)

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/audit/audit-findings-2026-03-30.md` (Critical finding)
- `adr/notes/env-trusted-origins.md`

## Goal

Dev / test must populate `TRUSTED_ORIGINS` correctly for the new `id.*` and `www.*` hosts, and
`localhost` is allow-listed only in dev.

## Key surface

Environment loading, `config/initializers/...` that configures `TRUSTED_ORIGINS`, dev fixtures, CI
env.

## Verification

WebAuthn registration / authentication ceremonies succeed in dev against the new hostnames;
production rejects an unknown origin.

## Adaptation notes

Shape this for the current app hosts (`id.*`, `www.*`).
