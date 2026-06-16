# OAuth 2.1 Grill-Me Review — Acme Authorization Server & Resource-Server Boundary

> Documentation-backed security/architecture review. **No files were modified.** This is a read-only
> assessment against OAuth 2.1 draft, RFC 9700 (Security BCP), RFC 8252 (Native Apps), RFC 9449
> (DPoP), and RFC 9728 (Protected Resource Metadata). Strict by design — inconsistencies are
> surfaced over politeness.

## Context

Acme is the sole Authorization Server / OpenID Provider for a multi-surface Rails app (`app`/`org`/
`com` tenants × `Acme`/`Sign`/`Core`/`Base`/`Palm` surfaces). OAuth/OIDC is **hand-rolled** (gems:
`jwt`, `omniauth*`; **no Doorkeeper/rodauth-oauth**). The question this review answers: _is the
implementation ready for OAuth 2.1-style API authorization?_ The fundamentals are strong; the gaps
are (1) refresh handled out-of-band, (2) unconstrained scope minting, (3) bearer-only native client,
(4) token-endpoint auth method not pinned. None are remote-exploitable P0s, but several block a
clean OAuth 2.1 conformance claim.

---

## A. Verdict

**Conditionally ready for first-party OIDC login + API access. NOT yet ready to be claimed as a
general-purpose OAuth 2.1 API authorization server.**

What is genuinely strong (verified in source):

- Authorization Code + **PKCE is mandatory for every client**, `S256` only, `plain` rejected at both
  the model layer and the authorize validator.
- `response_type=code` only; implicit (`token`) and ROPC (`password`) are **structurally
  impossible** (the authorize validator hard-rejects non-`code`; the token service hard-rejects
  non-`authorization_code`).
- Authorization codes: one-time-use (`consume!` + `consumed_at`), **10-second TTL**, row-locked,
  redirect_uri + client_id rebinding on redemption.
- Exact-match redirect URI validation — no wildcard/prefix logic exists.
- Access-token validation is rigorous: single-alg allowlist `["ES384"]`, `verify_iss/aud/exp/iat`,
  required claims `iss aud typ exp sub sid act jti acr`, and a **`typ` header+payload match that
  blocks ID-token-as-bearer confusion**.
- Refresh tokens are digest-stored, rotated, family-tracked, with **reuse detection → family-wide
  revocation** and a risk signal.
- DPoP infrastructure exists end-to-end (proof validator, JTI replay store, `cnf.jkt` binding,
  `DPoP-Nonce`).

What blocks an OAuth 2.1 readiness claim (details in L):

1. **Refresh is not an OAuth grant.** `/oauth/token` accepts `authorization_code` only. Refresh
   tokens are issued in the token response but can only be redeemed via a separate, undiscovered,
   cookie-oriented first-party endpoint. A conformant OAuth client cannot refresh.
2. **No per-client scope allowlist.** Requested scope is minted verbatim into the access token; the
   AS never checks a client is _entitled_ to a scope. Privilege is governed entirely by what each
   resource server happens to check.
3. **Palm (native public client) is bearer-only.** The Palm RS explicitly rejects DPoP — the one
   client class where RFC 9700 most wants sender-constrained tokens.
4. **Token-endpoint auth method is not pinned to the client's registered method** — a
   `private_key_jwt` client can fall through to `client_secret_post` if a secret exists.

---

## B. Current OAuth Route & Controller Inventory

Routes are defined per surface in `config/routes/acme.rb` (app/com/org blocks). Provider endpoints:

