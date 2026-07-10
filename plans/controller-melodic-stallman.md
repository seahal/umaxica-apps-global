# Controller Inheritance Audit — Prohibited controller-to-controller patterns

## Context

Policy: leaf controllers must inherit directly from the surface/domain's `ApplicationController` or
`BareController` only. Controller-to-controller inheritance is prohibited; shared behavior goes to
concerns, services, authority, ceremony objects, or private helpers.

This plan documents all violations found across `app/controllers/` by running:

```bash
grep -rn "class.*Controller.*<" app/controllers/sign/ --include="*_controller.rb" \
  | grep -v "ApplicationController\|BareController\|ActionController::Base" | sort

grep -rn "class.*Controller.*<" app/controllers/ --include="*_controller.rb" \
  | grep -v "/sign/" \
  | grep -v "ApplicationController\|BareController\|ActionController::Base" | sort
```

ADR reference: `adr/two-base-authentication-mode-boundaries.md` — target bases are `BareController`
(infrastructure, no actor) and surface-local `ApplicationController` (auth-aware pipeline).

---

## Severity Classification

| Severity    | Meaning                                                                                                                                                                                |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ⛔ Critical | Leaf inherits from another functional leaf; namespace/behavior boundary is broken                                                                                                      |
| ⚠️ High     | Named intermediate "base" inside a feature namespace; effectively leaf-to-leaf                                                                                                         |
| 🔶 Medium   | Legacy intermediate tier (`FullAccessController`, `PreferencesBaseController`, `RedirectOnlyController`); violates 2-base ADR target but contains shared behavior — migration required |

---

## ⛔ Critical — Sign/In dual-namespace duplication (33 controllers)

`sign/{surface}/sign/in/` controllers wrap and inherit from `sign/{surface}/in/` controllers.

### sign/app/sign/in/ (12 controllers)

```
sign/app/sign/in/challenges_controller.rb
  Sign::App::Sign::In::ChallengesController < ::Sign::App::In::ChallengesController

sign/app/sign/in/challenge/passkeys_controller.rb
  Sign::App::Sign::In::Challenge::PasskeysController < ::Sign::App::In::Challenge::PasskeysController

sign/app/sign/in/challenge/totps_controller.rb
  Sign::App::Sign::In::Challenge::TotpsController < ::Sign::App::In::Challenge::TotpsController

sign/app/sign/in/emails_controller.rb
  Sign::App::Sign::In::EmailsController < ::Sign::App::In::EmailsController

sign/app/sign/in/entrances_controller.rb
  EntrancesController < ::Sign::App::SignInsController

sign/app/sign/in/guards_controller.rb
  Sign::App::Sign::In::GuardsController < ::Sign::App::In::GuardsController

sign/app/sign/in/passkeys_controller.rb
  PasskeysController < ::Sign::App::In::PasskeysController

sign/app/sign/in/passkey/options_controller.rb
  OptionsController < ::Sign::App::In::PasskeysController

sign/app/sign/in/passkey/verifications_controller.rb
  VerificationsController < ::Sign::App::In::PasskeysController

sign/app/sign/in/secret_credentials_controller.rb
  Sign::App::Sign::In::SecretCredentialsController < ::Sign::App::In::SecretCredentialsController

sign/app/sign/in/session_cancellations_controller.rb
  Sign::App::Sign::In::SessionCancellationsController < ::Sign::App::In::SessionsController

sign/app/sign/in/sessions_controller.rb
  Sign::App::Sign::In::SessionsController < ::Sign::App::In::SessionsController
```

### sign/com/sign/in/ (11 controllers)

