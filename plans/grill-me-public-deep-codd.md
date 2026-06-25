# Grill-Me Audit: `info` Public Surface

**Date:** 2026-06-25 **Status:** Audit only — no implementation authorized

---

## 1. Executive Summary

The `info.umaxica.{com,app,org}` surface is viable and follows an established pattern in this
repository (docs/help/news). The core implementation pattern — `BareController`,
`ReadOnlyContentEntry`, `ReadOnlyContentRendering` — is directly reusable. However, three issues
must be resolved before any implementation begins:

1. **Hard blocker:** `ReadOnlyContentRendering#render_content_api_show` does NOT filter by published
   status. A draft entry with slug `terms` would be returned over a public API. This bug exists in
   docs/help/news too and must be fixed before adding legal content.

2. **Hard blocker:** `ReadOnlyContentRendering#content_locale` passes `params[:ri]` directly as a
   locale string (e.g. `"jp"`), but the model stores `"ja"` / `"en"`. A request with `ri=jp`
   silently returns no results. For legal documents, silent empty is unacceptable — missing regional
   legal pages must fail closed (404), not return empty.

3. **Infrastructure gap:** `ConfigValues::HostFamilyValues` has no `info_*` entries. No `ENV` keys,
   no boot-config slots, no host validation exist for the `info` surface. This must be added before
   routing is possible.

Once these three are resolved, the remaining work is additive, low-risk, and follows the exact
docs/news/help scaffold.

---

## 2. Current Implementation Map

### Public content surfaces

| Surface | Hosts (production examples)            | Controller namespace  | DB                 |
| ------- | -------------------------------------- | --------------------- | ------------------ |
| docs    | `docs.jp.umaxica.{app,com,org}`        | `Docs::{App,Com,Org}` | app/com/org zenith |
| news    | `news.jp.umaxica.{app,com,org}`        | `News::{App,Com,Org}` | app/com/org zenith |
| help    | via `boot_config.fetch(:hosts).help_*` | `Help::{App,Com,Org}` | app/com/org zenith |

### Key observations about docs/news/help

- **No ApplicationController** in these namespaces. Only `BareController < ActionController::Base`.
- All controllers declare `AUTHENTICATION_MODE = :bare` explicitly.
- Content tables per namespace: `docs_content_entries`, `news_content_entries`,
  `help_content_entries`. Same schema across all three. Surface is encoded in the model class name,
  not a column.
- Slug uniqueness is `(locale, slug)` within a table — not cross-surface.
- `ReadOnlyContentRendering#content_entry_class` resolves dynamically:
  `"#{content_namespace}_#{content_surface}_content_entry".camelize.constantize` → controller at
  `Docs::App::...` yields `DocsAppContentEntry`.

### Host pattern discrepancy

Docs and news embed region in the hostname: `docs.jp.umaxica.app`. The proposed
`info.umaxica.{com,app,org}` omits region from the hostname. This is intentional and acceptable —
legal documents have global slugs (`terms`, `privacy`) and region is handled via `ri=` query param,
consistent with how other surfaces expose region context. The difference in hostname scheme is a
legitimate design choice, not an error.

### Route architecture

Routes for read-only content surfaces live in `config/routes/{docs,news,help}.rb`, each drawn from
`config/routes.rb`. Each surface file applies host constraints, scopes the module and route prefix,
then adds: root, health, health probes, CSP report, and `api/v0/entries` resources.

---

## 3. Reusable Components Found

### Safe to reuse directly

