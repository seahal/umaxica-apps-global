# OAuth 2.1 / OIDC Grill Me Report

> READ-ONLY adversarial audit of Project Umaxica. No files modified, no migrations, no commits.
> Evidence cited as `path:line`. Findings verified directly where marked **[verified]**; remaining
> findings rest on Explore-agent evidence corroborated against the same files.

## Context

This audit was requested to determine what is still missing before the OAuth 2.1 layer can be called
complete. The implementation is more mature than a greenfield repo: PKCE/S256, one-time
authorization codes, exact redirect-URI matching, atomic refresh rotation, DPoP at the Acme token
endpoint, and the OIDC `/userinfo` resource server are all present and largely correct. The audit
therefore focuses on the _seams_ — the Palm native resource server, DPoP end-to-end consistency,
route drift, and the negative-test surface — because that is where the protocol guarantees actually
break.

---

## Executive Verdict

### NOT READY

The disqualifier is **resource-server validation**, which the grading rule treats as a hard gate.
`PalmAccessTokenAuthenticator` — the only bearer-token resource server outside OIDC — validates the
JWT signature/iss/aud/exp and the _resource_ row, but **never loads the token record and never
checks `token.active?`**. A logged-out, rotated, or revoked Palm access token remains fully usable
until its JWT `exp` (a window measured in minutes-to-an-hour). The sibling
`OidcAccessTokenAuthenticator` does this correctly, which proves the gap is an omission, not an
architectural choice. The same authenticator hard-codes the `Bearer` scheme and ignores `cnf.jkt`,
so any DPoP-bound Palm token is silently accepted as a plain Bearer token — a sender-constraint
downgrade.

Refresh rotation, by contrast, is **complete and safe** (atomic, locked, family-tracked,
replay-detecting), so the verdict rests squarely on resource-server validation plus the DPoP-at-RS
inconsistency.

---

## Top 10 Blockers

### B1 — Palm resource server ignores token revocation/session state

- **Severity:** Critical
- **Status:** Unsafe **[verified]**
- **Evidence:** `app/services/palm_access_token_authenticator.rb:22-47` — decodes JWT, checks
  `scope_allowed?`, `allowed_client_id?`, and `resource&.active?`, then returns success. There is
  **no** `ClientToken.find_by(oidc_sid:)` and **no** `token.active?` check. Contrast
  `app/services/oidc_access_token_authenticator.rb:36-39` (`find_token` → `token&.active?` →
  audience → jti).
- **Why it matters:** Logout, refresh rotation, credential change, and family revocation all mutate
  the token _record_, not the already-issued JWT. A resource server that never reads the record
  cannot honor any of them. RFC 6749 §5.2 / token revocation expects revocation to take effect for
  authorization, not "eventually, at TTL."
- **Required fix:** After decode, fetch the resource-type token by `sid`, verify `token.active?`,
  `oidc_jti` match, and audience binding — mirror `OidcAccessTokenAuthenticator`.
- **Required tests:** revoked Palm token rejected; rotated Palm token rejected; logged-out Palm
  token rejected; jti-mismatch rejected.

### B2 — Palm resource server does not enforce DPoP sender-constraint

- **Severity:** High
- **Status:** Unsafe / Partial **[verified]**
- **Evidence:** `app/services/palm_access_token_authenticator.rb:24` accepts only
  `authorization_scheme.casecmp?("Bearer")` and never reads `payload.dig("cnf","jkt")`. The Acme
  token endpoint _can_ mint DPoP-bound tokens (`cnf.jkt`) for any client including `app-ios-rp` /
  `app-android-rp`. `OidcAccessTokenAuthenticator#dpop_valid?` (`:63-79`) rejects a bound token
  presented as Bearer; Palm has no equivalent.
- **Why it matters:** If Palm tokens are (or become) DPoP-bound, the binding is unenforced at the
  one place it protects the API — a stolen token replays as Bearer. This is the "dangerously
  half-implemented DPoP" failure mode: bound at issuance, unverified at use.
