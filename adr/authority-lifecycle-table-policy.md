# Authority and Lifecycle Table Policy

## Status

Accepted

## Date

2026-07-03

## Context

The core resource model must not become a direct ownership tree. Relationship rows need lifecycle
semantics and clear write ownership.

## Decision

Relationships among Identity, Account, Organization, Unit, Avatar, and Group must be modeled as
authority or lifecycle tables instead of direct ownership foreign keys on base resource rows.

Authority and lifecycle tables must be able to represent:

- role
- state
- primary or representative selection
- valid_from
- valid_to
- granted_by
- revoked_by
- reason
- audit reference

Controllers must not directly create, update, or destroy authority or lifecycle rows. Controllers
call use-case services. The services own lifecycle transitions, authorization, validation, audit
references, and transaction boundaries.

DB constraints are the primary enforcement layer for table invariants. Rails validations may mirror
the same rule for earlier user-facing feedback, but validations must not be the only protection for
authority/lifecycle correctness.

The first Avatar DB constraint slice added or verified these protections:

- `avatar_assignments.role` is constrained to known v1 and legacy roles:
  `owner`, `affiliation`, `administrator`, `editor`, `reviewer`, and `viewer`.
- `avatar_assignments` already has primary-role partial unique indexes for one `owner` and one
  `affiliation` per Avatar, plus a unique `(avatar_id, user_id, role)` assignment key.
- `avatar_memberships.valid_from <= valid_to` is enforced by
  `chk_avatar_memberships_valid_period`.
- `avatar_memberships` already has active relation uniqueness on `(avatar_id, actor_id)` where
  `valid_to = 'infinity'`.
- `avatar_persona_bindings.revoked_at IS NULL OR revoked_at >= assigned_at` is enforced by
  `chk_avatar_persona_bindings_revoked_after_assigned`.
- `avatar_persona_bindings` already has active partial unique indexes for active pair, active
  Avatar, and active Persona relations, plus unique `public_id`.
- `avatar_lifecycle_events.from_state_key` and `to_state_key` reference
  `avatar_lifecycle_states.key`, and `chk_avatar_lifecycle_events_state_changes` rejects
  no-op events where both keys are equal.

The Avatar binding symmetry slice extended the same active-history contract to
`avatar_agent_bindings` and `avatar_individual_bindings`:

- both tables now carry unique `public_id`, non-null `assigned_at`, and nullable `revoked_at`
- both tables enforce `revoked_at IS NULL OR revoked_at >= assigned_at`
- both tables use active partial unique indexes for active pair, active Avatar, and active subject
  uniqueness

The lifecycle service remains responsible for transition authorization, including the rule that
`deleted` is terminal and does not emit an event for rejected transitions.

## Consequences

Bare join tables for ownership, membership, binding, or grants are transitional only. New work must
prefer explicit authority services and lifecycle-rich records.

Known unresolved gaps after the Avatar provisioning service slice:

- `group_avatar_memberships` does not exist yet, so no constraints were added.
- `avatar_agent_bindings.agent_id` and `avatar_individual_bindings.individual_id` remain existing
  cross-DB integer references. They are legacy compatibility paths, not approved patterns for new
  references.
- `avatars.client_id` remains a legacy Avatar-to-Member compatibility column. New ownership,
  authorization, and canonical subject binding must use `AvatarAssignment` plus the surface binding
  table, not `avatars.client_id`.
- `avatars.avatar_status_id` remains legacy lifecycle compatibility state.
- Historical avatar DB posts remain a legacy UGC violation.
- `persona_assignments` already has unique `public_id`, non-null assignment columns, and active
  pair uniqueness. It still lacks a DB check for `revoked_at >= assigned_at`; this is an
  app_zenith follow-up candidate, not part of the Avatar DB slice.
- `persona_memberships` already has reference-table role/state shape and active primary uniqueness,
  but its temporal and revoke-reason constraints need a dedicated app_zenith review before changes.

`AvatarProvisioning::Create` is the app-surface Avatar creation entry point. It creates Avatar,
Handle, app-surface `AvatarPersonaBinding`, and initial owner `AvatarAssignment` in one
transaction. `Base::App::AvatarsController#create` must remain a service caller and must not write
authority or lifecycle tables directly.

## Related

- `adr/umaxica-v1-core-resource-architecture.md`
- `adr/cross-db-reference-policy.md`
- `docs/architecture/umaxica-v1-architecture-lock.md`