| Component                          | File                                                      | Notes                                                   |
| ---------------------------------- | --------------------------------------------------------- | ------------------------------------------------------- |
| `ReadOnlyContentEntry` concern     | `app/models/concerns/read_only_content_entry.rb`          | Apply to new `Info*ContentEntry` models                 |
| `ReadOnlyContentRendering` concern | `app/controllers/concerns/read_only_content_rendering.rb` | Reuse after fixing show/draft bug and ri→locale mapping |
| `Robots` concern                   | `app/controllers/concerns/robots.rb`                      | Direct include in bare robots controller                |
| `Sitemap` concern                  | `app/controllers/concerns/sitemap.rb`                     | Direct include in bare sitemap controller               |
| `RateLimit` concern                | `app/controllers/concerns/rate_limit.rb`                  | Already included in `BareController`                    |
| `BareController` pattern           | `app/controllers/docs/app/bare_controller.rb` (example)   | Copy pattern exactly; do not share the class            |
| Route file pattern                 | `config/routes/docs.rb`                                   | Copy structure for `config/routes/info.rb`              |
| Route contract tests               | `test/integration/routes/docs_route_contract_test.rb`     | Copy and adapt                                          |

### Requires extraction before reuse

| Component                 | Current location           | Issue                                                          |
| ------------------------- | -------------------------- | -------------------------------------------------------------- |
| `render_content_api_show` | `ReadOnlyContentRendering` | Does not filter published — must be fixed before any legal use |
| `content_locale`          | `ReadOnlyContentRendering` | Uses `params[:ri]` as raw locale — must map jp→ja, us→en       |

### Do not reuse

- `ApplicationController` of any surface — `info` is public-only; no app/com/org
  ApplicationController should exist in the `info` namespace.
- `PreferenceGlobal` / `PreferenceLocalization` concerns — these belong to auth-lifecycle
  controllers. The `info` surface handles locale via `content_locale` only.

---

## 4. Design Risks

### 4a. Surface decomposition: 3 TLDs vs 1

**Challenge:** Legal documents (`terms`, `privacy`, `cookies`) are typically identical across
`.app`, `.com`, and `.org`. Creating three host-constrained surfaces produces three separately
deployable endpoints with the same content.

**Risk:** Duplicate indexable content if SEO robots reach all three.

**Mitigation:** Canonical URL policy — `.com` variant is canonical; `.app` and `.org` either serve
`X-Robots-Tag: noindex` or declare `rel=canonical` pointing to `.com`. See §8.

**Verdict:** Three TLD variants are consistent with the existing pattern and acceptable. Start with
`.com` only if capacity is limited.

### 4b. Hostname pattern divergence

Docs/news use `{namespace}.{region}.umaxica.{tld}` (e.g. `docs.jp.umaxica.app`). The proposed
`info.umaxica.{com,app,org}` uses no region prefix. This is the correct choice for legal docs
(region is a query param, not a hostname segment), but it means `info` cannot share host-resolution
code that assumes the `jp.` / `us.` subdomain level.

Ensure `CoreSurface.detect` and `CoreHostNormalization.normalize` handle `info.umaxica.com`
correctly (they parse the first matching surface label in the hostname — `com` — which is correct).

### 4c. `info` as a namespace collision

No naming collision found in `app/controllers/`, `app/models/`, `config/routes/`, or
`ConfigValues::HostFamilyValues`. `info` is safe as a new namespace.

### 4d. No `PublicController` convention

There is no `PublicController` base in this repository. Authentication behavior is controlled by
`AUTHENTICATION_MODE` declared on each concrete controller. Do not introduce a `PublicController`
base; follow the BareController + AUTHENTICATION_MODE pattern exactly.

---

## 5. Auth / Public-Access Risks

### 5a. Inheritance must be BareController, not ApplicationController

No `ApplicationController` must exist in the `info` namespace. The risk of accidentally creating one
and inheriting from it is real — if someone adds
`Info::Com::ApplicationController < ActionController::Base` with auth callbacks, it could silently
gate legal pages.

**Rule:** Create only `BareController` classes in the `info` namespace. No ApplicationController.

### 5b. Filters that must NOT appear

The following before-actions are found in app/com/org ApplicationControllers and must never appear
on `info` controllers:

