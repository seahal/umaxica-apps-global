# Grill Me: Routes / OAuth-OIDC Logout Boundary Audit

Status: audit only. No code, route, test, ADR, doc, memo, or note changes proposed. Date:
2026-06-15. Scope: `config/routes/*.rb`, every logout/sign-out/revocation controller across `acme`,
`sign`, `core`, `palm`, and the concerns / services that back them, measured against ADRs, docs, and
active plans recovered from `adr/`, `docs/`, `plans/`, `notes/`, `memos/`.

## Context

Recent ADRs (`adr/logout-completion-boundary.md`, `adr/acme-session-and-token-authority.md`,
`adr/logout-primitive-and-composition.md`) realigned the logout flow so that:

- `acme/www` is the only IdP authority that mutates sessions / revokes tokens / writes audit.
- `sign/id` is a redirect-only credential gateway that hosts a state-free `/signed-out` page.
- `core/*` are RP BFFs whose `/sso/logout` does a local-only RP logout and points users back to the
  IdP session-management UI for global sign-out.

The audit checks whether the live `routes.rb` files and the controllers/concerns that back them
faithfully implement that contract for three concerns kept deliberately distinct:

1. **OIDC RP-Initiated Logout** — OP-facing flow at the IdP's `end_session_endpoint`.
2. **OAuth Token Revocation (RFC 7009)** — token-facing endpoint at `revocation_endpoint`.
3. **RP local logout ceremony** — clearing RP-side cookies / session rows / JTIs.

The audit also re-examines the surface boundary (`app` / `org` / `com`) and `palm` to confirm no
contamination, no GET-mutates-state regression, no skipped pipeline stages, and no silent fallbacks
in the logout/revocation path.

## Method (read-only, Podman-bound)

To re-validate the audit on a fresh tree, run inside the Rails Podman service only:

```sh
podman compose ps
podman compose exec <rails-service> bin/rails routes | grep -Ei 'logout|sign_out|signed_out|revoke|revocation|end_session|oidc'
podman compose exec <rails-service> bin/rails routes -c Acme::App::Oidc::LogoutsController
podman compose exec <rails-service> bin/rails routes -c Acme::App::SignOutsController
podman compose exec <rails-service> bin/rails routes -c Sign::App::SignOutsController
podman compose exec <rails-service> bin/rails routes -c Acme::App::Oauth::RevocationsController
```

Do NOT run `bin/rails` or `bundle exec` on the host. Do NOT use `docker` or `docker compose`. Do NOT
alter DB, run migrations, install gems, or touch git state.

## Routing Map (current state)

Per-surface endpoints relevant to logout/revocation, distilled from `config/routes/*.rb`:

| Surface            | Endpoint                                          | Verb(s)                     | Controller                           | Concern                                     |
| ------------------ | ------------------------------------------------- | --------------------------- | ------------------------------------ | ------------------------------------------- |
| acme/{app,com,org} | `/.well-known/openid-configuration`               | GET                         | `OpenidConfigurationsController`     | —                                           |
| acme/{app,com,org} | `/oauth/authorize`                                | GET                         | `Oauth::AuthorizationsController`    | —                                           |
| acme/{app,com,org} | `/oauth/token`                                    | POST                        | `Oauth::TokensController`            | —                                           |
| acme/{app,com,org} | `/oauth/revoke`                                   | POST                        | `Oauth::RevocationsController`       | `AcmeOauthEndpoint`                         |
| acme/{app,com,org} | `/oauth/userinfo`                                 | GET                         | `Oauth::UserInfoController`          | —                                           |
| acme/{app,com,org} | `/oidc/logout`                                    | **GET only**                | `Oidc::LogoutsController`            | `SignOidcLogout`                            |
| acme/{app,com,org} | `/sso/authorize`                                  | GET                         | `Sso::AuthorizationsController`      | —                                           |
| acme/{app,com,org} | `/sso/logout`                                     | POST                        | `Sso::LogoutsController`             | `OidcRpLogout`                              |
| acme/{app,com,org} | `/sign/out`                                       | GET, GET edit, POST, DELETE | `SignOutsController`                 | `AuthenticationLogoutable`, `SignOutNotice` |
| acme/{app,com,org} | `/auth/callback`                                  | GET                         | `Auth::CallbacksController`          | `OidcCallback`                              |
| acme/{app,com,org} | `/settings/sessions` (+ `:others`, `:revoke_all`) | DELETE                      | `Settings::SessionsController`       | session list/destroy                        |
| sign/{app,com,org} | `/sign/out` (show/edit/create/destroy)            | GET, GET, POST, DELETE      | `SignOutsController` (redirect-only) | —                                           |
| sign/{app,com,org} | `/signed-out`                                     | GET                         | `SignedOutsController`               | —                                           |
| sign/app           | `/sign/in/session`                                | GET, PATCH, **DELETE**      | `In::SessionsController`             | `SessionLimitGate`                          |
| sign/{app,com,org} | `/settings/sessions/:id/revocation_attempt`       | POST                        | `Settings::Sessions::*`              | —                                           |
| sign/{app,com,org} | `/settings/session_revocations/{others,all}`      | POST                        | `Settings::SessionRevocations::*`    | —                                           |
| core/{app,com,org} | `/sso/logout`                                     | POST                        | `Sso::LogoutsController`             | `OidcRpLogout`                              |
| core/{app,com,org} | `/auth/callback`                                  | GET                         | `Auth::CallbacksController`          | `OidcCallback`                              |
| palm/app           | `/oauth/callback`                                 | GET                         | (stub)                               | —                                           |

