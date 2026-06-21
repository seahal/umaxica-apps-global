# RateLimit Store Isolation & Split-Brain Fix

## Context

A "grill me" audit brief raised three suspicions about `RateLimit`: test/dev bucket contamination,
store/namespace split-brain, and redirect-ceremony underbudgeting.

A full audit (concern + every `rate_limit` declaration + env/cache config + test runners + ceremony
controllers) shows **the brief's model of the code is largely stale**. Most of its "Required Fixes"
are already implemented:

- The legacy `RateLimit.store` / `build_store` registry is **gone**. The store is configured
  per-environment as `config.x.rate_limit.store` and read through the `rate_limit_store` class
  helper (`app/controllers/concerns/rate_limit.rb:9-11`). A static test already forbids the old API
  and the no-localhost-fallback (`test/controllers/concerns/rate_limit_test.rb:200-226`).
- Test uses `ActiveSupport::Cache::MemoryStore`; dev/prod use a dedicated Valkey `RedisCacheStore`.
  Test `config.cache_store` is `:null_store` (brief wrongly claimed `:solid_cache_store`).
- A `RateLimitProfiles` value object (`app/values/rate_limit_profiles.rb`) already provides
  ceremony/credential/token vocabulary; OIDC authorize has a 3-bucket limiter with structured
  logging (`app/controllers/concerns/oauth_authorize_rate_limit.rb`); sign flows have
  burst+sustained budgets. Solid Cache DBs are per-environment (`config/database.yml`).

What is **actually** wrong is narrow and real. This plan fixes only those items.

## Confirmed Findings (in scope)

**(a) Four limiters omit `store:` → split-brain.** Precise per-block scan found exactly four
`rate_limit` declarations without an explicit `store:`:

- `app/controllers/acme/app/oauth/tokens_controller.rb:20`
- `app/controllers/acme/com/oauth/tokens_controller.rb:16`
- `app/controllers/acme/org/oauth/tokens_controller.rb:16`
- `app/controllers/concerns/csp_violation_report.rb:9`

When `store:` is omitted, Rails' `rate_limit` DSL falls back to `Rails.cache`. That means: in
**dev/prod** these counters land in **Solid Cache**, not the dedicated Valkey store (split-brain —
different backend, different namespace, invisible to the rest of the limiter stack); in **test**
they land in `:null_store`, a no-op, so these limiters are **silently disabled in the suite** (the
token-exchange brute-force guard is effectively untested).

Every other declaration (all `sign/*` controllers, base application controllers, the
`oauth_authorize` concern) correctly passes `store: rate_limit_store`.

**(b) Dedicated Redis namespace lacks `Rails.env`.** Dev and prod both set
`RedisCacheStore.new(url: ..., namespace: "rate_limit")`
(`config/environments/development.rb:36-37`, `production.rb:85-86`). Solid Cache already
env-namespaces via `config/cache.yml` (`namespace: <%= Rails.env %>`), but the RateLimit store does
not. On any shared Valkey instance (multiple dev shells / branches / containers, or a prod/staging
pointing at one host) buckets collide across environments.

**(c) No static guard for missing `store:`.** The existing static-analysis test catches the
_removed_ API but nothing prevents a new `rate_limit` from omitting `store:` — which is exactly how
(a) slipped in.

**(d) Soft test-env enforcement.** `test/test_helper.rb` uses `ENV["RAILS_ENV"] ||= "test"`.
Lefthook runs `bundle exec rails test` inside a container whose `docker/core/env` exports
`RAILS_ENV=development` (`lefthook.yml:67-75`). `bin/rails test` normally forces `test`, but the
soft guard leaves a gap for non-standard invocations (`ruby test/...`) that would run the suite
against the dev Valkey/Solid Cache.

## Out of Scope (already done or brief is stale)

Legacy API removal, MemoryStore-in-test, no-localhost-fallback, profile vocabulary, ceremony
budgets, OIDC-authorize structured logging, setup/teardown clearing, per-env Solid Cache DBs. The
`rate_limit:clear` rake task (brief Fix 7) and broader DSL 429 logging (brief Fix 5) were explicitly
deferred by the user for this change.

Per the user's decision, token-exchange limits stay at the stricter `to: 10, within: 1.minute` (do
**not** raise to the `RateLimitProfiles.token_endpoint` value).

## Plan

### Fix 1 — Give the four bare limiters an explicit dedicated store

For the three OAuth token controllers, replace the bare one-liner with a full declaration that binds
the dedicated store, names a scope/rule, keys by IP, and renders via the shared helper. Preserve
`to: 10, within: 1.minute`. Example (`acme/app/oauth/tokens_controller.rb`, mirror for `com`/`org`
with surface-specific scope):

