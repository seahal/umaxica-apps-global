# Plan: Re-implement docs / news / help as content surfaces

## Context

docs / news / help were removed from this repository during the 2026 rebuild. The objective is **not
restoration** but **re-implementation on the current architecture**: docs/news/help become **content
surfaces** — public, read-only content delivery with **no RP/IdP role, no auth/authz authority, no
actor/session/cookie/preference lifecycle**.

This plan is an audit + implementation plan only. **No code, migrations, or implementation are
produced here.** Everything below is grounded in repository evidence; items that could not be
verified are marked `UNKNOWN`.

User decisions captured this session:

- **URL strategy:** host-based per surface (`docs.*` / `news.*` / `help.*` via `*_SERVICE_URL` /
  `*_CORPORATE_URL` / `*_STAFF_URL`), matching the existing host-constraint convention — _not_ a
  single path-based `/docs` host.
- **Persistence shape:** per-surface tables (`app_*` / `com_*` / `org_*`), matching the existing
  per-surface convention — _not_ a single flat `content_entries` with a `surface` column.
- **Table naming:** separate tables per content namespace and surface, such as `app_docs_entries`,
  `app_news_entries`, `app_help_entries` and matching `com_*` / `org_*` tables — _not_ shared
  `*_content_entries` tables reused across docs/news/help.

---

## A. 現状監査結果 (Audit)

### Routes

- **Current:** `config/routes.rb` draws only `:acme`, `:sign`, `:core` (lines 7–12). **No** docs /
  news / help routes exist. `config/routes/` contains only `acme.rb`, `core.rb`, `sign.rb`.
- Only near-match present: `config/routes/sign.rb:398` `resources :support, only: :index` — staff
  operator support index, **unrelated** to content.
- **Old (git history, last non-empty versions):**
  - `config/routes/docs.rb` @ `6d4d13381a`, `config/routes/news.rb` & `config/routes/help.rb` @
    `f639724608`. Deleted in `cd15826aba` → `faa8aed371`.
  - Shape: host-constrained per surface — `DOCS_CORPORATE_URL`/`DOCS_SERVICE_URL`/`DOCS_STAFF_URL`
    (and `NEWS_*`, `HELP_*`), each with `com`/`app`/`org` scope.
  - Each old surface exposed: `root "roots#index"`, `resource :health`, `robots.txt`, `sitemap.xml`,
    `namespace :auth { resource :callback }` (**OIDC callback**), `web/v0/{cookie, theme}`
    (**preference writes**), and `edge/v0` JSON API: `posts` (index/show) + nested `versions`,
    `tags`, `categories`. **help** had no `posts` — only `edge/v0/{health,sitemap}`.
  - **No path-based `/docs/:slug` ever existed.** Public content was the per-host root + `edge/v0`
    JSON API. The literal `/docs` `/news` `/help` framing in the objective is a **new** shape.
- **Compat / redirect / legacy routes:** none found in current repo.

### Models

- **Current:** **No** docs/news/help/content/article/document/faq model classes in `app/models`. No
  `content_entries` / `content_entry` model anywhere.
- `Post*` tables exist in `db/avatar_structure.sql` (`posts`, `post_versions`, `post_reviews`,
  `post_statuses`, `post_review_statuses`) but **have no ActiveRecord model classes**. Per
  `docs/architecture/regional-content.md`, `post` = SNS-style in-app posts, **explicitly not**
  docs/news publication.
- **Old (git history):** `ComPost/AppPost/OrgPost` (+ `*PostVersion`, `*PostTag*`, `*PostCategory*`,
  taxonomy join tables) on `com_publisher/app_publisher/org_publisher` DBs;
  `ComContact/AppContact/OrgContact` (help/inquiry) on `guest` DB. All deleted (`cc419fb3b`,
  `83ec2126d`).

### Migrations

- **Current:** No migrations create/drop docs/news/help/content tables. `Post*` tables created in
  `db/avatars_migrate/20251225200010_*` and reshaped (uuid→bigint) in `...20260201160000_*`. No
  `content_entries` migration anywhere.

### Data shape (old, from history)

- Old `*Post` (docs/news): `body`, `permalink` (unique, len 200), `published_at`, `expires_at`,
  `response_mode` (html/redirect), `redirect_url`, `revision_key`, `position`, `lock_version`,
  `public_id` (unique), `author_avatar_id`, `*_post_status_id`, `created_by_actor_id`,
  `latest_*_revision_id`, `latest_*_version_id`, `published_by_actor_id`. `*PostVersion`: `title`,
  `description`, `body`, `permalink`, `publish_at`, `expires_at`, `response_mode`, `redirect_url`,
  `public_id`, `edited_by_{id,type}`.
