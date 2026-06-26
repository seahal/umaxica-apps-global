# Acme Account / Organization Resource Boundary

Status: proposed

## Context

This ADR records the Acme surface Account / Organization resource boundary for the current
bootstrap implementation plan. It builds on `adr/acme-account-organization-bootstrap-boundary.md`
and does not replace it.

The repository already has a bootstrap path that provisions the initial Acme graph atomically.
This ADR keeps that behavior as a preservation target while documenting the next-step resource
shape, the unresolved choices, and the intended PR sequence.

## Decision

1. Acme owns Account and Organization resource management for the `app`, `org`, and `com` surfaces
   as separate but parallel surface contracts.
2. The current bootstrap path must remain atomic and must continue to provision the existing
   Account / Organization / Unit / Membership / Avatar graph.
3. Existing bootstrap behavior is preserved and expanded incrementally rather than replaced by a new
   bootstrap service.
4. Account and Organization are treated as public-lookup plural resources.
5. Rails routes keep `params[:id]` as the lookup parameter; `param: :public_id` is intentionally not
   adopted.
6. Controllers may interpret `params[:id]` as a public identifier and may rely on `to_param`
   returning `public_id`.
7. `title` is the intended short display name for Account and Organization resources.
8. Existing `moniker` and `name` fields are not removed in the initial migration and bootstrap
   stages.
9. Account title validation and Organization title validation stay separate.
10. The initial title constraint is ASCII alphanumeric, 1 to 10 characters, with no spaces,
    symbols, or Japanese characters.
11. Quota enforcement belongs in policy, quota object, or service layers rather than model
    validations.
12. The current quota direction is 10 Accounts per principal and 2 Organizations per principal.
13. Natural-person organization scope is the only scope in this effort; corporate, legal-entity,
    billing, contract, and representative-verification flows are excluded.
14. STI and enum-based `kind` / `type` modeling are not used for these resources.
15. `OrganizationUnit` is intentionally untouched by this work.
16. Preference authority conflicts are recorded separately from the Account / Organization resource
    decision.
17. The future Identity 1:n Account shape is deferred as a distinct architectural decision.
18. The next implementation work is documented as a docs-only freeze before any code, migration, or
    route changes.

## Current implementation facts

- `IdentityGraphProvisioner` delegates signup finalization to `AcmeSelectorBootstrapAuthority`.
- `AcmeSelectorBootstrapAuthority` currently provisions the Acme bootstrap graph in a single
  transaction.
- `AcmeSelectorSurfaceConfig` participates in the current selector/bootstrap wiring.
- The current bootstrap path creates the RP account, identity, account, collective, root unit,
  membership, and avatar-related artifacts.
- `Enterprise`, `Bureau`, and `Company` already expose `public_id` and `to_param` via the shared
  `PublicId` concern.
- Acme routes currently use ordinary plural resources for `accounts`, `organizations`, and
  `avatars`.
- Current controllers resolve resource identifiers through `params[:id]` and look up by
  `public_id`.
- `Persona` still carries `moniker`.
- `Organization` still carries `name`.
- `title` is not implemented yet.
- Current account binding is effectively 1:1 at the principal/account boundary.
- `OrganizationUnit` is currently created as part of the existing bootstrap flow.
- Quota enforcement is not implemented yet.

## Account / Organization model mapping

| Surface | Concrete model | Current public lookup | Notes |
| --- | --- | --- | --- |
| `app` | Account-side resource | `public_id` via `params[:id]` | Plural resource; `title` is planned additively |
| `org` | Organization-side resource | `public_id` via `params[:id]` | Plural resource; `title` is planned additively |
| `com` | Parallel Acme resource surface | `public_id` via `params[:id]` | Same lookup pattern; no `param: :public_id` |

## Existing bootstrap behavior to preserve

- `IdentityGraphProvisioner` remains the signup entry point.
- `AcmeSelectorBootstrapAuthority` remains the atomic bootstrap coordinator.
- `AcmeSelectorSurfaceConfig` remains part of the existing bootstrap wiring.
- The current bootstrap shape that creates account, organization, unit, membership, and avatar
  artifacts stays intact until a later implementation PR expands it.
