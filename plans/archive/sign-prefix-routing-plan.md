# Sign Prefix Routing Plan (`/sign/in`, `/sign/up`)

## Status

Completed (2026-05-07).

> **Completion notes (2026-05-07):**
>
> - `config/routes/sign.rb` has four `scope path: "sign" do` blocks (one each for `:app`'s `:up` and
>   `:in`, one each for `:com`, and the `:org` block separates `:up` and `:in` around the
>   social/auth routes). All other routes (`/settings`, `/preference`, `/auth`, `/social`,
>   `/verification`, `/health`, `/robots.txt`, `/sitemap.xml`, `/web/v0/*`, `/edge/v0/*`,
>   `/authorize`, `/token`, `/jwks`, root) stay outside the `/sign/` prefix.
> - `app/controllers/concerns/authentication/base.rb` rescue fallbacks updated to
>   `"/sign/in/session"` (lines 2041, 2044) and `"/sign/in/challenge"` (lines 2410, 2413).
> - All test path literals (`test/integration/turnstile_forms_test.rb`,
>   `test/integration/coverage_booster_v{2,3}_test.rb`,
>   `test/controllers/concerns/{social_auth_concern,authentication/base_coverage}_test.rb`,
>   `test/controllers/sign/{com,app}/...`, `test/unit/auth/mfa_intercept_test.rb`,
>   `test/javascript/controllers/passkey_authentication_controller.test.js`) now use `/sign/in/...`
>   and `/sign/up/...`.
> - Final regex scan returns only the harmless JS comment lines at
>   `app/javascript/controllers/passkey_authentication_controller.js:9-10`, which the plan
>   explicitly marks as optional to update.
> - Route helper names (`new_sign_app_in_path`, etc.) unchanged — only generated URL paths changed.

**Original status:** Active draft (2026-05-05)

## Summary

The IdP runs on `id.umaxica.{app,com,org}` (production) and `id.{app,com,org}.localhost`
(development). Today the sign-in / sign-up paths are bare `/in/...` and `/up/...` because
`config/routes/sign.rb:6` declares `scope module: :sign, as: :sign do` which sets module + helper
name prefix only, not a path prefix. Move only the `:in` and `:up` resources/namespaces under a
`/sign/` URL prefix so the live URLs become e.g. `id.umaxica.app/sign/in/new`,
`id.umaxica.app/sign/up/new`. Everything else (`/settings`, `/preference`, `/auth`, `/social`,
`/verification`, `/health`, `/robots.txt`, `/sitemap.xml`, `/web/v0/*`, `/edge/v0/*`, `/authorize`,
`/token`, `/jwks`, root `/`) stays where it is.

## Scope

In:

- Routes for `:in` and `:up` (and their nested children) on each of the three host scopes (`:app`,
  `:com`, `:org`) inside `config/routes/sign.rb`.
- Hardcoded `/in/...` and `/up/...` literal path strings in tests and a few defensive fallbacks.

Out:

- OmniAuth callback path stays at `/auth/:provider/callback`. No Google/Apple provider-side
  reconfiguration.
- Route helper names (`new_sign_app_in_path`, `new_sign_app_up_email_path`, etc.) stay the same.
  Only generated URL paths change.
- `IdHostEnv` (`lib/id_host_env.rb`) and host constraints are unchanged. Defaults `id.app.localhost`
  / `id.com.localhost` / `id.org.localhost` are correct.
- The Inertia entrypoints/views currently in working tree (`app/javascript/entrypoints/inertia.tsx`,
  `app/javascript/pages/inertia_example/`) are unrelated.

## Routing change

In each of the three host blocks in `config/routes/sign.rb`, wrap the `:up` and `:in` resource +
namespace pairs in `scope path: "sign" do`. Children inside the namespaces stay as is.

Pattern (apply once per host scope):

```ruby
scope path: "sign" do
  resource :up, only: :new
  namespace :up do
    # existing children unchanged
  end

  resource :in, only: %i(new)
  namespace :in do
    # existing children unchanged
  end
end
```

Target line ranges in `config/routes/sign.rb`:

- `:app` block — `resource :up` L68, `namespace :up` L69–79, `resource :in` L82, `namespace :in`
  L83–99
- `:com` block — `resource :up` L219, `namespace :up` L220–222, `resource :in` L225, `namespace :in`
  L226–242
- `:org` block — `resource :up` L345, `namespace :up` L346–353, `resource :in` L370, `namespace :in`
  L371–385