- **Mapping to objective's proposed columns:** `title`→version `title`; `body`→`body`;
  `summary`→closest is version `description`; `slug`→**old used `permalink`, not `slug`**;
  `published_at`→`published_at`/`publish_at`; `status`→`*_post_status_id` (FK, not a string);
  `category`/`tag`→separate master+join tables. **`locale` and `summary`: NOT FOUND** as columns in
  old `*Post`/`*PostVersion`. Do not assume parity.

### Dependencies / coupling (old impl)

- Old `docs/<surface>/application_controller.rb` (`f723842cde`) inherited the **heavy** surface
  ApplicationController and included `RateLimit`, `Preference::Regional`, `Authentication::User`,
  `Authorization::User`, `Verification::User`, `Pundit`, `Current`, `Finisher`; before_actions
  `enforce_withdrawal_gate!`, `transparent_refresh_access_token`, `enforce_access_policy!`,
  `enforce_verification_if_required`, `set_current`. Old help/contact additionally used
  `CloudflareTurnstile`, `Rotp`, mailers.
- **Conclusion:** old docs/news/help were fully coupled to Authentication / Authorization /
  Verification / Session / Actor / Preference / OIDC. The target content-surface model requires
  **zero** of these.

### Source-of-truth conflicts (must be resolved before implementation)

1. `adr/split-into-regional-and-global-repos.md` (Accepted) +
   `docs/architecture/regional-content.md`: docs/news/help are **Regional** surfaces owned by a
   **separate regional repository**. "Do not add regional content delivery implementation to this
   repository unless a current ADR explicitly changes the repository boundary." → **the objective
   reverses this; requires a superseding ADR.**
2. `adr/regional-docs-news-content-model.md` (Accepted): docs=`Document` family, news=`Timeline`
   family on `PublicationRecord`, with revision/version split, taxonomy, **org-CMS editing**, public
   read for app/com/org. → conflicts with the lean read-only `content_entries` + per-surface-table
   direction; requires a superseding/amending ADR.
3. `adr/regional-help-surface-direction.md` (Accepted): help reserved, no v1 content model, inquiry
   moved to `base`. → help-as-read-only-content is a direction change.

### Confirmed-correct building blocks (current architecture)

- `adr/two-base-authentication-mode-boundaries.md` (Accepted 2026-05-25) is the **current**
  controller-base authority: only `BareController` (inherits `ActionController::Base`, mode `:bare`,
  no auth machinery) and surface-local `ApplicationController` (auth-aware, `AUTHENTICATION_MODE`
  metadata). `:bare` is explicitly the right tier for "lightweight endpoints that do not use
  authentication machinery." → **BareController + `:bare` is the correct vehicle.**
- `adr/public-controller-base.md` and `adr/three-tier-controller-base.md` are **Historical /
  superseded** — do **not** introduce `PublicController` / `OpenController`.
- BareController reference implementation: `app/controllers/acme/app/bare_controller.rb` (inherits
  `ActionController::Base`; includes `RateLimit`; `AUTHENTICATION_MODE = :bare`;
  `protect_from_forgery using: :header_or_legacy_token`; `allow_browser versions: :modern`).
- **Base surface does not exist in code:** no `config/routes/base.rb`, no `app/controllers/base/`.
  The accepted Base contract (`docs/architecture/acme-sign-core-base-port.md`) defines Base as an
  **authenticated Rails control-plane** (settings/account/admin), _not_ a public content surface —
  so the objective's "Base = 公開・共通 surface" diverges from that doc. Per the user's host-based
  decision, docs/news/help should be their **own host-constrained content surfaces**, not folded
  into the authenticated Base contract.
- **Surface-authority divergence to flag (not adopt):** objective's Background says "Sign =
  Identity/Session authority, Acme = Account/Org authority." Repo source-of-truth
  (`acme-sign-core-base-port.md`, referenced `identity-authority-boundary.md`) says **Acme** is the
  IdP + Session/Token/Account/Preference/Authorization authority and **Sign (`id.*`)** is a
  credential gateway, **not** a session authority. Implementation must follow the repo model; this
  divergence does not affect content surfaces (they are neither) but should be reconciled in chat.

---

## B. リスク一覧 (Risks)

### High

