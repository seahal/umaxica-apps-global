# Task: Write Minitest

## Purpose

Write Minitest that verifies real application behavior.

Tests are required for all meaningful changes. A change without adequate tests is incomplete.

---

## Core Rules

You MUST:

- use Minitest, not RSpec
- follow existing project test structure and naming
- test behavior, not implementation trivia
- cover both success and failure paths
- include authorization and authentication cases when relevant
- include edge cases when input validation, routing, cookies, sessions, tokens, or policies are
  involved

You MUST NOT:

- write placeholder tests
- write meaningless assertions
- skip tests to make the suite pass
- mock the code under test so heavily that the test no longer verifies behavior
- add tests that merely restate implementation details without validating outcomes
- edit `test_helper.rb` while implementing or editing tests; treat global test helper changes as
  forbidden unless the user explicitly requests test infrastructure work

---

## Required Coverage

For any non-trivial change, tests MUST cover all relevant cases below.

### 1. Success path

Verify the intended behavior works.

Examples:

- valid request returns expected status
- record is created or updated correctly
- response body contains expected data
- redirect goes to the expected internal path

### 2. Failure path

Verify invalid or rejected behavior fails safely.

Examples:

- invalid params return expected error or render expected response
- unauthorized access is denied
- unauthenticated access is redirected or rejected
- forbidden operation does not mutate state

### 3. Authorization

When controller, policy, role, or staff/user context is involved, test authorization explicitly.

Examples:

- authorized actor can access action
- unauthorized actor is denied
- wrong surface or wrong role is rejected

### 4. Edge cases

Add edge-case coverage when behavior depends on:

- empty values
- nil values
- invalid format
- expired token
- wrong host
- wrong route
- missing cookie
- restricted session
- verification not completed
- already-existing record
- idempotent re-entry

---

## Test Design Rules

Apply the shared test code principles in `.harnes/policies/testing_rules.md` when writing or
updating Minitest. In particular, prefer locally readable tests over clever shared abstractions,
keep business setup visible, and make each test fail for one clear behavioral reason.

### Prefer request/integration tests for controller behavior

When testing controllers or endpoints, prefer request-level or integration-style tests that verify:

- status code
- redirect
- response body
- assigned state visible through behavior
- persisted data changes

Do not primarily test controller internals.

### Test observable outcomes

Assert on:

- HTTP status
- redirect target
- rendered response
- database changes
- cookies set or cleared
- headers when relevant
- policy result through behavior

Avoid asserting on:

- private methods
- internal temporary variables
- incidental implementation details

### Keep tests deterministic

Tests MUST:

- be order-independent
- not rely on wall-clock timing unless time is explicitly controlled
- not depend on external network access
- not depend on leaked global state
- cleanly isolate setup and assertions

---

## Preferred Structure

Use clear arrange / act / assert flow.

Example:

```ruby
test "creates session for valid credentials" do
  # arrange
  user = users(:one)

  # act
  post sign_in_path, params: { email: user.email, password: "secret" }

  # assert
  assert_response :redirect
  assert_redirected_to dashboard_path
end
```
