# PublicController Base Plan

## Status

Active draft (2026-05-06)

## Summary

Introduce `Acme::PublicController`, `Sign::PublicController`, and `Jump::PublicController`, each
inheriting directly from `ActionController::Base`. Migrate the existing public endpoints
(`HealthsController`, `RobotsController`, `SitemapsController`) to inherit from these new base
classes instead of from the heavy `<Boundary>::<Tld>::ApplicationController` chain. Drop the
`skip_before_action ..., raise: false` lines that became unnecessary.

Per `adr/public-controller-base.md`, only one `PublicController` is added per boundary. No per-TLD
subclass is introduced.

## Scope

In:

- New `Acme::PublicController`, `Sign::PublicController`, `Jump::PublicController`.
- Re-parenting of public endpoint controllers to the new bases.
- Removal of now-redundant `skip_before_action` calls and module includes on the migrated
  controllers.
- Tests covering the lifecycle of the new base classes and a regression pass on the migrated
  endpoints.

Out:

- Per-TLD `PublicController` subclasses.
- `Cache-Control` / `expires_in` headers on `/robots.txt` and `/sitemap.xml`.
- A dedicated public-endpoint rate limit profile.
- `rack-attack` gem adoption.
- Edge-layer (CDN/WAF) DDoS policy.
- Migrating `acme/*/edge/v0/healths_controller.rb` and `sign/*/edge/v0/healths_controller.rb`
  (API-style health endpoints).
- Adding public endpoints for `acme/dev` and `acme/net` TLDs that do not have them today.

## Implementation

### 1. Add `Acme::PublicController`

File: `app/controllers/acme/public_controller.rb`.

Behavior:

- Inherits from `ActionController::Base`.
- `allow_browser versions: :modern`.
- `include ::RateLimit`.
- `before_action :check_default_rate_limit`.
- `protect_from_forgery using: :header_or_legacy_token, with: :exception`.
- `public_strict!`.
- Does not include `Session`, `Authentication::*`, `Authorization::*`, `Verification::*`,
  `Preference::*`, `CurrentSupport`, `Finisher`, `ActionPolicy::Controller`, or
  `Oidc::SsoInitiator`.

### 2. Add `Sign::PublicController`

File: `app/controllers/sign/public_controller.rb`.

Same shape as `Acme::PublicController`. Does not include the sign-specific helpers (`current_user`,
`verification_*`, `identity_*`, `after_login_path`, etc.) from `Sign::<Tld>::ApplicationController`.

### 3. Add `Jump::PublicController`

File: `app/controllers/jump/public_controller.rb`.

Same shape as the others, with these differences:

- Does not call `set_jumper_context` or `reset_jumper_context`.
- Does not declare `jumper_actor_type`.
- Does not inherit from `Jump::ApplicationController`.

### 4. Migrate acme public endpoints

Re-parent and clean up:

- `app/controllers/acme/healths_controller.rb`
- `app/controllers/acme/com/healths_controller.rb`
- `app/controllers/acme/com/robots_controller.rb`
- `app/controllers/acme/com/sitemaps_controller.rb`
- `app/controllers/acme/org/healths_controller.rb`
- `app/controllers/acme/org/robots_controller.rb`
- `app/controllers/acme/org/sitemaps_controller.rb`
- `app/controllers/acme/app/healths_controller.rb`
- `app/controllers/acme/app/robots_controller.rb`
- `app/controllers/acme/app/sitemaps_controller.rb`

For each:

- Change parent class to `Acme::PublicController`.
- Remove `skip_before_action :canonicalize_query_params, raise: false`.
- Remove `skip_before_action :set_region, raise: false`.
- Keep the existing `Health` / `Robots` / `Sitemap` concern include.
- Keep the existing `public_strict!` call (redundant with the base but harmless and explicit).
- Keep the existing `show` action body unchanged.

### 5. Migrate sign public endpoints

Re-parent and clean up the same way:

