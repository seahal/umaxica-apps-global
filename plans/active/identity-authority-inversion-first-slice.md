# Identity Authority Boundary First Slice

## Status

Active implementation slice. This plan refines
`plans/identity-authority-inversion-implementation.md` and must not be used to restore the old
`sign/id` ceremony-only or Acme aggregation model.

## Current Implementation Conflicts

The accepted authority boundary is ahead of the current implementation. The following migration gaps
are known:

- Sign refresh/logout/session-revoke routes exist, but some paths still call token mutation
  primitives directly from controllers instead of a Sign authority facade.
- Sign step-up routes exist, but Acme business mutations need explicit verification and consumption
  of Sign step-up results.
- Sign app social callback/sign-up routes exist, but callback handling must be checked for premature
  durable Client/provider identity/ClientAccount creation before the approved confirmation checkpoint.
- Acme preference routes/controllers/dispatch still expose old acme preference-authority behavior.
- Acme app social link/unlink routes/controllers must not perform durable identity mutations; they
  must redirect or delegate to Sign app social authority.
- External RP-facing OIDC provider behavior still needs a retained/delegated/retired classification
  separate from internal Sign refresh/logout authority.
- Sign account, organization, avatar, selector, dashboard, RP authorization, and SNS-body behavior
  must be redirected, delegated, or removed unless the route is a credential, preference, refresh,
  logout, step-up, or app social authority endpoint.

These gaps are compatibility implementation, not authority decisions. Existing route helpers,
namespaces, and physical table locations do not override the logical authority boundary.

## Route Classification

Classify routes before changing behavior:

| Classification | Route families | Required first-slice behavior |
| --- | --- | --- |
| `SIGN_AUTHORITY` | identity entry, credential ceremonies, refresh, logout, session-token revocation, step-up, Preference screens/JWT/cookie, app social link/unlink | Keep on Sign. Route mutations through explicit Sign authority facades where practical. |
| `ACME_AUTHORITY` | Account, Organization, Avatar, Selector, Dashboard, RP Authorization, Billing, Activity, SNS body | Keep on Acme. Do not complete these business mutations inside Sign controllers. |
| `ACME_TO_SIGN_COMPAT` | Acme preference routes, Acme app social link/unlink compatibility routes | Preserve old URLs where practical, but redirect or JumpRT-delegate to Sign. |
| `SIGN_TO_ACME_COMPAT` | Sign account settings, dashboard, selector, organization/avatar/account business routes | Preserve old URLs where practical, but redirect or delegate to Acme. |
| `EXTERNAL_RP_REVIEW` | External RP-facing OIDC discovery, authorize, token, userinfo, revoke, logout | Classify as retained, delegated, or retired. If retired, remove routes/controllers/links rather than moving them to Acme. |
| `REMOVE_LATER` | Compatibility routes after replacements are covered | Remove in a later slice after redirects/delegation and tests are stable. |

## First-Slice Implementation Rules

- Do not modify physical database placement.
- Do not rename databases, tables, or token models.
- Do not rewrite all authentication, sign-in, sign-up, social login, refresh, logout, preference, or
  step-up behavior.
- Preserve old endpoint access where practical through redirects or explicit compatibility
  delegation.
- Use route helpers and explicit host/protocol handling; do not hardcode absolute URLs.
- Keep `app`, `com`, and `org` behavior surface-local.

## Security Requirements

For every security-sensitive behavior touched by this slice, classify the risk as one or more of:

- OWASP Cheat Sheet Series concern: authentication, session management, CSRF prevention, unvalidated
  redirects and forwards, OAuth/OIDC token handling, or logging and sensitive-data exposure.
- NIST SP 800-63B concern: AAL vocabulary, step-up or reauthentication, authenticator binding,
  authenticator lifecycle, freshness or recent authentication, or phishing-resistant authenticator
  treatment.
- Project-specific authority-boundary concern: Sign authority versus Acme authority.

