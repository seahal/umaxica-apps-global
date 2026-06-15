# Plan: Sign Route Naming Cleanup

## Context

`config/routes/sign.rb` accumulated ~25 FIXME/TODO comments during development, marking naming
patterns the original author considered suboptimal. This plan resolves all four confirmed
categories:

- **Comment cleanups** — stale TODO/FIXME comments where the code is already correct
- **emergency_key → secrets** — explicit rename with a known target
- **r18 route deletion** — unguarded org surface r18 gate that should be removed
- **Command resource renames** — drop verbose `_attempt`/`_cancellation` suffixes from nested
  sub-resources; restructure conflicting cancellation names with `namespace` blocks

Reference analysis: `plans/config-routes-fixme-binary-dream.md`,
`plans/config-routes-rb-sequential-waterfall.md`.

Implementation is divided into five groups ordered by risk. Each group is independently verifiable.

---

## Group 1 — Comment-only cleanups

Files: `config/routes/sign.rb`, `config/routes/acme.rb`

Delete the following stale comment lines. No code, helper, URL, or test changes required.

| File      | Comment                                                                                             | Reason to delete                                                                                         |
| --------- | --------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `sign.rb` | `# TODO: what is the following line? check it out!` above `resource :setup` (verification, app+com) | `setups_controller.rb` is live; routes sign-in users to MFA setup when no method is configured           |
| `sign.rb` | `# TODO: move settings to acme's identity entrypoints.` (org settings)                              | Passkey/TOTP WebAuthn origin binding requires settings to stay on the sign/id host; confirmed 2026-06-13 |
| `acme.rb` | `# FIXME: Check these entrypoints are still needed.` (settings/sessions collection block)           | `others` and `revoke_all` are implemented via `AcmeSettingsSessionManagement` and are active             |
| `sign.rb` | `# FIXME: I want to rename this much smarter naming.` above `resource :redelivery` (all surfaces)   | `redelivery` is an accepted domain term; no rename needed                                                |

---

## Group 2 — DSL cleanup: telephones `scope` → `namespace`

File: `config/routes/sign.rb` (app, com, and org settings sections)

The `scope path: "telephones", module: :telephones, as: :telephones` block is the explicit long form
of `namespace :telephones`. Rewrite to use the Rails-native shorthand, matching the adjacent
`namespace :emails` pattern already in use.

```ruby
# Before (all three surfaces)
scope path: "telephones", module: :telephones, as: :telephones do
  resource :registration, only: %i(new create edit update)
end

# After (all three surfaces)
namespace :telephones do
  resource :registration, only: %i(new create edit update)
end
```

No URL, helper, controller, view, or test changes — the two forms are functionally identical in
Rails. Remove the FIXME comment above the scope block in each surface.

---

## Group 3 — `emergency_key` → `secrets`

Affects the app surface only. The rename target is explicit (`# FIXME: rename this to "secrets"`).

### 3a. Route (`config/routes/sign.rb`)

```ruby
# Before
resource :emergency_key, only: :show

# After
resource :secrets, only: :show
```

### 3b. Controller

- Rename `app/controllers/sign/app/settings/emergency_keys_controller.rb` →
  `app/controllers/sign/app/settings/secrets_controller.rb`
- Change class declaration: `class EmergencyKeysController` → `class SecretsController`
- Module path becomes `Sign::App::Settings::SecretsController`

`resource :secrets` routes to `SecretsController` by default (Rails pluralizes `secrets` → `secrets`
since the name is already plural), so no explicit `controller:` override is needed.

### 3c. Views

Rename directory:

- `app/views/sign/app/settings/emergency_keys/` → `app/views/sign/app/settings/secrets/`

### 3d. Locales (4 files)

Rename key `sign.app.settings.emergency_key` → `sign.app.settings.secrets` in:

- `config/locales/jp/en.yml`
- `config/locales/jp/ja.yml`
- `config/locales/us/en.yml`
- `config/locales/us/ja.yml`

### 3e. Tests

- Rename `test/controllers/sign/app/settings/emergency_keys_controller_test.rb` →
  `test/controllers/sign/app/settings/secrets_controller_test.rb`
- Update all helper references inside: `sign_app_settings_emergency_key_path` →
  `sign_app_settings_secrets_path`

Verification grep before and after:

```bash
grep -r "emergency_key\|emergency_keys" app/ test/ config/ --include="*.rb" --include="*.erb" --include="*.yml"
# Should return nothing after the rename
bin/rails routes | grep secrets
bin/rails test test/controllers/sign/app/settings/secrets_controller_test.rb
```

---

## Group 4 — r18 route deletion (org surface)

The org surface r18 gate (`namespace :r18`) is in production sign.rb without a `Rails.env.local?`
guard. The equivalent acme route has such a guard (marked for future removal). The sign org r18
block and its controller should be removed.

### 4a. Route (`config/routes/sign.rb`)

Delete the `namespace :r18` block inside the org constraints section:

