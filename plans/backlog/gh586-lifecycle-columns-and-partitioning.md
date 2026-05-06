# GH-586: Implement Lifecycle Columns and Table Partitioning

GitHub: #586

## Summary

5 annotations flag architectural improvements for model lifecycle management and database
partitioning.

## Lifecycle Columns (`deletable_at` / `shreddable_at`)

- `app/models/app_preference.rb:52` — Add `deletable_at` to AppPreference
- `app/models/com_preference.rb:52` — Add `deletable_at` to ComPreference
- `app/models/org_preference.rb:52` — Add `deletable_at` to OrgPreference
- `app/models/user.rb:162` — User deletion should rely on `shreddable_at`; remove `deletable_at`
- `app/models/avatar.rb:39` — Add `shreddable_at` to Avatar
- `app/models/member.rb:32` — Add `shreddable_at` to Member
- `app/models/operator.rb:34` — Add `shreddable_at` to Operator

## Table Partitioning

- `db/principals_migrate/20240827130201_create_users.rb:3,7` — Hash partitioning for users
- `db/operators_migrate/20240827130202_create_staffs.rb:3,7` — Hash partitioning for staffs

## Action

1. Design the `deletable_at` / `shreddable_at` lifecycle strategy aligned with preference redesign.
2. Add migrations for the new columns.
3. Evaluate hashed table partitioning for `users` and `staffs` — benchmark and plan migration path.
4. Update model logic and add test coverage.

## Implementation Status (2026-04-07)

**Status: PARTIALLY DONE**

Done:

- `deletable_at` and `shreddable_at` columns exist on `users` and `staffs` tables (defaults to
  INFINITY).
- Token models (UserToken, StaffToken, CustomerToken) have `deletable_at`.

Remaining:

- Preference models (AppPreference, ComPreference, OrgPreference) do not have `deletable_at`.
- Avatar, Member, Operator do not have `shreddable_at`.
- No hash partitioning on users or staffs tables.

## Improvement Points (2026-04-07 Review)

- Separate lifecycle columns from partitioning. They have very different migration risk and should
  not be approved as one unit.
- Add data-volume and rollback assumptions. Partitioning work is not actionable until the benchmark,
  cutover path, and fallback plan are explicit.
