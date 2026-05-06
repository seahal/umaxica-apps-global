# Foundation / Distributor Docs/News CMS Implementation Plan

## Status

Active draft (2026-04-17)

## Summary

Implement Foundation-owned CMS editing and Distributor-owned delivery for `docs` and `news` using
the already accepted canonical model families:

- `docs` -> `Document`
- `news` -> `Timeline`

Implementation boundaries:

- editing only from the `base.org.*` staff CMS surface
- public read delivery from the `post.*` surface
- `help` is excluded from this plan
- `avatar.posts` is excluded

## Current Repo Findings

- `station` has stub staff CMS controllers for `docs`
- `station` has routes for `news`, but no meaningful controller implementation yet
- `press` has read endpoints, but they still return placeholder payloads
- `publication` schema already contains entry, revision, version, category, and tag tables for both
  `Document` and `Timeline`

## Implementation Changes

### 1. Distributor public read controllers

Replace placeholder delivery in the Distributor read surface with real model-backed behavior.

For `docs`:

- list entries from the `*Document` family
- show one entry from the current public version
- list versions for one entry
- show one version
- list category tree
- list tag tree

For `news`:

- mirror the same contract using the `*Timeline` family

### 2. Foundation staff CMS controllers

Implement content editing only under `base.org.*`.

For both `docs` and `news`, support:

- create entry shell
- show entry list
- show entry detail
- create draft revision
- edit by creating another draft revision
- assign one category
- assign zero or more tags
- publish a selected revision into a public version
- view version history

Do not implement taxonomy master CRUD in v1.

### 3. Draft and publish flow

- draft save creates a new `revision`
- publish creates or promotes a `version` derived from a selected `revision`
- entry updates `latest_revision_id`, `latest_version_id`, `status_id`, `published_at`, and
  `expires_at`

### 4. Taxonomy behavior

- category assignment stays one-per-entry
- tag assignment stays many-per-entry
- master CRUD remains out of scope for v1

## API and UI Contract

### Public read contract

`post.*` should expose the same shape for both `docs` and `news` resource families:

- entry list
- entry detail
- version list
- version detail
- category tree
- tag tree

### Staff CMS contract

`base.org.*` editing surface should provide:

- entry index
- entry create
- entry detail
- draft save
- taxonomy assignment
- publish action
- version history view

Foundation staff CMS is the only write surface.

## Test Plan

- `base.org.*` can create entries for `docs`
- `base.org.*` can create entries for `news`
- saving draft creates a new `revision`
- publishing from a revision creates or promotes a `version`
- `post.*` remains read-only
- non-Foundation surfaces cannot perform write operations

## Assumptions

- `help` will be designed in a separate Distributor track
- behavior matters more than historical naming during the first implementation pass
