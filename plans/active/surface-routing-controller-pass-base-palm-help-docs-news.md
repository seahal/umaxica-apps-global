# Acme / Sign / Core / Base / Palm / Help / Docs / News — Routing Surface Audit & Minimal Plan

## Context

Before Acme/RP integration work begins, the Rails routing/controller surface must be prepared for
the accepted boundary: **Acme** (sole IdP/Authorization Server), **Sign** (special RP, _not_ an
IdP), **Core** (Next.js Core Web RP/BFF + Rails Core backend), **Base** (Rails control-plane),
**Palm** (native bearer-token API, formerly "Port"), and **Help/Docs/News** (informational).

This document is an **investigation + plan**. The near-term goal is narrow: every Rails surface
should expose a simple 200 root message via a **BareController-style** controller (no DB, no Rails
browser session, no authenticated actor). No Acme/RP/Palm auth integration, no Next.js, no
redirects, no new databases in this pass.

Decisions confirmed with the user this session:

- New surfaces (Base, Palm, Help, Docs, News) are each scaffolded as **app/com/org triples**.
- Each new surface gets **root + health + robots** in this pass.
- Existing Acme/Sign/Core roots are **left untouched** (they already return 200).

---

## Executive Summary

- **Acme, Sign, Core exist** as full surfaces with app/com/org variants (Acme also has net/dev).
  Each variant has a surface-local `ApplicationController < ActionController::Base`, a
  `BareController < ActionController::Base`, a `RootsController`, plus health/robots/sitemap.
- **Base, Palm/Port, Help, Docs, News do NOT exist** as routes or controllers. Help/Docs/News and
  Core appear _only_ as OIDC client-registry entries; Port/Base appear _only_ in ADR/docs/plans.
- The **existing root controllers are NOT bare**: `Acme/Sign/Core *::RootsController` inherit the
  surface `ApplicationController` (full pipeline: `Session`, `AuthenticationClient`, `ActorSupport`,
  `set_current_actor`, `transparent_refresh_access_token`, `enforce_access_policy!`,
  `with_actor_lifecycle`). `AUTHENTICATION_MODE = :open` only relaxes the _authorization gate_; the
  session/actor/DB pipeline still runs. → For the new surfaces' no-DB/no-session roots,
  **BareController is the correct (and required) parent**, mirroring how `robots`/`health` already
  work today.
- **Palm vs Port is decided** (Palm is the accepted name). No code uses "Port" yet, so Palm is built
  fresh; Port references in `adr/docs/plans/memos` are historical (supersession-banner candidates),
  not a rename target this pass.
- **Three contradictions to report (not fix this pass):** Help/Docs/News wired as OIDC RP clients;
  `SIGN_ISSUERS` issuing on `id.umaxica.*`; Core OIDC clients redirecting to `www.jp.umaxica.*`.

---

## Current Route Inventory

`config/routes.rb` draws only three surfaces:

- `config/routes.rb:7` `draw :acme`
- `config/routes.rb:9` `draw :sign`
- `config/routes.rb:12` `draw :core`

Per-surface route files (host-constrained scopes; each variant defines `root to: "roots#index"`,
`resource :health` + nested `health/{live,ready,startup}`, `resource :robots`, `resource :sitemap`):

- **Acme** — `config/routes/acme.rb`
  - app (`ACME_SERVICE_URL`) `:14`, com (`ACME_CORPORATE_URL`) `:165`, org (`ACME_STAFF_URL`) `:284`
  - net (`ACME_NETWORK_URL`) `:406` and dev (`ACME_DEVELOPER_URL`) `:416` — root + single health
    only
- **Sign** — `config/routes/sign.rb`
  - app `:11` (`SIGN_SERVICE_URL`), com `:217` (`SIGN_CORPORATE_URL`), org `:388` (`SIGN_STAFF_URL`)
- **Core** — `config/routes/core.rb`
  - app `:14` (`CORE_SERVICE_URL`/`core.app.localhost`), com `:55` (`CORE_CORPORATE_URL`), org `:96`
    (`CORE_STAFF_URL`). Core adds `jwks`, `web/v0`, `edge/v0`, `auth/callback`, `sso`, `accounts`,
    `csp-violation-report` (org also `configuration`).

**No routes** for base, palm, port, help, docs, news. `config/routes/` contains only `acme.rb`,
`sign.rb`, `core.rb`.

---

## Current Controller Inventory

`app/controllers/application_controller.rb:4` `ApplicationController < ActionController::Base`.

Surface-local `ApplicationController < ActionController::Base` (each line 6):
`acme/{app,com,org,net,dev}`, `sign/{app,com,org}`, `core/{app,com,org}`.

Root controllers — all inherit the **surface ApplicationController** (full pipeline):