| Method   | Path                                     | Controller                                                  | Auth mode         |
| -------- | ---------------------------------------- | ----------------------------------------------------------- | ----------------- |
| GET      | `/oauth/authorize`                       | `Acme::{App,Com,Org}::Oauth::AuthorizationsController#show` | `:open` (session) |
| POST     | `/oauth/token`                           | `…::Oauth::TokensController#create` (rate-limited 10/min)   | `:open`           |
| GET      | `/oauth/userinfo`                        | `…::Oauth::UserinfosController#show`                        | `:bare`, bearer   |
| POST     | `/oauth/revoke`                          | `…::Oauth::RevocationsController#create`                    | `:bare`           |
| GET      | `/oauth/jwks` + `/.well-known/jwks.json` | `…::Oauth::JwksController` / `…::WellKnown::JwksController` | `:bare`, public   |
| GET      | `/.well-known/openid-configuration`      | `…::WellKnown::DiscoveriesController#show`                  | `:bare`, public   |
| GET/POST | `/oidc/logout`                           | `…::Oidc::LogoutsController`                                | `:open`           |

Out-of-band token lifecycle (NOT OAuth protocol endpoints, but security-relevant):

- `POST …/edge/v0/token/refresh` → `Acme::{App,Com,Org}::Edge::V0::Token::RefreshesController`
  (`refreshes_controller_base.rb`) — reads `params[:refresh_token]` **or** the `REFRESH_COOKIE_KEY`
  cookie, delegates to `AcmeRefreshTokenService`.
- `authentication_base.rb:536` `AcmeRefreshTokenService.call(refresh_token:)` — session/login
  refresh.
- Palm: `GET /oauth/callback`, `/oauth/callback/ios`, `/oauth/callback/android`
  (`config/routes/palm.rb`) are **inert stubs** — plain-text "open the app" responses, no session,
  no token exchange. Comment: `Compatibility callbacks only; Acme owns OAuth/OIDC`.
- Sign/Core: `POST /oidc/backchannel/logout` (RP logout receivers, `OidcRpLogoutReceiver`).

**Absent:** token introspection (RFC 7662), PAR (RFC 9126),
`/.well-known/oauth-authorization-server` (RFC 8414 — only the OIDC discovery doc exists), dynamic
client registration.

Key service objects: `OidcAuthorizeRequestValidator`, `OidcTokenExchangeService`,
`OidcAccessTokenAuthenticator`, `PalmAccessTokenAuthenticator`, `OidcClientRegistry`,
`OidcDiscoveryDocument`, `AcmeRefreshTokenService`, `DpopProofValidator`,
`SecurityJwtAuthAccessTokenCodec`, `OidcTokenRevocationService`.

---

## C. Client Registry Inventory

Source of truth: `app/services/oidc_client_registry.rb#build_clients` (in-memory, frozen, secrets
resolved from encrypted credentials `OIDC_CLIENT_SECRETS_<ID>`). No DB-backed clients, no runtime
registration. Redirect URIs are env-built (`https` for public hosts, `http://…:PORT` for loopback).

| client_id            | type                        | surface   | redirect_uri(s)                                      | auth method       | aud              | PKCE     | scope guard |
| -------------------- | --------------------------- | --------- | ---------------------------------------------------- | ----------------- | ---------------- | -------- | ----------- |
| `sign-rp`            | confidential                | Sign      | `https://id.{app,org,com}…/auth/callback`            | `private_key_jwt` | `sign-rp`        | required | none        |
| `base-rails-rp`      | confidential                | Acme/Base | `https://www.{app,org,com}…/auth/callback`           | `private_key_jwt` | `base-rails-rp`  | required | none        |
| `core-next-rp`       | confidential                | Core      | `https://www.jp.umaxica.{app,org,com}/auth/callback` | `private_key_jwt` | `core-next-rp`   | required | none        |
| `app-ios-rp`         | **public**                  | Palm      | `umaxica://oauth/callback`                           | `none`            | `palm-api`       | required | none        |
| `app-android-rp`     | **public**                  | Palm      | `com.umaxica.app:/oauth/callback`                    | `none`            | `palm-api`       | required | none        |
| `docs_{app,org,com}` | public (no auth method set) | Docs      | `https://docs.{…}/auth/callback`                     | _(unset → none)_  | `umaxica-docs-*` | required | none        |
| `news_{app,org,com}` | public (unset)              | News      | `https://news.{…}/auth/callback`                     | _(unset → none)_  | `umaxica-news-*` | required | none        |
| `help_{app,org,com}` | public (unset)              | Help      | `https://help.{…}/auth/callback`                     | _(unset → none)_  | `umaxica-help-*` | required | none        |

