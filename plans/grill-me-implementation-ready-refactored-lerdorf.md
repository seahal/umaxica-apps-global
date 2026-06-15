# Grill Me: Implementation-Ready OIDC Logout / Route Boundary Review

## Context

Why this review exists:

- The Acme discovery document advertises `end_session_endpoint = {issuer}/oidc/logout`
  (`app/services/oidc_discovery_document.rb:18`, `app/services/oidc_issuer.rb:38`).
- The implementation at `app/controllers/concerns/sign_oidc_logout.rb` accepts only a
  project-private signed `logout_request` JWT, does not accept `id_token_hint`, rejects
  `post_logout_redirect_uri` outright with HTTP 400, ignores `state` and `ui_locales`, and is wired
  to `GET` only on each Acme sub-surface (`config/routes/acme.rb:100, 230, 376`).
- The accepted ADR `adr/logout-completion-boundary.md` and the active plan
  `plans/active/logout-state-machine-implementation-plan.md` (§Non-Negotiable Boundaries) forbid
  *arbitrary* `post_logout_redirect_uri` but explicitly allow "a signed RP logout request permits a
  known behavior" — which is exactly what an exact-match allowlist against registered client
  metadata is.
- The discovery doc therefore claims OIDC RP-Initiated Logout 1.0 conformance that the
  implementation does not deliver. A third-party RP following the spec cannot interoperate.

Intended outcome:

- Decide whether to spec-align the advertised `end_session_endpoint`, or unadvertise it and rename
  the private flow.
- Make that decision *implementable in safe slices*, not in a single large refactor.
- Hold the Acme/Sign/Core/Palm boundary while doing it — no new Sign session authority, no new
  Palm OP authority.

Scope discipline:

- This file is the plan, not the implementation. Per `.agents/harnesses/rules/`, the first slice (A-E) is
  the only thing the next agent is authorized to ship; everything else is deferred backlog with
  explicit triggers.

---

## 0. Executive Verdict

**WARN — implementable with a narrow P0 slice (Slice A-E).**

The pipeline is sound on the parts that matter most for security (CSRF, token-only revocation
endpoint, no Palm OP authority, Sign as non-IdP). The one acute risk is *discovery–implementation
drift*: Acme advertises a standard OIDC logout endpoint that does not behave like one.

Top 5 blockers (must be resolved or explicitly deferred before merging Slice A-E):

1. **`end_session_endpoint` is GET-only and non-conforming to OIDC RP-Initiated Logout 1.0.** The
   discovery doc promises a standard endpoint; the implementation is a private JWT-only flow.
   Confirmed: `app/services/oidc_discovery_document.rb:18`,
   `app/controllers/concerns/sign_oidc_logout.rb:7-26`, `config/routes/acme.rb:100, 230, 376`.
2. **No registered storage for `post_logout_redirect_uri`.** `OidcClientRegistry` is config-based
   (`app/services/oidc_client_registry.rb:127-234`) and currently has only `redirect_uris`, not
   `post_logout_redirect_uris`. Slice C must extend this map; no DB migration is required.
3. **No `id_token_hint` verifier reuse pathway identified.** `OidcIdTokenVerifier` and
   `SecurityJwtOidcIdTokenCodec` exist, but the OIDC logout concern does not call them. Slice B
   needs to wire them in without weakening replay protection on the existing `logout_request` path.
4. **ADR/plan wording is ambiguous about exact-match allowlisted `post_logout_redirect_uri`.**
   `adr/logout-completion-boundary.md` ¶22-26 and `plans/active/logout-state-machine-implementation-plan.md:44-45`
   say *no arbitrary* `post_logout_redirect_uri` but allow "a signed RP logout request permits a
   known behavior." A short ADR note clarifying that exact-match allowlist *is* the "known
   behavior" boundary closes this gap without a full supersession. Required before Slice C ships.
5. **Sign `Sign::*::In::SessionsController#destroy` calls `AuthenticationLogoutCurrentSession.call`
   directly** (verified by recon, also matched by existing test
   `test/controllers/concerns/authentication/logout_current_session_test.rb`). This is a known
   boundary exception for session-limit cancellation. Out of scope for Slice A-E, but must be
   pinned by ADR exception (Slice G) before any further normalization in that area.

---

## 1. Corrected Severity Matrix

Severity model:

- **P0** = standard-advertised endpoint is non-conforming, security issue, or implementation cannot
  interoperate.
- **P1** = boundary violation, ambiguous ownership, duplicate destructive route, or missing tests
  for critical logout behavior.