Observations on the table:

- `acme` is the only surface that exposes a revocation endpoint, an end-session endpoint, and a
  destructive sign-out endpoint — consistent with `adr/acme-session-and-token-authority.md`.
- `sign/app/in/session#destroy` exists and is the lone session-mutation point on the sign surface
  (see Finding F).
- `palm` has no logout / revocation endpoint at all (see Finding J).

## Findings

Findings are ranked by severity for the IdP / RP responsibility separation contract. Each cites the
file path and observable evidence. None of these are fixed in this audit; they are inputs to
follow-up plans.

### A. `end_session_endpoint` is GET-only and not spec-aligned (High)

- `config/routes/acme.rb:99-101` declares `namespace :oidc { resource :logout, only: :show }` on all
  three acme surfaces (`app`, `com`, `org`).
- `app/services/oidc_discovery_document.rb:17` advertises this URL as `end_session_endpoint`, while
  `app/services/oidc_issuer.rb:37-39` maps it to `/oidc/logout`.
- OIDC RP-Initiated Logout 1.0 §3 requires the `end_session_endpoint` to accept **both GET and
  POST**. Today only GET is wired.
- `app/controllers/acme/app/oidc/logouts_controller.rb` is a thin shim that includes
  `SignOidcLogout`; the receiver does not consume the spec parameters `id_token_hint`,
  `post_logout_redirect_uri`, `state`, `logout_hint`, `ui_locales`. Instead it validates a
  project-internal signed `logout_request` JWT (`OidcLogoutRequest.verify`).
- Net: a third-party RP following the OIDC RP-Initiated Logout 1.0 contract cannot use this
  endpoint. `/.well-known/openid-configuration` is therefore advertising a non-conforming endpoint.

### B. RP-Initiated Logout does not consume `id_token_hint` (High)

- `app/controllers/concerns/sign_oidc_logout.rb` validates only the signed `logout_request` JWT and
  rejects `post_logout_redirect_uri` outright.
- OIDC RP-Initiated Logout 1.0 §2 lists `id_token_hint` as RECOMMENDED for both identifying the user
  and authenticating that the request originates from a known RP.
- Combined with Finding A, the implemented flow is a private RP-specific protocol named
  "RP-Initiated Logout" but is not the IETF / OIDF protocol of that name. This is a documentation /
  discovery-doc spec drift.

### C. No back-channel logout receiver, no back-channel notifier (High)

- No route declares a back-channel logout endpoint at `acme`, `core`, or `sign`. Grep for
  `backchannel_logout` / `back_channel_logout` returns no matches under `config/routes/` or
  `app/controllers/`.
- `app/services/oidc_discovery_document.rb:10-26` does not advertise `backchannel_logout_supported`
  or `backchannel_logout_session_supported`.