Flags:

- **`docs_*`/`news_*`/`help_*` have no `token_endpoint_auth_method`** → `public_client?` returns
  true (method `== "none"`), so they are treated as **public clients with no PKCE-independent
  authentication**. If these are server-side web apps they _should_ be confidential. Verify intent.
- All clients have **no allowed-scope list and no allowed-grant list** — entitlement is implicit.
- `base-rails-rp` doubles as Acme's own browser RP and Base's RP (identity ambiguity already noted
  in `memos/2026-06-16-oidc-routing-cleanup-remediation-plan.md`; rename to `acme-self-rp`
  proposed).
- No public client carries a `client_secret` (good): public auth path requires
  `client_secret.blank?`.

---

## D. Grant Type Support Matrix

| Grant / response                  | Supported?           | Where enforced                                                                                  | Note                                                                      |
| --------------------------------- | -------------------- | ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `authorization_code`              | ✅                   | `OidcTokenExchangeService#valid_grant_type?`                                                    | PKCE-gated                                                                |
| `refresh_token` (RFC 6749 §6)     | ❌ at `/oauth/token` | service rejects non-`authorization_code`                                                        | redeemed only via `…/edge/v0/token/refresh` (cookie/param) — **off-spec** |
| `client_credentials`              | ❌                   | not implemented                                                                                 | no M2M path today                                                         |
| ROPC `password`                   | ❌ (correct)         | token service hard-reject                                                                       |                                                                           |
| implicit / `response_type=token`  | ❌ (correct)         | `OidcAuthorizeRequestValidator` requires `response_type == "code"`                              |                                                                           |
| `urn:…:token-exchange` (RFC 8693) | partial              | `OidcTokenExchangeService` mentions exchange but token endpoint only wires `authorization_code` | confirm reachability                                                      |

Discovery advertises `grant_types_supported: ["authorization_code"]` and
`response_types_supported: ["code"]` — internally consistent, but it means **the `refresh_token`
returned to clients is not advertised or redeemable as an OAuth grant**.

---

## E. Redirect URI & PKCE Findings

- **Exact match only** (`OidcClientRegistry#valid_redirect_uri?` → `redirect_uris.include?(uri)`).
  No wildcard, prefix, or subdomain matching anywhere. ✅ (RFC 9700 §2.1)
- **PKCE mandatory** at authorize (`code_challenge` required, `code_challenge_method == "S256"`),
  re-verified at token (`verify_pkce`, constant-time compare of SHA-256). `plain` is rejected both
  by the validator and the model `inclusion: { in: %w(S256) }`. ✅
- redirect_uri is rebound at redemption (`authorization_code.redirect_uri == redirect_uri`). ✅
- **Native redirect URIs (classify as legacy/compat, do not remove in this review):**
  - `com.umaxica.app:/oauth/callback` — reverse-domain private-use scheme, **RFC 8252 §7.1
    compliant**.
  - `umaxica://oauth/callback` — **non-reverse-domain custom scheme**, discouraged by RFC 8252 §7.1
    (collision risk). Inconsistent with the Android entry.
  - Neither uses claimed-HTTPS (Universal Links / App Links per RFC 8252 §7.2), which would be more
    hijack-resistant. No loopback (`http://127.0.0.1`) redirect is configured. **Risk: LOW–MEDIUM.**
- `state` and `nonce` are **both required and validated separately** — `state` (CSRF, secure_compare
  in `OidcCallback`) is distinct from `nonce` (ID-token replay, secure_compare in
  `OidcIdTokenVerifier`). ✅

---

## F. Access Token Model Findings

Format: **self-contained JWS, not stored** (only refresh digests + metadata persisted). Codec:
`SecurityJwtAuthAccessTokenCodec`.