Required security checks:

- Acme compatibility endpoints must not perform durable Preference writes or Preference JWT/cookie
  issuance, update, or revocation.
- Acme app social compatibility endpoints must not create, link, or unlink durable identities
  directly.
- Sign account/dashboard/business compatibility endpoints must not perform durable Account,
  Organization, Avatar, Selector, Dashboard, RP Authorization, or SNS-body mutations directly.
- Sign refresh/logout/session-revoke endpoints should go through Sign authority facades that provide
  durable state transitions, idempotency, replay protection, and family revocation where applicable.
- Sign step-up results consumed by Acme business mutations must be verifiable and scoped.
- Do not introduce open redirects. Redirect targets must not be user-controlled unless an existing
  validated return-target or JumpRT mechanism is used.
- Do not convert unsafe mutations to `GET`.
- Preserve CSRF protections for destructive actions.
- Preserve host and surface separation.
- Logging added or touched by this slice must not include tokens, cookies, authorization headers, or
  full request parameters.

## Maintainability Requirements

- Prefer explicit authority services such as `Sign::RefreshAuthority`, `Sign::LogoutAuthority`,
  `Sign::StepUpAuthority`, `Sign::PreferenceAuthority`, or `Sign::AppSocialAuthority` over
  controller-level direct mutation primitives.
- If multiple compatibility controllers need the same redirect/delegation behavior, extract a small
  helper or concern.
- Prefer Rails concerns under `app/controllers/concerns` only when shared behavior is real.
- Do not create concerns that register hidden `before_action` callbacks merely by being included.
- Avoid broad base-controller changes unless required by the route flow.
- Keep comments short and in English.
- Remove or replace comments that say Preference, Refresh, Logout, or Step-up authority belongs to
  Acme when the behavior is browser/request identity authority.
- Remove dead code only when it is clearly unused by the new route flow and covered by tests.
- Mark retained compatibility code with TODO/FIXME text that names the next slice.

## Performance Requirements

- Redirect-only compatibility endpoints must avoid loading actor, preference, token, session
  inventory, account, organization, avatar, dashboard, activity, or SNS state unless needed to
  compute the handoff.
- Check whether inherited `before_action` callbacks or included concerns still perform expensive
  work on redirect/delegation-only endpoints.
- If unavoidable in this slice, add TODO/FIXME text with the exact concern or filter to remove in
  the next slice.
- Avoid broad eager loading without a failing test, clear query need, or visible review evidence.

## Required Work

1. Inventory current Sign authority routes for refresh, logout, session-token revocation, step-up,
   Preference, and app social link/unlink.
2. Inventory current Acme authority routes for Account, Organization, Avatar, Selector, Dashboard,
   RP Authorization, Billing, Activity, and SNS-body behavior.
3. Change Acme preference routes/controllers to redirect or JumpRT-delegate to Sign.
4. Change Acme app social link/unlink compatibility routes/controllers to redirect or delegate to
   Sign app social authority.
5. Change Sign account/dashboard/business compatibility routes/controllers to redirect or delegate to
   Acme.
6. Replace direct controller token/session mutation in touched Sign refresh/logout/session-revoke
   paths with Sign authority facades where practical; otherwise mark the retained direct mutation as
   a next-slice TODO/FIXME.
7. Audit app social callback/sign-up flow for premature durable Client/provider
   identity/ClientAccount creation before confirmation checkpoint finalization.
8. Classify external RP-facing OIDC provider routes as retained, delegated, or retired.
9. Add architecture guard tests, negative mutation tests, and security-property tests for the above
   compatibility and authority boundaries.

## Required Test Properties

- Regression tests for old compatibility URLs.
- Authority tests for Sign refresh/logout/session-revoke, step-up, Preference, and app social
  link/unlink URLs.
- Authority tests for Acme account, organization, avatar, selector, dashboard, RP authorization,
  billing, activity, and SNS-body URLs.
