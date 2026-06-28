# ADR: Decompose Member, ClientMembership, and Organization Before Placement Migration

## Status

Accepted

## Context

`principal` is retained compatibility storage and is not required to become empty. It is no longer
canonical authority storage merely because of its name, and it may later host regional-ready
application data before any later regional extraction.

`zenith` is the target canonical placement for Principal / Identity / Account / Organization
authority data.

`Member`, `ClientMembership`, and `Organization` are the highest-risk ambiguous placement cluster
in the current codebase. Their current storage does not determine semantic ownership. Each model
mixes authority-like, bridge, transitional, lifecycle, and in some cases regional-ready concerns.
Moving any of them wholesale would risk moving non-authority operational state into `zenith` or
leaving authority state incorrectly in `principal`.

### Member

`Member` currently lives in `app_principal`. It includes `Account`, belongs to `Client`, overlaps
with the `Persona` account direction, and links into legacy Avatar governance and client-member
history. It therefore contains account-authority, bridge, and retained-principal compatibility
portions, but those portions are not yet decomposed.

### ClientMembership

`ClientMembership` currently lives in `app_principal`. It joins `Client` to a raw `workspace_id`
and stores `joined_at` / `left_at`. It overlaps only loosely with `PersonaMembership` and does not
equal `PersonaAssignment`. Its `workspace_id` meaning must be resolved before any placement
decision.

### Organization

`Organization` currently lives in `org_principal`. It has organization-authority shape and legacy
workspace/container responsibilities. Its authority portion may later map toward `Bureau`, while
its operational/container portion may remain retained `principal`-side or become future regional
application state, but that split is not established yet.

### Runtime actors

`Client`, `Visitor`, and `Operator` are mixed runtime actor rows. They own or link
credential/contact/recovery/lifecycle/session-adjacent state and must not be moved wholesale to
`zenith`.

### Out of scope

Avatar relocation, Avatar social graph changes, ticket/session/ceremony/logout/OAuth transaction
migration, preference/settings migration, schema changes, table movement, and any controller,
service, route, or behavior change are out of scope for this ADR.

## Decision

Before any placement migration involving `Member`, `ClientMembership`, or `Organization`:

1. The models must be decomposed by semantic responsibility.
2. Authority portions must be mapped to `zenith`-side canonical models where appropriate.
3. Compatibility or operational portions may remain in retained `principal`.
4. Regional-ready portions may remain in retained `principal` until later regional extraction.
5. No wholesale table movement is allowed for these models.
6. Any actual migration requires a later ADR and migration plan.

### Model-specific decisions

#### Member

- Do not move `Member` wholesale to `zenith`.
- Treat `Member` as transitional.
- Decide later whether it decomposes, retires, remains as compatibility storage, or maps account
  authority portions toward `Persona`.
- Treat Avatar-governance and legacy bridge portions separately from account-authority portions.

#### ClientMembership

- Do not move `ClientMembership` wholesale to `zenith`.
- Treat `ClientMembership` as transitional membership / bridge state.
- Resolve `workspace_id` meaning before any migration.
- Decide later whether it maps to `PersonaMembership`, regional membership, or a compatibility
  bridge.

#### Organization

- Do not move `Organization` wholesale to `zenith`.
- Treat `Organization` as organization_authority / regional_ready / transitional.
- Separate authority hierarchy semantics from operational workspace/container semantics.
- Decide later whether authority portions map toward `Bureau` or another `zenith` organization
  model, and whether operational portions remain retained `principal` or future regional data.

#### Runtime actors

- Do not move `Client`, `Visitor`, or `Operator` wholesale to `zenith`.
- Decompose runtime actor, authority binding, credential/contact/recovery, lifecycle, and
  session-adjacent responsibilities first.

#### OIDC connection rows

- Audit OIDC connection rows separately from OAuth transaction rows.
- Do not settle their placement in this ADR.

## Consequences

### Positive

- Avoids unsafe wholesale movement of mixed-responsibility models.
- Preserves the `zenith` authority target without overloading it with operational state.
- Preserves retained `principal` as useful compatibility and regional-ready storage.
- Makes future migrations smaller and more reversible.
- Forces `workspace_id` and legacy bridge semantics to be resolved explicitly.