- `authenticate_client!` / `authenticate_visitor!` / `authenticate_operator!`
- `enforce_withdrawal_gate!`
- `enforce_restricted_session_guard!`
- `enforce_sign_in_selector_gate!`
- `enforce_verification_if_required`
- `enforce_access_policy!`
- `set_current_actor` / `with_actor_lifecycle`
- `transparent_refresh_access_token`
- `set_preferences_cookie`
- `verify_jump_return_rt!`

`BareController < ActionController::Base` inherits none of these. They are only in
`ApplicationController`. As long as `info` controllers inherit from `BareController`, no risk.

### 5c. CSRF on public GET endpoints

`BareController` uses `protect_from_forgery using: :header_or_legacy_token, with: :exception`. Rails
CSRF protection applies only to non-GET/HEAD/OPTIONS/TRACE by default. Public GET routes are not
affected. No exemption needed.

### 5d. Rate limiting

`BareController` includes `RateLimit`. Default rate limit applies. Legal document fetches are
low-volume; the default 300 req/min should be sufficient. Do not remove rate limiting.

---

## 6. Model / Data Risks

### 6a. New table vs existing docs table

**Option A:** Store legal docs in `docs_content_entries`. Does not work — `ReadOnlyContentRendering`
resolves `content_entry_class` from the controller's namespace. An `Info::Com::...` controller
yields `InfoComContentEntry`, not `DocsComContentEntry`. Forcing legal docs into
`docs_content_entries` would require overriding the dynamic class resolution or abandoning the
reusable concern.

**Option B (correct):** Create `info_content_entries` table (3 migrations: app_zenith, com_zenith,
org_zenith) with identical schema to docs/help/news. Create 9 model files: `InfoAppContentEntry`,
`InfoComContentEntry`, `InfoOrgContentEntry` (each including `ReadOnlyContentEntry`). This is the
established pattern and correct path.

### 6b. No region column — only locale

Current content entries have `locale` (string: `"ja"`, `"en"`) but no `ri` column. Implications:

- JP-Japanese terms (`locale=ja`) and US-Japanese terms (`locale=ja`) cannot be distinguished. Same
  entry serves both regions for a given locale.
- This is acceptable for initial implementation if JP and US terms are locale-differentiated. If JP
  English and US English legal content must differ, a `region` column would be needed.
  **Recommendation:** Accept the limitation now; add `region` column via migration if needed later.

### 6c. Draft exposure in `render_content_api_show`

`ReadOnlyContentRendering#render_content_api_show` calls:

```ruby
content_entry_class.find_by!(slug: params.expect(:slug))
```

This has NO published filter. A `draft` or `archived` entry is returned.

For legal docs this is a **hard blocker**. Fix required:

```ruby
content_entry_class.published.find_by!(slug: params.expect(:slug))
```

This fix also benefits docs/help/news. Apply it to the shared concern.

### 6d. `ri=jp` produces empty results silently

`content_locale` in `ReadOnlyContentRendering`:

```ruby
params[:locale] || params[:ri] || I18n.locale.to_s
```

`params[:ri]` is `"jp"` or `"us"`. The `for_locale` scope queries against `"ja"` / `"en"`.
`for_locale("jp")` returns nothing. `render_content_api_index` returns empty array (silently).
`render_content_api_show` raises `RecordNotFound` → 404 (accidentally correct but for wrong reason).

Fix `content_locale` to map region codes before using as locale:

```ruby
REGION_TO_LOCALE = { "jp" => "ja", "us" => "en" }.freeze

def content_locale
  locale = params[:locale] || REGION_TO_LOCALE[params[:ri]] || I18n.locale.to_s
  I18n.available_locales.map(&:to_s).include?(locale) ? locale : I18n.default_locale.to_s
end
```

### 6e. No fixtures/seeds for legal content

No existing seeds or fixtures for terms/privacy/cookies. Fixtures must be added in `test/fixtures/`
for `info_content_entries` table (3 tables × 3 DBs = 9 fixture files, or minimal set for test
surface only).

### 6f. No versioned archived access

