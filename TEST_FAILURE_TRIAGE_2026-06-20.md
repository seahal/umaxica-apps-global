# Test Suite Triage — 2026-06-20

`bin/rails test` on `develop` reports **114 failures + 50 errors (164 total)** out of 8182 runs.
This note records what was root-caused and fixed, and what was intentionally left because it is
in-progress migration work rather than an isolated, determinable defect.

The local WIP diff (`preference_access_token_transport.rb`, `sign_up_cycle_locator.rb` and their
tests) is unrelated to these failures and its own tests pass.

## Fixed (isolated, well-evidenced)

### 1. Social provider rename `google_app` -> `google`

Commit `771e639fc` changed `IdentitySocialCeremonyContract::PROVIDERS` from `%w(apple google_app)`
to `%w(apple google)`, completing the OmniAuth provider rename (see
`config/initializers/omniauth.rb` `name: "google"` and
`app/models/concerns/social_identifiable.rb:11` —
`"google_app" => "google", # legacy DB value; OmniAuth provider renamed to "google"`). The
`client_google_identities.provider` column default is now `"google"` (the schema annotation comment
is stale). Several tests still pinned the old literal and broke (contract validation
`provider is invalid`, `I18n::MissingTranslationData` while building the validation error, and a
`find_or_initialize_by` miss against the new default).

Updated the stale `google_app` literals to `google` in:

- `test/services/identity/social_ceremony_contract_test.rb`
- `test/services/identity/social_ceremony_acme_transaction_test.rb` (committer stores
  `normalize_provider(provider)` = `"google"`)
- `test/models/client_google_identity_test.rb` (non-comment lines only; schema annotation left
  as-is)

NOTE: `google_app` is still a _legitimate_ value elsewhere — the OmniAuth start path
`/auth/google_app`, the legacy `PROVIDER_MAP` key, and `model_for_provider`. It was **not**
blanket-replaced across the test tree; only the social-ceremony/identity tests whose provider must
be a current `PROVIDERS` member were touched.

### 2. `test/services/identity/social_ceremony_contract_test.rb` SQL helper bug

`encrypted_social_candidate_auth_hash` passed a `Regexp` literal as the SQL template to
`sanitize_sql_array` (`NoMethodError: include? for Regexp`). Replaced with the intended string
template `"SELECT auth_hash FROM identity_social_ceremony_candidates WHERE ref = ?"`. This was
masked before because the provider error aborted the test earlier.

### 3. `test/services/org/operator_lifecycle/execute_test.rb`

- Restore test: `OrgOperatorLifecycleExecute#restore_operator!` sets `discarded_at: Float::INFINITY`
  (the active sentinel; the last-active guard uses `discarded_at > now`). The assertion
  `assert_operator discarded_at, :>, Time.current` raised `comparison of Float with TimeWithZone`.
  Switched to `assert_equal Float::INFINITY, target.discarded_at`.
- Last-active test: `OrgOperatorLifecycleExecute` gained a self-execution guard
  (`requested_by_actor?`, "Requester cannot execute their own lifecycle request") that fires before
  the last-active check. The test used the same operator as requester and executor, so it tripped
  the wrong guard. Changed the executor to `operators(:sample_staff)` so requester != actor and the
  intended last-active path is exercised.

## Left intentionally — Acme/Sign authority-inversion migration (~140 failures)

The dominant failure category is the **in-progress, accepted** authority migration: Acme becomes the
sole IdP / Authorization Server (issuer/subject, OIDC, sessions, refresh, logout, account/identity
settings, telephone/email/authenticator management, dashboards, step-up freshness), and Sign is
retired to a credential-gateway / ceremony surface.

Source of truth:

- ADR `adr/acme-sign-core-base-port-boundary.md` (Accepted 2026-06-12) and supporting ADRs
  (`identity-authority-boundary.md`, `acme-session-and-token-authority.md`,
  `sign-credential-gateway-surface.md`, `sign-residual-idp-surface-retirement.md`).
- `plans/active/acme-sign-core-base-port-implementation.md`,
  `plans/identity-authority-inversion-implementation.md`.

These tests are spec-first slices (`*_authority_slice_1a/1c/1i/1j_test.rb`,
`acme/authenticator_lifecycle_authority_test.rb`, the `sign/**/settings` compatibility-redirect
tests) for endpoints that are **not yet implemented**. Symptoms, all consistent with "Acme side not
built / Sign side not yet redirecting":

- `404 Not Found` on `acme_*` settings/authenticator endpoints (~17).
- Missing route helpers `acme_app_settings_secret_url`,
  `enrollment_acme_app_settings_{secrets,totps, passkeys}_url`,
  `new_acme_com_settings_withdrawal_path`, `acme_org_current_avatar_path`,
  `acme_*_auth_authorization_*`, `edit_acme_*_settings_email_url`, etc. (~14).
- "`<Model>.count` didn't change" — mutations expected to move under Acme authority (~9).
- `Sign::Org::Settings::{Telephones,Activities}Controller` etc. still define their own `index`/
  `destroy` actions which shadow the `SignSettingsAuthorityRedirect` concern's redirect stubs
  (method-definition-after-include wins), so the real action runs and hits `current_operator` = nil
  (`undefined method 'staff_telephones'/'find' for nil`). The compatibility redirect was the intent;
  completing it is migration work.

Completing any of these means building Acme controllers/routes/views and the Sign-side redirects —
i.e. executing the migration, not fixing a test. Left for the planned slice work.

## Left intentionally — smaller items entangled with the migration (not cleanly determinable)

- `Acme::App::Social::AuthenticationsControllerTest` — `undefined method 'include?' for Symbol` and
  `DoubleRenderError` in the social completion flow (app social link/unlink must delegate to Sign
  per the ADRs; flow is mid-change).
- `Acme::App::Oidc::LogoutsControllerTest`, `Acme::App::SwitcherControllerTest`,
  `Acme::Com::Oidc::LogoutsControllerTest` — `422 Unprocessable` (turnstile/CSRF/form contract under
  the new Acme authority).
- `OidcClientRegistryTest` — expected redirect/callback config (`/auth/callback`) and client
  registration differ; OIDC client registry config change tied to the boundary work.
- `PageTitlePresenceTest` — 22 views missing a `page_title` declaration (largely newly added Acme
  views); should be filled in as those views are finalized.
- `CommonRedirectTest`, `jump_rt/*`, `step_up/scope_catalog_test`, `unit/security/*inventory*` —
  redirect-logging / scope-catalog / harness-inventory expectations that move with the same boundary
  change.
- `OrgOperatorLifecycleExecuteTest` last-active path was fixed, but if read/write splitting is added
  to that count query in future, watch for replica-visibility flakiness (the count must run on the
  writing/primary connection within the request).

## Gaps to promote later

- The `provider :string default("google_app")` schema annotations in
  `app/models/client_google_ identity.rb`, `client.rb`, etc. are stale (actual default is `google`).
  Regenerate annotations.
- Legacy `google_app` rows predating the rename are not matched by the current
  `find_or_create_from_auth_hash` (raw provider, no normalization on lookup). If such rows exist in
  any environment, a data backfill `UPDATE provider='google' WHERE provider='google_app'` is needed,
  or the lookup must normalize. Out of scope here; flagged for the social migration owner.
