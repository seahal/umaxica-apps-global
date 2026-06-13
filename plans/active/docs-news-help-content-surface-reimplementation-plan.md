# Plan: Docs / News / Help Content Surface Routing And Responsibility

## Summary

`docs`, `news`, and `help` are Rails read-authority surfaces consumed by a Next.js public frontend.
This plan records the target routing and responsibility boundary only. It does not authorize route,
controller, model, migration, or test changes by itself.

The current repository has already reintroduced `docs`, `news`, and `help` route files,
controllers, content-entry models, and zenith migrations. Some current implementation details differ
from the target recorded here and should be treated as cleanup work for a future implementation
task, not as the final boundary.

## Repository Facts

- `config/routes.rb` currently draws `:help`, `:docs`, and `:news` after `:base` and `:palm`.
- `config/routes/docs.rb`, `config/routes/news.rb`, and `config/routes/help.rb` use host-constrained
  routing for `app`, `com`, and `org` variants.
- Current docs/news/help routes expose `/entries`, `/entries/:slug`, `/robots.txt`, and
  `edge/v0/entries`. These are implementation drift from the target decision below.
- Current roots and `/entries` controllers render shared Rails content-entry HTML through
  `ReadOnlyContentRendering`. The target keeps `/` as a thin root and does not make Rails the public
  article HTML renderer.
- Current content persistence uses lean `docs_content_entries`, `news_content_entries`, and
  `help_content_entries` tables in the surface zenith databases.
- Existing `OidcClientRegistry` state was not inspected or changed for this decision. Any remaining
  docs/news/help OIDC registry entries are not authoritative for these surfaces.

## Final Routing Decision

Keep host-constrained routing. Do not collapse docs/news/help into a single host, a single API host,
or a shared surface path segment.

For every docs, news, and help host variant, Rails should conceptually expose only:

```text
GET /
GET /health
GET /health/liveness
GET /health/readiness
GET /health/startup
GET /api/v0/entries
GET /api/v0/entries/:slug
```

This applies to all nine host variants:

```text
docs app host
docs com host
docs org host
news app host
news com host
news org host
help app host
help com host
help org host
```

The read API resource noun is `entries`, not `posts`. `posts` implies blog, SNS, or forum-style
posting and may conflict with real SNS posts elsewhere in Umaxica. `entries` is neutral and matches
the lean content-entry direction. For help, `entries` means help article or help content read API; it
does not mean Contact or inquiry workflow.

Do not adopt these shapes:

```text
/api/v0/docs/entries
/api/v0/news/entries
/api/v0/help/entries
/api/v0/content/docs/entries
single API host + surface path segment
```

## Responsibility Boundary

Next.js owns the public frontend for docs/news/help and core. Next.js owns public HTML, article
index pages, article show pages, SEO metadata, canonical URLs, `robots.txt`, `sitemap.xml`, public
404/410 rendering, UI/UX, and locale fallback rendering when needed.

Rails owns the thin root, health family, read-only entries API, content persistence, import tasks,
and current published/readable content authority. Rails is not the public HTML renderer for these
surfaces. Rails `/` must remain a thin root and must not render article indexes, render article show
pages, render SEO content, serve `robots.txt`, serve `sitemap.xml`, perform authoring, perform
mutation, require local session authority, or become an identity/session authority.

Hono and ReactRouter do not own the docs/news/help/core public frontend. Hono may remain for bounded
uses such as jump behavior.

## Explicitly Excluded

Do not create or keep Rails-owned public HTML article routes:

```text
GET /entries
GET /entries/:slug
```

Do not create or keep Rails docs/news/help SEO routes:

```text
GET /robots.txt
GET /sitemap.xml
```

Do not restore old RP, preference, taxonomy, version/revision, or mutation routes:

```text
GET /auth/callback
GET /web/v0/cookie
PATCH /web/v0/cookie
GET /web/v0/theme
PATCH /web/v0/theme
GET /api/v0/tags
GET /api/v0/categories
GET /api/v0/entries/:slug/versions
GET /api/v0/entries/:slug/versions/:id
GET /api/v0/entries/:slug/revisions
GET /api/v0/entries/:slug/revisions/:id
POST /api/v0/entries
PATCH /api/v0/entries/:slug
PUT /api/v0/entries/:slug
DELETE /api/v0/entries/:slug
```

Do not add placeholder routes, controllers, response contracts, or schemas for excluded future work.

## Product Decisions

- Versions and revisions are future planned capabilities, not part of current docs/news/help
  routing. `revision` may represent internal editing history and `version` may represent external or
  public version history, but the boundary is not defined. Exposing routes now would prematurely
  create a public API contract.
- Mutation routes are not implemented under docs/news/help. Create, update, delete, publish,
  unpublish, archive, restore, create-revision, and promote-revision operations belong to future
  base > org authoring or management work.
- Taxonomy is abandoned for now. Do not restore tags, categories, `TaxonomyBuilder`,
  `DocumentTagMaster`, `DocumentCategoryMaster`, `TimelineTagMaster`, or
  `TimelineCategoryMaster`. Category or tag support can be reintroduced later if there is a clear
  product need.
- Help Contact/inquiry is not part of help restoration. Do not restore `Contact`, `ContactStatus`,
  `ContactCategory`, topics, emails, telephones, token verification, or inquiry workflow under help.
  That workflow belongs to future core/base migration and design.
- `app` and `com` content reads are public by default. `org` may require org-scoped read
  authorization in the future, but docs/news/help must not become identity, session, or
  authorization authorities. Future auth/authz must depend on existing authority boundaries.
- Persistence is temporarily borrowed/colocated in the existing Rails storage direction. Do not
  relocate databases or restore the old full global model stack in this task. Use the existing lean
  content-entry direction: `slug`, `locale`, `title`, `summary`, `body`, `status`, `published_at`,
  and timestamps.

## Future Implementation Checklist

- Remove or replace docs/news/help Rails-owned `/entries` and `/entries/:slug` public HTML routes
  with the target Next.js ownership model.
- Remove or replace Rails docs/news/help `robots.txt` handling with the target Next.js ownership
  model.
- Move the read API from the current `edge/v0/entries` shape to `api/v0/entries` for each
  host-constrained surface variant.
- Make Rails roots thin and stop rendering article indexes from `roots#index`.
- Preserve host constraints and app/com/org namespace separation while making routing changes.
- Keep all implementation work out of `OidcClientRegistry`, Core routes, and unrelated surfaces
  unless a future task explicitly expands scope.
- Add tests only in a future implementation task; this decision-record task intentionally does not
  edit tests.

## Risks / Unknowns

- `UNKNOWN`: whether any external consumer currently depends on `/entries`, `/entries/:slug`,
  `/robots.txt`, or `edge/v0/entries` on docs/news/help hosts.
- `UNKNOWN`: whether production ingress requires Rails to answer `robots.txt` for docs/news/help
  hosts before Next.js takes ownership.
- Current code and the target route decision differ. Future implementation must treat that as
  planned cleanup, not as authority to preserve Rails public HTML rendering.
- The exact future authoring, version, revision, and taxonomy boundaries remain undefined.
