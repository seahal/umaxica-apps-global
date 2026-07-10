# App Actor Uses Client Naming

**Status:** Accepted (2026-05-17)

## Context

The `app` surface historically used `User` as its authenticated actor name. That name overlaps with
policy concepts during the Action Policy rollout and makes actor and policy lookup ambiguous.

The repository also has long-lived `user_*` credential, token, preference, audit, and reference
tables. Those names are storage compatibility names and are not the runtime actor contract.

## Decision

The authenticated `app` actor is named `Client`.

- `Client < AppPrincipalRecord` owns the authenticated app actor record while remaining backed by
  the existing `users` table.
- Runtime authentication, current actor, authorization, verification, JWT actor claims, and policies
  use `client` naming.
- `sign/app` uses `current_client`, `authenticate_client!`, and `ClientPolicy`.
- JWT actor claims for the app surface use `client`.
- Existing `UserToken`, `UserEmail`, `UserPreference`, and related `user_*` storage names remain
  compatibility names until a separate storage/model cleanup is accepted.
- No `User` runtime compatibility constants, helpers, params, policy names, or actor-type claims are
  retained for the app authenticated actor.

## Consequences

- The actor rename plan is complete at the runtime boundary: `User(App) -> Client`,
  `Staff(Org) -> Operator`, and `Customer(com) -> Visitor`.
- Runtime code should not introduce new `User` actor APIs for app flows.
- Future cleanup may rename `user_*` storage-backed models and tables, but that is a separate
  migration plan because it touches database compatibility and historical records.
