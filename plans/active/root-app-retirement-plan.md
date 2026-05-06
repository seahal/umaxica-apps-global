# Root App Retirement Plan

## Status

Superseded (2026-04-22) by `adr/rails-way-engine-architecture-restoration.md`.

> **Superseded notice (2026-04-22):** The root app is no longer being retired. Under the restored
> Rails Way architecture, the root Rails app at the repository root is the canonical Rails
> application that mounts four mountable engines. Do not follow this plan. See
> `adr/rails-way-engine-architecture-restoration.md` for the current direction.

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
