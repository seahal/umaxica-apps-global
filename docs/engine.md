# Global Application Boundary

## Status

This document replaces the obsolete Rails Engine design notes that previously lived at this path.
Rails Engine extraction and the four-app split are both retired by
`adr/split-into-regional-and-global-repos.md`.

## Current Shape

This repository is a single ordinary Rails application. It owns the global product surface:

- `app`: end-user application surface
- `org`: staff and organization surface
- `com`: public and corporate surface

The regional content surface, such as docs, news, help, and other locale-specific delivery, belongs
to the separate regional repository.

## Routing Boundary

Routes stay in the root Rails app under `config/routes.rb` and `config/routes/*.rb`. Host
constraints and surface-local controller modules separate `app`, `org`, and `com` behavior.

Do not add `engines/`, wrapper apps under `apps/<name>`, `Jit::<EngineName>` namespaces,
`isolate_namespace`, deployment-mode engine mounting, or cross-engine routing proxies.

## Code Boundary

Use ordinary Rails layout:

- controllers, views, helpers, policies, and concerns live under `app/`
- shared Ruby support lives under `lib/` or existing local abstractions
- database ownership is expressed through base records and connection names, not engine ownership
- controller access contracts are expressed by the Open/Bare/Private/Guest boundary bases

## Related

- `adr/split-into-regional-and-global-repos.md`
- `docs/architecture/controller-boundaries.md`
- `docs/architecture/controller-lifecycle.md`
- `docs/architecture/database-boundaries.md`
- `docs/architecture/current_context.md`
