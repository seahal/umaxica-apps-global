# Root App Retirement Plan

## Status

Superseded (2026-05-07) by `adr/split-into-regional-and-global-repos.md`.

> **Superseded notice (2026-05-07):** The Rails Engine strategy and the four-app split have both
> been abandoned. This repository is now a single ordinary Rails application (IdP on `id.*` + RP on
> `www.*`); regional surfaces (docs, news, help) live in a separate repository. There is no "root
> app" being retired in favor of wrappers, and there are no engines being mounted. Do not follow
> this plan. See `adr/split-into-regional-and-global-repos.md` for the current direction.
>
> **Earlier supersede notice (2026-04-22, also obsolete):** Originally superseded by
> `adr/rails-way-engine-architecture-restoration.md`, which proposed keeping the root app as a host
> for four mountable Fat Engines. That ADR has itself been superseded by
> `adr/split-into-regional-and-global-repos.md`.

**Original status:** Active draft (2026-04-18)

## Summary

(Historical) The current root app was planned to be migration-only and fully removed under the
wrapper apps architecture. That direction has been abandoned.

## Rules

- no new domain code may be added to the root app
- no new runtime ownership may be added to the root app
- every remaining root file must be moved to an engine, a wrapper app, `lib/`, or deleted

## Retirement Sequence

1. create wrapper apps
2. move runtime boot into wrapper apps
3. move domain code into engines
4. remove root routes and `DEPLOY_MODE`
5. remove root importmap and root domain layouts
6. remove remaining root domain code
7. delete the root app

## Acceptance

- wrapper apps are the only runtime entrypoints
- root routes are gone
- `DEPLOY_MODE` is gone
- root app can be deleted without breaking runtime boot
