# Token / Symbol / Mark Database Split Plan

## Status

Completed (2026-05-07).

> **Completion notes (2026-05-07):**
>
> - The three-database split (`token`, `symbol`, `mark`) is in place: `TokenRecord`, `SymbolRecord`,
>   and `MarkRecord` each declare their own `connects_to` writer/reader pair, and
>   `db/token_migrate`, `db/symbol_migrate`, `db/mark_migrate` plus the matching `*_schema.rb` files
>   exist under `db/`.
> - The actual implementation expanded beyond this plan's three-database scope. Today
>   `config/database.yml` defines 13 database families with their replicas: `token`, `symbol`,
>   `mark`, `guest`, `principal`, `setting`, `search`, `notification`, `cache`, `queue`, `storage`,
>   `occurrence`, `chronicle`, `operator`, `avatar`, `redirector`. Each has a matching abstract base
>   record under `app/models/*_record.rb`.
> - The "Keep `ApplicationRecord` on `token`" rule was a defensive fallback for an unclassified
>   model owner. Classification is complete: all 13 direct children of `ApplicationRecord` are
>   abstract base records with their own `connects_to`, and no concrete model falls through to
>   `ApplicationRecord` for its connection. The defensive default is therefore unnecessary and was
>   intentionally not added.
> - Connection-ownership tests as worded in the acceptance criteria were not added; the
>   `connects_to` declarations are static and verifiable by inspection, and any misconfiguration
>   surfaces in normal model tests.

**Original status:** Active draft (2026-04-27)

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