- **Required fix:** Confirm whether Palm tokens are DPoP-bound. If yes (or ever), Palm RS must
  require the `DPoP` scheme + valid proof for `cnf.jkt` tokens and reject Bearer fallback. If Palm
  is intentionally Bearer-only forever, document that and ensure the token endpoint never binds
  `cnf.jkt` for Palm clients.
- **Required tests:** DPoP-bound Palm token presented as Bearer → rejected; valid DPoP proof →
  accepted; htm/htu/ath/jti-replay at Palm RS.

### B3 — No access-token revocation/denylist; revocation relies on RS cooperation

- **Severity:** High
- **Status:** Partial **[verified via B1 + rotation read]**
- **Evidence:** Revocation is enforced only by resource servers that re-read the token record
  (`oidc_access_token_authenticator.rb:37`). There is no shared denylist/introspection. Given B1,
  Palm does not cooperate, so the system-wide revocation guarantee is only as strong as the weakest
  RS.
- **Why it matters:** "Short TTL is our revocation" is a defensible _documented_ tradeoff, but here
  it is undocumented and unevenly applied. Security relies on every future RS remembering to check
  `token.active?`.
- **Required fix:** Either (a) make `token.active?` a mandatory, shared step in a single bearer-auth
  primitive every RS must call, or (b) document the short-TTL revocation model in `docs/security/`
  and bound the access-token TTL accordingly.
- **Required tests:** invariant test asserting every bearer authenticator rejects an inactive token.

### B4 — DPoP at resource server is stateless (no per-request jti replay rejection)

- **Severity:** Medium
- **Status:** Partial (documented tradeoff)
- **Evidence:** `app/services/oidc_access_token_authenticator.rb` → `DpopRequestVerifier` runs with
  `record_jti: false`; jti replay is recorded only at the token endpoint
  (`oidc_token_exchange_service.rb` DPoP path). Mitigated by `ath` binding + short `iat` window.
- **Why it matters:** Within the `iat` leeway, a captured proof+token can be replayed against the
  API. `ath` binding reduces but does not eliminate this.
- **Required fix:** Accept the tradeoff explicitly in `docs/security/` with the leeway value, or add
  a bounded replay cache on the hot path.
- **Required tests:** DPoP proof replay within leeway window (expected behavior asserted either
  way).

### B5 — Stale split Palm callback routes contradict the "unified callback" decision

- **Severity:** Medium
- **Status:** Stale **[verified]**
- **Evidence:** `config/routes/palm.rb:47-58` routes **both** `resource :callback`
  (`/oauth/callback`) **and** `namespace :callback` → `ios` + `android` (`/oauth/callback/ios`,
  `/oauth/callback/android`). All three are plain-text stubs. Prior decision prefers a single
  `/oauth/callback`.
- **Why it matters:** Drift between stated direction and routed surface; future implementers may
  wire real behavior into the wrong (split) controllers. Low _runtime_ risk today (stubs), real
  _maintenance/decision_ risk.
- **Required fix:** Decide unified vs split, delete the losing routes/controllers, leave a comment
  citing the decision.
- **Required tests:** request spec asserting the removed paths return 404.

### B6 — Native claimed-HTTPS verification files absent (assetlinks / AASA)

- **Severity:** Medium
- **Status:** Missing **[agent-verified: zero hits]**
- **Evidence:** No `public/.well-known/assetlinks.json`, no `apple-app-site-association`, no route
  serving them (searched `app config public`, 0 results); `config/routes/palm.rb` serves neither.
- **Why it matters:** Android App Links / iOS Universal Links require these to make the HTTPS
  callback a _claimed_ scheme. Without them the native callback is not a verified deep link, which
  is the entire security premise of preferring claimed-HTTPS over custom schemes.
- **Required fix:** Define the serving plan (static under `public/.well-known/` or a Base/Help
  route) before native flow ships. Track the app fingerprints/team IDs.
- **Required tests:** request spec for `200` + correct `content-type` on each file.

### B7 — Missing negative tests for token/JWT validation invariants

