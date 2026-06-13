# Design Review: docs / help / news Surface Routing and Responsibility

**Type:** Grill-me review — no implementation authorized. **Date:** 2026-06-13 **Scope:** docs,
news, help × app/com/org (9 surface variants)

---

## A. Facts from current repo

### A1. Route files

All three route files are structurally identical. `config/routes/docs.rb` is canonical; news and
help mirror it.

**`config/routes/docs.rb` (64 lines) — per app/com/org variant:**

```
root to: "roots#index"                                         # line 8 (app)
resource :health, only: :show                                  # line 9
namespace :health do                                           # line 10
  resource :liveness/readiness/startup, only: :show           # lines 11-13
end
resource :csp_violation_report, only: :create,
  path: "csp-violation-report"                                 # line 15
resources :entries, only: %i(index show)                       # line 16  ← CONFLICT
namespace :edge do namespace :v0 do                            # lines 17-18
  resources :entries, only: %i(index show)                     # line 19  ← CONFLICT
end end
```

`robots.txt` and `sitemap.xml` are **not** routed for docs/news/help. Confirmed. No mutation routes
(`POST/PATCH/PUT/DELETE`). Confirmed. No auth callback routes (`/auth/callback`, `/web/v0/cookie`,
`/web/v0/theme`). Confirmed. No taxonomy routes (tags, categories). Confirmed. No version/revision
routes. Confirmed.

**`config/routes/base.rb` (52 lines) — for comparison:**

Base has `resource :robot, only: :show, path: "robots.txt"` and
`resource :sitemap, only: :show, path: "sitemap.xml"` for all variants (lines 15-16, 31-32, 47-48).
Docs/news/help deliberately omit these. Confirmed.

### A2. Controllers

Per surface × variant (docs, help, news × app, com, org = **9 sets**, each containing):

```
bare_controller.rb                      # < ActionController::Base
roots_controller.rb                     # < BareController, includes ReadOnlyContentRendering
entries_controller.rb                   # < BareController, includes ReadOnlyContentRendering
edge/v0/entries_controller.rb           # < BareController, includes ReadOnlyContentRendering
healths_controller.rb                   # < BareController
health/livenesses_controller.rb         # < BareController
health/readinesses_controller.rb        # < BareController
health/startups_controller.rb           # < BareController
robots_controller.rb                    # < BareController, includes ::Robots  ← DEAD CODE
csp_violation_reports_controller.rb     # < BareController
```

**Total: 90 controller files** across 3 surfaces × 3 variants × 10 controllers.

`Docs::App::BareController` (representative, `app/controllers/docs/app/bare_controller.rb`):

```ruby
class BareController < ActionController::Base
  include ::RateLimit
  AUTHENTICATION_MODE = :bare
  allow_browser versions: :modern
  protect_from_forgery using: :header_or_legacy_token, with: :exception
end
```

Comment present: "Do not normalize this inheritance."

`Docs::App::RootsController` (`app/controllers/docs/app/roots_controller.rb`):

```ruby
def index
  render_content_index   # ← CONFLICT: not thin; hits DB
end
```

`Docs::App::RobotsController` (`app/controllers/docs/app/robots_controller.rb`):

```ruby
include ::Robots
def show
  show_plain_text   # ← DEAD CODE: file exists, route does not
end
```

### A3. ReadOnlyContentRendering concern

`app/controllers/concerns/read_only_content_rendering.rb`:

- `render_content_index`: queries
  `content_entry_class.published.for_locale(content_locale).recent_first` — **DB-backed**; renders
  `shared/content_entries/index.html.erb`.
- `render_content_show`: queries `find_by!(slug: params.expect(:id))` — raises `RecordNotFound` on
  miss.
- `render_content_api_index`: same DB query, renders JSON `{ entries: [...] }`.
- `render_content_api_show`: same, renders JSON `{ entry: {...} }`.
- `content_locale`: `params[:locale].presence || params[:ri].presence || I18n.locale.to_s` — The
  `params[:ri]` fallback is undocumented and not declared in any route constraint.
- `content_entry_class`: dynamically resolved from controller module name via `constantize`. — A
  controller name typo silently raises `NameError` at runtime.

### A4. Models

9 ContentEntry models (`{docs,help,news}/{app,com,org}/content_entry.rb`), all including
`ReadOnlyContentEntry`.

