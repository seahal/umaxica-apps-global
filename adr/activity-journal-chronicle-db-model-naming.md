# Activity, Journal, and Chronicle Naming

Status: superseded by `chronicle-audit-db-consolidation.md`

Superseded on: 2026-04-23

## Context

The repository uses Rails engine names to define routing, host labels, and responsibility
boundaries. Those names already have deployment meaning:

- `Identity`
- `Global`
- `Regional`

At the same time, the persistence layer needs different names for the new database families and the
model classes that sit on top of them.

## Decision

This ADR is kept for history only.

Keep the Rails engine names as `Identity`, `Global`, and `Regional`.

Use `Activity`, `Journal`, and `Chronicle` for the new database and model naming family.

Recommended mapping:

- `Activity` for identity and audit evidence
- `Journal` for shared global history and summary records
- `Chronicle` for regional detailed records

## Consequences

- Route and host documentation keeps the engine names unchanged.
- Database ownership documentation uses `Activity`, `Journal`, and `Chronicle`.
- Model names should follow the database family names when new models are introduced.
- Future persistence changes can evolve without forcing another engine rename.
- Reviewers should treat engine naming and data naming as separate concerns.

## Superseded Reason

The repository no longer treats `Activity`, `Journal`, and `Chronicle` as the active naming split
for audit-style persistence.

After the engine migration was abandoned in favor of independent Rails applications, the accepted
direction changed to:

- use one audit-domain name: `Chronicle`
- consolidate former `activity` and `behavior` families into one chronicle domain
- keep `occurrence` separate because it is not an audit-history concern

See `chronicle-audit-db-consolidation.md` for the accepted replacement decision.

## Notes

- Existing code and documentation that talk about engine boundaries should keep using `Identity`,
  `Global`, and `Regional`.
- New tables, base records, and model families should use the `Activity`, `Journal`, and `Chronicle`
  naming axis.
