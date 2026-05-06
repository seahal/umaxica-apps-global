# ADR: News Content Uses Timeline Models

## Status

Accepted (2026-04-13)

## Context

The publication-consolidation plan identified three options for the `news` domain:

1. Treat news as a publication-backed document subtype.
2. Treat news as a publication-backed timeline subtype.
3. Create a dedicated publication-backed news model family.

Historical migrations in `db/publications_migrate/` show that `news` tables were renamed to
`timeline` tables during an earlier rebuild (migrations starting
`20251226000006_rebuild_app_timelines.rb`). The `Timeline` model family (`AppTimeline`,
`ComTimeline`, `OrgTimeline` and their versions, revisions, statuses, categories, and tags) already
stores what was previously called "news" content. OIDC client entries (`news_app`, `news_org`,
`news_com`) and locale keys (`news`, `newsroom`) reference the news surface, and routing delegates
to the press engine for content delivery.

No separate `News*` model classes exist, and no `News*` database tables exist in any schema.

## Decision

**Option 2: news content is a timeline subtype.**

The `Timeline` model family on `PublicationRecord` is the publication-backed storage for news
content. No additional model family is required.

## Consequences

- All news-related content is stored in `*_timelines` tables in the `publication` database.
- OIDC client registry entries and locale keys continue referencing `news*` names for the
  application surface while the storage layer uses `Timeline` models.
- If a future product requirement demands news-specific fields, lifecycle rules, or workflows that
  diverge from timeline, a dedicated model family can be introduced at that time. That decision
  would require a new ADR.
- The `news` routing surface (hosts, locale keys) remains valid as an application-level concept
  independent of the storage model.
