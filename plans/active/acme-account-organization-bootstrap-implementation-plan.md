# Acme Account / Organization Bootstrap Implementation Plan

Status: active implementation

## Goal

Bring the Acme bootstrap and entity model toward the intended Account / Organization structure
without changing the current implementation in this planning step.

## Scope Guard

- Docs-only PR freeze.
- No application code changes.
- No migrations.
- No route changes.
- No model, controller, or service changes.
- No test changes.
- No `rails generate`.

## Current Repository State

- `Enterprise`, `Bureau`, and `Company` already have `public_id` and already use `to_param` behavior
  consistent with public lookup.
- Routes for `accounts`, `organizations`, and `avatars` already use standard plural resources and do
  not set `param: :public_id`.
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
- `Persona` / `Organization` naming is still legacy and should be treated as the transition source
  for `title`.
- The plan must stay compatible with the existing bootstrap transaction, idempotency, and atomic
  graph creation.

## Design Guardrails

- Existing bootstrap must not be broken.
- `IdentityGraphProvisioner`, `AcmeSelectorBootstrapAuthority`, and `AcmeSelectorSurfaceConfig`
  remain the bootstrap stack.
- Do not introduce a new bootstrap service.
- Keep Account title validation and Organization title validation separate.
- Keep natural-person scope only.
- Keep `OrganizationUnit` untouched.
- Keep preference authority conflicts documented, not implemented.

## Unresolved Design Points

1. Identity 1:n Account

- The current shape is 1:1.
- Future 1:n support will require association and uniqueness redesign.
- Option A: loosen identity-binding uniqueness.
- Option B: move account ownership under principal and keep identity binding as login / OIDC
  binding.
- Option C: keep 1:1 for now.
- This is a separate ADR and a separate implementation PR.

2. `title` introduction

- Add `title` first; do not rename `moniker` / `name` in this freeze.
- Keep Account title validation and Organization title validation separate.
- Keep bootstrap preparation additive so later PRs can write `title` without immediate removal of
  the older fields.
- Initial validation target: `/\A[A-Za-z0-9]{1,10}\z/`.
- Do not create a shared concern, shared validator, shared constant, or generic `ShortTitle`
  abstraction.

3. Quota direction

- Default quota targets are 10 Accounts per principal and 2 Organizations per principal.
- Keep the implementation in policy, quota object, or service layers.
- Record whether inactive rows count toward quota before implementation.

4. Preference authority

- Current direction: Acme read-write, other surfaces read-only.
- Existing ADRs may conflict with this direction.
- Resolve in a separate ADR rather than in this bootstrap plan.
- Keep signed-in and signed-out write behavior separate from the resource plan.

5. OrganizationUnit

- Do not change the Unit model, route, or API surface in this work.
- Preserve the existing root unit bootstrap behavior.
- Leave transfer and delegation for another decision.
- Do not add new Unit routes or APIs in any PR in this plan.

## Recommended PR Split

### PR 1: ADR and memo freeze

- Add the ADR and planning notes.
- Make no application code changes.
- Confirm `git diff --stat` only includes docs files.
- Confirm `git diff --name-only` only includes files under `adr/`, `memos/`, and `plans/active/`.
- Verify `app/`, `config/`, `db/`, `test/`, `spec/`, and `src/` are unchanged.
- This PR is the current task.

### PR 2: Additive `title` migration

- Add `title` to Account-side models.
- Add `title` to Organization-side models.
- Keep Account title validation and Organization title validation separate.
- Do not remove existing `moniker` / `name` fields yet.
- Prepare bootstrap to write `title` later.
- Keep the migration additive and reversible.
- Do not use a shared title concern or generic validator.

### PR 3: Signup bootstrap `title` support

- Update the Acme bootstrap path to populate `title`.
- Ensure signup completion creates account, organization, membership, and root unit atomically.
- Add tests that prove bootstrap writes `title`.
- Keep `IdentityGraphProvisioner` delegating to `AcmeSelectorBootstrapAuthority`.
- Preserve idempotency and existing transaction behavior.
- Rollback consideration: title writes must not break existing moniker/name fallback behavior.
- Risk: bootstrap drift if one surface is updated without the other.

### PR 4: Quota policy

- Enforce 10 Accounts per Identity.
- Enforce 2 Organizations per Identity.
- Put the logic in policy, quota, or service layers.
- Keep the limits configurable for future growth.
- Candidate names: `Acme::AccountQuotaPolicy`, `Acme::OrganizationQuotaPolicy`.
- Candidate constants: `ACCOUNTS_PER_PRINCIPAL = 10`, `ORGANIZATIONS_PER_PRINCIPAL = 2`.
- Test strategy: cover limit reached, under-limit, and boundary cases at 9/10 and 1/2.
- Rollback consideration: quota defaults should be easy to relax if production signups are blocked.
- Risk: count semantics for deleted or suspended rows can surprise users if not decided first.

### PR 5: Account / Organization route and controller alignment

- Keep `resources :accounts` and `resources :organizations`.
- Keep `param:` unspecified.
- Keep resolving `params[:id]` as `public_id`.
- Keep `to_param` returning `public_id`.
- Preserve the same pattern across app, org, and com.
- Test strategy: route recognition, controller lookup, and `to_param` behavior.
- Rollback consideration: keep old lookup code available until public-id lookup is proven.
- Risk: mismatched route helpers across surfaces if any surface is updated alone.

### PR 6: Identity 1:n redesign

- Treat this as a separate architectural change.
- Revisit association shape, unique indexes, bootstrap impact, fixtures, and tests before changing
  the storage model.
- Preferred direction: move Account ownership under principal and keep identity binding as login /
  OIDC binding.
- Test strategy: add coverage for multiple accounts per principal and uniqueness boundaries.
- Rollback consideration: this change will likely need migration and data backfill staging.
- Risk: the current 1:1 bootstrap assumptions will break if the redesign is attempted without a
  dedicated ADR.

## Open Questions

- Should quota count active records only or all records in terminal states too?
- Should title validation stay ASCII-only permanently or only for the initial cut?
- Should future 1:n Account ownership be principal-centric or binding-centric?
- Should `title` eventually replace `moniker` / `name`, or remain an additive field permanently?
- Should `OrganizationUnit` remain a purely structural node or gain membership/billing semantics in
  a future decision?

## Risks / Rollback

- The largest implementation risk is changing bootstrap shape before title and quota semantics are
  locked.
- A second risk is introducing a shared validation abstraction that later blocks divergence.
- A third risk is confusing the docs-freeze work with code changes.
- Rollback for this PR is simple: remove the added docs only.

## Docs-Only Verification

- Run `git diff --stat`.
- Run `git diff --name-only`.
- Confirm only `adr/`, `memos/`, and `plans/active/` files changed.
- Confirm no files changed under `app/`, `config/`, `db/`, `test/`, `spec/`, or `src/`.
- Confirm there is no migration, route, controller, model, service, or test diff.

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
