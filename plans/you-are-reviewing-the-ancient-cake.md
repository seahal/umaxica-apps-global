# Rails Surface Completeness Audit — Acme / Sign / Base / Core / Palm / Docs / Help / News

## Context

This is a hard implementation-completeness review of the **Rails side only**. Goal: determine
whether the Rails surfaces are internally complete, coherent, test-covered, and ready to support the
future Next.js Core RP/BFF and Cloudflare private backend (both treated as future/unknown). No
Next.js or Cloudflare work is in scope; no new DBs; Base settings stay Rails HTML; Palm stays
cookieless; Sign stays a non-IdP.

The governing decision is `adr/acme-sign-core-base-port-boundary.md` (Accepted 2026-06-12): **Acme
is the sole IdP/AS**; Sign is a special RP (never an issuer); Core is the Next.js web RP/BFF (Rails
Core is a transitional stand-in); Base is the Rails foundation/control-plane (settings, preferences,
account, org, admin); Palm is a native bearer-token Resource Server (no cookies/sessions);
Docs/Help/News are host-constrained Rails JSON content authorities with Next.js owning the frontend.

**User decision for this pass: deliver the audit report only.** No code, route, or test changes are
made here. Each finding records the smallest recommended Rails-side correction or freeze test as a
_follow-up_, not an executed change. The recorded preferred direction for the one BLOCKER (Palm
platform callback routes) is **remove routes + controllers**.

---

## 1. Evidence Summary

**Inspected**

- Route contracts: `config/routes.rb` +
  `config/routes/{acme,sign,core,base,palm,docs,help,news}.rb`.
- Governing docs: `adr/acme-sign-core-base-port-boundary.md`,
  `plans/active/acme-sign-core-base-port-implementation.md`,
  `docs/architecture/controller-boundaries.md`,
  `memos/2026-06-16-oidc-routing-cleanup-remediation-plan.md`,
  `memos/2026-06-13-codex-docs-help-news-phase-1-audit.md`.
- Controllers/tiers, OAuth/OIDC AS internals, cookies/CSP/CSRF, and test inventory (890 controllers,
  ~343 controller test files) via three read-only sweeps.

**Commands run**

- `ruby -c config/routes.rb config/routes/*.rb` → all **Syntax OK**.
- `bin/rails routes` (filtered) → routes load; helper/controller/host resolution captured below.
- Targeted `cat`/`grep` for Palm callback stubs, userinfo duplication, flash usage, `base-rails-rp`.

**Current failures**: none observed at the route/boot level. Full `bin/rails test` and
`vp test --coverage` were **not run** in this pass (audit-only; the working tree already carries
unrelated `M` changes). See §5.

**Important reconciliation**: the two remediation memos are partly historical. The _current_ routes
show OIDC-cleanup Phases 1–3 already implemented — no `/sso/*`, canonical `GET /auth` +
`POST /auth/logout`, canonical `/sign/in` + `/sign/up` (no `/entrance`), and Docs/Help/News already
shrunk to JSON `/api/v0/entries` with no HTML `/entries` and no `robots.txt`. The `OidcRpLogout`
flash violation is **already fixed** (`app/controllers/concerns/oidc_rp_logout.rb` has no
`notice:`).

---

## 2. What is solid (not rubber-stamped — evidence-backed)

- **OAuth/OIDC AS internals (Acme)** are correct and complete:
  - PKCE: `code_challenge` required and `code_challenge_method` must be `S256`, plain rejected —
    `app/services/oidc_authorize_request_validator.rb:33-34`; verifier checked at exchange with
    constant-time compare — `app/models/client_authorization_code.rb:108-116`.
  - `redirect_uri` **exact match** (`Array(...).include?`), no prefix/substring —
    `app/services/oidc_redirect_uri_validator.rb:7-9`; re-checked at token exchange
    `app/services/oidc_token_exchange_service.rb:99-100`.
  - Authorization code: 10s TTL, single-use via `consumed_at` + **pessimistic lock**
    (`app/models/client_authorization_code.rb:35,97-102`,
    `app/services/oidc_token_exchange_service.rb:86-103`).
  - Refresh rotation on exchange + family/generation tracking + replay detection
    (`app/models/concerns/refresh_tokenable.rb:22-52,174-196`).
  - Client auth: explicit `none`/secret/private_key_jwt, constant-time secret compare, **no silent
    fallback** for confidential clients (`app/services/oidc_client_registry.rb:21-26,101-107`).
  - **Sole minter**: Sign/Base/Palm mint no tokens; Core signs its browser JWT with **Acme's** keys
    (`app/services/core_browser_credential_contract.rb:47-62,81-85`).
