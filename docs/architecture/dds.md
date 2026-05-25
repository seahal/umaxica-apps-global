# Detailed Design Specification

## Purpose

This document translates the current global Rails app boundary model into implementation guidance.

## System Context

The Rails app serves the `app`, `org`, and `com` surfaces from one root application. The previous
Rails Engine and wrapper-app strategies are retired by
`adr/split-into-regional-and-global-repos.md`.

Regional content delivery is handled by a separate repository.

## Module Design

### Routing

- Keep route fragments under `config/routes/*.rb`.
- Use host constraints and surface-local modules for `app`, `org`, and `com`.
- Use ordinary Rails path helpers.
- Do not add `engines/`, `apps/<name>`, `isolate_namespace`, or engine routing proxies.

### Controllers

Controllers should use the current two-base lifecycle split:

- `BareController` for endpoints that do not use application authentication machinery.
- Surface-local `ApplicationController` for authentication-aware endpoints.

`OpenController`, `PrivateController`, and `GuestController` are legacy compatibility wrappers.
Authentication classification must be explicit concrete controller/action metadata, not controller
inheritance. Undeclared endpoints fail closed as `:deny_all`.

Surface behavior must remain local unless an existing shared concern explicitly abstracts it.

### Shared Code

| Layer                 | Ownership                                                   |
| --------------------- | ----------------------------------------------------------- |
| Controllers and views | Surface-local under `app/`                                  |
| Models                | Centralized in `app/models`                                 |
| Concerns              | Shared only through explicit local abstractions             |
| Services              | `app/services` unless a narrower existing namespace applies |
| Helpers               | Surface-local or shared through existing helper modules     |

## Data Design

Surface-owned database names follow the `surface_role` model documented in
`docs/architecture/database-boundaries.md`.

Cross-cutting and infrastructure databases remain separate, including `occurrence`, `chronicle`,
`avatar`, `redirector`, `search`, `queue`, `cache`, and `storage`.

## Verification

- Route tests should prove host constraints and surface isolation.
- Controller tests should cover authentication, authorization, verification, CSRF, and rate-limit
  behavior where relevant.
- Model and service tests should cover database connection ownership and business rules.