- No new bootstrap service is introduced in this planning stage.

## Signup bootstrap

Signup bootstrap should remain additive and transactional.

- The existing bootstrap transaction boundary is the one to preserve.
- `title` support is expected to be added later without changing the current bootstrap ownership
  boundary.
- The current bootstrap should continue to create the initial usable graph before any future 1:n
  account redesign.
- Identity 1:n Account support must not be inferred from the current implementation; it is a future
  change.

## Public lookup and routing

- Account and Organization remain public lookup plural resources.
- Rails routes should continue to use ordinary `resources :accounts` and `resources :organizations`
  without `param: :public_id`.
- `params[:id]` remains the route parameter.
- The controller layer may treat that value as `public_id`.
- `to_param` may return `public_id` for the public lookup models.
- `Enterprise`, `Bureau`, and `Company` already demonstrate the `public_id` pattern and do not need
  an organization public-id migration for this plan.
- Legacy `Organization#domain` is not the canonical Acme Organization identifier for this effort.

## Title naming decision

### Option A

- Rename `moniker` / `name` in place.
- Remove the legacy field shape early.
- This makes the migration and bootstrap path more disruptive.

### Option B

- Add `title` first.
- Keep `moniker` / `name` for the transition period.
- Move bootstrap, forms, controllers, views, and tests gradually.
- Defer removal or semantic repurposing of legacy fields to a later decision.
- This is the recommended path.

### Option C

- Keep the current fields and postpone `title`.
- This avoids migration work now but delays the intended resource naming model.

Recommendation: Option B.

## Quota policy direction

The intended direction is policy-driven quota enforcement with future override support.

- `Acme::AccountQuotaPolicy`
- `Acme::OrganizationQuotaPolicy`
- `ACCOUNTS_PER_PRINCIPAL = 10`
- `ORGANIZATIONS_PER_PRINCIPAL = 2`

Quota policy should not be embedded directly into controller or model validation code.

Open quota questions:

- whether active, deleted, suspended, or withdrawn resources count toward the limit
- whether admin grants or plan-based overrides can exceed the defaults
- whether the quota object is a policy class, a dedicated quota service, or a small guard object

## Known conflicts

- Preference authority documentation may still describe Sign as a write authority. The current
  direction is Acme preference as RW authority and other surfaces as RO, with signed-in and
  signed-out write behavior handled separately.
- If the existing bootstrap ADR or related docs imply a different Account / Organization end state
  than this ADR, the conflict should be resolved in later implementation ADRs rather than by
  rewriting the bootstrap boundary here.

## Deferred decisions

### Identity 1:n Account

Current implementation is effectively 1:1 at the identity binding boundary.

#### Option A

- Relax the identity-binding unique constraints.
- Allow one principal to hold multiple identity bindings.
- This changes the meaning of identity binding itself.

#### Option B

- Move Account creation under principal ownership rather than under identity binding.
- Keep identity binding as login / OIDC binding.
- Model Client -> Personas, Operator -> Agents, and Visitor -> Individuals as the account-owning
  direction.
- This is the preferred future direction, but it is not implemented in this docs freeze.

#### Option C

- Keep the current 1:1 shape for now.
- Add `title`, quota, and routing preparation first.
- Defer multi-account support to a later ADR and PR.

### OrganizationUnit

- `OrganizationUnit` is out of scope for this resource-boundary freeze.
- Root-unit bootstrap behavior remains as-is.
- Billing scope, membership scope, and delegation scope remain open questions for a later decision.

## Consequences

- The current bootstrap can be documented and evolved without pretending the current 1:1 shape is
  already the final model.
- `title` can be introduced additively.
- Quota enforcement can be planned as a policy concern instead of a model concern.
- Future 1:n Account work can be separated cleanly from bootstrap, title, and routing preparation.
- Preference conflicts and OrganizationUnit questions remain visible instead of being silently
  absorbed into this decision.