- **P2** = documentation gap, future feature, optional spec support, or non-critical route debt.
- **Info** = confirmed acceptable or deliberately out of scope.

| ID | Finding | Severity | Adopt / Reject / Defer | Reason | Implementation slice |
|----|---------|----------|------------------------|--------|----------------------|
| F1 | `end_session_endpoint` GET-only | **P0** | Adopt | Spec §3 requires both GET and POST on the OP endpoint. Discovery doc advertises it. | Slice A |
| F2 | No `id_token_hint` accepted/verified | **P0** | Adopt | Spec §2 RECOMMENDED parameter; absence prevents standard RPs from authenticating the request. | Slice B |
| F3 | `post_logout_redirect_uri` rejected outright | **P0** | Adopt | Spec §2 allows it with exact-match against registered URIs. Current behavior returns HTTP 400. | Slice B + Slice C |
| F4 | Private `logout_request` JWT is the sole input | **P0** | Adopt | Spec drift: standard parameters must be primary; private JWT becomes optional compat path only. | Slice B |
| F5 | `/oauth/revoke` clean separation from logout | **Info** | Confirmed acceptable | Token-only revocation via `BareController`, no browser session mutation, client-authenticated; exists only on Acme app/com/org. | None |
| F6 | Acme `/sso/logout` exists alongside `/oidc/logout` and `/sign/out` | **P1** | Defer | `Acme::*::Sso::LogoutsController` includes `OidcRpLogout` (RP-flavored). Suspicious on IdP surface but not unsafe. Needs decision (rename, delete, or document). | Slice F |
| F7 | Acme `/sign/out` exposes GET/POST/PATCH/DELETE (4 verbs) | **P1** | Defer | `Acme::*::SignOutsController` wires `show`, `edit`, `create`, `destroy`. Two destructive verbs (POST + DELETE) without documented semantic distinction; PATCH is suspicious. | Slice F |
| F8 | Sign `Sign::*::In::SessionsController#destroy` mutates session state | **P1** | Defer | Calls `AuthenticationLogoutCurrentSession.call` for session-limit cancellation. Predates `acme-sign-core-base-port-boundary.md` (2026-06-12). Needs ADR exception. | Slice G |
| F9 | Sign `/sign/out` is redirect-only with 4 verbs | **P2** | Defer | Recon found `/sign/out` not declared in `config/routes/sign.rb`; only `/signed-out` (GET) is. Acme `/sign/out` is the actual destructive route. If a Sign-side redirect entry remains, collapse to GET-only. | Slice F |
| F10 | Palm has `/oauth/callback*` only; no logout/revoke | **Info** | Confirmed acceptable | `palm/app/oauth/callbacks_controller.rb` is a stub. Native clients must use Acme `/oauth/revoke` and (post-Slice E) Acme `/oidc/logout`. Needs short doc. | Slice H |
| F11 | No back-channel logout implementation | **P2** | Defer | Not advertised in discovery (`backchannel_logout_supported` absent), no doc promises real-time logout. `Oidc::BackchannelLogoutNotifier` namespace reserved per `adr/logout-primitive-and-composition.md` but empty. Acceptable. | Documented; no slice |
| F12 | Multi-surface logout semantics undocumented | **P2** | Defer | Per-surface by design; logout from `app` does not affect `com`/`org`. No global-logout promise in stable docs. Needs explicit doc. | Slice I (note only) |
| F13 | `edge/v0` routes still present | **P2** | Defer | Confirmed at `config/routes/acme.rb:59-69, 210-220, 356-366`, `config/routes/core.rb:26-31, 74-78, 123-127`, `config/routes/sign.rb:43-50, 263-270, 440-447`. Out of scope for logout. | Slice I (backlog) |

---

## 2. Canonical Route Contract

Desired shape after cleanup. Each line is annotated **keep / rename / delegate / deprecate / remove**.

### Acme (OP / Authorization Server)

| Path | Verbs | Action | Status |
|------|-------|--------|--------|
| `/.well-known/openid-configuration` | GET | discovery | **keep** |
| `/.well-known/jwks.json` | GET | jwks | **keep** |
| `/oauth/authorize` | GET | authorization | **keep** |
| `/oauth/token` | POST | token | **keep** |
| `/oauth/userinfo` | GET | userinfo | **keep** |
| `/oauth/revoke` | POST | token revocation (client-authenticated, `BareController`) | **keep** |
| `/oidc/logout` | **GET + POST** | OIDC RP-Initiated Logout 1.0 (after Slice A) | **keep + extend** |
| `/sign/out` | GET, DELETE | Acme-internal human logout UI: GET = confirmation, DELETE = mutation | **rename or trim** (Slice F) |
| `/sign/out` (POST) | — | duplicate destructive verb | **remove** (Slice F) |
| `/sign/out` (PATCH) | — | unused verb | **remove** (Slice F) |
| `/sso/logout` | POST | currently RP-flavored on IdP surface | **decide** (Slice F): remove, delegate to `/oidc/logout`, or rename to clarify intent |