- `alg`: **`ES384` only** (`algorithms: ["ES384"]`) — no `none`, no alg-confusion surface. ✅
- Claims present: `iss sub aud exp iat jti act typ scp acr` (+ optional
  `amr sid auth_time cnf.jkt client_id step_up_until prf`). `cnf.jkt` carries DPoP binding when
  present.
- `decode_options`: `verify_iss`, `verify_aud`, `verify_exp`, `verify_iat` all true; required claims
  enforced; `kid`-based key selection via `JitSecurityJwtKeyring` with rotation. ✅
- **`typ` enforced on header AND payload** against the resource-type's expected token type → ID
  tokens (different `typ`) are rejected as bearer tokens. ✅ (RFC 9700 §2.4 / token confusion)
- ID tokens are RS256 (per discovery); access tokens are ES384 — distinct keys/algs, good
  separation.
- **No PII leakage check performed** beyond claim list; `email/name` live in ID token/userinfo, not
  in the access token — appears clean, but worth a deliberate assertion (see N).
- `aud` is always `[client.aud]` — single audience per client, audience-restricted by construction.
  ✅

---

## G. Refresh Token & Revocation Findings

Model: `RefreshTokenable` concern + `AcmeRefreshTokenService` over `ClientToken`/`VisitorToken`/
`OperatorToken`.

- Digest-only storage; `refresh_token_family_id`, `refresh_token_generation`, `rotated_at`,
  `discarded_at`, device-session and `dpop_jkt` binding preserved across rotation. ✅
- **Rotation + reuse detection:** redeeming a token with `rotated_at` present returns `:replay` and
  triggers **family-wide revocation** (`family_scope.update_all(discarded_at: now)`) plus a
  `SignRiskEmitter` signal. ✅ (RFC 9700 §4.14.2)
- TTLs (`SecurityTokenLifetimes`): client 30d, visitor 30d, operator 8h.
- **Gaps:**
  - Refresh tokens are **not redeemable at the OAuth token endpoint** (see D). The only redemption
    paths are `…/edge/v0/token/refresh` (cookie or `params[:refresh_token]`) and the internal login
    refresh. For first-party cookie RPs this is coherent; for the **Palm native client** that
    receives a `refresh_token` in the `/oauth/token` body, redemption requires posting to a
    non-discovered edge endpoint — **undocumented and off the OAuth contract** (open question O-1).
  - Public-client refresh tokens are **not sender-constrained** unless DPoP was used; for Palm
    (bearer today) they are bearer refresh tokens → rotation is the only theft mitigation. RFC 9700
    §2.2.2 wants rotation **or** sender-constraining for public clients — rotation is present, so
    this is acceptable but DPoP would strengthen it.
- Revocation endpoint (`/oauth/revoke`, `OidcTokenRevocationService`) handles access (by
  `sid`+`jti`) and refresh (by `public_id`+digest), requires client auth. ✅ No introspection
  endpoint (RS does local JWT validation instead — acceptable for self-contained tokens).

---

## H. Resource Server Boundary Findings

Two authenticators:

**`OidcAccessTokenAuthenticator`** (userinfo and OIDC consumers):

- Validates iss, aud (`token_belongs_to_audience?`), exp (codec), `jti` vs DB record
  (secure_compare), `openid` scope, subject match, resource active/not-locked.
- **DPoP sender-constraint enforced:** a token carrying `cnf.jkt` MUST be presented with the `DPoP`
  scheme + a valid proof; plain Bearer presentation of a DPoP-bound token is rejected. ✅

**`PalmAccessTokenAuthenticator`** (`palm/app/api/v0/*`):

- Requires **`Bearer` scheme and explicitly rejects `DPoP`** (`casecmp?("Bearer")`).
- Validates iss, `aud == ["palm-api"]`, `typ` (via codec), `palm.read` scope, **and a hard client_id
  allowlist `[app-ios-rp, app-android-rp]`**, resource active/not-locked. ✅ Good defense-in-depth:
  even if another client minted a `palm-api`-aud token, the client_id allowlist blocks it.

