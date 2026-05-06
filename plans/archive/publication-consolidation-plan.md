# Publication Consolidation Plan

## Summary

Move document-like and news-like published content into the `publication` database and remove the
remaining split between `document` and `publication`.

## Scope

- Move document runtime storage to `publication`.
- Define `news` storage inside `publication`.
- Remove duplicated document tables and schema ownership confusion.
- Keep behavior and audit storage out of the content tables.

## Current Repo Findings (2026-04-13)

The repository consolidation is nearly complete.

- `publication` contains all document and timeline tables.
- `document` schema (`db/document_schema.rb`) has been removed (superseded by
  `publication_schema.rb`).
- `db/documents_migrate/` is frozen (see its README).
- All 24 document models now inherit from `PublicationRecord` (previously `DocumentRecord`).
- `DocumentRecord` class has been removed.
- Timeline models already used `PublicationRecord`.
- `news` domain decision: Option 2 — news is a timeline subtype (see `adr/news-is-timeline.md`).

## Target State

- `publication` is the only published-content database. (Done)
- Document models inherit from `PublicationRecord`. (Done)
- News content uses the existing `Timeline` model family on `PublicationRecord`. (Done — see ADR)
- `document` no longer owns live runtime tables. (Done — `document` DB connection removed from
  `config/database.yml`; `db/document_schema.rb` removed)
- Published content structure is consistent across documents, timelines, and news. (Done)

## Completed Phases

### Phase 1: Inventory (Done)

All 24 `DocumentRecord`-inheriting models and 4 referencing tests were identified and updated.

### Phase 2: Reader And Writer Cutover (Done)

Document models switched to `PublicationRecord`. No dual-read layer was needed because both
`DocumentRecord` and `PublicationRecord` already connected to the same `publication` database.

### Phase 3: News Definition (Done)

Decision: **news is a timeline subtype** (Option 2). See `adr/news-is-timeline.md`.

### Phase 4: Cleanup (Done)

- `DocumentRecord` class removed.
- `db/document_schema.rb` removed (superseded by `db/publication_schema.rb`).
- `db/documents_migrate/README.md` added to mark the directory as frozen.
- `docs/architecture/engine.md` updated to reflect current database and model mapping.
- Locale keys and OIDC client entries for `news`/`newsroom` remain as application-surface concepts.

## Decision Needed For News

**Decision made (2026-04-13): Option 2 — news is a timeline subtype.**

The `news` domain is served by the existing `Timeline` model family (`AppTimeline`, `ComTimeline`,
`OrgTimeline` and associated models). The rename from `news` to `timeline` was completed in earlier
migrations. No separate news model family is required.

If a future product need arises for news-specific fields or lifecycle that differ from timeline, a
dedicated publication-backed model family can be introduced at that time.

## Acceptance Criteria

- [x] No live document model depends on `DocumentRecord`. (Completed 2026-04-13: all 24 document
      models now inherit from `PublicationRecord`; `DocumentRecord` class removed.)
- [x] Published content reads and writes go through `PublicationRecord`.
- [x] `news` has a defined publication-backed storage shape. (Decision: Option 2 — news is a
      timeline subtype. See `adr/news-is-timeline.md`.)
- [ ] Duplicate document ownership across `document` and `publication` is removed or clearly marked
      as a temporary migration state. (`db/document_schema.rb` removed; `db/documents_migrate/`
      frozen.)

## Related Work

- `plans/backlog/gh628-move-preferences-to-setting-db.md`
- `plans/analysis/engine-boundary-plan.md`
