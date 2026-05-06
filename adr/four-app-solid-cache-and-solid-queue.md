# Four-App Solid Cache and Solid Queue Adoption (2026-04-23)

> **Status update (2026-04-26):** Obsolete. Per `adr/split-into-regional-and-global-repos.md`
> (2026-04-25), the 4-app split (`identity` / `foundation` / `zenith` / `distributor`) has been
> abandoned. This repository is now a single Rails app (the **global** side of the global / regional
> split). The per-app cache/queue ownership boundary defined below no longer applies. Solid Cache
> and Solid Queue should be re-introduced as a single-app concern in a separate ADR if still wanted.
> Treat this document as historical only.

## Status

Accepted

## Context

The repository is moving away from the failed Rails engine shift and toward four independent Rails
applications:

- `identity`
- `foundation`
- `zenith`
- `distributor`

All four applications already carry database connections for cache and queue storage, and all four
carry the Solid Queue Puma plugin hook. At the same time, the current setup is only partially
adopted:

- database connections exist in each app
- root-level shared migrations are still used
- runtime configuration is not yet aligned across all four apps
- Solid Cache is not yet the active cache store in the four apps
- Solid Queue is not yet the uniformly wired Active Job adapter in the four apps

We want a single accepted direction for application-local cache and job infrastructure across the
four Rails applications.

## Decision

The four Rails applications will use Solid Cache and Solid Queue as their standard cache and job
infrastructure.

### Scope

- `identity`, `foundation`, `zenith`, and `distributor` all adopt Solid Cache and Solid Queue.
- Each application owns its own cache database and queue database.
- Cache and queue infrastructure are application-local concerns, not shared runtime services across
  the four apps.

### Runtime direction

- Solid Cache becomes the intended cache backend for the four Rails apps.
- Solid Queue becomes the intended Active Job backend for the four Rails apps.
- The Puma-side Solid Queue integration remains part of the expected application runtime model.

### Ownership direction

- Each app keeps its own queue and cache schema snapshot under its app directory.
- Each app should be able to prepare, migrate, and operate its own cache and queue databases as a
  normal part of app-local setup.
- Detailed migration-path placement and naming can evolve during implementation, but the ownership
  boundary is fixed: cache and queue belong to each app that uses them.

### Relationship to other persistence domains

- This decision is about cache and queue infrastructure only.
- It does not change the `chronicle` decision for audit persistence.
- It does not change the `occurrence` decision for rate-limit and anomaly-style counters.

## Consequences

- The four apps will converge on the same operational model for caching and job execution.
- Future setup work should remove partial adoption and wire Solid Cache and Solid Queue completely
  in each app.
- Shared root-level or library-era setup must not remain the long-term source of truth when it
  conflicts with app-local ownership.
- Reviewers should evaluate cache and queue changes against this four-app ownership rule.
