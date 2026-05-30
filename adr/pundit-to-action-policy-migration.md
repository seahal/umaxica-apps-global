# ADR: Use Action Policy for Authorization

## Status

Accepted (2026-05-06). Partially implemented; per-action object-level enforcement rollout is
pending. Re-verified 2026-05-30 — see the Phase 3 update for corrections to this section.

## Context

The codebase used `pundit` as the authorization gem. Multiple `# FIXME: I hate this line.` comments
on `include Pundit::Authorization` throughout engine controllers indicated developer intent to
remove it. The `action_policy` gem was already present in the Gemfile alongside `pundit`, confirming
the migration was anticipated.

We have decided that authorization in this Rails application will be implemented with
`gem "action_policy"`. Authentication remains separate; this ADR covers the authorization layer
only.

Key observations from the feasibility analysis:

- 48 policy files, all inheriting from a custom `ApplicationPolicy` (not `Pundit::Policy` directly),
  which lowered migration cost.
- `authorize_request!` in `Authorization::Base` was a stub returning `true` — Pundit was never
  actually enforcing authorization in production controllers.
- Pundit's unauthorized error API differs from `ActionPolicy::Unauthorized`:
  - Pundit: `.policy`, `.query`, `.record`
  - Action Policy: `.policy`, `.rule`, `.object`
- Action Policy `initialize(record = nil, **params)` uses keyword `user:` for the actor, which is
  inverted from Pundit's `(user, record)` positional convention.

## Decision

Use `action_policy` as the standard authorization library for this application.

New authorization work must use Action Policy concepts and APIs:

- policies inherit from `ApplicationPolicy`
- controllers use `ActionPolicy::Controller`
- record checks use `authorize!`
- collection filtering uses `authorized_scope`
- authorization failures are handled as `ActionPolicy::Unauthorized`

The historical Pundit implementation is not the target architecture. Any remaining Pundit-shaped
patterns should be treated as migration residue and removed when touched.

Migrate from `pundit` to `action_policy` in phases to reduce risk.

### Phase 1: Remove Pundit (complete — issue #674)

Remove the `pundit` gem and replace all references across controllers, concerns, and tests.

Changes made:

- `Gemfile`: removed `gem "pundit"`.
- Former engine-era ApplicationControllers (13 files): `include Pundit::Authorization` replaced with
  `include ActionPolicy::Controller`.
- `app/controllers/concerns/authorization_audit.rb`: updated to `ActionPolicy::Unauthorized`,
  `exception.rule`, `exception.object`.
- former `engines/signature/app/controllers/concerns/sign/error_responses.rb`: updated to
  `ActionPolicy::Unauthorized`.
- 15 test files: `Pundit::Authorization` references updated to `ActionPolicy::Controller`.

Result: zero `Pundit::` references remain; 496 runs / 0 failures on affected tests.

### Phase 2: ApplicationPolicy inherits ActionPolicy::Base (complete — issue #674)

Change `ApplicationPolicy` to inherit from `ActionPolicy::Base` with a backward-compatible
constructor shim.

Changes made:

- `app/policies/application_policy.rb`:
  - Class declaration: `class ApplicationPolicy < ActionPolicy::Base`
  - Authorization subject: `authorize :user, optional: true`
  - Legacy call shim via `case args.length`:
    - Two positional args → translated to `super(record, user: actor)`
    - One positional arg (native ActionPolicy style) → passed through
  - `alias_method :actor, :user` preserves the project-wide `actor` convention across all 47
    subclass policy files.
  - Inner `Scope` class retained as a transitional plain-Ruby class (not an ActionPolicy `scope_for`
    block).

Result: 442 runs / 0 failures on policy test suite; rubocop clean.

### Phase 3: Active enforcement (in progress — separate task)

