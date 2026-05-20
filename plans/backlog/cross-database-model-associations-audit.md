# Cross-Database Model Associations Audit

Created: 2026-05-19

## Context

Rails tests are slow, and one suspected contributor is ActiveRecord associations that cross Rails
multi-DB connection boundaries. This note records a static reflection audit so the cleanup can be
planned separately from test-speed work.

The audit used `Rails.application.eager_load!`, then compared each non-abstract model's
`connection_db_config.name` with each non-polymorphic association target model's connection name.
Replica suffixes were normalized away. No database queries or tests were run for behavior.

## Summary

- Initial resolved cross-database associations found: 70.
- After the first cleanup pass, resolved cross-database associations found: 65.
- Separate association definition problems found: 17, all in the occurrence model family.
- Relevant database-boundary docs:
  - `docs/architecture/database-boundaries.md`
  - `adr/surface-database-connection-naming.md`
  - `adr/actor-db-naming-policy.md`

## Cross-Database Association Families

Preference chronicle associations:

- `AppPreference` (`app_setting`) <-> `AppPreferenceChronicle` (`chronicle`)
- `ComPreference` (`com_setting`) <-> `ComPreferenceChronicle` (`chronicle`)
- `OrgPreference` (`org_setting`) <-> `OrgPreferenceChronicle` (`chronicle`)

App principal associations:

- `Client` (`app_principal`) -> `ClientChronicle` / `OperatorChronicle` (`chronicle`)
- `Client` (`app_principal`) -> `ClientToken`, `ClientOidcConnection` (`app_ticket`)
- `Client` (`app_principal`) -> `ClientNotificationRecord` (`app_signal`)
- `Client` (`app_principal`) -> `ClientAccount` (`app_zenith`)
- `Client` (`app_principal`) -> `AvatarAssignment`, `Avatar` (`avatar`)
- `ClientToken`, `ClientOidcConnection`, `ClientAuthorizationCode` -> `Client`
- `ClientAccount` -> `Client`
- `ClientNotificationRecord` -> `Client`

Com principal associations:

- `Visitor` (`com_principal`) -> `VisitorToken`, `VisitorOidcConnection` (`com_ticket`)
- `Visitor` (`com_principal`) -> `VisitorNotificationRecord` (`com_signal`)
- `Visitor` (`com_principal`) -> `VisitorAccount` (`com_zenith`)
- `VisitorToken`, `VisitorOidcConnection`, `VisitorAuthorizationCode` -> `Visitor`
- `VisitorAccount` -> `Visitor`
- `VisitorNotificationRecord` -> `Visitor`

Org principal associations:

- `Operator` (`org_principal`) -> `OperatorChronicle`, `ClientChronicle` (`chronicle`)
- `Operator` (`org_principal`) -> `OperatorToken`, `OperatorOidcConnection` (`org_ticket`)
- `Operator` (`org_principal`) -> `OperatorNotificationRecord` (`org_signal`)
- `Operator` (`org_principal`) -> `OperatorAccount` (`org_zenith`)
- `OperatorToken`, `OperatorOidcConnection`, `OperatorAuthorizationCode`, `OrganizationInvitation`
  -> `Operator`
- `OperatorAccount` -> `Operator`
- `OperatorNotificationRecord` -> `Operator`

Workspace, member, and avatar associations:

- `Avatar` (`avatar`) -> `Member`, `Client` (`app_principal`)
- `AvatarAssignment` (`avatar`) -> `Client` (`app_principal`)
- `Member` (`app_principal`) -> `Division` (`org_principal`)
- `Member` (`app_principal`) -> `Avatar`, `MemberAvatar*` (`avatar`)
- `MemberAvatarAccess`, `MemberAvatarDeletion`, `MemberAvatarExtraction`,
  `MemberAvatarImpersonation`, `MemberAvatarOversight`, `MemberAvatarSuspension`,
  `MemberAvatarVisibility` (`avatar`) -> `Member` (`app_principal`)
- Formerly: `ClientMembership` (`app_principal`) -> `Workspace` / `Organization` (`org_principal`)
- Formerly: `Organization` / `Workspace` (`org_principal`) -> `ClientMembership` (`app_principal`)
- Formerly: `Division` (`org_principal`) -> `Member` (`app_principal`)

