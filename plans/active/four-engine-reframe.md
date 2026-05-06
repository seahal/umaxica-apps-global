# Four-App Engine Reframe Plan

## Status

Active (2026-04-18)

## Summary

The target architecture is four near-independent Rails apps in one repository:

- `Identity`
- `Zenith`
- `Foundation`
- `Distributor`

Ownership is fixed as follows:

- `engine = domain code`
- `wrapper app = runtime boot`
- `lib = shared engine-neutral code only`

The current root app is migration-only and will be fully removed.

## Target Topology

| Engine          | Role                     | Wrapper app        |
| --------------- | ------------------------ | ------------------ |
| **Identity**    | Authentication / IDP     | `apps/identity`    |
| **Zenith**      | Shared shell / summary   | `apps/zenith`      |
| **Foundation**  | Business operations      | `apps/foundation`  |
| **Distributor** | API and content delivery | `apps/distributor` |

## Zenith Surface Contract

Zenith keeps the engine name and mount alias:

- engine name: `Jit::Zenith`
- mount alias: `:zenith`

Zenith changes the surface name:

- `acme` -> `acme`

This affects:

- route helper prefixes: `acme_*`
- controller and view paths: `.../acme/...`
- env names: `ZENITH_ACME_*`
- i18n scopes: `acme.*`
- OIDC identifiers that previously used `acme`

No compatibility alias is retained for `acme`.

## Runtime Model

Each wrapper app owns:

- `config/application.rb`
- `config/environment.rb`
- `config/routes.rb`
- `config/importmap.rb`
- `config/initializers/*`
- runtime middleware and session boot
- runtime asset registration

Each engine owns:

- models
- DB-facing logic
- services
- engine-specific concerns
- helpers
- views
- assets
- locale files
- engine tests

The root app owns no long-term domain runtime behavior.

## Code Placement Rule

Put code in `lib/` only if it is:

- engine-neutral
- persistence-neutral
- route-neutral
- runtime-neutral or shared boot support

Do not keep domain services, domain concerns, domain helpers, or domain models in the root app.

## Controller Path Rule

Flatten redundant engine nesting inside engine paths.

Preferred shape:

- from `engines/foundation/app/controllers/jit/foundation/base/org/contacts_controller.rb`
- to `engines/foundation/app/controllers/base/org/contacts_controller.rb`

Keep only path segments that carry routing meaning, such as:

- `sign`, `acme`, `base`, `post`
- `app`, `org`, `com`, `dev`, `net`
- `web/v0`, `edge/v0`

## Guardrails

- Do not add new domain code to the root app.
- Do not keep root-owned layouts, importmap pins, or domain initializers in the end state.
- Do not keep both old and new controller path layouts alive long-term.
- Do not treat archive plans as current execution input.
- Do not use `behavior` as a target Foundation database or model family name.

## Related

- `adr/four-app-wrapper-runtime-and-root-retirement.md`
- `plans/active/four-engine-enforcement-decisions.md`
- `plans/active/four-engine-migration-sequence.md`
- `plans/active/controller-path-flattening-plan.md`
