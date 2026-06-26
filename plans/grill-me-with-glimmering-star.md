# Plan: Migrate Sign `/settings` Ownership to Acme `/identity` — Inventory and Docs

## Context

The authority boundary (`docs/identity/authority-boundary.md`, `adr/identity-authority-boundary.md`)
already declares that Acme owns session management, account lifecycle, preference writes, and
settings UI. Sign is a credential gateway only. However, Sign `/settings` today carries a wide range
of non-credential surfaces — email management, telephone management, session lists, activity logs,
birthdate display, account withdrawal — that should belong to Acme by that declared authority.

This plan produces Phase 0 of the migration: an authoritative route/controller inventory, full
classification, and a focused architecture document. No code changes. No route changes.

## What We Found

### Sign `/settings` on the `app` surface — full route table

From `config/routes/sign.rb` lines 155–209:

| Path                                        | Methods                  | Controller                                                 | Description                                      |
| ------------------------------------------- | ------------------------ | ---------------------------------------------------------- | ------------------------------------------------ |
| `/settings`                                 | GET                      | `settings#show`                                            | Settings root                                    |
| `/settings/mfa/reset`                       | GET, POST                | `settings/mfa/resets#show,create`                          | MFA reset UI (reset currently disabled/readonly) |
| `/settings/mfa/challenge`                   | GET, PATCH               | `settings/mfa/challenges#show,update`                      | MFA level setting (displays passkeys/TOTPs)      |
| `/settings/totps`                           | GET, POST                | `settings/totps#index,create`                              | TOTP list + enroll                               |
| `/settings/totps/new`                       | GET                      | `settings/totps#new`                                       | TOTP registration                                |
| `/settings/totps/:id/edit`                  | GET                      | `settings/totps#edit`                                      | TOTP rename                                      |
| `/settings/totps/:id`                       | PATCH, DELETE            | `settings/totps#update,destroy`                            | TOTP update/remove                               |
| `/settings/passkeys`                        | GET, POST                | `settings/passkeys#index,create`                           | Passkey list + register                          |
| `/settings/passkeys/new`                    | GET                      | `settings/passkeys#new`                                    | Passkey registration                             |
| `/settings/passkeys/:id/edit`               | GET                      | `settings/passkeys#edit`                                   | Passkey rename                                   |
| `/settings/passkeys/:id`                    | GET, PATCH, DELETE       | `settings/passkeys#show,update,destroy`                    | Passkey detail/update/remove                     |
| `/settings/passkeys/:id/removal`            | POST                     | `settings/passkeys/removals#create`                        | Passkey removal ceremony                         |
| `/settings/passkeys/options`                | POST                     | `settings/passkeys/options#create`                         | WebAuthn registration challenge                  |
| `/settings/passkeys/verification`           | POST                     | `settings/passkeys/verifications#create`                   | WebAuthn credential binding                      |
| `/settings/emails/registration`             | GET, POST, PATCH         | `settings/emails/registrations#new,create,edit,update`     | Add email (OTP ceremony)                         |
| `/settings/emails/registration/redelivery`  | POST                     | `settings/emails/registrations/redeliveries#create`        | Resend OTP                                       |
| `/settings/emails`                          | GET                      | `settings/emails#index`                                    | Email list                                       |
| `/settings/emails/:id/edit`                 | GET                      | `settings/emails#edit`                                     | Email preferences                                |
| `/settings/emails/:id`                      | PATCH, DELETE            | `settings/emails#update,destroy`                           | Email update/remove                              |
| `/settings/telephones/registration`         | GET, POST, PATCH         | `settings/telephones/registrations#new,create,edit,update` | Add telephone (OTP ceremony)                     |
| `/settings/telephones`                      | GET, POST                | `settings/telephones#index,create`                         | Telephone list                                   |
| `/settings/telephones/new`                  | GET                      | `settings/telephones#new`                                  | Add telephone entry                              |
| `/settings/telephones/:id/edit`             | GET                      | `settings/telephones#edit`                                 | Edit telephone                                   |
| `/settings/telephones/:id`                  | DELETE                   | `settings/telephones#destroy`                              | Remove telephone                                 |
| `/settings/birthdate`                       | GET                      | `settings/birthdates#show`                                 | Birthdate display (step-up)                      |
| `/settings/apple`                           | GET, POST, DELETE        | `settings/apples#show,create,destroy`                      | Apple link status + link/unlink                  |
| `/settings/apple/edit`                      | GET                      | `settings/apples#edit`                                     | Apple link/unlink UI                             |
| `/settings/google`                          | GET, POST, DELETE        | `settings/googles#show,create,destroy`                     | Google link status + link/unlink                 |
| `/settings/google/edit`                     | GET                      | `settings/googles#edit`                                    | Google link/unlink UI                            |
| `/settings/secrets`                         | GET                      | `settings/secrets#show`                                    | Recovery secret (one-time reveal)                |
| `/settings/secret_credentials`              | GET, POST                | `settings/secret_credentials#index,create`                 | API credential list + create (step-up)           |
| `/settings/secret_credentials/new`          | GET                      | `settings/secret_credentials#new`                          | New API credential form (step-up)                |
| `/settings/secret_credentials/:id`          | GET, PATCH, DELETE       | `settings/secret_credentials#show,edit,update,destroy`     | API credential detail/update/remove              |
| `/settings/secret_credentials/:id/rotation` | POST                     | `settings/secret_credentials/rotations#create`             | API credential rotation (stub)                   |
| `/settings/secret_credentials/:id/removal`  | POST                     | `settings/secret_credentials/removals#create`              | API credential removal redirect                  |
| `/settings/sessions`                        | GET                      | `settings/sessions#index`                                  | Session list                                     |
| `/settings/sessions/:id`                    | GET                      | `settings/sessions#show`                                   | Session detail                                   |
| `/settings/sessions/:id/revocation`         | POST                     | `settings/sessions/revocations#create`                     | Revoke session                                   |
| `/settings/revocations/others`              | POST                     | `settings/revocations/others#create`                       | Revoke all other sessions                        |
| `/settings/revocations/all`                 | POST                     | `settings/revocations/alls#create`                         | Revoke all sessions                              |
| `/settings/activities`                      | GET                      | `settings/activities#index`                                | Audit/activity log                               |
| `/settings/withdrawal`                      | GET, POST, PATCH, DELETE | `settings/withdrawals#new,create,edit,update,destroy`      | Account withdrawal (step-up always)              |

