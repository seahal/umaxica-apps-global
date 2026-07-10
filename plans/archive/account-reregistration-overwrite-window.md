# Account Re-registration Overwrite Window

## Goal

Make the "overwrite an unverified account on duplicate sign-up, protect a verified one" rule
explicit and uniform across `app` and `com` surfaces, for both Email and Telephone, with a
**dedicated 10-second re-registration window** that is independent of the OTP send cooldown.

`org` is out of scope (user instruction).

## Status

**Implemented 2026-05-10.**

**Superseded detail, 2026-05-11:** the original app email implementation treated completed
registered emails as an "existing-email verification" branch. The current requirement is stricter:
only `UNVERIFIED_WITH_SIGN_UP` may enter the re-registration overwrite path. Completed identifiers
such as `VERIFIED` and `VERIFIED_WITH_SIGN_UP` are rejected by sign-up validation instead of being
redirected through a pending sign-up verification flow. See
`docs/spec/authentication-authorization-requirements-phase-1.md`.

## Background

- The Email side already implements the core rule in `Sign::EmailRegistrable`
  (`app/controllers/concerns/sign/email_registrable.rb:81-141`):
  - `remove_existing_unverified_emails!` (lines 205-221) deletes existing `UNVERIFIED_WITH_SIGN_UP`
    records before creating a new one.
  - `dispatch_existing_email_verification!` (lines 237-242) redirects to existing-email verification
    when the duplicate is **not** unverified — the verified-account overwrite-protection.
  - The "window" is currently the OTP send cooldown
    (`Common::OtpPolicy::SEND_COOLDOWN = 30.seconds`, `app/lib/common/otp_policy.rb:6`), used in
    `email_registrable.rb:105-119`.
- The Telephone side is **different**: `Sign::TelephoneRegistrable`
  (`app/controllers/concerns/sign/telephone_registrable.rb:19-56`) is scoped to the current user
  (`user.user_telephones`), not a cross-user sign-up flow. It has IP-based rate limiting (5 / 60
  sec) but no per-record overwrite-window cooldown.
- The `com` surface diverges further: `app/controllers/sign/com/up/emails_controller.rb` does
  **not** include `Sign::EmailRegistrable`. It implements the email sign-up flow directly with its
  own session keys (`SESSION_KEY`, `EXISTING_EMAIL_SESSION_KEY`,
  `EXISTING_EMAIL_SKIP_OTP_SESSION_KEY`, `PENDING_CUSTOMER_ID_SESSION_KEY` at lines 12-15) and
  operates on `CustomerEmail`. The overwrite/window semantics there must be audited and aligned.

## Requirements

1. **Verified account → cannot be overwritten.** Sign-up against an already-verified email or phone
   redirects to the existing-account verification path. Already implemented for the app email path;
   verify and replicate everywhere else.
2. **Unverified account, outside the window → overwrite + reissue token.** The earlier pending
   record (and its pending User/Customer) is destroyed; a fresh record is created with a
   freshly-issued OTP/token. Already implemented for the app email path.
3. **Unverified account, inside the 10-second window → reject with `:cooldown`.** Prevents
   rapid-fire overwrite attacks.
4. **Window length: 10 seconds**, independent of `SEND_COOLDOWN`. Reason: 30 seconds is tied to "do
   not spam OTPs"; the overwrite gate is a separate concept and should be tunable independently.

## Critical Files

- `app/lib/common/otp_policy.rb:6` — add `REREGISTRATION_OVERWRITE_WINDOW = 10.seconds` alongside
  `SEND_COOLDOWN`.
- `app/controllers/concerns/sign/email_registrable.rb:105-119` — replace `otp_cooldown_active?` gate
  with a new method that checks the 10-second window (e.g., `reregistration_window_active?` on the
  model concern).
- `app/models/concerns/email.rb:91-101` — add `reregistration_window_active?` next to
  `otp_cooldown_active?`. Same for `app/models/concerns/telephone.rb`.
- `app/controllers/sign/com/up/emails_controller.rb` — audit overwrite/window behavior, align with
  the rule. Decide whether to extract shared logic (do not refactor speculatively; only what this
  plan needs).
- `app/controllers/sign/com/up/telephones_controller.rb` — same audit.
- `app/controllers/concerns/sign/telephone_registrable.rb` — extend with cross-user
  unverified-overwrite logic if missing for the sign-up entry point. Verify scope: staff path
  (`Sign::OperatorTelephoneRegistrable`) is out.
- Status models referenced: `app/models/user_email_status.rb`, `customer_email_status.rb`,
  `user_telephone_status.rb`, `customer_telephone_status.rb` — confirm `UNVERIFIED_WITH_SIGN_UP` (or
  equivalent) is the only state eligible for overwrite.

Implementation notes:

- `Common::OtpPolicy::REREGISTRATION_OVERWRITE_WINDOW = 10.seconds` is separate from
  `SEND_COOLDOWN = 30.seconds`.
- Email records use `otp_last_sent_at` for the overwrite window.
- Telephone signup records do not all have `otp_last_sent_at`; telephone overwrite protection uses
  the record timestamp when the OTP timestamp column is unavailable.
- Existing verified email/telephone records dispatch the existing-account verification path and are
  not overwritten.

## Test Plan

Extend `test/controllers/sign/{app,com}/up/emails_controller_test.rb` and add a parallel suite for
telephone. Cases:

- Verified record exists → POST sign-up → existing-email verification path; original record
  untouched; no new token issued.
- Unverified record older than 10 seconds → POST sign-up → record replaced; new OTP delivered; old
  token invalidated.
- Unverified record within 10 seconds → POST sign-up → response is `:cooldown`; no record
  replacement; no new OTP delivered.
- Same three cases for `app` and `com`.
- Same three cases for telephone (assuming the cross-user overwrite is added).

## Verification

- `bin/rails test test/controllers/sign/{app,com}/up/`
- Manual dev: sign up with the same address twice within 10 sec → second attempt rejected; wait 11
  sec and retry → succeeds, replaces previous, sends fresh OTP.

2026-05-10 automated verification:

- `bin/rails test test/controllers/sign/app/up/emails_controller_test.rb test/controllers/sign/com/up/emails_controller_test.rb test/controllers/sign/app/up/telephones_controller_test.rb test/controllers/sign/com/up/telephones_controller_test.rb test/models/concerns/email_test.rb test/models/concerns/telephone_test.rb`
  passed: 145 runs, 599 assertions.

## Out of Scope

- `org` / staff sign-up flows.
- Identity merging (linking two accounts that turn out to be the same person).
- Audit-logging changes; that is `plans/backlog/sign-up-in-engine-rollback-and-ses-verification.md`.

## Related

- `adr/email-otp-race-condition-fixes.md` — adjacent atomicity work; do not regress its invariants.
- `plans/backlog/restoration-a1-email-otp-races.md` — tangential, OTP race; check no conflict on
  `otp_last_sent_at` semantics.
