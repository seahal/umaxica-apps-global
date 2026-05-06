# Localization Preference Flow

## Status

Accepted on 2026-04-07.

## Context

GitHub issue `#631` tracked completion of the localization preference flow across the sign surfaces.
The target was to confirm region, language, and timezone behavior for `app`, `org`, and `com`, and
to keep the UI copy and regression coverage aligned.

## Decision

The sign preference flow supports region, language, and timezone as first-class preference inputs on
all three sign surfaces: `app`, `org`, and `com`.

The request and cookie contract keeps:

- `ri` for region
- `lx` for language
- `tz` for timezone

The preference UI, redirect behavior, and persisted state use the same contract across all three
surfaces.

## Evidence

- `test/integration/sign_preference_test.rb` runs the same preference assertions for `app`, `org`,
  and `com` through the shared `DOMAINS` matrix.
- The same integration file verifies:
  - `lx` changes locale
  - region updates persist
  - timezone updates persist
  - default language and timezone values initialize cookies and JWT preference payloads
  - localized option labels and localized error handling work across surfaces
- `test/integration/preference_global_param_context_test.rb` verifies `lx` and `tz` propagation
  behavior in navigation and internal links.
- View and controller pairs exist for all sign surfaces:
  - `app/views/sign/app/preference/regions/edit.html.erb`
  - `app/views/sign/app/preference/region/languages/edit.html.erb`
  - `app/views/sign/app/preference/region/timezones/edit.html.erb`
  - matching `org` and `com` counterparts

## Consequences

- Localization behavior is now part of the stable preference contract, not an incomplete follow-up.
- Future work should extend this flow without changing the `ri` / `lx` / `tz` keys casually.

## Related

- Former plan: `plans/backlog/gh631-localization-preference-flow.md`
- Related contract: `adr/theme-preference-cookie-and-param-contract.md`