### Sign (credential-gateway only)

| Path | Verbs | Action | Status |
|------|-------|--------|--------|
| `/.well-known/jwks.json` | GET | RP jwks | **keep** |
| `/signed-out` | GET | static guest page (per `adr/logout-completion-boundary.md` ¶42-53) | **keep** |
| `/auth/callback` | GET | OIDC RP callback | **keep** |
| `/sign/out` | — | **not currently routed in `config/routes/sign.rb`** — confirm and either remove or, if present elsewhere, collapse to GET-only redirect | **deprecate** (Slice F) |

### Core (RP BFF, local logout only)

| Path | Verbs | Action | Status |
|------|-------|--------|--------|
| `/sso/authorize` | GET | RP-side SSO start | **keep** |
| `/sso/logout` | POST | RP-local logout (clears local session/cookies; does not call Acme revoke) | **keep** |
| `/auth/callback` | GET | OIDC RP callback | **keep** |
| `/api/v0/...` | various | RP BFF | **keep** |
| `/edge/v0/...` | various | legacy cookie/dbsc shims | **deprecate** (Slice I) |

### Palm (native bearer-token API)

| Path | Verbs | Action | Status |
|------|-------|--------|--------|
| `/oauth/callback`, `/oauth/callback/ios`, `/oauth/callback/android` | GET | native deep-link bridge stub | **keep, but document as native bridge only** (Slice H) |
| `/oauth/revoke` | — | NOT to be added; native clients call Acme | **explicitly absent** |
| `/oidc/logout` | — | NOT to be added; native clients call Acme | **explicitly absent** |
| `/api/v0/...` | various | resource server | **keep** |

### Help / Docs / News / Base

No logout, revocation, or OIDC endpoints. Confirmed clean. Out of scope.

---

## 3. Implementation-Ready Slices

### Slice A: OIDC end_session route contract

- **Priority:** P0
- **Files to inspect:** `config/routes/acme.rb:96-110` (app), `:226-240` (com), `:372-386` (org); `app/controllers/acme/app/oidc/logouts_controller.rb` and com/org siblings.
- **Files to edit:** `config/routes/acme.rb` for all three Acme sub-surfaces; the three `acme/{app,com,org}/oidc/logouts_controller.rb` files.
- **Changes:**
  - Replace `resource :logout, only: :show, ...` (currently GET-only) with `resource :logout, only: [:show, :create], ...` so both `GET /oidc/logout` and `POST /oidc/logout` route to the same controller.
  - In each controller, alias `def create; show; end` (delegate) for the parsing path — the verb decision is made in the concern (Slice B), not the controller.
  - Preserve `protect_from_forgery with: :exception` posture inherited from `ApplicationController`. The OIDC logout endpoint accepts cross-origin POST from RPs that supply a verified `id_token_hint` — explicit POST handling needs `skip_forgery_protection if: ->{ valid_id_token_hint? }` or equivalent narrow exception scoped to OIDC logout only. Decision goes in Slice B; Slice A only opens the route.
- **Tests:** None added in Slice A — route shape is verified by Slice E's controller tests.
- **Acceptance criteria:**
  - `bin/rails routes` (run via `podman compose exec <rails-service>`) shows both GET and POST for `/oidc/logout` on app, com, and org.
  - Route helpers `acme_{app,com,org}_oidc_logout_path` continue to resolve.
  - No existing tests break.
- **Non-goals:** Parameter handling, redirect URI validation, ID token verification.
- **Migration required:** No.
- **Risk:** Low. Route addition only.

### Slice B: OIDC logout request parser/validator