- **Severity:** Medium
- **Status:** Missing **[agent-verified]**
- **Evidence:** `test/services/oidc/` covers many paths but lacks: unknown `client_id` at `/token`
  (only `/authorize` covered), wildcard redirect rejection, disallowed audience at token exchange,
  expired access token at `/userinfo`, wrong-issuer token, unsupported `alg` (non-ES384), missing
  `typ`, DPoP jti-replay integrated into exchange, and stale-route rejection.
- **Why it matters:** These are exactly the regressions that silently re-open after a refactor; the
  positive-path tests won't catch them.
- **Required fix / tests:** see **Test Gaps** below — add each as an explicit negative test.

### B8 — Subject claim is the internal DB id (`resource.id`), not an opaque identifier

- **Severity:** Low–Medium
- **Status:** Unclear / needs decision **[agent-reported]**
- **Evidence:** Agent reported `authorization_token_claims.rb` builds `sub` from `resource.id`,
  while `OidcSubject` elsewhere uses prefixed `public_id` (`vis_`/`opr_`/`cli_`). Confirm which
  `sub` actually ships in the access token vs id token.
- **Why it matters:** Raw sequential DB ids in a token claim are an enumeration hint and contradict
  "no internal database IDs unless deliberately safe." If `OidcSubject.for` (public_id) is the real
  `sub`, this is a false alarm — but the two code paths disagree and must be reconciled.
- **Required fix:** Verify and standardize on the prefixed public id for `sub` everywhere.
- **Required tests:** assert `sub` format in issued access + id tokens.

### B9 — Session cookie is `SameSite=Lax`; confirm auth authority is not carried there

- **Severity:** Low–Medium
- **Status:** Unclear (likely by design) **[verified]**
- **Evidence:** `config/initializers/session_store.rb:18` → `same_site: :lax`. Auth cookies use
  `:strict` (`app/controllers/concerns/authentication_cookie_service.rb`), and production defaults
  to `cookies_same_site_protection: :strict`.
- **Why it matters:** `Lax` is often _required_ so the Rails session survives the top-level redirect
  back from the IdP, so this is plausibly correct. It is only a problem if authentication/authority
  state rides the Lax session cookie rather than the Strict `__Host-` auth cookies.
- **Required fix:** Confirm the session cookie carries no auth authority; document the split.
- **Required tests:** request spec asserting protected actions require the Strict auth cookie, not
  the Lax session cookie.

### B10 — Orphaned/legacy SSO controllers under Acme

- **Severity:** Low
- **Status:** Stale **[agent-reported]**
- **Evidence:** `app/controllers/acme/{app,com,org}/sso/authorizations_controller.rb` exist on disk;
  agent reports they are not routed. `core/app/sso/authorizations_controller.rb` and
  `core/app/sso/logouts_controller.rb` also exist.
- **Why it matters:** Dead auth controllers are a footgun — a stray `routes` line re-arms them.
- **Required fix:** Confirm unrouted, then delete or document why they remain.
- **Required tests:** n/a (deletion) or route-absence spec.

---

## Boundary Violations

- **Acme = sole issuer:** Confirmed. `/authorize`, `/token`, `/userinfo`, `/jwks`, discovery live
  only under `acme/*/oauth` and `acme/*/well_known` (`config/routes/acme.rb`). Sign/Core/Palm expose
  no token-minting endpoints.
- **Sign is RP-only:** Sign exposes a _signing-credential_ JWKS
  (`sign/app/well_known/jwks_controller.rb`, namespace `SIGN_APP`) and backchannel-logout receivers,
  not IdP authority. No boundary violation, but the dual meaning of "JWKS" (Acme authority keys vs
  Sign signing keys) is a naming hazard worth a comment.
- **Core = BFF/RP:** Core has `/auth/callback` (RP) and a BFF refresh path, not OAuth issuance.
- **Palm = native API:** Palm controllers inherit `BareController` and skip sessions
  (`request.session_options[:skip] = true`), correctly cookie-free. The boundary problem is
  **B1/B2**: Palm's bearer validation is weaker than OIDC's, not that Palm oversteps authority.

