# Review (redone): Native-App OAuth Redirect Foundation

**Type:** Security / boundary review. No code is changed by this document. No implementation.
**Date:** 2026-06-14 **Scope (as instructed):** app-audience native-app OAuth _redirect foundation_
only.

## Why this review was redone

The previously produced review (`plans/objective-perform-an-elegant-cake.md`) is for a **different
objective** — a full authentication / session / JWT-schema / cookie / logout / regional-propagation
architecture redesign. That is out of scope here. Per explicit instruction this review:

- does **not** move `plans/objective-perform-an-elegant-cake.md` to `memos/`,
- does **not** promote its C1–C5 conflicts to ADR amendments,
- does **not** redesign JWT schema, cookies, logout, session registry, or regional architecture,
- treats **Palm** only as the transitional native-API route/name (accepted name for the former
  "Port"), **not** a new surface,
- treats **Acme / Sign / Core / Base / Port** as the accepted repo surfaces.

This review is scoped strictly to: claimed-HTTPS redirect URIs, PKCE S256, public-client
(`token_endpoint_auth_method = none`), exact-match redirect_uri validation, authorization-code
binding, and inert Palm callback fallback — **app audience only; com/org reserved in shape only; no
custom scheme; no loopback; no WebView; no native app implementation.**

A correctly-scoped review already exists at `plans/objective-grill-the-twinkly-pascal.md`; this
document re-verifies it against source and answers the 11 required questions directly. The findings
agree.

---

## Headline finding

**The foundation is largely _unbuilt_, not _mis-built_.** Boundaries are clean today **because**
Palm has no OAuth code and no native client is registered. The existing AS primitives (exact-match
redirect_uri, mandatory PKCE S256, single-use bound codes) are correct and reusable. The risk lives
entirely in what gets added, and two latent traps already in the registry would bite during
implementation.

**Overall verdict: FAIL — foundation incomplete.** No boundary _violations_; the failures are
missing pieces (public-client path, Palm callback fallback, tests) plus two traps to avoid.

---

## PASS / FAIL Summary

| #   | Review area                                         | Verdict            | Evidence                                                                                 |
| --- | --------------------------------------------------- | ------------------ | ---------------------------------------------------------------------------------------- |
| 1   | Acme owns all OAuth AS responsibilities             | **PASS**           | `/authorize`, `/token`, code issuance, PKCE, redirect_uri allowlist all in Acme/services |
| 2   | Sign owns no native client / code / token           | **PASS**           | Sign is RP only; consumes Acme tokens, issues none                                       |
| 3   | Port/Palm callback fallback inert                   | **FAIL (absent)**  | No callback route/controller exists yet (`config/routes/palm.rb`)                        |
| 4   | Native clients app-only in this slice               | **PASS (vacuous)** | No native client registered at all                                                       |
| 5   | com/org native clients/routes/assets absent         | **PASS**           | None registered; no app-link assets exist                                                |
| 6   | redirect_uri exact-match only                       | **PASS**           | `include?` only, both endpoints                                                          |
| 7   | Only claimed-HTTPS redirect URIs accepted           | **PARTIAL**        | Allowlist is exact-match, but `build_redirect_uris` emits `http` for loopback hosts      |
| 8   | PKCE S256 mandatory                                 | **PASS**           | Required at authorize, verified at token                                                 |
| 9   | /token binds code to id/uri/expiry/use/challenge    | **PASS**           | `validate_code` + `verify_pkce` + lock + 10s TTL                                         |
| 10  | Callback routes avoid login/DB/exchange/session/log | **PASS (vacuous)** | Route does not exist; param-log filter already redacts `code`/`state`                    |
| 11  | Tests present for the above                         | **FAIL**           | Native-client and Palm-callback tests do not exist                                       |

---

## Answers to the 11 required questions