Tables: `docs_content_entries`, `news_content_entries`, `help_content_entries` in `app_zenith`,
`com_zenith`, `org_zenith` databases respectively.

Schema (from `db/app_zenith_migrate/20260613000001_create_read_only_content_entries.rb`):

```
slug          string  NOT NULL
locale        string  NOT NULL
title         string  NOT NULL
summary       text    (nullable)
body          text    NOT NULL
status        string  NOT NULL  default "draft"
published_at  datetime
created_at / updated_at
```

Indexes: `(locale, slug)` UNIQUE; `(status, published_at)`.

Statuses: `draft`, `published`, `archived`.

Published scope: `status = "published" AND published_at <= Time.current`.

### A5. OIDC registry

`app/services/oidc_client_registry.rb` lines 189–244: 9 entries present.

```
docs_app / docs_org / docs_com
news_app / news_org / news_com
help_app / help_org / help_com
```

Each has `redirect_uris` (built from ENV or localhost default), `aud`, `resource_type`, `name`. No
comment marks them as transitional or dormant. No auth callback routes exist in docs/help/news route
files.

### A6. Tests

- `test/controllers/docs/`, `test/controllers/help/`, `test/controllers/news/` — **all directories
  empty**.
- `test/controllers/public_robots_routing_test.rb`: asserts `assert_not_respond_to self, helper` for
  all 9 content-surface robots path helpers (lines 34-41). Test passes by construction because
  routes don't define those helpers.
- `test/controllers/csp_violation_reports_controller_test.rb`: tests CSP endpoints.
- `test/controllers/controller_inheritance_invariant_test.rb`: enforces BareController ancestry.

No integration tests, routing tests, or controller tests exist for entries endpoints. No fixture
files for `*_zenith` databases under `test/fixtures/`.

### A7. Active plans / ADRs

- `adr/read-only-content-surfaces-in-rails.md` (Accepted 2026-06-13): authorizes lean ContentEntry
  model and confirms BareController pipeline.
- `plans/active/docs-news-help-content-surface-reimplementation-plan.md`: records target routing and
  explicitly lists current implementation as drift. Future Checklist includes removing `/entries`,
  `/entries/:slug`; moving from `edge/v0` to `api/v0`; making roots thin.
- `plans/active/surface-routing-pass-remediation-plan.md`: three open streams — Stream 1 (tests),
  Stream 2 (health refactor, ~127 uncommitted files), Stream 3 (OIDC ADR).
- `plans/active/surface-routing-controller-pass-base-palm-help-docs-news.md`: original pass that
  created current controller/route scaffold.

---

## B. Conflicts with current decision

### B1. [HIGH] Root is not thin

**Decision:** "Rails root must not render article/entry index."

**Current:** `RootsController#index` calls `render_content_index` which:

1. Issues a DB query against `*_zenith`.
2. Renders `shared/content_entries/index.html.erb` (public article list).

This directly contradicts the target. Root is not stable-200-without-DB. File:
`app/controllers/{docs,help,news}/{app,com,org}/roots_controller.rb` (all 9).

### B2. [HIGH] Rails-owned public HTML article routes exist

**Decision:** "Do not create or keep Rails-owned public HTML article routes: GET /entries, GET
/entries/:slug."

**Current:** `resources :entries, only: %i(index show)` is routed (docs.rb line 16, and equivalent
in help.rb and news.rb). This generates:

```
GET /entries          → EntriesController#index  (HTML + JSON)
GET /entries/:id      → EntriesController#show   (HTML + JSON)
```

This means Rails is currently the public HTML renderer for article index/show, which is explicitly
excluded from the target. 6 routes per surface (2 routes × 3 variants) × 3 surfaces = 18 routes that
should not exist.

### B3. [HIGH] `edge/v0` instead of `api/v0`

**Decision:** Target routes are `GET /api/v0/entries` and `GET /api/v0/entries/:id`. Implemented as
`resources :entries, only: %i[index show]` inside `namespace :api do namespace :v0`. Route parameter
name remains `:id` (Rails convention). Internal lookup may resolve `params[:id]` against `slug`, but
the route contract is `:id`.

**Current:** Routes use `namespace :edge do namespace :v0 do resources :entries ... end end`,
producing `GET /edge/v0/entries` and `GET /edge/v0/entries/:id`.

The namespace is `edge/v0`, not `api/v0`. The plan confirms this is implementation drift. If any
consumer already calls `/edge/v0/entries`, renaming to `/api/v0` is a breaking change.