No surface improperly _issues_ tokens. The violations are all about _validation strength_ at the
Palm edge.

---

## Route Drift

| Route                                   | Owner  | Controller/action                        | Intended                  | Verdict                           |
| --------------------------------------- | ------ | ---------------------------------------- | ------------------------- | --------------------------------- |
| `/oauth/callback` (Palm)                | Palm   | `palm/app/oauth/callbacks#show` (stub)   | unified native callback   | keep (preferred)                  |
| `/oauth/callback/ios`                   | Palm   | `palm/.../callback/ios#index` (stub)     | fold into unified         | **stale → delete (B5)**           |
| `/oauth/callback/android`               | Palm   | `palm/.../callback/android#index` (stub) | fold into unified         | **stale → delete (B5)**           |
| `acme/*/sso/authorizations`             | Acme   | on disk, unrouted                        | n/a                       | **legacy → confirm+delete (B10)** |
| `core/app/sso/{authorizations,logouts}` | Core   | present                                  | RP/BFF logout?            | confirm intent                    |
| `/.well-known/assetlinks.json`          | (none) | —                                        | serve for App Links       | **missing (B6)**                  |
| `apple-app-site-association`            | (none) | —                                        | serve for Universal Links | **missing (B6)**                  |

Acme authority routes (`/oauth/authorize`, `/oauth/token`, `/oauth/userinfo`, `/oauth/revoke`,
`/.well-known/openid-configuration`, JWKS) are present and not duplicated across surfaces.

---

## OAuth 2.1 Compliance Gaps

Strong on the authorization/token core (see False Positives). Open items:

- Audience/resource binding at token exchange is enforced via client registry, but **no negative
  test** proves a disallowed audience is rejected at `/token` (B7).
- `client_credentials` grant: token exchange accepts only `authorization_code`
  (`oidc_token_exchange_service.rb`), so confidential service-client flows are absent. Confirm this
  is intended (no machine-to-machine clients yet) rather than an oversight.
- Refresh-grant handling exists via rotation, but verify the `/token` endpoint dispatches
  `grant_type=refresh_token` through the rotation path with the same client-auth checks.

---

## JWT / JWKS / Resource Server Gaps

- **Access token profile:** JWS (ES384), `kid` present, `none` rejected, claims avoid email/phone.
  **Deviation:** `typ` is the custom `auth-access-token;<resource>` rather than IANA `at+jwt`
  (`authentication_jwt_configuration.rb:40-45`) — intentional but non-standard; document it so
  external resource servers don't expect `at+jwt`.
- **JWKS rotation:** active+grace coexistence, unknown `kid` rejected, unsupported `alg` rejected
  (`lib/jit_security_jwt_*`, `security_jwt_auth_access_token_codec.rb:315-318`). Solid.
- **RS validation:** OIDC RS is thorough; **Palm RS is the gap (B1/B2)**. `sub` provenance needs
  reconciliation (B8).

---

## DPoP Gaps

**Status: partially implemented — safe at the token endpoint, inconsistent at the resource server.**

- Token endpoint: proof validated (typ=dpop+jwt, ES256/384, htm/htu/iat/jti, signature), `cnf.jkt`
  bound, jti replay recorded, refresh carries `dpop_jkt` through rotation
  (`refresh_tokenable.rb:72`). Good.
- OIDC RS: enforces bound-token-must-use-DPoP, rejects Bearer fallback
  (`oidc_access_token_authenticator.rb:63-79`); stateless jti (B4).
- **Palm RS: does not implement DPoP at all (B2)** — the dangerous seam. DPoP is end-to-end for OIDC
  but not for Palm, violating the "must be end-to-end if adopted" rule.

---

## Palm Native Flow Gaps

- Cookie-free: correct (`BareController`, session skip).
- Public client: correct — `app-ios-rp`/`app-android-rp` use `token_endpoint_auth_method: "none"`;
  no client secret.
