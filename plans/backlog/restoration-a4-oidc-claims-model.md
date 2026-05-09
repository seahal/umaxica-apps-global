# Restoration A4: OIDC Claims Model

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/oidc-claims-decision.md`
- `adr/notes/oidc-claims-model.md`
- `adr/notes/oidc-session-model.md`

## Goal

Lock in the claims model (subject_type, sid, sub, scoped claims) and the session model that backs
it.

## Key surface

Claim assembler service, session model, ID-token JWT builder.

## Verification

Unit tests for each claim type; round-trip test that the issued ID token decodes back to the
expected claim set for representative scopes.

## Adaptation notes

None structural; this work is already single-app friendly.
