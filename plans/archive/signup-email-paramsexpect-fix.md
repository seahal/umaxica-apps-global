# Fix `ParameterMissing` regression in `Sign::App::Up::EmailsController#create`

## Status

**Implemented / verified 2026-05-10.** `app` and `com` email signup now use safe nested parameter
reads, handle missing email params as validation failures, and validate Turnstile before parsing the
form payload.

## Context

After the "Rails app separation" refactor (commits `df95e1c8b`, `5716a1e2c`), the `app` surface
email signup form returns HTTP 400 (`ActionController::ParameterMissing`) before Cloudflare
Turnstile validation even runs. End users cannot register an email address. The form at
`app/views/sign/app/up/emails/new.html.erb` only submits `:raw_address` and `:confirm_policy`;
`:address` is intentionally absent — it is derived server-side from `raw_address` inside
`Sign::EmailRegistrable#initiate_email_verification!`.

The companion `Sign::Com::Up::EmailsController#create` is structured identically against
`:customer_email` and must be fixed in the same change. Telephone already uses the safe
`params[:user_telephone]&.permit(...)` pattern; emails should mirror it.

The user originally suspected Turnstile, but Turnstile is healthy — the strict-params check raises
before Turnstile is reached.

**Outcome:** signup succeeds when the form submits `:raw_address` and `:confirm_policy`; Turnstile
failure renders the form with a friendly i18n error rather than a 400.

## Root cause

`app/controllers/sign/app/up/emails_controller.rb:41`:

```ruby
email_params = params.expect(user_email: %i(raw_address address confirm_policy))
```

Rails 8 strict `params.expect` requires every listed key. The form omits `:address`, so
`ActionController::ParameterMissing` raises synchronously at action entry, **before**
`cloudflare_turnstile_validation` (line 44) is reached. The same anti-pattern lives in
`app/controllers/sign/com/up/emails_controller.rb` against `:customer_email`.

## Files to modify

- `app/controllers/sign/app/up/emails_controller.rb` (line 41) — replace `params.expect(...)` with
  safe permit; reorder Turnstile check above param parsing.
- `app/controllers/sign/com/up/emails_controller.rb` — apply the identical change against
  `:customer_email`.
- `config/locales/sign/app/up/emails.en.yml`, `.ja.yml` — add
  `sign.app.registration.email.create.address_required` (mirror in `com` locales).
- `test/controllers/sign/app/up/emails_controller_test.rb` — add three test cases (see
  Implementation step 5).
- `test/controllers/sign/com/up/emails_controller_test.rb` — mirror the three test cases.

## Implementation steps

1. **Reorder Turnstile check.** In `Sign::App::Up::EmailsController#create`, move the Turnstile
   validation block to the top of the action, before any strong-param call. If Turnstile fails,
   build `@user_email = UserEmail.new` (no parsed address available), add base error
   `sign.app.registration.email.create.turnstile_failed`, and
   `render :new, status: :unprocessable_content`.

2. **Replace `params.expect` with safe permit.** After Turnstile passes:

   ```ruby
   email_params = params[:user_email]&.permit(:raw_address, :address, :confirm_policy) ||
     ActionController::Parameters.new.permit!
   email_address = email_params[:raw_address].presence || email_params[:address].presence
   ```

3. **Handle blank address.** If `email_address` is blank, build `@user_email = UserEmail.new`, add
   base error `sign.app.registration.email.create.address_required` (new i18n key — add to
   `config/locales/sign/app/up/emails.en.yml` and `.ja.yml`), render `:new` with
   `:unprocessable_content`.

4. **Apply the same three transformations to `Sign::Com::Up::EmailsController#create`** against the
   `:customer_email` key. Keep `complete_customer_email_verification!` semantics intact. Add
   parallel locale keys under `sign.com.registration.email.create.*`.

5. **Tests** (Minitest, `IntegrationTest`, fixtures only — no factories):
   - `test "create renders unprocessable when user_email param missing"` — POST with empty body;
     Turnstile stubbed `success`. Expect `:unprocessable_content` and the address-required base
     error.
   - `test "create renders unprocessable when turnstile fails"` — set
     `CloudflareTurnstile.test_validation_response = { "success" => false }`; POST a valid form.
     Expect `:unprocessable_content` and the turnstile-failed flash/error.
   - `test "create succeeds with raw_address only"` — Turnstile stubbed `success`, POST
     `{user_email: {raw_address: "new@example.test", confirm_policy: "1"}}`. Expect 302 to
     `edit_sign_app_up_email_path(<public_id>)` and a verification email job enqueued.
   - Mirror the three cases in `com/up/emails_controller_test.rb`.

## Verification

- `bin/rails test test/controllers/sign/app/up/emails_controller_test.rb test/controllers/sign/com/up/emails_controller_test.rb`
- Manual smoke on `id.app.localhost/sign/up/emails/new`: submit a real address, expect redirect to
  `/sign/up/emails/<public_id>/edit`. Force Turnstile failure via
  `CLOUDFLARE_TURNSTILE_FORCE_FAIL=1` (or equivalent test env) to confirm the form re-renders with
  the i18n flash.
- `Rails.event` should record `sign.signup.email.validation_failed` (warn) on validation paths; no
  `ActionController::ParameterMissing` traces.

## Out of scope

- Refactoring `initiate_email_verification!` or its concern.
- Rebuilding the Turnstile concern.
- Changing the `org`, `dev`, or `net` surfaces (no email signup).
- Sharing controller logic between `app` and `com` surfaces (forbidden by the AGENTS.md
  surface-boundary rule).