- PKCE/S256: mandatory at `/authorize` (`oidc_authorize_request_validator.rb:33-34`).
- Callback routes: **split stubs are stale (B5)**.
- Claimed-HTTPS: **assetlinks/AASA missing (B6)**.
- Refresh-to-native sender constraint: `dpop_jkt` is carried on rotation, but **Palm RS does not
  verify it (B2)**, so the constraint is not actually enforced for native traffic.

---

## Refresh Rotation / Replay Gaps

**Implemented and safe [verified].** `refresh_tokenable.rb:23-53`: rotation runs inside a
`transaction` with `lock_refresh_token_record_by_digest` (pessimistic lock), rejects already-rotated
tokens as `:replay` (`:36`), checks `currently_usable?` (`:37`), stores only digests (`:108-109`),
tracks `refresh_token_family_id` + `refresh_token_generation` (`:63-64`), and updates the device
session atomically. Family revocation on reuse exists (`authentication_base.rb` reuse handler per
agent evidence).

Gap: **no test simulates two concurrent refreshes of the same digest** asserting exactly one
`:rotated` and one `:replay`. The lock makes this correct in code; prove it. (A
`test/models/refresh_token_concurrency_test.rb` exists — confirm it actually races the same digest
rather than two distinct tokens.)

---

## Logout / Revocation Gaps

- Browser/refresh logout: revokes sessions and increments `session_version`
  (`authentication_logout_all_sessions.rb`); refresh family revocation present.
- **Bearer API (Palm) after logout: not enforced (B1)** — a revoked token still authorizes unsafe
  `POST/PATCH/DELETE` on Palm until JWT `exp`. This is the concrete realization of B1 and is the
  single most important thing to fix.
- No documented access-token denylist; short-TTL model is implicit (B3).

---

## Logging / Secret Exposure Gaps

- `config/initializers/filter_parameter_logging.rb` filters `token`, `jwt`, `authorization`, `code`,
  `authorization_code`, `secret`, `credential`, `otp`, `cookie`, `rt`, `pt`, etc. — broad and good.
- JWT/token services log structured event names + `host`, not token bodies
  (`security_jwt_auth_access_token_codec.rb:151+`). No raw tokens/codes/verifiers found in logs.
- **Observability gap:** anomaly reporting exists for JWT decode/expiry, but there is no explicit
  named event for **refresh-token reuse detected**, **invalid redirect attempt**, or **DPoP
  replay**. Rotation silently returns `:replay`; security ops should see a signal. (Low–Medium.)

---

## Test Gaps

Grouped by layer. "Missing" = no test found; add as explicit negative test.

**Service / token endpoint (`test/services/oidc/`)**

- Missing: unknown `client_id` at `/token` (only `/authorize` covered).
- Missing: disallowed audience/resource at token exchange.
- Missing: wildcard/glob redirect_uri rejection (regression guard for exact-match).
- Partial: DPoP jti-replay integrated into the exchange flow (guard tested in isolation only).

**JWT / RS (`test/services/...authenticator`)**

- Missing: expired access token rejected at `/userinfo`.
- Missing: wrong-issuer token rejected.
- Missing: unsupported `alg` (non-ES384) rejected.
- Missing: missing/incorrect `typ` rejected.
- **Missing (critical): Palm RS rejects revoked/rotated/logged-out token (B1).**
- **Missing (critical): Palm RS rejects DPoP-bound token presented as Bearer (B2).**

**Models / concurrency**

- Confirm/῾add: two concurrent refreshes of the same digest → one `:rotated`, one `:replay`.

**Integration / routes**

- Missing: stale Palm split-callback paths return 404 after cleanup (B5).
- Missing: assetlinks/AASA served with correct content-type (B6).
- Present (good): Palm-audience token rejected on Core
  (`test/integration/core_browser_api_boundary_test.rb:58-68`). Add the symmetric Core-token-on-Palm
  case.

---

## False Positives / Things That Look OK

- **Authorization endpoint:** `response_type=code` only, implicit/password absent, PKCE+S256
  required, plain PKCE rejected, `state`/`nonce` required
  (`oidc_authorize_request_validator.rb:30-40`). **[agent-verified, internally consistent]**