- **Priority:** P0
- **Files to inspect:** `app/controllers/concerns/sign_oidc_logout.rb` (entire file), `app/services/oidc_id_token_verifier.rb`, `app/services/security_jwt_oidc_id_token_codec.rb`, `app/services/oidc_logout_request.rb`, `app/services/oidc_client_registry.rb`.
- **Files to edit:** `app/controllers/concerns/sign_oidc_logout.rb`. Possibly a new service `app/services/oidc_end_session_request.rb` that encapsulates parameter parsing and decides which path to take.
- **Changes:**
  - Add a new service that, given the params hash, returns a `Result` with: `client_id`, `subject`, `sid`, `post_logout_redirect_uri` (validated or nil), `state`, `ui_locales`, `requires_confirmation` (bool).
  - **Acceptance precedence:** if `id_token_hint` is present, verify it via `OidcIdTokenVerifier`/`SecurityJwtOidcIdTokenCodec` (sig + iss + aud + exp; `sub`/`sid` extracted). Use `client_id` either from the param or from the verified `aud` claim. If verification fails → confirmation page, **not** silent logout.
  - **Compat path:** if `id_token_hint` is absent and `logout_request` is present, fall back to `OidcLogoutRequest.verify` (existing JWT). Treated as compat-only — log a deprecation event at `info` level (not the token value).
  - **Missing both `id_token_hint` and `logout_request`:** render confirmation page (a new view) that explains the request and requires explicit POST confirmation. Never silent-logout on a bare GET with no hint.
  - **CSRF posture:** when a verified `id_token_hint` is present on a POST, skip CSRF — protocol-authenticated. When neither hint is present and the confirmation page submits, normal CSRF applies. The narrow `skip_forgery_protection if: ...` predicate must check verification success, not just parameter presence.
  - Move the rendering helpers (`invalid_post_logout_redirect_uri`, `invalid_logout_request`) into the same concern, replacing them with standard OIDC error responses (`invalid_request`, `unauthorized_client`).
- **Tests:** Covered by Slice E.
- **Acceptance criteria:**
  - `id_token_hint` path: valid → proceed to logout; invalid sig → confirmation; missing → confirmation.
  - `logout_request` path: continues to work for existing internal RP callers; emits compat-deprecation telemetry.
  - Parameter parsing is centralized in one new service object; no controller business logic.
- **Non-goals:** Storing `post_logout_redirect_uri` allowlist (Slice C); route changes (Slice A); discovery doc updates (Slice D).
- **Migration required:** No.
- **Risk:** Medium. Touches the security-critical hot path. Must preserve fail-closed behavior of the existing `OidcLogoutRequest.verify` replay-cache logic.

### Slice C: post_logout_redirect_uri allowlist

- **Priority:** P0
- **Files to inspect:** `app/services/oidc_client_registry.rb:127-234`, `app/services/oidc_client_registry.rb:236-...` (helpers).
- **Files to edit:** `app/services/oidc_client_registry.rb`. Add an optional `post_logout_redirect_uris:` field per client entry, populated from env vars analogous to `build_redirect_uris`. Add a public helper `valid_post_logout_redirect_uri?(client_id:, uri:)` modeled on the existing `valid_redirect_uri?`.
- **Changes:**
  - Per-client config gets `post_logout_redirect_uris:` (Array<String>). For dev defaults: `build_post_logout_redirect_uris("SIGN_SERVICE_URL", "id.app.localhost")` resolving to `{scheme}://{host}{:port}/signed-out` per surface, mirroring the existing `redirect_uris` builder shape.
  - `valid_post_logout_redirect_uri?` does exact string match, no normalization (per spec).
  - In the new `OidcEndSessionRequest` service (Slice B), if `post_logout_redirect_uri` param is present, require an exact match against the resolved client's allowlist. Mismatch → render an error page on Acme, **never** redirect to the supplied URI.
  - If `state` is present, it round-trips only if the redirect URI validates.
- **Tests:** Covered by Slice E.
- **Acceptance criteria:**
  - Registered URI: redirect with `state` echoed.
  - Unregistered URI: error page on Acme, no redirect, no `state` leak.
  - Missing `post_logout_redirect_uri`: fall back to existing internal completion path (`oidc_logout_completed_path`).
- **Non-goals:** DB-backed RP registration (out of scope; the registry is config-backed by design — see "Stop Conditions" if this ever becomes load-bearing).
- **Migration required:** No.
- **Risk:** Low. New code path, additive.

### Slice D: discovery metadata consistency

- **Priority:** P0
- **Files to inspect:** `app/services/oidc_discovery_document.rb:10-26`, `app/services/oidc_issuer.rb:22-53`.
- **Files to edit:** `app/services/oidc_discovery_document.rb`.
- **Changes:**
  - After Slices A-C, the existing advertised `end_session_endpoint` becomes accurate. No discovery URL change.
  - Do **not** add `backchannel_logout_supported` or `frontchannel_logout_supported`. Leave both absent (interpreted as `false`).
  - Optional: add `end_session_endpoint_auth_methods_supported` if the spec extension is in use; not required.