- **H1 — Repository-boundary ADR conflict.** Implementing here directly contradicts the accepted
  regional/global split. Mitigation: **Phase 0** writes a superseding ADR before any code.
- **H2 — Content-model ADR conflict.** Namespace-specific content-entry tables diverge from
  accepted `Document`/`Timeline`+`PublicationRecord` model. Mitigation: amend/supersede
  `adr/regional-docs-news-content-model.md` and `regional-help-surface-direction.md` in Phase 0.
- **H3 — No Base/content surface scaffolding exists.** The "simple 200" entrypoint silently requires
  standing up entire host-constrained surfaces (route files + per-surface controller trees + host
  ENV + trusted-origins/CSP/host fixtures). This is the audit's main hidden cost.

### Medium

- **M1 — Database placement is unresolved.** Old content lived on `*_publisher` DBs; ADR references
  `PublicationRecord`; **`config/database.yml` currently defines no `publication`/`publisher`
  connection** (per `plans/active/post-publication-implementation-plan.md`). The connection/DB group
  for new per-surface content tables is `UNKNOWN` and must be decided in Phase 2.
- **M2 — Surface non-mixing rule.** AGENTS.md forbids mixing app/org/com. Per-surface tables +
  per-surface controllers (the chosen direction) satisfy this; a shared table would have risked it.
- **M3 — Host-constraint / fixture wiring.** New `*_SERVICE_URL`/`*_CORPORATE_URL`/`*_STAFF_URL`
  ENV, dev `*.localhost` hosts, and CI host fixtures must be added or the surfaces are unreachable.
- **M4 — Route-inventory CI.** `two-base-...md` requires every route's concrete controller/action to
  carry an explicit `AUTHENTICATION_MODE`; bare/open are flagged as fail-open vectors. New
  controllers must declare `:bare` explicitly (no inherited-only declarations).

### Low

- **L1 — URL compatibility.** No evidence any old public docs/news/help URL is live in production
  (surfaces were dev-only, recently removed). Old `/auth/callback`, `/web/v0/{cookie,theme}` are
  auth/preference-coupled and must **not** be restored. See URL classification below.
- **L2 — Data shape mismatch.** Objective columns `slug`/`summary`/`locale` do not map 1:1 to old
  schema (`permalink`/`description`/none). New design defines them fresh; no import parity assumed.

### URL compatibility classification

- **must keep:** none identified (no evidence of live production URLs). `UNKNOWN` whether any
  external consumer depends on old hosts; confirm before deleting ENV host entries.
- **should keep (conceptually):** the read-only JSON edge API shape (`edge/v0/...`) is the ancestor
  of the future API (Phase 5) — re-design rather than restore.
- **safe to remove:** `namespace :auth { resource :callback }` (OIDC RP), `web/v0/cookie`,
  `web/v0/theme` (preference writes) — all contradict the content-surface (no-auth) model.

---

## C. 推奨復旧戦略 (Recommended strategy)

**Option 3 — New re-implementation.** Reasons grounded in the audit:

- The objective explicitly forbids restoring the old implementation.
- The old impl was fully **auth/authz/verification/actor/OIDC/preference-coupled** (heavy
  ApplicationController); the target is **zero-coupling BareController `:bare`**. Almost nothing is
  reusable as-is.
- The old data model (`*Post`/`*PostVersion` + revision/version + taxonomy, or the ADR's
  `Document`/`Timeline`+`PublicationRecord`) is far heavier than a read-only content surface needs,
  and uses `permalink`/`description`, not the objective's `slug`/`summary`/`locale`.
- The old URL shape (host roots + `edge/v0/posts`) differs from the chosen target (host-based
  content surfaces with a lean read model).

Option 1 (full restore) is rejected by the objective and by coupling. Option 2 (partial restore) is
not worthwhile: the only reusable assets are _patterns_ (host-constraint route structure, the
current `BareController` skeleton), which Option 3 already adopts by reference.

---

## D. 実装フェーズ (Implementation phases)

### Phase 0 — Decision / ADR (blocking)

- Write a superseding ADR that: (a) brings docs/news/help **content delivery** back into this repo
  as read-only content surfaces (supersedes the regional-repo boundary for these surfaces only); (b)
  records the per-surface-table + BareController `:bare` model and that it **amends**
  `adr/regional-docs-news-content-model.md` / `regional-help-surface-direction.md` (read-only, no
  CMS/editing, no revision/version, no taxonomy in v1); (c) reconciles the Acme/Sign authority
  wording. Update `docs/architecture/regional-content.md` status accordingly.
