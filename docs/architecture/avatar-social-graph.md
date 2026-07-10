# Avatar Social Graph

## Purpose

Avatar is the SNS actor boundary in this repository. Follow, block, and mute are Avatar-to-Avatar
relations and belong to Avatar social-graph semantics, not to Identity, Account, Organization, or
Principal ownership.

## Boundary

- Avatar remains a separate actor-authority boundary in this phase.
- Avatar rows stay in the avatar database.
- `Avatar`, `AvatarAssignment`, `AvatarMembership`, `AvatarOwnershipPeriod`, and
  `AvatarPersonaBinding` remain in the avatar database unless a later ADR explicitly moves them.
- Identity, Account, Organization, and Principal do not own follow, block, or mute state.
- This document does not move Avatar tables or rename any database key, database name, model, table,
  or route.

## Current Repository State

The repository currently implements explicit Avatar social-graph join models and directional
associations:

- [`app/models/avatar.rb`](../../app/models/avatar.rb) defines:
  - `has_many :outgoing_follows` and `has_many :incoming_follows`
  - `has_many :followings` through outgoing follow edges
  - `has_many :followers` through incoming follow edges
  - `has_many :outgoing_blocks` and `has_many :incoming_blocks`
  - `has_many :blocked_avatars` and `has_many :blocking_avatars`
  - `has_many :outgoing_mutes` and `has_many :incoming_mutes`
  - `has_many :muted_avatars` and `has_many :muting_avatars`
- [`app/models/avatar_follow.rb`](../../app/models/avatar_follow.rb) is an explicit join model with
  `belongs_to :follower_avatar` and `belongs_to :followed_avatar`.
- [`app/models/avatar_block.rb`](../../app/models/avatar_block.rb) is an explicit join model with
  `belongs_to :blocker_avatar` and `belongs_to :blocked_avatar`.
- [`app/models/avatar_mute.rb`](../../app/models/avatar_mute.rb) is an explicit join model with
  `belongs_to :muter_avatar` and `belongs_to :muted_avatar`.
- [`db/avatars_migrate/20260627000003_add_avatar_social_graph_invariants.rb`](../../db/avatars_migrate/20260627000003_add_avatar_social_graph_invariants.rb)
  adds the current self-edge check constraints without validation and the directed pair unique
  indexes.
- [`db/avatars_migrate/20260627000004_validate_avatar_social_graph_invariants.rb`](../../db/avatars_migrate/20260627000004_validate_avatar_social_graph_invariants.rb)
  validates those check constraints in a separate step.
- [`db/avatars_migrate/20260616150010_add_on_delete_actions_to_avatar_relationship_foreign_keys.rb`](../../db/avatars_migrate/20260616150010_add_on_delete_actions_to_avatar_relationship_foreign_keys.rb)
  adds cascade delete behavior for block and mute foreign keys.
- [`test/models/avatar_test.rb`](../../test/models/avatar_test.rb),
  [`test/models/avatar_follow_test.rb`](../../test/models/avatar_follow_test.rb),
  [`test/models/avatar_block_test.rb`](../../test/models/avatar_block_test.rb), and
  [`test/models/avatar_mute_test.rb`](../../test/models/avatar_mute_test.rb) cover the associations,
  self-edge rejection, and duplicate pair rejection.

Current code does not show dedicated follow/block/mute service objects or controller endpoints for
social-graph actions. The observed policy classes are empty stubs:

- [`app/policies/avatar_follow_policy.rb`](../../app/policies/avatar_follow_policy.rb)
- [`app/policies/avatar_block_policy.rb`](../../app/policies/avatar_block_policy.rb)
- [`app/policies/avatar_mute_policy.rb`](../../app/policies/avatar_mute_policy.rb)

## Follow and Follower Model

Follow is one directed self-referential Avatar-to-Avatar edge.

- `follower_avatar_id` identifies the source Avatar.
- `followed_avatar_id` identifies the target Avatar.
- From the source Avatar's perspective, the row means "following."
- From the target Avatar's perspective, the same row means "follower."
- Separate follower and following tables are not required.

The current repository shape matches this directed-edge model.

## Non-Follow

Non-follow is the absence of an active follow edge.

- Non-follow is not represented by a row.
- Do not add a separate "non-follow" table.
- If future follow history is added, non-follow still means no active row for the pair.

## Block

Block is a strong policy relation with its own directed Avatar-to-Avatar edge.

- `blocker_avatar_id` identifies the blocking Avatar.
- `blocked_avatar_id` identifies the blocked Avatar.
- Block should win over weaker relationship states when policy or visibility checks are evaluated.
- Block should prevent blocked -> blocker follow or interaction where policy requires it.
- Block does not need to erase follow state unless a later product decision explicitly requires
  that.

Current repository shape:

- `AvatarBlock` exists as a join model.
- `avatar_blocks` includes optional `reason` and `expires_at` columns.
- The model and database enforce directed pair uniqueness and no self-block.
- The repository does not yet show block policy logic, so block precedence is still a design
  requirement rather than an observed runtime rule.

## Mute

Mute is viewer-side filtering.