- Negative tests proving Acme preference compatibility endpoints do not perform durable Preference
  writes or Preference JWT/cookie issuance, update, or revocation.
- Negative tests proving Acme app social compatibility endpoints do not create, link, or unlink
  identities directly.
- Negative tests proving Sign compatibility endpoints do not perform Acme business mutations.
- Tests proving social callback creates pending evidence before confirmation and durable
  Client/provider identity/ClientAccount records only at the approved finalization point.
- Tests proving existing IdP collisions do not create a duplicate identity.
- Update existing tests rather than deleting coverage.
- If behavior changes intentionally, document the change in the test name.

Use explicit security-property test names where practical:

- `test_acme_preference_compatibility_does_not_write_preference`
- `test_acme_social_compatibility_does_not_link_identity_directly`
- `test_sign_refresh_uses_refresh_authority`
- `test_sign_logout_is_idempotent`
- `test_sign_step_up_result_is_scoped_for_acme_consumption`
- `test_social_callback_stores_pending_evidence_before_confirmation`
- `test_social_idp_collision_does_not_create_duplicate_identity`

## Security Standards Mapping

| Behavior touched | OWASP concern | NIST SP 800-63B concern | Project authority-boundary concern |
| --- | --- | --- | --- |
| Sign refresh/logout/session revoke | Session Management, CSRF Prevention, logging exposure | authenticator/session lifecycle, replay resistance | Sign owns refresh, logout, and session-token revocation |
| Sign step-up | Authentication, Session Management | AAL vocabulary, step-up, freshness, authenticator binding | Sign owns step-up evidence; Acme consumes scoped results |
| Sign Preference authority | CSRF Prevention, Authentication, Session Management | none unless authenticator settings are touched | Sign owns browser/request Preference writes and Preference JWT/cookie state |
| Sign app social link/unlink | Authentication, CSRF Prevention, OAuth/OIDC token handling | authenticator lifecycle, recent authentication where required | Sign owns app social identity mutation |
| Acme preference compatibility | CSRF Prevention, Authentication, Session Management | none unless authenticator settings are touched | Acme must not commit Preference writes or issue Preference JWT/cookie state |
| Acme business authority | Authentication, Authorization, CSRF Prevention | step-up result consumption for sensitive actions | Acme owns Account, Organization, Avatar, Selector, Dashboard, RP Authorization, and SNS-body state |
| External RP/OIDC retirement | OAuth/OIDC token handling, logging exposure | authenticator binding where retained | external RP service is separate from internal Sign refresh/logout authority |
| redirect or JumpRT target handling | Unvalidated Redirects and Forwards | none | authority result transport must not be confused with navigation |
| touched logging | Logging and sensitive-data exposure | authenticator lifecycle evidence must avoid secret exposure | logs must not become authority records |

## Tests And Checks

Run after implementation:

```bash
bin/rails routes | grep -E "sign|acme|logout|settings|preference|dashboard|social|oauth|oidc"
bin/rails test test/controllers/sign test/controllers/acme
rg -n "refresh_access_token|logout_current_session!|revoke!|destroy!|update!" app/controllers/sign app/controllers/acme
rg -n "PreferenceScreenDispatch|Preference authority belongs to acme|Acme::Preference" app/controllers app/controllers/concerns test
rg -n "resources :sessions|resource :dashboard|resource :settings|resource :preference|namespace :social|namespace :oauth|namespace :oidc|resource :sign_out" config/routes/sign.rb config/routes/acme.rb
git diff --stat
git diff -- config/routes/sign.rb config/routes/acme.rb app/controllers/sign app/controllers/acme test
```

## Next-Slice Risks

- Some direct Sign token/session mutation paths may require deeper service extraction than this slice
  can safely complete.
- Social callback collision handling must be checked against current tests before moving any
  finalization point.
- External RP-facing OIDC retirement may require docs, UI link, and client cleanup in a separate
  slice.
