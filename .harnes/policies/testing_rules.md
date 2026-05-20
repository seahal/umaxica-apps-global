# Testing Rules

## Requirements

All changes MUST include tests appropriate to the code being changed.

---

## Required Coverage

- Success path
- Failure path
- Authorization checks
- Edge cases

---

## Forbidden

DO NOT:

- write `assert true`
- skip tests
- use TODO as placeholder
- mock core logic
- call external APIs directly from tests
- edit `test_helper.rb` when implementing or editing tests; changes to global test setup are
  forbidden unless the user explicitly requests a test infrastructure change
- add or require test-aware code in `app/` to make tests pass; implementation code must not branch
  on test environment, test framework presence, fixture data, or test-only params, headers, cookies,
  routes, flags, or policy exceptions

---

## Quality

Tests MUST:

- Be deterministic
- Be meaningful
- Validate behavior, not implementation
- Prefer DAMP over DRY: keep test meaning readable at the point of use, even when that creates some
  duplication
- Follow Arrange / Act / Assert, or Given / When / Then, so setup, operation, and expectation are
  clearly separated
- Verify one behavior per test
- Follow FIRST:
  - Fast
  - Independent
  - Repeatable
  - Self-validating
  - Timely
- Be hermetic: do not depend on external environment, wall-clock time, randomness, execution order,
  or leftover database state
- Avoid stubs and mocks where practical, especially for application behavior under test; when an
  external API, payment provider, email provider, network service, or other third-party boundary is
  involved, replace that boundary with a local fake, fixture, adapter stub, or approved test helper
  instead of making a real external call
- Verify production behavior through production-valid seams; if a test needs control over time,
  external services, randomness, or adapters, control the boundary from the test without adding
  test-only branches to application code
- Make important setup visible in the test; do not hide business meaning in helpers, fixtures, or
  shared setup
- Prefer local clarity over global reuse
- Be obvious, not clever
- Fail for one clear reason
- For model-layer Minitest:
  - Test cases MUST include boundary value analysis and equivalence partitioning
  - Applies when validations, ranges, limits, formats, or categorizable inputs are involved

---

## Structure

- Use Minitest for Ruby code
- Use `vp test` (Vitest) for JavaScript code
- If a change spans Ruby and JavaScript, include coverage for both where behavior changes on both
  sides
- Follow existing patterns
- Keep tests readable

---

## Avoid

Avoid:

- Mystery Guest: important fixtures, setup, or helpers that are not visible from the test
- Obscure Test: abstractions that make the behavior under test unclear
- Fragile Test: assertions that break on harmless implementation changes
- Flaky Test: dependence on time, parallel execution, external APIs, randomness, or ordering
- Overspecified Test: checking internals so tightly that correct refactors fail
- Shared setup for business meaning: do not hide authorization conditions, user types, permissions,
  or state transitions in common setup

---

## Summary

A change without proper tests is invalid.