- `acme/{app,com,org}/roots_controller.rb` — `AUTHENTICATION_MODE = :open`, empty `index` (renders
  view)
- `acme/{net,dev}/roots_controller.rb` — `:deny_all` / minimal, `render plain:`
- `sign/{app,com,org}/roots_controller.rb` — `:open`
- `core/{app,com,org}/roots_controller.rb` — `:open`; **`index` renders
  `template: "acme/app/roots/index"`** (cross-surface view coupling — noted, not in scope to fix).

`core/app/application_controller.rb:6-72` confirms the heavy pipeline and
`AUTHENTICATION_MODE = :deny_all` default.

---

## BareController Inventory

Every existing surface variant defines its own `BareController < ActionController::Base` (identical
shape, e.g. `core/app/bare_controller.rb:8`, `acme/net/bare_controller.rb:8`):

```ruby
class BareController < ActionController::Base
  include ::RateLimit
  AUTHENTICATION_MODE = :bare
  allow_browser versions: :modern
  protect_from_forgery using: :header_or_legacy_token, with: :exception
end
```

Inline comment on each: _"Intentionally bypasses ApplicationController … Do not normalize this
inheritance."_ `HealthsController` and `RobotsController` (and nested health controllers) inherit
this `BareController` and include the `HealthEndpoint` / `Robots` concerns
(`app/controllers/concerns/health_endpoint.rb`, `app/controllers/concerns/robots.rb`). The `Robots`
concern returns `"User-agent: *\nDisallow:\n"` (allow-all) for all surfaces.

**Inheritance invariant test** (untracked:
`test/controllers/controller_inheritance_invariant_test.rb`) enforces that every controller inherits
an _approved base_ (`ApplicationController`, `BareController`, `ActionController::Base`, etc.). New
BareController-based roots **pass automatically** — no `KNOWN_VIOLATIONS`/`PERMITTED_LOCAL_BASES`
edits needed.

---

## Surface Classification Table

| Finding                                                                             | Bucket                   | Notes                                                                                                               |
| ----------------------------------------------------------------------------------- | ------------------------ | ------------------------------------------------------------------------------------------------------------------- |
| `acme/*` routes, controllers, OIDC `acme_*` clients                                 | **A** Keep as Acme       | Sole IdP. No change.                                                                                                |
| `sign/*` routes, controllers, OIDC `sign_*` clients                                 | **B** Keep as Sign       | RP only. No change.                                                                                                 |
| `core/*` Rails routes/controllers, OIDC `core_*` clients                            | **C** Core Rails backend | Legitimate Rails Core backend (holds OIDC state/session/token vault). **Not** a mislabeled Base; do **not** rename. |
| Base surface                                                                        | **D**                    | Does not exist yet — create fresh.                                                                                  |
| Palm surface (`palm-api`)                                                           | **E**                    | Does not exist — create fresh under name Palm.                                                                      |
| Help/Docs/News OIDC clients `oidc_client_registry.rb:188-244`                       | **F** + contradiction    | Informational; but currently wired as RPs (see Contradictions).                                                     |
| `adr/`, `docs/`, `plans/`, `memos/` "Port"/`port-api` text                          | **G**                    | Historical — supersession banners only, no rewrite.                                                                 |
| Repo/package/host/env names (`CORE_SERVICE_URL`, `umaxica-*`, `core.app.localhost`) | **H**                    | Do not rename this pass.                                                                                            |
| `SIGN_ISSUERS = id.umaxica.*` ceremony issuers                                      | **I**                    | Needs confirmation (likely WebAuthn URL-binding, see below).                                                        |
| Core clients redirecting to `www.jp.umaxica.*`                                      | **I**                    | Host/role inconsistency — human review.                                                                             |

---

## Contradictions Found (report only — do NOT fix this pass; all are deferred auth-integration)

1. **Help/Docs/News are wired as OIDC RP clients.** `app/services/oidc_client_registry.rb:188-244`
   defines `docs_{app,org,com}`, `news_{app,org,com}`, `help_{app,org,com}` each with
   `redirect_uris` → `/auth/callback`, `aud`, `resource_type`. The accepted architecture says
   Help/Docs/News are "generally not RPs" (org exception "may later" apply). → **Open question**,
   not a routing-pass change.
2. **`SIGN_ISSUERS` issues on Sign's own host.** `app/services/identity_*_ceremony_contract.rb`
   define `SIGN_ISSUERS = {"app" => "https://id.umaxica.app", ...}` and emit `iss => id.umaxica.*`
   on ceremony tokens (e.g. `identity_email_ceremony_result.rb:67`). This _looks_ like
   Sign-as-issuer, **but** recalled memory `step-up-webauthn-url-binding` indicates step-up/ceremony
   stays on `id.*` because WebAuthn RP ID/origin is URL-bound — so this is plausibly intentional and
   already reasoned. → Report as **"confirm this is the documented WebAuthn-binding case,"** not a
   clean Sign-is-IdP violation.
