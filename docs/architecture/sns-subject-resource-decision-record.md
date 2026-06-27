# SNS Subject Resource Decision Record

## Executive Summary

This document narrows the next implementation path for the SNS subject/resource work. It confirms
the current baseline from the grill audit, chooses a default bridge strategy for `Avatar` ownership,
and records the remaining gaps that must stay unresolved until the graph is aligned.

The main decisions are:

- Keep `Avatar` as the canonical SNS actor.
- Treat `Account -> Organization` as a required invariant, not a soft convention.
- Prefer a bridge-based transition for `Avatar` ownership rather than a destructive rewrite of the
  current `Member` path.
- Treat `AvatarAssignment` as authority-oriented and `AvatarMembership` as a separate
  participation/history concept until the boundary is proven.
- Treat `actor_id` as ambiguous legacy naming for now and avoid relying on it as the sole audit
  identity.
- Scope `ClientGroup` v1 as an `Avatar` container only, not a posting actor.
- Keep representative authority separate from posting authority.
- Preserve temporal history and cooldown behavior for handle and moniker changes.
- Prohibit last admin/owner removal, demotion, or revocation for managed resources.

## Source Documents

- [docs/architecture/sns-subject-resource-grill.md](/home/global/workspace/docs/architecture/sns-subject-resource-grill.md)
- [docs/index.md](/home/global/workspace/docs/index.md)
- [app/models/avatar.rb](/home/global/workspace/app/models/avatar.rb)
- [app/models/avatar_assignment.rb](/home/global/workspace/app/models/avatar_assignment.rb)
- [app/models/avatar_membership.rb](/home/global/workspace/app/models/avatar_membership.rb)
- [app/models/handle_assignment.rb](/home/global/workspace/app/models/handle_assignment.rb)
- [app/models/avatar_moniker.rb](/home/global/workspace/app/models/avatar_moniker.rb)
- [app/models/persona.rb](/home/global/workspace/app/models/persona.rb)
- [app/models/persona_membership.rb](/home/global/workspace/app/models/persona_membership.rb)
- [app/models/member.rb](/home/global/workspace/app/models/member.rb)
- [app/models/client_account.rb](/home/global/workspace/app/models/client_account.rb)
- [app/models/client.rb](/home/global/workspace/app/models/client.rb)
- [app/models/enterprise.rb](/home/global/workspace/app/models/enterprise.rb)
- [db/avatars_migrate/20251225200010_create_avatar_identity_core_tables.rb](/home/global/workspace/db/avatars_migrate/20251225200010_create_avatar_identity_core_tables.rb)

## Confirmed Baseline

- `Avatar` is the canonical SNS actor. The grill audit shows `Avatar` owns handles, handle
  assignments, monikers, memberships, ownership periods, and social edges. Evidence:
  [app/models/avatar.rb](/home/global/workspace/app/models/avatar.rb),
  [docs/architecture/sns-subject-resource-grill.md](/home/global/workspace/docs/architecture/sns-subject-resource-grill.md).
- `Account` requires `Organization`. The current repository expresses this as a membership-based
  graph in the account layer, not as a direct FK from `Avatar`. Evidence:
  [app/models/persona.rb](/home/global/workspace/app/models/persona.rb),
  [app/models/persona_membership.rb](/home/global/workspace/app/models/persona_membership.rb),
  [docs/architecture/sns-subject-resource-grill.md](/home/global/workspace/docs/architecture/sns-subject-resource-grill.md).
- `Avatar` requires `Account`. The target is not yet structurally enforced; current evidence still
  shows `Avatar -> Member/Client`. Evidence:
  [app/models/avatar.rb](/home/global/workspace/app/models/avatar.rb),
  [app/models/member.rb](/home/global/workspace/app/models/member.rb),
  [docs/architecture/sns-subject-resource-grill.md](/home/global/workspace/docs/architecture/sns-subject-resource-grill.md).
- `Group` is an `Avatar` container, not a posting actor. No group model currently exists. Evidence:
  [docs/architecture/sns-subject-resource-grill.md](/home/global/workspace/docs/architecture/sns-subject-resource-grill.md),
  [db/avatars_migrate/20251225200010_create_avatar_identity_core_tables.rb](/home/global/workspace/db/avatars_migrate/20251225200010_create_avatar_identity_core_tables.rb).
