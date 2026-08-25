# Umaxica v1 Architecture Implementation Plan

> **Superseded by GitHub issue #835 (2026-07-29):** This plan is deactivated. The GitHub issue is
> authoritative for current status and scope. This file is retained under `plans/archive/` for
> historical context only.

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

Known retirement targets after Slice 4.5:

- `avatars.avatar_status_id` is legacy compatibility state; `avatars.lifecycle_state_id` is
  canonical.
- Historical avatar DB `posts` remain a legacy UGC violation; new UGC, feed, media, reaction,
  comment, and actor snapshot tables remain forbidden in avatar DB.
- `avatar_agent_bindings` and `avatar_individual_bindings` no longer have bare binding shape. They
  now match `avatar_persona_bindings` with `public_id`, `assigned_at`, `revoked_at`, revoke ordering
  checks, and active partial unique indexes.
- `avatar_assignments.role` remains constrained to the current v1 plus known legacy set: `owner`,
  `affiliation`, `administrator`, `editor`, `reviewer`, and `viewer`. Reducing that to the four-role
  target set requires a separate compatibility decision.
- `persona_assignments` and `persona_memberships` have existing active uniqueness patterns, but
  app_zenith temporal and revoke-reason constraints still need a dedicated follow-up.
- `group_avatar_memberships` does not exist yet and remains deferred to Group v1.
- `avatar_agent_bindings.agent_id` and `avatar_individual_bindings.individual_id` remain existing
  cross-DB integer references.
- `avatars.client_id` remains a legacy compatibility column. Slice 4.5 confines new compatibility
  writes to `AvatarProvisioning::Create`; it is not canonical ownership, authorization, or binding
  authority.
- `Avatar.create_with_owner` is a deprecated wrapper around `AvatarProvisioning::Create` and is a
  removal candidate after callers are retired.
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

## Slice 4.5 Remaining Avatar Creation Paths

Slice 4.5 extended `AvatarProvisioning::Create` to the remaining bootstrap creation path.

Slice 4.5 inspected:

- `app/services/base_selector_bootstrap_authority.rb`
- `app/services/avatar_provisioning/create.rb`
- `app/models/avatar.rb`
- production controller, service, job, task, seed, and test references to Avatar creation, Handle
  creation, binding creation, `AvatarAssignment` creation, and `avatars.client_id`
- `test/services/acme/selector_bootstrap_authority_test.rb`
- `test/security/invariants/umaxica_architecture_guard_test.rb`

Slice 4.5 changed:

- `BaseSelectorBootstrapAuthority` now calls `AvatarProvisioning::Create` for app-surface bootstrap
  Avatar creation.
- `Base::App::AvatarsController#create` remains a service caller.
- `Avatar.create_with_owner` delegates to `AvatarProvisioning::Create` and is deprecated.
- Architecture guards reject production `Avatar.create_with_owner`, direct `Avatar.create!`, direct
  `avatar_assignments.create!`, direct `Handle.create!`, direct surface binding `create!`, and
  direct canonical `avatars.client_id` writes outside `AvatarProvisioning::Create`.

Do not remove `avatars.client_id`, remove `avatar_status_id`, migrate historical avatar DB posts,
implement actor snapshots, implement Group v1, or move Identity-to-Account assignment authority in
this slice.

## Next Slice Entry Point After Slice 4.5

The next slice is a dry-run conflict audit for existing Avatar binding backfill. It must inventory
conflicts and produce a reviewed mutation plan before any historical rows are changed.

Before starting it, inspect:

- `app/services/avatar_provisioning/create.rb`
- `app/models/avatar.rb`
- `app/models/avatar_persona_binding.rb`
- `app/models/avatar_agent_binding.rb`
- `app/models/avatar_individual_binding.rb`
- `test/services/avatar_provisioning/create_test.rb`
- `test/models/avatar_persona_binding_test.rb`
- `test/security/invariants/avatar_authority_lifecycle_constraint_test.rb`
- `test/security/invariants/umaxica_architecture_guard_test.rb`

Open issues before backfill mutation:

- Decide whether historical app-surface Personas may have more than one active Avatar. Current
  active Persona uniqueness means additional Avatar creation requires revoking or backfilling
  bindings deliberately.
