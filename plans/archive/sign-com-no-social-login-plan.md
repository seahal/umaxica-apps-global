# Sign :com No Social Login Plan

## Status

Completed (2026-05-07).

> **Completion notes (2026-05-07):**
>
> - `:com` view overrides exist at `app/views/sign/com/ins/new.html.erb` and
>   `app/views/sign/com/configurations/show.html.erb` with all Google / Apple UI removed.
> - `OmniAuthCorporateGuard` middleware is defined in `config/initializers/omniauth.rb` and inserted
>   before `OmniAuth::Builder`; it returns 404 for `/auth/...` requests when the host matches
>   `ENV["ID_CORPORATE_URL"]`.
> - i18n: `sign.com.*` keys added in both `config/locales/ja.yml` and `config/locales/en.yml`
>   without any `google` / `apple` / `social.*` keys (their absence is the load-bearing signal).
> - Tests: `test/controllers/sign/com/ins_controller_test.rb` and
>   `test/controllers/sign/com/configurations_controller_test.rb` assert no social references in the
>   response body. Integration tests `test/integration/com_social_login_blocked_test.rb` and
>   `test/integration/app_social_login_works_test.rb` cover both the `:com` 404 path and the `:app`
>   redirect path.
> - Regression sweep `grep -rn "google\|apple\|/auth/" app/views/sign/com` is clean.

**Original status:** Active draft (2026-05-05)

## Summary

The corporate IdP host (`id.umaxica.com` in production, `id.com.localhost` in development) currently
renders a "Googleでサインイン" button on `/in/new` and Google/Apple links on `/configuration`, even
though social login is not intended for `:com`. The cause is template-lookup fallback:

`app/controllers/sign/com/application_controller.rb:47-55` overrides `local_prefixes` so that any
view path under `sign/com/...` falls back to `sign/app/...` when no `:com`-specific template exists.
Most `:com` controllers have no dedicated views; they implicitly render the `:app` templates. Two of
those `:app` templates carry Google / Apple UI:

- `app/views/sign/app/ins/new.html.erb:13-15` — `button_to "/auth/google_app"` (Google sign-in)
- `app/views/sign/app/configurations/show.html.erb:28-29` — Google and Apple configuration links

In addition, the OmniAuth Rack middleware (`config/initializers/omniauth.rb:50-116`) handles
`/auth/google_app`, `/auth/google_org`, `/auth/apple` regardless of host, so a direct
`POST /auth/google_app` against `id.com.localhost` still starts the Google flow even if the UI is
hidden. Hiding the UI alone is not enough.

Goal: stop social login from being offered on `:com` (UI), and reject social-flow requests that
arrive on the `:com` host (server). `:app` and `:org` keep social login unchanged.

## Decisions taken with user

- Approach: create `:com`-specific view overrides instead of conditionally branching the existing
  `:app` templates. The `local_prefixes` fallback stays in place for everything else.
- Server-side guard: yes — reject `/auth/...` requests originating from the corporate host at the
  Rack level so direct POSTs cannot bypass the UI hiding.

## Scope

In:

- New `:com` view files at `app/views/sign/com/...` for the routes that today fall through to `:app`
  views containing social references.
- A small Rack middleware that gates `/auth/...` by request host, inserted before
  `OmniAuth::Builder`.
- Tests covering both UI absence and server rejection on `:com`.
- Any new `sign.com.*` i18n keys needed by the new views.

Out:

- `:app` and `:org` views, controllers, and routes (no behavior change).
- The `local_prefixes` fallback mechanism itself (kept; only the social-bearing templates get
  per-`:com` overrides).
- OmniAuth strategy registration in `config/initializers/omniauth.rb` (still registers `google_app`,
  `google_org`, `apple` — strategies are not `:com`-aware, the Rack guard is).
- `:com` configuration `/configuration/google` / `/configuration/apple` routes — these never existed
  on `:com`, no change.

## Changes

### 1. View overrides — `:com`-specific templates

Create the following files. Each is a focused copy of its `:app` counterpart with social UI removed,
and route helpers swapped from `sign_app_*` to `sign_com_*`.

#### a) `app/views/sign/com/ins/new.html.erb`

Source: `app/views/sign/app/ins/new.html.erb`. Remove L13-15 entirely (the
`button_to "/auth/google_app"` block) and the surrounding blank line. Update remaining
`new_sign_app_in_*` and `new_sign_app_up_*` helpers to `new_sign_com_in_*` / `new_sign_com_up_*`.
The `:com` route block does not include `:passkey` resource login at the same path; verify each
helper exists for `:com` (`new_sign_com_in_email_path`, `new_sign_com_in_passkey_path`,
`new_sign_com_in_secret_path`, `new_sign_com_up_path`) before linking. Drop links whose `:com`
helper does not exist.

#### b) `app/views/sign/com/configurations/show.html.erb`

Source: `app/views/sign/app/configurations/show.html.erb`. Remove L28-29 (the Google and Apple
`<li>` entries). Update remaining `sign_app_configuration_*` helpers to `sign_com_configuration_*`.
Drop any list entry that points to a `:com`-nonexistent route. Keep email / passkey / telephone /
secret / session / activity entries that exist in `:com` routes.

#### c) `app/views/sign/com/in/emails/new.html.erb` — review and decide

Source: `app/views/sign/app/in/emails/new.html.erb` references
`t("sign.app.registration.new.social.disclaimer", ...)` at L11 — a "no posting on your behalf" text
shown alongside the social options. On `:com`, where social is removed, that disclaimer is out of
place.

