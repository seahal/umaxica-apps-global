# Microsoft Entra ID Sign-In for Org Surfaces — Security Audit and Implementation Plan

> **Classification:** Sign-in only. No sign-up. No JIT provisioning. No auto-creation of any
> principal record. Deny-by-default callback.

---

## Executive Verdict

**Go after blockers.** The repository has a solid OIDC foundation, a clear surface separation
architecture, and a good precedent in `OidcSsoInitiator` + `OidcCallback` for RP-side OIDC flows.
However, four blockers must be resolved before any implementation begins:

| #   | Blocker                                                                                                                                                                                       | Severity |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| B1  | `omniauth_openid_connect` is not in the Gemfile; the OmniAuth stack is explicitly blocked on org hosts by `OmniAuthNonAppSocialGuard`. OmniAuth is not the correct template for this feature. | Critical |
| B2  | No data models exist for organization-level Entra ID configuration or pre-provisioned operator-to-Entra-identity mapping.                                                                     | Critical |
| B3  | No ADR defines the sign-in-only / deny-by-default boundary for external IdP org sign-in. This must be documented before any callback code is written.                                         | Critical |
| B4  | Credentials storage pattern for Entra client secrets on org surfaces (per-organization vs. per-environment Rails credentials) is undefined.                                                   | High     |

---

## 1. Current Repo Evidence

### 1.1 OmniAuth Architecture

**Configuration file:** `config/initializers/omniauth.rb` (lines 1–230)

- Path prefix: `/social` (`OmniAuth.config.path_prefix = "/social"`)
- Installed providers: `google_oauth2` (omniauth-google-oauth2 1.2.2) and `apple` (omniauth-apple
  1.4.0)
- CSRF gem: `omniauth-rails_csrf_protection` v2.0.1 (`Gemfile` lines 85–92)
- Both GET and POST allowed for the request phase
  (`OmniAuth.config.allowed_request_methods = %i(get post)`, line 189), with
  `silence_get_warning = true` (line 188)
- After-request hook: `SocialCallbackGuard.capture_request_state!` (line 190)
- `omniauth_openid_connect` gem: **NOT present** in `Gemfile` or `Gemfile.lock`

**`OmniAuthNonAppSocialGuard` middleware** (`config/initializers/omniauth.rb` lines 81–108):

```ruby
blocked_hosts = [
  boot_hosts.sign_corporate.host,   # com surface
  boot_hosts.sign_staff.host,       # org surface  ← auth org host is blocked
  boot_hosts.acme_corporate.host,
  boot_hosts.acme_staff.host,
]
```

Any request to `/social/...` on `sign_staff.host` returns HTTP 404. The auth org surface is
explicitly and correctly blocked from OmniAuth. This middleware must not be modified as part of this
feature.

**Surfaces currently using OmniAuth:** App surface only (`auth.app.localhost` /
`sign_service.host`). OmniAuth callback controller:
`Auth::App::Omniauth::OmniauthCallbacksController`.

**What OmniAuth callbacks create:** `ClientGoogleIdentity` / `ClientAppleIdentity` (in
`app_principal` database), linked to `Client` (app user). These are fundamentally app-surface
constructs.

**State management:** `SocialCallbackGuard` (`app/controllers/concerns/social_callback_guard.rb`),
5-minute TTL, session keys `social_auth_state`, `social_auth_state_started_at`,
`social_auth_state_used_at`, `social_auth_state_provider`.

**Conclusion from repo evidence:** OmniAuth is the wrong template for org Entra ID. The existing org
surface OIDC flow (`OidcSsoInitiator` + `OidcCallback`) is the correct template.

### 1.2 Org Surface Architecture

**Auth Org:**

- Host: `auth.org.localhost` / `PRIVATE_AUTH_STAFF_URL` (env var)
- Route macro: `auth_surface :org, host: [hosts.auth_staff.host, "auth.org.localhost"]`
  (`config/routes/auth.rb` lines 313–451)
- Actor: `Operator` (org_principal database)
- Application controller: `Auth::Org::ApplicationController`
  (`app/controllers/auth/org/application_controller.rb`)
  - `AUTHENTICATION_MODE = :deny_all`
  - Includes: `ActorSupport`, `AuthenticationOperator`, `SessionLimitGate`, `OidcSsoInitiator`
  - OIDC client ID: `"sign-rp"`
- Current sign-in methods: Passkey, secret credential — no social/OmniAuth
- OIDC role: Acts as a Relying Party (RP) that initiates OIDC authorization with Acme/Sign as IdP

**Base Org:**

- Host: `base.org.localhost` / `PUBLIC_BASE_STAFF_URL` (env var)
- Route structure: `scope module: :org` with host constraints on `PUBLIC_BASE_STAFF_URL`
  (`config/routes/base.rb` lines 397–602)
- Actor: `Operator` (org_principal database)
- Application controller: `Base::Org::ApplicationController`
  (`app/controllers/base/org/application_controller.rb`)
  - Includes: `AuthenticationOperator`, `AuthorizationOperator`, `VerificationOperator`,
    `OidcSsoInitiator`
  - OIDC client ID: `"base-rails-rp"`
- Role: Identity authority / context selection; handles `/oidc/callback`, `/oauth/authorize`,
  `/oauth/token`, etc.

**Existing OIDC flow pattern (`OidcSsoInitiator`):**
`app/controllers/concerns/oidc_sso_initiator.rb` — full PKCE S256, state, nonce, pending flow
tracking (limit 2), session storage with TTL. This is the correct template for the Entra ID request
phase.

**`OidcCallback` concern:** `app/controllers/concerns/oidc_callback.rb` — state validation, PKCE
verifier exchange, ID token verification via `OidcIdTokenVerifier`, nonce validation, abstract
`provision_rp_account_from_id_token_payload!` override. This is the correct template for the Entra
ID callback phase.

### 1.3 Existing Identity and OIDC Models

| Model                                  | File                                                    | Database      | Purpose                                   |
| -------------------------------------- | ------------------------------------------------------- | ------------- | ----------------------------------------- |
| `Operator`                             | `app/models/operator.rb`                                | org_principal | Staff member                              |
| `OperatorIdentity`                     | `app/models/operator_identity.rb`                       | org_principal | Core identity record                      |
| `OperatorIdentityState`                | `app/models/operator_identity_state.rb`                 | org_principal | Identity lifecycle state                  |
| `OperatorOidcConnection`               | `app/models/operator_oidc_connection.rb`                | org_ticket    | Acme OIDC session link (not external IdP) |
| `OperatorOidcAuthorizationTransaction` | `app/models/operator_oidc_authorization_transaction.rb` | org_ticket    | OIDC code exchange transaction            |
| `ClientGoogleIdentity`                 | `app/models/client_google_identity.rb`                  | app_principal | App user Google link                      |
| `ClientAppleIdentity`                  | `app/models/client_apple_identity.rb`                   | app_principal | App user Apple link                       |