- **Tests:** A request-spec test that fetches `/.well-known/openid-configuration` on each Acme sub-surface and asserts:
  - `end_session_endpoint` present and matches the routed path.
  - `backchannel_logout_supported` and `frontchannel_logout_supported` absent.
- **Acceptance criteria:**
  - Discovery doc matches route reality.
  - No false advertisement of unsupported logout features.
- **Non-goals:** Implementing back-channel/front-channel logout.
- **Migration required:** No.
- **Risk:** Low. Documentation-shaped change.

### Slice E: OIDC logout controller tests for app/com/org

- **Priority:** P0
- **Files to edit:** new test files —
  - `test/controllers/acme/app/oidc/logouts_controller_test.rb`
  - `test/controllers/acme/com/oidc/logouts_controller_test.rb`
  - `test/controllers/acme/org/oidc/logouts_controller_test.rb`
- **Changes:** Cover the Test Matrix below (Section 5) symmetrically across the three sub-surfaces. Reuse fixtures from existing OIDC tests; no new fixtures unless `post_logout_redirect_uris` config requires environment seeding.
- **Acceptance criteria:**
  - All matrix cases pass on all three sub-surfaces.
  - GET path does not mutate when no hint is present (confirmation rendered, session/token row unchanged).
  - Invalid `id_token_hint`: no mutation, confirmation rendered.
  - Invalid `post_logout_redirect_uri`: error rendered, no redirect.
  - Valid `state` returned only on successful redirect.
  - Legacy `logout_request` JWT path continues to pass an explicit "compat" test (must not regress).
- **Non-goals:** Coverage for `/sso/logout`, `/sign/out`, Sign session-limit destroy.
- **Migration required:** No.
- **Risk:** Low. Test-only.

### Slice F: Acme /sso/logout vs /sign/out decision (deferred)

- **Priority:** P1
- **Decision required, no code in this slice.** Either:
  - Remove `Acme::*::Sso::LogoutsController` (it currently includes `OidcRpLogout`, which is an RP concern). The IdP surface should not need an RP-flavored local logout.
  - Or rename/repurpose to clarify intent (e.g., `Acme::*::Sso::LocalLogoutsController` with explicit doc that it is for non-OIDC fallback).
- **Also decide:** Acme `/sign/out` exposes GET/POST/PATCH/DELETE (`acme/{app,com,org}/sign_outs_controller.rb`). Reduce to GET (confirmation) + DELETE (mutation). Remove POST and PATCH unless a documented caller exists.
- **Trigger to revisit:** After Slice A-E is in production for one release cycle.

### Slice G: Sign mutation exception (deferred)

- **Priority:** P1
- **Recommended:** **Option B — keep as explicit ADR exception.** Move-to-Acme (Option A) requires inventing a thin Acme endpoint for session-limit cancellation that does not exist today and would couple Sign sign-in UX to an Acme round-trip. Delegate-via-POST (Option C) is even worse — a Sign-side controller posting to Acme with a forged session cookie is exactly the cross-surface state mixing the boundary rules forbid.
- **Why Option B:** `Sign::*::In::SessionsController#destroy` mutates only the *restricted* token belonging to the current Sign-in cycle; it is not general logout. It is a session-limit *cancellation*, semantically owned by the sign-in ceremony. The mutation is bounded.
- **Action:** Add an ADR `adr/sign-session-limit-cancellation-exception.md` that names this specific method and forbids its pattern from spreading.
- **Trigger to revisit:** If session-limit cancellation needs to revoke more than the in-flight restricted token.

### Slice H: Palm / native policy docs (deferred)

- **Priority:** P2
- **Files to edit:** new `docs/security/native-client-logout.md`.
- **Content:**
  - Palm exposes no OAuth/OIDC authority endpoints.
  - Native clients (iOS, Android) use Acme `/oauth/revoke` for token revocation and Acme `/oidc/logout` for end-session.
  - Palm `/oauth/callback*` routes are deep-link bridges only.
- **Trigger to revisit:** When native client behavior changes.

### Slice I: Route debt backlog (deferred)

- **Priority:** P2
- **Items:**
  - `edge/v0` routes: enumerate, decide rename/remove. Tracked separately from logout work.
  - Multi-surface logout semantics: add a paragraph to `docs/security/logout-sequence.md` stating per-surface scoping is intentional, not a bug.
- **Trigger:** Independent project, not blocking Slice A-E.

---

## 4. Prompt to Implement Slice A-E Only

