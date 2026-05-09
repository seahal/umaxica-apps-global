# Four-App Engine Migration Sequence

## Status

Active draft (2026-04-18)

## Summary

Migrate from the current extracted-engine plus root-app model to the canonical four-app model:

- `Identity`
- `Zenith`
- `Foundation`
- `Distributor`

End-state rules:

- one wrapper app per engine
- engine owns domain code
- wrapper app owns runtime boot
- root app is fully removed
- shared code is limited to `lib/`
- Zenith surface is `acme`

## Legacy-To-Canonical Mapping

| Legacy physical name | Canonical engine |
| -------------------- | ---------------- |
| `signature`          | `Identity`       |
| `world`              | `Zenith`         |
| `station`            | `Foundation`     |
| `press`              | `Distributor`    |

## Naming Rule

Physical repository paths match canonical engine names.

- `engines/identity`
- `engines/zenith`
- `engines/foundation`
- `engines/distributor`

Runtime boot paths match wrapper apps:

- `apps/identity`
- `apps/zenith`
- `apps/foundation`
- `apps/distributor`

Zenith surface naming:

- `acme` is canonical
- `acme` is removed, not retained as a compatibility alias

## Migration Order

### Phase 1. Freeze the target

- record the four-app target in ADR and active plans
- freeze `engine = domain code`
- freeze `wrapper app = runtime boot`
- freeze root app retirement
- freeze `lib` as the only long-term shared code location
- freeze `acme` as the Zenith surface name
- freeze controller path flattening as active work

### Phase 2. Inventory current ownership

Classify every root-owned runtime and domain file into one destination:

- move to engine
- move to wrapper app
- move to `lib/`
- delete during root app retirement

Mandatory inventory groups:

- root `config/application.rb`
- root `config/initializers/*`
- root `config/importmap.rb`
- root `app/views/layouts/*`
- root `app/models/*`
- root `app/services/*`
- root `app/controllers/concerns/*`
- root `app/helpers/*`

### Phase 3. Create wrapper app skeletons

Add:

- `apps/identity`
- `apps/zenith`
- `apps/foundation`
- `apps/distributor`

Each wrapper app must define:

- `config/application.rb`
- `config/environment.rb`
- `config/routes.rb`
- `config/importmap.rb`
- `config/initializers/*`
- one-engine mount rule
- engine-specific boot config

### Phase 4. Flatten engine internal paths

For each engine:

- flatten redundant controller path nesting
- update Zeitwerk path mapping if needed
- move matching views, helpers, and path-sensitive tests
- remove the old nested path layout completely

Keep only meaningful segments such as:

- `sign`, `acme`, `base`, `post`
- `app`, `org`, `com`, `dev`, `net`
- `web/v0`, `edge/v0`

### Phase 5. Move runtime boot out of the root app

Move into wrapper apps:

- root `config/application.rb` responsibilities
- root runtime initializers
- root importmap pins
- root domain layouts
- root session and middleware boot that is not truly global

Keep in `lib/` only the boot helpers that are truly shared and engine-neutral.

### Phase 6. Move domain code into engines

Move into the owning engine:

- models
- DB base records
- persistence-aware services
- engine-specific concerns
- engine-specific helpers
- engine-specific assets and locale files

Database ownership:

- `Identity`: `principal`, `operator`, `token`, `preference`, `guest`, `activity`, `occurrence`
- `Zenith`: `journal`, `notification`, `avatar`
- `Foundation`: `chronicle`, `message`, `search`, `billing`, `commerce`
- `Distributor`: `publication`

Foundation uses `chronicle`, not `behavior`.

### Phase 7. Migrate engine by engine

Recommended order:

1. `Identity`
2. `Zenith`
3. `Foundation`
4. `Distributor`

Rationale:

- `Identity` sets the wrapper-app boot pattern under the strictest auth/runtime conditions
- `Zenith` follows while applying `acme`
- `Foundation` and `Distributor` follow after runtime and path rules are stable

### Phase 8. Remove obsolete contracts

- remove root-owned domain code
- remove root runtime routing
- remove `DEPLOY_MODE`
- remove old env names
- remove old `acme` helpers, ids, scopes, and paths
- remove old controller path layout
- archive superseded plans

## Acceptance Gates

- every engine boots through its wrapper app
- no active runtime dependency remains on the root app
- no long-term centralized root `app/models`
- no long-term root-owned importmap or domain layouts
- no active Zenith contract still uses `acme`
- no active Foundation naming plan still proposes `behavior`
- controller path flattening is complete for migrated engines
- root app can be deleted without breaking runtime boot

## Critical Guardrails

1. Treat `main_app.*` as a Rails route proxy, not as a rename target.
2. Do not keep the root app as a permanent compatibility shell.
3. Do not keep both old and new controller path layouts alive after one wave completes.
4. Do not introduce new shared domain code outside `lib/`.
5. Use implementation code and tests as the primary source when runtime and stable docs differ.

## Related

- `adr/four-app-wrapper-runtime-and-root-retirement.md`
- `plans/active/four-engine-reframe.md`
- `plans/active/wrapper-app-architecture-plan.md`
- `plans/active/controller-path-flattening-plan.md`
