# Four-App Engine Enforcement Decisions

## Status

Active draft (2026-04-18)

## Summary

This document closes implementation-blocking decisions for the Rails-way four-app target.

It defines:

- engine versus wrapper ownership
- shared code limits
- `dev` and `net` expectations
- canonical environment naming
- controller path flattening
- root app retirement rules

## 1. Ownership Boundary

### Engine ownership

Each engine owns:

- models
- DB base records and persistence logic
- domain services
- engine-specific concerns
- engine-specific helpers
- engine views
- engine assets
- engine locale files
- engine tests

### Wrapper ownership

Each wrapper app owns:

- `config/application.rb`
- `config/environment.rb`
- `config/routes.rb`
- `config/importmap.rb`
- `config/initializers/*`
- session and middleware boot
- runtime asset boot
- deployment-specific config

### Shared code rule

Shared code is restricted to `lib/`.

Put code in `lib/` only if it is:

- engine-neutral
- persistence-neutral
- route-neutral
- runtime-neutral or shared boot support

Do not keep shared-by-default code in root `app/models`, `app/services`, `app/helpers`, or
`app/controllers/concerns`.

## 2. Packwerk And Static Boundaries

Packwerk remains the static enforcement tool for engine boundaries.

Package layout target:

- `engines/identity`
- `engines/zenith`
- `engines/foundation`
- `engines/distributor`
- wrapper apps as separate app roots

Rule set:

- direct engine-to-engine constant references are forbidden unless a documented shared interface is
  used
- shared code may be referenced only from `lib/`
- root app packages are temporary and must shrink toward deletion

## 3. Cross-Boundary Event Ownership

Before any persistence refactor starts, every unchecked event must have:

- one engine write owner
- one destination database family
- one rule for whether a paired write is required

Minimum rule:

- `Identity` writes activity events
- `Zenith` writes journal events
- `Foundation` writes chronicle events
- `Distributor` writes publication events

`behavior` is not a valid Foundation target name. Foundation uses `chronicle`.

## 4. `dev` And `net`

### `dev`

`dev` is a human operational audience.

Rules:

- use authenticated staff session rules
- keep authorization explicit
- do not use Basic auth as the primary guard
- move operational tools such as `MissionControl::Jobs` to wrapper/engine surfaces intended for
  `dev`

### `net`

`net` is a non-public machine audience.

Rules:

- keep it API-first
- no browser-first HTML workflow
- no dependency on browser session auth
- restrict it to explicit internal-service use

## 5. Canonical ENV Scope

Canonical env naming is:

- `ENGINE_SURFACE_AUDIENCE_URL`
- `ENGINE_SURFACE_AUDIENCE_TRUSTED_ORIGINS`

Examples:

- `IDENTITY_SIGN_APP_URL`
- `ZENITH_ACME_APP_URL`
- `FOUNDATION_BASE_ORG_URL`
- `DISTRIBUTOR_POST_NET_URL`

Browser-facing trusted origins are required for:

- `app`
- `org`
- `com`
- `dev`

`net` does not require trusted-origin variables in this migration.

## 6. Runtime Boot Ownership

### Wrapper-app-owned by default

The default rule is:

- runtime boot belongs to the wrapper app

This includes:

- `config/application.rb`
- runtime initializers
- importmap pins
- session store
- middleware wiring
- runtime asset registration

### Global boot only when identical

Keep root-global boot only if it is identical for every wrapper app, such as:

- inflections
- parameter filtering
- low-level Ruby and Rails compatibility
- shared boot helper libraries called from wrapper apps

If an initializer exists because one engine needs it, it does not stay root-global.

## 7. Controller Path Flattening

Flatten redundant engine path nesting inside each engine.

Allowed remaining segments:

- surface: `sign`, `acme`, `base`, `post`
- audience: `app`, `org`, `com`, `dev`, `net`
- API segments: `web/v0`, `edge/v0`

Removed redundant segments:

- `jit/<engine>` under `engines/<engine>/app/controllers`
- matching redundant view/helper/test path segments where they only repeat the engine name

Use engine-local Zeitwerk mapping if needed to keep `Jit::<Engine>::...` constants while flattening
paths.

## 8. Root App Retirement Rule

The root app is migration-only.

Rules:

- no new runtime ownership may be added there
- no new domain code may be added there
- every remaining root file must have one destination: move to engine move to wrapper app move to
  `lib/` delete during retirement

End state:

- remove `DEPLOY_MODE`
- remove root runtime routing
- delete the root app once no runtime responsibility remains

## 9. Test Strategy

Before broad refactors:

- add or update contract tests for routes, env selection, and helper naming
- add static checks for cross-engine constant references
- add inventory checks for root-owned runtime files

During migration:

- migrate path-sensitive tests in the same wave as controller/view/helper path changes
- keep engine boot verification separate for each wrapper app

Acceptance posture:

- do not rely on root-app integration as the final proof shape
- wrapper app boot must become the authoritative runtime check

## Related

- `adr/four-app-wrapper-runtime-and-root-retirement.md`
- `plans/active/four-engine-migration-sequence.md`
- `plans/active/wrapper-app-architecture-plan.md`
- `plans/active/root-app-retirement-plan.md`
