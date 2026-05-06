# GH-628: Move Session-Like Preferences to Setting Database

GitHub: #628

## Summary

Move session-like preference storage out of current domain databases into a new dedicated `setting`
database.

## In Scope

- Add a new `setting` database and abstract record.
- Move `AppPreference`, `ComPreference`, `OrgPreference` families into `setting`.
- Retire `commerce` as a preference store after `ComPreference` is moved.
- Keep preference activity tables in `activity`.
- Keep `UserPreference`, `StaffPreference`, `CustomerPreference` in their current databases.
- Keep dual-write behavior while logged in.
- Keep `user_app_preferences` and `staff_org_preferences` where they are now.

## Out of Scope

- Changing the merge algorithm used during re-login (GH-629).
- Moving actor-owned preference tables into `setting`.
- Redesigning preference activity storage.

## Motivation

Preference-token data is split across `principal`, `commerce`, and `operator` databases. A dedicated
`setting` database gives this domain a clearer boundary.

## Implementation Status (2026-04-10)

**Status: RUNTIME CUTOVER DONE**

- `setting` database defined in `config/database.yml` with full read/write and replica
  configuration.
- Migrations path: `db/settings_migrate` with unified preferences schema.
- `Preference::StorageAdapter` implements dual-read and dual-write.
- `Preference::Adoption` implements sync recovery to local layer.
- `Preference::Core` includes ComPreference recovery to CustomerPreference.
- Legacy tables remain for rollback safety (removal is future work).

## Delivery Status Review (2026-04-10)

Implementation is partially complete.

Current delivery judgment:

- Schema foundation: done
- Database wiring: done
- Runtime model cutover: done (via Preference::StorageAdapter)
- Read-path cutover: done (dual-read with fallback)
- Write-path cutover: done (dual-write to setting + legacy)
- Sync recovery: done (surface-specific local layer recovery)
- Legacy store retirement: not done (intentionally deferred)

Recommended status label:

`In Progress: runtime cutover done, legacy retirement pending`

## Current Repo Findings (2026-04-10)

The target schema exists and runtime cutover is implemented.

- `SettingRecord` exists and points to the global `setting` database.
- `db/settings_migrate/20260407000001_create_unified_preferences_in_setting_db.rb` created the
  unified `settings_preferences` family.
- `db/setting_schema.rb` includes `settings_preferences`, option tables, cookie tables, and
  `settings_preference_activities`.
- `Preference::StorageAdapter` provides dual-read (setting first, fallback to legacy) and dual-write
  (write to both setting and legacy) capabilities.
- `Preference::Adoption` syncs shared preferences to local layer (UserPreference/StaffPreference/
  CustomerPreference) with recovery on failure.
- `SYNC_RECOVERY_FAILED` audit events are logged to surface-specific activity tables.
- Sync recovery rules:
  - `AppPreference` recovers to `UserPreference`
  - `OrgPreference` recovers to `StaffPreference`
  - `ComPreference` recovers to `CustomerPreference`
- Legacy tables in `principal`, `operator`, and `commerce` remain for rollback safety.

In short: the destination exists and runtime cutover is active with dual-write and sync recovery.

## Target State

- `settings_preferences` becomes the only store for token-like preference records.
- `AppPreference`, `OrgPreference`, and `ComPreference` runtime storage moves to `setting`.
- `commerce` stops storing preference data.
- Preference reads and writes are routed through one storage boundary.
- Legacy tables in `principal`, `operator`, and `commerce` are removed only after cutover and
  verification.

## Cutover Plan

1. Add concrete `SettingRecord`-backed preference models for the unified schema.
2. Introduce a storage adapter or repository so callers stop binding directly to
   `AppPreference`/`OrgPreference`/`ComPreference` tables.
3. Add dual-read support:
   - read from `setting` first
   - fall back to legacy tables during migration
4. Add dual-write support for all preference mutations.
5. Backfill legacy preference rows into `settings_preferences`.
6. Reissue tokens or refresh preference snapshots where the current storage location affects JWT or
   cookie flows.
7. Flip reads to `setting` only after parity checks pass.
8. Remove legacy preference tables from `principal`, `operator`, and `commerce`.
9. Drop `commerce` only if no non-preference responsibility remains.

## Sync Recovery Rules

During the migration, login and refresh flows must keep the local preference copy recoverable.

### Recovery target by surface

- `AppPreference` recovers to `UserPreference`
- `OrgPreference` recovers to `StaffPreference`
- `ComPreference` recovers to `CustomerPreference`

### Failure handling

- Do not show sync failure as a user-facing product error.
- Keep the request successful when the shared preference write succeeded.
- Recover the local preference copy from the shared copy when the sync path fails.
- Emit a structured error log for later recovery and investigation.

### Required log fields

- `preference_type`
- `source`
- `target`
- `action`
- `error_class`
- `error_message`
- `owner_id`
- `surface` or `scope`
- `request_id` or another correlation key

## Implementation Task List For A Follow-Up AI

Use this section as the execution brief for the next implementation agent.

### Goal

Make `setting` the runtime store for token-like preferences and retire legacy preference storage in
`principal`, `operator`, and `commerce`.

### Required Deliverables

1. Add concrete `SettingRecord`-backed models for:
   - unified preference root
   - language option link
   - region option link
   - timezone option link
   - colortheme option link
   - cookie consent
2. Add one storage adapter or repository layer so controllers and services do not depend directly on
   legacy `AppPreference` / `OrgPreference` / `ComPreference` models.
3. Implement dual-read:
   - primary read from `setting`
   - fallback read from legacy tables while migration is active
4. Implement dual-write for every preference mutation path.
5. Add or update regression tests for:
   - JWT preference snapshot generation
   - cookie consent persistence
   - region / language / timezone / theme updates
   - token rotation flows that touch preference storage
6. Add one parity/backfill path from legacy stores into `settings_preferences`.
7. Add a cutover flag or equivalent mechanism so reads can be switched cleanly to `setting` only.

### Explicit Non-Goals For The First Implementation Pass

- Do not remove legacy tables in the first cutover patch.
- Do not redesign preference activity storage in this task.
- Do not change the merge semantics described in GH-629.

### Done Definition

This issue is only complete when all of the following are true:

- production code reads token-like preferences from `setting`
- production code writes token-like preferences to `setting`
- legacy tables are no longer required for the normal read path
- tests prove parity on the main preference update flows
- `commerce` is no longer the live store for `ComPreference`

## Validation Needed Before Cutover

- Every preference read path is inventoried.
- Every preference write path is inventoried.
- JWT snapshot generation reads the same values before and after migration.
- Cookie consent state survives the move.
- Preference activity stays in `activity` and does not regain direct dependency on legacy tables.
- `sign`, `acme`, and other preference entry points pass integration tests with `setting` as the
  primary store.

## Improvement Points (2026-04-07 Review)

- Add a concrete table-by-table move list with source DB, target DB, and dual-write period. This is
  too large to stay as a conceptual boundary note.
- Define read routing during migration. Multi-database changes are incomplete until the reader path,
  writer path, and cutover checks are explicit.