> Copy-paste-ready prompt for the next agent. **Do not paraphrase.**

```
You are implementing OIDC RP-Initiated Logout 1.0 spec alignment for Acme in the umaxica-apps-global
repository. Read the plan at plans/grill-me-implementation-ready-refactored-lerdorf.md sections
0-5 before doing anything. Implement only Slices A, B, C, D, E. Do not implement Slices F, G, H, I.

## Hard Constraints

- Do not run bin/rails, bundle exec rails, rails, or ruby directly on the host.
- Do not run docker or docker compose.
- All Rails commands MUST go through Podman compose: first `podman compose ps` to discover the
  service name, then `podman compose exec <rails-service> bin/rails ...`.
- Do not modify routes, controllers, services, or tests outside the Acme OIDC logout flow
  (acme/{app,com,org}/oidc/logouts*, app/controllers/concerns/sign_oidc_logout.rb, app/services/oidc_*,
  config/routes/acme.rb in the /oidc/logout lines only, app/services/oidc_client_registry.rb).
- Do not touch Sign, Core, Palm controllers or routes.
- Do not touch /oauth/revoke or /sso/logout or /sign/out.
- Do not modify ADRs or stable docs. If you find an ADR conflict, stop and report.
- Do not remove the existing logout_request JWT compat path. Keep it as the fallback when
  id_token_hint is absent.
- No DB migration. The redirect URI allowlist lives in OidcClientRegistry config, not in a model.

## Desired Route Shape (Slice A)

For each of acme/{app,com,org} in config/routes/acme.rb, change:
  resource :logout, only: :show, path: "logout", controller: "logouts"
to:
  resource :logout, only: [:show, :create], path: "logout", controller: "logouts"

The route helper acme_{app,com,org}_oidc_logout_path must continue to resolve. Both verbs route to
the same controller. The controller's #create delegates to #show.

## Controller/Service Design (Slice B)

- Add app/services/oidc_end_session_request.rb. Public surface:
    OidcEndSessionRequest.call(params:, request:) -> Result
  Result fields: success?, client, post_logout_redirect_uri (validated or nil), state, ui_locales,
  requires_confirmation?, error_code, error_description, source (:id_token_hint | :logout_request |
  :no_hint).

- The service:
  1. If params[:id_token_hint] is present, decode/verify via SecurityJwtOidcIdTokenCodec. On
     verification failure, return Result with requires_confirmation? = true and source =
     :id_token_hint.
  2. Else if params[:logout_request] is present, verify via OidcLogoutRequest. Emit a structured
     compat-deprecation event at info level (no token bytes, no params). source = :logout_request.
  3. Else, return requires_confirmation? = true with source = :no_hint.
  4. Resolve client via OidcClientRegistry.find using either the verified aud claim or
     params[:client_id]. If both are present and disagree, return error.
  5. If params[:post_logout_redirect_uri] is present, call
     OidcClientRegistry.valid_post_logout_redirect_uri?(client_id:, uri:). On mismatch, return
     error (do not redirect anywhere).
  6. Carry params[:state] only if the redirect URI validated.

- Rewrite app/controllers/concerns/sign_oidc_logout.rb to delegate to the new service. On
  requires_confirmation? render a new view test/fixtures/views/acme/{app,com,org}/oidc/logouts/show.html.erb
  with a POST form back to the same path including the original params (state, post_logout_redirect_uri,
  client_id, id_token_hint or logout_request). On success, call log_out and redirect.

- CSRF: keep protect_from_forgery from ApplicationController. Skip forgery on POST only when a
  verified id_token_hint is present (predicate-based skip_forgery_protection in the controller).

## Allowlist Storage (Slice C)

In app/services/oidc_client_registry.rb:
- Add `post_logout_redirect_uris:` to each client entry that needs it, using a new helper
  `build_post_logout_redirect_uris(env_key, default_host)` analogous to the existing
  `build_redirect_uris`. Default path is "/signed-out".
- Add public class method:
    OidcClientRegistry.valid_post_logout_redirect_uri?(client_id:, uri:)
  Exact string match, no normalization.

## Discovery (Slice D)

Update app/services/oidc_discovery_document.rb only to add a test confirming end_session_endpoint
matches the route. Do not add backchannel_logout_supported or frontchannel_logout_supported.

## Tests (Slice E)

Create new test files for each of acme/{app,com,org}:
  test/controllers/acme/app/oidc/logouts_controller_test.rb
  test/controllers/acme/com/oidc/logouts_controller_test.rb
  test/controllers/acme/org/oidc/logouts_controller_test.rb

Cover all cases in the plan's Section 5 Test Matrix. Run via:
  podman compose exec <rails-service> bin/rails test test/controllers/acme/app/oidc/logouts_controller_test.rb
(and com, org). Also run the full OIDC test suite to ensure no regression in OidcLogoutRequest
behavior:
  podman compose exec <rails-service> bin/rails test test/services/oidc/

## Acceptance Criteria

- Discovery doc end_session_endpoint matches a route that accepts both GET and POST.
- GET without any hint → renders confirmation page (no mutation, no cookie clear).
- POST with verified id_token_hint and registered post_logout_redirect_uri → mutation + redirect
  with state echoed.
- POST with verified id_token_hint and unregistered post_logout_redirect_uri → 400 with no redirect.
- POST with invalid id_token_hint signature → confirmation page, no mutation.
- Legacy logout_request JWT path: existing test test/services/oidc/logout_request_test.rb still
  passes unchanged.
- New tests cover all rows of Section 5 Test Matrix.

## Stop Conditions (do not guess; stop and report)

- If you find that OidcClientRegistry is no longer config-based (e.g., backed by a DB model now),
  stop and report.
- If you find that SecurityJwtOidcIdTokenCodec does not expose a verify-with-allow-expired or
  verify-strict mode appropriate for logout, stop and report.
- If you find that an existing test asserts /oidc/logout is intentionally private (e.g., a test
  named "oidc logout is project-private" or asserting that id_token_hint is rejected), stop and
  report.
- If env-var-based default hosts in OidcIssuer produce a localhost issuer in production-like
  config, stop and report.
- If the app/com/org sub-surfaces are not symmetric (e.g., com lacks a route present on app), stop
  and report — the audit assumed symmetry.

## Final Step

After all tests pass, write a short note at notes/implementation/<YYYY-MM-DD>-oidc-end-session-spec-alignment.md
describing what was done, what was deferred (Slices F, G, H, I), and which existing files were
not touched. Do not commit; let the human review the diff first.
```

