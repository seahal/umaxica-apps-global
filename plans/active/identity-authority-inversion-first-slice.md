# Identity Authority Inversion First Slice

## Status

Active implementation slice. This plan refines
`plans/identity-authority-inversion-implementation.md` and must not be used to reintroduce sign-side
authority.

## Current Implementation Conflicts

The accepted authority boundary is ahead of the current implementation. The following sign-side
behaviors are known migration gaps:

- `/sign/out` controllers still call the logout primitive directly.
- sign edge token refresh controllers still execute refresh token rotation.
- sign OAuth/OIDC token controllers still issue protocol tokens.
- sign dashboard, welcome, settings, preference, session-management, and withdrawal routes still
  exist as normal sign-side routes.
- sign step-up ceremony code still writes `last_step_up_at`, `last_step_up_scope`, and equivalent
  session-freshness fields.
- sign social callbacks and sign-up flows still make some account-linking or account-finalization
  decisions.

These gaps are compatibility implementation, not authority decisions. Existing sign-side tables,
models, services, tests, route helpers, and namespaces do not imply sign-side authority.

## Route Classification

Classify sign routes before changing behavior:

| Classification          | Route families                                                                                                                                       | Required first-slice behavior                                                                                              |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `KEEP_ON_SIGN_CEREMONY` | unauthenticated sign-in/sign-up entrance, sign-in/up guardrail, sign-in/up checkpoint, passkey/WebAuthn, OTP/TOTP, social callback, step-up ceremony | Keep on sign/id. Do not expand into session, token, preference, dashboard, account, authorization, or freshness authority. |
| `REDIRECT_TO_ACME`      | sign `/sign/out`, dashboard, welcome, top-level settings, top-level preference, settings sessions, settings withdrawal                               | Preserve old URLs where practical, but redirect to acme authority routes.                                                  |
| `MOVE_TO_ACME`          | logout, dashboard, welcome, settings, preference writes, session listing/revoke/revoke-all, withdrawal/account lifecycle                             | Add or complete acme routes/controllers that own the mutation or authenticated page.                                       |
| `TEMP_COMPAT_DELEGATE`  | OAuth/OIDC discovery, JWKS, authorize, token, userinfo, revoke, logout; credential settings that still commit account state                          | Keep working if moving would break flows. Add explicit TODO/FIXME and tests documenting compatibility.                     |
| `REMOVE_LATER`          | sign authority pages after acme replacements are covered                                                                                             | Remove in a later slice after redirects and tests are stable.                                                              |

## First-Slice Implementation Rules

- Do not modify physical database placement.
- Do not rename databases, tables, or token models.
- Do not implement broad ceremony grant/result protocol in this slice.
- Do not rewrite all authentication, sign-in, sign-up, social login, or step-up behavior.
- Preserve old endpoint access where practical through redirects or explicit compatibility
  delegates.
- Use route helpers and explicit host/protocol handling; do not hardcode absolute URLs.
- Keep `app`, `com`, and `org` behavior surface-local.

## Security Requirements

For every security-sensitive behavior touched by this slice, classify the risk as one or more of:

- OWASP Cheat Sheet Series concern: authentication, session management, CSRF prevention, unvalidated
  redirects and forwards, OAuth/OIDC token handling, or logging and sensitive-data exposure.
- NIST SP 800-63B concern: AAL vocabulary, step-up or reauthentication, authenticator binding,
  authenticator lifecycle, freshness or recent authentication, or phishing-resistant authenticator
  treatment.
- Project-specific authority-boundary concern: acme/www authority versus sign/id ceremony-only
  compatibility.

Required security checks:

- sign/id must not directly mutate session, token, refresh, session inventory, withdrawal, or
  account-lifecycle state in this slice.
- sign/id compatibility endpoints must redirect or delegate only to acme route helpers.
- Do not introduce open redirects. Redirect targets must not be user-controlled unless an existing
  validated return-target transaction mechanism is used.
- Do not convert unsafe mutations to `GET`.
- Preserve CSRF protections for destructive actions.
- Preserve host and surface separation.
- Do not share authentication cookies between sign/id and acme/www.
- OIDC/OAuth compatibility routes must not issue new sign-authority claims in new code.
- Logging added or touched by this slice must not include tokens, cookies, authorization headers, or
  full request parameters.

## Maintainability Requirements

- If multiple sign controllers need the same redirect-only behavior, extract a small helper or
  concern.
- Prefer Rails concerns under `app/controllers/concerns` only when shared behavior is real.
- Do not create concerns that register hidden `before_action` callbacks merely by being included.
- Avoid broad base-controller changes unless required by the route flow.
- Keep comments short and in English.
- Add comments only where the authority boundary is non-obvious, for example:
  `sign/id is redirect-only here; acme/www owns session mutation.`
- Remove dead code only when it is clearly unused by the new route flow and covered by tests.
- Mark retained compatibility code with TODO/FIXME text that names the next slice.

## Performance Requirements

- Redirect-only sign endpoints must avoid loading actor, preference, token, session inventory, or
  withdrawal state unless needed to compute the redirect.
- Check whether inherited `before_action` callbacks or included concerns still perform expensive
  work on redirect-only endpoints.
- If unavoidable in this slice, add TODO/FIXME text with the exact concern or filter to remove in
  the next slice.
