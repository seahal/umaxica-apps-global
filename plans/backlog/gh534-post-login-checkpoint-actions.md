# GH-534: Implement Meaningful Checkpoint Actions for Post-Login Gate

GitHub: #534

## Current State

- Every login flow calls `issue_checkpoint!` and redirects to the checkpoint page.
- The checkpoint `kind` defaults to `"mock"` — no caller passes a specific kind.
- The "update" button only refreshes the timestamp with no real side effect.
- View text is placeholder.

## Intended Purpose

The checkpoint is a centralized interstitial gate for post-login requirements:

- MFA enrollment prompts.
- Terms of service re-acceptance.
- Forced password change.
- Compliance notices.

## Requirements

1. Define concrete checkpoint `kind` values (e.g., `mfa_enrollment`, `terms_acceptance`,
   `password_change`).
2. Implement conditional checkpoint issuance — only when there is an actionable requirement.
3. Implement real side effects for each checkpoint kind.
4. Skip the checkpoint entirely when no requirements are pending.
5. Apply to both app (user) and org (staff) flows.

## Affected Files

- `app/controllers/sign/app/in/checkpoints_controller.rb`
- `app/controllers/sign/org/in/checkpoints_controller.rb`
- `app/controllers/concerns/auth/base.rb`
- `app/views/sign/app/in/checkpoints/show.html.erb`
- `app/views/sign/org/in/checkpoints/show.html.erb`

## Implementation Status (2026-04-07)

**Status: NOT STARTED**

Checkpoint controllers do not exist at the expected paths. The feature appears as `issue_bulletin!`
in `authentication/base.rb` line 374 with `kind: "mock"` as default. No real checkpoint kinds are
implemented.

## Improvement Points (2026-04-07 Review)

- Add the exact checkpoint contract: trigger conditions, allowed actions, and exit criteria. The
  current file list is not enough to validate behavior.
- Add acceptance tests for both app and org sign-in flows so checkpoint behavior is verified through
  real redirects instead of inferred from controller structure.