```
sign/com/sign/in/challenges_controller.rb
  Sign::Com::Sign::In::ChallengesController < ::Sign::Com::In::ChallengesController

sign/com/sign/in/challenge/passkeys_controller.rb
  Sign::Com::Sign::In::Challenge::PasskeysController < ::Sign::Com::In::Challenge::PasskeysController

sign/com/sign/in/emails_controller.rb
  Sign::Com::Sign::In::EmailsController < ::Sign::Com::In::EmailsController

sign/com/sign/in/entrances_controller.rb
  EntrancesController < ::Sign::Com::SignInsController

sign/com/sign/in/guards_controller.rb
  Sign::Com::Sign::In::GuardsController < ::Sign::Com::In::GuardsController

sign/com/sign/in/passkeys_controller.rb
  PasskeysController < ::Sign::Com::In::PasskeysController

sign/com/sign/in/passkey/options_controller.rb
  OptionsController < ::Sign::Com::In::PasskeysController

sign/com/sign/in/passkey/verifications_controller.rb
  VerificationsController < ::Sign::Com::In::PasskeysController

sign/com/sign/in/secret_credentials_controller.rb
  Sign::Com::Sign::In::SecretCredentialsController < ::Sign::Com::In::SecretCredentialsController

sign/com/sign/in/session_cancellations_controller.rb
  Sign::Com::Sign::In::SessionCancellationsController < ::Sign::Com::In::SessionsController

sign/com/sign/in/sessions_controller.rb
  Sign::Com::Sign::In::SessionsController < ::Sign::Com::In::SessionsController
```

### sign/org/sign/in/ (10 controllers)

```
sign/org/sign/in/challenges_controller.rb
  Sign::Org::Sign::In::ChallengesController < ::Sign::Org::In::ChallengesController

sign/org/sign/in/challenge/passkeys_controller.rb
  Sign::Org::Sign::In::Challenge::PasskeysController < ::Sign::Org::In::Challenge::PasskeysController

sign/org/sign/in/entrances_controller.rb
  EntrancesController < ::Sign::Org::SignInsController

sign/org/sign/in/guards_controller.rb
  Sign::Org::Sign::In::GuardsController < ::Sign::Org::In::GuardsController

sign/org/sign/in/passkeys_controller.rb
  PasskeysController < ::Sign::Org::In::PasskeysController

sign/org/sign/in/passkey/options_controller.rb
  OptionsController < ::Sign::Org::In::PasskeysController

sign/org/sign/in/passkey/verifications_controller.rb
  VerificationsController < ::Sign::Org::In::PasskeysController

sign/org/sign/in/secret_credentials_controller.rb
  Sign::Org::Sign::In::SecretCredentialsController < ::Sign::Org::In::SecretCredentialsController

sign/org/sign/in/session_cancellations_controller.rb
  Sign::Org::Sign::In::SessionCancellationsController < ::Sign::Org::In::SessionsController

sign/org/sign/in/sessions_controller.rb
  Sign::Org::Sign::In::SessionsController < ::Sign::Org::In::SessionsController
```

---

## ⛔ Critical — Sign/Up dual-namespace duplication (39 controllers)

Same pattern: `sign/{surface}/sign/up/` inheriting from `sign/{surface}/up/`.

### sign/app/sign/up/ (23 controllers)