The param name `:id` is correct per Rails resource convention and requires no change.

### B4. [MEDIUM] RobotsController exists but is dead code for content surfaces

**Decision:** robots.txt is delegated to Next.js; no robots route for docs/help/news.

**Current:** 9 `RobotsController` files exist
(`{docs,help,news}/{app,com,org}/robots_controller.rb`) with `include ::Robots` and `def show`.
Routes do not reference them. They are unreachable.

This is dead code. It creates ambiguity: a future agent might add a robots route thinking the
controller is intentionally scaffolded. The `public_robots_routing_test.rb` test asserts the helpers
don't exist, which is the correct guard — but the dead controllers are not guarded.

### B5. [MEDIUM] OIDC registry entries for docs/help/news have no "dormant" marking

**Decision:** The remediation plan (Stream 3a) calls for adding a comment marking these entries as
"transitional, not long-term" and "dormant." This has not been done.

**Current:** 9 entries (`docs_app`, `docs_org`, `docs_com`, `news_*`, `help_*`) in
`oidc_client_registry.rb:189–244` with no comment distinguishing them from active RP clients. They
have `redirect_uris` configured but no auth routes.

Risk: future agents or auditors may treat these as active RP registrations and try to wire up auth
callbacks, reversing the bare-surface decision.

### B6. [LOW] `params[:ri]` in `content_locale` is undocumented

**Current:** `ReadOnlyContentRendering#content_locale` falls back to `params[:ri]`. `ri` is not
documented anywhere in the codebase. No route constraint exposes it. If `ri` is a legacy
locale/region identifier from the old preference system (the `/web/v0/cookie` or `/web/v0/theme`
era), it may be coupling content rendering to a removed concern. If it is intentional, it should be
documented or constrained.

### B7. [LOW] Health controllers still use old `healths_controller.rb` pattern

**Decision:** Stream 2 of the remediation plan migrates all surfaces to unified `HealthController`.

**Current:** Docs/help/news have `healths_controller.rb` (old naming, old concern). The ~127-file
health refactor is in-flight (uncommitted). Stream 1 tests are blocked on Stream 2 settling.

### B8. [LOW] `summary` field nullable with no documented fallback contract

**Current:** `summary text` is nullable. `as_public_json` exposes `summary: summary`. If Next.js
uses `summary` for OG/meta description, `null` may cause rendering failures or expose blank meta
tags. No fallback (e.g., `body.truncate(160)`) is documented.

---

## C. Missing information / UNKNOWN

- **C1.** Whether any external consumer (Next.js, CDN, crawler, monitoring) already calls
  `/entries`, `/entries/:slug`, or `/edge/v0/entries` on docs/help/news hosts. If yes, the B2/B3
  cleanups are breaking changes that need coordination.

- **C2.** Deployment topology: whether an ingress layer (Cloudflare, Nginx, ALB) routes
  `GET /robots.txt` requests to Next.js or to Rails today. If Rails is the only origin, removing the
  robots route before Next.js goes live would leave crawlers unserved.

- **C3.** What `params[:ri]` means in `content_locale`. Whether it is a legacy artifact that should
  be removed or an intentional locale mechanism.

- **C4.** ~~`:id` vs `:slug` as route param~~ — **Resolved:** `:id` is the correct param name per
  Rails resource convention. `param: :slug` is not adopted. Internal lookup against `slug` is
  permitted but the route and controller param name remain `:id`.

- **C5.** Whether the `body` field contains raw Markdown, HTML, or structured JSON. `as_public_json`
  exposes `body` directly. If it contains unsanitized HTML and Next.js renders it via
  `dangerouslySetInnerHTML`, there is an XSS risk.

- **C6.** Whether the 3 zenith databases (app/com/org) are truly separate or share a host today.
  "Borrowed/colocated" in the plan is ambiguous.

- **C7.** Whether `help_org`, `docs_org`, `news_org` will ever need auth-gated content (org-specific
  entries not visible to app/com). Currently all 9 variants are identical bare public reads.

- **C8.** Whether Next.js and Rails share a domain or run on subdomains. If Next.js owns
  `docs.app.example.com` and Rails is a backend API at the same host, the ingress must route
  `/api/v0/entries` to Rails and everything else to Next.js. No ingress configuration exists in this
  repo.

---

## D. Design critique

### D1. Is `/api/v0/entries` the right namespace, given the codebase uses `edge/v0`?