- **Authorization code:** 10s TTL, one-time `consume!`, bound to client_id/redirect_uri/
  code_challenge/scope/nonce/resource (`*_authorization_code.rb`).
- **Token exchange:** confidential-vs-public auth enforced, `code_verifier` S256 validated,
  redirect_uri/client_id match, consumed-code rejected, scope intersected with `allowed_scopes`
  (`oidc_token_exchange_service.rb`).
- **Redirect URIs:** exact `include?` match, no wildcards (`oidc_client_registry.rb`).
- **Refresh rotation:** atomic + locked + family-tracked + hashed **[verified]**.
- **OIDC separation:** id-token `typ=id-token+jwt`, `/userinfo` requires `openid` scope + valid
  access token, nonce end-to-end, claims minimized, prefixed subjects.
- **Cross-audience rejection:** Palm token rejected on Core (test present).
- **Param-filter logging:** comprehensive.

---

## Recommended Implementation Order

Security blockers first, cleanup last:

1. **B1** — Add token-record + `token.active?` validation to `PalmAccessTokenAuthenticator` (mirror
   `OidcAccessTokenAuthenticator`). Highest priority; this is the verdict's gate.
2. **B2** — Enforce DPoP sender-constraint at Palm RS (or prove/lock Palm to Bearer-only and stop
   binding `cnf.jkt` for Palm clients).
3. **B7 (the B1/B2 subset)** — Add the Palm RS negative tests alongside fixes 1–2.
4. **B3** — Centralize "reject inactive token" in one shared bearer primitive + add the invariant
   test; or document the short-TTL revocation model.
5. **B8** — Reconcile `sub` to the prefixed public id everywhere; assert in tests.
6. **B7 (remainder)** — wrong-issuer, unsupported-alg, missing-typ, disallowed-audience,
   expired-at-userinfo, unknown-client-at-token, DPoP-replay-in-exchange tests.
7. **B5** — Remove stale Palm split callbacks; add 404 specs.
8. **B6** — Plan + serve assetlinks/AASA before native ships.
9. **B4** — Document the stateless-DPoP-at-RS tradeoff (or add bounded replay cache).
10. **B9 / B10** — Confirm session-cookie has no auth authority; confirm + remove orphaned SSO
    controllers.

---

## Exact Next Prompt

> **Task: Close the Palm bearer-token resource-server validation gap (OAuth audit B1 + B2).** Scope
> strictly to `app/services/palm_access_token_authenticator.rb` and its tests. Do not touch OIDC,
> the token endpoint, routes, or other surfaces.
>
> 1. In `PalmAccessTokenAuthenticator#call`, after `AuthenticationTokenService.decode` succeeds and
>    before returning success, load the token record by `sid` for the `client` resource type
>    (`ClientToken.find_by(oidc_sid:)` via the `AppTicketRecord` reading role) and **reject unless
>    `token&.active?`**. Also verify `oidc_jti` matches the payload `jti` and the token's
>    `oidc_client_id` maps to the presented audience — mirror the checks in
>    `app/services/oidc_access_token_authenticator.rb:36-39,91-110`. Keep the existing
>    `resource.active?` / `admin_locked?` / `access_token_stale_for_administrative_lock?` checks.
> 2. Enforce DPoP: if the decoded payload carries `cnf.jkt`, require the `DPoP` authorization scheme
>    and a valid proof (reuse `DpopRequestVerifier`), and reject Bearer presentation of a bound
>    token. If product intent is that Palm is Bearer-only, instead add an assertion/guard that Palm
>    tokens are never minted with `cnf.jkt`, and document that decision in a comment — do not leave
>    binding unenforced.
> 3. Add Minitest coverage under `test/services/`:
>    - revoked `ClientToken` → `invalid_token`
>    - rotated/replaced token → `invalid_token`
>    - jti-mismatch → `invalid_token`
>    - DPoP-bound token presented as `Bearer` → `invalid_token` (or the Bearer-only guard test)
>    - happy path still succeeds.
> 4. Run `bin/rails test test/services` for the affected files and report results. Do not modify
>    migrations, routes, or unrelated controllers. Do not commit.
