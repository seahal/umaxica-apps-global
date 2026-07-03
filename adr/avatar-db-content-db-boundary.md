# Avatar DB and Content DB Boundary

## Status

Accepted

## Date

2026-07-03

## Context

Avatar must remain the authority for current actor identity, settings, state, and social relations,
while user-generated content and historical actor display snapshots belong outside the avatar DB.

## Decision

Avatar and Group are stored in the avatar database.

The avatar database owns:

- Avatar
- Group
- Avatar and Group settings
- Avatar and Group current state
- Avatar and Group relationship settings
- Avatar assignment, membership, and binding records
- GroupAvatarMembership
- Follow, block, mute, and related social graph relations
- Avatar lifecycle state authority

App-surface Avatar creation goes through `AvatarProvisioning::Create`, which creates Avatar, Handle,
`AvatarPersonaBinding`, and initial owner `AvatarAssignment` in one avatar DB transaction. For
app-surface creation, `AvatarPersonaBinding` is the canonical Avatar-to-Persona relation.
`avatars.client_id` is migration compatibility only and must not be used as ownership,
authorization, or canonical binding authority.

The avatar database does not own:

- Post bodies
- Comments
- Replies
- Captions
- Image posts
- Video posts
- Story or short video content
- DM bodies
- Reaction events
- Feed material
- Ranking sources
- Actor snapshots captured at posting time
- Content read models

Posts, comments, media, reactions, feed material, ranking sources, and posting-time actor snapshots
belong to content, media, interaction, moderation, or read-model domains and databases.

Avatar DB is the actor, settings, relation, and social graph DB. It must not become a UGC storage DB
and must not contain actor snapshot tables for content display history.

## Consequences

Content implementations must refer to Avatar through immutable public identifiers such as
`avatar_public_id`. They must not add cross-DB bigint foreign keys to avatar rows.

Existing historical `posts` placement in avatar migrations is a known violation to retire, not a
template for new tables.

## Related

- `adr/umaxica-v1-core-resource-architecture.md`
- `adr/avatar-lifecycle-state-authority.md`
- `adr/cross-db-reference-policy.md`
- `docs/architecture/umaxica-v1-architecture-lock.md`
