# Org Actor Uses Operator Naming

**Status:** Accepted (2026-05-14)

## Context

The `org` surface historically used `Staff` as its authenticated actor name. That name overlaps with
policy concepts during the Action Policy rollout and makes actor/policy lookup ambiguous.

The repository already had an `Operator` model backed by the `operators` table. That record is an
account-like org association, not the authenticated org actor.

## Decision

The authenticated `org` actor is named `Operator`.

- `Operator < OrgPrincipalRecord` owns the authenticated org actor table.
- The physical actor table has been migrated from `staffs` to the conventional `operators` table.
- Existing `staff_*` credential, token, preference, and audit tables remain physical backing tables
  for this step.
- The prior `Operator < OrgPrincipalRecord` account association is renamed to
  `OperatorWorkspaceAccount`. `OperatorAccount` is reserved for the org RP account in `org_zenith`.
- Runtime authentication, current actor, and policy lookup use `operator` naming.
- No `Staff` compatibility constants, helpers, params, policy names, or actor-type claims are
  retained for runtime code.

## Consequences

- `sign/org` uses `current_operator`, `authenticate_operator!`, and `OperatorPolicy`.
- JWT actor claims for the org surface use `operator`.
- Remaining `staff_*` table and association names are credential, preference, or compatibility
  storage names until those records are renamed separately.
- Existing OIDC clients or database rows that still say `staff` are legacy storage/settings inputs
  only; runtime issuance and validation normalize the authenticated actor to `operator`.