```
sign/app/sign/up/check/apple/birthdates_controller.rb
  Sign::App::Sign::Up::Check::Apple::BirthdatesController < ::Sign::App::Up::Check::Apple::BirthdatesController

sign/app/sign/up/check/apple/cancellations_controller.rb
  Sign::App::Sign::Up::Check::Apple::CancellationsController < ::Sign::App::Up::Check::Apple::BirthdatesController

sign/app/sign/up/check/apple/confirmations_controller.rb
  Sign::App::Sign::Up::Check::Apple::ConfirmationsController < ::Sign::App::Up::Check::Apple::ConfirmationsController

sign/app/sign/up/check/email/birthdates_controller.rb
  Sign::App::Sign::Up::Check::Email::BirthdatesController < ::Sign::App::Up::Check::Email::BirthdatesController

sign/app/sign/up/check/email/cancellations_controller.rb
  Sign::App::Sign::Up::Check::Email::CancellationsController < ::Sign::App::Up::Check::Email::BirthdatesController

sign/app/sign/up/check/email/otps_controller.rb
  Sign::App::Sign::Up::Check::Email::OtpsController < ::Sign::App::Up::Check::Email::OtpsController

sign/app/sign/up/check/google/birthdates_controller.rb
  Sign::App::Sign::Up::Check::Google::BirthdatesController < ::Sign::App::Up::Check::Google::BirthdatesController

sign/app/sign/up/check/google/cancellations_controller.rb
  Sign::App::Sign::Up::Check::Google::CancellationsController < ::Sign::App::Up::Check::Google::BirthdatesController

sign/app/sign/up/check/google/confirmations_controller.rb
  Sign::App::Sign::Up::Check::Google::ConfirmationsController < ::Sign::App::Up::Check::Google::ConfirmationsController

sign/app/sign/up/check/telephone/birthdates_controller.rb
  Sign::App::Sign::Up::Check::Telephone::BirthdatesController < ::Sign::App::Up::Check::Telephone::BirthdatesController

sign/app/sign/up/check/telephone/cancellations_controller.rb
  Sign::App::Sign::Up::Check::Telephone::CancellationsController < ::Sign::App::Up::Check::Telephone::BirthdatesController

sign/app/sign/up/check/telephone/otps_controller.rb
  Sign::App::Sign::Up::Check::Telephone::OtpsController < ::Sign::App::Up::Check::Telephone::OtpsController

sign/app/sign/up/check/telephone/passcodes_controller.rb
  Sign::App::Sign::Up::Check::Telephone::PasscodesController < ::Sign::App::Up::Check::Telephone::PasscodesController

sign/app/sign/up/check/telephone/passkeys_controller.rb
  Sign::App::Sign::Up::Check::Telephone::PasskeysController < ::Sign::App::Up::Check::Telephone::PasskeysController

sign/app/sign/up/emails_controller.rb
  Sign::App::Sign::Up::EmailsController < ::Sign::App::Up::EmailsController

sign/app/sign/up/entrances_controller.rb
  EntrancesController < ::Sign::App::SignUpsController

sign/app/sign/up/guard/apples_controller.rb
  Sign::App::Sign::Up::Guard::ApplesController < ::Sign::App::Up::Guard::ApplesController

sign/app/sign/up/guard/emails_controller.rb
  Sign::App::Sign::Up::Guard::EmailsController < ::Sign::App::Up::Guard::EmailsController

sign/app/sign/up/guard/googles_controller.rb
  Sign::App::Sign::Up::Guard::GooglesController < ::Sign::App::Up::Guard::GooglesController

sign/app/sign/up/guard/telephones_controller.rb
  Sign::App::Sign::Up::Guard::TelephonesController < ::Sign::App::Up::Guard::TelephonesController

sign/app/sign/up/telephones_controller.rb
  Sign::App::Sign::Up::TelephonesController < ::Sign::App::Up::TelephonesController
```

_(Note: cancellations controllers inherit from birthdates controllers of the same check type — an
additional cross-action inheritance compounded inside the dual-namespace violation.)_

### sign/com/sign/up/ (14 controllers)

