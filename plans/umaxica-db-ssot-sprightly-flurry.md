# Umaxica DB SSOT -> JWT Projection / RO-RW Boundary Audit + Remediation Plan

Date: 2026-07-02. Read-only audit; no code was changed. Evidence markers: **[FACT]** = read directly
from code/docs at the cited line, **[DOC]** = documented expectation, **[HYP]** = hypothesis needing
confirmation, **[REC]** = recommended change.

---

# Executive Summary

- **Overall status: partially protected.** The core doctrine (DB is SSOT, JWT is signed projection,
  `Actor.*` typed RO readers, refresh re-projects from DB, per-request DB revocation checks) is
  documented and largely implemented. The unprotected edges are: a broad write-on-GET preference
  lifecycle with no read-only invariant tests, a Com/Visitor sync asymmetry, brittle
  `controller_path`-position surface inference, and raw-JWT-based authorization scope/audience
  checks in `ApplicationPolicy`.
- **Biggest 5 findings:**
  1. Every `base/{app,com,org}` GET runs `set_preferences_cookie` before authentication, which can
     create a preference row + 12 child rows + 2 audit rows and rotate refresh tokens for
     unauthenticated visitors — doc-sanctioned as lifecycle, but not allowlisted, not
     authorization-checked, and not protected by any "no writes on RO routes" test
     (`app/controllers/concerns/preference_transport.rb:16-32`,
     `preference_refresh_token_transport.rb:113-162,176-225`,
     `base/app/application_controller.rb:70`).
  2. `authorize_preference_write!` deliberately skips GET/HEAD
     (`base/app/preferences_base_controller.rb:15,24-26`) while GET `edit` actions open `:writing`
     and create child rows via `set_*_preferences_edit` → `load_or_create_preference_child`
     (`preference_core.rb:16,31,76,121,146,196,244-257`; `preference_base.rb:1153-1164`).
  3. Com/Visitor is excluded from login/rotation preference adoption — `adoptable_preference_class?`
     allows only `AppPreference`/`OrgPreference` (`preference_adoption.rb:47-50`), and
     `VisitorToken` is missing from the binding-method/DBSC class maps
     (`preference_base.rb:557-579`), while reset/read paths do handle Visitor — uneven surface
     coverage.
  4. Surface selection uses two divergent mechanisms: host-label `CoreSurface.detect` (default
     `:com`, `app/values/core_surface.rb:6-30`) vs positional `controller_path.split("/")[1]` in
     `PreferenceClassRegistry.for_controller_path` (`preference_class_registry.rb:246-249`) and
     `controller_path.split("/").first` with default `"sign"` in `preference_route_authority`
     (`preference_core.rb:834-835`). No test locks them against each other.
  5. `ApplicationPolicy` derives `scp`/`aud`/`sub` from the raw JWT payload
     (`app/policies/application_policy.rb:75-128,198-200`); scopes are type-derived, not
     DB-role-derived (`authorization_token_claims.rb:88-100`); role helpers call `user.has_role?`
     which is not defined in `app/models` — dead legacy hooks at the authorization boundary.
- **Highest-risk security issue:** unauthenticated write-on-GET preference lifecycle with no
  rate/abuse guardrail asserted by tests (row-creation amplification + audit-log growth), combined
  with the GET authorization bypass on preference edit screens.
- **Highest-risk architecture issue:** the RO/RW boundary is enforced by convention and callback
  order only; concerns named `PreferenceBase`/`PreferenceGlobal`/`PreferenceTransport` and the
  "resolver" (`AuthenticationCurrentResourceResolver#touch_session_activity!`,
  `authentication_current_resource_resolver.rb:88-98`) all write DB, and nothing (test or static
  check) prevents a new controller from inheriting RW behavior silently.
- **Implementation changes recommended before cloud deployment:** yes — at minimum Slice 1
  (characterization/invariant tests) and Slice 6 (write allowlist + CI guardrail); Slice 5
  (Com/Visitor + surface-inference hardening) before exposing the com surface.

---

# Expected Architecture from Docs

All items **[DOC]** with citations.

- **DB is SSOT; Preference JWT is its signed projection and runtime read cache.**
  `docs/architecture/preference.md:223-239`; `docs/architecture/controller-lifecycle.md:104-122`;
  `adr/preference-soft-bubble-doctrine.md:36-42`; `adr/actor-current-facade.md:5-11`. Generalized to
  auth: "Treat the JWT as the projection of auth DB state, not as a separate source of truth"
  (`docs/contact.md:30`).
- **Auth access tokens must not carry preference snapshots**; the `prf` claim is retired ("dead
  transport") (`docs/architecture/preference.md:325,329-330`;
  `adr/preference-soft-bubble-doctrine.md:36-42`; history in
  `plans/archive/preference-actor-hydration-ssot.md:42-56`,
  `plans/archive/preference-jwt-runtime-cache-migration.md:12-27`).
- **Do not reverse the flow**: never issue JWTs from `Actor.preferences`, never write DB from
  `Actor.preferences`, never read JS cookies as Rails input
  (`docs/architecture/preference.md:275-285`).
- **`Actor` is the only request context container**, an immutable snapshot (`Data.define`), rebuilt
  per request, "not a cache source"; `Current`/`Signer`/`Acmeer` removed
  (`adr/actor-current-facade.md:29-35,64-66,104-117`;
  `docs/architecture/current_context.md:5-9,22-30,48-58`).
- **Preference DB write allowlist (de facto)** — only: new preference creation; valid refresh-token
  rotation; logged-in HTML preference edit-entry refresh; explicit update endpoints; explicit
  reset/delete; login-time adoption/sync; repair/admin. Normal `before_action` setup must NOT
  recover a broken preference JWT from DB (`docs/architecture/preference.md:291-312`;
  `controller-lifecycle.md:61-90`).
- **Sync field allowlist**: only language/region/timezone/theme/cookie-consent move on sync; auth
  secrets, identity, billing, moderation are forbidden
  (`docs/architecture/preference.md:126-134,150-157`; `preference-behavior-contract.md:42-63`).
  Re-login reconciliation is whole-record by parent recency
  (`adr/preference-relogin-reconciliation-record-recency.md:21-36`).
- **Surface separation**: app/com/org are "soft bubbles"; preference data must never be copied
  across surfaces (`adr/preference-soft-bubble-doctrine.md:104-126`;
  `docs/architecture/preference.md:110-124`). Credential cookies are host-only `__Host-` with role
  names, NOT surface-scoped names (surface-scoped names are legacy read/delete compat only)
  (`docs/security/cookie-domain-scope.md:8-23,57-64`).
