# Current Context Architecture

## Purpose

This document records the current request-context model for this Rails application.

The application-facing current context API is `Actor`. Do not introduce or restore `Current`,
`Jumper`, `Apexer`, `Signer`, or other surface-specific current containers.

## Status

Current as of 2026-05-17.

The accepted decision is `adr/actor-current-facade.md`.

## Runtime Contract

`Actor` is the only request-local current-context container and the only application-facing API for
request context.

The request-local storage slot holds an immutable `Actor::Context` snapshot implemented with Ruby
`Data.define`. Updating actor state replaces the snapshot. It does not mutate independent current
attributes in place.

`Actor` is a resolved request-context snapshot, not a cache source. Lifecycle code must rebuild the
snapshot from the current authentication, preference, and controller state instead of preferring
previous `Actor.authentication` or preference association values. This favors correctness over
avoiding repeated reads.

Application code reads request context through `Actor`, for example:

- `Actor.actor`
- `Actor.actor_type`
- `Actor.whoami`
- `Actor.client`
- `Actor.operator`
- `Actor.visitor`
- `Actor.tld`
- `Actor.preference`
- `Actor.authentication`
- `Actor.configuration`
- `Actor.signed_in?`
- `Actor.signed_up?`

Do not add direct application reads of older current-context APIs.

Removed current-context readers:

- `Actor.surface` and `Actor.domain` duplicated the surface label and are removed. Use `Actor.tld`.
- `Actor.session` is removed. Use `Actor.authentication.login_public_id`.
- `Actor.token` is removed. Use typed `Actor.authentication` readers. Code that still needs raw
  claims at a low-level auth or policy boundary may use `Actor.authentication.access_claims`.
  Lifecycle code must not use an existing `Actor.authentication.access_claims` value as a cache when
  rebuilding context.

## Request Lifecycle

Controllers that need request context include `ActorSupport`.

`ActorSupport` provides lifecycle methods only. Including it must not register controller callbacks.
Controllers opt in explicitly with `before_action` / `after_action`.

`ActorSupport#set_current_context` resolves request context that is safe before authentication, such
as host/surface context and the unauthenticated actor fallback.

`ActorSupport#set_current_actor` resolves the authenticated actor, authentication state, and
preference after authentication has had a chance to load or refresh the request resource. The legacy
`set_current` method remains a compatibility alias for `set_current_actor`.

`ActorSupport#with_actor_lifecycle` clears `Actor` in an `ensure` block for controller bases that
use an around-action lifecycle. `Finisher#purge_current` remains a compatibility cleanup method for
older after-action wiring.

Use `Actor.clear` for application code that explicitly empties the current request context.
`Actor.reset` remains the Rails `ActiveSupport::CurrentAttributes` lifecycle method and has the same
clearing effect, but application code should prefer the domain-facing `clear` name.

The resolved context includes:

- authenticated actor or `Unauthenticated.instance`
- actor type (`:client`, `:operator`, `:visitor`, or `:unauthenticated`)
- `Actor.tld` from `HostContextResolver`
- `Actor.authentication.login_public_id`
- typed authentication state derived from access-token claims
- resolved `Actor::Preference`
- observability identifiers when performant consent allows them

## Surface Actors

The three user-facing surfaces use these runtime actor names:

| Surface | Actor type  | Helper           |
| ------- | ----------- | ---------------- |
| `app`   | `:client`   | `Actor.client`   |
| `org`   | `:operator` | `Actor.operator` |
| `com`   | `:visitor`  | `Actor.visitor`  |

`Actor.whoami` returns the current actor type. `Actor.tld` returns the current surface label:
`:app`, `:com`, `:org`, `:net`, or `:dev`.

Storage names may still contain compatibility prefixes such as `user_*` or `staff_*`. Those storage
names do not change the runtime current-context API.

## Preference

Preference is exposed as an immutable value object through `Actor.preference`.

Request code should not read preference state from controller instance variables, raw JWT claims, or
legacy current-context APIs when `Actor.preference` is available.