```
sign/com/sign/up/check/email/birthdates_controller.rb
  Sign::Com::Sign::Up::Check::Email::BirthdatesController < ::Sign::Com::Up::Check::Email::BirthdatesController

sign/com/sign/up/check/email/cancellations_controller.rb
  Sign::Com::Sign::Up::Check::Email::CancellationsController < ::Sign::Com::Up::Check::Email::BirthdatesController

sign/com/sign/up/check/email/otps_controller.rb
  Sign::Com::Sign::Up::Check::Email::OtpsController < ::Sign::Com::Up::Check::Email::OtpsController

sign/com/sign/up/check/telephone/birthdates_controller.rb
  Sign::Com::Sign::Up::Check::Telephone::BirthdatesController < ::Sign::Com::Up::Check::Telephone::BirthdatesController

sign/com/sign/up/check/telephone/cancellations_controller.rb
  Sign::Com::Sign::Up::Check::Telephone::CancellationsController < ::Sign::Com::Up::Check::Telephone::BirthdatesController

sign/com/sign/up/check/telephone/otps_controller.rb
  Sign::Com::Sign::Up::Check::Telephone::OtpsController < ::Sign::Com::Up::Check::Telephone::OtpsController

sign/com/sign/up/check/telephone/passcodes_controller.rb
  Sign::Com::Sign::Up::Check::Telephone::PasscodesController < ::Sign::Com::Up::Check::Telephone::PasscodesController

sign/com/sign/up/check/telephone/passkeys_controller.rb
  Sign::Com::Sign::Up::Check::Telephone::PasskeysController < ::Sign::Com::Up::Check::Telephone::PasskeysController

sign/com/sign/up/emails_controller.rb
  Sign::Com::Sign::Up::EmailsController < ::Sign::Com::Up::EmailsController

sign/com/sign/up/entrances_controller.rb
  EntrancesController < ::Sign::Com::SignUpsController

sign/com/sign/up/guard/emails_controller.rb
  Sign::Com::Sign::Up::Guard::EmailsController < ::Sign::Com::Up::Guard::EmailsController

sign/com/sign/up/guard/telephones_controller.rb
  Sign::Com::Sign::Up::Guard::TelephonesController < ::Sign::Com::Up::Guard::TelephonesController

sign/com/sign/up/telephones_controller.rb
  Sign::Com::Sign::Up::TelephonesController < ::Sign::Com::Up::TelephonesController
```

_(+ entrances = 14 total)_

### sign/org/sign/up/ (2 controllers)

```
sign/org/sign/up/entrances_controller.rb
  EntrancesController < ::Sign::Org::SignUpsController

sign/org/sign/up/invitations_controller.rb
  Sign::Org::Sign::Up::InvitationsController < ::Sign::Org::Up::InvitationsController
```

---

## ⛔ Critical — Cross-flow and cross-domain inheritance in sign/\*/up/check/ (7 controllers)

These are NOT inside the dual-namespace wrappers. They exist in the canonical `sign/*/up/check/`
paths, where the inheritance target is a controller of a different action type or different domain.

```
sign/app/up/check/email/otps_controller.rb
  OtpsController < ::Sign::App::Up::EmailsController           ← OTP inherits from email flow

sign/app/up/check/telephone/otps_controller.rb
  OtpsController < ::Sign::App::Up::TelephonesController       ← OTP inherits from telephone flow

sign/app/up/check/telephone/birthdates_controller.rb
  BirthdatesController < ::Sign::App::Up::Check::Email::BirthdatesController  ← telephone inherits from email

sign/app/up/check/google/confirmations_controller.rb
  ConfirmationsController < ::Sign::App::Up::Check::Apple::ConfirmationsController  ← Google inherits from Apple

sign/com/up/check/email/otps_controller.rb
  OtpsController < ::Sign::Com::Up::EmailsController           ← OTP inherits from email flow

sign/com/up/check/telephone/otps_controller.rb
  OtpsController < ::Sign::Com::Up::TelephonesController       ← OTP inherits from telephone flow

sign/com/up/check/telephone/birthdates_controller.rb
  BirthdatesController < ::Sign::Com::Up::Check::Email::BirthdatesController  ← telephone inherits from email
```

The `sign/app/up/check/google/confirmations < Apple::ConfirmationsController` case is additionally a
cross-domain boundary violation.

---

## ⚠️ High — Redeliveries inheriting from EmailsController (3 controllers)

```
sign/com/verification/redeliveries_controller.rb
  Sign::Com::Verification::RedeliveriesController < ::Sign::Com::Verification::EmailsController

sign/app/verification/redeliveries_controller.rb
  Sign::App::Verification::RedeliveriesController < ::Sign::App::Verification::EmailsController

sign/app/settings/emails/redeliveries_controller.rb
  RedeliveriesController < RegistrationsController
```

The third case also warrants confirming the parent:
`sign/app/settings/emails/registrations_controller.rb` — if it is not inheriting from
`ApplicationController`, that is an additional violation.

---

## ⚠️ High — Settings passkeys nesting (6 controllers)

