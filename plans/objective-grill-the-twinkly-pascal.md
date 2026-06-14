# Review: Native-App OAuth Redirect Foundation for Palm

**Type:** Security / boundary review (NOT an implementation plan). No code changes were made.
**Date:** 2026-06-14 **Scope:** app-audience native client only. com/org native, native app itself,
and WebView are out of scope.

## Context

Palm is the native/mobile bearer-token Resource Server. The target flow is:

```
Native App -> system browser -> Acme /authorize -> Sign (auth ceremony) -> Acme resumes
  -> Acme redirects to claimed HTTPS redirect_uri -> OS opens Native App
  -> Native App exchanges code+PKCE at Acme /token -> calls Palm with Bearer token
```

Because the native app does not exist, Palm only needs **inert 200 fallback pages** for the claimed
HTTPS callback URLs. Acme must remain the only Authorization Server; Palm and Sign must never issue,
exchange, or validate-as-authority any code/token/redirect_uri.

**Headline finding:** The foundation is _largely unbuilt_, not mis-built. Today's boundaries are
clean **because** Palm has no OAuth code and no native client is registered. The risk is entirely in
what gets added. Two latent traps already in the codebase would bite during implementation.

---

## PASS / FAIL Summary

| #   | Review area                               | Verdict            | Note                                                                                            |
| --- | ----------------------------------------- | ------------------ | ----------------------------------------------------------------------------------------------- |
| 1   | Authority boundary (Acme only AS)         | **PASS**           | Palm/Sign issue no tokens; no code in Palm                                                      |
| 2   | Native client scope app-only              | **PASS (vacuous)** | No native client exists at all yet                                                              |
| 3   | redirect_uri exact-match validation       | **PASS**           | Exact `include?` match, both endpoints                                                          |
| 4   | PKCE enforcement (S256)                   | **PASS**           | Mandatory at authorize + verified at token                                                      |
| 5   | Token endpoint public-client behavior     | **FAIL**           | No `none` auth path → native exchange impossible (BLOCKER-1); silent-downgrade trap (BLOCKER-2) |
| 6   | Palm callback inert fallback pages        | **FAIL (absent)**  | Routes/controllers do not exist yet                                                             |
| 7   | Browser/native flow documented + testable | **PARTIAL**        | High-level flow in ADR; redirect/fallback layer + naming undecided                              |
| 8   | Security-regression search                | **PASS**           | No Port aliases, no catch-all callbacks, no compat layer                                        |
| 9   | Required tests present                    | **FAIL**           | Native-client and Palm-callback tests do not exist                                              |

**Overall: FAIL — foundation incomplete.** No boundary _violations_ found; the failures are missing
pieces plus two traps to avoid when building them.

---

## Critical Blockers

### BLOCKER-1 — Token endpoint has no public-client (`none`) path (functional)

`app/services/oidc_token_exchange_service.rb:56-60` → `OidcClientRegistry.authenticate`
(`oidc_client_registry.rb:63-69`) returns `false` whenever `client.client_secret.blank?`. A native
public client has no secret and presents no `client_assertion`, so `authenticated_client?` is always
false and the exchange fails with `"OIDC client authentication failed"` **before** PKCE is even
checked. **Native PKCE-only token exchange is impossible today.** Adding a `none` branch is
required.

### BLOCKER-2 — Silent confidential→public downgrade trap (security)

`oidc_client_registry.rb:268-270`:

```ruby
def default_auth_method(client_id)
  resolve_secret_credential(client_id).present? ? "client_secret_post" : "none"
end
```

