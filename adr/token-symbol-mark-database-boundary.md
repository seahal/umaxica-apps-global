# Token / Symbol / Mark Database Boundary

**Status:** Accepted (2026-04-27)

## Context

The application has been operating with one shared database configuration for token, symbol, mark,
and unclassified models. That makes persistence changes too broad: a migration, connection issue, or
test setup problem in one model family can affect unrelated model families.

The requested direction is a breaking split from one database to three databases, with model
ownership as the boundary. The repository currently uses `config/database.yml`; that file remains
the configuration target unless the application is renamed to `config/database.yaml` later.

## Decision

Use three database connections named `token`, `symbol`, and `mark`.

- `token` is the default owner and holds token models plus unclassified models.
- `symbol` holds symbol model families.
- `mark` holds mark model families.
- Model ownership is expressed through three abstract base records: `OrgTicketRecord`,
  `ComTicketRecord`, and `AppTicketRecord`.
- `OrgTicketRecord`, `ComTicketRecord`, and `AppTicketRecord` inherit directly from
  `ApplicationRecord`; they do not inherit from each other. Shared behavior belongs in concerns, not
  in another database base record.
- Each base record declares a stable writer/reader pair, including test: for example
  `connects_to database: { writing: :token, reading: :token_replica }`. Test code should use test
  database configuration aliases for replicas instead of changing the model inheritance or
  `connects_to` declaration by environment.
- Initial model migration follows naming convention: `Token*`, `Symbol*`, and `Mark*`.
- Test databases use `token_test`, `symbol_test`, and `mark_test`.
- Migration paths are split into `db/token_migrate`, `db/symbol_migrate`, and `db/mark_migrate`.

## Rationale

Model-family ownership is the clearest boundary for this change. It prevents token persistence work
from implicitly changing symbol or mark behavior, while keeping the calling code simple: each model
declares its database through inheritance instead of choosing a connection dynamically.

Keeping the three base records as siblings makes the persistence boundary visible in class
hierarchy. Token-like common behavior, such as JSON sanitization of refresh-token fields, is shared
through concerns so it does not imply database ownership.

Keeping unclassified models on `token` gives the system a deterministic default during the breaking
transition. This is safer than leaving ownership ambiguous or distributing models mechanically
across databases without a domain reason.

The plan intentionally avoids compatibility fallbacks and production backfill. The change is meant
to reset the database boundary, not preserve the old single-database runtime contract.

## Consequences

- Existing migrations must be sorted into owner-specific migration paths.
- Tests and fixtures that assume one shared database will need to be updated.
- Cross-database foreign keys should be avoided; relationships that cross `token`, `symbol`, and
  `mark` need application-level coordination or explicit service boundaries.
- Connection-sensitive shared code must resolve the concrete model's connection owner instead of
  wrapping all token-like models in `OrgTicketRecord.connected_to`.
- Operational tasks must create, migrate, reset, and back up three databases instead of one.

## Alternatives Considered

- Keep one database and add table namespaces: rejected because connection, migration, and test
  failures would still share the same persistence scope.
- Split by tenant or TLD: rejected because the requested boundary is model ownership, not runtime
  routing.
- Use dynamic connection selection in each model: rejected because abstract base records make
  ownership easier to audit and harder to bypass accidentally.