3. **Core OIDC clients redirect to `www.jp.umaxica.*`.** `oidc_client_registry.rb:165,173,181` and
   `app/models/core_*_bridge.rb` use `www.jp.umaxica.*`. Whether that host belongs to Core Web
   (`jp.*`) or Base (`www.jp.*`) is unresolved — **but do NOT rename Core to Base** (the
   architecture has both a Next.js Core Web _and_ a Rails Core backend). Report as open question
   only.

**Constraints checked and currently OK:** no `Domain=.example.com` on auth cookies (host-only,
`domain: false`); no shared session store across surfaces; API auth uses Access Tokens (not ID
Tokens) via `OidcAccessTokenAuthenticator`; no `__Host-core_sid`/`X-Core-Session`/
`CORE_BACKEND_SERVICE_TOKEN` yet (expected — Next.js/integration work); no
`core_*`/`base_*`/`palm_*` databases in `config/database.yml`.

---

## Port → Palm Rename Findings

- **No code, config, route, controller, or env var uses "Port"** — only documents do:
  `adr/acme-sign-core-base-port-boundary.md` (`:95,104,111,123,126`),
  `docs/architecture/acme-sign-core-base-port.md` (`:80,90,114`),
  `plans/active/acme-sign-core-base-port-implementation.md` (`:22,31`),
  `memos/2026-06-12-codex-acme-sign-core-base-port-recap.md:16`.
- **Zero occurrences of "Palm"/`palm-api`** anywhere.
- **Decision (per task):** Palm is the accepted name. → Build Palm fresh; treat Port docs as
  **historical (bucket G)** with optional supersession banners. **No global string replacement.**

---

## Core Split Findings

