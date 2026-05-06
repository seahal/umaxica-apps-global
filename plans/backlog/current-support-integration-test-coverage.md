# CurrentSupport Integration Test Coverage

## Goal

Add integration tests that verify `CurrentSupport#set_current` correctly populates `Current`
attributes during the request lifecycle and resets them afterward. The existing unit tests cover
`Current` model attributes and `Current::Preference` value objects well, but do not exercise the
`before_action` / `after_action` wiring through real requests.

## Missing Coverage

### 1. `set_current` request lifecycle

Verify that a request through a controller with `CurrentSupport` included:

- Sets `Current.actor`, `Current.actor_type`, `Current.domain`, `Current.surface`, `Current.realm`,
  `Current.session`, `Current.token`, and `Current.preference` during the action.
- Resets all `Current` attributes via `_reset_current_state` after the response.

### 2. `resolved_current_preference` fallback chain

Test the three-stage fallback in order:

1. DB preference record present → `Current.preference` built from record.
2. No DB record, JWT `prf` claim present → `Current.preference` built from JWT.
3. Neither present → `Current.preference` is `NULL` with safe defaults.

Each stage should also verify cookie consent propagation.

### 3. `resolved_current_token`

Test resolution paths:

- `access_token_payload` available → used.
- `access_token_payload` unavailable, `load_access_token_payload` available → used.
- Both unavailable → `nil`.
- Non-hash return values → ignored.
- Exception during resolution → `nil`.

### 4. `resolved_current_actor_type`

Test type detection from resource:

- Resource responds to `staff?` and returns `true` → `:staff`.
- Resource responds to `customer?` and returns `true` → `:customer`.
- Resource is a `User` → `:user`.
- Resource is `nil` → `:unauthenticated`.
- `Current.actor_type` already set → preserved.

### 5. Controller integration (real request round-trip)

For at least one surface per realm (sign, acme, core), verify:

- Authenticated request → `Current.actor` matches the authenticated resource.
- Unauthenticated request → `Current.actor` is `Unauthenticated.instance`.
- `Current.preference` reflects the actor's preference record or JWT claim.
- After response completes, `Current` attributes are reset.

## Approach

- Items 2-4 can be unit tests in `test/unit/current/` using the existing `Host` stub class pattern
  from `current_support_test.rb`.
- Items 1 and 5 require controller or integration tests with real HTTP requests. Place in
  `test/integration/` or `test/controllers/concerns/`.
- Use the existing `X-TEST-CURRENT-USER` / `X-TEST-CURRENT-STAFF` test support headers where
  applicable.

## Notes

- `test/controllers/concerns/current_support_included_do_test.rb` currently has a skipped test for
  `after_action` callback verification. This plan supersedes that skip.
- Avoid mocks for DB-backed preference records; use fixtures instead.
