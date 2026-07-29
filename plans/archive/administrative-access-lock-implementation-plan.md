# Administrative Access Lock Implementation Plan

> **Superseded by GitHub issue #830 (2026-07-29):** This plan is deactivated. The GitHub issue is
> authoritative for current status and scope. This file is retained under `plans/archive/` for
> historical context only.

## Summary

Implement service-only Administrative Access Lock for `Client`, `Visitor`, and `Operator`.

This plan intentionally changes only account access state and enforcement. It does not implement
normal inactivity dormancy, UI, routes, or controllers.

## Current Status

Implemented in the working tree on 2026-06-14:

- principal-table migrations for `clients`, `visitors`, and `operators`;
- chronicle-table migration and `AccountAccessEvent` model;
- shared `AdministrativeAccessLockable` concern for the three principal actors;
- `AdministrativeAccessLock` service with lock, unlock, session revocation, audit event recording,
  repeated-lock event classification, and last-enabled-operator protection;
- current-resource, OIDC access-token, sign-in, and refresh access checks for administratively
  locked actors and stale access-token `iat` values;
- focused model, service, resolver, OIDC, and authentication-base coverage.

Verification is still blocked in this checkout. `RAILS_ENV=test bin/rails db:prepare` fails because
the test database host `primary` is not resolvable from this shell, and overriding
`POSTGRESQL_TEST_HOST=localhost` cannot connect to a local PostgreSQL listener. Focused admin-lock
tests that reached Rails used stale parallel test database clones and failed before assertions with
missing tables such as `app_preference_binding_methods` and `clients`. The structure dumps have not
been regenerated from a live database in this change.

## Key Changes

- Add non-destructive schema to the `clients`, `visitors`, and `operators` principal tables:
  - `access_state`, default `"enabled"`, not null
  - `admin_locked_at`
  - `admin_locked_by_operator_id`
  - `admin_locked_reason_code`
  - `admin_locked_reason_note`
  - `token_valid_after_at`
  - `reactivated_at`
- Add indexes for operational lookup:
  - `access_state`
  - partial `admin_locked_at` where present
  - partial `token_valid_after_at` where present
- Add a durable audit table, tentatively `account_access_events`, in the audit/chronicle boundary:
  - `account_type`
  - `account_id`
  - `event_type`
  - `previous_access_state`
  - `next_access_state`
  - `operator_id`
  - `reason_code`
  - `reason_note`
  - `ticket_id`
  - `occurred_at`
  - `metadata`
- Do not use Rails `enum`. Use explicit constants, validations, and predicate methods.

## Implementation

- Add a shared account-access concern for `Client`, `Visitor`, and `Operator`:
  - states: `enabled`, `admin_locked`
  - predicates: `access_enabled?`, `admin_locked?`, `access_locked?`
  - reason-code validation for lock metadata
- Add `AccountAccess::AdministrativeAccessLock` service:
  - `lock!(account:, operator:, reason_code:, reason_note: nil, ticket_id: nil, metadata: {})`
  - `unlock!(account:, operator:, reason_code:, reason_note: nil, ticket_id: nil, metadata: {})`
  - `lock!` sets `access_state: "admin_locked"`, lock metadata, and `token_valid_after_at`.
  - `unlock!` sets `access_state: "enabled"`, clears lock metadata, sets `reactivated_at`, and
    advances `token_valid_after_at`.
  - repeated lock is safe and records `admin_lock_reaffirmed`.
  - operator targets must pass a last-enabled-operator safety check.
- Revoke active sessions through the existing session-revoke composition boundary. Do not introduce
  a parallel token mutation path.
- Enforce account access in the state-backed authentication paths:
  - sign-in: reject after credential verification and before session creation;
  - refresh: reject locked accounts and do not issue replacement access tokens;
  - `Authentication::CurrentResourceResolver`: reject locked resources and stale JWT `iat`;
  - `Oidc::AccessTokenAuthenticator`: apply the same locked/stale checks for downstream/OIDC access.
- Keep lifecycle `active?` / withdrawal methods separate from access-state methods. Do not fold
  `admin_locked` into withdrawal `active?`.

## Test Plan

- Model tests for all actor types:
  - default `enabled`;
  - `admin_locked?` and `access_enabled?`;
  - invalid access state rejected;
  - invalid reason code rejected.
- Service tests:
  - lock updates account state, lock metadata, `token_valid_after_at`, and audit event;
  - lock revokes all existing sessions for Client, Visitor, and Operator;
  - repeated lock remains safe and records a reaffirmed event;
  - unlock enables future access but does not make old tokens valid;
  - locking the last enabled Operator is rejected.
- Authentication tests:
  - correct credentials for a locked account do not create a session;
  - refresh for a locked account fails and does not issue a new access token;
  - access JWT issued before `token_valid_after_at` is rejected;
  - OIDC/userinfo access is rejected for locked or stale accounts;
  - at least one credential-mutation or step-up path proves locked accounts cannot proceed.

## Verification Commands

Run focused tests first:

```bash
bin/rails test test/models/administrative_access_lockable_test.rb
bin/rails test test/services/administrative_access_lock_test.rb
bin/rails test test/controllers/concerns/authentication/current_resource_resolver_test.rb
bin/rails test test/controllers/concerns/authentication/base_coverage_test.rb
bin/rails test test/services/oidc_access_token_authenticator_coverage_test.rb
```

Run broader authentication/security coverage if shared auth helpers or token validation behavior
changes:

```bash
bin/rails test test/controllers/concerns/authentication
bin/rails test test/security
bin/rails test test/integration
```

## Assumptions

- No UI, controller, or route is part of the first implementation slice.
- `dormant` remains out of scope.
- `admin_locked` is stronger than withdrawal/suspended gates and is checked independently.
- `reason_note` is never used for branching logic.
- Existing comments that describe `deactivated_at` as operator-driven suspension should be clarified
  when implementation lands, because `admin_locked` becomes the explicit forced access-removal
  state.
