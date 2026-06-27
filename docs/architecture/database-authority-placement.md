# Database Authority Placement

## Purpose

This document separates current storage naming from target authority placement.

## Scope

This is docs-only placement direction, not a rename and not an implementation change.

It describes the intended authority placement for the current global surfaces and their database
boundaries. `auth`, `base`, and `info` are global surfaces in this phase.

## Current Storage Names

The repository currently uses these storage and connection boundaries:

- `principal`
- `zenith`
- `avatar`

The `principal` name is retained in this phase and is not renamed.

## Target Authority Placement

`zenith` is the canonical store for global authority data for Principal / Identity / Account /
Organization placement.

After the placement migration, `principal` is not the canonical store for Principal authority data;
it is reserved for non-authority application data where appropriate.

This is a database placement migration, not a database rename.

## Avatar Boundary

Avatar remains a separate actor-authority boundary in the current code and in this phase.

`Avatar`, `AvatarAssignment`, `AvatarMembership`, `AvatarOwnershipPeriod`, and
`AvatarPersonaBinding` remain in the avatar database unless a later ADR explicitly moves them.
`app_zenith` is not the current target for `AvatarPersonaBinding`.

## Current Implementation Facts

- `Client`, `Visitor`, and `Operator` still live in `app_principal`, `com_principal`, and
  `org_principal`.
- `Client`, `Visitor`, and `Operator` still own credentials, sessions, lifecycle columns, and
  recovery/contact state.
- The zenith-side account and identity-binding graph already exists in `app_zenith`, `org_zenith`,
  and `com_zenith`.
- `Persona`, `ClientIdentity`, `Agent`, `OperatorIdentity`, `Individual`, `VisitorIdentity`, and
  their assignment/membership-style graph belong to the zenith-side account/identity-binding story.
- `ClientAccount`, `OperatorAccount`, and `VisitorAccount` are already zenith-side RP account
  projection records.
- `Member` and `ClientMembership` are still in `app_principal`.
- `Organization` is still in `org_principal`.
- This is the current ambiguity zone for account/organization placement.
- `Avatar`, `AvatarAssignment`, `AvatarMembership`, `AvatarOwnershipPeriod`, and
  `AvatarPersonaBinding` remain in the standalone avatar database.
- `Avatar` still points to member through `client_id`.
- Avatar remains a separate actor-authority boundary in this phase.

Relevant file paths:

- `app/models/client.rb`
- `app/models/visitor.rb`
- `app/models/operator.rb`
- `app/models/member.rb`
- `app/models/client_membership.rb`
- `app/models/organization.rb`
- `app/models/persona.rb`
- `app/models/client_identity.rb`
- `app/models/operator_identity.rb`
- `app/models/visitor_identity.rb`
- `app/models/client_account.rb`
- `app/models/operator_account.rb`
- `app/models/visitor_account.rb`
- `app/models/avatar.rb`
- `app/models/avatar_assignment.rb`
- `app/models/avatar_membership.rb`
- `app/models/avatar_ownership_period.rb`
- `app/models/avatar_persona_binding.rb`
- `docs/architecture/avatar-social-graph.md`

## Explicit Exclusions

- No database renames.
- No table renames.
- No schema edits.
- No connection-key edits.
- No model `connects_to` changes.
- No preference migration work.
- No token/session/ceremony/logout/OAuth transaction migration work.
- No Avatar database migration work in this phase.

## Ambiguities

- `Member` vs `ClientMembership` vs `Organization` remains the weakest boundary.
- `ClientOidcConnection`, `OperatorOidcConnection`, and `VisitorOidcConnection` may be future
  candidates, but they are not settled here.
- `representing_organization_id` on `Avatar` remains semantically unclear.
- `AvatarAssignment`, `AvatarMembership`, `AvatarOwnershipPeriod`, and `AvatarPersonaBinding` remain
  unresolved beyond the current "stay in avatar" phase.

## Future Implementation Sequence

1. Keep this placement document as the contract.
2. Audit identity/account/organization projections in `zenith`.
3. Audit `Member` / `ClientMembership` / `Organization` placement.
4. Only after that, separately revisit Avatar through a new ADR if needed.
5. Do not mix Avatar relocation into this placement migration.
