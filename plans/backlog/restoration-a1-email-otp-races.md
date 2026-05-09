# Restoration A1: Email OTP Race Condition Fixes

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/email-otp-race-condition-fixes.md`

## Goal

Eliminate races in email OTP issuance and verification. Use `update_all` for atomic counter
increments and `SELECT ... FOR UPDATE` (or equivalent) inside a transaction for consume-on-verify.

## Key surface

Email OTP service / controller pair (verification, throttling, attempt counter). The OTP model and
any OTP-related rate-limit code path.

## Verification

Concurrency tests that hit the verify path with two simultaneous attempts on the same OTP — only one
should succeed; counters and `consumed_at` must be consistent.

## Related

- `plans/backlog/security-otp-attempts-atomic-increment.md` — narrower follow-up on `locked_at`
  timestamp restoration when threshold is reached.