- `adr/logout-primitive-and-composition.md` records "`Oidc::BackchannelLogoutNotifier`" as a
  reserved future namespace. The work is not in `plans/active/`; the namespace is reserved but
  empty.
- Net: when a user revokes a session on `acme` (via `/sign/out`, `/oauth/revoke`, or the settings
  page), downstream `core` RPs are not notified. Their JWTs remain accepted until expiry; only
  refresh is blocked via `session_version` bumps. "Logout everywhere" is therefore a near-real-time,
  not real-time, property.

### D. No front-channel logout receiver, not advertised (Medium)

- Same shape as Finding C: no routes, no discovery advertisement, no notifier service.
- Lower severity because front-channel logout (iframe broadcast) is a strictly weaker primitive than
  back-channel logout; addressing back-channel logout first satisfies most product needs.

### E. `Acme::*::Sso::LogoutsController` includes RP-flavored concern on the IdP surface (High)

- `app/controllers/acme/app/sso/logouts_controller.rb:8` (and the `com`/`org` siblings) declares
  `include ::OidcRpLogout` — the same concern used by `Core::*::Sso::LogoutsController`.
- `OidcRpLogout` is designed for an RP doing a local-only logout and pointing the user to the IdP
  for session-management. Mixing it into the IdP surface itself is semantically wrong: on `acme`,
  this endpoint should either:
  - mutate the IdP session (and therefore live under `AuthenticationLogoutable`, the same contract
    `Acme::*::SignOutsController` uses), or
  - be removed in favor of the existing `/sign/out` route.
- The role of `acme/*/sso/logout` POST today is unclear. There is no ADR or active plan that
  documents why both `/sso/logout` and `/sign/out` exist on acme. This is a candidate for
  consolidation.

### F. `Sign::App::In::SessionsController#destroy` mutates sessions on the sign surface (High)

- `app/controllers/sign/app/in/sessions_controller.rb:96-100` calls
  `AuthenticationLogoutCurrentSession.call(...)` directly. That is a session-mutation primitive, on
  the sign surface, after the 2026-06-02 ADR moved that responsibility to acme.
- The controller comment (`l.4-19`) explains this is the session-limit edge case during sign-in. The
  flow is real (third concurrent login -> restricted session). The question is _why the primitive
  runs on sign instead of being delegated to acme_.
- The other sign surfaces (`sign/com`, `sign/org`) do not expose `/sign/in/session DELETE`. Only
  `sign/app` does, which is inconsistent.