---

## 5. Test Matrix

| # | Case | Request | Expected |
|---|------|---------|----------|
| T1 | GET, no params | `GET /oidc/logout` | 200, confirmation page rendered, no session mutation, no cookie cleared |
| T2 | POST, no params | `POST /oidc/logout` | 200 confirmation page (or 400 if confirmation page UX deems POST without any hint invalid); no silent logout |
| T3 | Valid `id_token_hint`, no redirect | `GET /oidc/logout?id_token_hint=<valid>` | 200 confirmation page if confirmation is required by policy; or 303 to internal completion if policy is "auto on valid hint" — pick one and pin it. Test both branches if the policy is configurable. |
| T4 | Valid `id_token_hint` via POST | `POST /oidc/logout` body `id_token_hint=<valid>` | 303 to internal completion; session/token row mutated; cookies cleared |
| T5 | Invalid `id_token_hint` signature | `POST /oidc/logout` body `id_token_hint=<tampered>` | Confirmation page or 400; no mutation |
| T6 | `id_token_hint` with mismatched `sid`/`sub` | `POST /oidc/logout` body `id_token_hint=<valid but other user>` | Confirmation page or 400; no mutation |
| T7 | Valid `post_logout_redirect_uri` (registered) | `POST /oidc/logout` body `id_token_hint=<v>&post_logout_redirect_uri=<registered>&state=xyz` | 303 to the registered URI with `state=xyz` appended |
| T8 | Invalid `post_logout_redirect_uri` (unregistered) | `POST /oidc/logout` body `id_token_hint=<v>&post_logout_redirect_uri=https://attacker.example/` | 400, error rendered on Acme, no redirect, no `state` echoed |
| T9 | `state` with valid redirect | covered in T7 | `state` appears in `Location` |
| T10 | `state` with invalid redirect | covered in T8 | `state` does not appear in any response header |
| T11 | Legacy `logout_request` JWT | `GET /oidc/logout?logout_request=<existing-signed-token>` | 303 to existing internal completion path; compat-deprecation telemetry emitted at info level |
| T12 | `/oauth/revoke` unchanged | `POST /oauth/revoke` with `token`, `client_id`, `client_secret` | 200 (success) or 401 (auth failure) — pre-existing behavior pinned |
| T13 | Core `/sso/logout` unchanged | `POST /sso/logout` on Core | Local RP logout only; no Acme call |
| T14 | Palm `/oauth/callback` unchanged | `GET /oauth/callback` on Palm | Stub message, not OP authority |

Likely test files (per Slice E):