Cross-cutting:

- ID-token-as-bearer: **blocked** (typ enforcement). ✅
- Wrong-issuer / wrong-audience / expired tokens: **rejected**. ✅
- Token in query string: not accepted by any RS path reviewed (all read the `Authorization` header).
  ✅ — but add an explicit negative test (N).
- **Weakness:** RS scope checks are per-endpoint and ad hoc (`openid` for userinfo, `palm.read` for
  Palm). There is no central scope→operation map, so the _only_ thing standing between a client and
  an over-broad scope it was minted (see I) is whether each RS remembers to check. This is the
  structural risk that makes the missing AS-side scope allowlist matter.

---

## I. Scope / Audience Model Findings

- Authorize requires `scope` to include `openid`; otherwise **scope is opaque and unvalidated**.
- **Token issuance mints requested scope verbatim:** `OidcTokenExchangeService` passes
  `scopes: authorization_code.scope.to_s.split` into the access token. There is **no per-client
  allowlist, no downscoping, no registry of valid scopes** beyond the discovery doc's advisory
  `["openid","profile","email"]`. A registered client can request `palm.read`, `admin`, `write:org`,
  etc., and the AS will embed them.
- The two competing "default scope" sets (`authenticated`, `domain:client`, `read:self`, …) reported
  during exploration are **not applied on the OAuth code→token path** — they belong to the
  cookie/login path, not OAuth issuance. So OAuth access tokens carry exactly what the client asked
  for. Confirm whether any RS relies on `domain:*`/`read:self` scopes that OAuth tokens won't
  contain (potential inconsistency, open question O-2).
- Audience: one `aud` per client, audience-restricted tokens — strong. No RFC 8693 `resource`
  indicator support and none needed today given 1:1 client↔aud.
- **Recommendation:** introduce a bounded, per-client `allowed_scopes` set and intersect requested
  scope at authorize-time; reject unknown/over-broad scopes. Add `palm.read` to `app-*-rp`
  allowlists explicitly. Treat `admin`/`all`/bare `read`/`write` as never-grantable via OAuth.

---

## J. Palm Native OAuth Findings

- Correctly modeled as **public clients** (`auth_method: none`, **no `client_secret`**, PKCE
  required). ✅ (RFC 8252 §8.4, §8.5)
- `/oauth/callback*` are inert stubs — **no Rails session/cookie is created from the native
  callback**. ✅ (RFC 8252 §8.10 session-fixation avoidance)
- External-browser / system-user-agent flow is consistent with the stub design.
- Custom-scheme redirects present (classify, do not remove): `umaxica://oauth/callback` (legacy,
  non-reverse-domain — **compatibility risk**) and `com.umaxica.app:/oauth/callback` (current,
  compliant). No claimed-HTTPS callback exists yet — tracked as Phase 5 in the routing-cleanup memo.
- **Bearer-only tokens** at the Palm RS (DPoP rejected) — the highest-value place to
  sender-constrain is currently the least protected. See K.
- **Refresh story unclear** for Palm (see G / O-1): native client gets a `refresh_token` it cannot
  redeem at `/oauth/token`.

---

## K. DPoP Feasibility Assessment

Infrastructure already exists: `DpopProofValidator` (ES256/ES384, `typ:dpop+jwt`, `htm/htu/iat/jti`,
optional `ath`/`nonce`), `Client/OperatorDpopProofState` replay store with purge job, `cnf.jkt`
binding, `DPoP-Nonce` issuance, and `OidcAccessTokenAuthenticator` already enforces
sender-constraint.

