# Controller Boundary Lifecycle Unification

## Status

Active.

## Context

The accepted controller boundary model is:

- `OpenController`
- `BareController`
- `PrivateController`
- `GuestController`

The stable lifecycle target is documented in `docs/architecture/controller-lifecycle.md`.

This plan supersedes these older or narrower plans where they overlap:

- `plans/backlog/controller-boundary-exception-retirement.md`
- `plans/backlog/static-guest-controller-flag-retirement.md`
- controller-lifecycle parts of `plans/active/actor-current-context-api-cleanup.md`

`plans/active/actor-current-context-api-cleanup.md` remains relevant for the lower-level Actor API
cleanup until all migration-only direct readers are removed.

## Goals

- Make controller inheritance express the request access contract.
- Keep `ApplicationController` as Rails compatibility, not as the semantic target.
- Move Open/Private lifecycle code toward:
  1. rate limit and request self-defense;
  2. side-effect-free Actor context seed;
  3. preference/authentication/session resolution;
  4. completed Actor snapshot;
  5. side-effect reflection from Actor values;
  6. action execution;
  7. guaranteed Actor cleanup.
- Move new runtime preference reads to `Actor.preference`.
- Keep preference writes inside preference concerns and surface-specific models.
- Replace endpoint-local `public_strict!`, `auth_required!`, and repeated `guest_only!` declarations
  with boundary bases or named derivatives.

## Current Gaps

- `Preference::Localization` no longer registers `apply_localization_preferences` through
  `included do`; each controller base must place the callback explicitly. Some bases still need
  callback-order cleanup so locale/timezone reflection runs from completed Actor state.
- Preference concerns no longer own request callback registration; controller bases and endpoint
  controllers must place preference callbacks and callback skips explicitly.
- `set_color_theme` runs before `set_current_actor` in several controller bases, so theme reflection
  does not yet use the completed `Actor.preference` snapshot.
- `set_preferences_cookie` intentionally performs preference-token and cookie side effects. Those
  effects must stay out of `set_current_context`.
- Some exception controllers still mix open/private or protocol-specific guard behavior.
- Some compatibility constants and flags remain while migration is incomplete.

## Preference Clarifications

"Shared preference" means `AppPreference`, `OrgPreference`, or `ComPreference`: login-independent
surface preference state.

"Actor-local preference" means `UserPreference`, `OperatorPreference`, or `VisitorPreference`:
account-local preference state for the runtime actor.

This distinction is not Rails `session`, and it is not the `Actor` CurrentAttributes object.

From Rails request code, prefer this trust order:

1. DB-backed preference state resolved by controller/concern boundaries.
2. The immutable `Actor.preference` snapshot.
3. JWT `prf` claims as transport/fallback.
4. Cookies as request input or compatibility fallback.

The language cookie key remains `language` for Hono framework compatibility. Do not rename it to
`lx` without a separate compatibility plan.

## Work Items

- Add guaranteed Actor cleanup through an `around_action` helper and migrate controller bases to it.
- Verify explicit localization callbacks are in the correct location for each controller base.
- Verify explicit preference callbacks and endpoint skips are in the correct location for each
  controller base.
- Move theme reflection after `set_current_actor` and prefer `Actor.preference.theme` where safe.
- Keep `set_preferences_cookie` before `set_current_actor` while it still resolves preference token
  state, but prevent it from becoming Actor context initialization.
- Introduce named derivative bases for exception families:
  - social auth open entry and private unlink;
  - session-limit gate;
  - OAuth/OIDC callbacks;
  - OAuth token exchange;
  - edge token, DBSC, and preference endpoints.
- Update tests to assert callback order for app/com/org Open and Private bases.
- Retire superseded compatibility flags only after descendant tests prove behavior parity.

## Done Criteria

- `docs/architecture/controller-lifecycle.md` matches implemented callback order.
- Open and Private bases complete Actor before applying locale/theme/observability side effects.
- Actor cleanup runs through an ensure-style lifecycle hook.
- Bare bases do not include Actor, preference, authentication, verification, or authorization state.
- Guest bases reject authenticated actors without endpoint-local repeated `guest_only!`.
- Exception controllers are either migrated to a named derivative base or explicitly listed in this
  plan with their guard state.
