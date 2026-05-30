# Actor Model And Table Cleanup

## Status

Backlog.

## Context

The accepted runtime actor names are `Client` for `app`, `Visitor` for `com`, and `Operator` for
`org`. Current ADRs and docs also prefer Rails-conventional model/table naming instead of preserving
old `User`, `Staff`, or `Customer` vocabulary in new runtime code.

The current tree still has substantial compatibility residue:

- app actor-owned models often expose `user` associations and `user_id` columns while pointing to
  `Client`;
- org actor-owned models often expose `staff` associations and `staff_id` columns while pointing to
  `Operator`;
- some `class_name`, `foreign_key`, and `inverse_of` declarations exist only to compensate for
  non-conventional association names;
- com/visitor models are closer to the target shape and should be treated as the control group
  during cleanup.

This cleanup should happen separately from feature work such as welcome/banner behavior changes.

## Goals

- Make actor-owned model APIs read as `client`, `visitor`, and `operator` unless a different domain
  concept is intentional.
- Rename actor-owned foreign keys and indexes to match those APIs: `client_id`, `visitor_id`, and
  `operator_id`.
- Remove redundant `class_name`, `foreign_key`, and compatibility association declarations once
  Rails conventions can infer them.
- Keep `app`, `com`, and `org` surface boundaries separate throughout the migration.

## Cleanup Plan

1. Build an inventory matrix before changing code.
   - Classify every `user_id`, `staff_id`, `belongs_to :user`, `belongs_to :staff`,
     `has_many :staff_*`, and matching fixture/test reference.
   - Mark each item as actor-owned residue, intentional non-actor domain language, or framework
     vocabulary that must remain, such as Action Policy's `user` context key.
   - Do not rename ambiguous records until the classification is written down.

2. Clean the app/Client actor family.
   - Rename actor-owned `user_id` columns to `client_id` in app-principal, app-ticket, app-signal,
     and related app-owned tables where the referenced row is `clients.id`.
   - Rename model associations from `user` to `client` and collection names from `users` to
     `clients` where they represent authenticated app actors.
   - Remove `class_name: "Client"` and `foreign_key: :user_id` once the association and column names
     are conventional.
   - Update fixtures, tests, policies, authentication helpers, and service objects to use
     `client_id`/`client` except where a source-of-truth ADR explicitly keeps `user`.

3. Clean the org/Operator actor family.
   - Rename actor-owned `staff_id` columns to `operator_id` where the referenced row is
     `operators.id`.
   - Rename associations from `staff`/`staff_*` to `operator`/`operator_*` when they refer to the
     authenticated org actor.
   - Keep separate account/workspace concepts explicit; do not collapse `Operator`,
     `OperatorAccount`, and `OperatorWorkspaceAccount`.
   - Remove redundant `class_name: "Operator"` and `foreign_key: :staff_id` after conventional names
     land.

4. Verify the com/Visitor family and avoid unnecessary churn.
   - Confirm `visitor_id`/`visitor` associations are already conventional for actor-owned models.
   - Only remove redundant declarations that are clearly unnecessary.
   - Do not rename RP-side `VisitorAccount`/identity concepts unless a separate ADR or plan requires
     it.

5. Migrate safely by database boundary.
   - Use one reversible migration set per affected database.
   - Use `rename_table_strict` for table renames and reversible `rename_column` operations for
     column renames.
   - Rename or recreate indexes and foreign keys so schema dumps no longer contain stale
     `user_*`/`staff_*` names for actor-owned records.
   - Keep schema changes separate from any data backfills.
   - During rename work, reset local dev/test DBs from schema with `bin/db-reset-all` and run
     `bin/rails db:verify_no_schema_drift` before handoff.

6. Remove compatibility code after tests pass.
   - Do not keep long-lived aliases such as `user`, `staff`, `staff_tokens`, or `user_status` for
     actor-owned models solely for compatibility.
   - If a short-lived alias is needed inside a single PR to keep a migration mechanical, remove it
     before the phase is complete.
   - Update docs/architecture/actor-naming.md after the cleanup is implemented.

## Test Plan

- Run focused model tests for every renamed model family.
- Run authentication, authorization, sign-in, sign-up, logout, withdrawal, preference, token, and
  banner tests for the affected surfaces.
- Run fixture load/model-load coverage after each database slice.
- Run `bin/rails test` after each surface-family phase and before merging the final cleanup.
- For database rename phases, run `bin/rails db:verify_no_schema_drift`.

## Assumptions

- This is a breaking internal cleanup and should not be combined with welcome/banner feature work.
- Runtime actor names remain `Client`, `Visitor`, and `Operator`.
- Action Policy's authorization context key may remain `:user`; that framework vocabulary is not an
  app actor API.
- Historical migration filenames may keep old words, but current models, schema dumps, fixtures,
  tests, docs, and new migrations should use the cleaned vocabulary.