- **Namespace model (target)**: Acme(IdP/AS)→`base`, Sign(ceremony RP)→`auth`, Core(BFF)→`core`,
  Base(control plane)→`base`, Palm(bearer RS)→`palm`; `base` is deliberately overloaded during
  transition (`docs/architecture/acme-sign-core-base-port.md:22-35`;
  `adr/acme-sign-core-base-port-boundary.md:31-67`). `apex` is a DNS term, not a code namespace.
  Legacy Rails namespaces: `sign`, `acme`, `jump`.
- **Authority placement**: Identity/Account/Organization authority = `zenith` DBs
  (`docs/architecture/database-authority-placement.md:24-32,57-72`); Avatar = separate `avatar` DB,
  bridged additively via `AvatarPersonaBinding` (`adr/avatar-account-bridge-boundary.md:5-46`);
  org/group/membership is the acknowledged "weakest boundary"
  (`database-authority-placement.md:73-76,113-122`).
- **ID token claim contract**: MUST `iss sub subject_type aud exp iat auth_time sid nonce acr amr`;
  `act` "intentionally not used" (in the ID-token contract)
  (`adr/oidc-claims-decision.md:22,52-86`).
- **Doc contradictions found** (details in Docs Gap List): preference-authority owner drifted
  `sign → acme/www → base` across docs; `plans/objective-perform-an-elegant-cake.md` claims `prf` is
  still emitted (stale — disproved below); `adr/identity-authority-boundary.md` was repurposed so
  older citations to it are stale; cookie-naming guidance in `preference.md:356-360` contradicts
  `cookie-domain-scope.md`.

---

# Actual Implementation Map

## JWT/token claim producers

| Token                                                                | Producer                                                                                                                                                                                            | Decoder                                                  | prf                                               | identity/avatar/org/group                                    | Sources                                               |
| -------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- | ------------------------------------------------- | ------------------------------------------------------------ | ----------------------------------------------------- |
| Auth access (ES384)                                                  | `AuthorizationTokenClaims.build` `app/controllers/concerns/authorization_token_claims.rb:7-36`; `SecurityJwtAuthAccessTokenCodec.encode` `app/values/security_jwt_auth_access_token_codec.rb:13-71` | same codec `:73-183` (JWT.decode `:126`)                 | **No** [FACT]                                     | **No** — only `sub`,`act`,`scp`,`acr/amr`,`sid`              | DB resource + token_record; not copied from prior JWT |
| Preference access                                                    | `SecurityJwtPreferenceTokenCodec.encode` `app/values/security_jwt_preference_token_codec.rb:11-25`; payload `preference_base.rb:658-714`; issue `preference_access_token_issuer.rb:9-43`            | codec `:27-80`                                           | **Yes** — `preferences` hash is the DB projection | preference row identity only (`public_id`,`preference_type`) | DB preference row + child option tables               |
| OIDC ID token                                                        | `security_jwt_oidc_id_token_codec.rb:37-62`; `oidc_id_token_issuer.rb:30-53`                                                                                                                        | codec `:14-34`                                           | No                                                | No                                                           | DB resource + client registry + nonce                 |
| OIDC access (RS)                                                     | same as auth access, via `oidc_token_exchange_coordinator.rb:188`, `core_browser_credential_contract.rb:48`                                                                                         | `oidc_access_token_authenticator.rb` (DB session lookup) | No                                                | No                                                           | DB                                                    |
| Backchannel logout                                                   | `oidc_logout_token_codec.rb:17-49`                                                                                                                                                                  | same (`consume_jti!` `:45`)                              | No                                                | No                                                           | session record                                        |
| Jump RT                                                              | `security_jwt_jump_rt_token_codec.rb:12-62`; `jump_rt_issuer.rb:49-66`                                                                                                                              | codec `:48`; `jump_rt_return_verifier.rb:72`             | No                                                | No — routing only                                            | request routing                                       |
| Ceremony grants (email/passkey/totp/secret/social/step-up/telephone) | `app/values/identity_*_ceremony_contract.rb` (~:146-163 each)                                                                                                                                       | same files                                               | No                                                | credential-under-registration refs only                      | ceremony DB rows                                      |
| Auth/preference refresh                                              | **opaque DB rows**, not JWTs — `acme_refresh_token_issuer.rb:36-71` (reuse → family revoke `:99-124`); `preference_refresh_token_transport.rb`                                                      | n/a                                                      | n/a                                               | n/a                                                          | DB                                                    |

## Runtime readers

| Domain             | Canonical reader                                                                           | Backing source                                                                                                                                                                                                                       | Classification                                                                            |
| ------------------ | ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------- |
| Preference         | `Actor.preferences` → `Actor::Preference` (`app/models/actor/preference.rb:17-257`)        | Preference JWT hash, installed only at `actor_support.rb:253-264` (`from_jwt` call `:259`) + request-param overlay `:349-390`                                                                                                        | typed RO over signed DB projection                                                        |
| Identity/authn     | `Actor.authn` → `Actor::Authentication` (`app/models/actor/authentication.rb:6-85`)        | JWT decoded then DB-confirmed by `AuthenticationCurrentResourceResolver#call` (`authentication_current_resource_resolver.rb:34-69`): jti↔DB `:162-168`, DPoP `:170-178`, resource by `sub` `:229-232`, admin lock `:238-251,278-281` | mixed JWT+DB; DB authoritative for revocation; `access_claims` exposes frozen raw payload |
| Authorization      | `Actor.authz` → `Actor::Authz`; consumed by `ApplicationPolicy`                            | `scp`/`aud`/`sub` from raw JWT (`application_policy.rb:75-128,198-200`); ownership from DB record                                                                                                                                    | mixed; scope/audience = raw JWT                                                           |
| Avatar/selection   | `Actor.selection` → `Actor::SelectedContext` (`app/models/actor/selected_context.rb:6-45`) | DB session token row (`actor_support.rb:182-195`)                                                                                                                                                                                    | DB read; no JWT claim exists                                                              |
| Organization/group | **none** — no Actor slot, no claim                                                         | DB via `record.organization` in policies (`application_policy.rb:64-71`) and `org_*` services                                                                                                                                        | DB-only by design; ad hoc                                                                 |

Notable: `access_token_payload` hook probed at `actor_support.rb:132` is defined nowhere — the
recompute path is dead; the authoritative install is
`AuthenticationBase#populate_current_attributes!` (`authentication_base.rb:1649-1681`). [FACT]

## DB writers

See DB Write Matrix below.

## Concerns and callbacks

before_action chain on `Base::App::ApplicationController`
(`base/app/application_controller.rb:54-87`; com/org mirror it): `set_preferences_cookie`(70,
**RW**) → `resolve_param_context`(71) → `set_region`(72) → `transparent_refresh_access_token`(75,
**RW**) → `set_current_actor`(76, triggers session-touch **RW**) →
`apply_localization_preferences`(77) → `set_locale/set_timezone/set_color_theme`(79-81) →
`prepend_around_action :with_actor_lifecycle`(87). Order locked by
`test/security/invariants/controller_lifecycle_order_invariant_test.rb`.

