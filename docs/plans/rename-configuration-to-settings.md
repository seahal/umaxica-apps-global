# Rename Configuration Routes to Settings

## Background

The current auth account area uses `/settings` and `Sign::*::Configuration::*`. For user-facing
account screens, `configuration` reads like administrator or system setup. `settings` is the more
natural English term for a client's, visitor's, or operator's own account preferences and security
controls.

## Target

- `/settings` account URLs on the sign app, com, and org surfaces
- `Sign::*::SettingsController`
- `Sign::*::Configuration::*` account-setting controllers
- route helpers such as `sign_app_settings_path`
- views under `app/views/sign/*/settingss` and `app/views/sign/*/settings`
- controller and integration tests that assert configuration routes/helpers
- locale keys that expose `configuration` for account settings UI

## Direction

Perform a breaking rename with no compatibility aliases:

- `/settings` -> `/settings`
- `SettingsController` -> `SettingsController`
- `Sign::*::Configuration::*` -> `Sign::*::Settings::*`
- `sign_*_configuration_*` helpers -> `sign_*_settings_*` helpers

Do not keep old URL aliases, controller aliases, or helper compatibility layers.

## Non-Goals

This plan records a future change only. It must not be implemented in the current auth sign surface
controller rename slice.

Hold these related naming candidates until their model/domain layer is ready:

- `/settings/totps` and `TotpsController` remain unchanged for now. Future candidate:
  `/settings/totp-credentials` and `TotpCredentialsController`.
- `telephones` remains unchanged for now. Future candidate: `phone_numbers`, after the `Telephone`
  domain model is renamed.

## Timing

Run this after the auth sign controller/helper rename has stabilized. The change touches routes,
helpers, views, controller tests, integration tests, and locale keys broadly, so it should be a
separate commit-sized slice.

## Test Plan

- `bin/rails routes`
- `bin/rails test test/controllers`
- `bin/rails test test/integration`
- `bin/rails test`
- Check i18n lookups for missing account settings keys.

## Risks

- Broad helper churn can hide real route regressions.
- View lookup paths and partial references can drift from controller names.
- Locale key rewrites can leave missing translations that only appear in a subset of regions.
- Redirect target tests that assert `/settings` must be updated in the same slice.

## Rollback

Keep the implementation as one revertable commit. If route/helper/view/test churn creates
regressions, revert that commit rather than adding temporary compatibility aliases.

## GitHub Issue Draft

Title: Rename auth account configuration routes to settings

Body:

The auth account area currently uses `/settings` and `Sign::*::Configuration::*` for user-facing
account settings. In English, `configuration` reads like administrator or system setup, while
`settings` is the natural term for account preferences, security controls, sessions, passkeys,
emails, and linked identities.

Proposed direction:

- Rename `/settings` to `/settings` across sign app, com, and org surfaces.
- Rename `Sign::*::SettingsController` to `Sign::*::SettingsController`.
- Rename `Sign::*::Configuration::*` account-setting controllers to `Sign::*::Settings::*`.
- Update route helpers, views, controller tests, integration tests, and locale keys in one slice.
- Do not keep compatibility URL aliases, controller aliases, or helper aliases.

Out of scope for this issue:

- Do not rename `/settings/totps` to `/settings/totp-credentials` until the TOTP credential
  controller/domain naming is ready.
- Do not rename `telephones` to `phone_numbers` until the `Telephone` domain model is renamed.

Risk:

This is broad route/helper/view/test/i18n churn, so it should happen after the current auth sign
controller rename is settled and should be delivered as a single revertable commit.

Existing tracking issue: https://github.com/seahal/umaxica-apps-global/issues/812
