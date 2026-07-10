# Move OperatorPreference Family to `operator` Database

## Status

Completed and archived (verified 2026-05-19).

> **Completion notes (2026-05-07):**
>
> - All 9 `staff_preference_*` tables exist in the `operator` DB:
>   `db/operators_migrate/20260506020000_create_staff_preferences_in_operator.rb` creates the
>   schema; `db/operator_schema.rb` is the dump.
> - Data migration:
>   `db/operators_migrate/20260506210800_migrate_staff_preferences_data_to_operator.rb`.
> - Principal-side drop:
>   `db/principals_migrate/20260506210900_drop_staff_preferences_from_principal.rb`.
> - All 9 model files (`app/models/staff_preference*.rb`) inherit from `OrgPrincipalRecord` and
>   carry `# Database name: org_principal`.
> - The Org↔Staff sync path in `Preference::Adoption` and
>   `Preference::Core#sync_to_resource_preference!` now operates within a single DB (`operator`).
> - `Preference::Adoption#resolve_cross_db_option_id` still exists — this is the intentional
>   out-of-scope follow-up. Its removal belongs to the preference retirement pass, not this
>   completed DB move. The old customer-side pairing plan is archived as superseded at
>   `plans/archive/customer-preferences-move-to-com-preference-db.md`.

## Summary

The `staff_preference_*` series tables are currently left in the `principal` DB. This is org TLD
This is interfering with bubble completion, and the `Staff` main body (`operator`) The only
inconsistency is that the DB of `OperatorPreference` (`principal`) is separated. `operator` Unify to
DB.

This is the customer at the time preference Written as a parallel effort to movement planning.
Currently the customer side plan is placement on 2026-05-18 It is superseded by update, and the
correct policy is to place com actor-local preference in `com_principal`.

## Motivation

### org TLD The end of the bubble

TLD confirmed with `adr/preference-soft-bubble-doctrine.md` Currently, org Only TLD straddles the
bubble boundary:

| TLD | anonymous preference | actor preference    | actor body                                   | actor authentication information |
| --- | -------------------- | ------------------- | -------------------------------------------- | -------------------------------- |
| app | principal ✓          | principal ✓         | principal ✓                                  | principal ✓                      |
| com | setting ✓            | setting ✓ (porting) | guest (as intended as com authentication DB) | guest ✓                          |
| org | operator ✓           | **principal** ✗     | operator ✓                                   | operator ✓                       |

If you move `staff_preference_*` to `operator`, the entire org TLD will be completed in `operator`.

### Eliminate double-write cross-DB at login

`Preference::Adoption` and `Preference::Core#sync_to_resource_preference!` synchronizes session-side
and actor-side in both directions when logging in and updating preferences. current situation:

- app: `principal.app_preferences` ↔ `principal.user_preferences` — Same DB
- com: `com_setting.com_preferences` ↔ `com_principal.visitor_preferences` — Explicit boundaries
- **org**: `operator.org_preferences` ↔ **`principal.staff_preferences`** — **DB straddle**

To deal with it `Preference::Adoption#resolve_cross_db_option_id` exists, and the option_id is
re-resolved by name (because the ID sequence numbers in the option table do not match if the DB is
different). Once this porting is complete, org will also be synced within the same DB, and
`resolve_cross_db_option_id` The route becomes unnecessary.

### Room for adding DB constraints

Currently `staff_preferences.staff_id` remains app-level FK (`staffs` is in `operator`)
`staff_preferences` is `principal` , so you cannot paste the DB constraint). After porting, the same
DB will be used, so change the DB-level to `staffs.id`. FK can be added (this can be treated as a
separate issue).

## Current State (2026-05-06)

### Under `principal` (move target, 9 tables)

- `staff_preferences` (parent)
- `staff_preference_languages`, `staff_preference_language_options`
- `staff_preference_regions`, `staff_preference_region_options`
- `staff_preference_timezones`, `staff_preference_timezone_options`
- `staff_preference_colorthemes`, `staff_preference_colortheme_options`

These DB-level FKs are `staff_preference_<child>` → `staff_preferences` and
`staff_preference_<child>` → `staff_preference_<child>_options` internal link only. `staffs` There
is no DB-level FK to (only app-level since it is cross-DB).

### Under `operator` (existing/nearby)

- `staffs` (actor body)
- `staff_passkeys`, `staff_emails`, `staff_telephones`, `staff_secrets`, etc. (authentication
  information)
- `org_preferences` series (session-side preference)
- `staff_org_preferences` (Bridge, currently `org_preference_id` → `org_preferences` `staff_id` is
  app-level FK)

### model reference point

- `app/models/staff_preference.rb` — `# Database name: app_principal`,
  `class OperatorPreference < AppPrincipalRecord`
- `app/models/staff_preference_language.rb` and 8 other files — also inherited from
  `AppPrincipalRecord`
- `app/models/staff.rb` — `has_one :staff_preference, dependent: :destroy`
- `app/services/preference/class_registry.rb` — `"Staff"` entry
- `app/controllers/concerns/preference/adoption.rb` — at `find_resource_preference` See
  `resource.staff_preference` (adaptation path is OrgPreference ↔ OperatorPreference)
- `app/controllers/concerns/preference/adoption.rb` — `resolve_cross_db_option_id` helper is org
  Exists for TLD (will be unused for org TLD after porting)

