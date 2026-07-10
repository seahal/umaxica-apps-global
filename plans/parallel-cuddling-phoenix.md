# Plan: SNS Subject Resource Grill Document

## Context

The designer is planning a full SNS subject-resource layer (Organization → Account → Avatar → Group)
but the codebase has evolved separately. Key conceptual mismatches and gaps need to be documented
before implementation begins. This plan produces a single architecture audit/interrogation document
at `docs/architecture/sns-subject-resource-grill.md`.

## Evidence Gathered

From three parallel Explore agents:

### Models (models/schema agent)

- **Avatar** (`avatar` DB): has `moniker`, `active_handle_id → Handle`, `owner_organization_id`,
  `representing_organization_id`, `client_id`. Role-based via `AvatarAssignment`
  (owner/affiliation/admin/editor/viewer/reviewer) and temporal `AvatarMembership`
  (NOTHING/VIEWER/EDITOR/ADMIN roles). Social graph: AvatarFollow, AvatarBlock, AvatarMute. Posts
  attributed to Avatar.
- **Handle** (`avatar` DB): `handle` column (unique non-system), `cooldown_until`, `is_system`.
  Tracked via `HandleAssignment` (temporal valid_from/valid_to). No format constraint visible in
  model/schema beyond uniqueness.
- **AvatarMoniker** (`avatar` DB): temporal history of moniker changes
  (valid_from/valid_to=Infinity). No equivalent for Organization/Account names.
- **Persona** (`app_zenith` DB, AppRpRecord): Account for app surface. Has `moniker`,
  `client_identity_id` (unique). No handle/public identifier beyond `public_id`. Belongs to
  Enterprise via `PersonaMembership`.
- **Enterprise** (`app_zenith` DB): Organization for app surface. Has `name`, `public_id`. No
  handle. Has hierarchical `EnterpriseUnit` with closure table.
- **PersonaMembership**: connects Persona → Enterprise + EnterpriseUnit. Has temporal columns
  (starts_at/ends_at/revoked_at), membership_kind, membership_state,
  granted_by/approved_by/revoked_by. One primary constraint enforced by partial unique index.
- **Agent/Bureau/AgentMembership** (`org_zenith` DB): Org surface mirror of
  Persona/Enterprise/PersonaMembership.
- **AvatarOwnershipPeriod**: temporal record of which Organization owns an Avatar.
- **Member** (`app_principal` DB): secondary identity record under Client. has `moniker`,
  `division_id`. ClientMember is M:M between Client and Member (unexpected - Client can have
  multiple Members?).
- **ClientAccount** (`app_zenith` DB): 1:1 between Client and something in zenith - used for
  cross-DB linkage.
- **Post** (`avatar` DB): authored by Avatar (author_avatar_id). Has PostReview.
- **NO Group model exists anywhere.**
- **AvatarMembership actor_id**: FK column is `actor_id`, not `avatar_id` — unclear what Actor is
  here.

### Controllers/Routes (routes agent)

- Switcher hierarchy stored: `account_public_id`, `collective_public_id`,
  `collective_unit_public_id`, `avatar_public_id`
- AcmeSelectorSurfaceConfig maps:
  - App: Client → Persona (account) + Enterprise (org) + EnterpriseUnit (unit) → Avatar
  - Com: Visitor → Individual + Company + CompanyUnit (no Avatar)
  - Org: Operator → Agent + Bureau + BureauUnit (no Avatar)
- Routes: `/selector`, `/switcher`, `/accounts`, `/organizations`, `/avatars`,
  `/organizations/:organization_id/memberships`
- **No Group routes exist.**
- Max nesting depth: 2 levels (`/organizations/:id/memberships/:id`)
- Avatar routes use `:id` param (unclear if internal or public_id)

### Docs/Plans/ADRs (docs agent)

- Bootstrap ADR: atomically creates Account + Organization + Unit + Membership + Avatar on first
  login
- Handle candidiate rule (A-Z/a-z/0-9/max-10) mentioned by designer — not yet in code
- No mention syntax (`@handle`) in any routes/docs
- Individual/Company models (com surface) exist per surface config but were not in model agent's
  inventory
- Discussion/moderation/notification: proposed in ADR, not implemented
- Post publication: blocked on ADR for repository boundary (global vs regional)
- ADR `account-workspace-avatar-billing.md` covers Avatar billing relationship

### Critical Mismatches vs Designer's Target

1. **Hierarchy inversion**: Designer says `Organization → Account`. Code has
   `Persona (Account) → Enterprise (Organization)` via `PersonaMembership`. The Account BELONGS TO
   the Organization, not the reverse. This matters for switcher assumption.
2. **No Group model**: Designer mentions Avatar Group as a near-term requirement. Zero code exists.
3. **Handle format rules**: Designer specifies A-Z/a-z/0-9/max-10. Handle model exists but no format
   validation is visible.
4. **AvatarMembership.actor_id**: Unclear what `actor_id` refers to — not obviously an Avatar FK.
   Needs investigation.
5. **Member model ambiguity**: `Member` model and `ClientMember` (M:M Client↔Member) is unexpected.
   May be a legacy or parallel model to `Persona`.
6. **No public handles for Organization/Account**: Only Avatar has handles. Organization has `name`,
   Account (Persona) has `moniker`. No @-style public identifiers for Account or Organization.
7. **representing_organization_id on Avatar**: Not backed by temporal model like
   `AvatarOwnershipPeriod`. Purpose unclear.
8. **Display name cooldown**: AvatarMoniker has temporal tracking. No cooldown column visible on
   AvatarMoniker (cooldown is on Handle, not moniker).
9. **History records for display/handle**: Handle changes tracked via HandleAssignment (has
   `assigned_by_actor_id`). Moniker changes tracked via AvatarMoniker (has `set_by_actor_id`). But
   no `identity_id`/`account_id`/`organization_id` on these — only `actor_id` (Avatar?).

## Deliverable

Single file: `docs/architecture/sns-subject-resource-grill.md`

Sections per spec:

1. Executive summary
2. Evidence map
3. Current model inventory
4. Current relationship graph
5. Join/intermediate model inventory
6. Authority/access-control matrix
7. Switcher/current-context inventory
8. Route/controller inventory
9. Public identifier / handle / display inventory
10. Avatar Group / Group findings
11. Mention syntax questions
12. Data integrity risks
13. Authorization risks
14. Routing/API risks
15. Gaps vs target concept
16. Detailed questions for the designer (grouped by topic, 40+ specific questions)

## Constraints

- Documentation-only; no code changes
- All factual claims cite file:class/column/method
- Uncertain items marked "unknown" or "requires product decision"
- Written in English per repository language policy
- Check whether docs/architecture/ exists and if docs/index.md has a convention to follow

## Verification

After writing:

- Confirm file exists at `docs/architecture/sns-subject-resource-grill.md`
- Confirm docs/index.md updated if convention requires it
- No implementation files changed
