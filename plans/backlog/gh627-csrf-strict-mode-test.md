# GH-627: Revisit CSRF Strict Mode in Test Environment

GitHub: #627

## Background

CSRF strict mode (`config.action_controller.allow_forgery_protection = true`) was rolled back in the
test environment. Enabling it caused a large test impact because many existing controller and
integration tests do not provide CSRF tokens. Failures were dominated by
`ActionController::InvalidCrossOriginRequest` and `422 Unprocessable Content`.

This is a test-suite readiness problem, not a product bug.

## Scope

- Audit all state-changing controller and integration tests.
- Add shared helpers for CSRF token setup in tests.
- Migrate tests in batches by surface and domain.
- Re-enable CSRF protection in `test` only after the suite is ready.

## Notes

Other strict settings remain in place. This is a dedicated hardening task.

## Implementation Status (2026-04-07)

**Status: PARTIALLY DONE**

`allow_forgery_protection` is false by default in tests. A `with_forgery_protection` helper exists
for per-test enablement. Global strict mode is not yet enabled.

## Improvement Points (2026-04-07 Review)

- Start with a failure inventory that counts which test files break under strict mode. Without that,
  the migration order is guesswork.
- Add one shared helper for CSRF setup before migrating individual suites. The plan should optimize
  for repeatability, not one-off fixes.
