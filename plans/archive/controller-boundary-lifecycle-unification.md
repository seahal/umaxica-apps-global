# Controller Boundary Lifecycle Unification

## Status

Deprecated by the 2026-05-25 two-base authentication mode direction.

## Context

The previous accepted controller boundary model was:

- `OpenController`
- `BareController`
- `PrivateController`
- `GuestController`

That model is no longer the active implementation direction. Current work should express only
`BareController` and surface-local `ApplicationController` as semantic destination bases, with
authentication classification handled by explicit concrete controller/action metadata and policy.
`OpenController`, `PrivateController`, and `GuestController` are compatibility wrappers only.

The stable lifecycle target is documented in `docs/architecture/controller-lifecycle.md`.

This plan supersedes these older or narrower plans where they overlap:

- `plans/backlog/controller-boundary-exception-retirement.md`
- `plans/backlog/static-guest-controller-flag-retirement.md`
- controller-lifecycle parts of `plans/archive/actor-current-context-api-cleanup.md`

`plans/archive/actor-current-context-api-cleanup.md` is now completed/retired (2026-06-01): the
lower-level Actor API cleanup is done and no migration-only direct readers remain.

## Goals

- Make controller inheritance express only the two lifecycle families; explicit metadata expresses
  the request access contract.
- Keep `BareController` for endpoints that do not use application authentication machinery.
- Move authentication-aware `ApplicationController` lifecycle code toward:
  1. rate limit and request self-defense;
  2. side-effect-free Actor context seed;
  3. preference/authentication/session resolution;
  4. completed Actor snapshot;
  5. side-effect reflection from Actor values;
  6. action execution;
  7. guaranteed Actor cleanup.
- Move new runtime preference reads to `Actor.preferences`.
- Keep preference writes inside preference concerns and surface-specific models.
- Replace endpoint-local `public_strict!`, `auth_required!`, and repeated `guest_only!` declarations
  with explicit authentication metadata.

## Current Gaps

- `Preference::Localization` no longer registers `apply_localization_preferences` through
  `included do`; each controller base must place the callback explicitly. Some bases still need
  callback-order cleanup so locale/timezone reflection runs from completed Actor state.
- Preference concerns no longer own request callback registration; controller bases and endpoint
  controllers must place preference callbacks and callback skips explicitly.
- `set_color_theme` runs before `set_current_actor` in several controller bases, so theme reflection
  does not yet use the completed `Actor.preferences` snapshot.
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
2. The immutable `Actor.preferences` snapshot.
3. JWT `prf` claims as transport/fallback.
4. Cookies as request input or compatibility fallback.

The language cookie key remains `language` for Hono framework compatibility. Do not rename it to
`lx` without a separate compatibility plan.

## Work Items

- Add guaranteed Actor cleanup through an `around_action` helper and migrate controller bases to it.
- Verify explicit localization callbacks are in the correct location for each controller base.
- Verify explicit preference callbacks and endpoint skips are in the correct location for each
  controller base.
- Move theme reflection after `set_current_actor` and prefer `Actor.preferences.theme` where safe.
- Keep `set_preferences_cookie` before `set_current_actor` while it still resolves preference token
  state, but prevent it from becoming Actor context initialization.
- Replace exception-family inheritance with explicit concrete controller/action authentication
  metadata or narrow local abstractions for:
  - social auth open entry and private unlink;
  - session-limit gate;
  - OAuth/OIDC callbacks;
  - OAuth token exchange;
  - edge token, DBSC, and preference endpoints.
- Update tests to assert callback order for app/com/org `ApplicationController` and `BareController`
  bases.
- Retire superseded compatibility flags only after descendant tests prove behavior parity.

## Done Criteria

- `docs/architecture/controller-lifecycle.md` matches implemented callback order.
- Authentication-aware bases complete Actor before applying locale/theme/observability side effects.
- Actor cleanup runs through an ensure-style lifecycle hook.
- Bare bases do not include Actor, preference, authentication, verification, or authorization state.
- Guest-mode endpoints reject authenticated actors without endpoint-local repeated `guest_only!`.
- Exception controllers are either migrated to explicit authentication metadata or explicitly listed
  in this plan with their guard state.