Legal documents often need "view archived version" access. The current model supports `archived`
status (hides from published scope) but no API to retrieve archived entries. The revision controller
is a stub returning empty arrays. This is a soft blocker for full legal compliance but acceptable
for initial implementation.

---

## 7. Routing Recommendation

### Minimal route shape

```ruby
# config/routes/info.rb
Rails.application.routes.draw do
  info_com_hosts = [
    boot_config.fetch(:hosts).info_corporate.host,
    "info.com.localhost"
  ].compact

  info_app_hosts = [
    boot_config.fetch(:hosts).info_service.host,
    "info.app.localhost"
  ].compact

  info_org_hosts = [
    boot_config.fetch(:hosts).info_staff.host,
    "info.org.localhost"
  ].compact

  constraints host: info_com_hosts do
    scope module: :info, as: :info do
      scope module: :com do
        root to: "roots#index"
        resource :health, only: :show
        namespace :health do
          resource :liveness,  only: :show, controller: :livenesses
          resource :readiness, only: :show, controller: :readinesses
          resource :startup,   only: :show, controller: :startups
        end
        resource :csp_violation_report, only: :create, path: "csp-violation-report"
        resource :robots,  only: :index, path: "robots.txt"
        resource :sitemap, only: :show,  path: "sitemap.xml"
        namespace :api do
          namespace :v0 do
            resources :entries, only: %i(index show), param: :slug
          end
        end
      end
    end
  end

  # Repeat for app_hosts and org_hosts with module: :app / :org
end
```

### Should `info` include /docs, /help, /news routes?

**No.** The constraint says existing routes must remain unchanged, and `info` is an additional
surface. Linking to docs/help from `info` is a frontend concern, not a Rails routing concern.

### Legal slug routing (`/terms`, `/privacy`, etc.)

These are **not Rails routes**. The roots controller renders an SPA shell (like docs roots do, with
`layout false`). The SPA fetches `/api/v0/entries/terms` to render the terms page. Do not add
`get "/terms", to: "..."` Rails routes — that would deviate from the established content surface
pattern.

---

## 8. Canonical / SEO Recommendation

### Canonical host for legal documents

`info.umaxica.com` should be the canonical host for all legal/public information pages.
`info.umaxica.app` and `info.umaxica.org` should include:

- `<link rel="canonical" href="https://info.umaxica.com/...">` in the SPA shell
- `X-Robots-Tag: noindex` response header OR robots.txt disallow for `.app` and `.org`

Implementing this in the SPA shell view is sufficient for initial rollout.

### Robots.txt

| Host               | Recommended behavior                           |
| ------------------ | ---------------------------------------------- |
| `info.umaxica.com` | `User-agent: *` / `Disallow:` (allow all)      |
| `info.umaxica.app` | `User-agent: *` / `Disallow: /` (disallow all) |
| `info.umaxica.org` | `User-agent: *` / `Disallow: /` (disallow all) |

### Duplicate content risk with existing surfaces

- Legal slugs (`terms`, `privacy`, `cookies`) will not exist in `docs_content_entries`,
  `help_content_entries`, or `news_content_entries` if seeded exclusively in `info_content_entries`.
  No cross-surface slug collision is possible unless content is manually cross-seeded.
- Docs/help/news use `docs.jp.umaxica.*` etc. host patterns — no URL overlap with `info.umaxica.*`.

### Sitemap

`info.umaxica.com` sitemap should list all published entries. Use the `Sitemap` concern. The sitemap
controller's `sitemap_urls` method should return URLs for all published `InfoComContentEntry`
entries.

---

## 9. Security / Cache Recommendation

### Draft content exposure (hard blocker)

Fix `ReadOnlyContentRendering#render_content_api_show` to scope to `.published` before `find_by!`.
Without this fix, **do not put legal content in any content entry table**.

### Cache headers on content entry API

Current `EntriesController` (docs/help/news) sets no explicit cache headers. For legal documents on
a public surface, add explicit public caching:

```ruby
# In Info::Com::Api::V0::EntriesController#show
expires_in 10.minutes, public: true, stale_while_revalidate: 5.minutes
```

Avoid caching too aggressively (legal docs change; users need current versions).

### No personalized content leakage

`BareController` has no actor/session machinery. Content entry responses contain only slug, locale,
title, summary, body, published_at — no personalized data. Safe for public caching.

### Path traversal via slug

Slug validation `(/\A[a-z0-9]+(?:[a-z0-9-]*[a-z0-9])?\z/)` enforced at model layer.
`params.expect(:slug)` used in controller (confirmed). No path traversal risk.

### Host header confusion

Host constraints in routes prevent host header confusion — unrecognized hosts fall through to a
404/routing error. No risk as long as host constraint is correctly configured.

### Open redirect via `ri` or slug

`BareController` does not include `PreferenceGlobal`, which is the concern that performs `ri`-based
redirects. No redirect risk on bare endpoints.

### 404 behavior for missing legal documents

`find_by!` raises `ActiveRecord::RecordNotFound`. Rails rescues this as 404 by default. Ensure the
application's default error handler returns a clean 404 (not a 500) and does not leak content entry
internals.

---

## 10. Test Plan

### Route contract tests (new file)

`test/integration/routes/info_route_contract_test.rb`

Copy the structure from `test/integration/routes/docs_route_contract_test.rb` and verify:

- `GET /` recognized at `info.umaxica.com` → `info/com/roots#index`
- `GET /` recognized at `info.umaxica.app` → `info/app/roots#index`
- `GET /` recognized at `info.umaxica.org` → `info/org/roots#index`
- `GET /api/v0/entries` at `info.umaxica.com`
- `GET /api/v0/entries/terms` at `info.umaxica.com`
- `POST /csp-violation-report` at each host
- `GET /robots.txt` at each host
- `GET /sitemap.xml` at each host
- `GET /api/v0/entries/terms` at `docs.jp.umaxica.com` → does NOT route (host isolation)

### Integration tests (new file)

`test/integration/info_content_access_test.rb`

- `GET /api/v0/entries` → 200, returns only published entries
- `GET /api/v0/entries/terms` with published terms entry → 200, body contains terms content
- `GET /api/v0/entries/terms` with draft terms entry → 404 (**validates the draft fix**)
- `GET /api/v0/entries/terms` with archived terms entry → 404
- `GET /api/v0/entries/unknown-slug` → 404
- No auth required: request with no session/cookie → 200 (not redirected)
- `ri=jp` in query string → ja locale content returned
- `ri=us` in query string → en locale content returned
- `ri=unknown` in query string → falls back to default locale
- `GET /api/v0/entries` → no draft or archived entries in response

### Existing tests to extend

- `test/models/read_only_content_entry_test.rb` — extend with `InfoComContentEntry` to confirm
  concern applies correctly to new model
- `test/integration/docs_help_news_revisions_test.rb` — add `info` surface if revisions stub is
  added

---

## 11. Minimal Implementation Plan

### Prerequisites (fix before creating info surface)

1. **Fix draft exposure in `ReadOnlyContentRendering#render_content_api_show`**
   - File: `app/controllers/concerns/read_only_content_rendering.rb`
   - Change: add `.published` scope to `find_by!` call
   - Tests: add to `test/integration/docs_help_news_revisions_test.rb` or dedicated test

2. **Fix `content_locale` ri→locale mapping**
   - File: `app/controllers/concerns/read_only_content_rendering.rb`
   - Change: map `"jp"` → `"ja"`, `"us"` → `"en"` before passing to `for_locale`

### Infrastructure (parallel with prerequisites)

3. **Add `info_*` entries to `ConfigValues::HostFamilyValues`**
   - File: `lib/config_values_host_family_values.rb`
   - Add: `info_service`, `info_corporate`, `info_staff` with ENV keys and dev defaults
   - Add to grouping methods