- Decide the **database group/connection** for the new tables (resolves M1) — verify against
  `config/database.yml` and `plans/active/post-publication-implementation-plan.md`.

### Phase 1 — Entrypoint revival (200 OK, static)

- Add `draw :docs`, `draw :news`, `draw :help` to `config/routes.rb`.
- Create `config/routes/{docs,news,help}.rb`, host-constrained per surface
  (`*_SERVICE_URL`/`*_CORPORATE_URL`/`*_STAFF_URL`, `app`/`com`/`org` scopes), exposing **only**
  `root "roots#index"` initially (plus `health`/`robots`/`sitemap` if desired). **No** `auth`,
  `web/v0`, OIDC.
- Create per-surface controller trees `app/controllers/{docs,news,help}/{app,com,org}/`:
  - `bare_controller.rb` modeled on `app/controllers/acme/app/bare_controller.rb`
    (`< ActionController::Base`, `include RateLimit`, `AUTHENTICATION_MODE = :bare`, CSRF header
    token, `allow_browser`).
  - `roots_controller.rb < BareController` (`AUTHENTICATION_MODE = :bare` declared explicitly),
    rendering a static page → **200**.
- Add ENV + dev `*.localhost` host entries + CI host fixtures (M3); ensure route-inventory CI passes
  (M4). Tests: request specs asserting 200 and absence of any auth/session/cookie behavior.

### Phase 2 — Content model (per-surface, read-only)

- Add separate per-namespace, per-surface tables on the Phase-0 DB group: `app_docs_entries`,
  `app_news_entries`, `app_help_entries`, with matching `com_*` and `org_*` tables. Candidate
  columns: `slug` (unique per table), `title`, `summary`, `body`, `status`, `locale`,
  `published_at`, timestamps.
  **Rationale for each beyond the objective's set:** `locale` — content surfaces are
  region/locale-specific by definition (regional-content.md); `status` + `published_at` — minimal
  publish gate without the heavy revision/version split. **Defer** category/tag/taxonomy (not needed
  for v1 read-only). Migrations: reversible, additive, no app models, follow `.harnes/rules/...`
  migration rules.
- Add corresponding per-surface model classes (reuse existing surface base-record pattern; confirm
  the connection base class chosen in Phase 0).

### Phase 3 — Import

- Define a one-off, idempotent import path (rake task / seed) mapping any retained legacy content
  into the new tables. **Mapping is lossy** (`permalink`→`slug`, version `description`→`summary`;
  `locale` newly assigned). Mark fields with no source as `UNKNOWN`/default. No import inside
  migrations.

### Phase 4 — Public read

- Add read-only show/index actions on BareController (e.g. `roots#index` listing published entries;
  a `entries#show` by `slug`), resolving only `status` published + `published_at` window. No draft
  exposure. Tests: published vs unpublished, locale, 404 for unknown slug, no auth side effects.

### Phase 5 — Optional Rails JSON API boundary

- If a JSON API is needed, expose it from Rails as the content **authority** and redesign the old
  `edge/v0` shape as a GET-only, versioned, `:bare`, cache-friendly API. Contract: list + show by
  slug + (later) taxonomy. Define schema explicitly before implementing. No frontend integration is
  planned here; handle presentation-layer integration in a separate plan if a concrete need appears.

---

## Critical files

- `config/routes.rb` (add draws); new `config/routes/{docs,news,help}.rb`.
- New `app/controllers/{docs,news,help}/{app,com,org}/{bare_controller,roots_controller}.rb`
  (pattern: `app/controllers/acme/app/bare_controller.rb`).
- New per-surface migrations under the Phase-0-chosen `db/<group>_migrate/`; new per-surface models
  under `app/models/`.
- New ADR under `adr/`; update `docs/architecture/regional-content.md`.

## Verification

- `bin/rails routes` shows the new host-constrained docs/news/help routes; route-inventory CI passes
  (every action has explicit `AUTHENTICATION_MODE`).
- Request specs: `root` returns **200** on each surface host with no `Set-Cookie`, no auth redirect,
  no actor/session state (Phase 1).
- Model/connection tests confirm per-surface isolation and correct DB group (Phase 2).
- Public-read specs: published-window + locale + 404 (Phase 4); JSON contract specs (Phase 5).
- `bin/rails test` narrow first, then broader where shared behavior is touched.

## Open / UNKNOWN items

- Exact database group/connection for content tables (M1) — resolve in Phase 0.
- Whether any old public URL/host is live externally (must-keep) — confirm before removing ENV.
