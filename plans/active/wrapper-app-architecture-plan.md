# Wrapper App Architecture Plan

## Status

Superseded (2026-04-22) by `adr/rails-way-engine-architecture-restoration.md`.

> **Superseded notice (2026-04-22):** The wrapper apps architecture is abandoned. The project
> returns to the Rails Way (single host Rails app + four mountable Fat Engines). Do not follow this
> plan. See `adr/rails-way-engine-architecture-restoration.md` for the current direction. A new
> implementation plan will be authored separately.

**Original status:** Active draft (2026-04-18)

## Summary

(Historical) Add one wrapper Rails app per engine so runtime boot follows standard Rails app
structure.

Wrapper apps:

- `apps/identity`
- `apps/zenith`
- `apps/foundation`
- `apps/distributor`

## Ownership

Each wrapper app owns:

- `config/application.rb`
- `config/environment.rb`
- `config/routes.rb`
- `config/importmap.rb`
- `config/initializers/*`
- middleware and session boot
- runtime asset registration

Each wrapper app mounts exactly one engine.

## Boot Rule

Operational target:

- `cd apps/identity && bin/rails s`
- `cd apps/zenith && bin/rails s`
- `cd apps/foundation && bin/rails s`
- `cd apps/distributor && bin/rails s`

The wrapper app is the runtime entrypoint.

## Sequencing

1. define common wrapper skeleton
2. stand up `apps/identity`
3. reuse the pattern for `apps/zenith`, `apps/foundation`, and `apps/distributor`
4. remove root-app runtime switching

## Acceptance

- each wrapper app boots one engine only
- no wrapper app depends on root `DEPLOY_MODE`
- runtime ownership is no longer ambiguous