During implementation, decide one of:

- Override `app/views/sign/com/in/emails/new.html.erb` and omit the disclaimer line.
- Override and substitute a `:com`-appropriate copy text under `sign.com.in.email.new.disclaimer`.
- Leave fallthrough if the rendered area is already hidden by surrounding markup on `:com`.

Inspect rendered output during smoke test before committing the choice.

### 2. OmniAuth host guard — Rack middleware

Add a small middleware that returns 404 for any `/auth/...` path when the request host matches the
corporate URL. Insert it before `OmniAuth::Builder` so OmniAuth never sees the request.

Location: append to `config/initializers/omniauth.rb` (or extract to
`config/initializers/omniauth_corporate_guard.rb` and `require_relative` from `omniauth.rb`).

Outline:

```ruby
class OmniAuthCorporateGuard
  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless env["PATH_INFO"].start_with?("/auth/")
    return [404, { "Content-Type" => "text/plain" }, ["Not Found"]] if corporate_host?(env)
    @app.call(env)
  end

  private

  def corporate_host?(env)
    corporate = ENV["ID_CORPORATE_URL"].to_s
    return false if corporate.empty?
    Rack::Request.new(env).host == corporate
  end
end

Rails.application.config.middleware.insert_before(OmniAuth::Builder, OmniAuthCorporateGuard)
```

Notes for implementation:

- `ENV["ID_CORPORATE_URL"]` is hostname-only in this codebase (`config/environments/production.rb`
  and `IdHostEnv`), so direct equality with `request.host` is correct; no scheme/port stripping
  needed.
- The guard is intentionally narrow (`/auth/`) so unrelated requests on `:com` are unaffected.
- 404 (not 302/failure) is the right response: there is no `:com` social flow to redirect to, and a
  deliberate 404 makes the absence explicit in logs.

### 3. i18n

Add only the keys actually consumed by the new `:com` views. Likely additions in both
`config/locales/ja.yml` and `config/locales/en.yml`:

- `sign.com.authentication.new.page_title`
- `sign.com.authentication.new.description`
- `sign.com.authentication.new.links.email`
- `sign.com.authentication.new.links.passkey` (if linked)
- `sign.com.authentication.new.links.secret`
- `sign.com.authentication.new.links.registration`
- (and any `sign.com.setting.index.*` entries needed by the configurations/show override)

Reuse existing `sign.com.*` keys where present. Do NOT add `google` / `apple` / `social.*` keys
under `sign.com.*` — their absence is a load-bearing signal.

### 4. Tests

Add or extend tests so this regression cannot reappear silently.

- `test/controllers/sign/com/ins_controller_test.rb` — assert response body contains no
  `/auth/google_app`, `/auth/google_org`, `/auth/apple` references and no Google / Apple i18n
  strings.
- `test/controllers/sign/com/configurations_controller_test.rb` (or equivalent) — assert response
  body contains no `/configuration/google`, `/configuration/apple` references.
- `test/integration/com_social_login_blocked_test.rb` (new) — set host to
  `ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")` and assert:
  - `post "/auth/google_app"` → 404
  - `post "/auth/google_org"` → 404
  - `post "/auth/apple"` → 404
- `test/integration/app_social_login_works_test.rb` (or extend existing) — sanity: same POSTs on
  `ENV.fetch("ID_SERVICE_URL", "id.app.localhost")` redirect (302 / OmniAuth handoff), proving the
  guard targets only `:com`.

## Verification

1. **Routes / strategies still healthy**

   ```bash
   bin/rails routes | grep -E "/auth/(google_app|google_org|apple)"
   bin/rails runner 'puts OmniAuth::Strategies.constants'
   ```

2. **Affected tests**

   ```bash
   bin/rails test test/controllers/sign/com \
                  test/integration/com_social_login_blocked_test.rb \
                  test/integration/app_social_login_works_test.rb
   ```

3. **Manual smoke (dev)** with `bin/dev` and three host aliases:
   - `http://id.app.localhost:3001/in/new?ri=jp` → Google button visible, click works
   - `http://id.com.localhost:3001/in/new?ri=jp` → **no** Google button, page renders cleanly
   - `http://id.org.localhost:3001/in/new?ri=jp` → Google button visible (staff), click works
   - `curl -X POST http://id.com.localhost:3001/auth/google_app -i` → `HTTP/1.1 404`
   - `curl -X POST http://id.app.localhost:3001/auth/google_app -i` → `HTTP/1.1 302` (Google)
   - `http://id.com.localhost:3001/configuration` (after sign-in) → no Google / Apple links

4. **Regression sweep**

   ```bash
   grep -rn "google\|apple\|/auth/" app/views/sign/com 2>/dev/null
   ```

   Expect: only Google Fonts CDN URLs (`fonts.googleapis.com`), no `/auth/google_app` /
   `/auth/google_org` / `/auth/apple` and no `sign.app.*social*` i18n key references.

## Acceptance

- `:com` sign-in page (`/in/new`) renders without any social login button or social i18n strings.
- `:com` configuration page (`/configuration`) renders without Google / Apple links.
- `POST /auth/google_app`, `POST /auth/google_org`, `POST /auth/apple` on the `:com` host return 404
  before reaching OmniAuth.
- `:app` and `:org` behavior is unchanged: social login still works there.
- Tests cover both the UI absence on `:com` and the server-side rejection on `:com`.
