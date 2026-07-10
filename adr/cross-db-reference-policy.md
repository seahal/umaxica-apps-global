# Cross-DB Reference Policy

## Status

Accepted

## Date

2026-07-03

## Context

Umaxica v1 uses multiple database boundaries. Native foreign keys cannot be the default contract
across those boundaries.

## Decision

Cross-DB references must not depend on native foreign keys. New cross-DB bigint or integer ID
associations are forbidden.

When content, media, interaction, moderation, or read models refer to Avatar, they must use
immutable public identifiers such as `avatar_public_id`. Other cross-DB references should use
explicit stable identifiers such as public_id, gid, surface, and resource_type rather than
database-local integer primary keys.

## Consequences

Existing cross-DB integer associations are known violations or transitional compatibility paths. New
migrations and models must not add more.

## Related

- `adr/avatar-db-content-db-boundary.md`
- `adr/authority-lifecycle-table-policy.md`
- `docs/architecture/umaxica-v1-architecture-lock.md`
