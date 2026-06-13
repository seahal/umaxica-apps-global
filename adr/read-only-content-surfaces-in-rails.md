# ADR: Read-Only Docs, News, And Help Content Surfaces In Rails

## Status

Accepted (2026-06-13)

## Context

`docs`, `news`, and `help` were previously treated as regional content surfaces outside this
repository. `docs/architecture/regional-content.md` said not to add regional content delivery here
unless a current ADR changed that boundary.

The current implementation direction brings a small v1 content delivery surface back into this Rails
application. The goal is public, read-only delivery only. It does not restore the previous regional
engine, CMS editing, OIDC relying-party callbacks, preference writes, or authenticated actor
lifecycle.

The existing `adr/regional-docs-news-content-model.md` accepted a heavier regional model: `Document`
for docs, `Timeline` for news, revision/version split, taxonomy, and org CMS editing. That model
remains useful historical context, but it is larger than this v1 delivery need.

## Decision

Implement `docs`, `news`, and `help` as read-only content surfaces in this Rails application.

Each surface has app, com, and org host variants. Public delivery controllers use the surface-local
`BareController` tier and declare `AUTHENTICATION_MODE = :bare`. They must not use Rails browser
sessions, authenticated actors, OIDC callbacks, preference writes, or application-controller
lifecycle callbacks.

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
- Existing OIDC client-registry entries for `docs`, `news`, and `help` are not made authoritative by
  this ADR. They remain a separate integration question.
- Content import must be an explicit task or seed/import command, not a migration side effect.

## Related

- `docs/architecture/regional-content.md`
- `adr/regional-docs-news-content-model.md`
- `adr/surface-database-connection-naming.md`
- `plans/active/docs-news-help-content-surface-reimplementation-plan.md`
