# Plan: SNS Subject Resource Grill Document

## Context

Create `docs/architecture/sns-subject-resource-grill.md` — a documentation-only architecture
interrogation and audit document. No implementation changes. The document exposes design ambiguity
before SNS subject/resource implementation begins.

## Deliverable

Single file: `docs/architecture/sns-subject-resource-grill.md`

Check whether `docs/index.md` has an architecture index convention, and add a link only if it does.

## Evidence gathered (three parallel Explore agents)

### Model inventory (app/models, db/schema)

**Identity layer (principal DBs):**

- `Client` (app_principal) — public_id, status_id, mfa_level_id; has_many avatar_assignments
- `Operator` (org_principal) — public_id, status_id, mfa_level_id
- `Visitor` (com_principal) — public_id, status_id, mfa_level_id

**Account-like layer (zenith DBs) — currently 1:1 with Identity:**

- `Persona` (app_zenith) — client_identity_id (unique FK), moniker, public_id; has_many
  persona_memberships
- `Agent` (org_zenith) — operator_identity_id (unique FK), moniker, public_id
- `Individual` (com_zenith) — visitor_identity_id (unique FK), moniker, public_id
- The `unique` constraint on identity FK means 1:1 currently. ADR notes "Identity 1:n redesign
  (future, deferred)."

**Organization-like layer (zenith DBs):**

- `Enterprise` (app_zenith) — name, public_id; includes Collective concern; has_many
  enterprise_units, persona_memberships
- `Bureau` (org_zenith) — name, public_id; includes Collective concern
- `Company` (com_zenith) — name, public_id; includes Collective concern
- `Organization` (org_principal) — separate staff hierarchy model (name, domain, operator_id,
  parent_id)

**Membership models (zenith DBs — richest join models):**

- `PersonaMembership` — persona_id, enterprise_id, enterprise_unit_id, membership_kind_id,
  membership_state_id; temporal (starts_at, ends_at, revoked_at); audit (granted_by_persona_id,
  approved_by_persona_id, revoked_by_persona_id); primary boolean
- `AgentMembership` — same pattern for Bureau
- `IndividualMembership` — same pattern for Company

**Organizational unit hierarchy:**

- `EnterpriseUnit` (app_zenith) — enterprise_id, parent_id (self-ref), name, public_id; includes
  CollectiveUnit
- `BureauUnit` (org_zenith) — same pattern
- `CompanyUnit` (com_zenith) — same pattern

**Intermediary Member model (app_principal — important gap):**

- `Member` — user_id → Client, moniker, division_id, public_id; has_many avatars (FK: client_id);
  includes Retainable
- `ClientMember` — user_id + member_id join table

**Avatar and Handle (avatar DB — cross-surface):**

- `Avatar` — public_id, moniker, active_handle_id (FK), client_id (FK to **Member**, not Persona),
  owner_organization_id (string), representing_organization_id (string), avatar_status_id; includes
  Retainable
  - has_many handle_assignments, avatar_monikers (history), avatar_memberships, avatar_assignments
  - has_many outgoing_follows/blocks/mutes (AvatarFollow/AvatarBlock/AvatarMute)
  - has*many member_avatar*\* (access, visibility, oversight, extraction, impersonation, suspension,
    deletion)
- `Handle` — handle (string, unique when is_system=false), public_id, cooldown_until,
  handle_status_id
- `HandleAssignment` — avatar_id, handle_id, assigned_by_actor_id (FK to **Avatar**), valid_from,
  valid_to; temporal
- `AvatarMoniker` — avatar_id, moniker, valid_from, valid_to, set_by_actor_id; temporal history

**Avatar RBAC models (avatar DB):**

- `AvatarAssignment` — avatar_id + user_id (FK to **Client**, not Persona); roles:
  owner/affiliation/administrator/editor/reviewer/viewer; unique (avatar_id, user_id, role); unique
  owner per avatar
