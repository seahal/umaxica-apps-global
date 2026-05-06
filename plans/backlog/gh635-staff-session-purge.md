# GH-635: Add Staff Session Purge for User, Staff, and Customer Accounts

GitHub: #635

## Current State

- Session management exists for each audience.
- Staff can already manage their own sessions in the configuration area.

## Scope

- Add a staff-facing purge action for user, staff, and customer sessions.
- Define the authorization boundary for who can purge which account type.
- Add regression tests for the allowed and denied cases.

## Out of Scope

- Self-service revoke-other-sessions flow (GH-634).
- Emergency revoke-all-sessions kill switch (GH-633).

## Implementation Status (2026-04-07)

**Status: NOT STARTED**

No staff-facing session purge controllers or actions found for user/customer sessions.

## Improvement Points (2026-04-07 Review)

- Add a policy matrix that states which staff roles may purge which actor types. This is the main
  correctness risk in the feature.
- Define the entrypoint UI and audit events together so implementation does not add a purge action
  without traceability.
