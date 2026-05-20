# Restoration A7: Self-Service Session Revoke (gh634)

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `notes/gh634-self-service-revoke-sessions.md`
- GitHub: #634

## Goal

A signed-in user can list their active sessions and revoke any of them (including current).
Revocation must invalidate refresh tokens and any cached AAL.

## Key surface

A "sessions" view under the account/security area; the session model; session revoke service.

## Verification

UI and controller tests that list sessions and revoke one; integration test that the revoked session
cannot perform any subsequent authenticated action.

## Related

- `plans/backlog/gh633-emergency-revoke-all-sessions.md` — admin/emergency kill-switch counterpart
  (different scope).
- `plans/backlog/gh635-staff-session-purge.md` — staff-side bulk purge counterpart.