- `AvatarMembership` — avatar_id + actor_id (**bigint, no FK**) + role_id (AvatarRole); temporal
  (valid_from, valid_to); granted_by_actor_id
- `AvatarRole` — fixed IDs: NOTHING=1, VIEWER=2, EDITOR=3, ADMIN=4
- `AvatarPermission` — fixed IDs: NOTHING=1, READ=2, WRITE=3, ADMIN=4
- `AvatarRolePermission` — role → permission mapping
- `AvatarOwnershipPeriod` — avatar_id, owner_organization_id (string), transferred_by_actor_id,
  temporal

**SNS interaction models (avatar DB):**

- `AvatarFollow` — follower_avatar_id ↔ followed_avatar_id (both FK to avatars)
- `AvatarBlock` — blocker_avatar_id ↔ blocked_avatar_id; reason, expires_at
- `AvatarMute` — muter_avatar_id ↔ muted_avatar_id; expires_at

**Audit (chronicle DB):**

- `Chronicle` — polymorphic actor/subject, occurred_at, event_uuid, metadata JSON
- `ClientChronicle` — subject_type/subject_id (no FK), actor_type/actor_id, occurred_at

**No Post model found in repository.** No ClientGroup/VisitorGroup/OperatorGroup found.

### Critical structural gap

Avatar connects to `Member` (app_principal) via `client_id`, not to `Persona` (app_zenith).  
`AvatarAssignment.user_id` connects to `Client` directly, not Persona.  
The confirmed target chain (Identity → Organization → Account → Avatar) is not reflected in DB FK
chains:

- Current DB: Client → Member → Avatar (app_principal + avatar DBs)
- Zenith chain: Client → Persona → Enterprise (app_zenith DB) — separate, no Avatar FK

There is no direct DB FK from Avatar to Persona/Account. The link exists only through the
selector/switcher services at runtime.

### Controller/route inventory

**Selector** (`Acme::App::SelectorsController < PreAccessController`):

- Route: `GET/PATCH/PUT /selector`
- Runs at `:private` tier during credential ceremony
- Params: account_public_id, organization_public_id, organization_unit_public_id, avatar_public_id
  (all public_ids)
- Session stores: selected_account_public_id, selected_collective_public_id,
  selected_collective_unit_public_id, selected_avatar_public_id, selected_at

**Switcher** (`Acme::App::SwitchersController < FullAccessController`):

- Route: `GET/PATCH/PUT /switcher`
- Runs post-login; atomically swaps context
- JSON response includes current context as public_ids + candidates list
- Raises `AcmeSwitcherAuthority::InvalidSwitch` on invalid attempt

**Accounts**: `GET /accounts`, `GET /accounts/:id` (public_id) — all three surfaces
(Acme::App/Com/Org)  
**Organizations**: `GET /organizations`, `GET /organizations/:id` (public_id) — all three surfaces  
**Organization Memberships**: Stubbed — all CRUD actions return 422/204/[] with no real logic  
**Avatars (app)**: `GET/POST /avatars`, `GET/PATCH/PUT /avatars/:id` — uses switcher-scoped lookup  
**Avatar (org)**: `GET/PATCH/PUT/DELETE /avatar` (singular current avatar)  
**Profile (palm)**: `GET /api/v0/profile` — returns actor type + public_id

**No routes for:** follows, blocks, mutes, posts, handles, handle changes, moniker changes, group
management.

### Policy inventory

All SNS policies are empty stubs inheriting `ApplicationPolicy`: AvatarPolicy,
AvatarMembershipPolicy, HandlePolicy, HandleAssignmentPolicy, AvatarFollowPolicy, AvatarBlockPolicy,
AvatarMutePolicy, AccountPolicy, OrganizationPolicy.

### Docs/ADRs/plans inventory

- `docs/dictionary/identity-account-organization-avatar.md` — confirms surface-specific naming
- `adr/collective-hierarchy-model.md` — Collective as accepted domain name
- `adr/surface-account-collective-model-naming.md` — surface→model mapping table
- `adr/acme-account-organization-bootstrap-boundary.md` — bootstrap creates Account + Organization
  atomically