Note: the `com` and `org` Sign surfaces have parallel subsets of these routes. The `org` surface
adds `operator_lifecycle_requests` routes. The analysis below focuses on `app`; the same
classification applies proportionally to `com` and `org`.

### Existing Acme `/identity` surface

From `config/routes/acme.rb`:

```ruby
resource :identity, only: :show           # /identity (GET) — identity overview
resources :accounts, only: ...            # /accounts CRUD
resources :organizations, only: ...       # /organizations CRUD
resources :avatars, only: ...             # /avatars CRUD
resource :preference, only: :show         # /preference (GET)
namespace :preference do ...end           # /preference/* — 12 preference controllers
resource :selector, only: ...             # /selector
resource :switcher, only: ...             # /switcher
```

There is currently no `namespace :identity` block in Acme. The `/identity` resource is a singular
show-only endpoint served by `Acme::App::IdentitiesController`.

### Controller step-up and auth characteristics

| Controller                    | step_up?                                                             | verification_scope           | Mutates state?                    |
| ----------------------------- | -------------------------------------------------------------------- | ---------------------------- | --------------------------------- |
| `EmailsController`            | implicit (edit/update/destroy check `verification_required_action?`) | `settings_email`             | Yes (update, destroy)             |
| `TelephonesController`        | implicit                                                             | (see registration flow)      | Yes (destroy, registration)       |
| `BirthdatesController`        | `step_up only: :show`                                                | `settings_birthdate`         | No (read-only)                    |
| `ApplesController`            | explicit `require_step_up_for_mutation!` before edit/create/destroy  | social op scope              | Yes (create=link, destroy=unlink) |
| `GooglesController`           | same pattern as Apple                                                | social op scope              | Yes                               |
| `SecretsController`           | implicit                                                             | (one-time token reveal)      | No (read-only)                    |
| `SecretCredentialsController` | `step_up only: %i(new create)`                                       | `settings_secret_credential` | Yes (create, update, destroy)     |
| `SessionsController`          | none                                                                 | —                            | Yes (destroy = revoke)            |
| `RevocationsController`       | none                                                                 | —                            | Yes (POST = revoke)               |
| `ActivitiesController`        | none                                                                 | —                            | No (read-only)                    |
| `WithdrawalsController`       | `verification_required_action? = true` (always)                      | `withdrawal`                 | Yes (create, update, destroy)     |
| `Mfa::ChallengesController`   | `verification_required_action?` for show+update                      | `settings_mfa`               | Yes (update = set MFA level)      |
| `Mfa::ResetsController`       | —                                                                    | —                            | Disabled/read-only                |
| `PasskeysController`          | WebAuthn ceremony                                                    | —                            | Yes (create, update, destroy)     |
| `TotpsController`             | TOTP ceremony                                                        | —                            | Yes (create, update, destroy)     |

