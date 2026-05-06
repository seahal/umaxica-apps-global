# Net Audience Implementation Plan

## Status

Active draft (2026-04-18)

## Summary

Implement `net` as a first-class audience tier across the four-app target.

## Audience Meaning

- `net` is a private internal-service audience
- `net` is intended for service-to-service API communication
- `net` is not a public browser-facing audience

## Host Matrix

| Engine      | `net` host   |
| ----------- | ------------ |
| Identity    | `sign.net.*` |
| Zenith      | `net.*`      |
| Foundation  | `base.net.*` |
| Distributor | `post.net.*` |

## Implementation Scope

- route constraints
- environment variables
- host allowlists
- wrapper-app runtime wiring where `net` is exposed
- trusted-origin policy where relevant
- test host coverage
- API-first defaults for `net` surfaces
- minimal machine-facing endpoints only in this migration

## Guardrails

- do not assume browser-first UX on `net`
- prefer JSON/API contracts over HTML-first contracts on `net`
- keep authn/authz explicit even for internal-only routes
- avoid mixing `dev` operator workflows into `net`
- do not introduce template-driven HTML defaults on `net`
- prefer machine-readable error responses on `net`
- do not move browser-session operator workflows onto `net`

## Acceptance Criteria

- all four engines have an explicit `net` host contract
- `net` is documented as non-public
- test coverage proves `net` routing and audience handling
- `net` endpoints default to API-first behavior rather than browser-first rendering
- `net` rollout in this migration does not require browser-session auth
- `net` runtime contracts are owned by wrapper apps rather than the retired root app

## Related

- `adr/four-engine-restoration-and-base-contract.md`
- `adr/four-app-wrapper-runtime-and-root-retirement.md`
- `plans/active/four-engine-reframe.md`
