# Model Layer Reference Validation and Test Hardening

## Summary

Harden the Rails model layer so that invalid numeric foreign-key values are rejected by model
validation before they reach database foreign-key enforcement.

This work also expands model tests so that failure paths, branch behavior, boundary values, and
table/database consistency are covered with clear and stable test names.

The implementation is limited to model-layer validation and model tests. It does not include route,
controller, or full-suite repair outside this scope.

## Problem

The current model layer has several gaps:

- Some models rely on database foreign-key errors instead of model validation for numeric reference
  columns.
- Some bigint reference columns are validated as string length instead of integer existence.
- Existing model tests are biased toward success paths and do not consistently cover invalid values,
  optional-reference branches, or representative schema/database mappings.
- Test naming is inconsistent in a few touched areas and does not always describe the protected
  rule.

These gaps make failures harder to understand, reduce branch coverage, and allow invalid values to
travel too far before rejection.

## Goals

1. Reject invalid numeric reference values in the model layer with explicit validation errors.
2. Replace incorrect validations on numeric lookup columns with consistent reference validation.
3. Add regression tests that prove invalid values fail before database FK enforcement.
4. Improve branch coverage for touched model families.
5. Add representative tests for table-name and database-name consistency.

## Implementation Changes

### Phase 1: Shared numeric reference validation

- Add one shared concern for numeric reference validation on `belongs_to` associations backed by
  numeric IDs.
- The concern must:
  - validate integer shape first
  - validate referenced-row existence through the association model
  - support `allow_nil: true` for optional references
  - add model errors before persistence
- Do not use raw SQL, validation-skipping persistence, or exception-driven control flow for the
  normal validation path.

### Phase 2: Apply validation to high-risk model families

Apply the shared validation to representative model families that use numeric reference tables:

- identity and account models
  - `status_id`
  - `visibility_id`
- token and preference models
  - status reference
  - binding-method reference
  - DBSC-status reference
  - kind reference where the column is numeric
  - self-reference such as `replaced_by_id` where applicable
- occurrence models
  - `status_id`
- activity and behavior models
  - `event_id`
  - `level_id`
- scavenger models
  - `event_id`
  - `status_id`

Use existing association names as the source of truth. Do not add parallel validation-only lookup
rules.

### Phase 3: Replace incorrect validations

- Remove or replace validations that treat numeric FK columns as string-length fields.
- Keep non-reference validations unchanged unless a direct conflict exists.
- Ensure each numeric reference column has one clear validation path, not overlapping duplicate
  errors.

### Phase 4: Preserve architecture boundaries

- Respect multi-database model ownership and existing record base classes.
- Use model associations and configured record classes as the source of truth for database
  ownership.
- Do not change routes, controllers, migrations, schema files, or `.harnes/`.
- Do not repair unrelated route-helper or full-suite failures as part of this work.

## Test Plan

### 1. Add focused invalid-reference regression tests

Create or update model tests that verify the model is invalid, with explicit errors, when these
values are unknown:

- identity and account `status_id`
- identity `visibility_id`
- token and preference lookup IDs
- occurrence `status_id`
- activity and behavior `event_id`
- activity and behavior `level_id`
- scavenger `event_id`
- scavenger `status_id`

These tests must prove that the failure is detected by model validation before the database FK would
reject the write.

### 2. Expand branch-aware model tests

For touched models, ensure tests cover:

- success path with valid reference IDs
- failure path with non-existent reference IDs
- optional-reference branch when `allow_nil: true`
- boundary-value behavior where integer shape matters
- helper and association branch behavior already relied on by the model

Test names must describe the protected rule, not the incidental implementation detail.

### 3. Add representative schema-mapping tests

Add a compact test file that verifies representative models map to the expected:

- `table_name`
- `connection_db_config.name`

Cover at least one touched model from each relevant database family:

- principal or operator identity
- occurrence
- token
- activity
- behavior

### 4. Validation commands to run after implementation

Run and report:

- `bundle exec rubocop`
- `bundle exec erb_lint .`
- `vp check`
- `vp test`
- `bundle exec rails test`
- `bundle exec brakeman --no-pager`
- `bundle exec bundler-audit check --update`
- `vp pm audit`

If a command fails because of unrelated existing issues, separate:

- failures introduced by this work
- failures already present outside this scope

## Known Out-of-Scope Failures

The repository currently has unrelated failures outside this plan's scope. The implementation report
must not merge them into this work item.

Known examples include:

- route-helper and route-alias failures in controller and integration tests
- missing sign, docs, acme, and core route helpers in full `rails test`
- unrelated formatting drift in files outside the touched model/test scope
- existing package audit findings outside the model-layer changes

These must be reported as existing blockers, not fixed as part of this task unless the task is
explicitly expanded later.

## Acceptance Criteria

- [ ] Invalid numeric FK values are rejected by model validation before database FK enforcement.
- [ ] Touched models no longer validate numeric reference columns as string length.
- [ ] New and updated tests cover both success and failure branches for the protected behavior.
- [ ] Representative schema-mapping tests confirm table and database alignment.
- [ ] The implementation report separates scoped results from unrelated existing repository
      failures.

## Assumptions

- This work is active and intended for near-term implementation.
- Acceptance is based on the model-layer hardening and its regression tests, not on repairing the
  repository's broader route-helper failures.
- Existing unrelated full-suite failures remain documented as blockers outside this plan.
