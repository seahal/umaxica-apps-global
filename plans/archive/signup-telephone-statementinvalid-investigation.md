# Investigate and fix telephone signup regression (NOT `ParameterMissing`)

## Status

**Implemented / verified 2026-05-10.** The actual reproducible failure was strict
`params.expect(:user_telephone)` / `params.expect(:customer_telephone)` handling nested telephone
form payloads as bad requests. `app` and `com` telephone signup now use safe nested parameter reads
and return validation responses instead of 400s.

## Context

After the "Rails app separation" refactor (commits `df95e1c8b`, `5716a1e2c`), telephone signup on
the `app` surface throws an exception in `Sign::App::Up::TelephonesController#create`. The
user-facing report names `ActionController::ParameterMissing`, but inspection shows the controller
already uses safe `params[:user_telephone]&.permit(...)` at line 35 — so **that exception cannot
originate inside `create` itself**. The user misclassified the exception class. The actual exception
is most likely `NoMethodError` or `NameError` raised by application code, which Rails surfaces to
the user with a generic 500.

**Outcome:** identify the real raise site, fix it, add a regression test covering the create path
end-to-end, and document the actual exception in the PR description so future reports are accurate.

## Root cause

The schema column is `user_identity_telephone_status_id` (verified in `db/principal_schema.rb` lines
606/612/718), but `app/controllers/sign/app/up/telephones_controller.rb` references
`@user_telephone.user_telephone_status_id` at lines 65, 82, 206, 284. This mismatch only "works"
when `UserTelephone` declares
`alias_attribute :user_telephone_status_id, :user_identity_telephone_status_id`.

Most probable causes, in priority order:

1. **`alias_attribute` was dropped from `UserTelephone`** during the separation refactor. Controller
   line 82
   (`@user_telephone.user_telephone_status_id = UserTelephoneStatus::UNVERIFIED_WITH_SIGN_UP`)
   raises `NoMethodError`.
2. **Status constant moved/renamed** — `UserTelephoneStatus::UNVERIFIED_WITH_SIGN_UP` no longer
   resolves, raising `NameError` at the same line.
3. **Encrypted-attribute config lost** for `Common::Otp#generate_otp_attributes` targets
   (`otp_private_key`, `otp_counter`), so `save!` raises.

## Files to investigate (then modify whichever is failing)

- `app/models/user_telephone.rb` — search for `alias_attribute` and any `_status_id` declarations.
  If `alias_attribute :user_telephone_status_id, :user_identity_telephone_status_id` is missing,
  that is the bug.
- `app/models/user_telephone_status.rb` — verify constants `UNVERIFIED_WITH_SIGN_UP` and
  `VERIFIED_WITH_SIGN_UP` resolve.
- `app/controllers/concerns/common/otp.rb` — check `generate_otp_attributes` writes valid columns on
  `UserTelephone`.
- `app/controllers/sign/app/up/telephones_controller.rb` — only modify if the alias-attribute
  approach is rejected. In that case, rename four occurrences at lines 65, 82, 206, 284 to
  `user_identity_telephone_status_id`, and audit
  `app/controllers/sign/app/in/telephones_controller.rb`,
  `app/controllers/sign/app/verification/telephones_controller.rb`, and any shared concern in
  `app/controllers/concerns/` for the same identifier.

## Implementation steps

1. **Reproduce.** Add a controller test in
   `test/controllers/sign/app/up/telephones_controller_test.rb`:

   ```ruby
   test "create succeeds with valid params and turnstile success" do
     CloudflareTurnstile.test_mode = true
     CloudflareTurnstile.test_validation_response = { "success" => true }
     assert_difference -> { UserTelephone.count } do
       post sign_app_up_telephones_url, params: {
         user_telephone: {
           raw_number: "+819012345678",
           confirm_policy: "1",
           confirm_using_mfa: "1",
         },
         "cf-turnstile-response": "stub",
       }
     end
     assert_redirected_to %r{/sign/up/telephones/.+/edit}
   end
   ```

   Run it once and **capture the exact exception class and message**. Quote the captured error in
   the PR description so the user's misclassification is corrected on record.

2. **Branch on the captured exception:**
   - **`NoMethodError: undefined method \`user_telephone_status_id=\`':** Restore
     `alias_attribute :user_telephone_status_id, :user_identity_telephone_status_id` in
     `UserTelephone`. This is the smallest blast radius.
   - **`NameError: uninitialized constant UserTelephoneStatus::UNVERIFIED_WITH_SIGN_UP`:** Locate
     the new constant location in `app/models/user_telephone_status.rb` (or seed-equivalent
     constants module) and update controller references.
   - **Encryption / `ActiveModel::EncryptedAttributeNotEncrypted` or similar:** Verify
     `UserTelephone` declares `encrypts :otp_private_key, :otp_counter` (or the project's
     equivalent) and that the schema columns exist.
   - **Anything else:** trace the stack, fix at root.

3. **Add regression coverage** for the existing-telephone branches:
   - `test "create with existing UNVERIFIED_WITH_SIGN_UP telephone of same digest cleans it up and re-issues"`
     — fixture with a `UserTelephone` of status `UNVERIFIED_WITH_SIGN_UP` with a matching
     `number_digest`; POST and assert the old record is destroyed, a new one is created, and an
     `SmsDeliveryJob` is enqueued.
   - `test "create with existing VERIFIED telephone dispatches existing-verification flow"` — expect
     redirect to `edit_sign_app_up_telephone_path` with the existing record's public_id and
     `session[:user_telephone_registration]["existing"]` set to true.

4. **Audit related call sites** if step 2 chose the rename path:
   `grep -rn 'user_telephone_status_id' app/ lib/`. Update every non-aliased reference to
   `user_identity_telephone_status_id`.

## Verification

- `bin/rails test test/controllers/sign/app/up/telephones_controller_test.rb` — green.
- `bin/rails test test/controllers/sign/app/up/` — broader run; ensure no fixture collisions.
- Manual smoke: `id.app.localhost/sign/up/telephones/new`, submit `+819012345678` with both
  checkboxes checked. Expect redirect to `/sign/up/telephones/<id>/edit` and `SmsDeliveryJob`
  enqueued (visible in `bin/jobs` log or test queue).
- PR description: quote the captured exception class from step 1 so the user's "ParameterMissing"
  framing is corrected on record.

## Out of scope

- Renaming the `user_identity_telephone_status_id` column itself (destructive migration; AGENTS.md
  forbids without explicit approval).
- Refactoring `Common::Otp` into a service object.
- Touching `Sign::Com::Up` (no telephone signup on `com`).
- Changing the form view at `app/views/sign/app/up/telephones/new.html.erb` unless step 1 reveals a
  form-side bug.
