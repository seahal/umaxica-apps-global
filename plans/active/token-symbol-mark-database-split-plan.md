# Token / Symbol / Mark Database Split Plan

## Status

Active draft (2026-04-27)

## Summary

Split the current single application database configuration into three model-owned databases:
`token`, `symbol`, and `mark`. This is an intentionally breaking change. The target is to stop token
changes from sharing persistence scope with symbol and mark models, and to make each model family
own its database connection explicitly.

The repository currently contains `config/database.yml`; use that file unless the application later
renames it to `config/database.yaml`.

## Target Database Layout

- `token`: primary/default database for token models and any unclassified models.
- `symbol`: database for symbol model families.
- `mark`: database for mark model families.
- Test database names use the `_test` suffix: `token_test`, `symbol_test`, and `mark_test`.
- Migration paths are split by owner:
  - `db/token_migrate`
  - `db/symbol_migrate`
  - `db/mark_migrate`

## Model Ownership Rules

- Add three abstract base records:
  - `TokenRecord`, connected to `token`
  - `SymbolRecord`, connected to `symbol`
  - `MarkRecord`, connected to `mark`
- Keep `ApplicationRecord` on `token` so unclassified models have a deterministic owner.
- Move model inheritance by name convention first:
  - `Token*` models inherit from `TokenRecord`
  - `Symbol*` models inherit from `SymbolRecord`
  - `Mark*` models inherit from `MarkRecord`
- If a model does not match those prefixes, leave it on `ApplicationRecord` unless a later audit
  identifies a stronger owner.

## Migration Approach

- Move token-related tables and migrations to `db/token_migrate`.
- Move symbol-related tables and migrations to `db/symbol_migrate`.
- Move mark-related tables and migrations to `db/mark_migrate`.
- Move unclassified tables and migrations to `db/token_migrate`.
- Do not add compatibility fallbacks to the old single database.
- Do not include production data backfill in this change. Rebuild or reload data separately after
  the split.

## Acceptance Criteria

- `bin/rails db:drop db:create db:migrate RAILS_ENV=test` can create and migrate all three test
  databases.
- Representative token, symbol, and mark models write to their own database connection.
- An unclassified model writes to `token`.
- Tests cover connection ownership for all three abstract base records.
- Existing token, symbol, and mark tests no longer assume that every table is reachable from one
  shared connection.

## Related Decision

- `adr/token-symbol-mark-database-boundary.md`
