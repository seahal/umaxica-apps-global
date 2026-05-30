# Rename Account Configuration Routes to Settings

## Summary

Audit found that `/configuration` is stiff and system-oriented for end-user account settings. Use
`/settings` for the user-facing settings surface, but do not implement this rename in the current
model/controller naming cleanup slice because it touches routes, helpers, views, tests, and i18n
across all sign surfaces.

This plan is intentionally backlog-scoped. It records the recommended direction and the minimum safe
execution shape for a later controller-layer rename.

GitHub issue: https://github.com/seahal/umaxica-apps-global/issues/812

## Recommended Rename

- Rename user-facing account settings URLs from `/configuration` to `/settings`.
- Rename `Sign::*::ConfigurationsController` to `Sign::*::SettingsController`.
- Rename `Sign::*::Configuration::*` namespaces to `Sign::*::Settings::*` where those controllers
  are account settings screens.
- Keep the domain concept as "account settings" in user-facing text. Avoid "configuration" in UI
  labels unless the screen is truly technical/system configuration.

## Scope

Apply the rename across the three sign surfaces as one controller-layer slice:

- app: client account settings
- com: visitor account settings
- org: operator account settings

Expected impact:

- `config/routes/sign.rb`
- `app/controllers/sign/{app,com,org}/configurations_controller.rb`
- `app/controllers/sign/{app,com,org}/configuration/**/*`
- `app/views/sign/{app,com,org}/configurations/**/*` and `configuration/**/*`
- route helper call sites such as `sign_app_configuration_path`
- controller and integration tests under `test/controllers/sign/**` and `test/integration/**`
- i18n keys under `config/locales/**`

## Implementation Notes

- Do not add old URL aliases.
- Do not add old controller class aliases.
- Update route helpers and tests directly to the new `settings` names.
- Preserve authentication, authorization, step-up, CSRF, and surface boundary behavior exactly.
- Keep Action Policy's framework subject key `user` unchanged; this rename is about URL/controller
  surface naming, not the policy subject interface.
- Run this after the controller/helper naming cleanup has stabilized enough that controller test
  failures are easy to attribute.

## Test Plan

- `bin/rails routes`
- `bin/rails test test/controllers`
- `bin/rails test test/integration`
- `bin/rails test`

## Acceptance Criteria

- No `/configuration` routes remain for user-facing account settings screens.
- Public route helpers and controller class names use `settings`.
- Views and locale keys no longer expose "configuration" for account settings UI.
- Controller and integration tests pass without compatibility aliases.
