# Sign Up / Sign In: Engine-Rollback Cleanup and SES-Cutover Verification

## Goal

Run an end-to-end smoke verification of Sign Up and Sign In on `app` and `com` surfaces after two
recent disruptive changes — the abandoned Rails engine extraction and the Resend → AWS SES
email-provider switch — and repair any defect surfaced.

## Background

Two recent changes left Sign Up / Sign In in an unverified state:

1. **Rails engine extraction was abandoned.** Commit
   `95d7a5460 [CheckPoint] destroy code which began to move rails engine` removed the in-progress
   engine work. The `engines/` directory does not exist. Code is back in
   `app/controllers/concerns/sign/`.
   - But `adr/email-provider-resend-to-amazon-ses.md:13-14` still references
     `engines/signature/app/controllers/concerns/sign/email_registrable.rb`, which is stale. The
     actual path is `app/controllers/concerns/sign/email_registrable.rb`. The ADR needs updating as
     part of this work.
   - Commit `df95e1c8b [NEW] Finalize Rails app separation` followed up by switching audit logging
     from `UserActivity` to `UserChronicle` in sign controllers; the migration may not be uniform
     across all paths.

2. **Resend → AWS SES cutover.** ADR `email-provider-resend-to-amazon-ses.md` is Accepted
   (2026-05-06) but its follow-ups are not yet confirmed:
   - SES sandbox out in production region.
   - DKIM (3 CNAMEs), SPF, DMARC on every sending domain.
   - IAM policy scoped to `ses:SendRawEmail`.
   - Bounce / complaint handling via SNS topic (replaces Resend webhooks).

Tests pass today but tests do not exercise real SMTP delivery, real SMS delivery, or full WebAuthn
ceremonies — the user explicitly noted that real-world correctness has not been checked.

## Verification Checklist

### Email OTP — `app` and `com` surfaces

1. `config/environments/development.rb` SMTP block matches the ADR
   (`address: email-smtp.<region>.amazonaws.com`, port 465, `tls: true`, `authentication: :login`,
   explicit timeouts).
2. Production env counterpart matches.
3. dev sign-up with email → OTP email actually arrives via SES.
4. ADR follow-ups (production prerequisite, document outcome here):
   - SES sandbox status.
   - DKIM 3 CNAMEs / SPF / DMARC on every sending domain.
   - IAM policy scoped to `ses:SendRawEmail`.
   - SNS bounce/complaint webhook handler exists or is filed as a follow-up.

### SMS OTP — `app` and `com` surfaces

5. dev sign-up with telephone → SMS OTP delivered, code accepted, registration completes.
6. Rate limit (5 / 60 sec, `Sign::TelephoneRegistrable:13-14`) trips on the sixth attempt.

### Passkey — `app` surface

7. `sign/app/up/passkey_registrations_controller.rb` issues a WebAuthn challenge, accepts a
   registration, persists `UserPasskey`.
8. `sign/app/in/passkeys_controller.rb` allows sign-in with the registered passkey.
9. DBSC challenge is issued alongside the passkey response when expected
   (`app/controllers/concerns/authentication/base/dbsc_helpers.rb`). Browser shows the
   `Sec-Session-Registration` mechanics.

### Activity → Chronicle migration consistency

10. `sign/com/up/emails_controller.rb:305-310` writes `UserChronicle`. Confirm.
11. grep for any remaining `UserActivity.create` / `Activity` references in sign paths and either
    migrate them or document why they remain.
12. Test fixtures: `user_chronicle_*` are loaded by sign controller tests.

### FIXME cleanup

13. `app/controllers/sign/com/application_controller.rb` — investigate
    `guest_only! # FIXME: remove this line.` and resolve (delete, document, or replace).
14. `app/controllers/sign/app/application_controller.rb` — investigate
    `include ::Preference::Adoption # FIXME: what is this?` and replace the comment with a real
    explanation or remove the include if dead.

### Documentation correction

15. Update `adr/email-provider-resend-to-amazon-ses.md:13-14` to reflect the post-engine path
    (`app/controllers/concerns/sign/email_registrable.rb`).

## Critical Files

- `app/controllers/concerns/sign/{email_registrable,telephone_registrable, staff_telephone_registrable}.rb`
- `app/controllers/sign/{app,com}/up/{emails,telephones,passkey_registrations}_controller.rb`
- `app/controllers/sign/{app,com}/in/{sessions,emails,passkeys}_controller.rb`
- `config/environments/development.rb`, `config/environments/production.rb`
- `app/mailers/email/app/registration_mailer.rb`, `app/mailers/user_mailer.rb`
- `app/controllers/sign/{app,com}/application_controller.rb`
- `adr/email-provider-resend-to-amazon-ses.md` (path correction)

## Verification

- `bin/rails test test/controllers/sign/`
- `bin/rails test test/integration/` for sign-related integration tests
- Manual E2E: every checklist item above on a dev environment with real SES SMTP creds (sandbox is
  fine for the `to:` addresses you control) and a real phone for SMS.
- Production prerequisite: items 4.a-d documented and confirmed before production cutover.

## Out of Scope

- DPoP integration (see `plans/active/gh573-dpop-controller-integration.md`).
- Encryption key rotation (`plans/active/gh533-encryption-blind-index-rotation.md`).
- Re-registration overwrite window (`plans/backlog/account-reregistration-overwrite-window.md`) —
  fixed independently.
- Apple/Google social login smoke (separate plan,
  `plans/backlog/social-login-apple-google-smoke-verification.md`).

## Related

- `adr/email-provider-resend-to-amazon-ses.md`
- `plans/backlog/restoration-a10-sign-configuration-sprint-spec.md` — earlier restoration work
  index.
- `plans/backlog/email-and-sms-not-delivering-via-request-flow.md` — overlapping concern.