### Negative

- Delays table movement.
- Requires more documentation before implementation.
- Leaves some ambiguity unresolved temporarily.
- May require bridge or projection layers during migration.

### Operational consequences

- Future implementation work must be table-by-table or responsibility-by-responsibility.
- Tests and constraints must be designed after decomposition decisions.
- Any new models must be classified before placement.

## Alternatives Considered

1. Move `Member`, `ClientMembership`, and `Organization` wholesale to `zenith`.
   Rejected: they contain mixed transitional and operational concerns, and wholesale movement could
   move non-authority state into canonical authority storage.

2. Leave everything in `principal` permanently.
   Rejected: `principal` is no longer canonical authority storage, and this would keep authority
   placement ambiguous while blocking future regional extraction.

3. Empty `principal` completely.
   Rejected: `principal` is retained compatibility storage and may host regional-ready application
   data. Emptying it is not required and would create unnecessary churn.

4. Immediately create regional databases.
   Rejected for now: regional extraction should happen after classification and decomposition.
   `principal` can serve as a retained regional-ready staging boundary first.

5. Treat `ClientMembership` as equivalent to `PersonaMembership`.
   Rejected: `ClientMembership` uses raw `workspace_id` and lacks `PersonaMembership`'s current
   account-to-enterprise/unit semantics.

6. Treat `Organization` as directly equivalent to `Bureau`.
   Rejected or deferred: `Organization` has legacy `org_principal` workspace/container semantics
   that must be separated before mapping.

## Placement Rules Established by This ADR

| item | rule |
| --- | --- |
| Member | transitional; no wholesale move; decompose before placement |
| ClientMembership | transitional membership / bridge; resolve `workspace_id` before placement |
| Organization | decompose authority hierarchy vs operational container before placement |
| Client / Visitor / Operator | decompose runtime actor vs authority / credential / lifecycle / session responsibilities |
| OIDC connection rows | separate audit; not settled here |
| Avatar rows | excluded; stay Avatar in this phase |
| Ticket / session / ceremony / OAuth transaction rows | excluded |
| Preference / settings rows | excluded |
| New global authority models | do not place in `principal` merely because of database name |
| New regional-ready models | may use retained `principal` only if designed for later regional extraction |

## Required Follow-up Work

- [ ] Write a Member decomposition plan.
- [ ] Decide whether Member maps to Persona, retires, or remains as compatibility / regional state.
- [ ] Map `ClientMembership.workspace_id` to an explicit domain concept or declare it legacy
  compatibility state.
- [ ] Decide whether ClientMembership maps to `PersonaMembership`, regional membership, or bridge
  state.
- [ ] Write an Organization decomposition plan.
- [ ] Decide whether Organization authority maps to `Bureau` or another `zenith` organization model.
- [ ] Identify which Organization operational / container portions remain retained `principal` or
  future regional.
- [ ] Audit `Client`, `Visitor`, and `Operator` decomposition separately.
- [ ] Audit OIDC connection rows separately from OAuth transactions.
- [ ] Create a migration ADR only after the above classification is accepted.

## Non-Goals

- No schema changes.
- No migrations.
- No table moves.
- No connection changes.
- No route, controller, or service changes.
- No policy changes.
- No test behavior changes.
- No Avatar relocation.
- No ticket / session / ceremony / OAuth transaction migration.
- No preference / settings migration.
- No immediate regional sharding.

## References

- [docs/architecture/principal-zenith-membership-organization-placement.md](../docs/architecture/principal-zenith-membership-organization-placement.md)
- [docs/architecture/model-database-inventory.md](../docs/architecture/model-database-inventory.md)
- [docs/architecture/database-authority-placement.md](../docs/architecture/database-authority-placement.md)
- [docs/architecture/database-boundaries.md](../docs/architecture/database-boundaries.md)
- [docs/dictionary/identity-account-organization-avatar.md](../docs/dictionary/identity-account-organization-avatar.md)
