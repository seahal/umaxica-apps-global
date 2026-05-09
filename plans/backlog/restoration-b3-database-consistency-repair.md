# Restoration B3: Database Consistency Repair

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/database-consistency-repair-plan.md`

## Goal

Apply the consistency fixes — partial indexes, NOT-NULL constraints, CHECK constraints, FK indexes —
that the ADR enumerates.

## Key surface

Migrations under `db/migrate/`. Schema dump.

## Verification

`bundle exec rails db:migrate` runs cleanly forward and backward. Each new constraint has a
model-level validation that mirrors it (so violations are caught before the DB raises).

## Related

- `plans/backlog/database-improvements.md` — broader DB improvements list (overlapping).
- `plans/backlog/gh586-lifecycle-columns-and-partitioning.md` — GH-586 lifecycle columns and
  partitioning.
