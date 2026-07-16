# Docs, Help, And News Content Boundary

## Purpose

This document describes the current responsibility split for `docs`, `help`, and `news`.

> **Persistence re-scoped (2026-07-16):** Per `adr/publishing-db-content-authority.md`, the content
> authority for `info`, `docs`, `news`, and `help` moves to the central `publishing` database
> (`Publishing::Entry` / `EntryRevision` / `EntryVersion` / `Publication` and media tables). All
> four surfaces are global content surfaces; `app`/`com`/`org` are audience identifiers. The
> "Persistence Direction" section below describes the superseded lean content-entry placement and is
> kept for migration reference only. Frontend ownership, routing direction, and the controller
> boundary in this document remain current.

## Frontend Ownership

Next.js owns the public frontend for `docs`, `help`, `news`, and `core`.

Next.js owns:

- public HTML;
- article index pages;
- article show pages;
- SEO metadata;
- canonical URLs;
- `robots.txt`;
- `sitemap.xml`;
- UI and UX;
- public 404 and 410 rendering;
- locale fallback rendering when needed.

Hono and ReactRouter do not own public HTML rendering, content frontend, SEO, or article pages for
`docs`, `help`, `news`, or `core`. Hono may remain for bounded uses such as jump behavior.

## Rails Ownership

Rails owns the content authority and read contract for `docs`, `help`, and `news`.

Rails owns:

- host-constrained surface routing;
- thin root endpoints;
- health endpoints;
- read-only content persistence;
- import tasks;
- read-only `api/v0/entries` contracts consumed by Next.js.

Rails must not own public article HTML rendering for these surfaces. Rails root endpoints may
remain, but they must stay thin and must not render article indexes, article detail pages, SEO
metadata, canonical URLs, `robots.txt`, or `sitemap.xml`.

## Routing Direction

Do not collapse `docs`, `help`, and `news` into a single host or a single API host with a surface
path segment. Keep the existing host-constrained routing model, with separation by host, namespace,
and surface.

Rails should conceptually keep:

```text
GET /
GET /health
GET /health/liveness
GET /health/readiness
GET /health/startup
GET /api/v0/entries
GET /api/v0/entries/:slug
```

The same route shape applies independently under each docs, help, and news app/com/org host.

The API resource noun is `entries`, not `posts`. `posts` implies blog, SNS, or forum-style posting
and may conflict with other Umaxica post domains. Help entries are help article/content reads; they
are not Contact or inquiry workflow.

Do not adopt a single API host or surface path segment. These shapes are not the target:

```text
/api/v0/docs/entries
/api/v0/news/entries
/api/v0/help/entries
/api/v0/content/docs/entries
```

Rails should not own:

- `/entries`;
- `/entries/:slug`;
- `/robots.txt`;
- `/sitemap.xml`;
- `/auth/callback`;
- `/web/v0/cookie`;
- `/web/v0/theme`;
- mutation routes;
- taxonomy routes;
- revision or version routes.

Do not add placeholder routes, controllers, response contracts, or schemas for excluded future work.

## Controller Boundary

`docs`, `help`, and `news` Rails controllers must not create identity, session, authorization,
preference, or OIDC authority.

For the current read-only public contract, use the surface-local `BareController` tier or an
equivalent API-only base that does not depend on:

- `ApplicationController`;
- authentication concerns;
- authorization concerns;
- Pundit or Action Policy user context;
- `Current` or `Actor`;
- Rails sessions;
- preference cookies or preference writes;
- OIDC callbacks.

`app` and `com` content reads are public by default. `org` content reads may become authenticated or
org-scoped in the future, but that must reuse the existing authority boundary and must not make
`docs`, `help`, or `news` a new identity, session, or authorization authority.

## Persistence Direction (superseded — migration reference only)

Use the lean content-entry direction. Do not restore the old `Document`, `Timeline`, `Contact`,
taxonomy, status, revision, or version model families.

The minimum content entry shape is:

- `slug`;
- `locale`;
- `title`;
- `summary`;
- `body`;
- `status`;
- `published_at`;
- timestamps.

Do not add category, tag, revision, version, publish workflow, `expires_at`, `redirect_url`,
`response_mode`, authoring UI, or approval workflow in the current phase.

Versions and revisions are future planned capabilities, but their boundary is not defined. A future
design may use revision for internal editing history and version for public release history. Do not
expose routes or schemas before that decision exists.

Taxonomy is abandoned for now. Category or tag support may be reintroduced later only with a fresh
product and API decision.

Mutation belongs to future base > org authoring or management work. Docs, help, and news remain
read-only surfaces.

The database is temporarily borrowed or colocated in the current Rails storage direction. Do not
restore the old full global model stack or relocate ownership as part of the current content-surface
cleanup.

## Related

- `adr/read-only-content-surfaces-in-rails.md`
- `docs/architecture/regional-content.md`
- `docs/architecture/acme-sign-core-base-port.md`