---

## Classification

### A. Keep in Sign

These features may remain in Sign because they are credential ceremonies or social provider
link/unlink flows that depend on Sign's OmniAuth integration, WebAuthn RP ID, or TOTP ceremony
state.

| Feature      | Sign paths to keep                                                                      | Why                                                                                                                                                                                                    |
| ------------ | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Passkeys** | `/settings/passkeys/*`, `/settings/passkeys/options`, `/settings/passkeys/verification` | WebAuthn RP ID is bound to the Sign host; ceremony state (challenge, verification) must live on the credential gateway; removal is a ceremony step                                                     |
| **TOTPs**    | `/settings/totps/*`                                                                     | TOTP registration is a credential ceremony; Sign is the credential authority for TOTP secrets                                                                                                          |
| **Google**   | `/settings/google`, `/settings/google/edit`                                             | OmniAuth callback is registered to the Sign host; social link/unlink initiation (`continue_social_authentication`) depends on `SignSocialAuthenticationEndpoint`; Google redirect URIs must not change |
| **Apple**    | `/settings/apple`, `/settings/apple/edit`                                               | Same as Google: OmniAuth, callback, and social provider route constraints are Sign-bound                                                                                                               |

Security requirements that must be preserved for A routes:

- Step-up verification before any mutation (link/unlink, registration, removal)
- CSRF protection (`authenticate_client!` + standard Rails CSRF)
- WebAuthn: challenge–response anti-replay (passkeys/options + passkeys/verification pair)
- Social: `SignSocialAuthenticationEndpoint` validates state/nonce/provider match
- `AuthMethodGuard`: prevents removal of the last authentication method
- `CloudflareTurnstile`: on registration actions where enabled

### B. Move to Acme `/identity`

Everything else under Sign `/settings` should migrate to Acme `/identity`.

