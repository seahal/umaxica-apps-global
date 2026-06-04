# Identity Authority Regression Checklist

## Purpose

Use this checklist when implementing or reviewing Identity Authority inversion work.

## Current Status

Status: `COMPLETE_WITH_BOUNDED_LEGACY` as of 2026-06-03.

The retained-authority closure removed the sign-side step-up freshness fallback and moved every app
social link final commit to acme completion. The sign callback now rejects BOTH grantless app social
`intent: "link"` (including the already-signed-in auto-link path) and grantless established app
social login; neither can create or mutate a social link or session on sign. Grant-backed link
commits are owned by `Acme::App::Social::AuthenticationsController#completion`
(`Identity::SocialCeremony::FinalCommitter`), are one-shot, and reject replay. Refresh rotation now
lives physically in `Acme::RefreshTokenService`; `Sign::RefreshTokenService` is a behavior-free
compatibility subclass.

Remaining bounded legacy:

- Unknown / incomplete social signup and account-selection remains bounded sign compatibility and
  must be moved to acme decision flow later. These paths still complete on the sign-side
  compatibility path (`SocialAuthService.handle_callback`). "Established account" is approximated by
  the birthdate-present predicate in `acme_social_login_completion_supported?` (birthdate is the
  final sign-up checkpoint); it is documented in code and guarded by tests. It does not expand link,
  unlink, token, or established-login authority.
- `Sign::RefreshTokenService` remains as a compatibility namespace only. Target paths call
  `Acme::RefreshTokenService`; the sign subclass implies no sign-side refresh issuer or authority
  and is pinned by `IdentityAuthorityInversionGuardTest`.

## Negative Checks

- `sign/id` does not issue, refresh, rotate, revoke, list, or display user sessions.
- `sign/id` does not issue access tokens, refresh tokens, downstream tokens, or step-up freshness.
- `sign/id` does not store `recent_auth`, `sudo`, `last_step_up_at`, or equivalent freshness.
- `sign/id` does not own preference writes, settings, dashboards, withdrawal, account lifecycle, or
  session-management UI.
- Migrated acme pages render acme templates/layouts and do not reuse `sign/...` account, preference,
  dashboard, settings, withdrawal, session-management, or sign-out templates.
- Migrated acme forms submit to acme routes; they do not generate `id.umaxica.*` or other sign-host
  form actions. Credential ceremony links to sign remain allowed only when they intentionally start
  a retained ceremony.
- `/sign/out`, if retained, redirects to acme logout and does not mutate session/token state.
- `core` and `line` reject sign-issued session/access/downstream tokens.
- Social provider callbacks on `sign/id` return evidence only; acme owns account linking.
- WebAuthn/passkey ceremonies on `sign/id` return evidence only; acme owns session/account effects.
- Redirect targets and OAuth/OIDC `state` do not carry authentication result facts.
- Existing sign-side physical tables/models are not treated as sign-side authority.
- Sign-side OAuth/OIDC, JWKS, userinfo, revocation, logout, and edge token endpoints are
  compatibility redirects, delegates, wrappers, or blocked endpoints only.
- Established app Google/Apple social login completes through acme-owned session decision.
- Grantless established app Google/Apple social login is rejected on the sign callback; it must not
  create a sign-side session.
- Grantless app social `intent: "link"` (including the already-signed-in auto-link path) is rejected
  on the sign callback; it must not create or mutate a social link on sign.
- App settings social link final commit occurs on acme completion only, is one-shot, and rejects
  replay; it never commits inline on the sign callback.
- Unknown social signup or account-selection paths, if retained, are classified as bounded legacy
  and have tests proving they do not expand link, unlink, token, or established-login authority.

## Positive Checks

- `acme/www` commits session, account, preference, token, authorization, and freshness state.
- Delegated ceremonies use acme-issued grants and signed sign-issued results.
- Ceremony results are short-lived, audience-bound, purpose-bound, one-shot, and transaction/session
  bound where applicable.
- Downstream services trust acme-issued downstream tokens only.
- `acme/www` owns OAuth/OIDC discovery, JWKS, authorization, token, userinfo, revocation, OIDC
  logout, and edge token refresh endpoints for new flows.
- `acme/www` owns final contact, authenticator, social link/unlink, and established social login
  commits.

## OWASP Review

