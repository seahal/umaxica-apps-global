# Umaxica v1 Architecture Implementation Plan

## Status

Active

## Scope

This plan sequences implementation after the architecture lock. It does not authorize migrations,
model rewrites, controller rewrites, Group v1, Identity-to-Account direct column deletion,
`avatars.client_id` deletion, content DB creation, or UGC implementation in the architecture-lock
slice.

## Sequence

1. Architecture lock and guard rails. Completed in Slice 0.
2. Avatar lifecycle state authority. Implemented in Slice 1 as `avatar_lifecycle_states`,
   `avatars.lifecycle_state_id`, `avatar_lifecycle_events`, and `AvatarLifecycle::Transition`.
3. First DB constraint slice. Implemented in Slice 2 with Avatar DB period, revoke, lifecycle event,
   lifecycle state-key, and DB bypass invariant tests.
4. Avatar binding symmetry. Implemented in Slice 3 for persona, agent, and individual bindings.
5. `AvatarProvisioning::Create` service extraction. Implemented in Slice 4 for the app surface.
6. Existing Avatar binding backfill.
7. `CollectiveMembership` service and controller wiring.
8. Identity-to-Account assignment authority.
9. Group v1.
10. `AvatarSocialGraph` controller and policy wiring.

## Next Slice Entry Point

After Slice 1, inspect the lifecycle authority before starting the next DB constraint slice:

- `app/models/avatar.rb`
- `app/models/avatar_lifecycle_state.rb`
- `app/models/avatar_lifecycle_event.rb`
- `app/services/avatar_lifecycle.rb`
- `app/models/avatar_membership.rb`
- `db/avatars_migrate/`
- `test/models/avatar_test.rb`
- `test/models/avatar_lifecycle_state_test.rb`
- `test/services/avatar_lifecycle/transition_test.rb`
- `test/security/invariants/umaxica_architecture_guard_test.rb`

Slice 1 deliberately did not rewrite `AvatarsController#create`, did not introduce
`AvatarProvisioning::Create`, did not remove `avatars.client_id`, did not implement Group v1, and
did not create the content DB.

Known retirement targets after Slice 4:

- `avatars.avatar_status_id` is legacy compatibility state; `avatars.lifecycle_state_id` is
  canonical.
- Historical avatar DB `posts` remain a legacy UGC violation; new UGC, feed, media, reaction,
  comment, and actor snapshot tables remain forbidden in avatar DB.
- `avatar_agent_bindings` and `avatar_individual_bindings` no longer have bare binding shape. They
  now match `avatar_persona_bindings` with `public_id`, `assigned_at`, `revoked_at`, revoke
  ordering checks, and active partial unique indexes.
- `avatar_assignments.role` remains constrained to the current v1 plus known legacy set:
  `owner`, `affiliation`, `administrator`, `editor`, `reviewer`, and `viewer`. Reducing that to the
  four-role target set requires a separate compatibility decision.
- `persona_assignments` and `persona_memberships` have existing active uniqueness patterns, but
  app_zenith temporal and revoke-reason constraints still need a dedicated follow-up.
- `group_avatar_memberships` does not exist yet and remains deferred to Group v1.
- `avatar_agent_bindings.agent_id` and `avatar_individual_bindings.individual_id` remain existing
  cross-DB integer references.
- `avatars.client_id` remains a legacy compatibility column. Slice 4 confines new app-surface
  compatibility writes to `AvatarProvisioning::Create`; it is not canonical ownership,
  authorization, or binding authority.
- `avatars.avatar_status_id` remains legacy compatibility state.
- Historical avatar DB `posts` remain a legacy UGC violation.

Slice 2 added these Avatar DB constraints:

- `chk_avatar_memberships_valid_period`
- `chk_avatar_persona_bindings_revoked_after_assigned`
- `chk_avatar_lifecycle_events_state_changes`
- `fk_avatar_lifecycle_events_from_state_key`
- `fk_avatar_lifecycle_events_to_state_key`

Slice 2 verified these existing Avatar DB constraints and indexes:

- `check_avatar_assignment_role`
- `index_avatar_assignments_unique`
- `index_avatar_assignments_unique_owner`
- `index_avatar_assignments_unique_affiliation`
- `index_avatar_memberships_on_avatar_id_and_actor_id`
- `idx_avatar_persona_bindings_active_pair`
- `idx_avatar_persona_bindings_active_avatar`
- `idx_avatar_persona_bindings_active_persona`
- `index_avatar_persona_bindings_on_public_id`

## Next Slice Entry Point After Slice 2

Before Avatar binding symmetry, inspect:

- `app/models/avatar_agent_binding.rb`
- `app/models/avatar_individual_binding.rb`
- `app/models/avatar_persona_binding.rb`
- `db/avatars_migrate/20260627000002_create_avatar_account_bindings.rb`
- `test/models/avatar_persona_binding_test.rb`
- `test/security/invariants/avatar_authority_lifecycle_constraint_test.rb`

Do not start controller rewrites, `AvatarProvisioning::Create`, Group v1, Identity-to-Account
assignment authority, `avatars.client_id` removal, `avatar_status_id` removal, content DB creation,
or historical posts migration in the binding symmetry slice.

## Slice 3 Avatar Binding Symmetry

Slice 3 added these Avatar DB columns:

- `avatar_agent_bindings.public_id`
- `avatar_agent_bindings.assigned_at`
- `avatar_agent_bindings.revoked_at`
- `avatar_individual_bindings.public_id`
- `avatar_individual_bindings.assigned_at`
- `avatar_individual_bindings.revoked_at`

Slice 3 added these Avatar DB constraints and indexes:

- `chk_avatar_agent_bindings_revoked_after_assigned`
- `chk_avatar_individual_bindings_revoked_after_assigned`
- `idx_avatar_agent_bindings_active_pair`
- `idx_avatar_agent_bindings_active_avatar`
- `idx_avatar_agent_bindings_active_agent`
- `idx_avatar_individual_bindings_active_pair`
- `idx_avatar_individual_bindings_active_avatar`
- `idx_avatar_individual_bindings_active_individual`
- `index_avatar_agent_bindings_on_public_id`
- `index_avatar_individual_bindings_on_public_id`

## Next Slice Entry Point After Slice 3

Slice 4 implemented `AvatarProvisioning::Create` service extraction.

Slice 4 inspected:

- `app/controllers/base/app/avatars_controller.rb`
- `app/models/avatar.rb`
- `app/models/avatar_assignment.rb`
- `app/models/avatar_persona_binding.rb`
- `app/models/avatar_agent_binding.rb`
- `app/models/avatar_individual_binding.rb`
- `test/controllers/base/app/avatars_controller_test.rb`
- `test/security/invariants/umaxica_architecture_guard_test.rb`

Do not remove `avatars.client_id`, remove `avatar_status_id`, migrate historical avatar DB posts,
implement actor snapshots, implement Group v1, or move Identity-to-Account assignment authority in
the provisioning extraction slice.

Slice 4 added:

- `app/services/avatar_provisioning/create.rb`
- `test/services/avatar_provisioning/create_test.rb`
- app-surface controller wiring through `AvatarProvisioning::Create`
- transaction coverage for Handle conflict, invalid Avatar params, and assignment failure rollback
- architecture guard updates removing the controller-side `avatar_assignments.create!` known
  violation

After Slice 4, `Base::App::AvatarsController#create` prepares params, resolves the selected Persona,
calls `AvatarProvisioning::Create`, and renders or redirects based on the service result. It must
not directly write Avatar authority or lifecycle tables. App-surface canonical Avatar-to-Persona
binding is `AvatarPersonaBinding`. `avatars.lifecycle_state_id` remains canonical lifecycle state;
`avatars.avatar_status_id` remains legacy compatibility state.

## Next Slice Entry Point After Slice 4

The next slice is existing Avatar binding backfill.

Before starting it, inspect:

- `app/services/avatar_provisioning/create.rb`
- `app/models/avatar.rb`
- `app/models/avatar_persona_binding.rb`
- `app/models/avatar_agent_binding.rb`
- `app/models/avatar_individual_binding.rb`
- `test/services/avatar_provisioning/create_test.rb`
- `test/models/avatar_persona_binding_test.rb`
- `test/security/invariants/avatar_authority_lifecycle_constraint_test.rb`

Open issues before backfill:

- Decide whether historical app-surface Personas may have more than one active Avatar. Current
  active Persona uniqueness means additional Avatar creation requires revoking or backfilling
  bindings deliberately.
- Define the backfill conflict policy for Avatars whose legacy `client_id` points to a principal
  but whose Persona binding already exists or is inconsistent.
- Keep `avatars.client_id`, `avatars.avatar_status_id`, historical avatar DB posts,
  `avatar_agent_bindings.agent_id`, `avatar_individual_bindings.individual_id`, Identity-to-Account
  direct identity columns, membership controller stubs, missing Group v1, and missing content DB as
  known unresolved work.

## Required Guard Rails

Keep the forbidden-pattern guard current before implementation work:

- Controllers must not directly create, update, or destroy authority/lifecycle rows.
- New code must not write `avatars.client_id` as canonical ownership.
- Avatar DB must not add UGC tables.
- Avatar DB must not add actor snapshot tables.
- New cross-DB integer or bigint associations are forbidden.
