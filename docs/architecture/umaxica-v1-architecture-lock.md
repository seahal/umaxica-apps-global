# Umaxica v1 Architecture Lock

## Purpose

This document locks the v1 resource, database, and guard-rail decisions before migrations, model
rewrites, controller rewrites, Group v1, Identity-to-Account cleanup, Avatar legacy cleanup, content
DB creation, or UGC implementation.

## Core Resources

Identity, Account, Organization, and Unit belong to the core domain and core database placement.
Identity data is integrated into the core side; there is no separate Identity database.

Identity is not owned by Account or Organization. Identity is a login key and credential subject.
Identity-to-Account relationships must be represented by grant, assignment, or lifecycle authority
tables instead of direct foreign-key ownership from Account-like rows.

Identity, Account, Organization, Unit, Avatar, and Group are independent resources. Ownership,
membership, use rights, management rights, operation rights, primary or representative selection,
transfer history, and active, suspended, or revoked state must be represented by authority or
lifecycle tables.

Authority and lifecycle tables are not bare join tables. They must be able to carry role, state,
primary flag, valid_from, valid_to, granted_by, revoked_by, reason, and audit reference fields.

Controllers must not directly write authority or lifecycle tables. Controllers call use-case
services that own authorization, validation, lifecycle transitions, audit references, and
transaction boundaries.

## Avatar DB Boundary

Avatar and Group belong to the avatar domain and avatar database.

Avatar DB owns:

- Avatar
- Group
- Avatar and Group settings
- Avatar and Group current state
- Avatar and Group relationship settings
- Avatar assignment, membership, and binding records
- GroupAvatarMembership
- Follow, block, mute, and related social graph relations
- Avatar lifecycle state authority

Avatar DB is the actor, settings, relation, and social graph DB.

Avatar DB does not own:

- Post bodies
- Comments
- Replies
- Captions
- Image posts
- Video posts
- Story or short video content
- DM bodies
- Reaction events
- Feed material
- Ranking sources
- Posting-time actor snapshots
- Content read models

Content, media, interaction, moderation, and read-model domains own posts, comments, media,
reactions, feed material, ranking inputs, and posting-time actor snapshots.

## Actor Snapshot Boundary

Avatar DB is the authority for current Avatar settings, state, and relationships. Posting-time
display snapshots such as `avatar_public_id`, handle, moniker, and display state belong to the
content database or content read model.

Do not create actor snapshot tables in Avatar DB.

## Avatar Lifecycle State

Avatar DB is the authority for the current lifecycle state of an Avatar. Content and moderation use
that state as input when deciding display, deletion, operation, or ranking behavior.

Content visibility, hiding, deletion, and ranking exclusion are implemented by content and
moderation domains, not by Avatar DB.

Lifecycle state is implemented as the avatar DB reference table `avatar_lifecycle_states`, and
`avatars.lifecycle_state_id` is the canonical current-state pointer. Rails integer enums and
PostgreSQL enums are not used. The legacy `avatars.avatar_status_id` column is compatibility state
and is not canonical for v1 lifecycle decisions.

| state     | New content | Existing content display   | Owner edit/restore                                                | Follow target | Group attach | Public discovery | Terminal | Moderation/audit reference |
| --------- | ----------- | -------------------------- | ----------------------------------------------------------------- | ------------- | ------------ | ---------------- | -------- | -------------------------- |
| active    | yes         | normally visible           | owner/admin edit                                                  | yes           | yes          | yes              | no       | yes                        |
| suspended | no          | content/moderation decides | limited settings review; moderator/admin restore only             | no            | no           | no               | no       | yes                        |
| archived  | no          | content/moderation decides | owner/admin restore may be allowed                                | no            | no           | no               | no       | yes                        |
| banned    | no          | content/moderation decides | owner restore is not allowed; moderator/admin only                | no            | no           | no               | no       | yes                        |
| deleted   | no          | content/moderation decides | no new operation; restoration is not allowed by v1 service policy | no            | no           | no               | yes      | yes                        |

`deleted` is terminal in the v1 transition service. Deleted Avatars remain only as minimum authority
records for audit, legal, or retention needs and must not resolve publicly.

The v1 transition policy is a service-local map, not a database table. The minimum allowed
transitions are:

- `active -> suspended`
- `suspended -> active`
- `active -> archived`
- `archived -> active`
- `active -> banned`
- `suspended -> banned`
- `archived -> banned`
- `active -> deleted`
- `archived -> deleted`
- `suspended -> deleted`
- `banned -> deleted`

Forbidden invariants:

- `deleted -> any`
- owner-authority restoration from `banned`
- content creation by `suspended`, `archived`, `banned`, or `deleted` Avatars
- public discovery for `suspended`, `archived`, `banned`, or `deleted` Avatars

## Cross-DB Reference Policy

Do not add new cross-DB bigint or integer ID associations. Do not assume native cross-DB foreign
keys.

Content DB references to Avatar must use immutable public identifiers such as `avatar_public_id`.
Other cross-DB references should use stable identifiers such as public_id, gid, surface, and
resource_type.

## Known Violations

These are current implementation risks to fix in later slices, not approved patterns for new work:

- `personas.client_identity_id` directly models Identity-to-Account ownership-like linkage.
- `agents.operator_identity_id` has the same direct identity column shape.
- `individuals.visitor_identity_id` has the same direct identity column shape.
- `avatars.client_id` remains as migration compatibility only. It is not ownership,
  authorization, or canonical Avatar-subject authority.
- `Base::App::Organizations::MembershipsController`,
  `Base::Com::Organizations::MembershipsController`, and
  `Base::Org::Organizations::MembershipsController` are stubs.