| Concern                                                   | Nominal role      | Actual                                                                                                                                                                                            | Verdict                                               |
| --------------------------------------------------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| `PreferenceTransport` / `PreferenceRefreshTokenTransport` | transport         | creates + rotates preference rows, audit rows, cookies on GET pre-auth (`preference_transport.rb:16-32`; `preference_refresh_token_transport.rb:113-162,176-225`)                                 | lifecycle RW, misnamed                                |
| `PreferenceBase` / `PreferenceGlobal`                     | base/read         | write helpers: `create_preference_options`(:186-199), `create_audit_log`(:369-391), `update_preference_child_with_audit`(:411-429), DBSC challenge `update!`(:619-625), replay handling(:888-924) | mixed RW, misnamed                                    |
| `PreferenceCore`                                          | settings snapshot | GET `edit` creates child rows (`:16,31,76,121,146,196,244-257`); updates dual-write (`:271-329,507-539`); resets (`:579-720`)                                                                     | mixed RW                                              |
| `PreferenceAdoption`                                      | login sync        | `create!`/`update!` under writing (`preference_adoption.rb:71-92,112-154`); App/Org only (`:47-50`); rescues StandardError (non-fatal)                                                            | lifecycle RW                                          |
| `PreferenceResourceSync`                                  | mirror sync       | `update!` at `:69,108,125,136,247,261`                                                                                                                                                            | lifecycle RW                                          |
| `AuthenticationBase`                                      | auth              | token issue/rotate/revoke writing switches (13+ sites incl. `:396,461,2441,2455`); `transparent_refresh_access_token` on GET (`:636-658`)                                                         | mixed RW                                              |
| `AuthenticationCurrentResourceResolver`                   | resolver (read)   | `touch_session_activity!` `update_columns` on GET (`:88-98`, throttled)                                                                                                                           | read-with-hidden-write                                |
| `RestrictedSessionGuard`                                  | guard             | opens `:writing` inside before_action (`restricted_session_guard.rb:61`)                                                                                                                          | suspicious                                            |
| `ActorSupport`, `PreferenceLocalization`, `RateLimit`     | read              | no DB writes [FACT]                                                                                                                                                                               | RO, clean                                             |
| `SecurityJwtAuthAccessTokenCodec` (value obj)             | codec             | acquires `role: :writing` connection during decode lookup (`security_jwt_auth_access_token_codec.rb:240`)                                                                                         | suspicious (connection role, not necessarily a write) |

## Surface mapping

| Mechanism          | Code                                                                                                                                                            | Behavior                                                                                  |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Host label         | `CoreSurface.detect/current` `app/values/core_surface.rb:6-30`                                                                                                  | first host label ∈ `app com org net dev`, **default `:com`**                              |
| Preference class   | `PreferenceClassRegistry.for_controller_path` `preference_class_registry.rb:246-249`                                                                            | `controller_path.split("/")[1]&.capitalize`; raises KeyError on unknown (`:241-243`)      |
| Route authority    | `preference_route_authority` `preference_core.rb:834-835`                                                                                                       | `controller_path.split("/").first`, **default `"sign"`**                                  |
| Cookie names       | `preference_cookie_name.rb:9-22,36-59`                                                                                                                          | current names role-based + `__Host-` (surface arg ignored); legacy names surface-prefixed |
| Auth JWT aud/iss   | `authentication_jwt_configuration.rb:26-37`; `authorization_token_claims.rb:24-25`; decode enforces iss+aud (`security_jwt_auth_access_token_codec.rb:299-312`) | per-resource-type audiences via ENV, fallback `["umaxica-api"]`                           |
| Preference JWT aud | host-scoped audience + exact iss match (`security_jwt_preference_token_codec.rb:142-163,268-286`)                                                               | host isolation                                                                            |

Legacy: `app/controllers/sign/{app,com,org}/` directories are empty; `acme`/`apex` survive only as
URL-helper prefixes, i18n roots, and the `preference_route_authority` default. [FACT]

---

# JWT Claim Production Findings

- **Preference**: projected only into the preference JWT (`preferences` hash built from DB
  associations, `preference_base.rb:658-714`). Auth access token emits **no `prf`** — verified
  directly in `authorization_token_claims.rb:16-35` [FACT]. This matches
  `docs/architecture/preference.md:329-330` and **disproves**
  `plans/objective-perform-an-elegant-cake.md` C5 which claims `prf` is still embedded (stale plan).
- **Identity**: not projected beyond `sub`/`act`/`acr`/`amr`/`sid`. Credential state (passkeys,
  TOTP, secrets, social) is DB-only; the resolver re-checks DB per request. Consistent with docs
  (intentional DB-only design).
- **Avatar**: no avatar claim in any token [FACT]. Selection context lives on the DB session row
  (`selected_avatar_public_id` etc., read at `actor_support.rb:182-195`). Docs place avatar
  authority in the avatar DB — **intentional DB-only design**.
- **Organization/group**: no claim [FACT]. Docs never call for one; org/group is DB-only. However
  `scp` is derived purely from `resource_type` (`authorization_token_claims.rb:88-100` — operator
  always gets `read:org write:org`), so the token carries a coarse role-like grant that does NOT
  reflect DB membership/role rows. Membership revocation therefore relies entirely on DB checks in
  policies — which are partly dead (see Runtime Reader Findings).
- **`act` claim**: emitted in the access token (`authorization_token_claims.rb:22`) while
  `adr/oidc-claims-decision.md:22` says `act` is "intentionally not used" — that ADR is scoped to
  the ID token, and the ID-token codec indeed emits `act` too
  (`security_jwt_oidc_id_token_codec.rb:37-62` per inventory). **Doc/code contradiction** (Medium).
- **Refresh/reissue**: auth access refresh rebuilds claims from `resource` + `token_record`
  (`authentication_jwt_tokens.rb:25-39,85-113`); preference reissue rebuilds from the live row
  (`preference_access_token_issuer.rb:9-20`). **No token type copies a previous JWT payload.** [FACT
  — strongest point of the implementation]
- **Staleness risk**: bounded. Auth: per-request DB checks (jti `:162-168`, DPoP `:170-178`, admin
  lock `:238-251`) invalidate revoked/rotated/locked tokens. Preference: DB `jti` rotation
  invalidates cookies on next read (`preference_access_token_transport.rb:47-70`). Residual
  staleness: within an access token's TTL, `scp`/`acr` and preference values persist until next
  request-time DB check or reissue — acceptable per docs, but `scp` has no DB anchor at all (see
  Security Finding S5).

# Runtime Reader Findings

- **Typed readers exist and are clean** for preference (`Actor.preferences`), authn (`Actor.authn`),
  authz (`Actor.authz`), selection (`Actor.selection`). `Actor` accessors perform no I/O [FACT].