`Actor::Preference` contains the resolved runtime preference used by the app/org/com preference
flows. In normal authenticated requests it is initialized from the verified access-token `prf`
claim, then valid request-local `lx`, `ct`, and `tz` values are overlaid when explicitly present.
That overlay affects only the current request and must not be copied back to the database or JWT.

Logged-in HTML preference edit screens may first refresh the current surface preference token from
the actor-local preference DB so another browser's preference change is visible before the edit
screen renders. This refresh is a bounded preference-screen entry flow and must run before
`Actor.preference` is initialized.

- localization: `language`, `region`, `timezone`
- presentation: `theme`, `motion`, `density`, `items_per_page`
- format defaults: `currency`, `date_format`, `time_format`
- consent cookie state through `Actor.preference.cookie`

Authenticated request setup must not repair a missing or malformed preference access-token by
reading the preference database. Treat that as a token failure and route it through the normal
failure path. `Actor::Preference::NULL` is reserved for unauthenticated, bearer-only, or explicitly
preference-free paths that are designed to run without a preference token.

## Authentication

Authentication state is exposed as an immutable value object through `Actor.authentication`.

Use `Actor.authentication.login_public_id` for the current login/session identifier. This is the
same kind of identifier used to mark the current row on `/configuration/sessions`, but it
intentionally does not use the bare name `session` because Rails session state is a different
concept.

Do not treat raw access-token payloads as the normal application contract. Prefer typed readers on
`Actor.authentication`, such as:

- `login_public_id`
- `acr`
- `amr`
- `restricted?`
- `verified?`

`Actor.authentication.access_claims` may exist as a low-level migration or policy escape hatch, but
new controller and service code should ask for typed authentication state instead of reading token
claim hashes directly.

## Authorization

Action Policy uses `user` as the authorization subject name. In this codebase that name is an
authorization-library interface, not a `User` model or application-facing current-context API.

Do not rename the Action Policy subject to `actor`: `Actor` is already the request-local current
context facade. Controllers should continue wiring Action Policy with
`authorize :user, through: :current_client`, `:current_operator`, or `:current_visitor` as
appropriate for the surface. Policies may read token claims through
`Actor.authentication.access_claims` when a low-level authorization decision still needs raw claims.

`Actor.signed_in?` is the request-level predicate for an authenticated actor. It is true when the
current actor type is `:client`, `:operator`, or `:visitor`.

`Actor.signed_up?` is true only when the current request has an authenticated actor with a persisted
identity. Anonymous users and unsaved actor objects return false.

## Configuration

Configuration state is exposed through `Actor.configuration`.

When no configuration is available, `Actor.configuration` returns a null object. Unknown readers
return a null value that is safe to chain and answers false to predicate-style feature checks such
as `enabled?` and `configured?`. This keeps guest and anonymous request paths from raising nil
errors when a view or service asks for optional configuration.

## Open/Bare Endpoints

Bare infrastructure endpoints should avoid the full `Actor` lifecycle.

Use `BareController` for pure infrastructure endpoints such as health, robots, and sitemap responses
when they do not need authentication, preference, verification, or `Actor` state.

Use `OpenController` when an endpoint is reachable without authentication but still needs to inspect
session, preference, authentication, or actor state when present. Documented temporary exceptions
may remain on compatibility parents until they have a named derivative of one of the four controller
boundaries.

## Rules

- Use `Actor` as the only application-facing current-context API.
- Extend `Actor` deliberately when new request context is needed.
- Keep request context request-local and clear it after the response.
- Do not use `Actor` values as memoized inputs while rebuilding `Actor`; resolve from current
  request/auth/preference state.
- Prefer typed helpers and value objects over raw token hashes where practical.
- Keep Action Policy's authorization subject name as `user`; it is not a `User` model reference.
- Do not restore old or surface-specific current containers.

## Related

- `adr/actor-current-facade.md`
- `adr/static-and-guest-controller-boundaries.md`
- `docs/architecture/actor-naming.md`
- `docs/architecture/controller-boundaries.md`