**1. Does Acme own all OAuth client registration, redirect_uri allowlisting, code issuance, PKCE
validation, and token issuance? — YES.** Registration: `OidcClientRegistry.build_clients`
(`app/services/oidc_client_registry.rb:111-246`). Redirect allowlist: `valid_redirect_uri?`
(`:53-58`). Code issuance: Acme `oauth/authorizations_controller` → `OidcAuthorizeService`. PKCE:
`OidcAuthorizeRequestValidator` (`:24-31`) + `OidcTokenExchangeService#verify_pkce` (`:93-98`).
Token issuance: `OidcTokenExchangeService` (`app/services/oidc_token_exchange_service.rb`). All live
in Acme/service layer, none in Palm or Sign.

**2. Does Sign avoid owning native client registration, redirect_uri validation, code issuance, or
token issuance? — YES.** Sign controllers include `OidcCallback` and only _consume_ Acme-issued
tokens to establish a Sign session; Sign defines no clients, no allowlist, no code/token issuance.

**3. Does Port/Palm callback fallback stay inert? — YES, vacuously.** `config/routes/palm.rb`
exposes only `root`, `health*`, `robots.txt`, `sitemap.xml`, `csp-violation-report` for app/com/org.
No `oauth/callback`, no `authorize`, no `token`. `Palm::App::BareController` inherits
`ActionController::Base` with `AUTHENTICATION_MODE = :bare` — a correct inert base, but no callback
action exists yet. **The inert fallback must be _built_; it cannot be confirmed as built.**

**4. Are native clients app-only in this slice? — YES, vacuously.** No native client of any audience
is registered.

**5. Are com/org native clients, routes, redirect URIs, app-link assets, and UI flows absent? —
YES.** No native client entries; no `apple-app-site-association` / `assetlinks.json`; Palm com/org
routes carry only health/metadata. com/org exist in _shape_ (route scopes) but no native OAuth
activation.

**6. Does Acme validate redirect_uri by exact match only? — YES.** `valid_redirect_uri?` uses
`client.redirect_uris.include?(uri)` (`:57`) — no prefix/suffix/host/wildcard/normalization.
Enforced at authorize (`oidc_authorize_request_validator.rb:48-53`) **and re-checked** at token
(`oidc_token_exchange_service.rb:87`).

**7. Are only claimed-HTTPS redirect URIs accepted? — NOT GUARANTEED for native.** The allowlist is
exact-match, so only registered URIs pass. But the registration _builder_ `build_redirect_uris`
(`oidc_client_registry.rb:248-253`) chooses `http` and a `:PORT` suffix for loopback/local hosts and
emits a single `/auth/callback`. Reusing it for a native client would register a non-HTTPS URI. A
native-specific builder that **forces HTTPS and rejects http/loopback/custom-scheme/wildcard** is
required. (No native client exists yet, so nothing is currently mis-registered.)

**8. Is PKCE S256 mandatory? — YES.** Authorize rejects a blank `code_challenge` and any
`code_challenge_method != "S256"` (`oidc_authorize_request_validator.rb:28-29`). Token requires
`code_verifier` and verifies SHA256 with `secure_compare` (`oidc_token_exchange_service.rb:93-98`,
model `verify_pkce`). `plain` is rejected; discovery advertises only `["S256"]`.

**9. Does /token bind the code to client_id, redirect_uri, expiry, single-use, and code_challenge? —
YES.** `validate_code` (`oidc_token_exchange_service.rb:83-91`) rejects expired/consumed/revoked
codes, `redirect_uri` mismatch, and `client_id` mismatch. Single-use: `consume!` under a pessimistic
`lock` (`:73-81, :108`) with a UNIQUE index on `code` and a 10s `CODE_TTL`. code_challenge binding:
`verify_pkce` (`:37, :93-98`). Cross-client / cross-redirect / replay are all closed.

**10. Do callback routes avoid login, DB mutation, code exchange, session/cookie creation, and
unsafe query logging? — YES, vacuously / by default.** No Palm callback route exists, so none of
these happen. `config/initializers/filter_parameter_logging.rb` already redacts `code`,
`oauth_code`, `authorization_code`, `state`, `uid`, so the _eventual_ fallback page's
`?code=&state=` query string will not leak into Rails request logs. The eventual controller must
still do nothing (static 200 only).