- `ClientGroup` / `VisitorGroup` / `OperatorGroup` are the preferred surface-specific model names
  for the future group family. No model exists yet. Evidence:
  [docs/architecture/sns-subject-resource-grill.md](/home/global/workspace/docs/architecture/sns-subject-resource-grill.md).
- `@handle` is Avatar-only for now. Evidence:
  [app/models/handle.rb](/home/global/workspace/app/models/handle.rb),
  [app/models/handle_assignment.rb](/home/global/workspace/app/models/handle_assignment.rb),
  [docs/architecture/sns-subject-resource-grill.md](/home/global/workspace/docs/architecture/sns-subject-resource-grill.md).
- `id`, `public_id`, `handle`, and `display`/`moniker` are separate concepts. Evidence:
  [app/models/avatar.rb](/home/global/workspace/app/models/avatar.rb),
  [app/models/handle.rb](/home/global/workspace/app/models/handle.rb),
  [app/models/avatar_moniker.rb](/home/global/workspace/app/models/avatar_moniker.rb).
- Posting authority and representative authority are separate. The repository exposes
  `representing_organization_id`, but its exact semantics are not yet proven. Evidence:
  [app/models/avatar.rb](/home/global/workspace/app/models/avatar.rb),
  [docs/architecture/sns-subject-resource-grill.md](/home/global/workspace/docs/architecture/sns-subject-resource-grill.md).
- Permission inheritance is not part of the initial implementation target. Evidence: current Avatar
  RBAC is flat in
  [app/models/avatar_assignment.rb](/home/global/workspace/app/models/avatar_assignment.rb) and no
  inheritance model appears in the grill audit.
- Handle changes should have 24-hour cooldown and immutable history. The repository already has
  `cooldown_until` and temporal handle assignment rows, but not the full product rule yet. Evidence:
  [app/models/handle.rb](/home/global/workspace/app/models/handle.rb),
  [app/models/handle_assignment.rb](/home/global/workspace/app/models/handle_assignment.rb),
  [db/avatars_migrate/20251225200010_create_avatar_identity_core_tables.rb](/home/global/workspace/db/avatars_migrate/20251225200010_create_avatar_identity_core_tables.rb).
- Moniker changes should have 24-hour cooldown and immutable history. The repository already has
  temporal moniker rows, but not a cooldown column. Evidence:
  [app/models/avatar_moniker.rb](/home/global/workspace/app/models/avatar_moniker.rb),
  [db/avatars_migrate/20251225200010_create_avatar_identity_core_tables.rb](/home/global/workspace/db/avatars_migrate/20251225200010_create_avatar_identity_core_tables.rb).
- Last admin/owner removal, demotion, or revocation should be prohibited. The repository has
  owner/admin-style assignment tables, but the last-admin invariant is not clearly enforced yet.
  Evidence: [app/models/avatar.rb](/home/global/workspace/app/models/avatar.rb),
  [app/models/avatar_assignment.rb](/home/global/workspace/app/models/avatar_assignment.rb),
  [docs/architecture/sns-subject-resource-grill.md](/home/global/workspace/docs/architecture/sns-subject-resource-grill.md).

## Decision 1: Avatar-to-Account Attachment Strategy

Decision: prefer a bridge-based transition rather than a direct destructive rewrite of the current
`Member` path.

Chosen default: **Option C**

- Add a new bridge model between `Account`/`Persona` and `Avatar` while preserving `Member` for
  legacy/principal linkage.

Why this is the safest default:

- The confirmed target requires `Organization -> Account -> Avatar`.
- The current repository still uses `Avatar -> Member/Client`, so the existing path cannot be
  treated as already aligned.
- A bridge model can absorb backfill and compatibility work without forcing an immediate
  schema-level cutover.

Current evidence:

- `Avatar` currently belongs to `member` through `client_id`. Evidence:
  [app/models/avatar.rb](/home/global/workspace/app/models/avatar.rb).
- `Member` is a real domain model, not just a placeholder. Evidence:
  [app/models/member.rb](/home/global/workspace/app/models/member.rb).
- `Persona` already represents an account-like model in the RP layer and participates in
  organization membership. Evidence:
  [app/models/persona.rb](/home/global/workspace/app/models/persona.rb),
  [app/models/persona_membership.rb](/home/global/workspace/app/models/persona_membership.rb).

