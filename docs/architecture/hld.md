# High-Level Design

## Purpose

This document describes the current high-level architecture for the global Rails application.

## Architecture Overview

The repository is a single Rails app with three user-facing surfaces:

| Surface | Responsibility                     |
| ------- | ---------------------------------- |
| `app`   | End-user product and account flows |
| `org`   | Staff and organization workflows   |
| `com`   | Public and corporate workflows     |

The application also contains identity provider and relying-party behavior that historically lived
behind engine names. Those engine boundaries are retired; the active boundaries are surfaces,
controller lifecycle contracts, database connection groups, and the separate regional repository.

## Routing

- `config/routes.rb` draws route fragments for the app.
- Route fragments apply host constraints and surface-local modules.
- New work should use RESTful routes and path helpers.
- Do not introduce local Rails Engines, wrapper apps, or cross-engine routing proxies.

## Data Ownership

Surface-owned database names follow the `surface_role` model documented in
`docs/architecture/database-boundaries.md`.

Cross-cutting and infrastructure databases remain separate, including `occurrence`, `chronicle`,
`avatar`, `redirector`, `search`, `queue`, `cache`, and `storage`.

## Quality Goals

- Keep surface boundaries explicit.
- Keep authentication, authorization, verification, CSRF, and rate-limit order intact.
- Keep business logic out of controllers.
- Keep database ownership readable through base records and connection names.
- Keep regional content concerns out of this repository unless a current ADR says otherwise.
