# Ongoing Rails Engine Migration State (2026-04-20)

> **Status update (2026-04-26):** Obsolete. Beyond the existing abandonment noted below, per
> `adr/split-into-regional-and-global-repos.md` (2026-04-25) the Rails Engine and 4-app strategies
> are both permanently retired. The codebase is now divided into two independent repositories: this
> **global** repository (a single ordinary Rails app combining IdP and RP, served on `id.*` and
> `www.*`) and a separate **regional** repository (docs / news / help). Do not resume the migration
> steps described below.

## Status

Abandoned (2026-04-22). Direction changed by `adr/rails-way-engine-architecture-restoration.md`.

> **Abandonment notice (2026-04-22):** The wrapper apps migration described below is no longer the
> project direction. The repository returns to the Rails Way (single host Rails app + four mountable
> Fat Engines + native engine routing proxies). Do not resume the steps in this document. A fresh
> implementation plan will be authored separately. This file is retained for historical traceability
> only.

## Context

(Historical) Root application to four separate Rails applications (`Identity`, `Zenith`,
`Foundation`, `Distributor`). This direction was abandoned on 2026-04-22.

## work completed

- **Wrapper app (`apps/`)**:
  - Skeleton creation of `identity`, `zenith`, `foundation`, `distributor`.
  - Add root `lib/` to `LOAD_PATH` in `config/boot.rb` of each app.
  - `lib/` in each app's `config/application.rb` and `app/errors`, `app/controllers` in the root Set
    as autoload target (for transition period).
  - Mount all engines with `routes.rb` in each app (for compatibility).
- **Engine flattening**:
  - Removed redundant nesting of `jit/<engine_name>/` such as `engines/*/app/controllers/`.
  - Fixed `Zeitwerk` mapping in `engine.rb` to maintain `Jit::<Engine>` namespace.
  - Adjust view path priority with `prepend_view_path`.
- **Code move**:
  - `app/models`, `app/services`, `app/helpers`, `app/controllers/concerns`, `app/jobs`,
    `app/mailers`, `app/policies`, `app/subscribers`, `app/validators`, `app/assets`, Move files in
    `app/javascript`, `app/config` to each engine or `lib/`.
  - Move the corresponding test files and fixtures in `test/` to each engine or `lib/`.
  - Move shared base classes (`ApplicationRecord`, `Current`, `ApplicationController`, etc.) to
    `lib/`.
- **Configuration fix**:
  - Corrected `migrations_paths` of `database.yml` to point to root `db/`.
  - Batch replacement of `Rails.root.join("lib/...")` in the migration file with `File.expand_path`.
  - Removed `Jit::Deployment` and `DEPLOY_MODE` related code and tests.

## Current issues and unfinished tasks

- **Identity test failure**:
  - `UrlGenerationError`: Some root helpers are not correctly referencing flattened controllers in
    integration tests.
  - `ActiveRecord::RecordInvalid`: `settings_preferences` fixtures do not comply with the latest
    database constraints (deprecation of polymorphic owners).
- **Maintaining remaining wrapper apps**:
  - For `zenith`, `foundation`, `distributor`, `db:prepare` The operation of individual tests has
    not been confirmed.
- **Cleanup**:
  - Organize `bin/`, `Rakefile`, `Procfile.dev`, etc. that remain on the route.

## Steps to take when restarting

1. Resolve remaining `UrlGenerationError` in `apps/identity` (`engines/identity/config/routes.rb`
   (Check the consistency of the namespace specification and the actual controller path).
2. Modify the fixtures in `engines/identity/test/fixtures/` to match the latest schema.
3. Run `db:prepare` on the other three apps one after another and confirm that the test passes.
4. Once testing is stable for all apps, completely delete unnecessary directories in root.
