# Sign :com Excludes Social Login

**Status:** Accepted (2026-05-05)

## Context

The IdP runs three host scopes: `:app` (`id.umaxica.app`, service users), `:com` (`id.umaxica.com`,
corporate customers), and `:org` (`id.umaxica.org`, staff). Social login (Google, Apple) is offered
on `:app` and `:org` but is not in scope for `:com`. The corporate flow uses email + passkey +
telephone + recovery secrets only.

Two specific implementation realities created drift from this intent:

1. `Sign::Com::ApplicationController` (`app/controllers/sign/com/application_controller.rb:47-55`)
   overrides `local_prefixes` so view paths under `sign/com/...` fall back to `sign/app/...` when no
   `:com`-specific template exists. Most `:com` controllers carry no dedicated view files.
2. `app/views/sign/app/ins/new.html.erb` and `app/views/sign/app/configurations/show.html.erb`
   contain Google / Apple UI. Through the fallback, those buttons and links surfaced on the `:com`
   host as well.
3. The OmniAuth Rack middleware in `config/initializers/omniauth.rb` is host-agnostic.
   `POST /auth/google_app` works on any host, including `:com`, regardless of routing — so even if
   the UI is hidden, a direct request would still start the Google flow.

The corporate flow on `:com` has independent product expectations (no per-end-user social identity
binding for corporate customers) and uses separate routes (`config/routes/sign.rb` `:com` block,
lines 172–288, defines no `:social`, `:auth`, `:configuration/google`, or `:configuration/apple`
resources). Social login surfacing on `:com` was unintended.

## Decision

`:com` does not offer or accept social login. Enforce this on two layers:

1. **UI layer**: provide `:com`-specific view files that omit social UI for the templates that
   currently fall through to `:app` and contain Google / Apple references — primarily
   `sign/com/ins/new.html.erb` and `sign/com/configurations/show.html.erb`. The `local_prefixes`
   fallback remains in place for templates that do not involve social login.

2. **Server layer**: a Rack middleware inserted before `OmniAuth::Builder` returns 404 for any
   request to `/auth/...` whose host matches `ENV["ID_CORPORATE_URL"]`. This is independent of
   routing and view rendering — direct POSTs to OmniAuth strategy paths cannot bypass the UI
   omission on `:com`.

`:app` and `:org` continue to use the existing `:social`, `:auth`, and configuration social routes.
The `google_app`, `google_org`, and `apple` OmniAuth strategies stay registered as they are (no
`google_com` strategy exists or will be added).

## Rationale

Two layers are needed because the two leak paths are independent. View overrides remove the visible
affordance and prevent accidental clicks, but OmniAuth's Rack-level interception means a crafted
POST would otherwise still work. A Rack guard prevents that without changing routing or strategy
registration.

Per-`:com` view overrides were chosen over conditional branches in `:app` templates because they
keep social-aware logic out of the `:app` views — `:app` should not need to know about `:com`. The
override surface is small (two confirmed templates plus a possible third for `in/emails/new`), so
duplication cost is low and the boundary is explicit.

The `local_prefixes` fallback was kept rather than removed because it covers many other non-social
templates (preferences, verification setup, configuration sub-pages) where `:com` and `:app`
legitimately share rendering. Removing the fallback would require creating dozens of
otherwise-identical `:com` files for no product benefit. Targeted overrides only where social
content exists is the smallest correct change.

The Rack guard returns 404 rather than redirecting to a failure page or 302'ing because there is no
`:com` social flow to redirect to. A 404 makes the absence explicit in logs and matches the "these
endpoints do not exist on `:com`" mental model.

The check uses host equality with `ENV["ID_CORPORATE_URL"]` (hostname-only in this codebase) so the
guard is configurable per environment without code changes and stays aligned with how `IdHostEnv`
and existing host constraints are written.

## Consequences

- New view files appear under `app/views/sign/com/` only for the social-bearing templates. Other
  `:com` rendering continues to fall through to `:app` via `local_prefixes`.
- `config/initializers/omniauth.rb` (or a sibling initializer) gains a `OmniAuthCorporateGuard`
  middleware inserted before `OmniAuth::Builder`.
- `POST /auth/google_app`, `POST /auth/google_org`, and `POST /auth/apple` return 404 on the
  corporate host. Documentation and ops dashboards that cover these endpoints should reflect the
  per-host availability.
- Tests pin both the UI absence on `:com` and the server-side rejection of `/auth/...` on `:com`;
  the absence becomes load-bearing rather than incidental.
- New `sign.com.*` i18n keys may be added for the override views. No new `sign.com.*social*` /
  `*google*` / `*apple*` keys are introduced — their absence is the signal that social is not
  offered.
- Future contributors adding new social-bearing UI to `:app` views must add a matching `:com`
  override (or move the social UI into a partial that is rendered only on social-enabled scopes).

## Alternatives Considered

- **Conditional rendering inside the `:app` templates** (e.g., a `social_login_available?` helper
  that returns false for `:com`). Rejected: pulls `:com` knowledge into `:app` views and spreads the
  boundary across the codebase. The override-file approach keeps each scope's templates
  self-contained.
- **Remove the `local_prefixes` `:com → :app` fallback**. Rejected: would force creating many
  `:com`-specific copies of templates that have no scope-specific differences (preferences,
  verification, etc.), expanding scope without product benefit.
- **Rely on UI hiding only**. Rejected: OmniAuth's Rack-level interception means the social flow
  remains reachable on `:com` via direct POST. Server-side enforcement is required to make the
  boundary real, not cosmetic.
- **Register a `google_com` strategy that fails immediately**. Rejected: introduces a strategy that
  exists only to fail, which is harder to reason about than not exposing the endpoint at all.
  Rack-level 404 is cleaner.
- **Remove the OmniAuth strategies entirely on `:com`**. Not applicable: OmniAuth strategies are
  registered process-wide via `Rails.application.config.middleware`, not per host. The Rack guard is
  the per-host equivalent.
