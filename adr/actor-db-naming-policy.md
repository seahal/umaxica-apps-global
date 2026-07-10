# Actor Database Names Follow Rails Model Conventions

**Status:** Supersedes previous policy (2026-05-20)

## Context

The authenticated runtime actor names are `Client`, `Operator`, and `Visitor`. A previous policy
kept runtime actor names and physical table names separate to avoid ambiguous actor vocabulary.

That separation required widespread `self.table_name` overrides and made model/table ownership hard
to inspect. The current cleanup prioritizes Rails conventions: model names and table names should
match without explicit table-name overrides.

## Decision

Actor-owned table names follow Rails model conventions.

- Models should not define `self.table_name` solely to preserve historical `user_*`, `staff_*`, or
  `customer_*` storage names.
- Physical table names may use `client`, `operator`, and `visitor` when those names are the
  conventional table names for the runtime actor models.
- No compatibility database names, runtime constants, helpers, params, policies, or actor-type
  claims are retained solely to preserve the old `User`, `Staff`, or `Customer` vocabulary.
- The rename is intended as a breaking cleanup performed in one coordinated implementation.
- The preferred migration mechanism is reversible `rename_table` and `rename_column` operations,
  with foreign keys and indexes renamed or recreated as needed.

## Follow-up Decision

The table-by-table rename matrix lives in the model-convention migration set created for this
cleanup. Database connection names remain governed by `adr/surface-database-connection-naming.md`.

## Consequences

- Runtime actor names and table names intentionally align where Rails conventions call for it.
- Future model additions should use conventional table names instead of adding table-name
  compatibility overrides.
- Existing ambiguous storage concepts must be disambiguated by model naming, not by preserving
  historical actor table prefixes.
- Existing runtime naming ADRs remain valid for Ruby/API boundaries, but their storage-compatibility
  notes are superseded where they imply retaining old database vocabulary indefinitely.

## Related

- `adr/app-actor-client-naming.md`
- `adr/org-actor-operator-naming.md`
- `adr/com-actor-visitor-naming.md`
- `adr/surface-database-connection-naming.md`
- `adr/pundit-to-action-policy-migration.md`