```ruby
rate_limit(
  to: 10,
  within: 1.minute,
  by: -> { request.remote_ip },
  scope: "acme_app_oauth_token",
  name: "token_exchange_ip",
  store: rate_limit_store,
  only: :create,
  with: -> { render_rate_limited(rule_name: "acme_app_oauth_token_exchange_ip", retry_after: 60) },
)
```

These controllers already `include ::RateLimit` (via their `BareController`) so `rate_limit_store`
and `render_rate_limited` are in scope. Confirm the `BareController` `respond_to?(:rate_limit)` path
is satisfied — the DSL is available because `ActionController::Base` provides it.

For the CSP report concern (`app/controllers/concerns/csp_violation_report.rb:9`), add
`store: rate_limit_store` to the existing call. Keep `to: 120, within: 1.minute` and the
`respond_to?(:rate_limit)` guard. Confirm every controller that calls
`protect_csp_violation_report_intake` includes `::RateLimit` (so `rate_limit_store` resolves); if
any does not, fall back to `Rails.configuration.x.rate_limit.fetch(:store)` inside the class method
instead of the helper.

### Fix 2 — Environment-namespace the dedicated Redis store

In `config/environments/development.rb` and `production.rb`, change the namespace from the bare
`"rate_limit"` to an env-qualified value, with an optional override for shared-Valkey isolation:

```ruby
config.x.rate_limit.store =
  ActiveSupport::Cache::RedisCacheStore.new(
    url: ENV.fetch("RATE_LIMIT_REDIS_URL"),
    namespace: ["rate_limit", Rails.env, ENV["RATE_LIMIT_NAMESPACE_SUFFIX"]].compact.join(":"),
  )
```

This keeps prod keys stable-by-default (`rate_limit:production`) while letting dev branches/
containers set `RATE_LIMIT_NAMESPACE_SUFFIX` to avoid collisions. Note: this rotates existing
dev/prod buckets once on deploy (acceptable — counters are short-TTL).

### Fix 3 — Static test: no `rate_limit` without explicit `store:`

Extend the existing static-analysis test in `test/controllers/concerns/rate_limit_test.rb`
(alongside the `"production code does not use removed rate limit APIs"` test). Scan `app/**/*.rb`,
find each `rate_limit(...)`/`rate_limit to:` invocation, and assert each balanced call includes
`store:`. Reuse the balanced-paren block-extraction approach the audit used (single Ruby pass over
each file). `assert_empty` the list of offenders. This both proves Fix 1 and prevents regression.

### Fix 4 — Hard test-environment guard

In `test/test_helper.rb`, after Rails is required and the environment is loaded, add a hard
assertion that aborts if the suite is not running under test, e.g.:

```ruby
abort("Refusing to run tests outside RAILS_ENV=test (got #{Rails.env}).") unless Rails.env.test?
```

This closes the gap where an inherited `RAILS_ENV=development` (from `docker/core/env`) plus a
non-`bin/rails test` invocation could run the suite against the dev Valkey/Solid Cache. Place it
before any fixtures load so it fails fast.

## Critical Files

- `app/controllers/acme/app/oauth/tokens_controller.rb` (+ `com`, `org` siblings) — Fix 1
- `app/controllers/concerns/csp_violation_report.rb` — Fix 1
- `config/environments/development.rb`, `config/environments/production.rb` — Fix 2
- `test/controllers/concerns/rate_limit_test.rb` — Fix 3
- `test/test_helper.rb` — Fix 4

Reuse: `rate_limit_store` / `render_rate_limited` (`app/controllers/concerns/rate_limit.rb`),
existing scope/name/with declaration pattern
(`app/controllers/sign/app/sign/in/emails_controller.rb`).

## Verification

```bash
# Precise scan must report zero bare declarations after Fix 1:
ruby -e 'Dir.glob("app/controllers/**/*.rb").each{|f| ...}'   # (the audit scan; expect no NOSTORE)

# Targeted tests
bin/rails test test/controllers/concerns/rate_limit_test.rb
bin/rails test test/controllers/concerns/default_web_rate_limit_test.rb

# Token-exchange limiter now actually trips under test (MemoryStore, not null_store).
# Add/confirm a test that an 11th POST to the token endpoint within a minute returns 429.

# Store wiring sanity (manual, in devcontainer):
RAILS_ENV=development bin/rails runner 'puts Rails.configuration.x.rate_limit.fetch(:store).class; \
  puts Rails.configuration.x.rate_limit.fetch(:store).options[:namespace]'

# Broader suite
COVERAGE=true bin/rails test
```

Acceptance: precise scan shows no `rate_limit` without explicit dedicated store; the new static test
fails if one is reintroduced; dev/prod namespace includes `Rails.env`; token-exchange and CSP
limiters use `rate_limit_store`; test suite aborts if not under `RAILS_ENV=test`; all targeted tests
pass.
