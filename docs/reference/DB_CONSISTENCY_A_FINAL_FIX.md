# DB Consistency Priority A Final Fixes

## Overview

This document details the final fixes applied to resolve Priority A `database_consistency` issues,
specifically focusing on `ColumnPresenceChecker` and `NullConstraintChecker`.

## Changes Applied

### A) Database Migrations (DB Constraints)

#### 1. `EnforceContactStatusNotNull` (`db/guests_migrate/20260202200300_enforce_contact_status_not_null.rb`)

- **Domain**: Guest
- **Tables**: `org_contacts`, `com_contacts`, `app_contacts`
- **Action**:
  - Created 'NEYO' status record in `org_contact_statuses`, `com_contact_statuses`, and
    `app_contact_statuses`.
  - Backfilled NULL `status_id` values with the 'NEYO' status ID.
  - Set `status_id` column to `NOT NULL` in all three contact tables.
  - Ensured indexes exist on `status_id`.
- **Rationale**: Resolves `ColumnPresenceChecker` failures by requiring the status association at
  the database level.

#### 2. `EnsureStaffSecretKindData` (`db/operators_migrate/20260202200301_ensure_staff_secret_kind_data.rb`)

- **Domain**: Operator
- **Tables**: `staff_secret_kinds`
- **Action**:
  - Seeded default codes: 'LOGIN', 'TOTP', 'default'.
  - Enforced `NOT NULL` on the `code` column.
- **Rationale**: Ensures data consistency and satisfies database requirements for the
  `NullConstraintChecker`.

### B) Model Adjustments (Presence Validators)

#### 1. `AvatarRolePermission` (`app/models/avatar_role_permission.rb`)

- **Action**:
  - Added `validates :created_at, :updated_at, presence: true`.
  - Commented out `self.record_timestamps = false` to allow Rails to handle timestamps, which
    ensures they are present during validation if being saved.
- **Rationale**: Resolves `NullConstraintChecker` failures by ensuring model-level validation
  matches database constraints.

#### 2. `StaffSecretKind` (`app/models/staff_secret_kind.rb`)

- **Action**:
  - Added `validates :code, presence: true`.
- **Rationale**: Resolves `NullConstraintChecker` failures.

## Verification Results

### `database_consistency` check:

- `ColumnPresenceChecker`: **0 failures**
- `NullConstraintChecker`: **0 failures**

Remaining failures are limited to `UniqueIndexChecker`, `MissingUniqueIndexChecker`, and
`CaseSensitiveUniqueValidationChecker`, which were explicitly excluded from this scope.

## How to Apply

```bash
SAFETY_ASSURED=1 bin/rails db:migrate
```