```
sign/app/settings/passkeys/options_controller.rb
  Sign::App::Settings::Passkeys::OptionsController < ::Sign::App::Settings::PasskeysController

sign/app/settings/passkeys/verifications_controller.rb
  Sign::App::Settings::Passkeys::VerificationsController < ::Sign::App::Settings::PasskeysController

sign/com/settings/passkeys/options_controller.rb
  Sign::Com::Settings::Passkeys::OptionsController < ::Sign::Com::Settings::PasskeysController

sign/com/settings/passkeys/verifications_controller.rb
  Sign::Com::Settings::Passkeys::VerificationsController < ::Sign::Com::Settings::PasskeysController

sign/org/settings/passkeys/options_controller.rb
  Sign::Org::Settings::Passkeys::OptionsController < ::Sign::Org::Settings::PasskeysController

sign/org/settings/passkeys/verifications_controller.rb
  Sign::Org::Settings::Passkeys::VerificationsController < ::Sign::Org::Settings::PasskeysController
```

---

## ⚠️ High — Settings sessions/revocations chaining (9 controllers)

```
sign/app/settings/revocation_attempts_controller.rb
  Sign::App::Settings::RevocationAttemptsController < Sign::App::Settings::SessionsController

sign/app/settings/session_revocations/alls_controller.rb
  Sign::App::Settings::SessionRevocations::AllsController < ::Sign::App::Settings::SessionsController

sign/app/settings/session_revocations/others_controller.rb
  Sign::App::Settings::SessionRevocations::OthersController < ::Sign::App::Settings::SessionsController

sign/com/settings/revocation_attempts_controller.rb
  Sign::Com::Settings::RevocationAttemptsController < Sign::Com::Settings::SessionsController

sign/com/settings/session_revocations/alls_controller.rb
  Sign::Com::Settings::SessionRevocations::AllsController < ::Sign::Com::Settings::SessionsController

sign/com/settings/session_revocations/others_controller.rb
  Sign::Com::Settings::SessionRevocations::OthersController < ::Sign::Com::Settings::SessionsController

sign/org/settings/revocation_attempts_controller.rb
  Sign::Org::Settings::RevocationAttemptsController < Sign::Org::Settings::SessionsController

sign/org/settings/session_revocations/alls_controller.rb
  Sign::Org::Settings::SessionRevocations::AllsController < ::Sign::Org::Settings::SessionsController

sign/org/settings/session_revocations/others_controller.rb
  Sign::Org::Settings::SessionRevocations::OthersController < ::Sign::Org::Settings::SessionsController
```

---

## ⚠️ High — Social auth inheriting from AuthenticationsController (4 controllers)

```
sign/app/social/apple/connection_attempts_controller.rb
  Sign::App::Social::Apple::ConnectionAttemptsController < ::Sign::App::Social::AuthenticationsController

sign/app/social/apple/disconnection_attempts_controller.rb
  Sign::App::Social::Apple::DisconnectionAttemptsController < ::Sign::App::Social::AuthenticationsController

sign/app/social/google/connection_attempts_controller.rb
  Sign::App::Social::Google::ConnectionAttemptsController < ::Sign::App::Social::AuthenticationsController

sign/app/social/google/disconnection_attempts_controller.rb
  Sign::App::Social::Google::DisconnectionAttemptsController < ::Sign::App::Social::AuthenticationsController
```

---

## ⚠️ High — Verification::BaseController pattern (9 controllers)

`Verification::BaseController` is an intermediate base inside the verification feature namespace,
not a surface `ApplicationController`.

```
sign/app/verification/emails_controller.rb
  Sign::App::Verification::EmailsController < ::Sign::App::Verification::BaseController

sign/app/verification/passkeys_controller.rb
  Sign::App::Verification::PasskeysController < ::Sign::App::Verification::BaseController

sign/app/verification/totps_controller.rb
  Sign::App::Verification::TotpsController < ::Sign::App::Verification::BaseController

sign/app/verifications_controller.rb
  Sign::App::VerificationsController < ::Sign::App::Verification::BaseController

sign/com/verification/emails_controller.rb
  EmailsController < ::Sign::Com::Verification::BaseController

sign/com/verification/passkeys_controller.rb
  PasskeysController < ::Sign::Com::Verification::BaseController

sign/com/verifications_controller.rb
  VerificationsController < Verification::BaseController

sign/org/verification/passkeys_controller.rb
  Sign::Org::Verification::PasskeysController < ::Sign::Org::Verification::BaseController

sign/org/verifications_controller.rb
  Sign::Org::VerificationsController < ::Sign::Org::Verification::BaseController
```