| Sign path                                  | Acme target path                           | Current controller                    | Proposed Acme namespace                                    | Step-up required?                     | Mutation?       | Migration risk                                                                    |
| ------------------------------------------ | ------------------------------------------ | ------------------------------------- | ---------------------------------------------------------- | ------------------------------------- | --------------- | --------------------------------------------------------------------------------- |
| `/settings` (root)                         | `/identity`                                | `settings#show`                       | Extend `Acme::App::IdentitiesController`                   | No                                    | No              | Low — GET redirect shim                                                           |
| `/settings/emails`                         | `/identity/emails`                         | `settings/emails#index`               | `Acme::App::Identity::EmailsController`                    | No (browse)                           | No              | Low                                                                               |
| `/settings/emails/:id/edit`                | `/identity/emails/:id/edit`                | `settings/emails#edit`                | same                                                       | Yes (edit)                            | No              | Low                                                                               |
| `/settings/emails/:id` (PATCH)             | `/identity/emails/:id`                     | `settings/emails#update`              | same                                                       | Yes                                   | Yes             | Medium — audit event must survive                                                 |
| `/settings/emails/:id` (DELETE)            | `/identity/emails/:id`                     | `settings/emails#destroy`             | same                                                       | Yes                                   | Yes             | High — `AuthMethodGuard`, `ClientChronicle` audit event                           |
| `/settings/emails/registration`            | `/identity/emails/registration`            | `settings/emails/registrations#*`     | `Acme::App::Identity::Emails::RegistrationsController`     | OTP ceremony                          | Yes             | Medium — OTP delivery, ceremony session                                           |
| `/settings/emails/registration/redelivery` | `/identity/emails/registration/redelivery` | redeliveries                          | same namespace                                             | No                                    | Yes             | Low                                                                               |
| `/settings/telephones`                     | `/identity/telephones`                     | `settings/telephones#index`           | `Acme::App::Identity::TelephonesController`                | No                                    | No              | Low                                                                               |
| `/settings/telephones/registration`        | `/identity/telephones/registration`        | registrations                         | `Acme::App::Identity::Telephones::RegistrationsController` | OTP ceremony                          | Yes             | Medium                                                                            |
| `/settings/telephones/:id` (DELETE)        | `/identity/telephones/:id`                 | `settings/telephones#destroy`         | same                                                       | Yes                                   | Yes             | Medium                                                                            |
| `/settings/birthdate`                      | `/identity/birthdate`                      | `settings/birthdates#show`            | `Acme::App::Identity::BirthdatesController`                | Yes (step-up on show)                 | No              | Low                                                                               |
| `/settings/secrets`                        | `/identity/recovery-secret`                | `settings/secrets#show`               | `Acme::App::Identity::RecoverySecretsController`           | Yes (one-time token)                  | No              | Medium — one-time token mechanism must port                                       |
| `/settings/secret_credentials/*`           | `/identity/credentials/*`                  | `settings/secret_credentials#*`       | `Acme::App::Identity::CredentialsController`               | Yes (new/create)                      | Yes             | High — step-up, ceremony state, Turnstile, AuthMethodGuard, raw secret in session |
| `/settings/sessions`                       | `/identity/sessions`                       | `settings/sessions#index`             | `Acme::App::Identity::SessionsController`                  | No                                    | No              | Low                                                                               |
| `/settings/sessions/:id`                   | `/identity/sessions/:id`                   | `settings/sessions#show`              | same                                                       | No                                    | No              | Low                                                                               |
| `/settings/sessions/:id/revocation` (POST) | `/identity/sessions/:id/revocation`        | revocations                           | `Acme::App::Identity::Sessions::RevocationsController`     | No (but validate not current session) | Yes             | Medium — `AuthenticationSelectedSessionRevoker` must port                         |
| `/settings/revocations/others` (POST)      | `/identity/revocations/others`             | revocations/others                    | `Acme::App::Identity::Revocations::OthersController`       | No                                    | Yes             | Medium                                                                            |
| `/settings/revocations/all` (POST)         | `/identity/revocations/all`                | revocations/alls                      | `Acme::App::Identity::Revocations::AllsController`         | No                                    | Yes             | Medium                                                                            |
| `/settings/activities`                     | `/identity/activities`                     | `settings/activities#index`           | `Acme::App::Identity::ActivitiesController`                | No                                    | No              | Low — `ClientChronicle` read; check DB role                                       |
| `/settings/withdrawal/*`                   | `/identity/withdrawal`                     | `settings/withdrawals#*`              | `Acme::App::Identity::WithdrawalsController`               | Yes (always)                          | Yes             | High — `AcmeSettingsWithdrawalFlow`, step-up always, policy authorization         |
| `/settings/mfa/challenge`                  | `/identity/mfa/challenge`                  | `settings/mfa/challenges#show,update` | `Acme::App::Identity::Mfa::ChallengesController`           | Yes                                   | Yes (update)    | Medium — needs to read passkeys/TOTPs from Sign DB or API                         |
| `/settings/mfa/reset`                      | `/identity/mfa/reset`                      | `settings/mfa/resets#show,create`     | `Acme::App::Identity::Mfa::ResetsController`               | —                                     | Disabled (stub) | Low                                                                               |

### C. Out of scope for this migration

The following are NOT settings and must not be touched:

- Sign-in/sign-up ceremony routes (`/sign/in/*`, `/sign/up/*`)
- Social callback routes (`/social/:provider/callback`, etc.)
- Step-up verification ceremony (`/verification/*`)
- OIDC/OAuth protocol endpoints (`/oauth/*`, `/oidc/*`)
- Sign-out routes (`/sign/out/*`)
- Web/edge API routes (`/web/v0/*`, `/edge/v0/*`)
- Acme context selector/switcher (`/selector`, `/switcher`)
- Acme preference routes (`/preference/*`)

---

## Proposed Acme `/identity` Route Shape

Add a `namespace :identity` block to `config/routes/acme.rb` on the `app` surface (and parallel
blocks on `com`/`org` where those surfaces carry the equivalent Sign settings).

```ruby
# In config/routes/acme.rb, within the app surface block,
# adjacent to the existing `resource :identity, only: :show`:

resource :identity, only: :show   # already exists — extend, do not replace

namespace :identity do
  # Email address management
  resources :emails, only: %i(index edit update destroy)
  namespace :emails do
    resource :registration, only: %i(new create edit update) do
      resource :redelivery, only: :create
    end
  end

  # Telephone management
  resources :telephones, only: %i(index new create edit destroy)
  namespace :telephones do
    resource :registration, only: %i(new create edit update)
  end

  # Birthdate display (read-only, step-up)
  resource :birthdate, only: :show

  # Recovery secret one-time reveal
  resource :recovery_secret, only: :show, path: "recovery-secret"

  # API credentials (secret credentials)
  resources :credentials, only: %i(index show new edit create update destroy) do
    resource :rotation, only: :create
    resource :removal, only: :create
  end

  # Session inventory and revocation
  resources :sessions, only: %i(index show) do
    resource :revocation, only: :create
  end
  namespace :revocations do
    resource :others, only: :create
    resource :all, only: :create
  end

  # Activity / audit log
  resources :activities, only: :index

  # Account withdrawal
  resource :withdrawal, only: %i(new create edit update destroy)

  # MFA level settings
  namespace :mfa do
    resource :challenge, only: %i(show update)
    resource :reset, only: %i(show create)
  end
end
```

URL convention: resource names use Rails underscore convention in routing (mapped to hyphenated
paths where needed via `path:` override). Use `path: "recovery-secret"` for the recovery secret to
avoid underscore in the URL.

---

## Security / Grill Questions

**1. Which Sign `/settings` routes act as identity authority even though they should belong to
Acme?**

All of the B-classified routes above. The most critical are:

- Sessions index/show/revocation — Acme owns the session authority by ADR; Sign should not be the
  listing UI owner.
- Withdrawal — account lifecycle is explicitly Acme authority per
  `docs/identity/authority-boundary.md`.
- MFA challenge (level setting) — security policy for the account, not a credential ceremony.
- Activity log — accountability records belong to the identity authority surface.

**2. Which routes mutate identity/security state?**

All POST/PATCH/DELETE routes in Group B. High-risk mutations:

- `DELETE /settings/emails/:id` — removes contact point, fires `ClientChronicle` audit event, checks
  `AuthMethodGuard`
- `POST /settings/emails/registration` — enrolls new email via OTP
- `DELETE /settings/telephones/:id` — removes telephone
- `POST /settings/revocations/others` and `/all` — bulk session revocation
- `PATCH /settings/withdrawal` / `POST /settings/withdrawal` — account withdrawal state machine
- `POST /settings/secret_credentials` — creates API credential with raw secret in session
- `PATCH /settings/mfa/challenge` — sets MFA level on the Client record

**3. Which routes require step-up?**

Step-up is verified via `VerificationClient` concern and `step_up` macro:

- `/settings/birthdate` — `step_up only: :show` (scope: `settings_birthdate`)
- `/settings/secret_credentials/new`, `/create` — `step_up only: %i(new create)` (scope:
  `settings_secret_credential`)
- `/settings/withdrawal/*` — `verification_required_action? = true` (always; scope: `withdrawal`)
- `/settings/emails` edit/update/destroy — implicit via `verification_required_action?` (scope:
  `settings_email`)
