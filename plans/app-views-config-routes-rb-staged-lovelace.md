# Align Rails Routes, Controllers, And View Namespaces

## Context

The route/controller/view layout has two separate concerns:

- Bare or API-only surfaces such as `base`, `core`, `docs`, `help`, `news`, `palm`, and bare `acme`
  namespaces may legitimately render `plain`, `json`, `head`, XML builders, or shared templates
  instead of conventional ERB templates.
- Sign ceremony routes currently use canonical `/sign/...` route modules and helpers, but some
  controller logic and views still live under legacy `sign/<surface>/{up,in}` namespaces and are
  bridged by inheritance and `local_prefixes` shims.

The first concern is repository visibility. The second concern is behavioral and must be handled as
a staged controller/view migration.

## Decision

Keep the current route shape and helper names. Do not change `config/routes/sign.rb` as part of this
work.

For bare/API-only surfaces, keep visible `app/views/<namespace>/<surface>/` directories with empty
`.keep` files. These directories do not imply Rails owns conventional HTML templates for those
endpoints; they only make the surface namespace visible in the repository.

For Sign ceremony routes, align controllers and views to the canonical route-resolved namespaces:

- `Sign::<Surface>::Sign::Up::*`
- `Sign::<Surface>::Sign::In::*`
- `app/views/sign/<surface>/sign/up/**`
- `app/views/sign/<surface>/sign/in/**`

After the migration, route modules, controller classes, and view paths should agree, and
`local_prefixes` shims should no longer be needed.

## Completed Repository-Visibility Work

The bare surface view namespaces should be represented with `.keep` files where no templates exist:

- `app/views/acme/dev/.keep`
- `app/views/acme/net/.keep`
- `app/views/core/app/.keep`
- `app/views/core/com/.keep`
- `app/views/core/dev/.keep`
- `app/views/core/net/.keep`
- `app/views/core/org/.keep`
- `app/views/docs/app/.keep`
- `app/views/docs/com/.keep`
- `app/views/docs/org/.keep`
- `app/views/help/app/.keep`
- `app/views/help/com/.keep`
- `app/views/help/org/.keep`
- `app/views/news/app/.keep`
- `app/views/news/com/.keep`
- `app/views/news/org/.keep`

Do not add per-action placeholder directories such as `api/v0/entries/` or `health/livenesses/`.
Those would imply conventional templates are expected for endpoints that deliberately render
non-template responses.

## Sign Migration Plan

Implement Sign one surface at a time in this order: `app`, `com`, then `org`.

For each surface:

1. Move legacy controller logic from `app/controllers/sign/<surface>/{up,in}/**` into the matching
   canonical `app/controllers/sign/<surface>/sign/{up,in}/**` path.
2. Preserve behavior-specific declarations from the current route-resolved canonical subclasses,
   including `AUTHENTICATION_MODE` and `declare_authentication_mode!` overrides.
3. Remove `local_prefixes` overrides once the matching views live under the canonical namespace.
4. Move legacy views from `app/views/sign/<surface>/{up,in}/**` into
   `app/views/sign/<surface>/sign/{up,in}/**`.
5. Update explicit render paths and template references from legacy paths such as `sign/app/up/...`
   to canonical paths such as `sign/app/sign/up/...`.
6. Update tests and inventory files that directly reference legacy controller constants, controller
   file paths, or view paths.

Special cases:

- Keep `app/views/sign/<surface>/sign_ins`, `sign_ups`, and `sign_outs` out of scope; those are
  existing shared entrance views, not the legacy `sign/<surface>/{up,in}` ceremony trees.
- Treat `Sign::Org::Sign::Up::InvitationsController` as part of the canonical org migration because
  the route-resolved namespace is `sign/org/sign/up`.
- Before deleting any orphaned legacy controller, verify whether it is still used through explicit
  render calls, inheritance, includes, or tests. Move live code; propose deletion separately for
  confirmed dead code.

## ADR Update

After the Sign migration is complete, amend `adr/sign-prefix-routing.md` in English:

- Record that the implementation uses `namespace :sign`, not only `scope path: "sign"`.
- Record that URL paths, helper names, controller namespaces, and view namespaces now intentionally
  align around `sign_<surface>_sign_*` helpers and `sign/<surface>/sign/{up,in}` controller/view
  paths.
- Remove or correct stale wording that says helper names remain `sign_<surface>_in_*`.
- Keep the ADR status accepted and add an amendment date.

## Verification

Run focused checks after each surface migration:

- `rg -n "local_prefixes" app/controllers/sign`
- `rg -n "sign/(app|com|org)/(up|in)/|Sign::(App|Com|Org)::(Up|In)::" app/controllers app/views test`
- `bin/rails test test/controllers/sign`
- `bin/rails test test/controllers/controller_inheritance_invariant_test.rb`
- `bin/rails test test/integration/layouts_stylesheet_test.rb`

After all surfaces are migrated, run the broader Rails test suite if the working tree and database
state permit it.

## Non-Goals

- Do not change `config/routes/sign.rb`.
- Do not change public URLs or route helper names.
- Do not add Rails flash, skipped authentication, skipped authorization, or new workflow bypasses.
- Do not change database schema or migration files for this work.
