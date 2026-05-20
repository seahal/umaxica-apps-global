# Sign Configuration Sprint Spec (2026-02-06)

This document fixes the remaining ambiguous points and is the source of truth for this sprint.

## 1. SMS + Passkey Required (Login Establishment)

### Adopted spec: A (no full login until passkey is completed)

- SMS OTP verification **does not** establish a full session by itself.
- After SMS OTP success, the user **must** complete passkey registration before a session is
  created.
- If a user already has an active passkey, SMS OTP success can complete login immediately.

### Flow summary

1. SMS OTP verified successfully.
2. If user has **no active passkey**:
   - set `session[:signup_passkey_registration]` (user_id + expires_at)
   - redirect to `/up/passkeys/new`.
3. Passkey registration completes:
   - creates passkey
   - issues passcode
   - establishes login session
   - redirects to passcode display page

### OTP resend (SMS)

- Resend is allowed even if the telephone record is missing or unverified (no existence leak).
- Rate limit: 60s cooldown per session for resend attempts.
- Response is generic on success; rate-limited responses use a generic cooldown message.

## 2. Unlink / Disable Conditions (Social / Email / Telephone / Passcode)

### Common guards (applies to all unlink/disable actions)

- **Recent StepUp required**: use the existing step-up gate (`Verification::Base::STEP_UP_TTL`,
  currently 15 minutes).
- **No lockout**: after removal, the user must still have **at least one** remaining authentication
  method.
- “Last method” removal is rejected with a user-facing error.
- Audit log entry is required for each unlink/disable action.

### What counts as an authentication method

- Email: `UserEmailStatus::VERIFIED` or `VERIFIED_WITH_SIGN_UP`.
- Telephone: `UserTelephoneStatus::VERIFIED` or `VERIFIED_WITH_SIGN_UP`.
- Passkey: `UserPasskeyStatus::ACTIVE`.
- Passcode: `UserSecretStatus::ACTIVE`.
- Social: Google/Apple identities in `ACTIVE` status.

### Telephone unlink interpretation

- Telephone is not mandatory.
- If removed, it is considered **SMS login disabled** for that user.

### Passcode disable rules

- `enabled=false` or destroy is treated as unlink and is guarded by the same rules.

## 3. Passcode (Issued After Passkey Registration)

### Adopted spec

- After a passkey is registered, a passcode is issued automatically.
- Stored in DB as a `UserSecret` with `user_secret_kind_id = RECOVERY` and **hashed** (never
  plaintext).
- Plaintext is shown **only once** on a dedicated page, then removed from session.
- Re-issuing invalidates prior active passcodes (set to `REVOKED`).
- Audit log:
  - Issue/re-issue: `UserAuditEvent::RECOVERY_CODES_GENERATED`.
  - Use: `UserAuditEvent::RECOVERY_CODE_USED` (when used to authenticate).

## 4. Withdrawal (2-way only)

### Adopted spec (based on current implementation + tests)

- Two-way model is **“withdraw (reversible)” ↔ “recover”** within a fixed recovery window.
- Permanent deletion is **not** available via UI in this sprint.
- `/configuration/withdrawal` should present **only the reversible path**.
- If permanent deletion is needed later, it must be moved to a separate flow (support or delayed
  job).

### Behavior

- Withdraw sets `withdrawn_at` and `status_id = PRE_WITHDRAWAL_CONDITION`.
- Recovery clears `withdrawn_at` if within `Withdrawable::WITHDRAWAL_RECOVERY_PERIOD` (30 days).
- Withdrawal gate confines users in PRE_WITHDRAWAL status to the withdrawal page until recovered.

## 5. public_id Boundary

- In configuration area, `totps`, `passkeys`, and `secrets` must use `public_id` in routes and
  lookup.
- `UserPasskey` must be upgraded to include a `public_id` (string, 21 chars, unique).
