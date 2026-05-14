# ADR: Actor Current Context

**Status:** Accepted (2026-05-13)

## Context

The app previously had multiple request-context experiments:

- `Current < ActiveSupport::CurrentAttributes` stored actor, token, session, surface/domain,
  preference, and observability state.
- `Jumper`, `Apexer`, and `Signer` are subdomain/surface-flavored `CurrentAttributes` classes.
- Application code read `Current.*` directly in some places.

This creates two problems. First, request-local storage and the application-facing API are coupled.
Second, subdomain-specific current classes make every new surface/tenant/region look like it needs a
new global-ish context class.

The desired direction is one request-local current-context container with one application-facing API.

## Decision

Adopt `Actor` as the only current-context container and application-facing API.

`Actor` is backed by `ActiveSupport::CurrentAttributes`. Controllers, middleware, authentication,
preference resolution, host/context resolvers, policies, services, and views read and write request
context through `Actor`, for example:

```ruby
Actor.user
Actor.account
Actor.surface
Actor.preference.language
```

`Actor` does not branch by subdomain. Host and surface differences are resolved before application
code runs, by a request-start resolver that populates `Actor`.

Preference remains an immutable value object exposed as `Actor::Preference`. Callers should access
the resolved request preference as `Actor.preference`.

## Rejected Direction

The subdomain-specific current classes are removed:

- `Jumper`
- `Apexer`
- `Signer`

Do not restore these classes as compatibility shims. Do not introduce more surface-specific
`CurrentAttributes` classes.

The old global `Current` class is also removed. Do not restore it as a compatibility shim.

`adr/jumper-current-boundary.md` is obsolete. Its provisional `Jumper` direction is no longer current
intent.

## Consequences

- Request-local storage and application API are both centered on `Actor`.
- Future surface, tenant, region, and host growth should extend resolver output and `Actor` fields,
  not create more `CurrentAttributes` classes.
- Existing direct reads of `Current.*` in application code are migrated to `Actor.*`.
- Existing `Jumper` / `Apexer` / `Signer` tests and lifecycle wiring are removed with this
  direction.

## Related

- `adr/jumper-current-boundary.md` — obsolete predecessor.
- `adr/current-context-boundary-by-engine.md` — obsolete engine-era predecessor.
- `adr/preference-soft-bubble-doctrine.md` — preference value-object doctrine; its read-side API is
  superseded from `Current::Preference` / `Current.preference` to `Actor::Preference` /
  `Actor.preference`.