- **Raw payload readers**: confined to resolver/codec/policy layers — `ApplicationPolicy`
  (`application_policy.rb:75-128,198-200`), preference transport
  (`preference_access_token_transport.rb:32,66,86-104`; `preference_base.rb:783-797`), auth resolver
  (`authentication_current_resource_resolver.rb:106,163-173,231`), OIDC authenticator, DPoP
  verifier, ceremony contracts. No scattered business-code raw access found.
  `Actor.authn.access_claims` / `Actor.authz.token_claims` expose the (deep-frozen) raw hash to any
  caller — a deliberate but unguarded escape hatch.
- **DB-vs-JWT precedence**: preference → JWT-first by design (JWT = signed DB projection); auth →
  JWT decoded then DB-confirmed; authz scopes/aud → JWT only; selection/org → DB only. Matches docs
  except `ApplicationPolicy` scope checks (docs are silent on `scp` grounding).
- **Missing readers**: no `Actor` slot for organization/workspace/membership — every policy/service
  resolves org context ad hoc from `record` (`application_policy.rb:64-71`). Role helpers
  `operator?/manager?/editor?/...` call `user.has_role?(…, organization:)` which is **not defined**
  in `app/models` — dead legacy hooks at the authz boundary [FACT per inventory; verify before Slice
  2]. Design gap.
- **Reads with hidden writes**: `touch_session_activity!`
  (`authentication_current_resource_resolver.rb:88-98`), stale-cookie deletion in
  `preference_access_token_transport.rb:49,56`, transparent refresh inside `load_current_resource`
  (`authentication_base.rb:1587-1593`).

---

# DB Write Matrix

Namespace legend: writes live under `base/{app,com,org}` controller trees + shared concerns +
services. Verdicts: expected / over-broad / suspicious / violation.

| #   | Write path                                                                            | Location                                                                                                                                                      | Domain              | Trigger                                   | GET?     | Pre-auth? | AuthZ?                                                         | Verdict                                                                          |
| --- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- | ----------------------------------------- | -------- | --------- | -------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| W1  | `create_new_preference_record!` (row + 12 children + cookie row + 2 audit rows)       | `preference_refresh_token_transport.rb:113-162`                                                                                                               | preference          | any request w/o valid tokens              | **Yes**  | **Yes**   | No                                                             | expected (doc allowlist "new preference creation") **but over-broad & untested** |
| W2  | `refresh_refresh_token_lifetime` → `rotate!` + audit + `adopt_rotated_preference!`    | `preference_refresh_token_transport.rb:176-225`                                                                                                               | preference/token    | refresh cookie present                    | **Yes**  | **Yes**   | No                                                             | expected (rotation) but over-broad                                               |
| W3  | `ensure_preferences_record`                                                           | `preference_base.rb:351-367`; wired `base/*/preference/*_controller.rb:12`                                                                                    | preference          | preference screens                        | **Yes**  | mixed     | GET skipped                                                    | over-broad                                                                       |
| W4  | `set_*_preferences_edit` → `load_or_create_preference_child` → `create_<assoc>!`      | `preference_core.rb:16,31,76,121,146,196,244-257`; `preference_base.rb:1153-1164`                                                                             | preference children | GET `edit`                                | **Yes**  | No        | **skipped on GET** (`preferences_base_controller.rb:15,24-26`) | **suspicious**                                                                   |
| W5  | `refresh_preference_token_from_db_for_edit_entry!`                                    | `preferences_base_controller.rb:19-22`                                                                                                                        | preference/token    | GET edit entry                            | Yes      | No        | No                                                             | expected (doc-sanctioned edit-entry refresh, `preference.md:306-312`)            |
| W6  | update endpoints (dual-write token+resource)                                          | `preference_core.rb:271-329,507-539`                                                                                                                          | preference          | POST/PATCH                                | No       | No        | `authorize_resource_preference_write!` (`:275,315,517`)        | expected                                                                         |
| W7  | resets (`retire_preference_for_reset!`, `destroy_resource_preference_for_reset!`)     | `preference_core.rb:579-720`                                                                                                                                  | preference          | POST                                      | No       | No        | yes                                                            | expected                                                                         |
| W8  | `adopt_preference_for!` create/copy                                                   | `preference_adoption.rb:15-25,71-92,112-154`                                                                                                                  | preference          | login + rotation (incl. GET via W2)       | indirect | No        | No                                                             | expected lifecycle; **App/Org only** (`:47-50`)                                  |
| W9  | `PreferenceResourceSync` mirror writes                                                | `preference_resource_sync.rb:69,108,125,136,247,261`                                                                                                          | preference          | update/sync                               | No       | No        | inherited                                                      | expected                                                                         |
| W10 | `touch_session_activity!` `update_columns`                                            | `authentication_current_resource_resolver.rb:88-98`                                                                                                           | session             | every authed request (throttled)          | **Yes**  | n/a       | n/a (authn bookkeeping)                                        | expected but hidden in a "resolver"; untested boundary                           |
| W11 | `transparent_refresh_access_token` rotation                                           | `authentication_base.rb:636-658`                                                                                                                              | token               | HTML request w/ refresh, no access cookie | **Yes**  | Yes       | No                                                             | expected lifecycle                                                               |
| W12 | auth token issue/rotate/revoke/session create                                         | `authentication_base.rb:396,461,1053,1135,1295,1455,1945,2076,2101,2441,2455,2516,2656`; `authentication_logout_current_session.rb:101,216,259`               | token/session       | login/refresh/logout                      | No       | n/a       | pipeline                                                       | expected                                                                         |
| W13 | OIDC callback provisioning                                                            | `oidc_callback.rb:24,256`; `oidc_rp_identity_provisioning.rb:42,61`                                                                                           | identity/token      | GET callback                              | **Yes**  | Yes       | protocol-gated                                                 | expected (protocol), document                                                    |
| W14 | identity ceremonies (passkey/TOTP/email/telephone/secret committers, social handlers) | `app/services/identity_*_ceremony_final_committer.rb`; `social_auth_{login_handler,signup_finalizer,link_handler}.rb`; `sign_secret_{issue,verify,revoke}.rb` | identity            | POST ceremonies                           | No       | No        | controller/policy                                              | expected                                                                         |
| W15 | org lifecycle                                                                         | `org_operator_lifecycle_invitation_acceptance.rb:71,112`; `org_operator_lifecycle_execute.rb:21`                                                              | organization        | POST                                      | No       | No        | service-level                                                  | expected                                                                         |
| W16 | `RestrictedSessionGuard` writing switch                                               | `restricted_session_guard.rb:61`                                                                                                                              | session             | before_action guard                       | possible | No        | n/a                                                            | **suspicious** — verify whether it writes or only opens the role                 |
| W17 | codec decode acquiring `role: :writing`                                               | `security_jwt_auth_access_token_codec.rb:240`                                                                                                                 | token lookup        | every decode                              | Yes      | Yes       | n/a                                                            | suspicious (read on writing conn defeats replica routing; audit intent)          |
| W18 | `dpop_proof_state_purge_job.rb:30`                                                    | job                                                                                                                                                           | token hygiene       | scheduled                                 | n/a      | n/a       | n/a                                                            | expected                                                                         |

