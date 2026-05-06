# GH-633: Add Emergency Revoke-All-Sessions Kill Switch

GitHub: #633

## Current State

- Per-session revoke and revoke-other flows already exist in configuration screens.
- Login flows already model restricted sessions and revocation state.

## Scope

- Add a full-session revocation path that invalidates all sessions for the targeted account.
- Define the authorization and safety checks for using the kill switch.
- Add regression tests for the emergency path and failure cases.

## Out of Scope

- Self-service revoke-other-sessions flow (GH-634).
- Staff-only purge for selected account types (GH-635).

## Implementation Status (2026-04-07)

**Status: NOT STARTED**

No controllers, actions, or revoke-all logic found. Only per-session and revoke-other flows exist.

## Improvement Points (2026-04-07 Review)

- Define the authorization and audit contract before implementing the kill switch. This is a
  high-impact action and should have explicit operator safeguards.
- Add a scope table for which actor types and token families are affected so the feature cannot be
  misread as a normal "revoke others" variant.