```ruby
# Delete these lines
namespace :r18 do
  resource :gate, only: %i(show create) do
    get :blocked
    get :stopped
  end
end
```

### 4b. Controller

- Delete `app/controllers/sign/org/r18/gates_controller.rb`
- **Do not delete** `app/controllers/concerns/r18_gate.rb` — still referenced by
  `app/controllers/acme/app/dev/r18/gates_controller.rb`
- **Do not delete** `test/controllers/concerns/r18_gate_test.rb` — tests the shared concern

### 4c. Verification

```bash
grep -r "sign_org_r18\|r18.*sign.*org\|sign.*org.*r18" test/ app/
# → should return nothing
bin/rails routes | grep r18
# → should show only acme dev r18, not sign org r18
```

---

## Group 5 — Command resource renames

This is the most extensive group. Work as focused micro-slices within the group. Each sub-item can
be committed independently once its tests pass.

### 5a. Drop `_attempt` suffix from nested sub-resources

These sub-resources are nested under collection members (`passkeys/:id`, `sessions/:id`, etc.) where
the parent context already disambiguates the action. The `_attempt` suffix adds no information.

| Current                 | New             | Parent resource                          | Surfaces        |
| ----------------------- | --------------- | ---------------------------------------- | --------------- |
| `removal_attempt`       | `removal`       | `passkeys/:id`, `secret_credentials/:id` | app / com / org |
| `rotation_attempt`      | `rotation`      | `secret_credentials/:id`                 | app / com       |
| `revocation_attempt`    | `revocation`    | `sessions/:id`                           | app / com / org |
| `disconnection_attempt` | `disconnection` | `social/apple`, `social/google`          | app only        |

For each rename:

1. Change `resource :X_attempt` → `resource :X` in `config/routes/sign.rb` (all affected surfaces).
2. Rename controller file: `X_attempts_controller.rb` → `Xs_controller.rb`.
3. Rename controller class: `XAttemptsController` → `XsController`.
4. Grep and update helper references: `sign_*_X_attempt_path` → `sign_*_X_path`.

Primary files to grep: `app/views/`, `test/controllers/`, `test/integration/`,
`test/controllers/controller_inheritance_invariant_test.rb`.

`controller_inheritance_invariant_test.rb` lists these controllers in its known-violation registry
(lines ~34, ~41, ~48 for revocation; ~92-95 for social). Update class names there after each
controller rename.

### 5b. Merge `connection_attempt` into `connection` (social/apple, social/google — app only)

The `connection` resource already exists for `show`. The `connection_attempt` resource exists only
for `create`. Merging the two into one resource removes the `_attempt` noise and follows REST
conventions for creating a resource.

**Routes** (app section only, repeat for both apple and google):

```ruby
# Before
resource :connection, only: :show
resource :connection_attempt, only: :create

# After
resource :connection, only: %i(show create)
```

**Controllers:**

- Move the `create` action from `connection_attempts_controller.rb` into `connections_controller.rb`
- Delete `app/controllers/sign/app/social/apple/connection_attempts_controller.rb`
- Delete `app/controllers/sign/app/social/google/connection_attempts_controller.rb`

**Helper change:**

- Old: `sign_app_social_apple_connection_attempt_path`
- New: `sign_app_social_apple_connection_path` (same URL helper used for both GET show and POST
  create)

**Key call sites to update:**

- `test/support/missing_helpers.rb:334` — `_connection_attempt_path` → `_connection_path`
- `test/support/missing_helpers.rb:389` — same
- All `test/integration/social_*` files that reference `connection_attempt`

**`route_naming_test.rb` update** (lines 56-71): Replace the `connection_attempt` assertion with a
`connection` POST assertion, and add `assert_unrecognized` for the old `_attempt` paths:

```ruby
# Before
assert_recognizes_sign_route(:app, "/social/apple/connection_attempt", :post,
  "social/apple/connection_attempts", "create")
assert_recognizes_sign_route(:app, "/social/google/disconnection_attempt", :post,
  "social/google/disconnection_attempts", "create")

# After
assert_recognizes_sign_route(:app, "/social/apple/connection", :post,
  "social/apple/connections", "create")
assert_recognizes_sign_route(:app, "/social/google/disconnection", :post,
  "social/google/disconnections", "create")
assert_unrecognized(:app, "/social/apple/connection_attempt", :post)
assert_unrecognized(:app, "/social/google/disconnection_attempt", :post)
```

### 5c. Restructure `session_cancellation` / `check_cancellation` with `namespace` blocks

Both reside in `sign/in` namespace. Simply renaming both to `cancellation` would create a URL
collision. Using explicit `namespace` blocks gives each a clear parent context while **preserving
the existing route helper names** (the helper prefix chain stays identical).

**Routes** (sign/in namespace, all 3 surfaces):

```ruby
# Before
resource :session, only: %i(show update destroy)
resource :session_cancellation, only: :create
resource :check, only: %i(show update)
resource :check_cancellation, only: :create

# After
resource :session, only: %i(show update destroy)
namespace :session do
  resource :cancellation, only: :create
end
resource :check, only: %i(show update)
namespace :check do
  resource :cancellation, only: :create
end
```

