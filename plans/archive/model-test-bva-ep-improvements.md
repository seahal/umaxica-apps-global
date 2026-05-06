# Model Test BVA/EP Improvements — Part A

## Summary

Existing model tests for five high-security models miss systematic boundary value analysis (BVA) and
equivalence partitioning (EP) for resource limits, column lengths, and time-based logic. This plan
adds the missing cases to existing test files without changing production code.

## Problem

The following models have test files but are missing specific boundary and equivalence cases that
matter for correctness and security:

| Model                 | Risk                                                                    | Missing cases                                                                               |
| --------------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `UserPasskey`         | WebAuthn limit bypass                                                   | below/at/above MAX (4), isolation, update-exemption, sign_count=0                           |
| `UserOneTimePassword` | TOTP limit bypass, title overflow                                       | title 32 vs 33 chars, below/at/above MAX (2), private_key exactly 1024 chars                |
| `UserSecret`          | Backup-code limit bypass, sign-in after expiry                          | name exactly 255, below/at limit, isolation, expiry boundary (inclusive/exclusive/Infinity) |
| `UserToken`           | Session count bypass, status overflow                                   | 3rd session allowed, rotated excluded from count, status col length 20/21                   |
| `StaffPasskey`        | Same as UserPasskey for staff; fragile stub prevents DB-level detection | Replace Struct stub with real DB; add full BVA                                              |

## Approach

- Modify existing test files only. No production code changes.
- Follow t_wada style: test names describe the protected invariant, not implementation steps.
- Use `freeze_time` for expiry boundary tests.
- Use `Prosopite.pause` inside multi-record setup loops.

## Detailed Cases

### `user_passkey_test.rb`

- `sign_count = 0` (lower boundary) is valid
- 3 passkeys for a user: 4th create succeeds (below limit)
- 4 passkeys for a user: 4th is the last allowed — create succeeds (at limit)
- 5th passkey for a user: create fails with limit error (above limit)
- Passkey count is per-user: one user at limit does not block another user
- Updating an existing passkey does not re-run the per-user limit check

### `user_one_time_password_test.rb`

- `title` exactly 32 chars: valid
- `title` 33 chars: invalid
- `private_key` exactly 1024 chars: valid (the DB column limit)
- 1 TOTP for a user: 2nd create succeeds (below limit)
- 2nd TOTP is the last allowed: create succeeds (at limit = MAX_TOTPS_PER_USER)
- 3rd TOTP for a user: create fails with limit error (above limit)

### `user_secret_test.rb`

- `name` exactly 255 chars: valid
- 9 secrets for a user: 10th create succeeds (below limit)
- 10th secret is the last allowed: create succeeds (at limit = MAX_SECRETS_PER_USER)
- 11th secret: create fails (above limit)
- Secret count is per-user (isolation)
- `usable_for_secret_sign_in?`: `now == expires_at` → usable (inclusive boundary)
- `usable_for_secret_sign_in?`: `now == expires_at + 1 second` → not usable
- `usable_for_secret_sign_in?`: `expires_at = Float::INFINITY` → always usable
- `verify_for_secret_sign_in!` accepts a `now:` keyword; uses it for expiry comparison

### `user_token_test.rb`

- 2 non-rotated sessions for a user: 3rd session create succeeds (below MAX_TOTAL_SESSIONS)
- Rotated tokens (rotated_at present) are not counted toward the session limit
- `status` column value exactly 20 chars: valid
- `status` column value exactly 21 chars: invalid

### `staff_passkey_test.rb`

- Replace `Struct.new(:count).new(MAX)` stub with real DB inserts
- 3 passkeys for a staff: 4th create succeeds (below limit)
- 4 passkeys for a staff: 4th is last allowed — create succeeds (at limit)
- 5th passkey for a staff: create fails with limit error (above limit)
- `sign_count = -1`: invalid

## Files Changed

- `test/models/user_passkey_test.rb` — add cases
- `test/models/user_one_time_password_test.rb` — add cases
- `test/models/user_secret_test.rb` — add cases
- `test/models/user_token_test.rb` — add cases
- `test/models/staff_passkey_test.rb` — replace stub + add cases
