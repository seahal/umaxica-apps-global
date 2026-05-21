# Actor Naming

## Purpose

This document records the accepted authenticated actor naming for surfaces that have completed the
runtime rename. These names are runtime contracts for controllers, current context, tokens,
policies, and tests.

## Surface Actors

| Surface | Authenticated actor | Runtime actor type | Current helper     | Policy           | Status  |
| ------- | ------------------- | ------------------ | ------------------ | ---------------- | ------- |
| `app`   | `Client`            | `client`           | `current_client`   | `ClientPolicy`   | Current |
| `org`   | `Operator`          | `operator`         | `current_operator` | `OperatorPolicy` | Current |
| `com`   | `Visitor`           | `visitor`          | `current_visitor`  | `VisitorPolicy`  | Current |

## Current Migration State

The authenticated actor naming migration is complete at the runtime boundary. The accepted decisions
are:

- `app`: `User` was renamed to `Client`.
- `org`: `Staff` was renamed to `Operator`.
- `com`: `Customer` was renamed to `Visitor`.

The `app` authenticated actor is `Client`. Actor-owned credential, preference, ticket, signal,
occurrence, and chronicle models use Rails-conventional table names such as `clients` and
`client_*`.

For `org`, the authenticated actor is `Operator`. The actor model now uses the conventional
`operators` table, and actor-owned models use `operator_*` table names.

The org-principal workspace account linked to the authenticated `Operator` is
`OperatorWorkspaceAccount`, backed by the `org_zenith.operator_workspace_accounts` table.
`OperatorAccount` is reserved for the org RP account in `org_zenith.operator_accounts`.

## Rules

- Do not introduce `Staff` runtime compatibility constants, helpers, policies, params, or JWT actor
  claims.
- Do not introduce `User` runtime compatibility constants, helpers, policies, params, or JWT actor
  claims for the `app` authenticated actor.
- Use `current_client`, `authenticate_client!`, `client?`, and `ClientPolicy` for `app`
  authenticated flows.
- Use JWT `act=client` for `app` actor tokens.
- Use `current_operator`, `authenticate_operator!`, `operator?`, and `OperatorPolicy` for `org`
  authenticated flows.
- Use JWT `act=operator` for `org` actor tokens.
- Do not add `self.table_name` compatibility overrides for old `user_*`, `staff_*`, or `customer_*`
  actor table names.

## Related Decisions

- `adr/app-actor-client-naming.md`
- `adr/org-actor-operator-naming.md`
- `adr/com-actor-visitor-naming.md`
