# Foundation Implementation Plan

## Status

Active draft (2026-04-18)

## Summary

Stabilize Foundation as a wrapper-driven engine on the canonical `base` public contract and the
`chronicle` database family.

## Canonical Contract

| Surface item | Canonical name      | Remove                       |
| ------------ | ------------------- | ---------------------------- |
| Engine name  | `Foundation`        | `Regional`                   |
| Host label   | `base`              | `main`, `core`, `ww`         |
| ENV family   | `FOUNDATION_BASE_*` | `MAIN_*`, `CORE_*`, `BASE_*` |
| Route helper | `base_*`            | `main_*`                     |

## Scope

- route host constraints for `base.*`
- `FOUNDATION_BASE_*` runtime reads
- `base_*` public route helpers
- wrapper-app runtime boot for Foundation
- layout and redirect links
- tests and fixtures that still use `main.*` or `wwww.*`
- `dev` and `net` audience support on `base.*`
- `MissionControl::Jobs` routing move from `org` to `dev`
- Foundation-owned `chronicle`, `message`, `search`, `billing`, and `commerce` boundaries

## Required Changes

1. Replace route alias `main` with `base`
2. Remove `MAIN_* || CORE_*` fallback reads and transitional `BASE_*` compatibility reads
3. Rename trusted-origin variables to `FOUNDATION_BASE_*_TRUSTED_ORIGINS`
4. Replace helper usage from `main_*` to `base_*`
5. Replace localhost defaults with `base.*.localhost`
6. Keep Rails `main_app.*` untouched
7. Move `MissionControl::Jobs` to `base.dev.*`
8. Add a negative route test for `base.org.* /jobs`
9. Move Foundation runtime boot out of the root app and into `apps/foundation`
10. Do not use `behavior` as a Foundation target model or DB family name

## Acceptance Criteria

- no Foundation public route depends on `main_*`
- no Foundation runtime env read depends on `MAIN_*`, `CORE_*`, or transitional `BASE_*`
- no Foundation localhost default uses `main.*` or `wwww.*`
- `base.{app,org,com,dev,net}` is consistently documented and tested
- `main_app.*` remains unchanged in engine code
- `base.org.*` does not route `MissionControl::Jobs`
- Foundation runtime boot does not depend on the root app
- Foundation naming uses `chronicle`, not `behavior`

## Related

- `plans/active/four-engine-migration-sequence.md`
- `plans/active/net-audience-implementation-plan.md`
- `plans/active/foundation-distributor-db-boundary-plan.md`
- `plans/active/wrapper-app-architecture-plan.md`