**No existing model for:** organization-level external IdP configuration, operator-to-Entra mapping.
`OperatorOidcConnection` is for Acme/Sign OIDC sessions only — it must not be repurposed.

### 1.4 Relevant ADRs

- `adr/identity-authority-boundary.md` — Acme is Session/Token/Account authority; Sign is Credential
  Gateway only. Org Entra ID sign-in is a credential ceremony (Sign/auth surface concern) that
  delivers an OIDC code to Base (Acme) for session issuance.
- `adr/oidc-authn-hardening-implementation-decisions.md` — PKCE, nonce, state, required claims
  baseline. Superseded by `identity-authority-boundary.md` for IdP/RP role assignment.
- `adr/session-reset-on-privilege-transition.md` — Session must be reset on login.
- `adr/org-cloudflare-access-authentication-layer.md` (Accepted 2026-06-29) — Cloudflare Access
  gates org read-only paths (`/docs/*`, `/help/*`, etc.). Explicitly out of scope for `auth/org`,
  `base/org`, `core/org` which continue using Acme/Sign ceremonies.
- `adr/sign-credential-gateway-surface.md` — Sign is a Credential Gateway. External IdP ceremonies
  belong here as credential ceremony entry points.
- `adr/two-base-authentication-mode-boundaries.md` — base authentication mode boundaries.

---

## 2. Official Docs Evidence

### 2.1 Microsoft Entra ID / Microsoft identity platform