The former relationships above were removed on 2026-05-19. The scalar `workspace_id` and
`division_id` columns remain, but they are no longer modeled as ActiveRecord associations across DB
boundaries.

## Association Definition Problems

These are not DB-crossing problems. They are reflection resolution failures inside the `occurrence`
connection caused by historical `user` association names without matching Ruby class names.

`ClientOccurrence` defines these associations without `class_name`, so Rails tries to constantize
non-existent classes:

- `has_many :area_user_occurrences` -> expects `AreaUserOccurrence`; actual model is
  `AreaClientOccurrence`.
- `has_many :domain_user_occurrences` -> expects `DomainUserOccurrence`; actual model is
  `DomainClientOccurrence`.
- `has_many :email_user_occurrences` -> expects `EmailUserOccurrence`; actual model is
  `EmailClientOccurrence`.
- `has_many :ip_user_occurrences` -> expects `IpUserOccurrence`; actual model is
  `IpClientOccurrence`.
- `has_many :telephone_user_occurrences` -> expects `TelephoneUserOccurrence`; actual model is
  `TelephoneClientOccurrence`.

The through associations depending on those missing source reflections also fail:

- `ClientOccurrence#area_occurrences`
- `ClientOccurrence#domain_occurrences`
- `ClientOccurrence#email_occurrences`
- `ClientOccurrence#ip_occurrences`
- `ClientOccurrence#telephone_occurrences`

Reverse through associations affected by the same missing source reflections:

- `AreaOccurrence#client_occurrences`
- `DomainOccurrence#client_occurrences`
- `EmailOccurrence#client_occurrences`
- `IpOccurrence#client_occurrences`
- `OperatorOccurrence#client_occurrences`
- `TelephoneOccurrence#client_occurrences`
- `ZipOccurrence#client_occurrences`

`ZipOccurrence#client_occurrences` is slightly different: the join model exists as
`ClientZipOccurrence`, but the legacy physical table is `user_zip_occurrences`. It should be checked
with the same naming cleanup because the join association already uses `client_zip_occurrences`
instead of `*_user_occurrences`.

## Cleanup Notes

- Decide which DB-crossing associations are intentional domain navigation and which should become
  explicit service/query code.
- For Rails test speed, prioritize associations that trigger fixture loading or eager reflection
  across many databases: actor token/account/notification relationships, avatar/member
  relationships, and chronicle relationships.
- Fix occurrence reflection failures separately with explicit `class_name` on the legacy
  `*_user_occurrences` association names, or rename the association APIs consistently.
- Add narrow model/reflection tests before changing association names, because several names
  preserve old table vocabulary while runtime models have moved to `Client`.

## Placement Classification

This section classifies whether the cross-DB relationships look like model placement mistakes or
intentional boundaries.

### Intentional Database Split

These model placements match `docs/architecture/database-boundaries.md` and
`adr/surface-database-connection-naming.md`. The associations may still be too convenient or too
expensive, but the target model does not appear to be in the wrong DB.

- Actor principal -> ticket:
  - `Client` (`app_principal`) <-> `ClientToken`, `ClientOidcConnection`, `ClientAuthorizationCode`
    (`app_ticket`)
  - `Operator` (`org_principal`) <-> `OperatorToken`, `OperatorOidcConnection`,
    `OperatorAuthorizationCode`, `OrganizationInvitation` (`org_ticket`)
  - `Visitor` (`com_principal`) <-> `VisitorToken`, `VisitorOidcConnection`,
    `VisitorAuthorizationCode` (`com_ticket`)
- Actor principal -> signal:
  - `Client` <-> `ClientNotificationRecord`
  - `Operator` <-> `OperatorNotificationRecord`
  - `Visitor` <-> `VisitorNotificationRecord`
- Actor principal -> zenith:
  - `Client` <-> `ClientAccount`
  - `Operator` <-> `OperatorAccount`
  - `Visitor` <-> `VisitorAccount`
