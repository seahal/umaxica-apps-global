# GH-576: Implement Planned Automated Test Stack

GitHub: #576

## Summary

Build out the planned testing layers that are documented but not yet implemented.

## Scope

- Add API/contract testing support with Rswag or an agreed equivalent.
- Add JS unit test coverage for frontend helpers/modules.
- Add system/integration coverage with Playwright or Capybara for key user flows.
- Add performance test tooling for important endpoints (e.g., k6 or wrk).
- Wire the selected tools into local developer workflow and CI.

## Acceptance Criteria

- Contract/API testing is implemented and exercised on at least one surface.
- Frontend unit testing has a working baseline.
- End-to-end or system coverage exists for at least one critical flow.
- Performance tooling is checked in with at least one runnable scenario.
- The docs are updated to reflect actual selected tools.

## Source

- `docs/test.md`

## Implementation Status (2026-04-07)

**Status: NOT STARTED**

No Rswag, Playwright, Capybara, or k6 found. Existing stack includes simplecov, minitest-mock,
test-prof, prosopite, committee-rails, guard. No API contract testing, system tests, or performance
tooling set up.

## Improvement Points (2026-04-07 Review)

- Pick the concrete tools and first runnable path before adding more categories. The current note is
  still a target list, not a selected stack.
- Add one "done means done" matrix that names the baseline command for each layer so this plan can
  be closed incrementally instead of all at once.
