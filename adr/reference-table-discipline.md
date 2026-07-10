# Reference table convention

## Status

Accepted

## Context

Lookup tables are widely used throughout the application, but their design is inconsistent.

Main issues:

1. Many of the reference tables are `record_timestamps = false` does not have date information, but
   the value of the NOTHING constant varies from 0/1/11
2. The convention “unspecified = 0” is only implicitly applied.
3. Unnecessary `created_at`/`updated_at` may remain in the join table.

## Decision

We adopt the following rules:

1. The reference table has only PK. `record_timestamps = false` is required for all models.
2. All referenced models have `NOTHING = 0` as sentinel and the first row of reference data is
   `id = 0`, and logically means "unspecified/unknown/not set".
3. FKs to reference tables use `default: 0`, and the unset state is represented by the NOTHING row
   (nullable FKs are not used).
4. Join tables between reference tables, such as `avatar_role_permissions`, also do not have
   timestamp columns. Their lifecycle is treated as part of the reference data itself.

## Exceptions

For some existing models, the NOTHING value may not be changed to maintain compatibility. These
models are documented separately.

- `AvatarMembershipStatus`: NOTHING = 1
- `AvatarMonikerStatus`: NOTHING = 1
- `AvatarOwnershipStatus`: NOTHING = 1
- `AvatarPermission`: NOTHING = 1
- `AvatarRole`: NOTHING = 1
- `ComPreferenceStatus`: NOTHING = 2
- `CustomerEmailStatus`: NOTHING = 5
- `CustomerPasskeyStatus`: NOTHING = 5
- `CustomerSecretStatus`: NOTHING = 6
- `CustomerStatus`: NOTHING = 2
- `CustomerTelephoneStatus`: NOTHING = 5
- `DepartmentStatus`: NOTHING = 1
- `DivisionStatus`: NOTHING = 1
- `HandleAssignmentStatus`: NOTHING = 5
- `HandleStatus`: NOTHING = 5
- `MemberStatus`: NOTHING = 5
- `OperatorStatus`: NOTHING = 2
- `OrgPreferenceStatus`: NOTHING = 2
- `OrganizationStatus`: NOTHING = 1
- `PostReviewStatus`: NOTHING = 1
- `PostStatus`: NOTHING = 1
- `OperatorChronicleEvent`: NOTHING = 7
- `OperatorChronicleLevel`: NOTHING = 1
- `OperatorEmailStatus`: NOTHING = 4
- `OperatorOccurrenceStatus`: NOTHING = 1
- `OperatorSecretKind`: NOTHING = 1
- `OperatorIdentityStatus`: NOTHING = 2
- `OperatorTelephoneStatus`: NOTHING = 4
- `UserChronicleEvent`: NOTHING = 9
- `UserChronicleLevel`: NOTHING = 4
- `UserEmailStatus`: NOTHING = 5
- `UserOneTimePasswordStatus`: NOTHING = 5
- `UserPasskeyStatus`: NOTHING = 5
- `UserSecretStatus`: NOTHING = 6
- `UserSocialAppleStatus`: NOTHING = 6
- `UserSocialGoogleStatus`: NOTHING = 6
- `UserStatus`: NOTHING = 11

## Rationale

This convention keeps reference tables consistent and improves data integrity. Unifying FK defaults
also makes unset states explicit.

## Impact

- Added `include ReferenceRecord` to 68 existing reference models
- Data migration required to unify to `NOTHING = 0`
- Migration to remove timestamp columns from join tables