---

## ⚠️ High — Guard BaseController (6 controllers)

`BaseController` is a local intermediate base within the guard namespace.

```
sign/app/up/guard/apples_controller.rb
  ApplesController < BaseController

sign/app/up/guard/emails_controller.rb
  EmailsController < BaseController

sign/app/up/guard/googles_controller.rb
  GooglesController < BaseController

sign/app/up/guard/telephones_controller.rb
  TelephonesController < BaseController

sign/com/up/guard/emails_controller.rb
  EmailsController < BaseController

sign/com/up/guard/telephones_controller.rb
  TelephonesController < BaseController
```

---

## ⚠️ High — Sign web/v0 preferences inheriting from PreferencesBaseController (6 controllers)

```
sign/app/web/v0/cookies_controller.rb:   CookiesController < PreferencesBaseController
sign/app/web/v0/themes_controller.rb:    ThemesController < PreferencesBaseController
sign/com/web/v0/cookies_controller.rb:   CookiesController < PreferencesBaseController
sign/com/web/v0/themes_controller.rb:    ThemesController < PreferencesBaseController
sign/org/web/v0/cookies_controller.rb:   CookiesController < PreferencesBaseController
sign/org/web/v0/themes_controller.rb:    ThemesController < PreferencesBaseController
```

---

## ⚠️ High — OAuth::JwksController inheriting from JwksController (acme, 3 controllers)

```
acme/app/oauth/jwks_controller.rb:   Acme::App::OAuth::JwksController < Acme::App::JwksController
acme/com/oauth/jwks_controller.rb:   Acme::Com::OAuth::JwksController < Acme::Com::JwksController
acme/org/oauth/jwks_controller.rb:   Acme::Org::OAuth::JwksController < Acme::Org::JwksController
```

`JwksController` (the parent) inherits from `BareController` — so these are 3-tier
`BareController → JwksController → OAuth::JwksController`.

---

## 🔶 Medium — RefreshesControllerBase (acme, 1 controller)

```
acme/com/edge/v0/token/refreshes_controller_base.rb
  RefreshesControllerBase < Acme::Com::ApplicationController   ← intermediate base

acme/com/edge/v0/token/refreshes_controller.rb
  Acme::Com::Edge::V0::Token::RefreshesController < Acme::Com::Edge::V0::Token::RefreshesControllerBase
```

Shared setup in `RefreshesControllerBase` should move to a concern.

---

## 🔶 Medium — RedirectOnlyController in sign surface (24 controllers)

`Sign::RedirectOnlyController < ApplicationController` exists as a sign-root intermediate base for
endpoints that are being migrated to redirects per `plans/active/sign-acme-boundary-remediation.md`.
These endpoints will eventually be deleted; they are still a policy violation in the interim.

