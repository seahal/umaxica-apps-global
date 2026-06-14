# Post Publication Implementation Plan

## Status

Backlog planning note. Moved out of `plans/active` during active-plan strictness cleanup on
2026-06-14 because the current stable regional-content boundary does not authorize implementing this
repository-local `post` / publication surface yet.

Before this can return to `plans/active`, an ADR must explicitly decide whether `post` routes,
controllers, and publication storage belong in this repository or in the separate regional
repository.

## Context

`config/routes/post.rb` is not present in the current repository and has no tracked Git history in
this working copy. The current stable repository boundary says regional content delivery belongs to
the separate regional repository, not this global Rails app.

This plan is about docs/news publication history, not the global SNS-style or in-application `post`
boundary described in `docs/architecture/regional-content.md`. Global `post` work must not be used
as an implicit decision to bring docs/news/help publication back into this repository.

Older ADRs and archived plans still preserve the product and storage history:

- `post.*` was the former Publisher / Distributor public contract for content delivery.
- `docs` content maps to the `Document` model family on `PublicationRecord`.
- `news` content maps to the `Timeline` model family on `PublicationRecord`.
- `avatar.posts` and `post_versions` are explicitly not the intended storage for `docs/news`.
- archived publication work consolidated document-like and news-like published content into the
  `publication` database.

Because this plan intentionally reopens `post` / publication implementation work, it must be treated
as future-facing work until an ADR explicitly changes or narrows the current regional repository
boundary.

## Current Conflict To Resolve

Stable docs currently say:

- regional content delivery is outside this repository;
- `docs`, `news`, `help`, and similar regional or locale-specific delivery belong to the separate
  regional repository;
- this repository should not add regional content delivery implementation unless a current ADR
  changes that boundary.

Before implementation starts, write or update an ADR that decides one of:

- implement `post` in the separate regional repository and keep this repository limited to
  references and handoff notes;
- reintroduce a narrowly scoped `post` surface in this repository;
- keep storage contracts here but move routing/controllers to the regional repository.

## Database History

The historical database direction was:

- `Distributor`: owns `publication`.
- `publication` is the published-content database.
- document runtime storage moved from the old `document` split into `publication`.
- `DocumentRecord` was removed; document models inherited from `PublicationRecord`.
- timeline/news models already used `PublicationRecord`.

Current `config/database.yml` in this repository does not define `publication` or
`publication_replica`. It uses the current surface-owned database set (`app_principal`,
`org_principal`, `com_principal`, `*_ticket`, `*_zenith`, `*_signal`, `*_setting`) plus the
remaining cross-cutting databases. If `post` work returns to this repository, adding a publication
connection requires an explicit database migration plan and an ADR update, not an incidental config
edit.

## Intended Product Shape

Use the historical `post` name for the content publication surface only after the repository
boundary decision is updated.

The implementation should preserve these content model decisions:

- `docs` uses `*Document*` models.
- `news` uses `*Timeline*` models.
- staff editing belongs to the `org` CMS boundary.
- public reads can exist for `app`, `com`, and `org` delivery surfaces.
- draft saves create `revision` records.
- publishing creates or promotes a public `version` from a selected `revision`.
- public reads resolve from `latest_version_id`, never directly from draft revisions.
- readability requires published status and the `publish_at` / `expires_at` window.

## Implementation Phases

### Phase 1. Boundary Decision

- Write an ADR that supersedes or amends the current regional repository rule for `post`.
- Decide whether `post` routes live in this repository or the regional repository.
- Decide whether the host contract is `post.{app,com,org}.*`, another host, or path-scoped routing.
- Decide whether `help` is in scope or remains deferred.

### Phase 2. Database Placement

- Decide whether `publication` returns as a cross-cutting database in this repository or stays in
  the regional repository.
- Define `PublicationRecord` ownership and connection names.
- Define migrations paths and schema dump filenames.
- Add a production-safe migration plan for any database copy, rename, or restore from ZFS snapshots.
- Do not drop or destructively rename existing databases or tables without a separately approved
  operational plan.

### Phase 3. Route And Controller Skeleton

- Add route files only after the boundary ADR is accepted.
- Keep app/org/com boundaries separate; do not mix controllers, sessions, policies, or state across
  surfaces.
- Keep controllers focused on HTTP concerns.
- Put publication behavior in models, services, policies, or existing local abstractions.
- Use existing authentication, authorization, CSRF, and rate-limit pipelines.

### Phase 4. Content Services

- Implement draft revision creation.
- Implement publish promotion from revision to version.
- Implement public read resolution from `latest_version_id`.
- Implement publication-window checks.
- Keep taxonomy assignment compatible with single category and many tags.

### Phase 5. Tests And Verification

- Add model tests for document/timeline publication rules.
- Add service tests for revision-to-version promotion.
- Add controller tests for public read success, unpublished content, expired content, future
  content, authentication, authorization, and CSRF where relevant.
- Add route tests for each surface and host/path contract chosen by the ADR.
- Run the narrowest relevant tests first, then broader route/controller tests.

## Acceptance Criteria

- A current ADR explicitly authorizes the selected `post` repository and routing boundary.
- The selected database placement is documented and reflected in `config/database.yml` only when
  this repository owns the connection.
- `docs` reads and writes use `Document` models on `PublicationRecord`.
- `news` reads and writes use `Timeline` models on `PublicationRecord`.
- Public reads never serve draft revisions.
- Tests cover success, unpublished, not-yet-published, expired, and unauthorized cases.
- Stable docs are updated when implementation becomes current behavior.

## References

- `adr/regional-docs-news-content-model.md`
- `adr/news-is-timeline.md`
- `adr/split-into-regional-and-global-repos.md`
- `docs/architecture/regional-content.md`
- `plans/archive/publication-consolidation-plan.md`
- `plans/archive/four-engine-migration-sequence.md`
