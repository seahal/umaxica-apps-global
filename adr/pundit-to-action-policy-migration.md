# ADR: Migrate authorization from Pundit to Action Policy

## Status

Partially implemented (Phase 1 and Phase 2 complete). Active enforcement pending.

## Context

The codebase used `pundit` as the authorization gem. Multiple `# FIXME: I hate this line.` comments
on `include Pundit::Authorization` throughout engine controllers indicated developer intent to
remove it. The `action_policy` gem was already present in the Gemfile alongside `pundit`, confirming
the migration was anticipated.

Key observations from the feasibility analysis:

- 48 policy files, all inheriting from a custom `ApplicationPolicy` (not `Pundit::Policy` directly),
  which lowered migration cost.
- `authorize_request!` in `Authorization::Base` was a stub returning `true` — Pundit was never
  actually enforcing authorization in production controllers.
- `ActionPolicy::Unauthorized` API differs from `ActionPolicy::Unauthorized`:
  - Pundit: `.policy`, `.query`, `.record`
  - Action Policy: `.policy`, `.rule`, `.object`
- Action Policy `initialize(record = nil, **params)` uses keyword `user:` for the actor, which is
  inverted from Pundit's `(user, record)` positional convention.

## Decision

Migrate from `pundit` to `action_policy` in phases to reduce risk.

### Phase 1: Remove Pundit (complete — issue #674)

Remove the `pundit` gem and replace all references across controllers, concerns, and tests.

Changes made:

- `Gemfile`: removed `gem "pundit"`.
- Engine ApplicationControllers (13 files): `include Pundit::Authorization` replaced with
  `include ActionPolicy::Controller`.
- `app/controllers/concerns/authorization_audit.rb`: updated to `ActionPolicy::Unauthorized`,
  `exception.rule`, `exception.object`.
- `engines/signature/app/controllers/concerns/sign/error_responses.rb`: updated to
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

### Phase 3: Active enforcement (pending — separate task)

The `authorize_request!` stub in `Authorization::Base` still returns `true`. Actual authorization
enforcement requires:

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

- Authorization is still not enforced in production (Phase 3 pending). This is the same state as
  before the migration — the stub was always returning `true`.
- The constructor shim (`case args.length`) is a transitional layer. All 132 legacy-style test
  instantiations continue to work, but should be migrated to `Policy.new(record, user: actor)` style
  once enforcement is active.
- Staff controllers require explicit context wiring before Phase 3 can activate (the railtie default
  wires `current_user`, which is undefined on staff controller trees).

## Related

- GitHub issue #674: Migrate authorization from Pundit to Action Policy
- `app/policies/application_policy.rb`
- `app/controllers/concerns/authorization/base.rb` (stub to replace in Phase 3)
- Action Policy documentation: https://actionpolicy.evilmartians.io/