- **Cookies**: `__Host-auth_access/_refresh/_dbsc` and `__Host-preference_*` are Secure, HttpOnly,
  SameSite=Strict, host-only (`domain:false`), Path=/, partitioned in prod
  (`app/controllers/concerns/authentication_cookie_service.rb:26-48`,
  `app/services/core_cookie_options.rb`). Session cookie `__Host-session` is SameSite=**Lax**
  (justified for OIDC/email-link inbound nav). Public theme/consent cookies are intentionally
  non-HttpOnly/apex-scoped.
- **CSP report sink** emits a Rails event, rate-limited, body-capped — **not** a per-request DB
  write (`app/services/csp_violation_report_intake.rb`). **CORS disabled**
  (`config/initializers/cors.rb`). **CSRF** active everywhere; `null_session` only for OIDC
  backchannel; Palm uses header-token + `:exception`.
- **Palm** is correctly cookieless bearer-only: `request.session_options[:skip]=true`,
  `PalmAccessTokenAuthenticator` validates `aud=palm-api`
  (`app/controllers/palm/app/api/v0/base_controller.rb`).
- **Tier model** fails closed: undeclared endpoints resolve to `:deny_all`
  (`docs/architecture/controller-boundaries.md`,
  `app/controllers/concerns/authentication_base.rb:40-62`).

---

## 3. Findings

### BLOCKER

**B1 — Palm defines OAuth/OIDC callback routes the accepted ADR explicitly forbids.**

- Evidence: `config/routes/palm.rb:51-58` defines
  `palm_app_oauth_callback_ios GET /oauth/callback/ios` and
  `palm_app_oauth_callback_android GET /oauth/callback/android` (controllers
  `app/controllers/palm/app/oauth/callback/{ios,android}_controller.rb`). The ADR states verbatim:
  _"Palm must not add platform-specific OAuth/OIDC callback routes such as `/oauth/callback/ios`,
  `/oauth/callback/android`"_ (`adr/...port-boundary.md:146-152`) and _"Express those differences
  through client registration and request metadata"_.
- Why it matters: this is a direct violation of an accepted architecture boundary. Platform identity
  must live in `client_id`/`redirect_uri`/PKCE metadata, never in route paths. The controllers are
  inert today (skip session, `Cache-Control: no-store`, plain-text stub, no token exchange, no
  cookie — verified), so this is a boundary/contract defect, not an active exploit.
- Recommended fix (**preferred direction: remove routes + controllers**): delete the
  `namespace :callback do resources :ios/:android end` block from `config/routes/palm.rb`, keep the
  generic inert `GET /oauth/callback`, delete the two platform controllers, and add negative
  assertions to `test/integration/routes/palm_route_contract_test.rb` that the two paths no longer
  resolve. ADR caution (do not delete callback stubs before checking native registration / provider
  console / external docs / access logs) applies as an ops precondition; the _platform-specific_
  routes are "must not exist," so removal is the correct end state.
- Status: **left as follow-up** (audit-only pass).

### HIGH

**H1 — Refresh-token reuse detected but family-wide revocation on reuse is unconfirmed.**

- Evidence: `app/models/concerns/refresh_tokenable.rb:22-52` returns `{status: :replay}` when a
  rotated token is presented again, but the sweep did not confirm that detecting reuse **revokes the
  entire token family** (RFC 9700 revoke-on-reuse). It flags `rotated_at` and returns `:replay` to
  the caller.
- Why it matters: if a stolen refresh token is replayed and the family is not revoked, an attacker
  may retain a parallel valid chain. This is the one place where the otherwise-strong AS could leak.
- Recommended fix: add a focused test that proves replay of a rotated refresh token revokes the
  whole family (all generations invalid thereafter). If the test fails, implement revoke-on-reuse in
  `rotate_refresh!`/the exchange path. Verify the caller in
  `app/services/oidc_token_exchange_service.rb` acts on `:replay`.
- Status: follow-up (needs verification before asserting a defect).

### MEDIUM

**M1 — Base is an open `:bare` stub, not the authenticated control-plane the ADR assigns it.**

- Evidence: `config/routes/base.rb` exposes only `settings#show` (+ health/robots/sitemap/csp);
  `app/controllers/base/{app,com,org}/settings_controller.rb` inherit `BareController`,
  `AUTHENTICATION_MODE = :bare`, and render `plain: "Settings"`. No `/auth/*`, no login, no settings
  CRUD, no dashboard. The ADR (lines 42-46) assigns settings/preferences/account/org/admin to Base.