- `app/controllers/sign/com/healths_controller.rb`
- `app/controllers/sign/com/robots_controller.rb`
- `app/controllers/sign/com/sitemaps_controller.rb`
- `app/controllers/sign/org/healths_controller.rb`
- `app/controllers/sign/org/robots_controller.rb`
- `app/controllers/sign/org/sitemaps_controller.rb`
- `app/controllers/sign/app/healths_controller.rb`
- `app/controllers/sign/app/robots_controller.rb`
- `app/controllers/sign/app/sitemaps_controller.rb`

Each becomes a subclass of `Sign::PublicController`.

### 6. Migrate jump public endpoints

Re-parent the three jump health controllers:

- `app/controllers/jump/com/healths_controller.rb`
- `app/controllers/jump/org/healths_controller.rb`
- `app/controllers/jump/app/healths_controller.rb`

Each becomes a subclass of `Jump::PublicController`. Remove the parent change from
`Jump::ApplicationController` so jumper context is no longer set on these endpoints.

### 7. Verify removed includes are still loaded elsewhere

Confirm that removing `include ::RateLimit`, `include ::Session`, `include ::Authentication::*`,
etc. from these controllers does not break shared autoload behavior. Each of those modules continues
to be loaded by the heavy `<Boundary>::<Tld>::ApplicationController` classes for the rest of the
app.

## Tests

### Unit / integration

For each of the three boundaries, add or extend tests that prove the following on the new base:

- `GET /health`, `GET /robots.txt`, and `GET /sitemap.xml` (where applicable) return successfully
  under the new parent.
- The 300 req/min/IP default rate limit applies (one extension test per boundary that exceeds the
  limit and asserts a 429 response with `Retry-After`).
- `protect_from_forgery` is active: a `POST` to one of these routes without a token receives a 4xx
  CSRF response. Use a test-only POST route to assert this without changing the production routes.
- No `Current` / `Jumper` / `Preference` / `Session` state leaks into the response. Specifically,
  after the request:
  - `Current.session` is unchanged.
  - For jump tests: `Jumper.domain` is `nil` (the lifecycle was not invoked).

### Regression

Run the existing controller tests for the migrated endpoints unchanged. They should continue to
pass:

- `test/controllers/acme/healths_controller_test.rb`
- `test/controllers/acme/<tld>/healths_controller_test.rb`
- `test/controllers/acme/<tld>/robots_controller_test.rb`
- `test/controllers/acme/<tld>/sitemaps_controller_test.rb`
- `test/controllers/sign/<tld>/healths_controller_test.rb`
- `test/controllers/sign/<tld>/robots_controller_test.rb`
- `test/controllers/sign/<tld>/sitemaps_controller_test.rb`
- `test/controllers/jump/<tld>/healths_controller_test.rb`

If a regression test relies on a `before_action` from the heavy `ApplicationController` running on a
public endpoint (for example, expecting `Current.preference` to be populated), update the test to
match the new base behavior rather than restoring the callback.

## Verification

```bash
bin/rails test test/controllers/acme/healths_controller_test.rb \
               test/controllers/acme/com \
               test/controllers/acme/org \
               test/controllers/acme/app \
               test/controllers/sign/com \
               test/controllers/sign/org \
               test/controllers/sign/app \
               test/controllers/jump/com \
               test/controllers/jump/org \
               test/controllers/jump/app
```

Then run the rate limit and CSRF concern suites:

```bash
bin/rails test test/controllers/concerns/rate_limit_test.rb
```

## Acceptance

- Three new base classes exist: `Acme::PublicController`, `Sign::PublicController`,
  `Jump::PublicController`, each inheriting from `ActionController::Base`.
- All listed public endpoint controllers inherit from the appropriate
  `<Boundary>::PublicController`.
- No `skip_before_action ..., raise: false` lines remain in the migrated controllers.
- The default `RateLimit` 300/min/IP applies to all migrated endpoints.
- `protect_from_forgery` is active on all three new bases.
- `Cache-Control` headers, dedicated public rate limit profiles, and edge-layer policy remain
  unchanged from today.
- Existing controller tests for the migrated endpoints pass.
