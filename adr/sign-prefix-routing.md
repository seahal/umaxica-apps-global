# Sign Prefix Routing on IdP Hosts

**Status:** Accepted (2026-05-05)

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

`config/routes/sign.rb:6` already declares `scope module: :sign, as: :sign do`, but that only sets
the controller module and route helper name prefix; it does not add a path prefix. The live URLs
today are bare `/in/new`, `/up/new`, etc. Helper names like `new_sign_app_in_path` are widely used
across controllers, views, and tests and should keep working.

## Decision

On the IdP hosts, prefix the sign-in and sign-up flows with `/sign/`. The prefix applies only to the
`:in` and `:up` resources and namespaces. All other routes in `config/routes/sign.rb` remain at
their current paths.

- Authentication entry points move: `/in/...` → `/sign/in/...`, `/up/...` → `/sign/up/...`.
- Account, preference, OmniAuth callback, OIDC, health, robots, sitemap, web/v0, edge/v0, and the
  per-host root remain at their current paths and do not gain a `/sign/` prefix.
- Route helper names (`sign_app_in_*`, `sign_com_up_*`, etc.) are unchanged. Only generated URL
  paths change.
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

Keeping the existing `as: :sign` and `module: :sign` declarations preserves the controller layout
under `app/controllers/sign/` and the helper name surface (`sign_app_in_*`, etc.). The only
mechanical change is wrapping the affected resources in `scope path: "sign" do` inside each host
block.

A compatibility redirect from `/in` and `/up` is intentionally not introduced; this is a clean break
on a controlled host, in line with the project's preference for direct migrations over shimming.

## Consequences

- `config/routes/sign.rb` gains three `scope path: "sign" do` wrappers (one in each of the `:app`,
  `:com`, `:org` host blocks) around the `:in` and `:up` declarations.
- Hardcoded `/in/...` and `/up/...` literal paths in tests and a small number of defensive fallback
  strings in `app/controllers/concerns/authentication/base.rb` need updating to the new `/sign/...`
  form.
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
- **Rename the `:sign` route name prefix as part of the move.** Rejected because helper names
  (`sign_app_in_*`, etc.) are heavily referenced across controllers, views, and tests; renaming
  would expand scope without changing observable behavior.