**11. Are tests present for the above? — NO (for the native slice).** Existing OAuth/PKCE tests
cover the confidential-client web flow. There are **no** native-public-client authorize/token tests,
**no** HTTPS-only / loopback-reject redirect tests, **no** Palm callback-inertness tests, and **no**
BLOCKER-2 downgrade regression guard.

---

## Critical Blockers

### BLOCKER-1 — Token endpoint has no public-client (`none`) path (functional)

`authenticated_client?` (`oidc_token_exchange_service.rb:56-60`) falls through to
`OidcClientRegistry.authenticate`, which returns `false` whenever `client.client_secret.blank?`
(`oidc_client_registry.rb:63-69`). A native public client has no secret and presents no
`client_assertion`, so authentication always fails with `"OIDC client authentication failed"`
**before PKCE is checked**. **Native PKCE-only token exchange is impossible today.** A `none` branch
is required.

### BLOCKER-2 — Silent confidential→public downgrade trap (security)

`default_auth_method` (`oidc_client_registry.rb:268-270`) returns `"none"` whenever a secret is
blank/missing, and `find` (`:38`) applies it as the _effective_ `token_endpoint_auth_method` for any
client without an explicit value. Harmless today (no `none` path exists). But if the future `none`
branch keys off this **effective** value, a confidential client whose secret fails to load (missing
ENV/credential) is silently downgraded to public and **bypasses client authentication entirely**.

**Load-bearing design constraint:** the native client MUST declare
`token_endpoint_auth_method: "none"` **explicitly**, and the token endpoint's `none` branch MUST
gate on the **explicitly configured registry value**, never on `default_auth_method` / "secret
happens to be absent."

---

## Boundary Violations

**None found.** Verified clean:

- Palm routes contain no `authorize`/`token`/`oauth/callback` (`config/routes/palm.rb`).
- `Palm::App::BareController` is correctly inert (`ActionController::Base`, `:bare`).
- Sign issues no codes/tokens; Acme owns issuance (`oidc_token_exchange_service.rb`,
  `oidc_authorization_code_issuer.rb`).
- No `Port`-alias routes or compatibility shims.

---

## Security Issues / Strengths

**Strengths (invariants to preserve when extending):** exact-match redirect_uri at both endpoints;
mandatory PKCE S256 with `secure_compare`; single-use, pessimistically-locked, 10s, fully-bound
authorization codes; param-log redaction of `code`/`state`.

**Issues to address when building:**

- No native client and no `application_type` / `client_kind` / `public_client` concept anywhere.
- `build_redirect_uris` unsafe for native (emits `http` for loopback, single `/auth/callback`).
- Discovery omits `none` (`oidc_discovery_document.rb:22` lists only `private_key_jwt`,
  `client_secret_post`); `code_challenge_methods_supported` is already correctly `["S256"]`.
- Minor: `revoked?` and `expired?` share identical conditions in the code model — not a hole, worth
  a clarifying comment.

---

## Questionable Design Choices (to settle before building, not to fix now)

- **Audience / client naming drift.** ADR/docs use `port-api` / `app-ios-rp`; the registry uses
  `umaxica-*` audiences and `<surface>_<aud>` client_ids. This determines the `aud` Palm will
  validate and must be settled before registering the native client.
- **Single `/auth/callback` path shape** in `build_redirect_uris` vs. the multiple claimed-HTTPS
  callback URLs a native foundation needs — a native-specific builder is warranted rather than
  overloading the existing one.
- **`default_auth_method` returning `none` implicitly** (BLOCKER-2) is a questionable default
  independent of native work; explicit per-client auth methods would remove the trap.

---

## Missing Tests

- **Acme /authorize (native):** accepts registered app native client + claimed-HTTPS redirect_uri +
  S256; rejects missing PKCE, `plain`, unregistered URI, `http://`, wildcard/partial URI, and any
  com/org native activation.