Source: Microsoft identity platform documentation
(https://learn.microsoft.com/en-us/entra/identity-platform/)

**Authorization code flow with PKCE:**

- Microsoft supports and recommends authorization code flow + PKCE S256 for server-side web apps.
- Endpoint: `https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/authorize`
- Token endpoint: `https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token`
- Discovery: `https://login.microsoftonline.com/{tenant_id}/v2.0/.well-known/openid-configuration`

**Issuer validation:**

- Tenant-specific issuer: `https://login.microsoftonline.com/{tenant_id}/v2.0`
- Multi-tenant (`common`/`organizations`) endpoint issues tokens with
  `https://login.microsoftonline.com/{tenant_id}/v2.0` as issuer regardless of endpoint used.
  Discovery document from `common` lists `{tenantid}` as a placeholder — library validation must
  replace it with the actual tenant.
- **Risk with `common`:** Accepts tokens from ANY Microsoft tenant unless tenant is validated
  separately. This is a critical misconfiguration risk.
- **Recommendation:** Use tenant-specific discovery URL and issuer per organization connection.

**Stable identity claims:**

- `oid` (Object ID): Stable across the tenant for the user object. Does NOT change on email change,
  display name change, or UPN change.
- `tid` (Tenant ID): Identifies the tenant. Required to scope `oid` (same `oid` value can appear in
  different tenants if the same Microsoft account is a guest in multiple tenants).
- `sub` (Subject): Tenant- and app-specific identifier. Stable within a single app registration.
  Changes if the app registration changes. Combination of `tid + oid` is more portable.
- `email`: NOT stable. Can change. Must not be used as primary key or authorization signal.
- `upn` (User Principal Name): NOT stable. Can change.
- `preferred_username`: NOT stable. Can change.
- **Recommended stable key:** `tid + oid`

**Client secret vs. certificate:**

- Server-side web applications (confidential clients) require client authentication at the token
  endpoint. Both client secret and certificate credential are supported.
- Client secret is simpler to start with; certificate credential is preferred for production.
- PKCE does not replace client authentication for confidential clients — both are required.

**Scopes for sign-in only:**

- `openid profile email` — sufficient for sign-in identity claims
- Do NOT request `offline_access` unless refresh tokens are needed (they are not, for sign-in only)
- Do NOT request MS Graph scopes unless specifically needed

**Single-tenant vs. multi-tenant App Registration:**

- Single-tenant: only users in the registered tenant can sign in. Simpler, more predictable.
- Multi-tenant: users from any Entra tenant can sign in (requires careful tenant validation).
- **Recommendation for v1:** Single-tenant App Registration per organization. One App Registration
  per organization connection, or one App Registration with explicit tenant ID validation.

**PKCE:**

- Required for public clients; recommended for confidential clients.
- Entra ID supports S256 method.
- `code_challenge_method=S256` must be sent in authorization request; `code_verifier` sent in token
  request.

**Redirect URIs:**

- Must be registered in the App Registration.
- Wildcards are not supported for production redirects.
- Separate URIs for each environment (dev, staging, prod).
- Each surface (auth org, base org) needs its own registered callback URI if separate client IDs are
  used.

### 2.2 OmniAuth and omniauth_openid_connect

Source: omniauth/omniauth README, nov1ero/omniauth_openid_connect README

- `omniauth_openid_connect` wraps the `openid_connect` Ruby gem and handles OIDC discovery, code
  exchange, and ID token verification.
- It is the standard OmniAuth adapter for OIDC providers including Entra ID.
- **However:** It still requires the OmniAuth middleware to be mounted and accessible on the target
  host. The `OmniAuthNonAppSocialGuard` in this repo explicitly blocks the org surface.
- **Conclusion:** `omniauth_openid_connect` can be used, but only if OmniAuth is mounted on a
  separate path prefix that is not blocked, OR if a dedicated separate OmniAuth builder is added for
  org surfaces. This significantly increases complexity and risk of cross-surface confusion.
- **Better approach:** Mirror the existing `OidcSsoInitiator`/`OidcCallback` pattern with a
  dedicated `EntraIdSsoInitiator`/`EntraIdCallback` concern pair.

---

## 3. Required Design Boundary

### 3.1 Architecture Decision

**Entra ID org sign-in uses the existing OIDC RP concern pattern, not OmniAuth.**

Rationale from repo evidence:

1. `OmniAuthNonAppSocialGuard` explicitly blocks `sign_staff.host` (auth org) from `/social/` paths.
   This guard is correct and must not be weakened.
2. OmniAuth callbacks currently create `Client*` records in `app_principal`. Operators live in
   `org_principal`. Grafting OmniAuth onto org would require either: a new OmniAuth stack mounted on
   a different path, or bypassing the guard — both increase attack surface.
3. `OidcSsoInitiator` already implements PKCE S256, state, nonce, pending flow TTL, and session
   management for org surfaces (`Auth::Org::ApplicationController` and
   `Base::Org::ApplicationController` both include it).
4. `OidcCallback` already implements state validation, PKCE exchange, ID token verification, and
   nonce validation with an abstract `provision_rp_account_from_id_token_payload!` hook.
5. The pattern is already tested in `test/controllers/concerns/oidc/sso_initiator_test.rb` (989
   lines).

**Entra ID request phase:** A new concern `EntraIdOrgSsoInitiator` wraps Microsoft's authorize
endpoint, using `OidcSsoInitiator` as the structural template with tenant-specific configuration.

**Entra ID callback phase:** A new concern `EntraIdOrgCallback` wraps the token exchange and ID
token validation, using `OidcCallback` as the structural template with the deny-by-default
`provision_rp_account_from_id_token_payload!` implementation.

### 3.2 Sign-In Only Invariant

The Entra ID callback MUST enforce all of the following before establishing a session:

1. Valid OIDC response (no error, code present)
2. State present and matches session-stored state (not expired, not reused)
3. Nonce present and matches session-stored nonce in the ID token `nonce` claim
4. Valid ID token signature (against Entra JWKS for the configured tenant)
5. `iss` exactly matches the configured issuer for the organization connection
   (`https://login.microsoftonline.com/{tenant_id}/v2.0`)
6. `aud` exactly matches the configured `client_id` for this surface/connection
7. Token not expired (`exp`) and not before valid (`nbf`)
8. `tid` claim matches the configured `tenant_id` for the organization connection
9. `oid` claim present
10. Matching `OrganizationEntraConnection` found and `enabled: true`
11. Matching `OperatorEntraIdentity` record found (by `tenant_id + oid`) and `enabled: true`
12. Linked `Operator` record found and in valid active state
13. No sign-up: if any of steps 10–12 fail, deny with safe error message, log denial reason
    server-side, do NOT create any record

### 3.3 What Must Not Happen

| Prohibited action                                                                | Why                                          |
| -------------------------------------------------------------------------------- | -------------------------------------------- |
| Create `Operator`, `OperatorIdentity`, `Organization`, or any record on callback | JIT provisioning; forbidden by requirement   |
| Look up `OperatorEntraIdentity` by email alone                                   | Email is not a stable or authoritative claim |
| Use email domain to infer org membership                                         | Domain matching is not proof of membership   |
| Accept `common` or `organizations` issuer without tenant validation              | Allows cross-tenant impersonation            |
| Accept a valid Entra token on the wrong surface                                  | Cross-surface token acceptance               |
| Accept a disabled organization connection                                        | Disabled connection must deny                |
| Accept a disabled operator mapping                                               | Disabled mapping must deny                   |
| Merge with existing app/com principal session                                    | Cross-surface session contamination          |
| Skip session reset on successful sign-in                                         | Session fixation                             |

---

## 4. Proposed Routes

### 4.1 Auth Org Surface

Auth org is a Credential Ceremony Zone. Entra ID sign-in is a credential ceremony that delivers an
OIDC code to Base (Acme) for session issuance. The auth org surface initiates the Entra ID
authorization and handles the callback to establish a Sign-side ceremony result.

```ruby
# config/routes/auth.rb — inside auth_surface :org block

namespace :entra do
  # Sign-in entry page (GET) — renders "Sign in with Microsoft" button
  resource :sign_in, only: %i[show], controller: "sign_ins", path: "sign/in"

  # Entra ID request phase — initiates OIDC authorization with Microsoft (POST, CSRF token required)
  # POST /entra/auth — sets state/nonce/PKCE in session, redirects to Microsoft authorize endpoint
  resource :auth, only: %i[create], controller: "auths"

  # Entra ID callback — Microsoft redirects here with code+state
  # GET /entra/callback
  resource :callback, only: %i[show], controller: "callbacks"

  # Failure handler
  # GET /entra/failure
  resource :failure, only: %i[show], controller: "failures"
end
```

**Provider name within this surface:** `auth_org_entra_id` (used in session keys to prevent
collision with base org or app social session keys).

### 4.2 Base Org Surface

Base org is the identity/session authority for operators. After the auth org ceremony succeeds, the
Entra ID flow there issues a short-lived assertion that base org converts to an operator session via
the normal Acme/Sign OIDC callback. Base org does NOT need its own Entra ID callback route in v1 —
Entra ID is a credential ceremony handled entirely at auth org.

If Base org needs a direct Entra ID login bypass route in a future version, add it as:

```ruby
# config/routes/base.rb — inside scope module: :org block (FUTURE, not v1)
namespace :entra do
  resource :sign_in, only: %i[show], controller: "sign_ins", path: "sign/in"
  resource :auth,    only: %i[create], controller: "auths"
  resource :callback, only: %i[show], controller: "callbacks"
  resource :failure,  only: %i[show], controller: "failures"
end
```

**For v1:** Only auth org gets the Entra ID route. Base org continues to issue operator sessions via
the existing Acme/Sign OIDC flow after auth org completes the credential ceremony.

### 4.3 No Sign-Up Route

Do NOT add `/entra/sign/up` or any route that initiates an operator creation flow. If such a route
is accidentally routed, it must return 404 or redirect to the sign-in page.

### 4.4 Route Naming Rationale

- `namespace :entra` keeps all Entra ID routes isolated under `/entra/` prefix, separate from
  `/sign/` (passkey/secret credential) and `/social/` (app OmniAuth).
- Separate controller namespace prevents accidental inheritance from app social controllers.
- `resource :auth, only: %i[create]` — POST only, enforcing CSRF token requirement from Rails.
- Provider-scoped session keys (`auth_org_entra_id_state`, etc.) prevent session key collision.

---

## 5. Proposed Data Model

### 5.1 Check: No Reusable Existing Model

Confirmed from repo exploration:

- `OperatorOidcConnection` (org_ticket DB) — stores Acme OIDC session connections for operators, not
  external IdP configurations. Schema: `staff_id`, `client_id` (Acme client ID), `scope`,
  `last_used_at`, `revoked_at`. Must not be repurposed.
- `OperatorOidcAuthorizationTransaction` — Acme OIDC code transaction. Not reusable.
- No `OrganizationEntraConnection` or `OperatorEntraIdentity` model exists.

### 5.2 New Model: `OrganizationEntraConnection`

**Database:** `org_principal` (alongside Organization and Operator) **Table:**
`organization_entra_connections`

```
id                    bigint PK
public_id             string(21)  not null, unique  — public identifier
organization_id       bigint      not null, FK → organizations
tenant_id             string(36)  not null           — Entra tenant UUID
issuer                string(255) not null           — https://login.microsoftonline.com/{tid}/v2.0
client_id             string(255) not null           — Entra App Registration client_id
client_secret_digest  string      not null           — keyed digest; plaintext stored in Rails credentials
surface               string(32)  not null           — "auth_org" (or "base_org" for future)
enabled               boolean     not null default false
sign_in_only          boolean     not null default true  — must always be true; enforced in validation
created_at            datetime    not null
updated_at            datetime    not null
```

**Indexes:**

- Unique on `(organization_id, surface)`
- Index on `(tenant_id, client_id)` — for fast lookup during callback
- Index on `enabled`

**Validations:**

- `sign_in_only` must always be `true` — raise if set to false
- `issuer` must match `https://login.microsoftonline.com/{tenant_id}/v2.0` — validate format
- `tenant_id` must be a valid UUID format
- `surface` must be in `%w[auth_org]` (extend for base_org in future)

### 5.3 New Model: `OperatorEntraIdentity`

**Database:** `org_principal` **Table:** `operator_entra_identities`

```
id                    bigint PK
public_id             string(21)  not null, unique
operator_id           bigint      not null, FK → operators
organization_id       bigint      not null, FK → organizations
connection_id         bigint      not null, FK → organization_entra_connections
tenant_id             string(36)  not null  — denormalized for fast lookup; must match connection.tenant_id
oid                   string(36)  not null  — Entra object ID (oid claim) — stable key
sub                   string(255) null      — OIDC subject (iss+sub for protocol record)
iss                   string(255) null      — issuer at time of provisioning
email_for_display     string(255) null      — display only; NOT used for auth lookup
display_name          string(255) null      — display only
enabled               boolean     not null default false
provisioned_at        datetime    not null
provisioned_by_id     bigint      not null  — FK → operators (admin who created the mapping)
last_signed_in_at     datetime    null
created_at            datetime    not null
updated_at            datetime    not null
```

**Indexes:**

- Unique on `(tenant_id, oid)` — the stable lookup key during callback
- Index on `operator_id`
- Index on `connection_id`
- Index on `enabled`

**Validations:**

- `tenant_id` must match `connection.tenant_id`
- `oid` must be present and non-empty
- Operator must be in a valid state (not withdrawn, not admin-locked)

### 5.4 Migration Strategy

- Two separate migrations: one for `organization_entra_connections`, one for
  `operator_entra_identities`
- Both in `org_principal` database migrations (check existing migration directory convention)
- No data migrations required (new tables, empty at creation)
- Both migrations must be reversible (`drop_table` in `down`)
- No application models used inside migrations

---

## 6. Security Invariants

### 6.1 Critical — Must Fail Closed

| Invariant                                                                  | Implementation point                                                                    |
| -------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| Callback denies if `OrganizationEntraConnection` not found                 | `EntraIdOrgCallbackResolver#resolve` step 1                                             |
| Callback denies if connection `enabled: false`                             | `EntraIdOrgCallbackResolver#resolve` step 2                                             |
| Callback denies if `OperatorEntraIdentity` not found by `(tenant_id, oid)` | Step 3 — lookup is by `tid+oid` only                                                    |
| Callback denies if mapping `enabled: false`                                | Step 4                                                                                  |
| Callback denies if linked Operator is not in valid active state            | Step 5                                                                                  |
| No record is created if any step fails                                     | Resolver is read-only; session creation is a separate step only reached on full success |
| Session is reset before operator session is established                    | `reset_session` called before writing any session data                                  |
| Entra token audience must exactly match `connection.client_id`             | ID token verifier checks `aud` against connection record                                |
| Entra token issuer must exactly match `connection.issuer`                  | ID token verifier checks `iss` against connection record                                |
| `tid` claim must match `connection.tenant_id`                              | Explicit check after ID token verification                                              |
| Nonce in ID token must match session-stored nonce                          | `OidcIdTokenVerifier` or equivalent                                                     |
| State in callback params must match session-stored state                   | `EntraIdOrgCallback` validates before token exchange                                    |
| PKCE verifier must be sent in token request                                | `code_verifier` from session, S256 challenge sent in auth request                       |
| Common/organizations endpoint must not be used                             | `issuer` in connection record is always tenant-specific                                 |
| Email claim must not be used for lookup or authorization                   | Resolver uses only `tid + oid`                                                          |

### 6.2 High — Cross-Surface and Cross-Principal Isolation

| Invariant                                                                                       | Implementation point                                                         |
| ----------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| Auth org Entra callback route is only accessible on `sign_staff.host`                           | Host constraint in `auth_surface :org` route macro                           |
| Entra `client_id` registered in `OrganizationEntraConnection` is specific to `auth_org` surface | `surface` column enforced; separate App Registration recommended per surface |
| Operator session cannot contaminate `app_principal` Client session                              | Separate session namespace; operators use `org_principal` database           |
| `SocialCallbackGuard` and `social_auth_*` session keys are not used                             | Entra ID flow uses its own session key namespace                             |
| `OmniAuthNonAppSocialGuard` is not modified                                                     | Verified: guard blocks `/social/` on org hosts; Entra ID uses `/entra/` path |

### 6.3 Medium — Operational Security

| Invariant                                                                                      | Implementation point                                              |
| ---------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| Disabled organization Entra connection stops all sign-ins for that org                         | `connection.enabled` checked first                                |
| Removing an `OperatorEntraIdentity` record immediately revokes Entra sign-in for that operator | Identity lookup fails → deny                                      |
| Entra `client_secret` is never logged                                                          | Credentials stored in Rails credentials; only digest stored in DB |
| State and nonce are single-use (not replayable)                                                | Clear session state immediately after validation                  |
| Callback URL is registered exactly in Entra App Registration (no wildcards)                    | Documented in setup guide                                         |
| PKCE verifier is discarded after use                                                           | Clear from session after token exchange                           |

### 6.4 Security Failure Modes Addressed

| Failure mode                                              | Status                                                                                         |
| --------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Entra login success → implicit operator sign-up           | **Blocked:** resolver is deny-by-default; no record creation                                   |
| Unknown tenant accepted                                   | **Blocked:** `tid` must match `connection.tenant_id`                                           |
| Wrong audience token accepted                             | **Blocked:** `aud` checked against `connection.client_id`                                      |
| Auth token accepted on base surface                       | **Not applicable in v1:** only auth org has Entra callback                                     |
| `common` endpoint allows personal Microsoft accounts      | **Blocked:** tenant-specific issuer only in connection record                                  |
| Email claim used as authority                             | **Blocked by design:** resolver uses `tid + oid` only                                          |
| Email domain matching grants org access                   | **Blocked by design:** no domain matching logic                                                |
| `sub` used without issuer/tenant context                  | **Mitigated:** primary lookup is `tid + oid`; `sub`/`iss` stored as protocol data only         |
| `oid` used without tenant context                         | **Blocked:** lookup key is always `(tenant_id, oid)`                                           |
| Missing nonce validation                                  | **Blocked:** nonce validated in `EntraIdOrgCallback` before session                            |
| Missing state validation                                  | **Blocked:** state validated before token exchange                                             |
| Missing PKCE                                              | **Blocked:** S256 PKCE required in both auth request and token exchange                        |
| GET request phase CSRF                                    | **Mitigated:** request phase uses POST (Rails CSRF token); `/entra/auth` is `only: %i[create]` |
| Callback route exposed on wrong host                      | **Blocked:** route is inside `auth_surface :org` host constraint                               |
| Redirect URI mismatch                                     | **Blocked:** exact URI registered in Entra; Rails generates from known host                    |
| Session fixation on successful login                      | **Blocked:** `reset_session` called before session write                                       |
| Existing customer/product session merged with org session | **Blocked:** org and app use separate databases and separate session namespaces                |
| Disabled organization membership still signs in           | **Blocked:** connection and identity `enabled` flags checked                                   |
| Deleted/disabled Entra mapping remains accepted           | **Blocked:** identity lookup fails → deny                                                      |
| Group/role claim overage causes unsafe allow              | **Not applicable:** no group/role claims used; mapping is pre-provisioned                      |
| Test environment bypass reaches production                | **Mitigated:** no test bypass code; use real OIDC flow in test with stub server or VCR         |

---

## 7. Microsoft Entra App Registration Shape

### 7.1 Registration Decisions

| Decision          | Recommendation                                                                        | Rationale                                                  |
| ----------------- | ------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Tenant scope      | Single-tenant per organization                                                        | Simpler; no cross-tenant risk; start here                  |
| Endpoint          | `https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/authorize`                 | Tenant-specific; avoids `common`                           |
| Discovery         | `https://login.microsoftonline.com/{tenant_id}/v2.0/.well-known/openid-configuration` | Tenant-specific JWKS                                       |
| Issuer            | `https://login.microsoftonline.com/{tenant_id}/v2.0`                                  | Exact match validation                                     |
| Client IDs        | Separate App Registration per organization                                            | Avoids shared secret; limits blast radius                  |
| Scopes            | `openid profile email`                                                                | Minimum for identity claims; no offline_access             |
| Stable key        | `tid + oid`                                                                           | `oid` is stable across name/email changes; `tid` scopes it |
| PKCE              | S256 required                                                                         | Defense-in-depth even for confidential client              |
| Client auth       | Client secret (v1) → certificate credential (hardening)                               | Secret is simpler to start                                 |
| `offline_access`  | Do not request                                                                        | No refresh tokens needed for sign-in only                  |
| Personal accounts | Blocked by single-tenant registration                                                 | Single-tenant = no personal Microsoft accounts             |

### 7.2 Required Redirect URIs per Environment

| Environment | Auth Org Callback URI                              |
| ----------- | -------------------------------------------------- |
| Local dev   | `http://auth.org.localhost:3000/entra/callback`    |
| Staging     | `https://{auth_staff_staging_host}/entra/callback` |
| Production  | `https://{auth_staff_prod_host}/entra/callback`    |

Each URI must be registered exactly in the Entra App Registration. No wildcards.

### 7.3 Issuer Validation — Single vs Multi-Tenant

**Single-tenant (v1):**

- Issuer in ID token: `https://login.microsoftonline.com/{tenant_id}/v2.0`
- Validate exactly against `connection.issuer`
- No placeholder substitution required

**Multi-tenant (future, not v1):**

- Issuer in ID token still contains actual `tenant_id`, not `common`
- But JWKS discovery uses `common` endpoint with placeholder in issuer
- Requires explicit `tid` substitution in issuer validation
- Risk: if library performs issuer validation against discovery document literally, `{tenantid}` in
  the document will not match the actual issuer — must handle manually
- **Do not implement in v1.** Mark as a future ADR.

---

## 8. Implementation Slices

### Slice 0: Prerequisite — Read Harness Files (Not a Code Change)

Before any implementation, read:

- `.agents/harnesses/rules/generic/controllers.mdc`
- `.agents/harnesses/rules/generic/routing.mdc`
- `.agents/harnesses/rules/project/surfaces.mdc`
- `.agents/harnesses/rules/project/controller-inheritance.mdc`
- `.agents/harnesses/rules/generic/testing.mdc`
- `.agents/harnesses/rules/generic/migrations.mdc`
- `.agents/harnesses/rules/generic/no-silent-fallback.mdc`
- `docs/architecture/controller-lifecycle.md`

---

### Slice 1: ADR — Entra ID Org Sign-In-Only Boundary

**Files:**

- `adr/entra-id-org-sign-in-only-boundary.md` (new)

**Content must cover:**

- Sign-in only; no sign-up; no JIT provisioning
- Pre-provisioned operator mapping requirement
- `tid + oid` as the stable key; email is display-only
- Tenant-specific issuer; no `common`
- No domain-based authorization
- Surface isolation (auth org only in v1)
- Deny-by-default callback contract

**Security invariant:** No implementation proceeds without an accepted ADR.

**Rollback risk:** None — documentation only.

**Tests:** None for this slice.

---

### Slice 2: Gemfile — Add `openid_connect` Gem (If Needed)

**Assessment:** The repo may already have the `openid_connect` gem as a transitive dependency (via
existing OIDC concerns). Verify with `grep "openid_connect" Gemfile.lock` before adding.

**If not present:**

- `Gemfile`: add `gem "openid_connect"` (for JWKS/ID token verification)
- Run `bundle install`
- `Gemfile.lock`: committed change

**Do NOT add:** `omniauth_openid_connect` — the OmniAuth stack is not used for org surfaces.

**Security invariant:** No new OmniAuth provider registered on org host.

**Rollback risk:** Low — Gemfile.lock change only.

**Tests:** `bundle exec ruby -e "require 'openid_connect'"` in CI.

---

### Slice 3: Migrations — New Tables

**Files:**

- `db/org_principal_migrate/{timestamp}_create_organization_entra_connections.rb`
- `db/org_principal_migrate/{timestamp}_create_operator_entra_identities.rb`

**Each migration:**

- Reversible (`create_table` in up, `drop_table` in down)
- No application models used
- Explicit `null: false` on all non-nullable columns
- Indexes as specified in data model section above
- After migration: run `bin/rails db:verify_no_schema_drift` per `AGENTS.md`

**Security invariant:** `sign_in_only` column defaults to `true`; `enabled` defaults to `false`
(connections and identities are disabled until explicitly activated by an admin).

**Rollback risk:** Low — new tables, no existing data affected. `down` drops both tables cleanly.

**Tests:**

- Migration runs cleanly from scratch (CI database reset)
- Migration is reversible (`bin/rails db:rollback STEP=2`)
- Schema dump matches migrations

---

### Slice 4: Models — `OrganizationEntraConnection` and `OperatorEntraIdentity`

**Files:**

- `app/models/organization_entra_connection.rb`
- `app/models/operator_entra_identity.rb`
- `test/models/organization_entra_connection_test.rb`
- `test/models/operator_entra_identity_test.rb`

**Model requirements:**

- `OrganizationEntraConnection`:
  - Validates `sign_in_only: true` always
  - Validates `issuer` matches expected format for `tenant_id`
  - Validates `surface` in allowed list
  - `enabled` scope: `OrganizationEntraConnection.enabled`
- `OperatorEntraIdentity`:
  - Validates `tenant_id` matches `connection.tenant_id`
  - Validates `oid` present and non-empty
  - `enabled` scope
  - No write-path logic (read-only during callback)

**Security invariant:** `OperatorEntraIdentity` has no `find_or_create_by` or upsert methods. Lookup
only.

**Rollback risk:** Low — new models, no existing behavior changed.

**Tests:**

- Validation tests: `sign_in_only` cannot be false
- Validation tests: issuer format
- Lookup by `(tenant_id, oid)` returns correct record
- Disabled record not returned by `enabled` scope
- No `find_or_create_by` or `create` methods exist on callback-facing paths

---

### Slice 5: Config — Per-Organization Entra Credentials Pattern

**Files:**

- `config/credentials/` — add Entra client_secret storage pattern (do not commit actual secrets)
- `lib/config_values_host_family_values.rb` or new config value object — add Entra JWKS endpoint
  resolution helper (derives from `tenant_id`)

**Approach:**

- Client secrets stored in Rails encrypted credentials, keyed by `connection.public_id` or
  organization slug
- `OrganizationEntraConnection#client_secret` decrypts from credentials by `public_id`
- JWKS URI: dynamically constructed as
  `https://login.microsoftonline.com/{tenant_id}/discovery/v2.0/keys`

**Security invariant:** Client secret is never stored in `organization_entra_connections` table in
plaintext. Digest only in DB; plaintext in Rails credentials.

**Rollback risk:** Low — no behavioral change, credentials format only.

**Tests:** Unit test for JWKS URI construction from `tenant_id`.

---

### Slice 6: Core Concern — `EntraIdOrgSsoInitiator`

**Files:**

- `app/controllers/concerns/entra_id_org_sso_initiator.rb`
- `test/controllers/concerns/entra_id_org_sso_initiator_test.rb`

**Behavior** (mirrors `OidcSsoInitiator`):

- `initiate_entra_sign_in!(organization_slug:)`:
  1. Load `OrganizationEntraConnection` for org + surface `"auth_org"`, `enabled: true`
  2. Generate PKCE verifier + S256 challenge
  3. Generate cryptographic `state` and `nonce`
  4. Store in session under `entra_org_*` prefixed keys (not `oidc_*` or `social_auth_*`)
  5. Construct Microsoft authorize URL with all required params
  6. Return URL for redirect
- `entra_org_session_keys`: `entra_org_state`, `entra_org_nonce`, `entra_org_code_verifier`,
  `entra_org_connection_id`, `entra_org_started_at`
- TTL: 10 minutes (matches WebAuthn challenge TTL in `sign_webauthn.rb`)

**Security invariant:** Session keys are namespaced to avoid collision with `oidc_*`,
`social_auth_*`, and other session keys.

**Rollback risk:** Low — new concern, not included in any controller yet.

**Tests:**

- State and nonce are cryptographically random and different each call
- PKCE challenge is correct SHA256 of verifier
- Session keys are written correctly
- Unknown or disabled organization returns error (not raise)
- URL contains all required params (`response_type=code`, `code_challenge_method=S256`, `nonce`,
  `state`, `scope`, `redirect_uri`)

---

### Slice 7: Core Concern — `EntraIdOrgCallback`

**Files:**

- `app/controllers/concerns/entra_id_org_callback.rb`
- `test/controllers/concerns/entra_id_org_callback_test.rb`

**Behavior** (mirrors `OidcCallback` with deny-by-default override):

- `handle_entra_callback`:
  1. Validate `state` param matches `entra_org_state` in session (not expired, not reused) → deny on
     failure
  2. Load `OrganizationEntraConnection` by `entra_org_connection_id` in session → deny if not found
     or disabled
  3. Exchange `code` for tokens via `EntraIdTokenClient` (sends `code_verifier`, `client_secret`)
  4. Verify ID token signature against Entra JWKS for `connection.tenant_id`
  5. Validate `iss` == `connection.issuer` → deny on mismatch
  6. Validate `aud` == `connection.client_id` → deny on mismatch
  7. Validate `exp` and `nbf` → deny on expiry
  8. Validate `tid` == `connection.tenant_id` → deny on mismatch
  9. Validate `nonce` in ID token == `entra_org_nonce` in session → deny on mismatch
  10. Extract `oid` claim → deny if missing
  11. Look up `OperatorEntraIdentity` by `(tenant_id: tid, oid: oid)` → deny if not found or
      disabled
  12. Load linked `Operator` → deny if not in valid state
  13. Clear all `entra_org_*` session keys
  14. Call `reset_session`
  15. Establish operator session via `establish_signed_in_operator_session!`
  16. Redirect to `auth_org_dashboard_path` or pending OIDC authorization if present

**`EntraIdTokenClient`** (new service):

- Wraps `Net::HTTP` or Faraday POST to token endpoint
- Sends: `grant_type=authorization_code`, `code`, `redirect_uri`, `client_id`, `client_secret`,
  `code_verifier`
- Returns parsed token response or raises `EntraIdTokenExchangeError`

**Security invariant:** All 16 steps are sequential with early denial on any failure. No step may be
bypassed. No record is created at any step.

**Rollback risk:** Low — new concern, not included in any controller yet.

**Tests:**

- Each of the 16 steps fails independently and returns denial
- Nonce mismatch denies
- State mismatch denies
- Expired state denies
- Wrong `iss` denies
- Wrong `aud` denies
- Wrong `tid` denies
- Missing `oid` denies
- Unknown mapping denies
- Disabled mapping denies
- Disabled connection denies
- Inactive operator denies
- Session is reset on success
- No record created on any failure or success path

---

### Slice 8: Controllers — Auth Org Entra Sign-In

**Files:**

- `app/controllers/auth/org/entra/sign_ins_controller.rb`
- `app/controllers/auth/org/entra/auths_controller.rb`
- `app/controllers/auth/org/entra/callbacks_controller.rb`
- `app/controllers/auth/org/entra/failures_controller.rb`
- `app/views/auth/org/entra/sign_ins/show.html.erb`
- `test/controllers/auth/org/entra/sign_ins_controller_test.rb`
- `test/controllers/auth/org/entra/callbacks_controller_test.rb`

**Controller inheritance:**

- All inherit from `Auth::Org::ApplicationController`
- `Auth::Org::Entra::CallbacksController` includes `EntraIdOrgCallback`
- `Auth::Org::Entra::AuthsController` includes `EntraIdOrgSsoInitiator`

**Sign-in page (`show`):**

- Renders "Sign in with Microsoft" button
- Does NOT render any sign-up links
- POST button to `/entra/auth` with Rails CSRF token

**Auth create action:**

- Loads org from params (slug or public_id)
- Calls `initiate_entra_sign_in!(organization_slug:)`
- Redirects to Microsoft authorize URL (`allow_other_host: true`)

**Callback show action:**

- Calls `handle_entra_callback`
- On success: redirect to dashboard or OIDC challenge
- On failure: redirect to `/entra/failure` with safe error code

**Failure show action:**

- Renders safe error message (no internal detail exposed)
- Links back to sign-in page

**Security invariant:** `callbacks_controller` must not subclass any app-surface controller. Must
not include `SocialCallbackGuard` or any `social_auth_*` concern.

**Rollback risk:** Medium — routes and controllers added. Rolled back by removing route block and
deleting controller files. No existing behavior changed.

**Tests:**

- `GET /entra/sign/in` renders sign-in page on org host; returns 404 on app host
- `POST /entra/auth` without CSRF token returns 422
- `POST /entra/auth` with valid CSRF redirects to Microsoft
- `GET /entra/callback` with valid params signs in existing enabled mapping
- `GET /entra/callback` with unknown mapping returns failure redirect
- `GET /entra/callback` with disabled mapping returns failure redirect
- `GET /entra/callback` with disabled connection returns failure redirect
- `GET /entra/callback` without state returns failure redirect
- `GET /entra/callback` with nonce mismatch returns failure redirect

---

### Slice 9: Routes — Register Entra Routes in `config/routes/auth.rb`

**Files:**

- `config/routes/auth.rb`
- `test/integration/health_endpoints_test.rb` (verify no route leak)

Add the `namespace :entra` block inside the `auth_surface :org` block.

**Security invariant:** The entra namespace must be inside the org surface host constraint, not at
the top-level or inside the app surface block.

**Rollback risk:** Low — removing the namespace block is clean rollback.

**Tests:**

- `bin/rails routes` output confirms `/entra/` paths only appear on org host
- `GET /entra/sign/in` returns 404 on app host (`id.app.localhost`)
- Route test: no `/social/` path registered on org host

---

### Slice 10: Admin UI — Pre-Provisioning Interface (Minimal)

**Out of scope for v1 backend-only implementation.** An admin must be able to:

1. Create `OrganizationEntraConnection` (with tenant_id, client_id, issuer, surface)
2. Enable/disable a connection
3. Create `OperatorEntraIdentity` (with operator_id, oid, tid, email_for_display)
4. Enable/disable a mapping

In v1, this can be done via Rails console or a seed/import script. A proper admin UI belongs in a
follow-up slice.

**Files (v1 console approach):**

- `db/seeds/entra_id_example.rb` — commented example seed for development

---

### Slice 11: Test Matrix Implementation

See Section 9 (Test Matrix) for the full list. Implement all tests in slices 6–9.

---

### Slice 12: Documentation

See Section 10 (Documentation Plan).

---

## 9. Test Matrix

| #   | Test case                                                                | Controller/Layer                    | Expected result                                        |
| --- | ------------------------------------------------------------------------ | ----------------------------------- | ------------------------------------------------------ |
| T01 | Valid existing enabled mapping signs in                                  | `EntraIdOrgCallback`                | Session established, redirect to dashboard             |
| T02 | Unknown `tid` (not in any connection)                                    | Callback                            | Denial — no session                                    |
| T03 | Known `tid` but unknown `oid`                                            | Callback                            | Denial — no session                                    |
| T04 | Known `(tid, oid)` but `OperatorEntraIdentity.enabled = false`           | Callback                            | Denial                                                 |
| T05 | Known mapping but `OrganizationEntraConnection.enabled = false`          | Callback                            | Denial                                                 |
| T06 | Disabled operator (withdrawn, admin-locked)                              | Callback                            | Denial                                                 |
| T07 | Wrong `aud` in ID token                                                  | Callback                            | Denial — aud mismatch                                  |
| T08 | Wrong `iss` in ID token                                                  | Callback                            | Denial — iss mismatch                                  |
| T09 | Missing `nonce` in session                                               | Callback                            | Denial                                                 |
| T10 | Nonce mismatch (ID token nonce ≠ session nonce)                          | Callback                            | Denial                                                 |
| T11 | State mismatch (callback state ≠ session state)                          | Callback                            | Denial                                                 |
| T12 | Expired state (older than TTL)                                           | Callback                            | Denial                                                 |
| T13 | Callback with `error` param from Microsoft                               | Callback                            | Denial — no token exchange attempted                   |
| T14 | Callback cannot create `OperatorEntraIdentity`                           | Callback                            | Denial — verify no DB write                            |
| T15 | Callback cannot create `Operator`                                        | Callback                            | Denial — verify no DB write                            |
| T16 | Email in ID token changes; `oid`/`tid` unchanged                         | `OperatorEntraIdentity` model       | Sign-in succeeds; email_for_display updated (optional) |
| T17 | Email-only match attempt (no oid match)                                  | Callback                            | Denial — lookup is by `(tid, oid)` only                |
| T18 | Auth org token not accepted on app surface                               | Route constraints                   | 404 on app host                                        |
| T19 | `/entra/callback` returns 404 on app host                                | Route constraints                   | 404                                                    |
| T20 | Request phase (POST /entra/auth) without CSRF token                      | Controller                          | 422 Unprocessable                                      |
| T21 | Request phase GET to /entra/auth returns 404 or 405                      | Route                               | 404/405 — POST only                                    |
| T22 | Session is reset on successful sign-in                                   | Callback                            | Session ID changes after sign-in                       |
| T23 | Pre-existing app Client session not merged with operator session         | Session isolation                   | App session keys absent in org session after login     |
| T24 | PKCE verifier sent in token exchange; wrong verifier rejected            | `EntraIdTokenClient`                | Token exchange fails with wrong verifier               |
| T25 | Disabled connection stops sign-in immediately                            | Callback                            | Denial at connection lookup step                       |
| T26 | `sign_in_only: false` cannot be saved                                    | `OrganizationEntraConnection` model | Validation error                                       |
| T27 | Issuer format mismatch in connection record                              | `OrganizationEntraConnection` model | Validation error                                       |
| T28 | `oid` empty in `OperatorEntraIdentity`                                   | Model                               | Validation error                                       |
| T29 | Multiple concurrent sign-in flows from same session (pending flow limit) | `EntraIdOrgSsoInitiator`            | Second flow overwrites or limits enforced              |
| T30 | Sign-in succeeds when operator has enabled passkey but uses Entra        | Callback                            | Success — auth method orthogonal                       |

---

## 10. Documentation Plan

### 10.1 ADR (Architecture Decision Records)

| File                                        | Content                                                                                                                                                                                        |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `adr/entra-id-org-sign-in-only-boundary.md` | Defines sign-in-only contract, deny-by-default, pre-provisioned mapping requirement, `tid+oid` as stable key, no email-based auth, no JIT, no domain matching. Accepted before implementation. |

### 10.2 Architecture Documentation

| File                                             | Content                                                                                                                                                                                                |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `docs/security/entra-id-org-sign-in-design.md`   | Architecture overview: how Entra ID org sign-in fits into auth/base surface boundary, credential ceremony model, data flow from sign-in page through callback to operator session, security invariants |
| `docs/identity/entra-id-org-identity-mapping.md` | Explains `OrganizationEntraConnection` and `OperatorEntraIdentity` models, `tid+oid` key rationale, provisioning lifecycle                                                                             |

### 10.3 Operations Documentation

| File                                                      | Content                                                                                                                                        |
| --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `docs/operations/entra-id-app-registration-setup.md`      | Step-by-step Microsoft Entra App Registration setup: tenant type, scopes, redirect URIs per environment, client secret rotation, JWKS endpoint |
| `docs/operations/entra-id-org-connection-provisioning.md` | How to add/remove an org Entra connection and operator identity mapping: Rails console commands for v1, future admin UI reference              |

### 10.4 Security Notes

| File                                               | Content                                                                                                             |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `docs/security/entra-id-sign-in-only-rationale.md` | Why sign-up/JIT/email-domain are forbidden: attack surface analysis, identity binding risks, pre-provisioning model |

### 10.5 Update Existing Docs

| File                        | Update                                                             |
| --------------------------- | ------------------------------------------------------------------ |
| `docs/hld.md` or equivalent | Add Entra ID org sign-in to org authentication surface description |
| `adr/README.md`             | Add entry for `entra-id-org-sign-in-only-boundary.md`              |

---

## 11. Open Blockers

| #   | Blocker                                                                                                                                                                                                                                                                                                                                                                                                             | Who resolves                   | Impact                                       |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------ | -------------------------------------------- |
| B1  | `OmniAuthNonAppSocialGuard` blocks org hosts — OmniAuth is confirmed as wrong template. Confirm owner agrees with `OidcSsoInitiator`-pattern approach instead.                                                                                                                                                                                                                                                      | Owner                          | Blocks all implementation                    |
| B2  | Which database migrations directory to use for `org_principal` new tables? (Confirm convention from `db/org_principal_migrate/` or equivalent.)                                                                                                                                                                                                                                                                     | Repo convention check          | Blocks Slice 3                               |
| B3  | Client secret storage pattern: one Rails credential entry per connection `public_id`, or per organization slug, or per environment?                                                                                                                                                                                                                                                                                 | Owner + security review        | Blocks Slice 5                               |
| B4  | Does the `openid_connect` gem (for JWKS/ID token verification) already exist in `Gemfile.lock`? If not, is there an existing internal ID token verifier (`OidcIdTokenVerifier`) that can be reused/extended?                                                                                                                                                                                                        | Repo check (grep Gemfile.lock) | Blocks Slice 6–7                             |
| B5  | How is the auth org Entra ID callback expected to deliver the credential ceremony result to base org for operator session issuance? Option A: Auth org establishes its own short-lived operator session directly. Option B: Auth org issues an opaque ceremony token that base org exchanges. The existing internal OIDC flow uses Option B (Sign→Acme code exchange). Entra ID v1 may use Option A for simplicity. | Owner architecture decision    | Shapes Slice 8 significantly                 |
| B6  | Is a multi-organization Entra setup in scope for v1 (one connection per organization) or a single shared Entra App Registration for all organizations? Single-per-org is recommended but requires multiple App Registration entries in Azure.                                                                                                                                                                       | Owner                          | Shapes data model and App Registration count |

---

## 12. Questions for Owner

Only questions that are genuinely blocking and cannot be resolved from repo evidence alone:

**Q1 (B1):** The existing `OmniAuthNonAppSocialGuard` blocks the org host from all `/social/` paths.
Repo evidence confirms OmniAuth is not appropriate for org Entra ID. The recommended approach is a
dedicated `EntraIdOrgSsoInitiator` concern mirroring `OidcSsoInitiator`. Do you agree with this
approach, or do you specifically require OmniAuth middleware to be used?

**Q2 (B5):** After the Entra ID callback succeeds in auth org, how should the operator session be
issued? Option A: auth org calls `establish_signed_in_operator_session!` directly (same as
passkey/secret-credential sign-in today). Option B: auth org issues a short-lived ceremony token;
base org exchanges it for an operator session (mirrors the existing Acme/Sign OIDC flow). Option A
is simpler for v1. Which is correct for your architecture?

**Q3 (B6):** Should each customer organization get its own Entra App Registration (separate
`client_id` per org), or should one App Registration be shared across all organizations (single
`client_id`, multiple redirect URIs, tenant validated by `tid` in the callback)? Separate
registrations are more isolated (breach of one org's secret doesn't affect others) but require more
Azure administration. What is the operational preference?
