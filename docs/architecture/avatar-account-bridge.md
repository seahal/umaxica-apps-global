# Avatar / Account Bridge

This document summarizes the accepted `Avatar -> Account` bridge boundary for implementation
planning.

## Summary

- `Avatar` remains the canonical SNS actor.
- `Persona` is the Phase 1 `app` Account model.
- `AvatarPersonaBinding` already exists.
- The bridge is explicit and additive.
- `AvatarAssignment` remains the Avatar authority model.
- `AvatarMembership` remains a temporal / participation / history model.
- `Member` remains a legacy bridge.
- Phase 1 is app only.
- `com` remains Avatar-ineligible.
- `org` is deferred as a later candidate.
- Current app bootstrap creates one `AvatarPersonaBinding`.
- `com` and `org` do not create `Avatar` records at present.

## Current Implementation Facts

- `Avatar` has_one `:avatar_persona_binding`.
- `Persona` has_one `:avatar_persona_binding`.
- `AvatarPersonaBinding` is stored in the avatar database today.
- `avatar_id` and `persona_id` are both unique.
- No explicit foreign keys are declared for the bridge table.
- `AcmeSelectorBootstrapAuthority#bind_avatar_account!` creates the binding during app bootstrap.
- `AcmeSelectorSurfaceConfig` marks the app surface as `requires_avatar: true`.
- Existing tests expect `AvatarPersonaBinding.count == 1` after app bootstrap.

## Bridge Shape

Recommended bridge table: `AvatarPersonaBinding`.

Recommended semantics:

- `assigned_at` marks activation.
- `revoked_at` marks deactivation.
- Active rows are those with `revoked_at IS NULL`.
- A single `Avatar` / `Persona` pair may have only one active row.
- Historical revoked rows remain in place.

This bridge records association / binding, not ownership or authority.

## Database Placement

Current implementation placement: avatar database.

Reasoning:

- The table already exists in the avatar database.
- The implementation does not currently duplicate the table in `app_zenith`.
- Phase 1 remains app-only, so the bootstrap flow can create the binding without changing storage
  placement.
- Cross-DB foreign keys are still avoided.

Historical candidate: `app_zenith`.

- This was the earlier additive-bridge placement idea.
- Treat it as a future relocation candidate only if the existing table is intentionally moved.
- Do not interpret it as a requirement to create a second copy of the table.

## Bootstrap

The initial app signup/bootstrap flow already creates the initial `AvatarPersonaBinding`, and that
behavior must remain idempotent without breaking the existing transaction boundary.

The implementation PR should verify:

- idempotent bootstrap behavior
- `RecordNotUnique` handling
- active unique index behavior

## Backfill Inputs

A later data-audit PR should determine whether existing records can be matched using:

- `Avatar.client_id`
- `Avatar.member`
- `Member.client_id`
- `Persona.client_identity_id`
- `ClientIdentity.source_record_id`
- existing bootstrap pairings

`actor_id` remains ambiguous legacy naming and is not the bridge key for this work.

The bridge path to record is `Avatar -> Persona` through `AvatarPersonaBinding`.

## Boundaries

- `AvatarAssignment` is not expanded to cover this bridge.
- `AvatarMembership` is not repurposed as the bridge.
- `Member` is not destructively rewritten in Phase 1.
- `AccountAssignment` stays separate from `AvatarAssignment`.
- No shared Account abstraction, STI, enum `kind` / `type`, or polymorphic owner is introduced.
- No duplicate `avatar_persona_bindings` table is added to `app_zenith`.

## Related

- `adr/avatar-account-bridge-boundary.md`
- `plans/active/avatar-account-bridge-implementation-plan.md`
- `adr/surface-account-collective-model-naming.md`
- `docs/architecture/sns-subject-resource-decision-record.md`
