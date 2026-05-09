# Distributor Implementation Plan

## Status

Active draft (2026-04-18)

## Summary

Stabilize Distributor as a wrapper-driven delivery engine on the canonical `post` contract.

## Canonical Contract

| Surface item | Canonical name       | Remove                                                    |
| ------------ | -------------------- | --------------------------------------------------------- |
| Engine name  | `Distributor`        | `Publisher`, delivery-as-Regional                         |
| Host label   | `post`               | `docs`, `help`, `news` as public entry labels             |
| ENV family   | `DISTRIBUTOR_POST_*` | `DOCS_*`, `HELP_*`, `NEWS_*`, `POST_*` as public contract |
| Route helper | `post_*`             | delivery helpers tied to old host labels                  |

## Scope

- public delivery host ownership
- `post.*` route and URL generation
- content and API read contracts
- wrapper-app runtime boot for Distributor
- `dev` and `net` audience support on `post.*`
- read/delivery surface separation from Foundation admin writes
- legacy `docs.*`, `help.*`, and `news.*` inventory before removal

## Required Changes

1. Converge public delivery entry points onto `post.*`
2. Move public helper naming toward `post_*`
3. Normalize canonical env names toward `DISTRIBUTOR_POST_*`
4. Keep admin and editorial write flows in Foundation unless explicitly moved later
5. Treat `post.net.*` as private internal API delivery
6. Audit host constraints, env reads, and helper names for all three legacy public labels
7. Add tests that prove `post.*` is the only canonical public delivery label
8. Move Distributor runtime boot out of the root app and into `apps/distributor`

## Acceptance Criteria

- no Distributor public delivery path depends on `docs.*`, `help.*`, or `news.*`
- `post.{app,org,com,dev,net}` is the canonical host matrix
- Distributor remains delivery-first, not admin-first
- Foundation and Distributor responsibilities are documented separately
- no legacy delivery label remains as an undocumented public contract
- Distributor runtime boot does not depend on the root app

## Related

- `plans/active/foundation-distributor-db-boundary-plan.md`
- `plans/active/net-audience-implementation-plan.md`
- `plans/active/wrapper-app-architecture-plan.md`
