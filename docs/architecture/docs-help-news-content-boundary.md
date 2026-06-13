# Docs, Help, And News Content Boundary

## Purpose

This document describes the current responsibility split for `docs`, `help`, and `news`.

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
- read-only JSON/read contracts consumed by Next.js.

Rails must not own public article HTML rendering for these surfaces. Rails root endpoints may
remain, but they must stay thin and must not render article indexes, article detail pages, SEO
metadata, canonical URLs, `robots.txt`, or `sitemap.xml`.

## Routing Direction

Do not collapse `docs`, `help`, and `news` into a single host or a single API host with a surface
path segment. Keep the existing host-constrained routing model, with separation by host, namespace,
and surface.

Rails should conceptually keep:

- `/`;
- `/health`;
- `/health/liveness`;
- `/health/readiness`;
- `/health/startup`;
- the read-only content API/read contract.

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

API URL naming is intentionally out of scope here. Do not infer a preferred `edge`, `web`, or `api`
path from this document.

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

## Persistence Direction

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

## Related

- `adr/read-only-content-surfaces-in-rails.md`
- `docs/architecture/regional-content.md`
- `docs/architecture/acme-sign-core-base-port.md`
