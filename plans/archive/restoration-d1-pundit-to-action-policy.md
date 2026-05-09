# Restoration D1: Pundit → Action Policy Migration

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/pundit-to-action-policy-migration.md`

## Goal

Replace Pundit with Action Policy across the codebase. Use `authorize :user, optional: true` where
the original code allowed an unauthenticated path.

## Key surface

Every controller that calls `authorize`, `policy`, or `policy_scope`. The `app/policies/` tree. The
`ApplicationController` authorization mixins.

## Verification

No remaining `Pundit` constant in the codebase. Existing controller tests pass. Add tests for any
policy whose semantics changed.
