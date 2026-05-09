# Restoration B5: Chronicle Audit DB Consolidation

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/chronicle-audit-db-consolidation.md`
- `adr/activity-journal-chronicle-db-model-naming.md`

## Goal

Consolidate audit / log persistence into the Chronicle DB with the agreed naming. Audit emission
paths use `chronicle` connection.

## Key surface

`database.yml`, audit emitter service, audit models, migrations under `db/chronicle_migrate/` (or
whichever path the ADR settles on for the single-app layout).

## Verification

Audit emission test that writes to chronicle and reads back. Confirm the primary DB does not gain
audit tables.

## Adaptation notes

This was originally written assuming 4 apps each with their own DBs. In the single-app world there
is just `primary` and `chronicle` (and any others the consolidation ADR specifies). Drop per-app
cache / queue DB language; it is replaced by C-section work.

## Related

- `plans/backlog/audit-log-write-points-and-otel-mapping.md` — audit emission points and OTEL
  mapping (overlapping scope).