```
sign/app/dashboards_controller.rb:            DashboardsController < ::Sign::RedirectOnlyController
sign/app/settings/activities_controller.rb:   ActivitiesController < ::Sign::RedirectOnlyController
sign/app/settings/sessions_controller.rb:     SessionsController < ::Sign::RedirectOnlyController
sign/app/sign_outs_controller.rb:             SignOutsController < ::Sign::RedirectOnlyController

sign/com/dashboards_controller.rb:            DashboardsController < ::Sign::RedirectOnlyController
sign/com/settings/activities_controller.rb:   ActivitiesController < ::Sign::RedirectOnlyController
sign/com/settings/emails_controller.rb:       EmailsController < ::Sign::RedirectOnlyController
sign/com/settings/sessions_controller.rb:     SessionsController < ::Sign::RedirectOnlyController
sign/com/settings/withdrawals_controller.rb:  WithdrawalsController < ::Sign::RedirectOnlyController
sign/com/settings_controller.rb:              SettingsController < ::Sign::RedirectOnlyController
sign/com/sign_outs_controller.rb:             SignOutsController < ::Sign::RedirectOnlyController

sign/org/accounts_controller.rb:              AccountsController < ::Sign::RedirectOnlyController
sign/org/audit_controller.rb:                 AuditController < ::Sign::RedirectOnlyController
sign/org/billing_controller.rb:               BillingController < ::Sign::RedirectOnlyController
sign/org/configurations_controller.rb:        ConfigurationsController < ::Sign::RedirectOnlyController
sign/org/dashboards_controller.rb:            DashboardsController < ::Sign::RedirectOnlyController
sign/org/iam_controller.rb:                   IamController < ::Sign::RedirectOnlyController
sign/org/settings/activities_controller.rb:   ActivitiesController < ::Sign::RedirectOnlyController
sign/org/settings/emails_controller.rb:       EmailsController < ::Sign::RedirectOnlyController
sign/org/settings/sessions_controller.rb:     SessionsController < ::Sign::RedirectOnlyController
sign/org/settings_controller.rb:              SettingsController < ::Sign::RedirectOnlyController
sign/org/sign_outs_controller.rb:             SignOutsController < ::Sign::RedirectOnlyController
sign/org/support_controller.rb:               SupportController < ::Sign::RedirectOnlyController
sign/org/system_controller.rb:                SystemController < ::Sign::RedirectOnlyController
```

---

## 🔶 Medium — Legacy FullAccessController / PreAccessController tiers (acme, 22 controllers)

These are intermediate bases that are in active use per the current code but violate the 2-base ADR
target. Leaves inherit from `FullAccessController` or `PreAccessController`, not from
`ApplicationController` directly.

The intermediate base definitions themselves:

```
acme/app/full_access_controller.rb:   FullAccessController < Acme::App::PreAccessController
acme/com/full_access_controller.rb:   FullAccessController < Acme::Com::PreAccessController
acme/org/full_access_controller.rb:   FullAccessController < Acme::Org::PreAccessController
```

Leaves via `FullAccessController`:

```
acme/app/accounts_controller.rb        acme/app/avatars_controller.rb
acme/app/dashboards_controller.rb      acme/app/organizations_controller.rb
acme/app/settings_controller.rb        acme/app/settings/activities_controller.rb

acme/com/accounts_controller.rb        acme/com/dashboards_controller.rb
acme/com/settings_controller.rb        acme/com/settings/activities_controller.rb

acme/org/accounts_controller.rb        acme/org/avatars_controller.rb
acme/org/dashboards_controller.rb      acme/org/organizations_controller.rb
acme/org/settings_controller.rb        acme/org/settings/activities_controller.rb
```

Leaves via `PreAccessController` directly (skipping FullAccess):

```
acme/app/selectors_controller.rb:   SelectorsController < Acme::App::PreAccessController
acme/com/selectors_controller.rb:   SelectorsController < Acme::Com::PreAccessController
acme/org/selectors_controller.rb:   SelectorsController < Acme::Org::PreAccessController
```

---

## 🔶 Medium — Legacy PreferencesBaseController tiers (acme, 42 controllers)

`PreferencesBaseController < ApplicationController` is an intermediate base that introduces a 3rd
tier. All 13 preference leaves per surface (× 3 surfaces = 39) inherit through it, plus 3
`PreferencesController` definitions using an unqualified reference.