### Migrations (3 files, one per DB)

4. **`db/app_zenith_migrate/{timestamp}_create_info_content_entries.rb`**
5. **`db/com_zenith_migrate/{timestamp}_create_info_content_entries.rb`**
6. **`db/org_zenith_migrate/{timestamp}_create_info_content_entries.rb`**

   Schema: identical to `20260613000001_create_read_only_content_entries.rb` for docs. Table name:
   `info_content_entries`.

### Models (9 files)

7. `app/models/info_app_content_entry.rb` →
   `class InfoAppContentEntry < AppRpRecord; include ReadOnlyContentEntry; end`
8. `app/models/info_com_content_entry.rb` → `ComRpRecord`
9. `app/models/info_org_content_entry.rb` → `OrgRpRecord`

### Controllers (per surface — com is minimum viable)

10. `app/controllers/info/com/bare_controller.rb` — copy docs/com/bare_controller.rb exactly
11. `app/controllers/info/com/roots_controller.rb`
12. `app/controllers/info/com/api/v0/entries_controller.rb` — include `ReadOnlyContentRendering`
13. Standard support: health, health probes, csp_violation_report, robots, sitemap controllers

    Repeat for `app/` and `org/` surface if multi-TLD from day one.

### Views

14. `app/views/info/com/roots/index.html.erb` — copy from docs/com/roots; update title/meta

### Routes

15. `config/routes/info.rb` — follow docs.rb structure with info\_\* hosts
16. `config/routes.rb` — add `draw :info`

### Fixtures

17. `test/fixtures/info_content_entries.yml` — entries for terms, privacy, cookies (published), and
    one draft entry (for draft-exposure tests)

### Tests

18. `test/integration/routes/info_route_contract_test.rb`
19. `test/integration/info_content_access_test.rb`

### Commands to run

```bash
bin/rails db:migrate:reset        # rebuild all DBs after new migrations
bin/rails test test/models/       # model layer
bin/rails test test/integration/routes/info_route_contract_test.rb
bin/rails test test/integration/info_content_access_test.rb
bin/rails test                    # full suite; verify existing routes unchanged
```

---

## 12. Go / No-Go Verdict

### Hard blockers (must fix before any legal content goes live)

| Blocker                                                                         | File                                                      | Severity                                |
| ------------------------------------------------------------------------------- | --------------------------------------------------------- | --------------------------------------- |
| `render_content_api_show` returns draft content                                 | `app/controllers/concerns/read_only_content_rendering.rb` | **STOP** — legal docs would leak drafts |
| `content_locale` passes `ri=jp` as locale to `for_locale("jp")` — returns empty | same file                                                 | **STOP** — Japanese content not served  |
| No `info_*` host entries in `ConfigValues::HostFamilyValues`                    | `lib/config_values_host_family_values.rb`                 | **STOP** — routing cannot be configured |

### Soft blockers (address in first iteration)

| Issue                                                            | Impact                                              |
| ---------------------------------------------------------------- | --------------------------------------------------- |
| No cross-TLD canonical URL in content rendering concern          | SEO duplicate content on `.app`/`.org`              |
| No cache headers on entry API responses                          | CDN cannot cache legal pages                        |
| No region differentiation for same-locale different-region terms | JP-English and US-English content indistinguishable |

### Naming risks

None. `info` is clear, unused, and consistent with intent.

### Migration risks

Low. Three additive migrations, no destructive operations, no existing table changes.

### Security risks

The draft-exposure bug is a genuine security risk for legal content. It exists in docs/help/news too
but is lower-stakes there (no one sues you for a draft blog post). Fix it before proceeding.

### Recommended decision

**Conditional go.** Fix the three hard blockers first (all are small, targeted changes to one
concern file and one library file). Once fixed, the remaining implementation is mechanical and
follows the established docs/help/news scaffold with low risk.

Do not begin `info` surface implementation until the draft-exposure fix is merged and tested.