Open questions that still need implementation design:

- Whether the bridge should attach to `Persona`, `Account`, or a future shared abstraction.
- Whether the bridge can coexist with `Member` long enough for backfill and read-path migration.
- Whether a direct `Avatar -> Persona` FK would cross current database boundaries.

## Decision 2: Account-to-Organization Enforcement Strategy

Decision: prefer a hybrid invariant enforcement model.

Chosen default: **Option D**

- Use the existing membership model as the authority, plus database constraints and indexes for the
  required primary membership relationship where the schema supports it.

Why this is the safest default:

- The target disallows organization-less accounts.
- The repository already expresses account-to-organization linkage through membership patterns,
  especially `PersonaMembership`.
- Pure service enforcement is too weak for a core structural invariant.
- A direct FK alone may not fit the current multi-surface membership model.

Current evidence:

- `PersonaMembership` links `persona_id` to `enterprise_id` and `enterprise_unit_id`, with a unique
  partial index for one active primary membership. Evidence:
  [app/models/persona_membership.rb](/home/global/workspace/app/models/persona_membership.rb).
- `Persona` is the current account-like model in the RP layer. Evidence:
  [app/models/persona.rb](/home/global/workspace/app/models/persona.rb).
- `Enterprise` is the organization-like model in the RP layer. Evidence:
  [app/models/enterprise.rb](/home/global/workspace/app/models/enterprise.rb).

Open questions that still need implementation design:

- Whether one primary organization is mandatory for every account-like record.
- Whether multiple organizations may be associated with one account, and if so which one is
  authoritative.
- Whether the same enforcement pattern should be mirrored across `Persona` / `Enterprise`, `Agent` /
  `Bureau`, and `Individual` / `Company`.

## Decision 3: AvatarAssignment vs AvatarMembership Boundary

Decision: prefer `AvatarAssignment` as the authority model and keep `AvatarMembership` as a separate
participation/history concept unless later evidence proves otherwise.

Chosen default: **Option A**

- `AvatarAssignment` is authority-oriented.
- `AvatarMembership` is not the primary authority model for account-to-avatar access.

Why this is the safest default:

- The current code shows `AvatarAssignment` as role-based access control with explicit roles.
- `AvatarMembership` has temporal rows and an `actor_id`, but its referent is not yet clear enough
  to use as the primary authority bridge.
- Keeping the models separate avoids baking ambiguous semantics into group authorization.

Current evidence:

- `AvatarAssignment` stores owner/affiliation/administrator/editor/reviewer/viewer roles and is used
  through `Avatar`. Evidence: [app/models/avatar.rb](/home/global/workspace/app/models/avatar.rb),
  [app/models/avatar_assignment.rb](/home/global/workspace/app/models/avatar_assignment.rb).
- `AvatarMembership` stores temporal rows with `actor_id`, `role_id`, `valid_from`, and `valid_to`.
  Evidence:
  [app/models/avatar_membership.rb](/home/global/workspace/app/models/avatar_membership.rb),
  [db/avatars_migrate/20251225200010_create_avatar_identity_core_tables.rb](/home/global/workspace/db/avatars_migrate/20251225200010_create_avatar_identity_core_tables.rb).

Open questions that still need implementation design:

- Which model controllers and services use today for any live permission checks.
- Which model should carry posting authority, if any future posting flow needs it.
- Whether `AvatarMembership` should remain a history layer or become a deprecated legacy table.

## Decision 4: actor_id Semantics

Decision: treat `actor_id` as ambiguous legacy naming for immediate implementation safety.

Chosen default: **Option C**

- Do not rely on `actor_id` alone for new audit requirements until its referent is proven table by
  table.

Why this is the safest default:

- The audit/history requirements need clear identity, account, and organization context.
- The repository already shows mixed `actor_id` usage across several tables and models.
- Some records include `actor_id` without a proven FK target, so the column cannot be assumed to
  mean `Avatar`.

Current evidence:

- `AvatarMembership` contains `actor_id` with no FK shown in the schema comment. Evidence:
  [app/models/avatar_membership.rb](/home/global/workspace/app/models/avatar_membership.rb).
- `HandleAssignment` contains `assigned_by_actor_id`, which is linked to `Avatar` in the model.
  Evidence:
  [app/models/handle_assignment.rb](/home/global/workspace/app/models/handle_assignment.rb).