# Concern Boundary Findings

- **Misnamed RW concerns**: `PreferenceBase`, `PreferenceGlobal`, `PreferenceCore`,
  `PreferenceTransport` all write DB (evidence in matrix). Write methods are `private` (good) but
  any controller inheriting a surface `ApplicationController` gets the full lifecycle.
- **Broad includes**: `Base::App::ApplicationController` includes `PreferenceGlobal` +
  `PreferenceAdoption` + `AuthenticationClient` (`base/app/application_controller.rb:7-32`); every
  descendant — including `AUTHENTICATION_MODE = :open` controllers — is RW on GET.
- **Callback order**: writes (`set_preferences_cookie` :70) run **before** authentication resolution
  (`set_current_actor` :76). This is intentional and doc-locked (`actor_support.rb:242-252`,
  `controller_lifecycle_order_invariant_test.rb`) but means pre-auth writes are structural.
- **Public route RW risk**: `PreferencesBaseController` is `:open`
  (`preferences_base_controller.rb:10`) with the GET authz bypass (`:15,24-26`) → confirmed
  public-GET RW.
- **GET/HEAD write risk**: W1-W5, W10, W11, W13 above. Only W5/W11 (and arguably W1/W2) are
  doc-sanctioned; none has a "this is the exhaustive set" allowlist or invariant test.
- **Clean concerns**: `ActorSupport`, `PreferenceLocalization`, `RateLimit` are RO [FACT].
- Escape hatches: theme/cookie/DBSC edge endpoints skip the lifecycle explicitly via
  `skip_before_action` lists (`base/app/web/v0/themes_controller.rb:17-19`,
  `base/app/edge/v0/{cookies,dbsc}_controller.rb`) — pattern exists but is per-controller and
  unauditable at scale.

# app/com/org Separation Findings

- **Correct behavior**: per-surface abstract record bases
  (`AppPrincipalRecord`/`ComPrincipalRecord`/`OrgPrincipalRecord`, `AvatarRecord`);
  per-resource-type JWT audiences (`authentication_jwt_configuration.rb:26-37`); host-scoped
  preference JWT audience (`security_jwt_preference_token_codec.rb:142-163`); `__Host-` cookies with
  host isolation; registry raises `KeyError` on unknown surface segment
  (`preference_class_registry.rb:241-243`) rather than silently defaulting.
- **Violations**: none confirmed as cross-surface data flow.
- **Brittle inference** [FACT]: preference class from `controller_path.split("/")[1]`
  (`preference_class_registry.rb:246-249`) vs surface from host label with **default `:com`**
  (`core_surface.rb:6-7`) vs route authority from `split("/").first` defaulting to `"sign"`
  (`preference_core.rb:834-835`). Three inference points that can diverge under namespace migration
  (exactly the sign→auth/base migration in flight). No test locks host-surface == path-surface.
- **Com/Customer gaps** [FACT]:
  - Adoption excludes Com (`preference_adoption.rb:47-50`); mapping helpers return nil for Com
    (`:317-333` region per inventory). Docs say Com sync goes through `ResourceSync`/`Core` instead
    (`plans/backlog/legacy-preference-models-retirement-plan.md:80-84`) — so this is **documented
    asymmetry**, but rotation-time sync (W2 → `adopt_rotated_preference!`) silently no-ops for Com,
    and nothing tests the Com path end-to-end.
  - `preference_binding_method_class`/`preference_dbsc_status_class` map
    `ClientToken`/`OperatorToken` but omit `VisitorToken` (`preference_base.rb:557-579`) —
    **undocumented gap**.
- **Cookie/host/audience issues**: current cookie names ignore the surface argument
  (`preference_cookie_name.rb:9-22`, `_ = surface`) — doc-compliant (role names, host isolation),
  but it makes host isolation the single separation control; `CoreSurface` default `:com` means an
  unrecognized host silently behaves as com (no-silent-fallback concern).

# DB SSOT -> JWT Projection Lifecycle Findings

Preference lifecycle (App/User shown; Org/Staff identical; Com/Visitor deviations noted):

| Event                                          | SSOT row                                | Token effect                                       | Evidence                                                      | Risk                   |
| ---------------------------------------------- | --------------------------------------- | -------------------------------------------------- | ------------------------------------------------------------- | ---------------------- |
| Guest first request                            | new `AppPreference` (+children)         | preference access+refresh+DBSC cookies issued      | W1                                                            | row amplification (S1) |
| Subsequent guest request (valid access cookie) | unchanged                               | none                                               | `preference_transport.rb:16-32` guard                         | ok                     |
| Refresh-cookie-only request                    | same row, `rotate!`                     | reissue access, rotate refresh                     | W2                                                            | ok                     |
| Login                                          | shared + local (`user_preference`) dual | adoption sync by recency; JWT reissued from DB     | W8; `adr/preference-relogin-reconciliation-record-recency.md` | **Com: no-op**         |
| Preference update                              | DB dual-write, jti rotated              | new preference JWT from live row                   | W6; `preference_access_token_issuer.rb:9-20,45-49`            | ok                     |
| DB jti rotated elsewhere / row stale           | DB wins                                 | stale cookie deleted on next read                  | `preference_access_token_transport.rb:47-70`                  | ok (pull-based)        |
| Reset                                          | retire + destroy mirror                 | reissue                                            | W7                                                            | ok                     |
| Auth transparent refresh                       | token_record rotated                    | auth JWT rebuilt from DB; preferences re-installed | `authentication_jwt_tokens.rb:85-113` (`:110-112`)            | ok                     |

Identity lifecycle: credential create/revoke, deactivation, admin lock are DB rows checked per
request by the resolver (jti binding `:162-168`, lock staleness `:278-281`); withdrawn-refresh is
invariant-tested (`test/security/invariants/withdrawn_resource_refresh_invariant_test.rb`). No
identity claims to go stale. **Protected.**

Avatar lifecycle: switch/assignment stored on the session row (DB); disable/delete enforcement
depends on policies reading DB at each boundary — no claim staleness possible, but no test asserts a
disabled avatar's selection is rejected. **Partially verified.**

Organization/group lifecycle: no claims; membership changes take effect only where policies actually
query DB. Given `has_role?` is undefined, the generic role helpers cannot be the enforcement point;
enforcement is per-feature. **Weakest domain — matches docs' own assessment**
(`database-authority-placement.md:113-122`).

# Security Findings