| Question                          | Assessment                                                                                                                                       |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Needed for Palm?                  | **Yes — highest value.** Native public client, bearer token theft = full `palm-api` access until exp.                                            |
| Needed for Core/Base server-side? | Lower — confidential clients already use `private_key_jwt`; mTLS/DPoP is incremental.                                                            |
| Can client hold a private key?    | Yes (iOS Secure Enclave / Android Keystore).                                                                                                     |
| Where stored / `jkt`?             | Device keystore; `cnf.jkt` already supported in token claims.                                                                                    |
| Refresh sender-constrained?       | Refresh rotation preserves `dpop_jkt` — binding path exists.                                                                                     |
| RS validation?                    | `OidcAccessTokenAuthenticator` already does it; `PalmAccessTokenAuthenticator` would need to **stop hard-rejecting DPoP** and call the verifier. |
| Replay cache?                     | Already implemented (`dpop_proof_states` + purge job).                                                                                           |

**Recommendation: ADOPT for Palm (near-term, low marginal cost — the hard parts exist). DEFER for
Core/Base/server-side RPs.** Justification: the only missing piece for Palm is flipping the RS to
accept+verify DPoP and having the AS bind `cnf.jkt` for `app-*-rp` token issuance; everything else
is already built and tested for the OIDC path.

---

## L. Security Risks Ranked

**P0 (exploitable-now):** none identified. No implicit grant, no ROPC, PKCE enforced, exact redirect
match, strong token validation, short one-time codes, refresh rotation + reuse→family-revoke.

**P1 (must fix before broadening / before any third-party or higher-trust client):**

- **P1-a — Unconstrained scope minting.** Any registered client can request any scope and have it
  embedded in its access token; only ad-hoc RS checks limit privilege. (I, H)
- **P1-b — Palm bearer-only tokens.** Native public client lacks sender-constraining though DPoP
  infra exists; token theft → full API access. (J, K)
- **P1-c — Refresh off the OAuth contract.** `refresh_token` issued but not redeemable at
  `/oauth/token`; native client refresh path is undocumented/cookie-coupled. Interop + operational
  risk, and a future third-party integration foot-gun. (D, G, O-1)

**P2:**

- **P2-a — Token-endpoint auth method not pinned.** A `private_key_jwt` client can authenticate via
  `client_secret_post` if a secret exists in credentials; `authenticated_client?` doesn't enforce
  the client's _registered_ method. (RFC 9700 §2.3) — confirm no secrets are provisioned for
  assertion-only clients, then pin the method.
- **P2-b — `docs_*`/`news_*`/`help_*` default to public** (no `token_endpoint_auth_method`). If
  these are server-side web apps they should be confidential. (C)
- **P2-c — `umaxica://` non-reverse-domain custom scheme** (RFC 8252 §7.1). Legacy; plan migration
  to claimed-HTTPS or at least reverse-domain.

**P3 / hygiene:**

- No RFC 8414 `/.well-known/oauth-authorization-server` (only OIDC discovery). Add if non-OIDC OAuth
  clients are expected.
- `base-rails-rp` identity ambiguity (rename to `acme-self-rp`, per routing-cleanup memo).
- No introspection endpoint — acceptable for self-contained tokens; revisit if opaque tokens or
  third-party RSs appear.

---

## M. Minimal Remediation Plan

1. **Scope allowlist (P1-a).** Add `allowed_scopes` per client in `OidcClientRegistry`; intersect
   requested scope in `OidcAuthorizeRequestValidator` (reject unknown/over-broad); never mint a
   scope a client isn't entitled to. Grant `palm.read` only to `app-*-rp`.
2. **DPoP for Palm (P1-b).** Bind `cnf.jkt` when issuing `app-*-rp` tokens; change
   `PalmAccessTokenAuthenticator` to accept `DPoP` and call `DpopRequestVerifier`; phase Bearer out
   behind a flag.
3. **Refresh contract (P1-c).** Decide explicitly: either (a) implement `grant_type=refresh_token`
   at `/oauth/token` for native clients and advertise it in discovery, or (b) document that Palm
   refresh uses the edge endpoint and remove `refresh_token` from the `/oauth/token` body for
   non-cookie clients. Do not leave it ambiguous.