- Rails `core/*` (routes + controllers + `core_*` OIDC clients) = **Core Rails backend** (bucket C).
  This is correct per architecture ("Rails Core backend holds OIDC state, nonce, PKCE verifier,
  session DB, token vault").
- **Core Web (Next.js)** and the `__Host-core_sid` host-only cookie are **not implemented in Rails**
  and are out of scope (Next.js + later integration work).
- Docs that describe Core only as Rails, or reference non-existent `Help::Com::ContactsController`
  etc., are stale (see below). The `www.jp.umaxica.*` redirect host on Core clients is the one real
  inconsistency → open question, not a rename.

---

## Help / Docs / News Findings

- **No routes/controllers exist.** Present only as OIDC RP clients
  (`oidc_client_registry.rb:188-244`, app/org/com triples on
  `{docs,news,help}.{app,org,com}.localhost`).
- **Stale doc references** to controllers/namespaces that don't exist: `docs/hld.md:150`,
  `docs/dds.md:136`, `docs/srs.md:77,139` (`Help::Com::ContactsController`), `docs/test.md:115-116`
  (`Help::*`, `Docs::*`, `News::*`). Docs also call them "placeholders" (`docs/hld.md:96`,
  `docs/srs.md:79`).
- This pass: create informational **placeholder roots** (200 message) for help/docs/news app/com/org
  via BareController — **no IdP/RP/callback behavior**. Leave the OIDC RP entries alone (open
  question).

---

## Minimal Implementation Plan

For each **new surface × variant** = {base, palm, help, docs, news} × {app, com, org} = 15
namespaces. Mirror the existing `core/<variant>` minimal shape (BareController-backed
root/health/robots), using **`render plain:`** for roots to avoid view scaffolding and cross-surface
view coupling.

1. **Routes:** add `config/routes/{base,palm,help,docs,news}.rb` (one host-constrained scope per
   variant, each with `root`, `health` + nested, `robots`); add
   `draw :base`/`:palm`/`:help`/`:docs`/ `:news` to `config/routes.rb`. Reuse host env-var naming
   convention (`BASE_SERVICE_URL`/`BASE_CORPORATE_URL`/`BASE_STAFF_URL`, `PALM_*`, and existing
   `HELP_*`/`DOCS_*`/`NEWS_*` already referenced by the OIDC registry) with
   `*.{app,com,org}.localhost` defaults.
2. **Controllers:** per variant, add `bare_controller.rb` (copy existing BareController exactly),
   `roots_controller.rb` (`< <Surface>::<Variant>::BareController`, `def index` → `render plain:`),
   `healths_controller.rb` + `health/{lives,readies,startups}_controller.rb`
   (`include ::HealthEndpoint`), `robots_controller.rb` (`include ::Robots`).
3. **Root parent:** **BareController** for all new roots (forced — see Executive Summary). Do not
   use surface `ApplicationController`.
4. **Tests:** add an integration test per new root asserting `200` + expected message body,
   following the existing `host! ENV.fetch(...)` + `get <surface>_<variant>_root_url` pattern; add
   health/robots smoke tests mirroring existing surface tests. No edits to the inheritance invariant
   test needed.
5. **Docs/notes:** add a `notes/implementation/` handoff note recording this audit's contradictions
   and the deferred items.

### Root message intent (per surface)

- **Base:** "Base services available" — point conceptually to `/settings` (no settings impl).
- **Palm:** "Palm API for native/handheld clients; browser access is not a product UI."
- **Help/Docs/News:** simple informational placeholder, no auth.
- (Acme/Sign/Core roots already exist and are unchanged.)

---

## Suggested Route Map (one per new variant, `core.rb` shape)

```ruby
# config/routes/base.rb (palm/help/docs/news analogous)
scope module: :base, as: :base do
  base_app_hosts = [ENV["BASE_SERVICE_URL"], "base.app.localhost"].compact.uniq
  # ... com/org host lists ...
  constraints ->(r) { base_app_hosts.include?(r.host) } do
    scope module: :app, as: :app do
      root to: "roots#index"
      resource :health, only: :show
      namespace :health do
        resource :live, only: :show
        resource :ready, only: :show
        resource :startup, only: :show
      end
      resource :robots, only: :show, path: "robots.txt"
    end
  end
  # ... com, org blocks ...
end
```

Add to `config/routes.rb`: `draw :base`, `draw :palm`, `draw :help`, `draw :docs`, `draw :news`.

## Suggested Controller Map (per variant, e.g. `Base::App`)

```ruby
# app/controllers/base/app/bare_controller.rb  — copy of existing BareController
class BareController < ActionController::Base
  include ::RateLimit
  AUTHENTICATION_MODE = :bare
  allow_browser versions: :modern
  protect_from_forgery using: :header_or_legacy_token, with: :exception
end

# app/controllers/base/app/roots_controller.rb
class RootsController < Base::App::BareController
  def index
    render plain: "Base services are available. See /settings."
  end
end

# healths_controller.rb (include ::HealthEndpoint) + health/{lives,readies,startups}_controller.rb
# robots_controller.rb (include ::Robots)
```

## Suggested Tests

- `test/controllers/<surface>/<variant>/roots_controller_test.rb` — `get …_root_url` → `200`, body
  match.
- Health smoke: `…_health_url`, `…_health_live_url`, etc. → `200`.
- Robots: `…_robots_url` → `200`, `text/plain`, allow-all body (existing common policy).
- Existing `controller_inheritance_invariant_test.rb` should still pass unchanged (verify).

## Docs / ADR / Plan Updates Needed

- Add a `notes/implementation/` handoff note: this audit's findings, the 3 deferred contradictions,
  and the Palm-not-Port decision.
- (Optional, small) Supersession banner on Port docs/ADR/plan noting Palm is the accepted name.
- (Optional, small) Fix/flag stale `Help::Com::ContactsController` / `Docs::*` / `News::*`
  references in `docs/{hld,dds,srs,test}.md`.

## Files That Should NOT Be Changed

- Existing `acme/*`, `sign/*`, `core/*` controllers and roots (incl. their
  `ApplicationController`s).
- `app/services/oidc_client_registry.rb` (Help/Docs/News RP entries — deferred auth integration).
- `app/services/identity_*_ceremony_contract.rb` (`SIGN_ISSUERS`).
- `config/database.yml` (no new databases).
- `test/controllers/controller_inheritance_invariant_test.rb` (no edits required).
- Port references across `adr/docs/plans/memos` (no rename / no global replace).

## Open Questions for Human Decision

1. **Help/Docs/News as OIDC RPs:** keep registry entries (org RP exception) or remove until needed?
2. **Core client redirect host** `www.jp.umaxica.*`: intended for Rails Core backend, or should Core
   Web use `jp.umaxica.*`? (No rename now regardless.)
3. **`SIGN_ISSUERS` on `id.umaxica.*`:** confirm this is the documented WebAuthn URL-binding case,
   not Sign-as-IdP.
4. **Palm as app/com/org triples:** Palm is a non-browser native API — confirm 3 browser-facing
   placeholder roots are wanted (decision so far: yes, uniform triples).
5. **Palm robots policy:** follow common allow-all, or disallow-all for the API surface?

## Verification Commands

- `bin/rails routes | grep -E 'base|palm|help|docs|news'` (after impl) — confirm new
  roots/health/robots.
- `bin/rails test test/controllers/.../roots_controller_test.rb` (new tests) and
  `bin/rails test test/controllers/controller_inheritance_invariant_test.rb`.
- `rg -n "Port|port-api|Palm|palm-api" .` — confirm no stray Port in new code.
- `rg -n "__Host-core_sid|X-Core-Session|CORE_BACKEND_SERVICE_TOKEN|Domain=\.example\.com" app config test`.
