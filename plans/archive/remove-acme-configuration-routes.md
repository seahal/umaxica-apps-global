# Remove redundant acme configuration routes

## Context

`TODO: consider this. we did move this to sign routing.` in the app/org scope of `acme.rb` There is
a comment. Even though the configuration route and related controller views have been completely
migrated to the sign side, they remain as stubs on the acme side. The same structure remains in the
com scope without TODO.

The sign side is emails, totps, passkeys, secrets, sessions, activities, Complete version including
withdrawal etc. acme side show + emails (new/create/edit/update) only stub. The layout's header is
already `sign_*_configuration_url` However, the footer and roots/index refer to the acme side.

There is a copy-paste bug in acme/com/settings/emails/edit.html.erb (when using `acme_app_*` and
`acme_com_*` ).

## Approach

### Step 1: Route deletion — `config/routes/acme.rb`

Delete the following blocks:

- **com scope** (L35-39): `resource :settings` + `namespace :settings { emails }`
- **app scope** (L71-76): TODO comment + `resource :settings` + `namespace :settings { emails }`
- **org scope** (L129-134): TODO comment + `resource :settings` + `namespace :settings { emails }`

### Step 2: Controller deletion

- `app/controllers/acme/app/settingss_controller.rb`
- `app/controllers/acme/com/settingss_controller.rb`
- `app/controllers/acme/org/settingss_controller.rb`
- `app/controllers/acme/app/settings/emails_controller.rb`
- `app/controllers/acme/org/settings/emails_controller.rb`

(acme/com/settings/emails_controller.rb does not exist)

### Step 3: View deletion

- `app/views/acme/app/settingss/` (show.html.erb)
- `app/views/acme/com/settingss/` (show.html.erb)
- `app/views/acme/org/settingss/` (show.html.erb)
- `app/views/acme/app/settings/emails/` (edit.html.erb etc.)
- `app/views/acme/com/settings/emails/` (edit.html.erb etc.)
- `app/views/acme/org/settings/emails/` (edit.html.erb etc.)

### Step 4: Link re-pointing

The part where `acme_*_configuration_path` is used on the layout/root page of acme
`sign_*_configuration_url` Change to The header is already facing the sign, so just the footer and
roots/index:

| File                                                  | Change                                                  |
| ----------------------------------------------------- | ------------------------------------------------------- |
| `app/views/layouts/acme/app/application.html.erb` L50 | `acme_app_configuration_path` → `sign_app_settings_url` |
| `app/views/layouts/acme/org/application.html.erb` L50 | `acme_org_configuration_path` → `sign_org_settings_url` |
| `app/views/acme/app/roots/index.html.erb` L20         | `acme_app_configuration_path` → `sign_app_settings_url` |
| `app/views/acme/org/roots/index.html.erb` L19         | `acme_org_configuration_path` → `sign_org_settings_url` |

### Step 5: Test deletion and update

- `test/controllers/acme/com/settingss_controller_test.rb` — delete file
- `test/controllers/acme/coverage_test.rb` — delete configuration test cases (around L15, L24)

### Step 6: Empty directory cleanup

Check the directories that will be empty after deletion and delete them:

- `app/controllers/acme/app/settings/`
- `app/controllers/acme/com/settings/` (if exists)
- `app/controllers/acme/org/settings/`
- `app/views/acme/*/settingss/`
- `app/views/acme/*/settings/`

## Verification

1. `bundle exec rails routes | grep acme.*configuration` — routes are gone
2. `grep -r "acme.*configuration" app/ test/ config/routes/` — no remaining references
3. `bundle exec rubocop`
4. `bundle exec erb_lint .`
5. `bundle exec rails test test/controllers/acme/` — acme tests pass
