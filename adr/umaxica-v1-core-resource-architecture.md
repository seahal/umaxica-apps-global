# Umaxica v1 Core Resource Architecture

## Status

Accepted

## Date

2026-07-03

## Context

Umaxica v1 needs a stable resource model before implementation work continues. Existing code still
has transitional direct ownership paths, especially around Identity, Account, Avatar, and legacy
Member rows. This ADR locks the target architecture before migrations, model rewrites, or controller
rewrites.

## Decision

Identity, Account, Organization, and Unit belong to the core domain and core database placement.
There is no separate Identity database in this architecture. Identity is integrated into the same
core-side placement as Account, Organization, and Unit.

Identity is not owned by Account, Organization, or Unit. Identity is a login key and credential
subject. Account relationships must be represented through grant, assignment, or lifecycle authority
tables instead of direct foreign-key ownership from an account row.

Avatar and Group belong to the avatar domain and avatar database. They are independent resources,
not children of Account, Organization, Unit, or Identity.

The following resources must be treated as independent base resources:

- Identity
- Account
- Organization
- Unit
- Avatar
- Group

Ownership, membership, use rights, management rights, operating rights, primary or representative
selection, transfer history, and active, suspended, or revoked state must be represented by
authority or lifecycle tables. These are not bare join tables; they must be able to carry role,
state, primary flag, valid_from, valid_to, granted_by, revoked_by, reason, and audit reference
fields.

Controllers must not directly write authority or lifecycle tables. Controllers may call use-case
services that own validation, authorization, lifecycle transitions, audit references, and
transaction boundaries.

## Consequences

Existing direct ownership-like columns are transitional violations, not the model for new work.
Future slices must introduce authority services and lifecycle tables before removing legacy columns.

This ADR does not implement migrations, model rewrites, controller rewrites, Group v1, content DB
creation, or legacy column deletion.

## Related

- `adr/avatar-db-content-db-boundary.md`
- `adr/avatar-lifecycle-state-authority.md`
- `adr/cross-db-reference-policy.md`
- `adr/authority-lifecycle-table-policy.md`
- `docs/architecture/umaxica-v1-architecture-lock.md`