- `adr/acme-account-organization-resource-boundary.md` — title attribute plan, quota enforcement (10
  Accounts/Identity, 2 Organizations/Identity)
- `adr/actor-current-facade.md` — Actor as immutable request-local context container
- `docs/architecture/current_context.md` — lifecycle of set_current_context / set_current_actor
- `docs/architecture/database-boundaries.md` — multi-DB surface boundaries
- `plans/active/acme-account-organization-bootstrap-implementation-plan.md` — docs-only freeze;
  planned PRs include title migration, quota enforcement, Identity 1:n redesign (deferred)

### Key ambiguities for the document

1. **actor_id ambiguity**: AvatarMembership.actor_id has no FK — unknown referent (Avatar? Client?
   Persona?)
2. **AvatarAssignment vs AvatarMembership**: Two parallel RBAC models with unclear boundary
3. **Avatar → Member gap**: Avatar.client_id → Member, not Persona — the confirmed Account→Avatar
   chain is not enforced in DB
4. **representing_organization_id type**: stored as string on Avatar — is this public_id or name?
5. **owner_organization_id type**: also string on Avatar and AvatarOwnershipPeriod — same question
6. **Moniker vs display**: `moniker` column exists on Persona/Agent/Individual/Avatar/Member;
   product uses "display" — no `display` column anywhere
7. **Handle uniqueness**: Handle.handle is unique when is_system=false; case-sensitivity not
   confirmed
8. **Handle format rule**: designer says A-Z/a-z/0-9, max 10 chars — not confirmed in code evidence
9. **No Post model**: SNS posting capability exists in schema design but no Post model found
10. **Organization membership stubs**: All membership controllers are stubs returning 422/204
11. **No Group model**: ClientGroup/VisitorGroup/OperatorGroup not present
12. **Cooldown**: cooldown_until on Handle; no cooldown on AvatarMoniker confirmed
13. **Persona 1:1 constraint**: unique FK means one Persona per Client — contradicts multi-account
    design
14. **No follow/block/mute routes**: Models exist, no controllers or routes
15. **Member model role**: Member (app_principal) intermediates Client → Avatar but is not the
    Account concept (Persona is)

## Document structure

The document will follow exactly the section structure specified in the task:

1. Executive summary
2. Confirmed design decisions (table)
3. Evidence map
4. Current model inventory
5. Current relationship graph (actual vs target)
6. Join/intermediate model inventory
7. AvatarAssignment vs AvatarMembership subsection
8. Authority/access-control matrix
9. Switcher/current-context inventory
10. Route/controller inventory
11. Public identifier / handle / display / moniker inventory
12. Moniker/display terminology decision
13. Handle/display history and cooldown interrogation
14. Actor ambiguity section
15. Group findings
16. Mention syntax questions
17. SNS subject model interrogation
18. Data integrity risks
19. Authorization risks
20. Routing/API risks
21. Multi-surface vocabulary
22. Gaps vs confirmed target (table)
23. Detailed questions for the designer (largest section, Q01–Q50+)
24. Top product/architecture decisions (20+ forced-choice)
25. Recommended implementation sequence

## Approach

1. Verify `docs/architecture/` exists and `docs/index.md` index convention
2. Write `docs/architecture/sns-subject-resource-grill.md` with full evidence-backed content
3. Add link to `docs/index.md` only if index convention is clearly present
4. Run validation: confirm only doc files changed, all claims cite evidence, uncertain items marked

## Constraints

- Documentation only. No model, migration, controller, route, policy, service, or test changes.
- Every factual claim cites a file path, class name, column, association, or migration.
- Uncertain items marked: "unknown", "not represented yet", "requires product decision", "repository
  evidence insufficient".
- Do not claim Group exists. Do not claim display is separate from moniker. Do not claim actor_id
  means Avatar.
- Do not treat public_id / handle / slug / code / internal id as interchangeable.