- `AvatarMoniker` contains `set_by_actor_id`, but the schema comment does not prove the referent.
  Evidence: [app/models/avatar_moniker.rb](/home/global/workspace/app/models/avatar_moniker.rb).
- `PersonaMembership` uses `granted_by_persona_id`, `approved_by_persona_id`, and
  `revoked_by_persona_id`, which are explicit about their subject model. Evidence:
  [app/models/persona_membership.rb](/home/global/workspace/app/models/persona_membership.rb).

Implementation guidance for later stages:

- New audit records should prefer explicit foreign-key names over generic `actor_id` when the
  subject matters.
- If a system actor must be recorded, it should be represented explicitly rather than inferred from
  a legacy column.

## Decision 5: ClientGroup v1 Scope

Decision: scope `ClientGroup` v1 as a managed `Avatar` container only.

Chosen default: **Option A**

- A `ClientGroup` contains `Avatar` records within one account only.

Why this is the safest default:

- The current `Account -> Avatar` graph is not yet structurally enforced.
- Cross-account and cross-organization grouping would create a larger authorization problem than the
  current model can safely absorb.
- An account-scoped first version keeps the boundary clear while leaving room for later
  `VisitorGroup` and `OperatorGroup` variants.

Current evidence:

- No `ClientGroup`, `VisitorGroup`, or `OperatorGroup` model exists in the repository evidence
  reviewed for the grill audit.
- `Avatar` already has ownership and membership-style records, so a group container would be a new
  concept rather than a rename. Evidence:
  [app/models/avatar.rb](/home/global/workspace/app/models/avatar.rb),
  [app/models/avatar_membership.rb](/home/global/workspace/app/models/avatar_membership.rb).

Open questions that still need implementation design:

- Whether `ClientGroup` should have `public_id` and `moniker` from day one.
- Whether `ClientGroup` should have a handle. The current recommendation is no for v1.
- Whether an avatar may belong to multiple client groups.
- Whether empty groups are allowed.
- Whether a group can be deleted and what happens when the last avatar leaves.

## Decision 6: Representative Authority vs Posting Authority

Decision: keep representative authority separate from posting authority.

Chosen default: **Option B + D**

- Treat them as separate explicit capabilities.
- Require temporal auditability for representation changes if and when the feature is implemented.

Why this is the safest default:

- The repository exposes `representing_organization_id`, but its semantics are not yet proven.
- Representative authority is high-risk and should not be collapsed into ordinary posting
  permission.

Current evidence:

- `Avatar` has `representing_organization_id` and `owner_organization_id` string columns. Evidence:
  [app/models/avatar.rb](/home/global/workspace/app/models/avatar.rb),
  [db/avatars_migrate/20251225200010_create_avatar_identity_core_tables.rb](/home/global/workspace/db/avatars_migrate/20251225200010_create_avatar_identity_core_tables.rb).
- No `Post` model exists in the repository evidence reviewed for the grill audit, so posting
  authority remains a design target only. Evidence:
  [docs/architecture/sns-subject-resource-grill.md](/home/global/workspace/docs/architecture/sns-subject-resource-grill.md),
  [db/avatars_migrate/20251225200010_create_avatar_identity_core_tables.rb](/home/global/workspace/db/avatars_migrate/20251225200010_create_avatar_identity_core_tables.rb).

Open questions that still need implementation design:

- Whether representation belongs in a history model rather than a string column.
- Whether representation changes require step-up authentication.
- Whether posting as an avatar should imply representative authority. The current answer is no until
  proven otherwise.

## Decision 7: Handle and Moniker Cooldown/History

Decision: preserve the current temporal pattern and align it with the product rule for cooldowns.

Chosen default: **Option A + C**

- Use the existing `Handle` / `HandleAssignment` and `AvatarMoniker` history rows as the source of
  truth for current and historical values.
- Keep current values denormalized where needed, but treat the temporal rows as the history record.

Why this is the safest default:

- The repository already has handle and moniker history structures.
- The product target requires both immutable history and 24-hour cooldowns.
- Adding parallel history tables would create unnecessary duplication unless the current structures
  are insufficient.

Current evidence:

- `Handle` has `cooldown_until`, `handle`, `public_id`, and `is_system`. Evidence:
  [app/models/handle.rb](/home/global/workspace/app/models/handle.rb),
  [db/avatars_migrate/20251225200010_create_avatar_identity_core_tables.rb](/home/global/workspace/db/avatars_migrate/20251225200010_create_avatar_identity_core_tables.rb).
- `HandleAssignment` tracks `valid_from` / `valid_to` and the assigning avatar. Evidence:
  [app/models/handle_assignment.rb](/home/global/workspace/app/models/handle_assignment.rb).
- `AvatarMoniker` tracks `valid_from` / `valid_to` and the setting actor column. Evidence:
  [app/models/avatar_moniker.rb](/home/global/workspace/app/models/avatar_moniker.rb).

Open questions that still need implementation design:

- Whether the 24-hour rule is already enforced elsewhere or still needs explicit model/service
  validation.
- Whether old handles must remain reserved forever.
- Whether handle uniqueness must remain case-insensitive across all future write paths.
- Whether moniker cooldowns need to exist before any UI change form is exposed.

## Decision 8: Last Admin/Owner Protection

Decision: protect managed resources with transactional checks and row locking.

Chosen default: **Option C**

- Use service-level checks inside a transaction, with row locking where necessary to prevent
  concurrent loss of control.

Why this is the safest default:

- The invariant is cross-row and can be violated by concurrent updates.
- DB constraints alone are usually not expressive enough for “last remaining admin/owner” style
  rules.
- Background repair is not a primary safeguard for a correctness invariant.

Current evidence:

- `Avatar` exposes owner/admin-style assignment associations. Evidence:
  [app/models/avatar.rb](/home/global/workspace/app/models/avatar.rb).
- `AvatarAssignment` has unique owner and affiliation constraints, but no explicit last-owner
  invariant. Evidence:
  [app/models/avatar_assignment.rb](/home/global/workspace/app/models/avatar_assignment.rb).
- `PersonaMembership` enforces one active primary membership per persona, which is related but not
  the same as last-admin protection. Evidence:
  [app/models/persona_membership.rb](/home/global/workspace/app/models/persona_membership.rb).

Open questions that still need implementation design:

- Which managed resources are in scope first.
- Which roles count as admin/owner for each resource type.
- Whether recovery or system overrides are allowed.
- How concurrency should be handled when multiple demotions or revocations happen at once.

## Decision 9: Switcher Current Context Contract

Decision: keep the hierarchical current-context contract, but require server-side revalidation for
every request.

Chosen default: **Option A**

- Prefer the existing public-id session approach where it already exists, and revalidate the
  selected context against the database on each request.

Why this is the safest default:

- The UX already carries hierarchical `account_public_id`, `organization_public_id`,
  `organization_unit_public_id`, and optional `avatar_public_id`.
- The session or selector state should not be trusted without DB confirmation.

Current evidence:

- The selector and switcher flow already pass hierarchical public IDs in the repository. Evidence:
  [docs/architecture/sns-subject-resource-grill.md](/home/global/workspace/docs/architecture/sns-subject-resource-grill.md).

Open questions that still need implementation design:

- What exact values the selector and switcher persist.
- Whether future group selection should be independent from avatar selection.
- Whether APIs should accept context explicitly or derive it from session state.

## Decision 10: Implementation Order

Implement in this order:

1. Stabilize terminology in docs.
2. Decide the bridge strategy for `Avatar -> Account`.
3. Decide `Account -> Organization` enforcement and backfill.
4. Clarify `AvatarAssignment` versus `AvatarMembership`.
5. Clarify `actor_id` audit semantics.
6. Add tests and design for last admin/owner protection.
7. Add the `ClientGroup` design document.
8. Only then implement migrations, models, and policies.
9. Keep `Post` out of scope until the avatar actor and group boundary are stable.

## Gaps Intentionally Left Unresolved

These items are intentionally not implemented by this decision record:

- `Post` model
- Group as a posting actor
- `@@group` mention syntax
- `Account` / `Organization` mention syntax
- Permission inheritance
- `VisitorGroup` / `OperatorGroup` implementation
- public group handle
- cross-organization `ClientGroup`
- representative history model, unless later implementation needs it

## Implementation Notes

This document is a decision record, not a code change. It deliberately chooses safe defaults where
the repository evidence is incomplete and leaves the remaining questions visible so the next
implementation step can be smaller and more explicit.