- `test/controllers/acme/app/oidc/logouts_controller_test.rb`
- `test/controllers/acme/com/oidc/logouts_controller_test.rb`
- `test/controllers/acme/org/oidc/logouts_controller_test.rb`
- `test/services/oidc/end_session_request_test.rb` (new — covers the new service in isolation)

Existing files to leave alone:

- `test/services/oidc/logout_request_test.rb` (must continue to pass unchanged)
- `test/services/oidc_token_revocation_service_coverage_test.rb`
- `test/controllers/concerns/authentication/logout_*_test.rb`
- `test/controllers/sign/oidc_logouts_controller_test.rb` (asserts Sign-side OIDC logout is retired — keep)

---

## 6. Stop Conditions

The implementer must stop and report (do not guess) if:

1. **No registered `post_logout_redirect_uri` storage exists.** Status: storage exists in
   `OidcClientRegistry` (config-based); Slice C extends it. If a future refactor moves it to a DB
   model first, the implementer must update this plan rather than improvising.
2. **ID token verification service does not exist.** Status: `OidcIdTokenVerifier` and
   `SecurityJwtOidcIdTokenCodec` exist. Creating new verification logic for logout would be a
   broad cross-cutting change and is forbidden.
3. **Discovery endpoint is generated from env fallback that may produce `localhost` in production.**
   Status: `OidcIssuer.host_for_resource_type` resolves hosts from `ACME_*_URL` env vars
   (`app/services/oidc_issuer.rb:45-53`). If production deployment is found to leak a localhost
   fallback, stop and escalate before shipping discovery doc changes.
4. **Current tests prove `/oidc/logout` is intentionally private protocol.** Status: no such test
   found. The Sign-side `test/controllers/sign/oidc_logouts_controller_test.rb` asserts the
   Sign-side route is *retired*, not that the Acme-side is private. If new tests assert the
   Acme-side is intentionally private, stop and confirm with the human.
5. **Changing route helpers would break existing callbacks.** Status: route helper names are
   preserved by adding `:create` to an existing `resource :logout, only: :show`. If the new shape
   renames any existing helper, stop.
6. **DB migration appears necessary.** Status: not expected. The allowlist lives in
   `OidcClientRegistry` config. If the implementer reaches for a migration, stop and escalate.
7. **app/com/org surfaces are not symmetric.** Status: symmetric per recon. If a sub-surface
   deviates, stop.

---

## 7. Final Recommendation

**Recommended first implementation:**

- Slice A-E only. This closes the discovery-implementation drift, lets standard RPs interoperate,
  preserves the existing internal `logout_request` JWT path as compat, and ships behind a Test
  Matrix that pins the security-critical behaviors (no GET mutation, no redirect to unregistered
  URIs, no `state` leak on invalid redirects, no silent logout on missing/invalid hints).

**Do not implement yet:**

- Back-channel logout (F11). Not advertised, not promised — P2 only.
- Front-channel logout. Not advertised, not promised — P2 only.
- Palm revocation/logout (F10). Native clients use Acme endpoints; Palm policy doc (Slice H) is
  P2.
- Cross-surface global logout (F12). Per-surface semantics are intentional; doc note only (Slice
  I).
- `edge/v0` migration (F13). Independent route debt; Slice I.
- Sign durable-settings migration. Out of scope for this audit.
- Acme `/sso/logout` removal / `/sign/out` verb pruning (F6, F7). Deferred to Slice F after Slice
  A-E ships.
- Sign session-limit ADR exception (F8). Deferred to Slice G.

**Reason:**

The advertised OIDC `end_session_endpoint` is the current interoperability/spec risk. Everything
else is either correct (revocation separation, Palm boundary, no false advertisement of
back-channel logout) or a documentation/decision gap that is safe to defer. Slice A-E is the
minimum coherent change that closes the spec drift without touching boundaries that are already
correctly held.

---

## Appendix: Confidence Labels

- F1, F2, F3, F4, F5, F10, F11, F13: **Confirmed** by static analysis of files cited in §0 and §1.
- F6: **Confirmed** route shape; **Needs implementation decision** for keep/rename/remove.
- F7: **Confirmed** four verbs are wired in `Acme::*::SignOutsController`; **Needs implementation
  decision** for which to prune.
- F8: **Confirmed** call site; **Needs ADR decision** for exception wording.
- F9: **Likely** — recon noted Sign `/sign/out` is not declared in `config/routes/sign.rb` but is
  referenced elsewhere; implementer should confirm before acting on Slice F.
- F12: **Confirmed** absence of documented multi-surface logout policy.