- `/settings/mfa/challenge` show+update — `verification_required_action?` (scope: `settings_mfa`)
- `/settings/apple` edit/create/destroy — explicit `require_step_up_for_mutation!`
- `/settings/google` edit/create/destroy — same pattern

When these move to Acme, Acme's `VerificationClient` (or equivalent step-up concern) must be wired
with the same scopes. Do not lose step-up verification during migration.

**4. Which routes rely on Sign session state today?**

All Sign settings controllers use `AUTHENTICATION_MODE = :private` and `authenticate_client!`, which
reads the Sign-side session. After migration to Acme, the moved controllers must authenticate via
Acme's session (`AUTHENTICATION_MODE = :private` on Acme's `ApplicationController`), which is
already established for all existing Acme controllers.

**5. Which routes become simpler if Acme owned them?**

- Sessions/revocations: `AuthenticationSelectedSessionRevoker` already reads Acme-authority token
  data; routing through Sign adds a cross-authority hop.
- Withdrawal: `AcmeSettingsWithdrawalFlow` concern's name already signals Acme ownership; the shared
  concern currently runs on Sign's controller.
- MFA challenge: the `mfa_level` field lives on the `Client` model (Acme authority). Sign reading
  and writing it is an authority inversion.

**6. Which routes cannot safely be redirected on non-GET methods?**

All POST/PATCH/DELETE routes. Browsers do not follow redirect with the original method for form
submissions; a `302` or `303` on a mutation turns it into a GET to the target. Specifically:

- `POST /settings/emails/registration` → form data and OTP state lost
- `PATCH /settings/emails/:id` → preference params lost
- `DELETE /settings/emails/:id` → destructive action silently dropped
- `POST /settings/telephones/registration`
- `DELETE /settings/telephones/:id`
- `POST /settings/sessions/:id/revocation`
- `POST /settings/revocations/others`, `/all`
- `POST/PATCH/DELETE /settings/withdrawal`
- `POST /settings/mfa/challenge` (update)
- `POST /settings/secret_credentials`
- `PATCH/DELETE /settings/secret_credentials/:id`

**7. Which old Sign GET routes can safely become redirect shims?**

These GET endpoints can return `301` (permanent) or `302` (temporary during migration):

- `GET /settings` → `GET /identity` (Acme)
- `GET /settings/emails` → `GET /identity/emails`
- `GET /settings/emails/:id/edit` → `GET /identity/emails/:id/edit`
- `GET /settings/emails/registration/new` → `GET /identity/emails/registration/new`
- `GET /settings/telephones` → `GET /identity/telephones`
- `GET /settings/telephones/:id/edit` → `GET /identity/telephones/:id/edit`
- `GET /settings/telephones/registration/new` → `GET /identity/telephones/registration/new`
- `GET /settings/birthdate` → `GET /identity/birthdate`
- `GET /settings/secrets` → `GET /identity/recovery-secret`
- `GET /settings/secret_credentials` → `GET /identity/credentials`
- `GET /settings/secret_credentials/:id` → `GET /identity/credentials/:id`
- `GET /settings/sessions` → `GET /identity/sessions`
- `GET /settings/sessions/:id` → `GET /identity/sessions/:id`
- `GET /settings/activities` → `GET /identity/activities`
- `GET /settings/withdrawal/new` → `GET /identity/withdrawal/new`
- `GET /settings/withdrawal/edit` → `GET /identity/withdrawal/edit`
- `GET /settings/mfa/challenge` → `GET /identity/mfa/challenge`
- `GET /settings/mfa/reset` → `GET /identity/mfa/reset`

Use `302` during migration (temporary) and promote to `301` once Acme routes are stable and tested.

**8. Which old Sign mutation routes should become 405/410 instead of redirecting?**

All the non-GET routes listed in question 6. Recommended disposition:

- Return `410 Gone` (not `405 Method Not Allowed`) since the resource has moved, not just the
  method. A `410` with a human-readable body pointing users to the Acme URL is safe for bookmarked
  direct links.
- Do not redirect POST/DELETE: the body is lost and the user is confused.
- Do not accept the submission on Sign and forward it to Acme: this would require Sign to hold
  Acme-bound credentials and creates a confused proxy.

