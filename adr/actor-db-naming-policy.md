# Actor Database Names Avoid Runtime Actor Names

**Status:** Accepted (2026-05-17)

## Context

The authenticated runtime actor names are `Client`, `Operator`, and `Visitor`. Those names are
useful in Ruby code, controller helpers, policy names, and token actor claims, but reusing the same
words as physical database names creates a different risk:

- `Client` already collides with older `client_*` storage concepts that do not mean the app actor.
- `Operator` and `Visitor` are actor model names, not storage-domain names.
- Historical `user_*`, `staff_*`, and `customer_*` table names carry old runtime actor language.
- Action Policy and authorization code are sensitive to ambiguous actor vocabulary.

The next database cleanup should therefore avoid both the old actor names and the current runtime
actor model names.

## Decision

Actor-owned database names will be redesigned as a separate storage vocabulary instead of mirroring
runtime actor model names.

- Physical table and column names must not use `user`, `staff`, or `customer` for authenticated
  actor ownership.
- Physical table and column names must not simply reuse `client`, `operator`, or `visitor` as the
  actor storage vocabulary.
- Existing ambiguous `client_*` storage names must be reconsidered because they collide with the
  `Client` runtime actor name.
- No compatibility database names, runtime constants, helpers, params, policies, or actor-type
  claims are retained solely to preserve the old `User`, `Staff`, or `Customer` vocabulary.
- The rename is intended as a breaking cleanup performed in one coordinated implementation.
- The preferred migration mechanism is reversible `rename_table` and `rename_column` operations,
  with foreign keys and indexes renamed or recreated as needed.

## Follow-up Decision

This ADR intentionally did not choose the final storage vocabulary for each actor boundary.
`adr/surface-database-connection-naming.md` later accepted the database connection vocabulary for
surface-owned databases.

This ADR still does not provide a full table-by-table rename matrix for credentials, tickets,
preferences, occurrences, chronicles, signal records, fixtures, or schema dumps. That matrix belongs
in the implementation plan that follows the connection-name decision.

## Consequences

- Runtime actor names and database storage names intentionally diverge.
- Future database rename work must first choose a collision-free storage vocabulary.
- Plans that rename `users` directly to `clients`, `staff_*` directly to `operator_*`, or
  `visitor_*` as a blanket rule conflict with this ADR.
- Existing runtime naming ADRs remain valid for Ruby/API boundaries, but their storage-compatibility
  notes are superseded where they imply retaining old database vocabulary indefinitely.

## Related

- `adr/app-actor-client-naming.md`
- `adr/org-actor-operator-naming.md`
- `adr/com-actor-visitor-naming.md`
- `adr/surface-database-connection-naming.md`
- `adr/pundit-to-action-policy-migration.md`
