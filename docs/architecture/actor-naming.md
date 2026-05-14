# Actor Naming

## Purpose

This document records the accepted authenticated actor naming for surfaces that have completed the
runtime rename. These names are runtime contracts for controllers, current context, tokens,
policies, and tests.

## Surface Actors

| Surface | Authenticated actor | Runtime actor type | Current helper | Policy | Status |
| --- | --- | --- | --- | --- |
| `org` | `Operator` | `operator` | `current_operator` | `OperatorPolicy` | Current |
| `com` | `Visitor` | `visitor` | `current_visitor` | `VisitorPolicy` | Current |

## Current Migration State

The naming migration is being done by surface. The current accepted decisions are:

- `com`: `Customer` was renamed to `Visitor`.
- `org`: `Staff` was renamed to `Operator`.

The `app` surface still uses `User` in current runtime code. Do not use `VisitorAccount` for `app` runtime
code until that surface has its own accepted ADR and implementation.

For `org`, the authenticated actor is `Operator`. The actor model now uses the conventional
`operators` table.

The account-like org association linked to the authenticated `Operator` is `OperatorAccount`, backed
by the conventional `operator_accounts` table.

## Rules

- Do not introduce `Staff` runtime compatibility constants, helpers, policies, params, or JWT
  actor claims.
- Use `current_operator`, `authenticate_operator!`, `operator?`, and `OperatorPolicy` for `org`
  authenticated flows.
- Use JWT `act=operator` for `org` actor tokens.
- Keep `staff_*` names only where they refer to credential, preference, or compatibility records
  that have not yet been renamed at the model/API level.

## Related Decisions

- `adr/org-actor-operator-naming.md`
- `adr/com-actor-visitor-naming.md`
