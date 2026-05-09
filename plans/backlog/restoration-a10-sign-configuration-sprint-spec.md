# Restoration A10: Sign Configuration Sprint Spec

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/sign-configuration-sprint-spec.md`

## Goal

Land the sprint spec items (multi-factor enrollment flow, recovery codes, TOTP, passkey enrollment,
etc.) into the global app.

## Key surface

`app/controllers/sign/...`, `app/views/sign/...`, the corresponding services.

## Verification

Per-flow integration tests; confirm each MFA method enrolls, verifies, and revokes cleanly.

## Adaptation notes

Path stays `sign/*` (the URL surface name is unchanged); the _hostname_ changes to `id.*`. Do not
invent a new namespace.
