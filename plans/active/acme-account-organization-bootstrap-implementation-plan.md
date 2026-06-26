# Acme Account / Organization Bootstrap Implementation Plan

Status: active implementation

## Goal

Bring the Acme bootstrap and entity model toward the intended Account / Organization structure
without changing the current implementation in this planning step.

## Current Repository State

- `Enterprise`, `Bureau`, and `Company` already have `public_id` and already use `to_param`
  behavior consistent with public lookup.
- Routes for `accounts`, `organizations`, and `avatars` already use standard plural resources and
  do not set `param: :public_id`.
- Current controllers resolve resources through `params[:id]` and `public_id` lookup.
- Account-side records still expose `moniker` rather than `title`.
- Organization-side records still expose `name` rather than `title`.
- `title` is not implemented yet for the target Account / Organization entities.
- `IdentityGraphProvisioner` currently calls `AcmeSelectorBootstrapAuthority`.
- `AcmeSelectorBootstrapAuthority` currently provisions the bootstrap graph in a single transaction.
- The current bootstrap path already creates the root unit.
- The current identity binding shape remains effectively 1:1 at the account boundary.
- Quota enforcement is not yet implemented.
- `OrganizationUnit` is already part of bootstrap behavior, but this plan does not change it.

## Unresolved Design Points

1. Identity 1:n Account

- The current shape is 1:1.
- Future 1:n support will require association and uniqueness redesign.
- The correct place for the new shape still needs an ADR if the storage model changes.

2. `title` introduction

- Decide whether to rename `moniker` / `name` or add `title` first.
- Keep Account title validation and Organization title validation separate.
- Keep bootstrap preparation additive so later PRs can write `title` without immediate removal of
  the older fields.

3. Preference authority

- Current direction: Acme read-write, other surfaces read-only.
- Existing ADRs may conflict with this direction.
- Resolve in a separate ADR rather than in this bootstrap plan.

4. OrganizationUnit

- Do not change the Unit model, route, or API surface in this work.
- Preserve the existing root unit bootstrap behavior.
- Leave transfer and delegation for another decision.

## Recommended PR Split

### PR 1: ADR and memo freeze

- Add the ADR and planning notes.
- Make no application code changes.

### PR 2: Additive `title` migration

- Add `title` to Account-side models.
- Add `title` to Organization-side models.
- Keep Account title validation and Organization title validation separate.
- Do not remove existing `moniker` / `name` fields yet.
- Prepare bootstrap to write `title` later.

### PR 3: Signup bootstrap `title` support

- Update the Acme bootstrap path to populate `title`.
- Ensure signup completion creates account, organization, membership, and root unit atomically.
- Add tests that prove bootstrap writes `title`.

### PR 4: Quota policy

- Enforce 10 Accounts per Identity.
- Enforce 2 Organizations per Identity.
- Put the logic in policy, quota, or service layers.
- Keep the limits configurable for future growth.

### PR 5: Account / Organization route and controller alignment

- Keep `resources :accounts` and `resources :organizations`.
- Keep `param:` unspecified.
- Keep resolving `params[:id]` as `public_id`.
- Keep `to_param` returning `public_id`.
- Preserve the same pattern across app, org, and com.

### PR 6: Identity 1:n redesign

- Treat this as a separate architectural change.
- Revisit association shape, unique indexes, bootstrap impact, fixtures, and tests before changing the
  storage model.

## Non-Goals

- No application code changes in this planning step.
- No migrations in this planning step.
- No route changes in this planning step.
- No model changes in this planning step.
- No controller changes in this planning step.
- No test changes in this planning step.
- No OrganizationUnit redesign in this planning step.
- No selector / switcher refactor in this planning step.

## Next Step

Use this plan together with the ADR to guide the first implementation PR that adds `title` and keeps
the bootstrap path additive.
