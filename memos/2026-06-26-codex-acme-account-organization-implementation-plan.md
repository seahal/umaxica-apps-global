# Acme Account / Organization Implementation Plan Notes

## Context

This memo records the current repository state and the unresolved implementation questions around
Acme Account / Organization bootstrap.

## Observed

- `Enterprise`, `Bureau`, and `Company` each already expose `public_id` and `to_param` via the
  shared `PublicId` concern.
- Acme routes use ordinary plural resources for `accounts`, `organizations`, and `avatars`; they do
  not use `param: :public_id`.
- Current Acme controllers resolve resource identifiers through `params[:id]` and look up by
  `public_id`.
- `Persona` still carries `moniker` and `Organization` still carries `name`; `title` is not
  implemented yet.
- `IdentityGraphProvisioner` delegates sign-up finalization to `AcmeSelectorBootstrapAuthority`.
- `AcmeSelectorBootstrapAuthority` already provisions the Acme bootstrap graph inside a single
  transaction.
- The current bootstrap shape creates the RP account, identity, account, collective, root unit,
  membership, and avatar-related artifacts in one coordinated flow.
- The current account binding shape is still 1:1 at the principal/account boundary.
- Quota enforcement for accounts per identity and organizations per identity is not implemented.
- `OrganizationUnit` is currently created as part of the existing bootstrap flow, and the root unit
  behavior is already established.

## Why It Matters

The repository already contains most of the mechanical pieces needed for the intended Acme model,
but the long-term direction is not yet captured cleanly in the implementation plan:

- the current 1:1 binding must be distinguished from the target 1:n direction;
- `title` should be introduced without forcing an early rename;
- quota should stay out of model validation;
- preference authority needs a separate ADR update if the older docs still describe the wrong
  owner.

## Open Questions

1. Identity 1:n Account

- The current model is effectively 1:1 at the identity binding boundary.
- Moving to 1:n will require association changes and likely unique index changes.
- It is not yet decided whether the future shape should hang multiple Accounts directly under the
  principal or should expand identity bindings.

2. `title` introduction

- It is still open whether `moniker` / `name` should eventually be renamed or whether `title`
  should be added first and adopted gradually.
- Existing `name` validation and collective concerns will need careful handling if `title` is added
  first.

3. Preference authority

- The current direction is Acme read-write and other surfaces read-only.
- Older ADRs may still describe a different authority split.
- That conflict needs a separate ADR update and should not be mixed into this account plan.

4. OrganizationUnit

- This memo intentionally does not define a new Unit design.
- The current root unit bootstrap behavior should remain intact until a separate decision is made.

## Promotion Candidate

This memo should be promoted into implementation PR notes and task slicing when the next change is
ready to touch models, migrations, or bootstrap code.
