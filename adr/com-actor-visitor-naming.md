# Com Actor Uses Visitor Naming

**Status:** Accepted (2026-05-13)

## Context

The `com` surface historically used `Customer` as its authenticated actor name. That name overlaps
with policy concepts during the Action Policy rollout and makes actor/policy lookup ambiguous.

The repository also has visitor-database client/account records. Those models are client-side
visitor records, not the authenticated `com` actor.

## Decision

The authenticated `com` actor is named `Visitor`.

- `Visitor < ComPrincipalRecord` owns the former customer account and credential tables.
- Visitor tokens, verification, step*up, preferences, and occurrences use `visitor*\*` names.
- `VisitorIdentity < ComRpRecord` remains a separate RP-side visitor identity binding record backed
  by the `visitor_identities` table.
- No `Customer` compatibility constants, helpers, params, or policy names are retained.

## Consequences

- `sign/com` uses `current_visitor`, `authenticate_visitor!`, and `VisitorPolicy`.
- Database tables and foreign keys use `visitor_*` names.
- Historical migration filenames may still mention customer, but current runtime code, schema, and
  tests use visitor naming.
