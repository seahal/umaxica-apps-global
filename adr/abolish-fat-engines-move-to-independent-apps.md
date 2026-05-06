# Abolishing Fat Engine Design in Favor of Independent Rails Applications (2026-04-22)

> **Status update (2026-04-26):** Obsolete. Per `adr/split-into-regional-and-global-repos.md`
> (2026-04-25), both the Rails Engine strategy and the 4-app split strategy have been abandoned. The
> codebase is now divided into two independent repositories: this **global** repository (a single
> ordinary Rails app combining IdP and RP, served on `id.*` and `www.*`) and a separate **regional**
> repository (docs / news / help). The 4-app `apps/<name>/` layout described below is no longer the
> target architecture. Treat this document as historical only.

## Status

Accepted

## Context

The project previously adopted a "Fat Engine" architecture, where major domains (Identity, Zenith,
Foundation, Distributor) were implemented as Rails Engines mounted into a single root application.

However, we faced significant challenges in completing the migration due to the complexity of
isolating dependencies between engines, handling nested namespaces (`jit/<engine_name>/`), and
managing routing and view path precedence during engine mounting.

## Decision

We will discontinue the "Fat Engine" design approach and transition to independent Rails
applications (`apps/<name>/`) within the monorepo.

- **Prioritize Migration Completion**: This change is not based on the inherent superiority of one
  design over another, but is a pragmatic decision to ensure the migration is successfully
  completed. By operating as standard Rails applications while maintaining domain isolation, we
  reduce development and deployment complexity.
- **Monorepo Structure**: Independent Rails applications with their own Gemfiles and configurations
  will be located in `apps/identity`, `apps/zenith`, `apps/foundation`, and `apps/distributor`.
- **Handling of Existing Engine Implementations**: Existing code within `engines/` is marked for
  deprecation. However, it will be retained temporarily as a source for porting logic until each
  application is fully functional.
- **Shared Code**: Infrastructure code that is domain-neutral or shared across multiple domains will
  continue to reside in `lib/` and be referenced by each application.

## Consequences

- Each application will have an independent execution environment focused on its own domain.
- We are liberated from the complex Zeitwerk and mounting configurations specific to Rails Engines.
- The `engines/` directory will be deleted once all logic has been migrated to the respective
  applications in `apps/`.