Exception: during a transitional phase where Acme mutation routes are not yet live, keep the Sign
mutation routes operational and do not return 410. Only stop accepting writes in Sign after the
corresponding Acme mutation route is live and tested.

**9. Which tests currently encode the old ownership boundary?**

All tests under `test/controllers/sign/app/settings/` that are NOT for passkeys, TOTPs, Google, or
Apple:

- `test/controllers/sign/app/settings/emails_controller_test.rb`
- `test/controllers/sign/app/settings/telephones_controller_test.rb` (if it exists)
- `test/controllers/sign/app/settings/sessions_controller_test.rb` (if it exists)
- `test/controllers/sign/app/settings/withdrawals_controller_test.rb`
- `test/controllers/sign/app/settings/activities_controller_test.rb` (if it exists)
- `test/controllers/sign/app/settings/secrets_controller_test.rb` (if it exists)
- `test/controllers/sign/app/settings/birthdates_controller_test.rb` (if it exists)
- `test/controllers/sign/app/settings/secret_credentials_controller_test.rb`
- MFA challenge/reset tests

These tests must eventually move to `test/controllers/acme/app/identity/` and be rewritten to assert
Acme auth context rather than Sign auth context.

**10. Which docs describe Sign as the settings authority, and how should they update?**

- `docs/security/preference-settings-authority.md` (32 lines): states "Sign owns settings shell on
  identity host, credential configuration, session mgmt UI." This is the primary doc that must be
  updated to reflect the new boundary. Update it to say Sign owns only credential ceremony
  management (passkeys, TOTP, Google, Apple); Acme owns everything else currently under `/settings`.
- `docs/identity/authority-boundary.md`: already has a supersession note (2026-06-12). The body
  still says Sign "may … keep credential inventory" which currently includes sessions and emails in
  practice. Add a clarifying note that credential inventory means passkey/TOTP/social inventory
  only, not email/telephone/session/withdrawal.
- `docs/index.md`: add `docs/architecture/sign-settings-to-acme-identity.md` to the content-model
  references list.

---

## Redirect / Deprecation Policy

```
GET routes moving to Acme:
  During migration:   Sign returns 302 → Acme identity path
  After stabilization: Sign returns 301 → Acme identity path
  Final removal:       Sign route deleted; only Acme route exists

Mutation routes (POST/PATCH/PUT/DELETE) moving to Acme:
  While Acme route is not yet live: Sign continues to accept writes (status quo)
  Once Acme route is live and tested: Sign route returns 410 Gone with body linking to Acme
  Do NOT redirect mutations. Do NOT proxy mutations from Sign to Acme.
  New forms must POST directly to Acme /identity paths.

Routes to NEVER redirect (stay in Sign permanently for this migration):
  /settings/passkeys/*
  /settings/passkeys/options
  /settings/passkeys/verification
  /settings/totps/*
  /settings/apple
  /settings/apple/edit
  /settings/google
  /settings/google/edit
```

---

## Implementation Phases (documentation only — do not implement)

### Phase 0 (this task): Inventory and docs

- Route/controller/view/test inventory. ✓ (this plan)
- Classify Sign `/settings` into keep/move/out-of-scope. ✓
- Write `docs/architecture/sign-settings-to-acme-identity.md`. ← output of this task
- Update `docs/security/preference-settings-authority.md`.
- Update `docs/index.md`.

### Phase 1: Acme `/identity` read surfaces

- Add `namespace :identity` to `config/routes/acme.rb`.
- Implement read-only Acme identity controllers for emails, telephones, birthdate, sessions,
  activities, MFA challenge (show only), withdrawal (show only), credentials (index/show).
- Extend `Acme::App::IdentitiesController#show` to link to moved pages.
- Link passkey/TOTP/Google/Apple management back to Sign settings URLs (not to Acme).
- Write `test/controllers/acme/app/identity/*` tests for each read endpoint.

### Phase 2: Move non-exception mutation flows to Acme

