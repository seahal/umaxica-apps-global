# Avatar / Account Bridge Boundary

Status: proposed

## Context

`Avatar` is the canonical SNS actor. `Persona` is the concrete `app` surface Account model. The
current repository also contains `AvatarAssignment`, `AvatarMembership`, and `Member`, but those
models serve different boundaries and must not be conflated with the Avatar / Account bridge.

This ADR freezes the bridge strategy for the `Avatar -> Account` relationship. The goal is to make
the binding explicit without turning it into ownership, authority, or a shared Account abstraction.

## Decision

1. Adopt **Option D**: represent the `Avatar` / `Account` relationship with an explicit bridge
   table.
2. Do not model the relationship as a direct foreign key, ownership relation, shared Account
   abstraction, STI hierarchy, enum `kind` / `type`, or polymorphic owner.
3. Do not reuse the RP account bridge for this relationship.
4. Phase 1 is **app only**.
5. The Phase 1 concrete `Account` model is `Persona`.
6. The Phase 1 bridge is `Avatar <-> Persona`.
7. `org` future support remains a later candidate through `Agent`, but it is not part of Phase 1.
8. `com` remains Avatar-ineligible for now through `Individual`.
9. `AvatarAssignment` remains the Avatar role / posting authority model and is not expanded to
   cover the bridge.
10. `AvatarAssignment` and `AccountAssignment` stay separate and must not be merged.
11. `AvatarMembership` remains a temporal / participation / history-like model and must not be
    repurposed as the bridge.
12. `Member` remains a legacy bridge and is not destructively rewritten in this phase.
13. Bridge semantics are additive binding semantics, not authority semantics.
14. The bridge should track `assigned_at` and `revoked_at`.
15. Active bridge rows are those where `revoked_at IS NULL`.
16. The same `Avatar` / `Persona` pair must not have more than one active bridge row.
17. Revoked rows remain as history.
18. Posting authority, representative authority, and ownership must continue to live in separate
    models or policies.
19. Cross-DB foreign keys must not be introduced for this bridge.
20. The current implementation places `avatar_persona_bindings` in the avatar database.
21. The bridge table name is `AvatarPersonaBinding`.
22. Do not create a duplicate `avatar_persona_bindings` table in `app_zenith` for Phase 1.

## Bridge Semantics

The bridge is the current-state projection of a binding relationship with preserved history.

Recommended semantics:

- `assigned_at` records when the binding became active.
- `revoked_at` records when the binding was ended.
- Active rows are unique per `Avatar` / `Persona` pair.
- Historical rows remain for auditability and backfill safety.
- The bridge does not imply posting authority.
- The bridge does not imply representative authority.
- The bridge does not imply ownership.

These meanings are intentionally narrower than `AvatarAssignment` and broader than a one-off session
or transient access token.

## DB Boundary

The bridge must not cross databases with a foreign key.

Current implementation placement: avatar database.

Reasoning:

- The bridge already exists in the avatar database.
- Phase 1 is still app-only, so the bridge remains scoped to the app bootstrap flow.
- `Persona` is the Phase 1 concrete Account model, but the current storage location is not a reason
  to duplicate the table in `app_zenith`.
- Keeping the bridge singular avoids cross-database drift while the implementation remains in the
  current avatar DB.

Old placement candidate: `app_zenith`.

- This was a prior design candidate for an additive bridge table.
- It is now a future migration candidate only if the project explicitly chooses to relocate the
  existing table.
- It must not be treated as the current implementation plan.

## Bootstrap

Phase 1 bootstrap already creates the initial bridge during app signup/bootstrap, and the existing
transaction/idempotency boundary must be preserved.

Guidance:

- Initial bridge creation is the natural place to connect the bootstrap Avatar to the bootstrap
  Persona.
- The implementation must remain idempotent.
- The implementation PR should test `RecordNotUnique` handling and active unique index behavior.
- Existing bootstrap transaction shape must not be broken.
- Existing bootstrap behavior already expects one active `AvatarPersonaBinding`.

## Backfill

Do not implement a backfill strategy in this ADR.

Instead, record the required audit inputs for a later data-audit PR:

- `Avatar.client_id`
- `Avatar.member`
- `Member.client_id`
- `Persona.client_identity_id`
- `ClientIdentity.source_record_id`
- Existing bootstrap records that already pair Avatar and Persona

The backfill question is whether those records can be deterministically matched without relying on
`actor_id` semantics. This ADR does not resolve that mapping.

## Last Admin / Owner Protection

The bridge itself does not own admin or owner authority.

Protection of the last usable admin / owner path belongs in `AvatarAssignment` or a dedicated
authority policy. If bridge revocation would remove the final path to operate the Avatar, the policy
layer must guard that transition.

This ADR records the policy connection point but does not implement the policy. The policy PR should
follow the bridge data model PR and before any cleanup that could strand the last operator.

## Consequences

- The `Avatar` / `Account` relationship is explicit and additive.
- Bridge semantics stay separate from authority semantics.
- `AvatarAssignment`, `AvatarMembership`, and `Member` remain intact and uncollapsed.
- Phase 1 scope is limited to `app` and `Persona`.
- Cross-DB FK risk is avoided.
- Future `org` support can be introduced as a separate decision.

## Alternatives Considered

- Direct `Avatar -> Persona` ownership FK. Rejected because it collapses bridge semantics into
  ownership and makes the relationship too brittle for backfill and lifecycle changes.
- Shared Account abstraction or STI. Rejected because the surfaces remain concrete and
  independently evolvable.
- `AvatarAssignment` as the bridge. Rejected because authority and binding are separate concerns.
- `AvatarMembership` as the bridge. Rejected because its actor semantics remain ambiguous and
  temporal history is a different boundary.
- Rewriting `Member` destructively. Rejected because legacy compatibility must be preserved through
  an additive transition.

## Related

- `docs/architecture/avatar-account-bridge.md`
- `plans/active/avatar-account-bridge-implementation-plan.md`
- `adr/surface-account-collective-model-naming.md`
- `adr/account-workspace-avatar-billing.md`
- `docs/architecture/sns-subject-resource-decision-record.md`
