# Fix Google social login: `redirect_to` to a POST-only route

## Status

**Implemented / verified 2026-05-10.** `Sign::Org::Configuration::GooglesController#create` prepares
the social-auth intent directly and redirects to the OmniAuth authorize path. The remaining
`start_sign_*_social_authentication_path` usages are POST forms/buttons, not controller
`redirect_to` calls.

## Context

Staff (`org` surface) clicking the Google sign-in button on the configuration page hits
`Sign::Org::Configuration::GooglesController#create`, which calls

```ruby
redirect_to(start_sign_org_social_authentication_path(provider: "google_org", ri: params[:ri]))
```

The browser follows the 302 with a GET, but the route at `config/routes/sign.rb:382` is
`post :start, on: :member`. The result is `ActionController::RoutingError`, which the user described
as "nil". The previous helper `new_sign_org_social_session_path` was removed in commits `df95e1c8b`
/ `5716a1e2c`. The same anti-pattern likely exists for the `app` surface.

**Outcome:** clicking the staff Google button reliably initiates OmniAuth with valid CSRF/state in
session, completes the round-trip, and returns the user to `sign_org_configuration_path` with a
success flash.

## Root cause

`redirect_to` always issues HTTP 302/303 followed by a GET. The `start` action is registered
POST-only:

```ruby
namespace :social do
  resources :authentications, path: "auth", param: :provider, only: [] do
    post :start, on: :member
  end
end
```

The cleanest fix is to perform what `start` does directly inside `create`: validate the provider,
prepare the social-auth intent in session, then redirect to the OmniAuth authorize endpoint. This
keeps the user-initiated POST → 302 pattern, sets state in the same session, and avoids needing a
GET-friendly start route (which would weaken CSRF posture).

## Files to modify

- `app/controllers/sign/org/configuration/googles_controller.rb` — rewrite `create` to inline intent
  setup (Option C from design).
- `app/controllers/sign/app/configuration/googles_controller.rb` — confirm whether a `create` action
  exists; if so, mirror the fix with provider `"google_app"` and the appropriate intent (`"link"`
  for the configuration page, `"login"` for any unauthenticated entry point). If no such action
  exists, document the gap and stop.
- `app/controllers/concerns/social_auth_concern.rb` — read-only reference. Confirm
  `prepare_social_auth_intent!` and `omniauth_authorize_path` (or equivalents) exist and document
  their signatures.
- `app/views/sign/org/configuration/googles/show.html.erb` — verify the form POSTs (CSRF token
  present); fix if it currently uses a GET link.
- `test/controllers/sign/org/configuration/googles_controller_test.rb` — add controller-level
  redirect tests.
- `test/integration/sign/org/google_social_login_flow_test.rb` (new) — end-to-end flow under
  `OmniAuth.config.test_mode`.

## Implementation steps

1. **Read `social_auth_concern.rb`** to confirm helper signatures. Look for:
   - `prepare_social_auth_intent!(intent, provider:)` (or similar)
   - `omniauth_authorize_path(provider, **params)` (or equivalent for `/auth/:provider`)
   - `safe_redirect_to(path, fallback:)`
   - `handle_social_auth_error(e)` rescuing `SocialAuth::BaseError`

2. **Verify the originating form does POST.** Read
   `app/views/sign/org/configuration/googles/show.html.erb`. The Google button must submit a POST
   form with CSRF token (a `button_to` or `form_with` calling `sign_org_configuration_google_path`
   with `method: :post`). Fix if currently a GET link.

3. **Rewrite `Sign::Org::Configuration::GooglesController`:**

   ```ruby
   module Sign
     module Org
       module Configuration
         class GooglesController < ApplicationController
           include SocialAuthConcern

           auth_required!
           before_action :authenticate_staff!

           def show
             @google_login_enabled = current_staff.staff_emails.exists?(
               staff_identity_email_status_id: [OperatorEmailStatus::ACTIVE, OperatorEmailStatus::VERIFIED],
             )
           end

           def create
             provider = "google_org"
             state = prepare_social_auth_intent!("link", provider: provider)
             safe_redirect_to(
               omniauth_authorize_path(provider, state: state, ri: params[:ri]),
               fallback: new_sign_org_in_path,
             )
           rescue SocialAuth::BaseError => e
             handle_social_auth_error(e)
           end
         end
       end
     end
   end
   ```

4. **Mirror in `Sign::App::Configuration::GooglesController`** if a `create` exists, using provider
   `"google_app"`. Intent is `"link"` for the configuration page (user already authenticated) —
   confirm by reading the originating view. If a separate unauthenticated entry point exists,
   replace `auth_required!` with `public_strict!` for that route and use intent `"login"`.

5. **Audit other call sites** for the same anti-pattern:

   ```bash
   grep -rn 'redirect_to.*start_sign_.*social_authentication_path' app/
   ```

   File follow-up tickets (or in-line fixes) for any matches.

6. **Tests:**
   - In `googles_controller_test.rb`: with a staff fixture logged in, assert `post :create` returns
     302 with `Location` matching `%r{\A/auth/google_org\?}` and that the session social-state key
     (`SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY` or equivalent) is set.
   - Integration test (`test/integration/sign/org/google_social_login_flow_test.rb`):

     ```ruby
     OmniAuth.config.test_mode = true
     OmniAuth.config.mock_auth[:google_org] = OmniAuth::AuthHash.new(
       provider: "google_org",
       uid: "123",
       info: { email: "staff@example.test" },
     )
     ```

     Drive the full POST `/sign/configuration/google` → `/auth/google_org` →
     `/auth/google_org/callback` flow and assert the final redirect lands on
     `sign_org_configuration_google_path` (or the configured success path) with a success flash. Use
     the staff fixture whose email matches `staff@example.test`.

## Verification

- `bin/rails test test/controllers/sign/org/configuration/googles_controller_test.rb test/integration/sign/org/google_social_login_flow_test.rb`
  — green.
- Manual: with a real Google client id, log in as staff on `id.org.localhost`, click "Connect
  Google" — confirm the round-trip lands back at `sign_org_configuration_google_path` with a success
  flash.
- `Rails.event` log should not show `social_auth.state_missing` or `social_auth.intent_expired`.
- Confirm the originating form has `authenticity_token` (open browser devtools or use
  `assert_select` in tests).

## Out of scope

- Adding GET-friendly `start` routes (rejected — weakens CSRF).
- Apple sign-in changes.
- Refactoring `SocialAuthConcern` (consume only).
- Touching `Sign::Com` surface (no Google login per current routes).