Helper name verification — both are preserved because the namespace chain is additive:

- `namespace :session { resource :cancellation }` → `sign_app_sign_in_session_cancellation_path` ✓
- `namespace :check { resource :cancellation }` → `sign_app_sign_in_check_cancellation_path` ✓

URL changes (the only visible difference):

- `/sign/in/session_cancellation` → `/sign/in/session/cancellation`
- `/sign/in/check_cancellation` → `/sign/in/check/cancellation`

**Controller file moves** (app, com, org — six files total):

- `sign/app/sign/in/session_cancellations_controller.rb` →
  `sign/app/sign/in/session/cancellations_controller.rb`
- `sign/app/sign/in/check_cancellations_controller.rb` →
  `sign/app/sign/in/check/cancellations_controller.rb`
- (repeat for com and org surfaces)

**Class renames:**

- `SessionCancellationsController` → `CancellationsController` (in module
  `Sign::*::Sign::In::Session`)
- `CheckCancellationsController` → `CancellationsController` (in module `Sign::*::Sign::In::Check`)

`controller_inheritance_invariant_test.rb` lists these controllers (lines ~65, ~74). Update class
names and module paths after the moves.

Verify old URLs are gone:

```bash
bin/rails routes | grep -E "session_cancellation|check_cancellation"
# → should return nothing
```

### 5d. `session_revocations` namespace → `revocations`

The `session_` prefix is redundant — the parent `settings` context and proximity to
`resources :sessions` already makes the subject clear. Rename the namespace across all three
surfaces.

**Routes** (settings namespace, app / com / org):

```ruby
# Before
namespace :session_revocations do
  resource :others, only: :create
  resource :all, only: :create
end

# After
namespace :revocations do
  resource :others, only: :create
  resource :all, only: :create
end
```

URL change: `/settings/session_revocations/others` → `/settings/revocations/others`

Helper change: `sign_*_settings_session_revocations_others_path` →
`sign_*_settings_revocations_others_path`

Controller changes:

- Move files from `sign/*/settings/session_revocations/` → `sign/*/settings/revocations/`
- Module rename: `Settings::SessionRevocations::` → `Settings::Revocations::`

**`route_naming_test.rb` update** (lines 82-98): The test named "session revocation uses post
attempt routes instead of collection deletes" asserts the old route contracts. Update to assert the
new names:

```ruby
# After 5a + 5d renames, the session revocation test should assert:
assert_recognizes_sign_route(:app, "/settings/sessions/abc/revocation", :post,
  "settings/revocations", "create")         # was revocation_attempt
assert_recognizes_sign_route(:app, "/settings/revocations/others", :post,
  "settings/revocations/others", "create")  # was session_revocations/others
assert_recognizes_sign_route(:app, "/settings/revocations/all", :post,
  "settings/revocations/alls", "create")    # was session_revocations/all
assert_unrecognized(:app, "/settings/sessions/abc/revocation_attempt", :post)
assert_unrecognized(:app, "/settings/session_revocations/others", :post)
```

### 5e. `secret_credential` in sign/in — deferred

`resource :secret_credential` in `sign/in` represents entering a credential during sign-in. The
FIXME appears in com and org surfaces (not app). The canonical rename target must be confirmed from
`docs/dictionary/` before implementing — the term "secret credential" may be the accepted ubiquitous
language or may have a preferred shorter alias (e.g., `passcode`).

Action now: remove the FIXME comment lines only. Handle the actual rename in a separate slice after
dictionary confirmation.

---

## Deferred Items

- **`secret_credential` rename** (5e above): needs `docs/dictionary/` confirmation of target term
- **`web/v0` / `edge/v0` → `api/v0`**: separate migration per
  `adr/api-route-vocabulary-consolidation.md`

---

## Verification

Run after all groups to confirm no old names remain:

```bash
# Confirm old names are gone from routes
bin/rails routes | grep -E "session_cancellation|check_cancellation|removal_attempt|rotation_attempt|revocation_attempt|connection_attempt|disconnection_attempt|session_revocations|emergency_key|r18"
# → should return nothing (except acme dev r18 which is retained)

# Confirm new names resolve
bin/rails routes | grep -E "/cancellation|/removal|/rotation|/revocation|/connection|/disconnection|/revocations|/secrets"

# Group 3: emergency_key tests
env PARALLEL_WORKERS=1 bin/rails test test/controllers/sign/app/settings/secrets_controller_test.rb

# Group 5: sign controller and integration tests
env PARALLEL_WORKERS=1 bin/rails test test/controllers/sign/
env PARALLEL_WORKERS=1 bin/rails test test/integration/social_login_robustness_test.rb
env PARALLEL_WORKERS=1 bin/rails test test/integration/social_auth_app_flow_contract_test.rb
env PARALLEL_WORKERS=1 bin/rails test test/integration/social_auth_link_test.rb

# Full suite
env PARALLEL_WORKERS=1 bin/rails test
```