- Move email/telephone registration, update, destroy to Acme identity controllers.
- Move session revocation to Acme.
- Move withdrawal lifecycle to Acme (extract/port `AcmeSettingsWithdrawalFlow`).
- Move MFA level setting (challenge update) to Acme.
- Move recovery secret reveal to Acme.
- Move API credential (secret_credentials) CRUD to Acme.
- Preserve `AuthMethodGuard` checks, `ClientChronicle` audit events, and step-up requirements.
- Wire `VerificationClient` (or Acme equivalent) with the same verification scopes.
- Write mutation tests in `test/controllers/acme/app/identity/`.

### Phase 3: Sign redirect/deprecation shims

- Sign GET routes for moved features return 302 to Acme equivalents.
- Sign mutation routes return 410 Gone (after Phase 2 is live).
- Sign passkey/TOTP/Google/Apple routes remain unchanged.
- Write route contract tests proving moved Sign mutation routes no longer accept writes.

### Phase 4: Test cleanup

- Move remaining Sign settings tests to `test/controllers/acme/app/identity/`.
- Keep `test/controllers/sign/app/settings/passkeys_controller_test.rb`, `totps_controller_test.rb`,
  `apples_controller_test.rb`, `googles_controller_test.rb`.
- Add regression tests: Sign mutation routes return 410, Sign GET routes return 302/301.
- Update `docs/qa/identity-authority-regression-checklist.md` with new Acme identity checks.

### Phase 5 (future, out of scope for this migration)

- Sign temporary-session model issued by Acme.
- Sign no longer modeled as an RP with its own full session.
- Sign-out simplification.
- OIDC/session redesign.

Do not treat Phase 5 work as part of this migration. Do not design toward it in Phases 1–4.

---

## Open Questions / Blockers

1. **MFA challenge cross-DB read**: `Mfa::ChallengesController#show` reads passkeys and TOTPs from
   the Sign-side DB. When moved to Acme, will Acme have read access to Sign's credential tables, or
   must the page call a Sign API? Needs architecture decision before Phase 2 for MFA challenge.

2. **`AcmeSettingsWithdrawalFlow` concern**: Already named "Acme" but runs in Sign. Confirm it does
   not depend on Sign-side session internals before porting to an Acme controller.

3. **`AuthenticationSelectedSessionRevoker`**: Session revocation service used in Sign sessions
   controller. Confirm it operates on Acme-authority token data and can run from an Acme controller
   without modification.

4. **Step-up verification scope names**: Current scopes (`settings_email`, `settings_mfa`,
   `withdrawal`, etc.) are strings matched against the Sign-side `VerificationClient`. Confirm these
   scope names work unchanged in Acme's verification flow, or document the rename.

5. **`org` surface withdrawal**: Sign org surface has `resource :withdrawal, only: :show`
   (read-only), not the full state machine. Classification for org is different from app. Document
   separately.

6. **`com` surface coverage**: The `com` Sign surface has emails, telephones, sessions, revocations,
   activities, withdrawal, birthdate, and secret_credentials — but no Google/Apple and no TOTP (com
   has passkeys only). Verify this before Phase 1 to avoid building Acme com routes that don't exist
   yet.

---

## Output: Files to Create / Update

### Create

- `docs/architecture/sign-settings-to-acme-identity.md` — the primary ownership boundary document.
  Full content is the structured version of this plan with Summary, Decision, Inventory, Keep
  exceptions, Move targets, Route shape, Redirect policy, Security notes, Phases, Test plan, and
  Open questions sections.

### Update

- `docs/security/preference-settings-authority.md` — replace the claim that Sign owns "settings
  shell on identity host" with the correct boundary: Sign owns credential ceremony management
  (passkeys, TOTP, Google, Apple settings only); Acme owns all other identity/settings surfaces.
- `docs/index.md` — add `docs/architecture/sign-settings-to-acme-identity.md` to the content-model
  references list.

---

## Verification

After writing the docs, confirm:

```sh
# Route inventory spot-check (run if rails env is available)
bin/rails routes | grep -E 'settings|identity' | grep -v 'preference'

# File existence
ls docs/architecture/sign-settings-to-acme-identity.md
grep 'sign-settings-to-acme-identity' docs/index.md
grep -v 'settings shell on identity host' docs/security/preference-settings-authority.md
```

No code changes are part of this task. Verification is documentation review only.
