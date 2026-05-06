# Database Consistency Repair Plan

## Summary

This plan defines the next pass for model and schema consistency repairs in the Rails app. It is
based on direct inspection of model code, schema files, and the current runtime output from
`database_consistency`.

The goal is to repair the confirmed violations first, keep the work small, and leave a clear audit
trail for follow-up fixes.

## Scope

In scope:

- model validations that do not match the current schema
- association declarations that do not match the current database contracts
- missing or redundant indexes where the code and schema clearly disagree
- missing foreign keys or delete actions where the model already declares a clear dependency rule
- missing `implicit_order_column` for UUID primary keys when the model relies on ordered queries
- missing model files or broken association targets that point to non-existent models

Out of scope for this pass:

- broad refactors that do not repair a confirmed inconsistency
- schema redesigns that require a new product decision
- database consistency checker internals
- unrelated application features

## Confirmed Findings

Treat these as confirmed and actionable:

- `ApplicationPushDevice` has no corresponding table.
- `UserPreference` has a `belongs_to :user` relationship without a database foreign key.
- `SettingPreference` has unique indexes on `dbsc_session_id` and `owner_type + owner_id` without
  matching uniqueness validations.
- `OrganizationInvitation.code` is limited in the database, but the model does not validate length.
- `AuthorizationCode.code`, `client_id`, and `code_challenge_method` are limited in the database,
  but the model does not validate length.
- `SettingPreferenceActivity.created_at` is `NOT NULL`, but the model does not validate presence.
- `HandleAssignment.valid_from` is `NOT NULL`, but the model does not validate presence.
- `AuditTimestamp.tsa_request` and `tsa_response` are `NOT NULL`, but the model does not validate
  presence.
- `AuditTimestamp.verification_status` is a nullable boolean and should be reviewed against the
  intended state model.
- `SearchBehavior.search` and `MessageBehavior.message` refer to non-existent models.
- `UserAppPreference` has a redundant non-unique index on `user_id`.
- `User.user_app_preferences` and `Staff.staff_org_preferences` depend on delete behavior in the
  model, but the database FK rules are not fully aligned with that intent.
- Document parent/version/revision associations in `AppDocument`, `ComDocument`, and `OrgDocument`
  need review against the actual FK delete actions.
- `AuditTimestamp` uses a UUID primary key without an explicit ordering column.

## Repair Strategy

### 1. Fix high-confidence model/schema mismatches first

- Add missing validations that are directly implied by the schema:
  - `presence`
  - `length`
  - `uniqueness`
- Add missing foreign keys only when the model already declares a stable `belongs_to` contract.
- Remove redundant indexes only when another existing index fully covers the same lookup path.
- Add `implicit_order_column` only when the model uses a UUID primary key and ordering is required
  by current query behavior.

### 2. Preserve existing behavior where the checker is noisy

Some checker findings are likely false positives or need manual confirmation:

- conditional uniqueness validations that are backed by partial unique indexes
- reverse cascade warnings on document version/revision relationships

Do not change these until the model and schema contract is confirmed by direct inspection.

### 3. Keep the smallest safe edit

- Prefer model validation fixes before schema edits when both can solve the same mismatch.
- When a schema edit is required, keep it narrow and reversible.
- Do not change unrelated concerns, callbacks, or naming just to satisfy the checker.

## Implementation Order

1. Add regression tests for the confirmed failures.
2. Fix model validations and broken associations.
3. Fix schema/index/FK mismatches that remain after the model changes.
4. Re-run the consistency check and the focused model test set.
5. Expand only the remaining confirmed findings into the next repair batch.

## Test Plan

Add or update tests that prove the repaired rules:

- invalid length values are rejected before persistence
- missing required references are rejected by model validation
- unique constraints are enforced at the model level where the schema already requires them
- broken associations fail fast in test coverage instead of only in runtime checker output
- UUID primary key ordering behavior is explicit where it matters

Use the existing model test style already used in this repository:

- clear behavior names
- boundary checks for validation rules
- deterministic fixtures or explicit record setup
- no hollow mocks for core domain behavior

## Validation Plan

Run the applicable checks after each repair batch:

- `bundle exec rails test`
- `bundle exec rubocop`
- `bundle exec erb_lint .` if views change
- `vp check` if JavaScript changes
- `bundle exec database_consistency` with the local Rails-compatible workaround if the stock command
  still fails on `ActiveRecord::Base.connection`

If a command fails because of an existing repository issue, record it separately from new failures.

## GitHub Issue Plan

Use GitHub issues only for confirmed, actionable repair groups.

Recommended grouping:

- one issue for model validation gaps
- one issue for association and foreign key mismatches
- one issue for index cleanup
- one issue for missing models or broken association targets
- one issue for UUID ordering and table-level edge cases

If a later batch reveals a single isolated problem, keep it as a separate issue instead of merging
it into a larger theme.

## Acceptance Criteria

- confirmed violations are repaired or explicitly deferred with a reason
- model tests cover the repaired behavior
- `database_consistency` no longer reports the repaired items
- the plan remains small enough for incremental implementation
- no unrelated schema or routing changes are introduced

## Assumptions

- The current runtime checker output is the main evidence source for this pass.
- Checker warnings that conflict with direct schema/model inspection are deferred until manually
  confirmed.
- The next implementer will keep the repair scope narrow and will not use this plan to start a broad
  schema redesign.
