# Restoration A2: Refresh / Revoke / AAL Downgrade and Replay Hardening

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`

## Goal

Block AAL downgrade on refresh; reject replays of refresh tokens; ensure revocation cascades
correctly. Tighten the refresh path so a stolen refresh token cannot be used to obtain a lower-AAL
session that bypasses step-up.

## Key surface

Refresh-token service, session model, OAuth/OIDC token endpoint, AAL evaluator.

## Verification

Integration tests that (a) attempt refresh after revoke, (b) attempt to reuse a rotated refresh
token, (c) confirm the new access token's AAL ≥ original. Audit emit on each rejection.

## Adaptation notes

The token endpoint now lives in the global repo (no `Jit::Identity`).

## Related

- `plans/backlog/gh558-refresh-token-rotation.md` — refresh token rotation with concurrency control
  (overlapping scope).