**S1 — Unauthenticated write-on-GET preference bootstrap is unbounded by tests. High. Present.**
Evidence: W1/W2; chain wired at `base/{app,com,org}/application_controller.rb` (:70 for app).
Failure scenario: cookie-less crawler / cookie-stripping client creates a preference row + 12
children + audit rows per request; storage/audit amplification and write-DB pressure; also the doc
allowlist (`preference.md:291-304`) is not machine-enforced. Minimal test: request spec asserting a
GET to a content route with no cookies creates at most one preference record set, and a repeat
request with returned cookies creates zero. Fix direction: keep lifecycle but add creation
throttle/idempotency assertion + RO-invariant tests (Slice 1/6).

**S2 — GET preference `edit` writes with authorization explicitly skipped. High. Present.**
Evidence: `preferences_base_controller.rb:15,24-26` + W3/W4. Failure scenario: any visitor GET
`edit` on `:open` preference screens triggers child-row creation with no `authorize!`; policy
regressions on write endpoints are masked because GET already materialized state. Minimal test: GET
edit as guest asserts no `create!` beyond documented bootstrap; authz check invoked for the records
touched. Fix: make GET-edit read-only (render from JWT/DB without `load_or_create`), or extend
`authorize_preference_write!` to lifecycle writes (Slice 3).

**S3 — Com/Visitor sync asymmetry + `VisitorToken` omission. High. Present.** Evidence:
`preference_adoption.rb:47-50`; `preference_base.rb:557-579`. Failure: com users' local/shared
preferences drift silently on rotation; DBSC/binding lookups for VisitorToken raise or misroute.
Minimal test: com login + rotation round-trip asserting mirror sync (expected to fail today). Fix:
implement Com adoption or explicitly disable with a raising guard + doc (Slice 5).

**S4 — Divergent surface inference (host vs path position, silent `:com` default). Medium.
Present.** Evidence: `core_surface.rb:6-30`; `preference_class_registry.rb:246-249`;
`preference_core.rb:834-835`. Failure: a namespace move (sign→auth/base, exactly in flight) makes
path-derived preference class disagree with host-derived cookie surface → wrong preference class or
KeyError in production. Minimal test: invariant asserting for every routed controller that registry
surface == host surface for its constraints. Fix: single `SurfaceResolver` contract (Slice 5).

**S5 — Authorization scopes are JWT-only and DB-unanchored; role helpers dead. Medium (High if any
endpoint relies on `operator?`-family helpers). Present.** Evidence:
`authorization_token_claims.rb:88-100`; `application_policy.rb:75-128,161-196`; `has_role?`
undefined. Failure: `scp` grants `write:org` to any operator for the token TTL regardless of DB
membership; org membership removal doesn't shrink scope until reissue; generic role predicates
silently raise or are unreachable. Minimal test: policy test calling `manager?` (expects
NoMethodError today); token test asserting scopes for a membership-revoked operator. Fix: decide
scope grounding (DB-role projection with `sid`-anchored recheck, or drop scp-based authz) in Slice
4; remove dead helpers.

**S6 — Read paths with hidden writes / writing-connection reads. Medium. Present.** Evidence: W10
(`update_columns` on GET), W16 (`restricted_session_guard.rb:61`), W17 (decode on writing conn,
`security_jwt_auth_access_token_codec.rb:240`). Failure: replica routing defeated; write outages
break reads; invisible write surface for future regressions. Minimal test: no-write-on-GET invariant
excluding the allowlist. Fix: move touch to explicit lifecycle, audit W16/W17 (Slice 3/6).

**S7 — Doc/code contradictions (`act` claim; stale `prf` claim in capstone plan;
preference-authority owner drift; repurposed ADR). Medium. Present.** Evidence:
`authorization_token_claims.rb:22` vs `adr/oidc-claims-decision.md:22`;
`plans/objective-perform-an-elegant-cake.md` C5 vs verified code; §11 of doc inventory. Failure:
future agents implement against stale authority docs. Fix: Slice 0 doc reconciliation.

**S8 — Stale-JWT-after-revocation. Low (mitigated). Absent as exploitable.** Per-request DB checks
(jti/DPoP/lock) + refresh family revoke (`acme_refresh_token_issuer.rb:99-124`) + withdrawn-refresh
invariant tests cover this. Residual: within-TTL `acr`/`scp` staleness (S5).

Risks assessed absent: cross-surface token acceptance (audience+host checks), refresh copying old
claims (disproved), JWT carrying sensitive mutable data (none found).

# Test Gap List

Existing relevant tests:
`test/security/invariants/{controller_lifecycle_order,refresh_token_reuse,withdrawn_resource_refresh,withdrawal_gate,cookie_security,forbidden_patterns}_invariant_test.rb`,
`test/unit/actor/*`, `test/services/preference_token_test.rb`,
`test/policies/preference_write_policy_test.rb`, `test/unit/core/surface_test.rb`.

Missing (proposed):

1. `test/security/invariants/read_only_route_write_invariant_test.rb` —
   `ReadOnlyRouteWriteInvariantTest#test_get_requests_perform_no_db_writes_outside_allowlist`:
   subscribe to `sql.active_record` (INSERT/UPDATE/DELETE) during GETs to representative base/app
   routes; assert only allowlisted statements (preference bootstrap, session touch). **Fails today**
   if allowlist starts empty — that's the point; seed allowlist from the matrix.
2. `test/controllers/base/com/preference/adoption_flow_test.rb` —
   `test_com_login_syncs_visitor_preference_mirror`: com login with newer shared row asserts
   `VisitorPreference` updated. **Fails today** (S3).
3. `test/unit/preference_class_registry_surface_alignment_test.rb` —
   `test_registry_surface_matches_host_surface_for_all_routed_controllers`: iterate routes, assert
   path-derived prefix corresponds to host constraint surface. Guards S4.
4. `test/policies/application_policy_role_helpers_test.rb` —
   `test_role_helpers_are_backed_by_a_real_role_source`: call `manager?` with an operator; documents
   S5 (expects NoMethodError today).
5. `test/security/invariants/preference_get_edit_readonly_test.rb` —
   `test_get_edit_does_not_create_child_records_beyond_bootstrap` (S2; fails today).
6. `test/unit/preference_binding_method_visitor_token_test.rb` —
   `test_visitor_token_has_binding_and_dbsc_classes` (fails today per `preference_base.rb:557-579`).
7. `test/security/invariants/raw_token_claims_access_invariant_test.rb` — static grep-style
   invariant (like `forbidden_patterns_invariant_test.rb`) forbidding `Actor.authz.token_claims` /
   `access_claims` dereference outside `app/policies/application_policy.rb` and resolver files.
8. `test/controllers/.../guest_preference_bootstrap_idempotency_test.rb` — repeat GET with cookies
   creates zero rows (S1).

# Docs Gap List

1. `plans/objective-perform-an-elegant-cake.md` — C5/§2.1: mark the "`prf` still embedded" claim as
   resolved/stale (code verified 2026-07-02).