Do **not** wrap the surrounding `:configuration`, `:preference`, `:verification`, `:social`,
`:auth`, `:web`, `:edge`, `:health`, `:robots`, `:sitemap`, `:authorize`, `:token`, `:jwks`, or
`root` declarations.

## Production-code fallbacks to update

In `app/controllers/concerns/authentication/base.rb`, the rescue fallbacks should agree with the new
helper output. Reached only when route helpers are missing, but keep them consistent:

- L2041, L2044: `"/in/session"` → `"/sign/in/session"`
- L2410, L2413: `"/in/challenge"` → `"/sign/in/challenge"`

## Host authorization exclude (verify-and-decide)

`config/environments/production.rb:127`:

```ruby
config.host_authorization = { exclude: ->(request) { request.path.start_with?("/health", "/up") } }
```

`/up` here is ambiguous between the Rails default health probe and sign-up. Default expectation is
that this targets the Rails-built-in `/up` health controller and should be left alone (there is no
overlap with new `/sign/up`). Confirm at implementation time by checking whether anything other than
the Rails health controller responds at bare `/up`. If the intent was sign-up bypass, change to
`"/sign/up"`.

## Test path literals to update

Replace `/in/...` with `/sign/in/...` and `/up/...` with `/sign/up/...` in:

- `test/integration/turnstile_forms_test.rb:11-12`
- `test/integration/coverage_booster_v2_test.rb:36, 40, 45, 51, 55, 59`
- `test/integration/coverage_booster_v3_test.rb:35, 39, 44, 50, 54, 58`
- `test/controllers/concerns/social_auth_concern_test.rb:39` (`"/in"` → `"/sign/in"`)
- `test/controllers/concerns/authentication/base_coverage_test.rb:246, 270`
- `test/controllers/sign/com/in/sessions_controller_test.rb:98, 123, 194`
- `test/controllers/sign/com/up/emails_controller_test.rb:82, 272, 274`
- `test/controllers/sign/app/ins_controller_test.rb:32, 39, 48` (`/up/new?ri=...`)
- `test/controllers/sign/app/ups_controller_test.rb:35, 36`
- `test/controllers/sign/app/in/secrets_controller_test.rb:426, 521, 573`
- `test/controllers/sign/app/auth/omniauth_callbacks_controller_test.rb:27, 29, 30, 46, 55, 60, 65, 81, 85, 92, 136, 144, 149, 165`
- `test/controllers/sign/app/up/emails_controller_test.rb:60, 172, 478, 518`
- `test/unit/auth/mfa_intercept_test.rb:113, 133`
- `test/javascript/controllers/passkey_authentication_controller.test.js:35-36`

After edits, run a final scan and expect zero matches:

```bash
grep -rn '"/in/\|"/up/\|'\''/in/\|'\''/up/' app/ test/ \
  | grep -v "/sign/in/\|/sign/up/"
```

JS comment-only references at `app/javascript/controllers/passkey_authentication_controller.js:9-10`
may be updated for consistency or skipped.

## Verification

1. **Routes inspection**

   ```bash
   bin/rails routes -g sign | grep -E "sign_(app|com|org)_(in|up)"
   ```

   Confirm paths now show `/sign/in/...` and `/sign/up/...`. Helper names unchanged.

2. **Affected tests**

   ```bash
   bin/rails test test/integration/turnstile_forms_test.rb \
                  test/integration/coverage_booster_v2_test.rb \
                  test/integration/coverage_booster_v3_test.rb \
                  test/controllers/sign \
                  test/controllers/concerns/authentication/base_coverage_test.rb \
                  test/controllers/concerns/social_auth_concern_test.rb \
                  test/unit/auth/mfa_intercept_test.rb
   yarn test test/javascript/controllers/passkey_authentication_controller.test.js
   ```

3. **Manual smoke (dev)** with `id.app.localhost:3000`:
   - `GET /sign/in/new` → renders sign-in
   - `GET /sign/up/new` → renders sign-up
   - `POST /sign/up/emails` → sign-up email OTP flow proceeds
   - `GET /settings`, `/preference`, `/auth/google_app/callback`, `/health`, `/` → still work, not
     moved
   - Old paths `GET /in/new`, `/up/new` → 404 (expected; no compat redirect)

## Acceptance

- `/in/...` and `/up/...` no longer respond on IdP hosts; `/sign/in/...` and `/sign/up/...` do.
- Other routes under `config/routes/sign.rb` keep their current URLs.
- All tests pass without altering route helper names.
- No remaining `"/in/..."` / `"/up/..."` literals in `app/` or `test/` (except sign-prefixed forms).
