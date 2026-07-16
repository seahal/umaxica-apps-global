# ADR: Read-Only Docs, News, And Help Content Surfaces In Rails

## Status

Superseded by `adr/publishing-db-content-authority.md` (2026-07-16)

Accepted (2026-06-13)

> **Superseded:** コンテンツ authority は zenith DB の lean content-entry テーブルから中央
> `publishing` DB へ移行する。docs/news/help を含む info/docs/news/help はすべて global content
> surface となり、taxonomy 廃止・revision/version future の判断も新 ADR に置き換わる。API noun
> `entries`、host 分離ルーティング、Next.js/Rails の責務分担、BareController 境界は新 ADR でも維持される。

## Context

`docs`, `news`, and `help` were previously treated as regional content surfaces outside this
repository. `docs/architecture/regional-content.md` said not to add regional content delivery here
unless a current ADR changed that boundary.

The current implementation direction brings a small v1 content authority back into this Rails
application. Public HTML rendering for `docs`, `news`, and `help` belongs to the frontend
application, not Rails. Rails owns thin roots, health endpoints, content persistence, import, and a
read-only API/read contract for the frontend. This does not restore the previous regional engine,
CMS editing, OIDC relying-party callbacks, preference writes, or authenticated actor lifecycle.

The existing `adr/regional-docs-news-content-model.md` accepted a heavier regional model: `Document`
for docs, `Timeline` for news, revision/version split, taxonomy, and org CMS editing. That model
remains useful historical context, but it is larger than this v1 delivery need.

## Decision

Implement `docs`, `news`, and `help` as read-only content authority surfaces in this Rails
application.

Each surface has app, com, and org host variants. Keep host-constrained routing; do not collapse
`docs`, `news`, and `help` into one host with a surface path segment.

The public frontend owner for `docs`, `news`, and `help` is Next.js. Next.js owns public HTML,
article index and show pages, SEO metadata, canonical URLs, `robots.txt`, `sitemap.xml`, UI/UX,
public 404/410 rendering, and locale fallback rendering when needed. Hono and ReactRouter are not
owners for the `docs`, `news`, `help`, or `core` public frontend. Hono may remain for bounded
purposes such as jump behavior, but not for content frontend ownership.

Rails owns the read side of the content authority:

- thin root endpoints;
- health endpoints;
- content persistence;
- import tasks;
- read-only `api/v0/entries` contracts consumed by the frontend.

Rails must not own public article HTML routes for these surfaces. Rails root endpoints may exist,
but they must remain thin: they must not render article indexes, article details, SEO metadata,
canonical URLs, `robots.txt`, or `sitemap.xml`.

For each docs, news, and help host variant, the target Rails routing surface is:

```text
GET /
GET /health
GET /health/liveness
GET /health/readiness
GET /health/startup
GET /api/v0/entries
GET /api/v0/entries/:slug
```

The same route shape applies independently under the app, com, and org host variants for docs, news,
and help. Do not use a single API host, a path-based surface segment, or paths such as
`/api/v0/docs/entries`, `/api/v0/news/entries`, `/api/v0/help/entries`, or
`/api/v0/content/docs/entries`.

The read API resource noun is `entries`, not `posts`. `posts` is reserved for blog, SNS, or
forum-style posting semantics and may conflict with other Umaxica post domains. For help, `entries`
means help article or help content reads, not Contact or inquiry workflow.

Public delivery and read-contract controllers use the surface-local `BareController` tier and
declare `AUTHENTICATION_MODE = :bare` by default. They must not use Rails browser sessions,
authenticated actors, OIDC callbacks, preference writes, or application-controller lifecycle
callbacks. `app` and `com` content reads are public by default. `org` content reads may require
authenticated or org-scoped read access in the future, but any such access must depend on the
existing authority boundary and must not make `docs`, `news`, or `help` an identity, session, or
authorization authority.

For v1, use lean content-entry tables instead of the historical `Document`/`Timeline` model
families:

- `docs_content_entries`
- `news_content_entries`
- `help_content_entries`

Each table stores published read-model fields: `slug`, `locale`, `title`, `summary`, `body`,
`status`, and `published_at`.

The tables live in the existing surface zenith databases:

- app content: `app_zenith`
- com content: `com_zenith`
- org content: `org_zenith`

This is an intentional v1 placement decision. It extends zenith beyond account and subject
projection storage for these read-only content entries. A future ADR may split content into
dedicated `app_content`, `com_content`, and `org_content` connections if the content model grows.

## Consequences

- This ADR supersedes the regional-content repository boundary for read-only `docs`, `news`, and
  `help` delivery in this Rails repository.
- This ADR amends `adr/regional-docs-news-content-model.md` for the current Rails v1 implementation.
- The old regional `Document`/`Timeline`, revision/version, taxonomy, and org CMS editing model is
  not implemented in this pass.
- Version and revision routes remain future work only. Do not add placeholder routes, controllers,
  response contracts, or schemas until their boundary is defined.
- Taxonomy is abandoned for now. Tags, categories, taxonomy builders, and taxonomy master model
  families are not part of the current routing or persistence boundary.
- Mutation belongs to future base > org authoring or management work. `docs`, `news`, and `help`
  expose no create, update, delete, publish, unpublish, archive, restore, revision-create, or
  revision-promotion endpoints.
- Help is a read surface for help content. It does not own Contact, inquiry, contact-status,
  contact-category, topic, email, telephone, or token-verification workflow.
- Existing OIDC client-registry entries for `docs`, `news`, and `help` are not made authoritative by
  this ADR. They remain a separate integration question.
- Content import must be an explicit task or seed/import command, not a migration side effect.
- Rails public article HTML routes, `robots.txt`, and `sitemap.xml` for `docs`, `news`, and `help`
  should be delegated to the frontend. Existing Rails routes with those responsibilities are
  compatibility or cleanup work, not the target boundary.
- Existing Rails `/entries`, `/entries/:slug`, `/robots.txt`, and non-`api/v0` entries routes are
  cleanup work, not the target boundary recorded by this ADR.

## Related

- `docs/architecture/docs-help-news-content-boundary.md`
- `docs/architecture/regional-content.md`
- `adr/regional-docs-news-content-model.md`
- `adr/surface-database-connection-naming.md`