- Define the backfill conflict policy for Avatars whose legacy `client_id` points to a principal but
  whose Persona binding already exists or is inconsistent.
- Decide the dry-run output schema, owner, retention expectation, and review path before writing a
  backfill command that mutates rows.
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

## Slice 5A Legacy Avatar Client Binding Audit

Slice 5A adds a dry-run-only audit path for existing `avatars.client_id` compatibility rows:

- `AvatarBackfill::AuditLegacyClientBindings`
- `avatar_backfill:audit_legacy_client_bindings`
- default JSON report path: `tmp/avatar_backfill/legacy_client_binding_audit.json`

The audit does not create, update, revoke, archive, delete, or canonicalize any database rows. It
classifies each Avatar with a legacy `client_id` into structured review buckets, including safe
backfill candidates, already-consistent bindings, inconsistent bindings, subject conflicts, multiple
legacy Avatars for one subject, missing clients, unresolved subjects, deleted Avatar skips, legacy
UGC review, cross-DB reference errors, and unknown failures.

Only `safe_to_backfill` rows are eligible for Slice 5B. Conflicts are manual-review inputs and must
not be resolved by automatic subject selection, binding revocation, Avatar archival, or deletion.

## Slice 5B Legacy Avatar Client Binding Backfill

Slice 5B adds an idempotent backfill path for candidates that Slice 5A classifies as
`safe_to_backfill`:

- `AvatarBackfill::BackfillLegacyClientBindings`
- `avatar_backfill:legacy_client_bindings`
- default JSON report path: `tmp/avatar_backfill/legacy_client_binding_backfill.json`

The task defaults to dry-run. It mutates rows only when invoked with `APPLY=1`. The implementation
currently backfills the app-surface legacy path where `avatars.client_id` resolves to
`Client -> ClientIdentity.source_record_id -> Persona`; unresolved or ambiguous data remains in the
manual-review track. The backfill creates `AvatarPersonaBinding` with `assigned_at` from the Avatar
creation timestamp when available. It does not revoke existing active bindings, archive/delete
Avatars, remove `avatars.client_id`, or treat `avatars.client_id` as canonical authority.

Known Slice 5B compatibility remaining:

- `avatars.client_id` remains a physical compatibility column and removal candidate.
- Non-app historical rows without an unambiguous current subject resolution are manual review.
- Generated reports under `tmp/avatar_backfill/` are operational artifacts and are not committed.

## Slice 5C Operational Result

Completed against the current development database on 2026-07-03:

- Dry-run audit command:
  `bin/rails avatar_backfill:audit_legacy_client_bindings REPORT=tmp/avatar_backfill/legacy_client_binding_audit_20260703.json`
- Audit summary: 0 total Avatars, 0 Avatars with legacy `client_id`, 0 `safe_to_backfill`, and 0
  conflict or unresolved buckets.
- APPLY was not run because there were no safe candidates to mutate.
- Idempotency dry-run command:
  `bin/rails avatar_backfill:legacy_client_bindings REPORT=tmp/avatar_backfill/legacy_client_binding_backfill_dry_run_20260703.json`
- Dry-run backfill summary: 0 scanned candidates, 0 created, 0 skipped, 0 failed.

## Foundation v1 Current Status

Resolved in this pass:

- Group v1 table/model/service/controller foundation exists in the Avatar DB.
- `group_avatar_memberships` exists with active pair uniqueness, lifecycle state, and revoke-order
  constraints.
- Avatar follow/block/mute HTTP routes delegate to `AvatarSocialGraph` services and policy checks.
- `CollectiveMembership::*` service commands exist for grant, revoke, make primary, transfer unit,
  accept, and suspend.

Compatibility-only:

- `avatars.client_id`
- `avatars.avatar_status_id`
- `personas.client_identity_id`
- `agents.operator_identity_id`
- `individuals.visitor_identity_id`

Manual review required:

- Existing legacy cross-DB integer references in Avatar binding compatibility tables.
- Final request-level wiring for app/org/com membership controllers.
- Any future conflict bucket emitted by `AvatarBackfill::AuditLegacyClientBindings`.

Future content track:

- content DB, posts, comments, media, feed, timeline, ranking, recommendation, reactions, search,
  actor snapshot read model, public SNS UI.

Future moderation/eventing track:

- moderation workflow, durable moderation events, cache/event fanout design.
