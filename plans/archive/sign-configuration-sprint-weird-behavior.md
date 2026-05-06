# Sign Configuration Sprint - Weird Behavior Analysis (2026-02-06)

## 1) SMS OTP could establish login without passkey

- What was weird:
  - `DELETE /up/telephones/:id` logged in the user even though SMS flow is supposed to require
    passkey registration.
- Repro:
  1. Complete SMS verification so `user_telephone_status_id = VERIFIED_WITH_SIGN_UP`.
  2. Call `DELETE /up/telephones/:id`.
  3. Session is established without passkey.
- Cause:
  - `Sign::App::Up::TelephonesController#destroy` updated user status + created token
    unconditionally.
- Fix:
  - `destroy` now sets the passkey registration session and redirects to `/up/passkeys/new`.
  - Full login is only granted after passkey registration.
- Regression tests:
  - `test/controllers/sign/app/up/telephones_controller_test.rb`
    - "should require passkey registration on destroy when verified"
    - "should log in after sms verification when passkey already exists"

## 2) Passkey edit/show pages were scaffold placeholders and used numeric IDs

- What was weird:
  - `/configuration/passkeys/:id/edit` and `show` rendered placeholder scaffolds and leaked numeric
    IDs.
- Repro:
  1. Visit edit/show page for an existing passkey.
  2. Placeholder content appears; URL uses numeric id.
- Cause:
  - Scaffolded views left in place and routes used default `:id` param.
- Fix:
  - Routes now use `param: :public_id`.
  - Edit/show views updated with real UI and public_id-based links.
- Regression tests:
  - `test/controllers/sign/app/configuration/passkeys_controller_test.rb`
    - edit/update/destroy by public_id
    - other user public_id returns 404
    - index link uses public_id

## 3) Unlink/disable could lock users out

- What was weird:
  - Email/telephone/secret removal lacked last-method checks and audit logging.
- Repro:
  1. User has only one login method (email or telephone or secret).
  2. Remove it via configuration.
  3. User is locked out; no audit trail.
- Cause:
  - No shared guard for “last authentication method” and no unlink audit.
- Fix:
  - Added `AuthMethodGuard` to enforce at least one remaining method.
  - Added audit events for email/telephone/social unlink.
  - Added step-up requirement for secret disable/destroy.
- Regression tests:
  - `test/controllers/sign/app/configuration/emails_controller_test.rb`
    - destroy succeeds with another method
    - destroy blocked when last method
  - `test/controllers/sign/app/configuration/telephones_controller_test.rb`
    - destroy succeeds with another method
    - destroy blocked when last method

## 4) Emergency key not issued after passkey registration

- What was weird:
  - Passkey registration completed without issuing an emergency key.
- Repro:
  1. Complete passkey registration.
  2. No recovery key is created or displayed.
- Cause:
  - Missing issuance flow after passkey registration.
- Fix:
  - Added `UserSecrets::IssueRecovery` and `EmergencyKeysController`.
  - Passkey registration now issues a recovery secret and redirects to one-time display.
- Regression tests:
  - `test/controllers/sign/app/up/passkeys_controller_test.rb`
    - passkey registration issues emergency key and logs in
