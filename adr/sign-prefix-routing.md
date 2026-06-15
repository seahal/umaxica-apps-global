# Sign Prefix Routing on IdP Hosts

**Status:** Accepted (2026-05-05; amended 2026-06-15)

> **Partial supersession (2026-06-02):** The `sign/id` routing vocabulary in this ADR is refined by
> `adr/sign-credential-gateway-surface.md`. `sign/id` routes are Credential Gateway / ceremony
> routes, not IdP application-session routes. Routing details in this ADR must not be used to add
> `sign/id` sessions, preference writes, dashboards, account lifecycle, authorization decisions, or
> downstream token issuance.

## Context

The IdP runs on dedicated hosts: `id.umaxica.{app,com,org}` in production and
`id.{app,com,org}.localhost` in development. Host selection is enforced by `IdHostEnv`
(`lib/id_host_env.rb`) and the host constraints in `config/routes/sign.rb`.

Historically the implementation used `sign.<tld>/in` and `sign.<tld>/up` host names. The current
direction is `id.<tld>/sign/in` and `id.<tld>/sign/up` — auth flow paths sit under a `/sign/` URL
prefix on the IdP host instead of being part of the host name.

`config/routes/sign.rb` declares the credential-gateway flows under `namespace :sign`. Rails
`namespace` applies the same segment to URL paths, controller modules, and helper prefixes. The
canonical ceremony shape is therefore:

- URL paths: `/sign/in/...` and `/sign/up/...`
- controllers: `Sign::<Surface>::Sign::In::*` and `Sign::<Surface>::Sign::Up::*`
- route helpers: `sign_<surface>_sign_in_*` and `sign_<surface>_sign_up_*`
- views: `app/views/sign/<surface>/sign/in/**` and `app/views/sign/<surface>/sign/up/**`

## Decision

On the IdP hosts, prefix the sign-in and sign-up flows with `/sign/`. The prefix applies only to the
`:in` and `:up` resources and namespaces inside the Sign ceremony. All other routes in
`config/routes/sign.rb` remain at their current paths.

- Authentication entry points move: `/in/...` → `/sign/in/...`, `/up/...` → `/sign/up/...`.
- Account, preference, OmniAuth callback, OIDC, health, robots, sitemap, web/v0, edge/v0, and the
  per-host root remain at their current paths and do not gain a `/sign/` prefix.
- Route helper names include the explicit Sign ceremony segment (`sign_app_sign_in_*`,
  `sign_com_sign_up_*`, etc.). These helper names are the canonical helper surface for ceremony
  routes.
- Controller and view namespaces align with those helpers under `sign/<surface>/sign/{in,up}`.
- No backward-compatible redirect from old `/in` and `/up`. Old paths return 404.

## Rationale

Putting auth flows under a single visible URL segment makes it explicit at the URL level that the
user is in an authentication step. It also separates auth entry points from account configuration
and infrastructure endpoints on the same host, which makes log filtering, CSP source rules, and
operational dashboards easier to scope.

Limiting the prefix to `:in` and `:up` matches the user-facing meaning of "sign". `/setting`,
`/preference`, `/configurator`, OIDC endpoints, OmniAuth callbacks, and infra paths are not part of
the sign-in or sign-up step in the same sense and have established external contracts (especially
the OmniAuth callback URL). Keeping them at their current paths avoids forcing provider-side
reconfiguration and avoids touching every reference to those routes.

Using `namespace :sign` for the affected ceremonies keeps URL paths, controller modules, helper
names, and views in one visible structure. Earlier implementations carried compatibility inheritance
and `local_prefixes` view-lookup shims between `Sign::<Surface>::In/Up` and
`Sign::<Surface>::Sign::In/Up`; those shims are not the target shape.

A compatibility redirect from `/in` and `/up` is intentionally not introduced; this is a clean break
on a controlled host, in line with the project's preference for direct migrations over shimming.

## Consequences

- `config/routes/sign.rb` keeps explicit `namespace :sign` blocks around the `:in` and `:up`
  declarations for app, com, and org.
- Hardcoded `/in/...` and `/up/...` literal paths in tests and defensive fallback strings should use
  the `/sign/...` form.
- Controller and view files for ceremony routes live under `sign/<surface>/sign/{in,up}`.
- `config/environments/production.rb` host authorization exclude lists `/up`, which is intended for
  the Rails default health probe; it should be reviewed during implementation but is expected to
  remain as-is because new sign-up paths start with `/sign/up`, not `/up`.
- Bookmarks, external links, or documentation that assumed `/in` or `/up` will break. Internal
  callers use route helpers and migrate automatically.
- OmniAuth provider configurations (Google, Apple) do not need to change because
  `/auth/:provider/callback` is out of scope.

## Alternatives Considered

- **Move the entire sign module under `/sign/`** by adding `path: "sign"` to the outer
  `scope module: :sign, as: :sign` declaration. Rejected because it would also relocate `/setting`,
  `/preference`, `/configurator`, OIDC endpoints, OmniAuth callbacks, health/robots/sitemap, and
  web/v0/edge/v0 — forcing OAuth provider redirect URI changes and breaking infra probe paths
  without clear benefit.
- **Move only `/in` and keep `/up` bare** (or vice versa). Rejected for asymmetry; sign-in and
  sign-up are paired flows and their URLs should be parallel.
- **Add a compatibility redirect from `/in` and `/up` to `/sign/in` and `/sign/up`.** Rejected
  because the project prefers clean breaks for controlled hosts and the surface area is small.
- **Use `scope path: "sign"` instead of `namespace :sign`.** Rejected for the current implementation
  because helper names and route-resolved controller modules already use the explicit
  `sign_<surface>_sign_*` / `Sign::<Surface>::Sign::*` shape. Preserving that shape and aligning
  views to it is less ambiguous than maintaining compatibility inheritance and view lookup shims.