4. **Pin token-endpoint auth method (P2-a).** In `authenticated_client?`, require the client's
   `registered_token_endpoint_auth_method` rather than trying each path.
5. **Re-classify `docs_*`/`news_*`/`help_*` (P2-b).** Set explicit `token_endpoint_auth_method`.
6. **Native redirect hygiene (P2-c).** Track migration of `umaxica://` to claimed-HTTPS / reverse-
   domain (coordinate with routing-cleanup memo Phase 5; do not break existing installs).

Sequence: 1 → 4 → 5 (AS-side, bounded, no client changes) before 2 → 3 (require client/app
coordination).

---

## N. Tests To Add Or Update

- Authorize: reject `response_type=token`, missing `code_challenge`, `code_challenge_method=plain`,
  missing `state`/`nonce`, unregistered/mismatched `redirect_uri`, missing `openid`.
- Token: reject `grant_type=password`/`refresh_token`/`client_credentials`; reject reused/expired/
  consumed code; reject redirect_uri & client_id mismatch; PKCE failure; public client sending a
  secret.
- **Scope (new):** once allowlist exists — client requesting a scope outside its allowlist is
  rejected at authorize; minted access token contains only allowlisted scopes.
- Access-token codec: reject `alg != ES384`, reject ID-token `typ` as bearer, reject wrong
  `iss`/`aud`/ expired/missing required claims.
- Resource servers: Palm rejects wrong-aud, wrong client_id, missing `palm.read`, ID token, token in
  query string; OIDC RS enforces DPoP sender-constraint (DPoP-bound token presented as Bearer →
  401).
- Refresh: rotation happy path; reuse → family revocation + risk signal; cross-family isolation.
- DPoP (when Palm adopts): valid proof accepted, replayed `jti` rejected, `htu`/`htm` mismatch
  rejected.

---

## O. Open Questions

- **O-1.** How is the **Palm native client expected to refresh**? It receives `refresh_token` from
  `/oauth/token` but the only redemption paths are cookie/edge. Is there a native refresh contract?
- **O-2.** Do any resource servers rely on `domain:*` / `read:self` scopes that the OAuth code→token
  path does **not** mint (those come from the login/cookie path)? Potential silent authz gap.
- **O-3.** Are `docs_*`/`news_*`/`help_*` server-side web apps (should be confidential) or
  SPAs/native (public is correct)?
- **O-4.** Is RFC 8693 token exchange actually reachable from `/oauth/token`, or dead code?
- **O-5.** Any plan to serve non-OIDC OAuth clients (would require RFC 8414 metadata + a real
  refresh grant + scope model)?

---

## P. Recommended First Implementation Prompt

> Implement a per-client scope allowlist for the Acme authorization server. In
> `app/services/oidc_client_registry.rb`, add an `allowed_scopes` field to each client config and to
> the `VisitorAccount` Data type (default to the minimal OIDC set `%w(openid profile email)`; grant
> `palm.read` only to `app-ios-rp` and `app-android-rp`). In `OidcAuthorizeRequestValidator`,
> intersect the requested `scope` against the client's `allowed_scopes` and raise `ArgumentError` (→
> `invalid_scope`) if any requested scope is not allowed, keeping the existing mandatory-`openid`
> check. Ensure `OidcTokenExchangeService` mints only the validated, intersected scope (never raw
> requested scope). Do not change the cookie/login scope path. Add Minitest coverage for: a client
> requesting an out-of-allowlist scope is rejected at authorize; a Palm client successfully
> requesting `openid palm.read`; and an access token minted with only allowlisted scopes. Run the
> narrowest relevant tests first, then the broader oauth/oidc controller and service suites. Treat
> `admin`, `all`, bare `read`, and bare `write` as never-grantable via OAuth.

---

_Review complete. No files modified. Next step is yours to choose — Section P is the highest-value,
lowest-blast-radius starting point; P1-b (DPoP for Palm) and P1-c (refresh contract) require
app-side coordination and should follow._