- Recommend: either (i) record an explicit ADR exception ("session-limit cancellation is the one
  case sign mutates sessions, because the user is not yet IdP-authenticated"), or (ii) move the
  cancellation primitive to acme behind a sign-initiated POST. Either way, this is a documentation
  gap today.

### G. Duplicate state-mutating verbs on `Acme::*::SignOutsController` (Medium)

- `config/routes/acme.rb:109-111` declares
  `resource :sign_out, ..., only: %i(show edit create destroy)` — both POST and DELETE land on the
  same `perform_sign_out!`.
- `app/controllers/acme/app/sign_outs_controller.rb:24-38` implements `create` and `destroy`
  identically (`destroy` is `perform_sign_out!`; `create` is a confirm-gate then
  `perform_sign_out!`).
- Two destructive verbs reaching the same primitive doubles the routing surface (CSRF tokens,
  reverse-proxy rules, regression tests) without adding behavior. Recommend converging on one verb.
  The state-machine plan in `plans/active/logout-state-machine-implementation-plan.md` may pin this;
  verify before changing.

### H. Sign-surface `/sign/out` exposes four verbs for a redirect (Low)

- `config/routes/sign.rb` does not declare `/sign/out` directly under sign — the sign-surface routes
  are not the source. Instead `app/controllers/sign/app/sign_outs_controller.rb` inherits
  `Sign::RedirectOnlyController` and stubs `show`, `edit`, `create`, `destroy` to the same redirect.
  The route helpers must come from a different file (likely a shared sign route block). Audit
  whether all four verbs are actually exposed on sign; if so, collapse to a single redirect
  entrypoint.

### I. Discovery document does not advertise revocation/end-session features (Medium)

- `app/services/oidc_discovery_document.rb` advertises the endpoint URLs (good) but does not
  declare:
  - `revocation_endpoint_auth_methods_supported`
  - `revocation_endpoint_auth_signing_alg_values_supported`
  - `end_session_endpoint_auth_methods_supported` (project-specific; absent because flow is
    non-standard)
  - `backchannel_logout_supported` / `backchannel_logout_session_supported`
  - `frontchannel_logout_supported` / `frontchannel_logout_session_supported`
- Without these, well-behaved RP clients (Auth.js, oidc-client-ts, Spring Security) will fall back
  to defaults that do not match this server.

### J. `palm` surface has no logout/revocation surface (Medium)

- `config/routes/palm.rb` (per Explore agent) only wires
  `namespace :oauth { resource :callback, only: :show }`. There is no equivalent of `/oauth/revoke`
  or `/oidc/logout` reachable by palm clients.
- Acceptable if palm is expected to call `acme`'s revocation endpoint directly, but that policy is
  not documented in `docs/security/` or any ADR. Flag for explicit decision.

### K. No documented multi-surface logout semantics (Medium)

- The three surfaces (`app`, `org`, `com`) share neither cookies nor session cookies (correct per
  surface-isolation rules), but they share an actor model in some cases (one human can have both an
  `org` operator identity and an `app` client identity).
- No ADR or doc describes whether logging out of `org` ends the user's `app` sessions, or whether
  `revoke_all` on one surface ripples to the others. The relevant primitives
  (`AuthenticationLogoutAllSessions`) iterate the resource's tokens, so by default no — but this
  invariant is not pinned by an ADR or regression test.
- The settings/session listing pages are per-surface and so are their `revoke_all` buttons. This
  means a user who wants to "log out of everywhere" must do it three times. Not a bug, but not
  stated as policy either.

### L. JTI / `sid` claim invalidation strategy is implicit (Medium)

- `app/services/security_jwt_oidc_id_token_codec.rb`, `OperatorToken`, `VisitorToken`, `ClientToken`
  carry JTIs and `oidc_sid` (used by `OidcTokenRevocationService` to look up the token row from a
  JWT — see `app/services/oidc_token_revocation_service.rb:50-70`).
- There is no ADR that records the JTI generation/format/uniqueness policy, nor the back-pressure
  invariant ("once a JTI is on the revocation table, no future JWT may reuse it").
- Combined with Finding C, this means: even if back-channel logout is implemented later, the
  receiver has nothing to authoritatively look up a `sid` against unless this is pinned now.

### M. Redirect target for `redirect_to_signed_out_page!` is environment-coupled (Low)

- `app/controllers/acme/app/sign_outs_controller.rb:64-70` calls
  `sign_app_signed_out_url(ri: params[:ri], host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"))`.
- The `host:` argument is read directly from ENV with a literal fallback. If the env var is
  misconfigured in production, users land on a localhost host. Recommend reviewing whether the
  fallback should be removed in non-development environments (no silent fallback rule), or at least
  raise loudly when ENV is blank in production.

### N. Cross-surface bridge models still expose `revoke!` paths (Informational)

- `app/models/operator_token.rb`, `visitor_token.rb`, and `client_token.rb` include
  `RefreshTokenable` (per `app/models/concerns/refresh_tokenable.rb`). The revocation surface is
  per-token, called by `OidcTokenRevocationService` and `AuthenticationLogoutCurrentSession`.
- No surface contamination observed: each model lives in its own bridge (`core_app_client_bridge`,
  `core_com_visitor_bridge`, `core_org_operator_bridge`), and the revocation service dispatches on
  `oidc_sid` lookup per resource type.
- Note this here so that any later "global revoke" abstraction does not collapse the per-bridge
  separation.

## Cross-cutting Spec/Pipeline Notes

These do not have a single owning controller; they are global properties to check.

1. **No GET-mutates-state regression** — `acme/oidc/logout` is GET but does not destroy state
   inline; it renders a confirmation page and redirects to `acme/sign/out` which uses POST/DELETE.
   That is conformant. Verify via:
   `podman compose exec <rails-service> bin/rails test test/controllers/acme/app/oidc/logouts_controller_test.rb`.

2. **No `skip_before_action` on logout paths** — `Acme::App::SignOutsController` uses
   `prepend_before_action :authenticate!, only: %i(edit create destroy)` rather than a skip; `show`
   is :open and renders only the redirect. Conformant with the `skip` policy in
   `.agents/harnesses/rules/generic/absolute-rules.mdc`.

3. **No `rescue nil` in revocation path** — `OidcTokenRevocationService` returns explicit error
   structures (`result.success?` / `result.error_description`). No silent swallow. Conformant.

4. **Surface contamination** — `Acme::*` and `Core::*` both `include OidcRpLogout`, which lives
   under `app/controllers/concerns/`. That is allowed (shared abstraction). The concern itself does
   not pull surface-specific helpers; it dispatches via `idp_sessions_url` defined on the including
   class. Conformant.

5. **CSRF on state-changing routes** — `/oauth/revoke` and `/sign/out` (POST/DELETE) live under
   `BareController` for the OAuth endpoint, and under `ApplicationController` for the sign-out
   endpoint. The OAuth revocation endpoint is token-authenticated (client_id/client_secret), not
   CSRF-protected, which is correct for an RFC 7009 endpoint. `/sign/out` is CSRF-protected through
   the standard pipeline. Conformant.

## Recommended Follow-ups (not implementation)

These are the candidate work items the audit surfaces. Each should turn into its own
`plans/backlog/*.md` or `plans/active/*.md` file, written by a human, not by this audit.

1. **Spec-align `end_session_endpoint`** (Findings A, B, H, I). Decide whether to:
   - implement the OIDC RP-Initiated Logout 1.0 spec verbatim (POST + GET, `id_token_hint`,
     allowlisted `post_logout_redirect_uri`), or
   - rename the endpoint and remove `end_session_endpoint` from the discovery document so we stop
     advertising a non-conforming endpoint.
2. **Decide on back-channel logout** (Findings C, D, L). At minimum, document the chosen position in
   an ADR; reserved namespace alone is not load-bearing.
3. **Consolidate or document `/sso/logout` vs `/sign/out` on acme** (Finding E, G). Pick one
   destructive primitive on the IdP surface, or document why both exist.
4. **Pin the sign session-mutation exception** (Finding F). Either add an ADR exception for the
   session-limit cancellation flow, or move the primitive to acme.
5. **Document multi-surface logout semantics** (Finding K). Add a doc under `docs/security/` stating
   whether logging out of one surface ripples to others.
6. **Decide palm logout strategy** (Finding J). Document whether palm uses acme's revocation
   endpoint directly or gets its own surface.
7. **Pin JTI / sid policy** (Finding L). Add an ADR so the revocation receiver has a stable lookup
   contract.
8. **Audit `redirect_to_signed_out_page!` fallback host** (Finding M). Decide whether the literal
   `"id.app.localhost"` fallback is acceptable outside development.

## Verification (read-only)

After turning any of the items above into a plan, verify the audit findings still hold:

```sh
# 1. Routes inventory
podman compose exec <rails-service> bin/rails routes \
  | grep -Ei 'logout|sign_out|signed_out|revoke|revocation|end_session'

# 2. Discovery document
podman compose exec <rails-service> bin/rails runner \
  'puts OidcDiscoveryDocument.new(resource_type: :app).to_json'

# 3. Logout-related concerns sanity
podman compose exec <rails-service> grep -rn 'include OidcRpLogout\|include SignOidcLogout\|include AuthenticationLogoutable' app/controllers

# 4. Test pins
podman compose exec <rails-service> bin/rails test \
  test/controllers/acme/app/oidc/logouts_controller_test.rb \
  test/controllers/acme/app/sign_outs_controller_test.rb \
  test/controllers/acme/app/oauth/revocations_controller_test.rb \
  test/controllers/core/app/sso/logouts_controller_test.rb \
  test/controllers/sign/app/sign_outs_controller_test.rb
```

Do not run any of the above on the host. All commands stay inside the Podman service.

## Out of Scope

- No implementation. No route change. No test change. No ADR/doc/memo/note authoring.
- No changes to git state.
- No DB / migration / seed operations.
- No package install or bundler operations.
- No host-side Rails commands.
- All commands run inside `podman compose exec <rails-service> …` only.