- Why it matters: Base cannot yet function as the classic RP control-plane; the control-plane
  currently lives under Acme (see M2). `:bare` is open (maps to `public_strict`), so the placeholder
  is anonymous-reachable — acceptable only because it renders nothing sensitive today, but the
  boundary is unfrozen. "Migration path … to the new component boundary" is an explicit Open Item in
  the port plan, so this is known debt, not a surprise.
- Recommended fix (freeze, don't migrate now): add a Base contract test asserting current reality —
  Base exposes no auth/token routes and mints no tokens — and a tracked follow-up for the Acme→Base
  settings move. Do **not** perform the large migration in a review pass.
- Status: follow-up.

**M2 — Acme and Sign carry near-duplicate full settings/credential CRUD trees (ownership
ambiguity).**

- Evidence: `config/routes/acme.rb:181-220` and `config/routes/sign.rb:215-268` both define
  passkeys/TOTP/secrets/emails/telephones/sessions/activities/withdrawal trees. Per the ADR, durable
  control-plane belongs to Base and credential ceremony belongs to Sign; Acme should be the AS/IdP.
- Why it matters: two surfaces owning overlapping settings invites drift and double-maintenance, and
  blurs the AS-vs-control-plane boundary the ADR draws.
- Recommended fix: document the intended owner per settings area (Sign = credential ceremony state;
  Base = durable account/preference control-plane; Acme = AS only) and add a boundary test freezing
  the split as it is decided. Track de-duplication with the M1 migration.
- Status: follow-up.

**M3 — Core Rails renders public HTML, contradicting "internal backend for future Next.js Core."**

- Evidence: `app/controllers/core/{app,com,org}/roots_controller.rb` render
  `template: "acme/<realm>/roots/index"` (full HTML landing) under `:open`. Core also serves
  `robots.txt`/`sitemap.xml` (`config/routes/core.rb`). Core's BFF API
  (`core/*/api/v0/base_controller.rb` + `CoreBrowserApiBoundary`) is correctly cookie-bound and
  bearer-rejecting — that part is fine.
- Why it matters: audit question 2 — Rails Core acting as the final public HTML owner competes with
  the future Next.js Core frontend and can split SEO/landing ownership.
- Recommended fix: treat the HTML landing as explicitly transitional; add a test that Core stays a
  thin landing and (separately) that Core exposes **no** AS/provider endpoints
  (`/authorize|/token|/userinfo|/oauth/*`) — the isolation negative test from the OIDC memo §H.
- Status: follow-up.

**M4 — `base-rails-rp` client name implies Base ownership but is handled entirely by Acme.**

- Evidence: `app/services/oidc_client_stores_static_client_store.rb:32,39` (client + `aud`),
  `app/controllers/acme/{app,com,org}/application_controller.rb` and
  `.../auth/callbacks_controller.rb` all reference `"base-rails-rp"`; redirect URIs point to Acme
  hosts; Base has no callback. This is Acme's own local-session RP login misnamed as Base's.
- Why it matters: identity confusion (flagged HIGH in the OIDC memo's risk table) — future work may
  wrongly treat Base as an RP or move the callback.
- Recommended fix (minimal): add an explicit comment at the client definition and callbacks
  declaring this is Acme's own browser RP; or rename to `acme-self-rp` with a prior check for stored
  `client_id = "base-rails-rp"` in token/code tables before any rename. Comment-only is the smallest
  safe correction.
- Status: follow-up.

**M5 — Test gaps that leave intended boundaries unfrozen.**

- Evidence (test inventory): Docs/Help/News have ~1 controller test file each; Base ~3; Palm ~3.
  Missing: Docs/Help/News non-RP contracts (mutations 404, no session, no auth cookies, read-only);
  Palm explicit no-cookie/session-rejection + non-`palm-api` audience rejection negatives; Base "no
  auth routes / mints no tokens"; per-surface credential isolation (cookie on `*.app` host not
  honored on `*.com` host). Strong areas already covered: `core_browser_api_boundary_test.rb`
  (cookie attrs, CSRF, audience binding), `palm_access_token_authenticator_test.rb`, route contract
  tests per surface.
- Why it matters: these are exactly the regressions that silently erode the surface boundaries this
  architecture depends on.
- Recommended fix: add the focused negative/contract tests listed above (highest value:
  Docs/Help/News non-RP, Palm no-cookie, Base no-tokens).
- Status: follow-up.

### LOW

**L1 — Dead duplicate userinfo controller.** Route resolves to `acme/app/oauth/userinfos#show`
(plural), but `app/controllers/acme/app/oauth/user_info_controller.rb` (singular
`UserInfoController`) also exists and is unrouted. Recommend: confirm zero references
(`grep -rn "UserInfoController\|user_info_controller" app test config`) and delete the dead file.

**L2 — Sign app vs com/org ceremony-controller placement inconsistency.** App-surface entrypoints
resolve to `sign/app/sign_ups#show` (no `sign` module segment) while com/org wrap in
`scope module: :sign` → `sign/com/sign/sign_ups#show` (`config/routes/sign.rb:39-40` vs `302-305`).
Cosmetic divergence; align both or document the intentional difference.

**L3 — Docs/Help/News `revisions` endpoints are stubs.** `revisions_controller` returns `[]`/`{}`
(intended content-backend future work). Note as incomplete-but-planned; ensure the read-only
contract test still pins method/shape so the stub can't silently become a mutation surface.

---

## 4. Audit-question verdicts (1–10)

1. **Roles separated?** Mostly yes. Acme=AS, Sign=ceremony RP, Palm=bearer RS, Docs/Help/News=JSON
   are clean. **Base under-built** (M1) and **Acme/Sign settings overlap** (M2) are the exceptions.
2. **Core acting as public classic RP?** Partially — HTML landing + robots/sitemap (M3); its BFF API
   layer is correctly internal/cookie-bound. Transitional, freeze with isolation test.
3. **Base complete as classic RP?** **No** — open `:bare` stub, no login, no CRUD (M1).
4. **Palm complete native RS?** Bearer/PKCE/no-cookie correct; **B1** route violation is the
   blocker; single protected endpoint (`profile`) is thin but acceptable for now.
5. **Side/Docs/Help/News non-RP?** Yes — `:bare`, read-only index/show, no mutations, no session;
   coverage thin (M5).
6. **Acme/Sign boundary clean?** **Yes** — Sign mints nothing; Acme is the sole issuer/AS.
7. **Cookies/scope/SameSite/Secure/HttpOnly/path/domain correct?** **Yes** — `__Host-`, host-only,
   Strict (Lax for session, justified), partitioned.
8. **Token/refresh/session/logout/revocation/JWKS/issuer/redirect_uri/client-auth/PKCE coherent?**
   **Yes**, with one open verification: refresh **revoke-on-reuse** family revocation (H1).
9. **Routes aligned, no dead/dangerous routes?** Mostly — **B1** (forbidden Palm routes), **L1**
   (dead userinfo). OIDC-cleanup Phases 1–3 already landed.
10. **Tests sufficient?** AS/cookie/core-boundary strong; **gaps** in Docs/Help/News, Base, Palm
    negatives, and per-surface isolation (M5).

---

## 5. Recommended follow-ups (Rails-only, not executed here)

Priority order: **B1** (remove Palm `/oauth/callback/{ios,android}` routes + controllers, add
negative route tests) → **H1** (prove/implement refresh revoke-on-reuse) → **M5** freeze tests
(Docs/Help/News non-RP, Palm no-cookie, Base no-tokens, per-surface cookie isolation) → **M3** Core
isolation + thin-landing tests → **M4** `base-rails-rp` comment/rename → **L1/L2/L3** cleanups →
**M1/M2** the Acme→Base control-plane migration (large; separate plan, out of review scope).

**Future Next.js / Cloudflare (explicitly not implemented now):** Core's final public
HTML/SEO/robots ownership moves to Next.js; Cloudflare edge cookie-stripping (Next.js zero-cookie
boundary) cannot be asserted from Rails and stays a deployment-contract concern.

**Verification when remediation is approved:** `bin/rails routes` (confirm B1 paths gone, isolation
holds), `bin/rails test test/integration/routes/ test/controllers/{palm,base,docs,help,news}` for
the focused suites, then `bin/rails test` and `vp test --coverage` for the full run and coverage
numbers.

---

## Scope guardrails honored

No Next.js/Cloudflare implementation; no new DBs; no Base→Next.js conversion; Palm stays cookieless;
Sign stays non-IdP; no casual `config/` edits (route-removal for B1 is the only recommended
config/routes change and is justified by the accepted ADR). This pass made **no code/route/test
changes** — audit report only.