## Target State

- All `staff_preferences` series exist in `operator` DB.
- `# Database name:` comment in `app/models/staff_preference*.rb` points to `operator`.
- The parent class has been changed from `AppPrincipalRecord` to `OrgPrincipalRecord`.
- The Org↔Staff route of `Preference::Adoption` can be within the same DB.
- `staff_preference_*` table is removed from `principal` DB (after cutover completes).

## Migration Steps (high level)

1. **Schema porting**:
   - Added migration for `staff_preferences` series 9 table creation to `db/operators_migrate/`.
   - The structure will remain the same for the time being (normalized schema and option_id foreign
     key system).
   - Internal FK (`staff_preference_<child>` → `staff_preferences`, `<child>` → `<child>_options`)
     is the same DB, so it can be reproduced as is.
   - **Additional improvements** for the new `operator.staff_preferences.staff_id`
     `add_foreign_key :staff_preferences, :staffs` (possible with the same DB). It is up to the
     implementer to decide whether to include this in this work or separate it.
2. **Model connection destination change**:
   - `app/models/staff_preference*.rb` with all 9 files:
     - Parent class `AppPrincipalRecord` → `OrgPrincipalRecord`
     - Schema comment `# Database name: app_principal` → `operator`
3. **Data migration**:
   - `principal.staff_preferences` From all 9 tables `operator.staff_preferences` One-time migration
     that copies the entire data to the system.
   - `staff_id` is an app-level FK, so cross-DB references are the same before and after the move.
   - option table (`staff_preference_language_options` etc.) is close to a static seed, so copy it
     while keeping the id, and copy the child table (`staff_preference_languages` etc.) will also be
     consistent if you copy them while keeping `option_id`.
4. **Cutover**:
   - Switch both reading and writing to the `operator` side (automatically switched when modifying
     the model).
   - After switching, `db/principals_migrate/` to `staff_preference_*` 9 Added post-cutover
     migration to drop tables.
   - Pay attention to the internal FK drop order (child table → parent table → option table).
5. **verification**:
   - Sign / Acme Edit preferences for each surface (org / sign-org) (region / language / timezone /
     colortheme) integration test is green.
   - Org→Staff synchronization of `Preference::Adoption` does not regress (when logging in with
     `org_preferences`) updated_at comparison and copy of `staff_preferences` is successful within
     the same DB).
   - `Preference::Core#sync_to_resource_preference!` The OrgPreference→OperatorPreference path does
     not recur.

- JWT `prf` claims are consistent with `Actor::Preference` (login → preference update → token
  reissue).

## Out of Scope

- Structural change of `staff_preferences` (from normalization to denormalization or vice versa).
  This is B2 (actor-side schema unification) as an independent issue.
- Delete `Preference::Adoption#resolve_cross_db_option_id` itself. Another preference remains after
  this port. Since it belongs to the cleanup judgment, it is handled in the retirement plan.
- `staff_org_preferences` Bridge design review. As it is currently within the same DB, it will not
  be touched upon in this case.
- Do not touch the area around the token DB (mark/symbol/token).
- DB-level to `staffs` It is up to the implementer to decide whether adding FK is within the scope
  (it may be included in this work or made into a separate patch).

## Risks / Notes

- option table (`staff_preference_language_options` etc.) must be copied while preserving the ID.
  The code is constant (`OperatorPreferenceLanguageOption::JA` etc.), the ID is directly referenced,
  so if the old and new IDs do not match, a regression will occur.
- `Preference::Adoption#resolve_cross_db_option_id` The reason for "resolving by name" is to remedy
  the case where the IDs do not match, so you can use this helper when porting, but it is simpler if
  you can maintain the ID.
- Depending on the number of production data of the existing `staff_preferences`, it is necessary to
  secure maintenance time.
- Drop migration on the principal side is performed after complete data migration and confirmation
  of read/write path switching is completed.

## Acceptance Criteria

- [x] `staff_preference_*` series 9 table exists in `operator` DB.
- [x] `app/models/staff_preference*.rb` 9 The parent class of the file is `OrgPrincipalRecord`,
      schema comment is `operator`.
- [x] Org↔Staff synchronization of `Preference::Adoption` is completed within the same DB.
- [x] `staff_preference_*` 9 table has been deleted from `principal` DB.
- [x] org TLD preference edit / cookie consent / token rotation regression test is green.
- [x] double-write at login (`AppPreference`↔`UserPreference`, `OrgPreference`↔`OperatorPreference`)
      works as expected, and Com Explicit `com_setting`→`com_principal` of
      `ComPreference`↔`VisitorPreference` treated as a boundary.

## References

- `adr/preference-soft-bubble-doctrine.md` — Basic policy of unifying the interface while keeping
  the DB in a separate bubble
- `plans/archive/customer-preferences-move-to-com-preference-db.md` — Parallel work when superseded
- `plans/backlog/legacy-preference-models-retirement-plan.md` — Overall retirement roadmap
- `app/services/preference/class_registry.rb` — `"Staff"` entry
- `app/controllers/concerns/preference/adoption.rb` — `resolve_cross_db_option_id` double-write
  logic, including
- `app/controllers/concerns/preference/core.rb` — OrgPreference for `sync_to_resource_preference!` →
  OperatorPreference route
- `app/models/staff.rb` — `has_one :staff_preference`
