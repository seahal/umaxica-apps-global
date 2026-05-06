# Add `dev` Audience Tier

## Status

Active draft (2026-04-18)

## Summary

Add a fourth audience tier (`dev`) to the engines that need a human operational surface.

This plan follows the four-app target:

- runtime boot happens in wrapper apps
- Zenith uses `acme`
- Foundation uses `base`

## Scope

### In scope

- add `dev` handling to the relevant engines and wrapper apps
- move operational tools to the `dev` tier
- add canonical `*_DEV_URL` and `*_DEV_TRUSTED_ORIGINS` variables where required
- create minimal `dev` controllers and views where still needed

### Out of scope

- new authentication mechanisms for `dev`
- browser-first `net` behavior

## Target Hostnames

| Engine      | Surface | `dev` hostname       | ENV variable               |
| ----------- | ------- | -------------------- | -------------------------- |
| Identity    | `sign`  | `sign.dev.localhost` | `IDENTITY_SIGN_DEV_URL`    |
| Zenith      | `acme`  | `dev.localhost`      | `ZENITH_ACME_DEV_URL`      |
| Foundation  | `base`  | `base.dev.localhost` | `FOUNDATION_BASE_DEV_URL`  |
| Distributor | `post`  | `post.dev.localhost` | `DISTRIBUTOR_POST_DEV_URL` |

## Implementation Phases

### Phase 1: Runtime contract update

1. add canonical `*_DEV_URL` env variables
2. add browser-facing `*_DEV_TRUSTED_ORIGINS` where required
3. update wrapper-app runtime config instead of root-app-only config

### Phase 2: Route and surface wiring

1. add `dev` host handling to each required engine route file
2. move operational tools such as `MissionControl::Jobs` to the Foundation `dev` surface
3. keep authorization explicit for `dev`

### Phase 3: Minimal `dev` endpoints

Each engine that exposes `dev` gets minimal endpoints such as:

- root
- health
- robots

## Acceptance

- `dev` runtime contracts use canonical engine/surface naming
- Zenith uses `ZENITH_ACME_DEV_URL`, not `ZENITH_ACME_DEV_URL`
- operational tools no longer sit on non-`dev` public surfaces by default

## Related

- `plans/active/four-engine-migration-sequence.md`
- `plans/active/wrapper-app-architecture-plan.md`
