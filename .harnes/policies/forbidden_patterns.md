# Forbidden Patterns

## Forbidden Rails Methods

The single source of truth for Rails methods that must not be used is
`docs/reference/forbidden-rails-methods.md`.

Read that document before changing controllers, models, migrations, rendering boundaries, or
transport-security code.

---

## Exception Handling

DO NOT:

- rescue and ignore errors
- use `rescue nil`

Reason: hides failures.

---

## Global State

DO NOT USE:

- @@variables
- Thread.current
- global variables

Reason: unsafe in concurrent environments.

---

## Test-Only Application Code

DO NOT add application code that changes behavior because tests are running.

Forbidden examples:

- `Rails.env.test?` branches in `app/` code
- checks for `ENV["RAILS_ENV"] == "test"` or similar test-environment flags in implementation code
- `defined?(Minitest)`, `defined?(RSpec)`, or other test-framework detection in implementation code
- test-only params, headers, cookies, feature flags, routes, service branches, or policy exceptions
  added only to make tests pass
- hardcoded fixture ids, fixture names, factory data, or seeded test data assumptions in application
  behavior
- bypassing authentication, authorization, verification, callbacks, validations, rate limits, CSRF,
  external-service boundaries, or error handling only under test

Reason: tests must verify production behavior. Passing tests by adding test-aware behavior to
application code hides bugs and creates unsafe bypasses.

If behavior needs a controllable boundary, introduce or use a production-valid abstraction such as a
service object, adapter, configuration object, dependency injected collaborator, or local fake in
the test. The application behavior must remain valid outside the test environment.

---

## Logging

DO NOT LOG:

- tokens
- cookies
- authorization headers
- full params

---

## Enforced Regression Guards

`test/unit/security/forbidden_rails_patterns_test.rb` mechanically enforces:

- No test-framework detection or known test-only bypass in `app/`/`lib/` (`defined?(Minitest)`,
  `defined?(RSpec)`, `ENV["RAILS_ENV"]`, `TEST_VERIFICATION_COOKIE_PREFIX`).
- `skip_before_action :enforce_verification_if_required`, `:enforce_step_up_prereqs!`, and
  `:authenticate_client!` may appear only in the reviewed allowlist (`SENSITIVE_SKIP_ALLOWLIST`).
  Adding a new file that skips one fails the suite until the boundary change is reviewed.

`test/controllers/apex/app/bare_controller_test.rb` pins the set of controllers inheriting
`Apex::App::BareController` (a no-op `public_strict!` boundary); a new descendant fails the suite
until it is confirmed to be a public, self-defending endpoint.

If one of these tests fails, do not just edit the allowlist — confirm the underlying change is an
intentional, reviewed security decision first.

---

## Summary

If a change introduces risk or bypasses safeguards, it is forbidden.
