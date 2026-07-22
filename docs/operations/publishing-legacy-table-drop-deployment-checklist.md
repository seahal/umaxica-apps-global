# Publishing DB Cutover: Legacy Table DROP — Production Deployment Checklist

The legacy per-surface lean and CMS tables (app/com/org zenith databases) were
already dropped in development and test as part of the `publishing` DB cutover
(`plans/publishing-db-valiant-moore.md` Phase 7,
`memos/2026-07-16-publishing-db-migration-complete.md`). **The equivalent DROP has
not been run against any real production database and must not be, until every
item below is satisfied and explicitly approved.** This checklist exists so that
future production application of these migrations is a deliberate, gated action,
not an incidental side effect of a routine deploy.

## What Will Run

| Migration | Surface | Effect |
|---|---|---|
| `db/app_zenith_migrate/20260716200600_drop_publishing_migration_source_tables.rb` | app | Drops `docs_content_entries`, `news_content_entries`, `help_content_entries`, and the `app_{docs,news,info,help}_*` CMS table families |
| `db/com_zenith_migrate/20260716200601_drop_publishing_migration_source_tables.rb` | com | Same, `com_*` |
| `db/org_zenith_migrate/20260716200602_drop_publishing_migration_source_tables.rb` | org | Same, `org_*` |

All three call the shared migration-only `PublishingLegacyTableDrop` guard. The
guard fails before any DROP unless every expected table exists and every row
count is zero. In production it also requires the exact approval value documented
below. DROP runs in known foreign-key dependency order without `CASCADE`; an
unexpected dependency stops the migration instead of being deleted implicitly.

All three explicitly `raise ActiveRecord::IrreversibleMigration` on `down` —
there is no code-level rollback. Restoration after an incorrect run means
restoring from a database backup (see "Recovery Procedure" below), not reverting
the migration.

## Pre-Deployment Checklist

Work through every item in order. Do not proceed to the next item until the
current one is satisfied.

1. **Backup confirmation.** Confirm a recent, verified-restorable backup exists for
   every affected production database (app/com/org zenith) that predates this
   deploy. Record the backup identifier/timestamp here before proceeding.

2. **Row-count and dependency audit.** Run the existing read-only audit against
   production (read replica preferred if available):
   ```sh
   RAILS_ENV=production bin/rails publishing:migration:audit REPORT=tmp/publishing_migration_audit_prod.json
   ```
   This uses `PublishingMigrationAudit` (`app/services/publishing_migration_audit.rb`),
   which only issues `SELECT` statements — it never writes, migrates, or repairs
   anything. Confirm from the summary:
   - `lean_total_rows` — expected `0` (all legacy content already fully cut over to
     `publishing`).
   - `cms_total_rows` — expected `0`.
   - `surfaces_unreachable` — expected empty (every surface's database was
     reachable during the audit).
   If any count is non-zero, **stop**. Non-zero rows mean production has legacy
   content that never made it into `publishing`, and dropping these tables would be
   a genuine, unrecoverable-without-backup data loss. Investigate and re-run the
   audit before proceeding.

3. **Verify reads and writes have already cut over.** Confirm (via the delivery
   controllers under `app/controllers/{info,docs,news,help}/{app,com,org}/api/v0/`
   and `docs/architecture/docs-help-news-content-boundary.md`) that production
   traffic is being served exclusively from the `publishing` database, not from any
   legacy per-surface table. The legacy tables should already be write-dead by this
   point (Phase 7 removed the models, concerns, and feature-flag/shadow-read
   plumbing that could have written to them — see the completion memo).

4. **Explicit approval.** Record who approved this specific production run, when,
   and against which environment. This checklist itself is not the approval — a
   human must explicitly authorize execution against the real production database,
   per this repository's constraint that destructive database operations require
   the user's explicit approval of the risk and migration plan.

   After that approval is recorded, set the executable gate for the migration
   process only:
   ```sh
   export PUBLISHING_LEGACY_TABLE_DROP_APPROVAL='drop-empty-legacy-publishing-tables:production:app,com,org'
   ```
   A missing or different value stops a production migration before table
   inspection or DROP. The value is an accidental-execution guard; it does not
   replace the backup, audit, or human approval recorded in steps 1–4.

5. **Run the migrations** (only after 1–4 are all satisfied and approved):
   ```sh
   RAILS_ENV=production bin/rails db:migrate:app_zenith
   RAILS_ENV=production bin/rails db:migrate:com_zenith
   RAILS_ENV=production bin/rails db:migrate:org_zenith
   ```
   Each command rechecks that its surface's complete expected table set is present
   and empty. Any missing table, non-zero count, or unknown dependent object stops
   the migration. Unset `PUBLISHING_LEGACY_TABLE_DROP_APPROVAL` after the run.

6. **Post-migration validation.**
   - Re-run the audit; confirm `lean_tables` report `exists: false` and
     `cms_tables` report `tables_present: 0` for all three surfaces.
   - Run the application's health checks and a smoke pass over the four content
     surfaces (info/docs/news/help) across app/com/org.
   - Regenerate structure dumps for the three `*_zenith` connections (same
     procedure as the repository's Gate 0 — disposable-database rebuild, never a
     direct dump of a long-lived database) and commit them so the migration
     history and the checked-in schema stay consistent.

## Recovery Procedure

Because `down` is intentionally irreversible, recovery from an incorrect
production run means restoring the affected database(s) from the backup
confirmed in step 1, not running a migration rollback. After restoring:

1. Confirm via the audit task that the legacy tables are back and match the
   pre-drop row counts.
2. Investigate why step 2's audit did not catch the problem before the migration
   ran.
3. Do not re-attempt the DROP until the root cause is understood and this
   checklist is re-run from step 1.

## Status

**Not yet executed against any production database.** Development and test
execution is complete and verified (see
`memos/2026-07-16-publishing-db-migration-complete.md` and this repository's
`plans/project-umaxica-rails-mutable-duckling.md` Gate 0/Gate 5 records). This
checklist governs the separate, later, explicitly-approved production action.
