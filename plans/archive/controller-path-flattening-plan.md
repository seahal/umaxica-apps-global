# Controller Path Flattening Plan

## Status

Superseded (2026-05-07) by `adr/split-into-regional-and-global-repos.md`.

> **Superseded notice (2026-05-07):** The Rails Engine strategy and the four-app split have been
> abandoned. This repository is now a single ordinary Rails application (IdP on `id.*` + RP on
> `www.*`); regional surfaces (docs, news, help) live in a separate repository. The `engines/` tree
> and the `Jit::<Engine>::` namespace this plan flattens no longer exist as targets. Do not follow
> this plan. See `adr/split-into-regional-and-global-repos.md` for the current direction.

**Original status:** Active draft (2026-04-18)

## Summary

Flatten redundant engine path nesting so contributors do not need to navigate paths such as:

- `engines/foundation/app/controllers/jit/foundation/base/org/contacts_controller.rb`

Target shape:

- `engines/foundation/app/controllers/base/org/contacts_controller.rb`

## Rules

- keep `Jit::<Engine>::...` constants
- remove redundant `jit/<engine>` path nesting inside engine internals
- keep meaningful route and API segments only

Allowed remaining segments:

- `sign`, `acme`, `base`, `post`
- `app`, `org`, `com`, `dev`, `net`
- `web/v0`, `edge/v0`

## Matching Moves

Flatten in the same wave:

- controllers
- matching views and layouts
- matching helpers
- path-sensitive tests

## Loader Strategy

Use engine-local Zeitwerk mapping if needed so flattened paths still resolve to namespaced
constants.

## Sequencing

1. define flattened path convention
2. migrate one engine at a time
3. remove old nested layout immediately after the new layout passes

## Acceptance

- no migrated engine still keeps redundant `jit/<engine>` controller paths
- tests and views follow the same flattened convention