2. `adr/oidc-claims-decision.md:22` — clarify `act` scope: "not used **in ID tokens**" vs
   access-token `act` (or remove `act` from access tokens; decide in Slice 4).
3. `docs/architecture/preference.md:356-360` — align cookie naming with
   `docs/security/cookie-domain-scope.md` (role names current, surface names legacy).
4. `docs/identity/authority-boundary.md` + docs citing `adr/identity-authority-boundary.md` for the
   old authority matrix — fix stale citations; add a pointer note in the ADR about its repurposing.
5. New: `docs/security/db-write-allowlist.md` — the machine-checked allowlist (Slice 0/6
   deliverable) enumerating W1-W18-style sanctioned writes incl. GET lifecycle writes.
6. `docs/architecture/preference.md` — add explicit statement of Com/Visitor adoption status
   (currently only in `plans/backlog/legacy-preference-models-retirement-plan.md:80-84`).
7. `docs/architecture/controller-lifecycle.md` — document `touch_session_activity!` and
   `transparent_refresh_access_token` as sanctioned GET writes with their throttles.

# Remediation Strategy

- **Slice 0 — Contracts & docs** (no behavior change): write `docs/security/db-write-allowlist.md`;
  reconcile the 7 doc gaps; state claim schema (auth access: keep/drop `act`, `scp` grounding
  decision recorded as open until Slice 4); state surface-resolver contract; record Com/Visitor
  status.
- **Slice 1 — Characterization/invariant tests**: add tests 1, 3, 5, 6, 8 above (allowlist seeded to
  current behavior so suite is green), plus failing-marked-known tests 2, 4 as `# KNOWN GAP`
  non-placeholder assertions of current behavior (assert the _current_ no-op, referencing the
  backlog item) — no `skip`.
- **Slice 2 — Typed read hardening**: add `Actor.organization`/`Actor::Membership` snapshot
  (DB-resolved at boundary, per-feature opt-in); restrict raw-claims dereference via invariant test
  7; delete dead `access_token_payload` probe (`actor_support.rb:132`) or implement it — currently
  dead code.
- **Slice 3 — Concern RO/RW split**: extract `PreferenceSessionLifecycle` (W1/W2/W5) and
  `PreferenceCommand` (W6/W7) out of `PreferenceBase`/`PreferenceCore`; make GET `edit` read-only
  (drop `load_or_create` on GET, render defaults from JWT + option tables); move
  `touch_session_activity!` into an explicit `AuthenticationSessionLifecycle`; audit
  `RestrictedSessionGuard`/codec writing-connection (W16/W17).
- **Slice 4 — JWT projection hardening**: decide `scp` grounding (recommend: keep type-derived
  scopes but document them as transport-coarse, and require DB policy checks for org-sensitive
  actions; remove dead `has_role?` helpers); decide `act` fate; keep no-avatar/no-org claims
  (confirmed intentional).
- **Slice 5 — Surface hardening**: introduce `SurfaceResolver` single contract (host-authoritative,
  path-verified, raise on mismatch — no `:com` silent default in Rails runtime); implement or
  explicitly disable Com adoption (raising guard); add `VisitorToken` classes to binding/DBSC maps
  or raise loudly.
- **Slice 6 — CI guardrails**: promote test 1's SQL-subscription allowlist into a shared helper; add
  grep-invariant for `connected_to(role: :writing)` outside allowlisted files (extend
  `forbidden_patterns_invariant_test.rb`); CI command `bin/rails test test/security/invariants`.
- **Slice 7 — Cleanup**: remove empty `app/controllers/sign/**` dirs, `"sign"` default in
  `preference_route_authority` (raise instead), legacy cookie-name read/delete compat after expiry
  window, stale acme URL-helper prefixes as routes allow.

# Concrete Implementation Plan

PR sequence (each independently revertable; risk L/M/H; every PR includes its tests):

1. **PR1 (Slice 0)** — docs only. Files: `docs/security/db-write-allowlist.md` (new),
   `docs/architecture/preference.md`, `docs/architecture/controller-lifecycle.md`,
   `adr/oidc-claims-decision.md`, `plans/objective-perform-an-elegant-cake.md`,
   `docs/identity/authority-boundary.md`. Risk L. Rollback: revert.
2. **PR2 (Slice 1)** — tests only: the 8 files in Test Gap List (2 and 4 as current-behavior
   characterizations). Expected behavior change: none. Risk L. Dependency: PR1 allowlist content.
3. **PR3 (Slice 3a)** — GET-edit read-only: change `PreferenceCore#set_*_preferences_edit` to a
   read/build (not create) path on GET; move creation into the update/command path; flip test 5 to
   the strict assertion. Files: `app/controllers/concerns/preference_core.rb` (`:16-257`),
   `preference_base.rb` (`load_or_create_preference_child` split),
   `base/{app,com,org}/preferences_base_controller.rb`. Risk M (UI defaults rendering). Rollback:
   revert; behavior returns to create-on-GET.
4. **PR4 (Slice 3b)** — extract `PreferenceSessionLifecycle` + `AuthenticationSessionLifecycle`
   concerns; controller includes updated in the 3 surface ApplicationControllers; callback order
   preserved and asserted in `controller_lifecycle_order_invariant_test.rb`. Files: new
   `app/controllers/concerns/preference_session_lifecycle.rb`,
   `authentication_session_lifecycle.rb`; edits to `preference_transport.rb`,
   `preference_refresh_token_transport.rb`, `authentication_current_resource_resolver.rb` (move
   `touch_session_activity!` call site), surface application controllers. Risk M-H (lifecycle).
   Feature flag not needed (pure extraction); deploy behind full invariant suite.
5. **PR5 (Slice 5a)** — `SurfaceResolver` value object (`app/values/surface_resolver.rb`,
   pseudocode: `SurfaceResolver.resolve(request:, controller_path:) -> Surface` raising
   `SurfaceMismatchError`); `PreferenceClassRegistry.for_controller_path` and `CoreSurface.current`
   route through it; remove silent `:com` default in Rails runtime paths (keep for
   mailers/host-context where documented). Risk M. Rollback: revert; old inference intact behind
   resolver.
6. **PR6 (Slice 5b)** — Com/Visitor decision. Option A: extend `PreferenceAdoption`
   (`adoptable_preference_class?` += ComPreference;
   `find_resource_preference`/`resource_preference_mapping` add Visitor branch; add `VisitorToken`
   to `preference_binding_method_class`/`preference_dbsc_status_class` maps in
   `preference_base.rb:557-579`). Option B: raising guard + doc. Requires product decision (Open
   Questions Q1). Risk M. Tests 2/6 flip to strict.
7. **PR7 (Slice 4)** — remove dead role helpers from `application_policy.rb:161-196` (or back them
   with a real role source); decide `act`; docs updated. Risk M (must grep all policy subclass usage
   first).
