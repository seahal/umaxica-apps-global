# Foundation and Distributor Content Design

## Purpose

This document records the current stable design for content surfaces split across `Foundation` and
`Distributor`.

It covers only `post.*` delivery for docs and news families.

`help` is not part of this design and is planned separately.

## Surface Mapping

Content is split by surface role and storage model:

- `docs` uses the `Document` model family
- `news` uses the `Timeline` model family

Audience-specific storage remains separate:

- `app` -> `AppDocument` / `AppTimeline`
- `com` -> `ComDocument` / `ComTimeline`
- `org` -> `OrgDocument` / `OrgTimeline`

Editing is performed only from the `org` staff CMS surface.

Foundation owns editorial write flows. Distributor owns public and API delivery on `post.*`.

Public delivery exists for `app`, `com`, `org`, `dev`, and `net`, but `dev` and `net` are restricted
by audience purpose.

## Canonical Content Models

### Docs

The canonical model family for `docs` is:

- entry: `*Document`
- draft/history: `*DocumentRevision`
- public snapshot: `*DocumentVersion`

Do not use `Post` or `PostVersion` for `docs`.

### News

The canonical model family for `news` is:

- entry: `*Timeline`
- draft/history: `*TimelineRevision`
- public snapshot: `*TimelineVersion`

`news` remains an application surface name. The storage model is `Timeline`.

Do not use `Post` or `PostVersion` for `news`.

## Editorial Model

The content model keeps both `revision` and `version`.

Their roles are different:

- `revision` stores draft and working history
- `version` stores public release snapshots

Editorial flow:

1. create an entry shell
2. save draft edits by creating a new `revision`
3. publish by creating or promoting a `version` from a selected `revision`
4. update the entry pointers and publication state

Public read controllers must use `latest_version_id` as the public source.

`latest_revision_id` is the working/history pointer and is not the public source.

## Publication Rules

An entry is publicly readable only when both conditions are satisfied:

- the entry is in an allowed published status
- `published_at <= now < expires_at`

This rule applies to both `docs` and `news`.

## Taxonomy Model

Taxonomy master data is tree-structured.

- category masters use a parent-child tree
- tag masters use a parent-child tree
- tree reads use recursive traversal

Assignment rules:

- category is single-valued per entry
- tag is multi-valued per entry

This means:

- one entry has at most one category assignment
- one entry can have many tag assignments
- duplicate assignment of the same tag to one entry is invalid

In v1:

- public APIs may read taxonomy trees
- staff CMS may assign existing taxonomy values
- taxonomy master CRUD is out of scope

## Out of Scope

The following are outside the current docs/news design:

- `help`
- `avatar.posts`
- review workflow
- taxonomy master CRUD
- cross-surface editing from `app` or `com`

## Related

- `adr/news-is-timeline.md`
- `adr/regional-docs-news-content-model.md`
- `plans/active/regional-docs-news-cms-implementation-plan.md`
