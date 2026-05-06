# GH-616: Remove Remaining any_instance.stub Usage

GitHub: #616

## Summary

Remove remaining controller-level `any_instance.stub` usage from authentication and verification
tests, and replace with deterministic alternatives.

## Scope

- Replace time-based `any_instance.stub` with `freeze_time` / `travel_to`.
- Replace verification-flow controller stubs with service injection or real request flows.
- Replace login-result controller stubs with invalid input cases or service mocks.
- Replace registration-session controller stubs with real session setup through requests.

## Target Groups

- Refresh token expiry tests.
- Verification and step-up tests.
- Login and authentication result tests.
- Telephone registration tests.
- Remaining individual controller cases called out in the migration plan.

## Acceptance Criteria

- Targeted controller test files no longer rely on `any_instance.stub`.
- Replacement tests remain deterministic and readable.
- Coverage is preserved or improved for refresh, verification, login, and registration flows.
- CI remains green without a major runtime regression.

## Out of Scope

- Broad service-layer redesign unrelated to test cleanup.
- Private-method testing through `send`.
- Replacing one brittle controller stub pattern with another.

## Source

- `plans/active/any-instance-stub-removal-plan.md`

## Implementation Status (2026-04-07)

**Status: NEARLY COMPLETE**

Grep for `any_instance` in test/ returns 0 matches. `freeze_time`/`travel_to` included in
test_helper.rb. Plan notes a few remaining cases in verification integration tests and acme cookie
controller test may still need addressing.

## Improvement Points (2026-04-07 Review)

- This issue is still open in the codebase. Remaining `any_instance.stub` usage exists in multiple
  verification integration tests and in the acme cookie controller test.
- Narrow the finish line to the still-open files only. The broad source plan is useful context, but
  this issue now needs a short "remaining cases" list.
