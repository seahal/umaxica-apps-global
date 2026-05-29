# Application Boundary Design

## Status

This file records the current replacement for the retired Rails Engine boundary model. The old
Identity / Zenith / Foundation / Distributor engine architecture is historical only.

## Repository Boundary

This repository is the global Rails application. It combines identity provider behavior and the
primary relying-party application in one Rails app.

Regional content delivery is isolated by repository boundary, not by Rails Engine boundary. Docs,
news, help, and other regional or locale-specific delivery belong to the regional repository.

## Surface Boundary

Within this Rails app, the active user-facing surfaces are:

| Surface | Purpose                      |
| ------- | ---------------------------- |
| `app`   | End-user product flows       |
| `org`   | Staff and organization flows |
| `com`   | Public and corporate flows   |

Treat these as independent boundaries. Do not mix controllers, routes, views, policies, sessions, or
request state across surfaces unless the code already provides an explicit shared abstraction.

## Routing and Isolation

- `config/routes.rb` draws root route fragments such as `acme`, `sign`, and `jump`.
- Route fragments use host constraints and surface-local modules to keep behavior separated.
- Cross-surface navigation uses ordinary Rails route helpers and explicit allowed redirect policy.
- There are no local Rails Engines, wrapper apps, `isolate_namespace` boundaries, or
  `Jit::<EngineName>` namespaces in the current architecture.

## Runtime Context

Request context is application-level and exposed through the current Actor API. Surface-specific
authentication, preference, and authorization state must be initialized through the established
controller lifecycle rather than through engine-local `Current` objects.

## Data Boundary

Surface-owned database names follow the `surface_role` model in
`docs/architecture/database-boundaries.md`. Database ownership is expressed by base records and
connection names, not by Rails Engine ownership.

## Related

- `adr/split-into-regional-and-global-repos.md`
- `adr/actor-current-facade.md`
- `docs/architecture/controller-boundaries.md`
- `docs/architecture/controller-lifecycle.md`
- `docs/architecture/database-boundaries.md`
