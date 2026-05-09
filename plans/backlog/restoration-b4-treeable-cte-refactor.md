# Restoration B4: Treeable CTE Refactor

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/treeable-cte-refactor.md`

## Goal

Replace ad-hoc tree-walk code with a `Treeable` concern that uses recursive CTE (`with_recursive`).
Apply it to the models the ADR names.

## Key surface

New `Treeable` concern; the models that adopt it; any view that walks ancestors / descendants.

## Verification

Tree-traversal tests that compare the CTE result to a reference Ruby walk on a small fixture set.