- Settings -> chronicle and actor -> chronicle:
  - Chronicle tables are documented as a cross-cutting DB.
  - Several chronicle models already use `subject_id` / `subject_type` comments for cross-DB
    compatibility instead of physical foreign keys.
- Avatar core models:
  - `avatar` is documented as a cross-cutting database.
  - `Avatar`, `AvatarAssignment`, `AvatarMembership`, `AvatarOwnershipPeriod`, `Post`, and related
    avatar-local reference tables appear intentionally placed in `avatar`.

### Likely Navigation-Only Associations

These model placements look intentional, but Rails associations create convenient cross-DB traversal
that should probably be replaced or constrained before performance work:

- `Client#client_tokens`, `Operator#staff_tokens`, `Visitor#visitor_tokens`
- `Client#notification_records`, `Operator#notification_records`, `Visitor#notification_records`
- `Client#rp_account`, `Operator#rp_account`, `Visitor#rp_account`
- `Preference#*_preference_chronicles`
- `Client#client_chronicles`, `Operator#staff_chronicles`
- `Avatar#owner`, `Avatar#administrators`, `Avatar#editors`, `Avatar#reviewers`, `Avatar#viewers`

These are useful read paths, but the DB boundary is real. Avoid relying on them for callbacks,
fixtures, eager loading, or cleanup cascades.

### Needs Design Decision

These look like the real placement-risk area. The first cleanup pass removed the Rails associations
for these cross-DB links while leaving the scalar columns in place:

- `ClientMembership` is in `app_principal`, but stores `workspace_id` for `Workspace` /
  `Organization` in `org_principal`.
  - `adr/account-workspace-avatar-billing.md` says the first implementation introduced
    `user_memberships` to show which `Workspace` a `User` belongs to, with `Staff` out of scope.
  - That means the current `app_principal` placement is not clearly wrong by the ADR.
  - But the row is a bridge between account and tenant, so it cannot have a DB-level FK to
    `Workspace` while it remains in `app_principal`.
  - `db/org_principal_schema.rb` also still contains `user_workspaces`, with no matching model found
    in `app/models`; this should be checked as stale schema/table residue before moving anything.
- `Member` is in `app_principal`, but stores `division_id` for `Division` in `org_principal`.
  - If `Member` is an app-side account/person/profile record, then direct `division_id` couples it
    to org-owned structure and should likely move behind `ClientMembership` or a membership role
    row.
  - If `Member` means an organization membership/personnel row, then `Member` may itself belong in
    an org-owned DB.
  - Current docs do not clearly distinguish `Member`, `ClientMembership`, and `AvatarGrant`.
- The removed `Division#members` association was the inverse of the `Member#division` ambiguity and
  should be replaced only after the membership model is clarified.

### Probably Not Placement Bugs, But Association API Bugs

Avatar permission rows are stored in `avatar`, which matches the cross-cutting avatar DB. The
problem is that some rows point directly at app-principal actors or members through Rails
associations:

- `AvatarAssignment#user` and `Avatar#owner` / role-based user associations point to `Client`.
- `MemberAvatarAccess`, `MemberAvatarVisibility`, `MemberAvatarOversight`, `MemberAvatarExtraction`,
  `MemberAvatarImpersonation`, `MemberAvatarSuspension`, `MemberAvatarDeletion` point to `Member`.

`adr/account-workspace-avatar-billing.md` describes this concept as `AvatarGrant` permission granted
by `Membership` to operate an `Avatar`. The existing `member_avatar_*` tables may be an older or
parallel form of that idea. Before moving tables, decide whether the grant target should be
`Client`, `Member`, `ClientMembership`, or an actor key stored without ActiveRecord traversal.

### Placement Investigation Priority

1. Clarify `Member` vs `ClientMembership` vs `AvatarGrant`.
2. Decide whether `ClientMembership` is account-owned (`app_principal`) or tenant-owned
   (`org_principal`), and handle the stale-looking `user_workspaces` table.
3. Replace cross-DB Rails traversal in avatar grants with explicit IDs or query/service APIs.
4. Only after those decisions, consider reducing actor -> ticket/signal/zenith associations; those
   placements appear intentional.