The _effective_ auth method silently becomes `"none"` whenever a secret is blank/missing. Harmless
today (the `none` path doesn't exist). But if the future `none` branch keys off this **effective**
value, a confidential client whose secret fails to load (missing ENV/credential) is silently
downgraded to a public client and **bypasses client authentication entirely**. This is the single
most important design constraint:

- The native client MUST declare `token_endpoint_auth_method: "none"` **explicitly** in the
  registry.
- The token endpoint's `none` branch MUST gate on the **explicitly configured** value, never on
  `default_auth_method` / "secret happens to be absent".
- Violating this re-introduces a token-theft path for every confidential client.

---

## Boundary Violations

**None found.** Verified clean:

- Palm routes (`config/routes/palm.rb`) contain only `root`, `health*`, `robots.txt`, `sitemap.xml`,
  `csp-violation-report`. No `authorize`, no `token`, no `oauth/callback`.
- Palm `BareController` (`app/controllers/palm/app/bare_controller.rb`) inherits
  `ActionController::Base`, `AUTHENTICATION_MODE = :bare`, no app session/auth — a correct inert
  base for fallback pages.
- Sign owns ceremony only; codes/tokens are issued by Acme (`oidc_token_exchange_service.rb`,
  `oidc_authorization_code_issuer.rb`). Sign's OIDC callback _consumes_ Acme tokens, never issues.
- No `Port` alias routes or compat shims (grep hits on "report" are coincidental substrings).

---

## Security Issues / Strengths

**Strengths (keep these invariants when extending):**

- Exact redirect_uri match — `OidcClientRegistry.valid_redirect_uri?`
  (`oidc_client_registry.rb:53-58`, `include?` only — no prefix/suffix/host/wildcard), enforced at
  authorize (`oidc_authorize_request_validator.rb:48-53`) **and** re-checked at token
  (`oidc_token_exchange_service.rb:87`).
- PKCE S256 mandatory at authorize for _all_ clients (`oidc_authorize_request_validator.rb:24-31` —
  rejects missing challenge and any method ≠ S256); `code_verifier` required and SHA256-verified at
  token (`oidc_token_exchange_service.rb:93-98`, `client_authorization_code.rb:108-116`,
  `secure_compare`).
- Authorization code is single-use (`consume!` + `consumed_at` + UNIQUE index on `code`
  `client_authorization_code.rb:29,97-102`), pessimistically locked at exchange
  (`oidc_token_exchange_service.rb:73-81`), 10s TTL (`CODE_TTL`), and bound to client_id +
  redirect_uri + code_challenge (`validate_code` `:83-91`). Replay / cross-client / cross-redirect
  are all closed.
- Param-log filtering already redacts `code`, `oauth_code`, `authorization_code`, `state`, `uid`
  (`config/initializers/filter_parameter_logging.rb`) — covers the fallback-page query string in
  Rails' filtered request logging.

**Issues to address when building the foundation:**

- **No native client registered**, no `application_type`/`client_kind` concept anywhere, no
  per-client PKCE/auth-method config that expresses "native public". (Confirmed: no
  `native`/`application_type`/ `public_client` references in app code.)
- **`build_redirect_uris` is unsafe to reuse for native** (`oidc_client_registry.rb:248-253`): it
  emits a single `/auth/callback` URI and picks **http** for loopback/local hosts. Native needs
  multiple **claimed-HTTPS** callback URIs and an explicit reject of http/loopback/custom-scheme/
  wildcard at registration time.
- **Discovery omits `none`** (`oidc_discovery_document.rb:22` advertises only `private_key_jwt`,
  `client_secret_post`). Must add `none` when public clients go live;
  `code_challenge_methods_supported` is already correctly `["S256"]`.
- Minor: `revoked?` and `expired?` are identical conditions (`client_authorization_code.rb:81-91`) —
  not a hole, but `revoke!` only works while the code is still live; worth a comment or fix.

---

## Browser / Native Flow (Task 7)

The high-level native path is in `adr/acme-sign-core-base-port-boundary.md:90-112` and
`docs/architecture/acme-sign-core-base-port.md`. **Undecided / undocumented** (intentionally
deferred): the claimed-HTTPS redirect/fallback layer, app-links / assetlinks.json /
apple-app-site-association, and **audience/client naming drift** — the ADR uses `port-api` /
`app-ios-rp`, while the registry uses `umaxica-*` audiences and a different client_id shape. This
naming choice is an open design item that must be settled before registering the native client (it
determines `aud` on the access token Palm will validate). No WebView support exists and none should
be added.

---

## Missing Tests (Task 9)

None of these exist today and should be required by the eventual patch:

**Acme /authorize (native client):** accepts registered app native client + claimed-HTTPS
redirect_uri + S256; rejects missing PKCE; rejects `plain`; rejects unregistered redirect_uri;
rejects `http://`; rejects wildcard/partial redirect_uri; rejects any com/org native activation.

**Acme /token (public client):** accepts correct code + client_id + redirect_uri + code_verifier for
a `none` client **with no secret**; rejects missing code_verifier; rejects wrong code_verifier;
rejects reused code; rejects wrong client_id; rejects wrong redirect_uri; **rejects a confidential
client that omits its secret** (BLOCKER-2 regression guard).

**Palm callback fallback:** returns 200; works unauthenticated; mutates no DB; performs no token
exchange; sets no session cookie; handles `?code=&state=` inertly (no persistence, no log leak).

**Boundary guards:** Palm exposes no token endpoint; Palm exposes no authorize endpoint; Sign owns
no native client registration; Sign issues no tokens.

Existing coverage confirmed: `test/services/oidc/authorize_service_test.rb` already rejects `plain`.

---

## Recommended Minimal Patch Plan (for later approval — do NOT implement now)

Ordered, minimal, app-only. Each step is small and independently testable.

1. **Register one app-only native public client** in `OidcClientRegistry.build_clients`
   (`oidc_client_registry.rb`): explicit `token_endpoint_auth_method: "none"`,
   `resource_type: "client"`, and an explicit list of **claimed-HTTPS** redirect URIs
   (`https://<palm-host>/oauth/callback`, `.../oauth/callback/ios`, `.../oauth/callback/android`).
   Do **not** reuse `build_redirect_uris`; add a native-specific builder that forces `https` and
   rejects loopback/custom-scheme/wildcard. No com/org entries.
2. **Add the `none` path to the token endpoint** (`oidc_token_exchange_service.rb:56-60`): when the
   **registered** `token_endpoint_auth_method == "none"` and no secret/assertion is presented, treat
   the client as authenticated by PKCE + client_id match (already enforced). Gate strictly on the
   explicit registry value — never on `default_auth_method`. Confidential clients keep requiring a
   secret/assertion.
3. **Advertise `none`** in `oidc_discovery_document.rb:22`.
4. **Add Palm callback fallback routes + controller**: `GET oauth/callback`, `.../ios`,
   `.../android` under the existing `PALM_SERVICE_URL` (app) constraint in `config/routes/palm.rb`,
   served by a new inert controller on `Palm::App::BareController` that renders a static 200 message
   and does nothing else (no DB, no session, no token exchange, no logging of code/state). com/org
   stay untouched.
5. **Tests** per the "Missing Tests" section, including the BLOCKER-2 downgrade regression guard.
6. **Settle audience/client naming** (open design item) before step 1 is finalized; record the
   decision in the relevant plan/ADR.

Out of scope and explicitly excluded: native app code, com/org native clients/routes/assets,
custom-scheme and loopback redirect URIs, WebView, any rename of existing surfaces, and any change
to the authentication→authorization pipeline ordering.

---

## Verification (for the eventual implementation, not now)

- `bin/rails test test/services/oidc/` (authorize + token, incl. new native + downgrade-guard cases)
- `bin/rails test test/controllers/palm/` (new callback fallback tests)
- Manually hit `/.well-known/openid-configuration` to confirm `none` is advertised.
- Confirm the native redirect URIs are exact-match-only and HTTPS-only via authorize-endpoint tests.

---

## Files Inspected

- `app/services/oidc_client_registry.rb`
- `app/services/oidc_authorize_request_validator.rb`
- `app/services/oidc_token_exchange_service.rb`
- `app/services/oidc_discovery_document.rb`
- `app/models/client_authorization_code.rb`
- `app/controllers/acme/app/oauth/authorizations_controller.rb`
- `app/controllers/palm/app/bare_controller.rb`
- `config/routes/palm.rb`, `config/routes/acme.rb` (reviewed via exploration)
- `config/initializers/filter_parameter_logging.rb`
- `adr/acme-sign-core-base-port-boundary.md`, `docs/architecture/acme-sign-core-base-port.md`,
  `plans/active/acme-sign-core-base-port-implementation.md`,
  `plans/archive/surface-routing-controller-pass-base-palm-help-docs-news.md`,
  `docs/security/oauth2-1-compliance-gap.md` (reviewed via exploration)

## Commands Run

- `grep` for `filter_parameter`, `native`/`application_type`/`client_kind`/`public_client`,
  `Port`-alias routes, and discovery auth methods.
- Three parallel Explore sweeps (Acme OAuth, Palm/Sign surfaces, plans/ADR/docs).