Every other Rails API namespace in this repo uses `edge/v0` (Core uses `edge/v0/` for token
endpoints). The target decision switches to `api/v0` without explaining why. If this is a deliberate
read/write boundary signal (`edge` = internal/infrastructure, `api` = external/consumer), that
distinction should be in an ADR. Without it, `api/v0` on docs/help/news and `edge/v0` on Core looks
like inconsistency, not intentional differentiation.

**Ask:** Is `edge/v0` for internal-facing endpoints and `api/v0` for public-facing content APIs? If
yes, document this. If not, pick one namespace consistently and explain what it signals.

### D2. Can root truly be DB-free when `readiness` already checks the DB?

The target says root must return stable 200 without DB dependency. The `readiness` probe is supposed
to verify DB connectivity. If the DB is down, `readiness` returns non-200 (signalling the load
balancer to remove the instance), but `root` must still return 200.

This is architecturally sound — root is a liveness signal, readiness is for DB. But the current
`RootsController#render_content_index` conflates both: root fails when DB fails. Fixing root to be
thin solves this.

**Ask:** Should thin root return `204 No Content` or `200 OK` with a plain text body? The choice
affects monitoring (some uptime checkers require specific bodies) and Next.js (which may render root
as a page). Define the contract.

### D3. What should `GET /api/v0/entries/:slug` return for non-published entries?

The current implementation calls `find_by!(slug:)` on the `published` scope. This raises
`RecordNotFound` for:

- Draft entries (status = "draft")
- Archived entries (status = "archived")
- Future-published entries (published_at > now)
- Unknown slugs (not in DB at all)

All four cases result in the same response. The HTTP status depends on Rails rescue configuration
(likely `404 Not Found`). But semantically:

- Unknown slug → `404 Not Found` (correct)
- Archived entry → `410 Gone` (debatable; semantically correct but exposes authoring state)
- Future-published → `404 Not Found` or `503 Service Unavailable`? (depends on use case)
- Draft entry → `404 Not Found` (correct; must not leak existence)

**Ask:** Should the API distinguish 404 vs 410? Exposing 410 leaks that an entry existed and was
archived. If Next.js caches 410 aggressively, removing an entry from "archived" back to "published"
could cause stale 410s. Recommend: return 404 for everything non-published; never expose 410 until
there is a cache invalidation strategy.

### D4. The org variant is bare-public now; is that the right default?

`org` variants are currently bare public reads with no auth. The decision says "org may require
org-scoped read authorization in the future." But BareController is the permanent base, and
BareController bypasses all authentication/authorization callbacks.

If future org authz is added, BareController cannot accommodate it without adding explicit
`before_action` chains that replicate what `ApplicationController` already provides. This is not
impossible, but it is architecturally awkward. The typical pattern in this repo is: BareController =
forever bare; ApplicationController = auth-aware.

**Ask:** Is "maybe future org authz" a serious planned feature or a speculative footnote? If
serious, org variants should start from `ApplicationController` now with
`AUTHENTICATION_MODE = :open`. If speculative, document "org is permanently public" in an ADR and
don't carry the caveat. The current hedge ("may require") creates false confidence that
BareController can be upgraded. It cannot without architectural rework.

### D5. Delegating robots/sitemap to Next.js: who owns it during the transition?

`robots.txt` and `sitemap.xml` are not routed in docs/help/news. RobotsController files exist (dead
code). The plan says UNKNOWN for whether production ingress routes these to Next.js before Next.js
goes live.

If Next.js is not deployed yet, `GET /robots.txt` on docs/news/help hosts returns 404. Googlebot
treats a 404 on `robots.txt` as "allow all" per RFC, so crawling continues — but this is luck, not
design. If Next.js deployment is delayed, a temporary Rails `robots.txt` handler may be needed.

**Ask:** Is Next.js deployed for any docs/news/help host today? If not, is a 404 on `robots.txt`
acceptable, or does Rails need to serve a temporary allow-all response until handoff?

### D6. Does removing taxonomy now create a navigation gap in Next.js?

Without tags or categories, Next.js can only navigate entries by: locale, published date order
(`recent_first`), and slug. If any docs/help/news surface has more than ~20-30 entries, pagination
is required. If entries span multiple topics (e.g., help articles covering billing, account,
security), there is no filtering mechanism.

The decision says taxonomy can be "reintroduced later if there is a clear product need." But
introducing taxonomy later means:

1. Schema migration on 3 tables × 3 databases = 9 migrations.
2. API contract change (new fields in `as_public_json`).
3. Backfilling existing entries with category/tag assignments.
4. Next.js UI changes.

Deferring taxonomy is reasonable if the content volume is small and homogeneous. It is risky if the
content volume grows before taxonomy is designed.

**Ask:** What is the anticipated entry count per surface per locale at launch? Under 50 entries per
locale: taxonomy deferral is safe. Over 50: navigation may be unusable without taxonomy.

### D7. Does not exposing versions/revisions make future history UI harder to add?

The current model has no version/revision tracking. The slug is unique per locale; there is no
history. If a published entry is edited (via import or org authoring), the current entry is
overwritten. There is no way to show "this article was last updated" beyond `updated_at`.

The decision says versions/revisions are "future planned capabilities" and "the boundary is not
defined." This is acceptable for MVP. But the model must at minimum preserve `updated_at` for "last
modified" display — which it does. The risk is that once entries are published and indexed by
Next.js, edit tracking expectations will emerge quickly.

**Ask:** Is `updated_at` sufficient for "last updated" display in Next.js? If yes, confirm
`as_public_json` exposes it. (It does: `as_public_json` returns `published_at:` in ISO8601.
`updated_at` should also be included or documented as omitted intentionally.)

### D8. Is `entries` sufficiently clear to API consumers?

`GET /api/v0/entries` is ambiguous without a surface-specific host. Because the resource noun is
identical across docs, news, and help hosts, the surface is determined entirely by the host:

```
GET https://docs.app.example.com/api/v0/entries   → documentation entries
GET https://news.app.example.com/api/v0/entries   → news entries
GET https://help.app.example.com/api/v0/entries   → help entries
```

This is consistent with the "host determines surface" policy. The concern is developer experience: a
consumer must know the host semantics to understand the resource. If Next.js calls both docs and
help APIs, it must maintain two base URLs with identical path shapes. This is correct per the
architecture but may cause accidental host confusion (calling docs host for help content).

**Ask:** Is there a developer documentation plan that explains host semantics to Next.js developers?
Without it, `GET /api/v0/entries` on three different hosts is a footgun.

### D9. Does the OIDC registry precede route cleanup, or can they proceed in parallel?

The 9 OIDC registry entries for docs/news/help are dormant (no auth routes exist). Stream 3a calls
for adding an ADR and dormant comments. If route cleanup proceeds before Stream 3a, the registry
entries remain unlabelled and potentially confusing. If Stream 3a runs first, the entries are
properly annotated.

There is no dependency: route cleanup does not touch the registry, and registry annotation does not
touch routes. They can proceed in parallel. But the remediation plan implies Stream 3 should run
before or alongside the others.

**Risk:** If the route cleanup task adds `api/v0/entries` routes without touching the registry, a
future agent might see the registry entries and attempt to wire OIDC callbacks, undoing the
bare-surface decision.

### D10. Are health endpoints too expensive if they check DB?

The `readiness` health endpoint presumably checks DB connectivity. With 9 surface variants across
docs/help/news, each readiness probe queries its respective zenith database. If the
borrowed/colocated DB is shared, this is 3 DB connections per readiness cycle. If the DB is
unavailable, all 9 readiness endpoints fail simultaneously — which is correct behavior, but the
blast radius is total for all content surfaces at once.

**Ask:** Do the health profiles for docs/news/help use the same DB dependency check as core, or are
they lighter? The plan says "decide whether `core` should keep `App/Com/Org` or get Core-specific
profiles." The same question applies to content surfaces.

### D11. Route param: `:id` is correct; internal slug lookup is already in place

**Decision (corrected):** The route contract is `GET /api/v0/entries/:id` using standard
`resources :entries, only: %i[index show]`. `param: :slug` is **not** used. Controllers read
`params[:id]`.

This is already consistent with the current controller code: `find_by!(slug: params.expect(:id))` in
`ReadOnlyContentRendering#render_content_show` — the controller already treats `params[:id]` as a
slug value. No controller change is needed for the namespace rename.

The potential confusion is documentation-level: callers passing a numeric primary key as `:id` will
get 404 (since lookup is by slug, not PK). This is not a route bug but must be documented.

**Ask:** Should API documentation state that `:id` accepts a slug string, not a numeric PK? If
undocumented, Next.js developers may construct `GET /api/v0/entries/42` and get unexpected 404s.

