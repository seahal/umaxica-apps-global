# Collective Hierarchy Model

**Status:** Accepted (2026-05-19)

## Context

The `Workspace` / `Organization` implementation was originally introduced to give accounts a common
place in a hierarchy. That hierarchy is not only for legal companies or staff organizations. It is
also needed for personal accounts, accounts with no external affiliation, and the `app` / `com` /
`org` surfaces that need a shared interface for placement, authorization, preferences, assets, and
future billing.

The current names are confusing:

- `Workspace` sounds like a tenant or work area.
- `Organization` sounds like a legal or staff-facing organization.
- `Department` and `Division` describe some org-chart levels but do not name the common recursive
  structure.
- `com` has grown enough shared behavior that org-specific naming is no longer a good common
  abstraction.

The product model remains a recursive organization-chart-like structure. Accounts are attached to
branches or leaves of that structure. Even personal or unaffiliated accounts receive a node in the
same hierarchy instead of bypassing it.

## Decision

Use **Collective** as the accepted domain name for the common recursive hierarchy concept.

A Collective represents a node in the hierarchy that can contain child Collectives and receive
account placements. It is intentionally broader than company, organization, workspace, department,
or division.

The conceptual model is:

```text
Collective
  -> child Collective
  -> child Collective
      -> account placement / membership
```

Equivalently, from the actor side:

```text
Session -> Account -> Placement/Membership -> Collective
                                           -> ancestors/descendants
```

The common concern should express the hierarchy contract, not a surface-specific organization model.
Surface-specific models may keep their own storage names while exposing a Collective-compatible
interface.

## Semantics

- A Collective is a recursive hierarchy node.
- A Collective may represent a company, a public/corporate container, a staff organization unit, a
  department-like node, a personal space, or an unaffiliated placeholder.
- An Account is not outside the hierarchy. Every account should be placeable in a Collective.
- Membership or placement joins an Account to a Collective and carries role, state, employment, or
  lifecycle metadata.
- Authorization and asset access should prefer Collective ancestry and placement checks over
  surface-specific organization checks.
- Personal and unaffiliated accounts should use generated personal/private Collectives rather than
  `nil` hierarchy state.

## Naming Direction

Future implementation should migrate toward these names where practical:

| Current / legacy idea              | Direction                                                |
| ---------------------------------- | -------------------------------------------------------- |
| `Workspace`                        | `Collective` or a compatibility name for Collective      |
| `Organization`                     | Legacy/external label, not the common base abstraction   |
| `Department` / `Division`          | Collective node kinds or specialized projections         |
| `Membership` / `Placement`         | Account-to-Collective join                               |
| `OperatorWorkspaceAccount`         | Org surface projection that should gain Collective terms |
| `workspace_id` / `organization_id` | Transitional storage names until migration               |

This ADR does not require an immediate rename. It records the intended vocabulary so future cleanup
can migrate deliberately.

## Consequences

- New shared concerns should use Collective terminology when they model the recursive hierarchy.
- New code should not treat `Workspace` as only a company tenant or `Organization` as the common
  base hierarchy term.
- Surface-specific naming remains acceptable at storage and compatibility boundaries while migration
  is incomplete.
- Existing `Workspace`, `Organization`, `Department`, and `Division` models should be read as
  transitional pieces of the Collective hierarchy until renamed or adapted.
- Documentation and future plans should describe account placement as account-to-Collective, even
  when current tables still use workspace or organization columns.

## Related

- `adr/account-workspace-avatar-billing.md`
- `adr/org-actor-operator-naming.md`
- `docs/architecture/actor-naming.md`
- `docs/architecture/database-boundaries.md`