- `muter_avatar_id` identifies the Avatar choosing to mute.
- `muted_avatar_id` identifies the muted Avatar.
- Mute should not destroy follow state.
- Mute should not grant or revoke visibility by itself.
- Mute should not affect the muted Avatar's ability to view or follow unless another policy does
  that.

Current repository shape:

- `AvatarMute` exists as a join model.
- `avatar_mutes` includes optional `expires_at`.
- The model and database enforce directed pair uniqueness and no self-mute.
- No timeline, feed, or notification projection code was found in the inspected repository area.

## Required Invariants

The intended invariant set is:

- Avatar cannot follow itself.
- Avatar cannot block itself.
- Avatar cannot mute itself.
- Current or active directed edges should be unique per pair.
- Follow, block, and mute operations should be idempotent at the service boundary when those
  services are introduced.

The repository currently enforces the first four invariants with both model validations and database
constraints, using the add-then-validate pattern for the check constraints.

## Recommended Database Shape

The current repository already uses explicit join tables. The recommended long-term shape remains
the same join-table approach:

### `avatar_follows`

- `follower_avatar_id`
- `followed_avatar_id`
- `status`
- `requested_at`
- `accepted_at`
- `ended_at`
- `created_at`
- `updated_at`

### `avatar_blocks`

- `blocker_avatar_id`
- `blocked_avatar_id`
- `ended_at`
- `created_at`
- `updated_at`

### `avatar_mutes`

- `muter_avatar_id`
- `muted_avatar_id`
- `ended_at`
- `created_at`
- `updated_at`

The repository currently has a simpler physical shape:

- `avatar_follows` has `follower_avatar_id`, `followed_avatar_id`, `created_at`, and `updated_at`.
- `avatar_blocks` has `blocker_avatar_id`, `blocked_avatar_id`, `reason`, `expires_at`,
  `created_at`, and `updated_at`.
- `avatar_mutes` has `muter_avatar_id`, `muted_avatar_id`, `expires_at`, `created_at`, and
  `updated_at`.

## Recommended Constraints

The intended constraints are:

- `follower_avatar_id <> followed_avatar_id`
- `blocker_avatar_id <> blocked_avatar_id`
- `muter_avatar_id <> muted_avatar_id`

The repository currently enforces these constraints with database check constraints and model
validations.

The intended uniqueness shape is:

- one current or active follow edge per follower/followed pair
- one current or active block edge per blocker/blocked pair
- one current or active mute edge per muter/muted pair

The repository currently uses unique directed pair indexes on all three join tables.

## Recommended Indexes

Directional lookups should stay cheap:

- `avatar_follows`: unique pair index on `(follower_avatar_id, followed_avatar_id)`
- `avatar_follows`: `follower_avatar_id + created_at` for following lists
- `avatar_follows`: `followed_avatar_id + created_at` for follower lists
- `avatar_blocks`: unique pair index on `(blocker_avatar_id, blocked_avatar_id)`
- `avatar_blocks`: reverse block lookup index if policy needs fast target-side checks
- `avatar_mutes`: unique pair index on `(muter_avatar_id, muted_avatar_id)`
- `avatar_mutes`: reverse mute lookup index if policy or projection needs fast target-side checks

The repository currently has directional single-column indexes and a unique pair index for each of
the three join tables.

## Performance Notes

- Join tables are acceptable as the source of truth for the social graph.
- The dangerous part is repeatedly deriving counts, timelines, recommendations, and visibility
  checks through large request-time joins.
- Follower/following lists should use cursor pagination and batch relation lookup instead of N+1
  `exists?` checks.
- Counts should eventually be projected or cached instead of repeatedly computed with `COUNT(*)` on
  large relation sets.
- Timeline generation and notification fan-out should eventually move toward projections or
  outbox-driven fanout rather than giant runtime joins.
- Do not create a separate non-follow table.

## Known Implementation Gaps

Gaps observed in the current repository:

- No follow/block/mute service objects were found in `app/services`.
- No controller endpoints for social-graph actions were found in `app/controllers`.
- `AvatarFollowPolicy`, `AvatarBlockPolicy`, and `AvatarMutePolicy` are empty stubs.
- The repository does not yet show policy logic proving that block wins over follow or mute.
- No batch-list or projection code for social counts, timeline entries, notification projections, or
  recommendation candidates was found in the inspected area.

## Future Checklist

- Add explicit service objects if follow/unfollow/block/unblock/mute/unmute actions are introduced.
- Add or tighten model validations so the self-edge invariants remain explicit in code.
- Keep the current database check constraints and unique pair indexes aligned with the model rules.
- Add policy semantics once the request path and authorization boundary are defined.
- Add tests for block precedence over weaker graph states.
- Add tests for directional follower/following behavior if more read paths are introduced.
- Add batch relation lookup for list screens instead of N+1 `exists?` calls.
- Add projected counts, timeline entries, notification projections, and recommendation projections
  before the runtime graph grows large enough for request-time joins to dominate.

## Related Docs

- [`docs/architecture/database-authority-placement.md`](./database-authority-placement.md)
- [`docs/architecture/avatar-account-bridge.md`](./avatar-account-bridge.md)
- [`docs/architecture/sns-subject-resource-grill.md`](./sns-subject-resource-grill.md)