8. **PR8 (Slice 6)** — extend `test/security/invariants/forbidden_patterns_invariant_test.rb` with
   writing-connection allowlist; CI wiring. Risk L.
9. **PR9 (Slice 7)** — legacy cleanup (empty sign dirs, `"sign"` default → raise, legacy cookie
   compat removal per `cookie-domain-scope.md` window). Risk L-M; last.

Observability: preference lifecycle writes already audit via `create_audit_log`; add a structured
log event when `SurfaceResolver` raises and when Com adoption no-ops (until PR6).

# File-by-File Change Plan

| File                                                                                        | Change                                                                                                                                                 |
| ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `app/controllers/concerns/preference_core.rb`                                               | split edit-entry into read-only builders; keep `*_update`/reset in a `PreferenceCommand`-tagged section                                                |
| `app/controllers/concerns/preference_base.rb`                                               | split `load_or_create_preference_child` into `find_preference_child` (RO) + `create_preference_child!` (RW); add VisitorToken to `:557-579` maps (PR6) |
| `app/controllers/concerns/preference_transport.rb`, `preference_refresh_token_transport.rb` | move into `PreferenceSessionLifecycle`; no logic change                                                                                                |
| `app/controllers/concerns/preference_adoption.rb`                                           | Com branch or raising guard (`:47-50,60-92`)                                                                                                           |
| `app/controllers/concerns/authentication_current_resource_resolver.rb`                      | relocate `touch_session_activity!` invocation to lifecycle concern                                                                                     |
| `app/controllers/concerns/preference_class_registry.rb`                                     | route `for_controller_path` through `SurfaceResolver`                                                                                                  |
| `app/values/core_surface.rb`                                                                | deprecate silent `:com` default for Rails runtime callers                                                                                              |
| `app/values/surface_resolver.rb` (new)                                                      | host-authoritative, path-verified resolver                                                                                                             |
| `app/policies/application_policy.rb`                                                        | remove/back `:161-196` role helpers; document raw-claims boundary                                                                                      |
| `base/{app,com,org}/application_controller.rb`, `preferences_base_controller.rb`            | include updates; GET-edit read-only                                                                                                                    |
| `test/security/invariants/*`, new test files                                                | per Test Gap List                                                                                                                                      |
| docs per Docs Gap List                                                                      | reconciliation + allowlist                                                                                                                             |

# Proposed Target Architecture

**JWT claim policy**: preference → preference JWT only (DB projection, jti-versioned,
pull-invalidated) — unchanged; identity → DB-only, `sub`/`acr`/`amr`/`sid` transport identifiers
only, per-request DB recheck — unchanged; avatar → DB-only (session-row selection) — unchanged,
documented; organization/group → DB-only; `scp` documented as coarse transport hint, never sole
authority for org-sensitive actions; `act` → keep in access token, ADR clarified (or removed — Q2).

**Reader policy**: `Actor.*` snapshots are the only sanctioned readers; raw
`token_claims`/`access_claims` dereference allowed only in `ApplicationPolicy` + resolver/codec
files, enforced by grep-invariant; org context via new `Actor.organization` DB-resolved snapshot
where needed; guests get `Actor::Preference::NULL` + overlay (unchanged).

**Write policy**: allowlist file enumerating lifecycle writes (preference
bootstrap/rotation/edit-entry refresh, session touch, transparent refresh, OIDC callbacks) and
command writes (update/reset/ceremonies/org lifecycle); everything else forbidden and CI-checked;
GET writes only from the lifecycle list.

**Concern layout**: RO — `ActorSupport`, `PreferenceLocalization`, `Preference` read builders;
lifecycle RW — `PreferenceSessionLifecycle`, `AuthenticationSessionLifecycle`, `PreferenceAdoption`;
command RW — `PreferenceCommand` (updates/resets), ceremony services. Callback order unchanged and
invariant-locked.

**Surface separation**: `SurfaceResolver` single contract; host authoritative, path verified,
mismatch raises; Com/Visitor either fully symmetric or explicitly disabled with raising guards.

# Proposed Test Plan

- Add: Test Gap List 1-8. Expected to fail now: 2 (Com sync), 4 (role helpers), 5 (GET edit writes),
  6 (VisitorToken maps) — added first as characterizations of current behavior, flipped per-PR.
- Pass after PR3: 5 strict. After PR6: 2, 6 strict. After PR7: 4 (helpers removed → test asserts
  absence). Invariants 1, 3, 7, 8 green from PR2 with seeded allowlist, tightening in PR4/PR5/PR8.
- Commands: `bin/rails test test/security/invariants`, `bin/rails test test/policies`,
  `bin/rails test test/unit/actor test/unit/core`, full `bin/rails test` before each merge. Key
  greps used: `rg -n 'connected_to\(role: :writing\)' app lib`,
  `rg -n 'JWT\.(encode|decode)' app lib`, `rg -n 'token_claims|access_claims' app --type ruby`,
  `rg -n 'controller_path\.split' app`, `bin/rails routes | rg 'preference'`.

# Migration / Compatibility Plan

- No schema migrations required for Slices 0-6. PR6 Option A writes only through existing tables.
- Compatibility risks: PR3 changes what a guest sees on first GET `edit` (defaults now rendered,
  persisted only on save) — verify UI parity; PR5 turns silent `:com` fallback into an error — audit
  all hosts (net/dev bare surfaces) before enabling raise, ship with log-only mode first (config
  flag `SURFACE_RESOLVER_STRICT`, ENV-fetched per no-silent-fallback rule); PR9 cookie-compat
  removal must respect the documented legacy read/delete window.
- Deployment order = PR order; each PR independently revertable; no feature flags except
  `SURFACE_RESOLVER_STRICT` (temporary, removed in PR9).
- Rollback: pure reverts; PR4 (lifecycle extraction) is the riskiest — keep it mechanically pure
  (move code, no logic edits) so revert is clean.

# Open Questions

1. **Com/Visitor adoption**: should com participate in login/rotation preference sync symmetrically
   (PR6 Option A), or is com intentionally sync-less until the B2 schema decision
   (`adr/preference-soft-bubble-doctrine.md:188-198`)? Product/architecture decision.
2. **`act` claim in access tokens**: keep (and amend `adr/oidc-claims-decision.md`) or remove
   (breaking for any RS parsing it)? Security/architecture decision.
3. **`scp` grounding**: accept type-derived coarse scopes permanently (documenting that
   org-sensitive authorization must always hit DB), or project DB roles into `scp` with sid-anchored
   recheck? Security decision — affects Slice 4 scope.
4. **Guest preference bootstrap on all GETs**: keep eager creation (current, doc-sanctioned) vs
   defer row creation to first explicit preference interaction (reduces S1 amplification but changes
   cookie-consent UX)? Product decision.