> **Re-verification correction (2026-05-30).** The original Phase 3 text below predated the Actor
> facade and the authentication-mode work; several of its claims are now stale. Corrected status:
>
> - **Authorization is two distinct layers; do not conflate them.**
>   1. **Authentication-mode enforcement** (`enforce_access_policy!` in
>      `app/controllers/concerns/authentication/base.rb`) — gates _who may reach an action_ (modes
>      `:bare` / `:deny_all` / `:guest` / `:private` / `:open`) per ADR
>      `two-base-authentication-mode-boundaries.md`. This is **live** as a `before_action` on all
>      three surface base controllers (`sign/{app,org,com}/application_controller.rb`). It is NOT
>      object-level authorization.
>   2. **Object/resource authorization** (`authorize!(record)`, `authorized_scope`) — gates _what an
>      authenticated actor may do to a specific record_. This is the work still rolling out.
> - The `authorize_request!` hook in `Authorization::Base` **no longer returns `true`** — it now
>   `raise`s (fail-closed, "disabled; authorize through Action Policy") and has no callers. The
>   "implicit allow" risk described in the old Consequences section is resolved.
> - **Context wiring is already done and is Actor-based**, not the railtie default. All three
>   surface bases declare `authorize :user, through: :current_policy_user`, where
>   `current_policy_user` (`app/controllers/concerns/actor_support.rb`) returns
>   `Actor.authz.policy_user || safe_current_resource`. The old "user controllers use
>   `current_user`, staff controllers need `current_staff`" plan is superseded — both unify on the
>   Actor.
> - **No `policy_scope(...)` call sites remain**; that migration sub-item is complete.
>
> Genuine remaining Phase 3 work: add per-action `authorize!` / `authorized_scope` to controllers.
> As of this re-verification only **14 of 508** controllers do so. Roll this out test-first, one
> controller group per PR (read-only/low-risk first, sensitive operations last), proving for each
> group that allowed actors keep their status/redirect/flash and denied actors are correctly
> rejected through the existing `authorization_audit.rb` / `rescue_from ActionPolicy::Unauthorized`
> path. Migrate remaining transitional `Scope` inner classes to `scope_for :active_record_relation`
> as the controllers that use them are touched.

Original Phase 3 text (retained for history; see correction above):

- Replacing the stub with real `authorize!` calls in controllers.
- Mapping authorization context per controller base class:
  - User controllers: `authorize :user, through: :current_user` (railtie default)
  - Staff controllers: `authorize :user, through: :current_staff` (explicit override required)
- Migrating `Scope` inner classes to `scope_for :active_record_relation` blocks.
- Replacing `policy_scope(...)` call sites with `authorized_scope(...)`.

## Consequences

**Positive:**

- Pundit dependency removed; no more `FIXME` noise in engine controllers.
- `ActionPolicy::Base` provides policy caching, typed scopes, and richer error context.
- `ApplicationPolicy` is now aligned with Action Policy conventions, enabling gradual enforcement
  rollout per controller.

**Negative / risks:**

- Object-level authorization is enforced on only a minority of controllers (14/508 as of
  2026-05-30); the rollout is in progress (Phase 3). Note this is no longer the pre-migration state:
  the `authorize_request!` hook now fails closed (raises) instead of returning `true`, and the
  authentication-mode gate (`enforce_access_policy!`) is live, so the "implicit allow everywhere"
  risk is gone — what remains is extending per-record checks.
- The constructor shim (`case args.length`) is a transitional layer. All 132 legacy-style test
  instantiations continue to work, but should be migrated to `Policy.new(record, user: actor)` style
  once enforcement is active.
- ~~Staff controllers require explicit context wiring before Phase 3 can activate~~ — superseded:
  all surface bases now wire `authorize :user, through: :current_policy_user` (Actor-based), so no
  per-tree `current_user`/`current_staff` wiring is needed.

## Related

- GitHub issue #674: Migrate authorization from Pundit to Action Policy
- `app/policies/application_policy.rb`
- `app/controllers/concerns/authorization/base.rb` (`authorize_request!` now raises; fail-closed)
- `app/controllers/concerns/actor_support.rb` (`current_policy_user`, Actor-based policy context)
- `app/controllers/concerns/authentication/base.rb` (`enforce_access_policy!`, authentication-mode
  layer)
- ADR `two-base-authentication-mode-boundaries.md` (the distinct authentication-mode layer)
- Action Policy documentation: https://actionpolicy.evilmartians.io/
