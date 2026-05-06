# Treeable Recursive SQL Refactor

GitHub: #672

## Summary

Replace the raw recursive SQL in `app/models/concerns/treeable.rb` with the Rails CTE API (`with` /
`with_recursive`).

This is a shared concern refactor. It affects every master model that includes `Treeable`:

- document masters for app, com, and org
- timeline masters for app, com, and org

## Implementation Changes

- Rewrite the recursive tree queries in `Treeable` to build relations with Rails CTE methods.
- Keep the current behavior for:
  - root sentinel handling
  - `include_self`
  - `max_depth`
  - tree order with `position` fallback
- Keep `TaxonomyBuilder` behavior stable when it consumes the returned relation.
- Remove model-specific tree SQL duplication only if it appears during the refactor.

## Test Plan

Add or update regression tests before the implementation is finalized:

- Shared tree tests in `test/support/treeable_shared_tests.rb`
  - subtree ids with and without self
  - ancestor ids with and without self
  - breadcrumb order
  - ancestor and descendant relation behavior
  - stable tree order with and without `position`
  - cycle validation
- Add a regression case for `max_depth` if the new API keeps that path.
- Confirm `TaxonomyBuilder` still returns the same tree order.
- Keep coverage for one model with custom tree setup if it still needs a local test file.

## Acceptance Criteria

- Raw recursive SQL is removed from `Treeable`.
- Tree master behavior stays unchanged for all current models.
- The shared test suite detects order, depth, and cycle regressions.
- The refactor is documented after implementation in `adr/`.

## Assumptions

- Current Active Record already provides the recursive CTE API.
- The work should stay limited to the shared tree concern and its tests.
- The GitHub issue is the tracking record for the implementation work.