---

## E. Recommended scope for next implementation task

The minimal safe next task that removes current HIGH conflicts:

1. **Make roots thin** (9 controller changes): Replace `render_content_index` in all 9
   `RootsController#index` methods with a DB-free thin response (e.g.,
   `render plain: "OK", status: :ok` or a documented minimal JSON). Decide the response contract
   first (see D2).

2. **Remove public HTML article routes — Phase 1** (3 route file changes): Delete
   `resources :entries, only: %i(index show)` from docs.rb, news.rb, help.rb (line 16 in each). The
   9 `EntriesController` files become unreachable but are **not deleted yet**. Verify via
   `bin/rails routes | grep entries` that no HTML entries routes remain, and via grep/test that no
   other file references the HTML entries controllers. Controller/view deletion is Phase 1 cleanup —
   a separate step once tests confirm no references.

3. **Rename `edge/v0` to `api/v0`** (3 route file changes; no controller changes needed): Replace
   `namespace :edge do namespace :v0 do` with `namespace :api do namespace :v0 do` in docs.rb,
   news.rb, help.rb (lines 17-21 each). Keep `resources :entries, only: %i[index show]` unchanged —
   param name stays `:id`, controllers stay `params[:id]`. Do not add `param: :slug`.

4. **Mark OIDC registry entries as dormant** (1 file change, no route touch): Add comment to each of
   the 9 entries in `oidc_client_registry.rb:189-244` per Stream 3a.

5. **Write tests** (Stream 1): Add fixture files and routing/controller tests for the 9 surface
   variants. These are currently entirely absent. Blocked on health refactor settling (Stream 2).

Do NOT include in the same task: health refactor (Stream 2), robot controller deletion, ingress
changes, Next.js integration, or ADR authoring.

---

## F. Things explicitly not to implement next

- Health refactor (Stream 2 — separate, in-flight, ~127 files uncommitted).
- Deletion of `RobotsController` files in docs/help/news (dead code, but premature to delete without
  confirming no deployment requires them as fallback).
- `robots.txt` route addition (Next.js owns this; transition plan is UNKNOWN).
- `sitemap.xml` route (same reason).
- `param: :slug` on `resources :entries` — do not add; keep `:id` per Rails convention.
- `GET /api/v0/entries/:slug` as an explicit named-param route — do not create.
- Simultaneous deletion of `EntriesController` files alongside route removal — phase it; delete only
  after test/grep confirms no remaining references.
- Taxonomy routes/models (explicitly deferred).
- Version/revision routes/models (explicitly deferred).
- Mutation routes (not in scope).
- OIDC auth callbacks for docs/help/news (surfaces remain bare).
- org-scoped authz (speculative; not defined).
- Ingress / Cloudflare / deployment configuration.
- Next.js integration or Next.js API client changes.
- OidcClientRegistry deletion of docs/news/help entries.
- Core route changes.
- Preference/cookie/theme routes.
- Contact/inquiry workflow.

---

## G. Suggested follow-up tasks (not next task)

| #   | Task                                                                               | Dependency                  |
| --- | ---------------------------------------------------------------------------------- | --------------------------- |
| G1  | Stream 2: health refactor — settle ~127-file in-flight change                      | None (already in progress)  |
| G2  | Stream 3a: add transitional-boundary ADR and annotate OIDC registry                | Can parallel next task      |
| G3  | Stream 1: write tests for all 9 surface variants                                   | Stream 2 must settle first  |
| G4  | Clarify `params[:ri]` — document or remove from `content_locale`                   | Needs product/arch decision |
| G5  | Add `updated_at` to `as_public_json` or document its omission                      | Before Next.js uses the API |
| G6  | Define robots.txt transition plan (who serves it during Next.js ramp?)             | Deployment decision         |
| G7  | Define org authz position: permanently bare or application-controller candidate    | ADR decision                |
| G8  | Define entry count/taxonomy threshold for deferral to remain safe                  | Product decision            |
| G9  | Decide `body` field format (Markdown/HTML/JSON) and document XSS handling          | Before Next.js renders      |
| G10 | ADR for `edge/v0` vs `api/v0` namespace semantics across all surfaces              | Before route rename         |
| G11 | Define `404 vs 410` response contract for non-published entries                    | Before Next.js caches       |
| G12 | Delete dead `RobotsController` files from docs/help/news once transition confirmed | After G6                    |