- `avatar_agent_bindings` and `avatar_individual_bindings` now match the
  `avatar_persona_bindings` active-history contract. They carry `public_id`, `assigned_at`, and
  `revoked_at`; enforce revoke ordering; and use active partial unique indexes for active pair,
  active Avatar, and active subject uniqueness.
- `avatars.avatar_status_id` is legacy compatibility state and must be retired after
  `avatars.lifecycle_state_id` is fully adopted.
- Historical avatar migrations include `posts` in the avatar DB.
- `avatar_memberships.actor_id` is an integer actor reference inside the avatar DB boundary that
  still needs review before Group v1 and content integration.
- Existing direct integer references between legacy Member, Client, Persona, Agent, Individual, and
  Avatar paths remain transitional compatibility paths.
- `avatar_agent_bindings.agent_id` and `avatar_individual_bindings.individual_id` remain existing
  cross-DB integer references. This slice did not migrate them to public-id target references.
- `persona_assignments` has active pair uniqueness but still needs an app_zenith constraint review
  for `revoked_at >= assigned_at`.
- `persona_memberships` has active primary uniqueness but still needs a dedicated app_zenith review
  for temporal and revoke-reason constraints.

## Slice 2 DB Constraint Inventory

Authority and lifecycle invariants must be protected primarily by DB constraints and indexes. Rails
validations are supplemental only.

Added in Slice 2:

- `chk_avatar_memberships_valid_period`: enforces `avatar_memberships.valid_from <= valid_to`.
- `chk_avatar_persona_bindings_revoked_after_assigned`: enforces
  `avatar_persona_bindings.revoked_at IS NULL OR revoked_at >= assigned_at`.
- `chk_avatar_lifecycle_events_state_changes`: rejects lifecycle events where
  `from_state_key == to_state_key`.
- `fk_avatar_lifecycle_events_from_state_key`: requires `from_state_key` to reference
  `avatar_lifecycle_states.key`.
- `fk_avatar_lifecycle_events_to_state_key`: requires `to_state_key` to reference
  `avatar_lifecycle_states.key`.

Already present and verified in this slice:

- `avatar_assignments.role` has a DB check for `owner`, `affiliation`, `administrator`, `editor`,
  `reviewer`, and `viewer`. `affiliation`, `editor`, and `reviewer` are known legacy roles retained
  for compatibility.
- `avatar_assignments` has one-owner and one-affiliation partial unique indexes per Avatar, plus a
  unique `(avatar_id, user_id, role)` key.
- `avatar_memberships` has active relation uniqueness on `(avatar_id, actor_id)` where
  `valid_to = 'infinity'`.
- `avatar_persona_bindings` has unique `public_id` and active partial unique indexes for active
  Avatar, active Persona, and active pair relations.
- `avatars.lifecycle_state_id` is non-null and foreign-keyed to `avatar_lifecycle_states`.

Not added in this slice:

- `group_avatar_memberships` constraints were not added because the table does not exist.
- `avatar_agent_bindings` and `avatar_individual_bindings` temporal constraints were deferred to
  the binding symmetry slice because the tables currently have no `assigned_at` or `revoked_at`
  lifecycle columns.
- Revoke-reason requirements were not added because the Avatar tables in scope do not yet define a
  revoke reason column.
- `avatar_assignments` was not reduced to the four-role v1 target set because current code and tests
  still use `affiliation`, `editor`, and `reviewer`.

## Slice 3 Avatar Binding Symmetry Inventory

Slice 3 extended the `avatar_persona_bindings` active-history contract to
`avatar_agent_bindings` and `avatar_individual_bindings`.

Added in Slice 3:

- `avatar_agent_bindings.public_id`
- `avatar_agent_bindings.assigned_at`
- `avatar_agent_bindings.revoked_at`
- `avatar_individual_bindings.public_id`
- `avatar_individual_bindings.assigned_at`
- `avatar_individual_bindings.revoked_at`
- `chk_avatar_agent_bindings_revoked_after_assigned`
- `chk_avatar_individual_bindings_revoked_after_assigned`
- `idx_avatar_agent_bindings_active_pair`
- `idx_avatar_agent_bindings_active_avatar`
- `idx_avatar_agent_bindings_active_agent`
- `idx_avatar_individual_bindings_active_pair`
- `idx_avatar_individual_bindings_active_avatar`
- `idx_avatar_individual_bindings_active_individual`

Slice 4 introduced `AvatarProvisioning::Create` as the only Avatar creation entry point for the
app surface. `Base::App::AvatarsController#create` is a service caller and must not directly create,
update, or destroy Avatar authority or lifecycle rows. The service creates Avatar, Handle,
`AvatarPersonaBinding`, and initial owner `AvatarAssignment` in one transaction.

For the app surface, `AvatarPersonaBinding` is the canonical Avatar-to-Persona binding.
`avatars.client_id` is written only inside `AvatarProvisioning::Create` as migration compatibility
for legacy constraints and read paths; it is not a basis for ownership or authorization.
`avatars.lifecycle_state_id` is the canonical current lifecycle state pointer. Historical avatar DB
posts remain a legacy UGC violation and were not changed in Slice 4.

## Out of Scope for This Slice

- Existing Avatar binding backfill
- Group v1 implementation
- Identity-to-Account direct column removal
- `avatars.client_id` removal
- Content DB creation
- Post, comment, media, reaction, or feed implementation

## Related Decisions

- `adr/umaxica-v1-core-resource-architecture.md`
- `adr/avatar-db-content-db-boundary.md`
- `adr/avatar-lifecycle-state-authority.md`
- `adr/cross-db-reference-policy.md`
- `adr/authority-lifecycle-table-policy.md`