```
# PreferencesController (unqualified, 3 controllers):
acme/app/preferences_controller.rb:   PreferencesController < PreferencesBaseController
acme/com/preferences_controller.rb:   PreferencesController < PreferencesBaseController
acme/org/preferences_controller.rb:   PreferencesController < PreferencesBaseController

# Preference leaves (13 per surface × 3 = 39):
acme/{app|com|org}/preference/cookies_controller.rb       < {Surface}::PreferencesBaseController
acme/{app|com|org}/preference/currencies_controller.rb    < {Surface}::PreferencesBaseController
acme/{app|com|org}/preference/dates_controller.rb         < {Surface}::PreferencesBaseController
acme/{app|com|org}/preference/densities_controller.rb     < {Surface}::PreferencesBaseController
acme/{app|com|org}/preference/languages_controller.rb     < {Surface}::PreferencesBaseController
acme/{app|com|org}/preference/motions_controller.rb       < {Surface}::PreferencesBaseController
acme/{app|com|org}/preference/page_sizes_controller.rb    < {Surface}::PreferencesBaseController
acme/{app|com|org}/preference/regions_controller.rb       < {Surface}::PreferencesBaseController
acme/{app|com|org}/preference/resets_controller.rb        < {Surface}::PreferencesBaseController
acme/{app|com|org}/preference/screens_controller.rb       < {Surface}::PreferencesBaseController
acme/{app|com|org}/preference/themes_controller.rb        < {Surface}::PreferencesBaseController
acme/{app|com|org}/preference/times_controller.rb         < {Surface}::PreferencesBaseController
acme/{app|com|org}/preference/timezones_controller.rb     < {Surface}::PreferencesBaseController
```

---

## Summary

| Severity    | Group                                                             | Count   |
| ----------- | ----------------------------------------------------------------- | ------- |
| ⛔ Critical | Sign/In dual-namespace                                            | 33      |
| ⛔ Critical | Sign/Up dual-namespace                                            | 39      |
| ⛔ Critical | Cross-flow/cross-domain in sign/up/check                          | 7       |
| ⚠️ High     | Redeliveries                                                      | 3       |
| ⚠️ High     | Settings passkeys nesting                                         | 6       |
| ⚠️ High     | Settings sessions/revocations chaining                            | 9       |
| ⚠️ High     | Social auth                                                       | 4       |
| ⚠️ High     | Verification::BaseController                                      | 9       |
| ⚠️ High     | Guard BaseController                                              | 6       |
| ⚠️ High     | Sign web preferences                                              | 6       |
| ⚠️ High     | OAuth::JwksController (acme)                                      | 3       |
| 🔶 Medium   | RefreshesControllerBase (acme)                                    | 1       |
| 🔶 Medium   | RedirectOnlyController (sign, to be deleted per remediation plan) | 24      |
| 🔶 Medium   | FullAccess/PreAccess tiers (acme)                                 | 22      |
| 🔶 Medium   | PreferencesBaseController tiers (acme)                            | 42      |
| **Total**   |                                                                   | **214** |

---

## Recommended remediation pattern

For each ⚠️ High violation:

1. Identify what shared behavior the intermediate base provides (before_actions, helper methods,
   shared constants, `AUTHENTICATION_MODE`)
2. Extract that behavior into a Concern module
3. Change each leaf to inherit from the surface `ApplicationController` (or `BareController`)
4. Include the extracted concern in each former child
5. Delete the intermediate base controller

For the ⛔ Critical dual-namespace pattern (`sign/*/sign/in/` and `sign/*/sign/up/`): the
`sign/{surface}/sign/in/*` wrappers may be deletable entirely if their routes resolve to the
underlying `sign/{surface}/in/*` controllers — confirm route mapping in `config/routes/sign.rb`
before removing.

For 🔶 Medium `RedirectOnlyController` controllers: these are slated for deletion in
`plans/active/sign-acme-boundary-remediation.md`; remediation is deleting them, not refactoring.

---

## Verification

```bash
# Reproduce this list at any time:
grep -rn "class.*Controller.*<" app/controllers/sign/ --include="*_controller.rb" \
  | grep -v "ApplicationController\|BareController\|ActionController::Base" | sort

grep -rn "class.*Controller.*<" app/controllers/ --include="*_controller.rb" \
  | grep -v "/sign/" \
  | grep -v "ApplicationController\|BareController\|ActionController::Base" | sort

# Baseline test coverage before changes:
bin/rails test test/controllers/
```