- For acme session inventory, check for obvious N+1 risks and use `includes` or `preload` only when
  the query actually needs associated records.
- Avoid broad eager loading without a failing test, clear query need, or visible review evidence.

## Required Work

1. Add acme authority entry points for logout, dashboard, welcome, settings, preference, session
   management, and withdrawal for each supported surface.
2. Change sign `/sign/out` controllers to redirect-only or delegate-only behavior. After the slice,
   sign controllers must not call `logout_current_session!` directly.
3. Change sign dashboard and welcome routes/controllers to compatibility redirects to acme.
4. Change sign settings, preference, settings sessions, and withdrawal routes/controllers to
   redirect to acme unless the route is a credential ceremony that intentionally remains on sign.
5. Inventory OAuth/OIDC sign routes. Add acme aliases only if existing token flows remain passing;
   otherwise keep them as `TEMP_COMPAT_DELEGATE` with a TODO/FIXME.
6. Add architecture guard tests, negative mutation tests, and security-property tests for sign
   redirect-only behavior and acme authority endpoint existence.

## Required Test Properties

- Regression tests for old sign URLs.
- Authority tests for new acme URLs.
- Negative tests proving sign endpoints do not perform local session, refresh, token, preference,
  withdrawal, or freshness mutation.
- Route tests proving sign-in, sign-up, guardrail, checkpoint, and credential ceremony routes remain
  on sign.
- Update existing tests rather than deleting coverage.
- If behavior changes intentionally, document the change in the test name.

Use explicit security-property test names where practical:

- `test_sign_out_redirect_is_not_session_mutation`
- `test_sign_out_redirect_uses_acme_authority`
- `test_redirect_target_is_not_user_controlled`
- `test_destroy_requires_non_get_method`
- `test_step_up_freshness_is_not_committed_on_sign`

## Security Standards Mapping

| Behavior touched                                | OWASP concern                                                   | NIST SP 800-63B concern                                      | Project authority-boundary concern                                           |
| ----------------------------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------ | ---------------------------------------------------------------------------- |
| sign `/sign/out` compatibility redirect         | Session Management, CSRF Prevention, Unvalidated Redirects      | reauthentication and freshness cleanup impact                | sign/id must not mutate logout or session state                              |
| acme logout/session destroy                     | Session Management, CSRF Prevention, logging exposure           | reauthentication and freshness invalidation                  | acme/www is the only session mutation authority                              |
| sign dashboard, welcome, settings redirects     | Unvalidated Redirects, Authentication                           | none unless freshness checks are invoked                     | sign/id must not present signed-in authority UI                              |
| sign preference/settings write compatibility    | CSRF Prevention, Authentication, Session Management             | none unless authenticator settings are touched               | sign/id must not commit preference writes                                    |
| sign session inventory/revoke compatibility     | Session Management, CSRF Prevention                             | authenticator/session lifecycle interaction                  | sign/id must not list, revoke, or rotate sessions                            |
| sign withdrawal/account lifecycle compatibility | Authentication, CSRF Prevention, logging exposure               | reauthentication before sensitive account actions            | sign/id must not own withdrawal or account lifecycle                         |
| sign token/refresh/OIDC compatibility           | OAuth/OIDC token handling, Session Management, logging exposure | AAL vocabulary, authenticator binding, freshness propagation | new authority must be acme; retained sign routes are temporary compatibility |
| sign step-up ceremony compatibility             | Authentication, Session Management                              | AAL1/AAL2, step-up, authenticator lifecycle, recent auth     | sign/id may execute ceremony but must not commit freshness                   |
| redirect target handling                        | Unvalidated Redirects and Forwards                              | none                                                         | authentication result transport must not be confused with navigation         |
| touched logging                                 | Logging and sensitive-data exposure                             | authenticator lifecycle evidence must avoid secret exposure  | logs must not become authority records                                       |

## Tests And Checks

Run after implementation:

```bash
bin/rails routes | grep -E "sign|acme|logout|settings|preference|dashboard|withdrawal|oauth|oidc"
bin/rails test test/controllers/sign test/controllers/acme
rg -n "logout_current_session!" app/controllers/sign app/controllers/concerns/sign
rg -n "before_action|include .*Session|include .*Preference|include .*Authentication|include .*Verification|logout_current_session!|refresh_access_token|revoke_all|withdrawal" app/controllers/sign app/controllers/concerns/sign
rg -n "TODO|FIXME" app/controllers/sign app/controllers/acme app/controllers/concerns
rg -n "resources :sessions|resource :dashboard|resource :settings|resource :preference|resource :withdrawal|namespace :oauth|namespace :oidc|resource :sign_out" config/routes/sign.rb config/routes/acme.rb
git diff --stat
git diff -- config/routes/sign.rb config/routes/acme.rb app/controllers/sign app/controllers/acme test
```

## Next-Slice Risks

- Step-up ceremony currently writes freshness directly; the next slice must move freshness commit to
  acme result consumption.
- Social callback validation may stay on sign, but account linking decisions must move to acme.
- Sign-up credential ceremony may stay on sign, but account finalization must move to acme.
- OAuth/OIDC issuer, discovery, token, revoke, and logout authority need a dedicated acme token
  authority migration slice.
