# Restoration A6: Token Endpoint CSRF / Hardening (gh611)

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/notes/gh611-harden-token-endpoints-csrf.md`
- GitHub: #611

## Goal

Ensure token endpoints have correct CSRF posture (none for `application/json` token endpoints
invoked by clients; CSRF on browser-driven endpoints), and the hardening described in the note (rate
limit, locked client auth, etc.).

## Key surface

Token controller, application controller CSRF posture, rate-limit middleware / service.

## Verification

Tests for both legitimate client calls and CSRF replay attempts. Confirm `protect_from_forgery`
posture matches the design.