- **Acme /token (public):** accepts code + client_id + redirect_uri + code_verifier for a `none`
  client with no secret; rejects missing/wrong verifier, reused code, wrong client_id, wrong
  redirect_uri, and **a confidential client that omits its secret** (BLOCKER-2 guard).
- **Palm callback fallback:** returns 200 unauthenticated; mutates no DB; performs no token
  exchange; sets no session/cookie; handles `?code=&state=` inertly without logging.
- **Boundary guards:** Palm exposes no token/authorize endpoint; Sign registers no native client and
  issues no tokens.

---

## Recommended Minimal Patch Plan (for later approval — do NOT implement now)

App-only, ordered, each independently testable:

1. Register **one** app-only native public client in `OidcClientRegistry.build_clients` with
   explicit `token_endpoint_auth_method: "none"`, `resource_type: "client"`, and an explicit list of
   **claimed-HTTPS** redirect URIs via a **new native-specific builder** that forces `https` and
   rejects loopback/custom-scheme/wildcard. No com/org entries.
2. Add a `none` branch to `OidcTokenExchangeService#authenticated_client?` that authenticates by
   PKCE + client_id match **only when the registered (explicit) auth method is `none`** — never via
   `default_auth_method`. Confidential clients keep requiring secret/assertion.
3. Advertise `none` in `oidc_discovery_document.rb:22`.
4. Add inert Palm callback fallback route(s) under `PALM_SERVICE_URL` (app only) in
   `config/routes/palm.rb`, served by a new controller on `Palm::App::BareController` that renders a
   static 200 and does nothing else. com/org untouched.
5. Add the tests in "Missing Tests," including the BLOCKER-2 regression guard.
6. Settle audience/client naming before finalizing step 1; record the decision in the active
   plan/ADR.

Explicitly excluded: native app code; com/org native clients/routes/assets; custom-scheme and
loopback redirect URIs; WebView; surface renames; any change to the authentication→authorization
pipeline ordering; JWT/cookie/logout/session-registry/regional redesign.

---

## Verification (for the eventual implementation, not now)

- `bin/rails test test/services/oidc/` (authorize + token, incl. new native + downgrade-guard cases)
- `bin/rails test test/controllers/palm/` (new callback-fallback inertness tests)
- `GET /.well-known/openid-configuration` shows `none` once public clients go live.
- Authorize-endpoint tests confirm native redirect URIs are exact-match-only and HTTPS-only.

---

## Files Inspected

- `app/services/oidc_client_registry.rb` (read in full)
- `app/services/oidc_token_exchange_service.rb` (read in full)
- `app/services/oidc_authorize_request_validator.rb` (read in full)
- `config/routes/palm.rb` (read in full)
- `plans/objective-grill-the-twinkly-pascal.md` (existing correct-scope review, cross-checked)
- `plans/objective-perform-an-elegant-cake.md` (the mis-scoped prior review, confirmed
  off-objective)
- Via Explore sweeps: `app/services/oidc_discovery_document.rb`,
  `app/models/{client,operator,visitor}_authorization_code.rb`,
  `app/controllers/acme/app/oauth/{authorizations,tokens}_controller.rb`,
  `app/controllers/palm/app/bare_controller.rb`,
  `app/controllers/sign/*/auth/callbacks_controller.rb`, `config/routes/acme.rb`,
  `config/initializers/filter_parameter_logging.rb`, `adr/acme-sign-core-base-port-boundary.md`,
  `docs/architecture/acme-sign-core-base-port.md`, existing `test/services/oidc/*`,
  `test/controllers/acme/*`.

## Commands Run

- Three parallel Explore sweeps: (a) Acme OAuth AS implementation, (b) Sign/Palm/Port surfaces and
  callback inertness, (c) OAuth/PKCE tests + ADRs + plans/docs.
- Direct reads of the four primary source files above to ground every PASS/FAIL.