- Destructive or freshness/token mutation endpoints are non-GET.
- CSRF protection remains enabled for browser-authenticated mutating endpoints.
- Compatibility redirects use fixed route helpers and do not accept arbitrary external targets.
- Provider tokens, refresh tokens, session tokens, raw passwords, TOTP seeds, and ceremony secrets
  do not appear in URLs, logs, grant payloads, or browser-carried result payloads.
- OAuth/OIDC state, nonce, PKCE, issuer, audience, and redirect URI validation remain covered.
- Refresh token rotation remains one-shot and replay-safe; compromised families are revoked.
- JWKS exposes public keys only.

## NIST / Identity Review

- `acme/www` owns session, token, account, and step-up freshness decisions.
- `sign/id` remains a credential ceremony executor and provider callback surface.
- AAL, `acr`, `amr`, and `auth_time` semantics are preserved.
- Step-up freshness is recent reauthentication committed by acme-owned state.
- Social provider proof is external identity evidence, not local session authority.
- Contact OTP remains contact/verifier proof; it is not treated as phishing-resistant.
- Passkey/WebAuthn, TOTP, and secret credential enrollment distinguish ceremony from final binding.

## Compatibility Classification Checks

Classify every remaining sign-side hit as one of:

- `CEREMONY_ALLOWED`
- `PROVIDER_CALLBACK_ALLOWED`
- `COMPATIBILITY_WRAPPER_ALLOWED`
- `BOUNDED_LEGACY_UNKNOWN_SOCIAL`
- `OUT_OF_SCOPE_SIGN_IN_SIGN_UP`
- `DEAD_CODE_REMOVE`
- `AUTHORITY_VIOLATION_FIX`

Do not leave sign-side session, token, account, preference, freshness, or lifecycle mutations
unclassified.

## Guard Commands

```bash
rg -n "logout_current_session!|logout_all_sessions_for!|RefreshTokenService|refresh_access_token|transparent_refresh|TokenExchangeService|AuthorizeService|userinfo|revocation|revoke|jwks|openid|oidc|oauth|last_step_up_at|last_step_up_scope|recent_auth|sudo|Preference::|Withdrawal::Lifecycle|SocialAuthService|create_session|dashboard|settings" app/controllers/sign app/controllers/concerns/sign app/services/sign app/views/sign app/helpers test/controllers/sign test/integration
rg -n "sign.*IdP|id.*IdP|sign.*session|sign.*token|sign.*refresh|sign.*preference|sign.*settings|sign.*dashboard|sign.*withdrawal|sign.*OAuth|sign.*OIDC|sign.*step-up|sign.*freshness|sign.*social.*link|sign.*account" docs plans adr
rg -n "surface:SIGN|SIGN_.*issuer|SIGN_.*jwks|sign.*issuer|sign.*token|Sign::RefreshTokenService" app lib test config
```

## Regression Commands

```bash
bin/rails test test/controllers/acme/oauth_oidc_authority_test.rb
bin/rails test test/controllers/acme/authenticator_lifecycle_authority_test.rb test/controllers/acme/step_up_intent_authority_test.rb
bin/rails test test/services/identity/passkey_ceremony_contract_test.rb test/services/identity/passkey_ceremony_acme_transaction_test.rb
bin/rails test test/services/identity/totp_ceremony_contract_test.rb test/services/identity/totp_ceremony_acme_transaction_test.rb
bin/rails test test/services/identity/secret_credential_ceremony_contract_test.rb test/services/identity/secret_credential_ceremony_acme_transaction_test.rb
bin/rails test test/services/identity/step_up_ceremony_contract_test.rb test/services/identity/step_up_ceremony_acme_transaction_test.rb
bin/rails test test/services/identity/telephone_ceremony_contract_test.rb test/services/identity/telephone_ceremony_acme_transaction_test.rb
bin/rails test test/services/identity/email_ceremony_contract_test.rb test/services/identity/email_ceremony_acme_transaction_test.rb
bin/rails test test/services/identity/social_ceremony_contract_test.rb test/services/identity/social_ceremony_acme_transaction_test.rb
bin/rails test test/integration/social_auth_login_test.rb test/integration/social_auth_app_flow_contract_test.rb test/integration/social_auth_unlink_test.rb test/integration/social_link_unlink_test.rb
bin/rails test test/integration/sign/app/credential_removal_constraints_test.rb test/integration/sign/com/credential_removal_constraints_test.rb test/integration/sign/org/credential_removal_constraints_test.rb
bundle exec rails test test/controllers/sign test/controllers/acme
```
