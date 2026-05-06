# Identity / Zenith / Foundation / Distributor Implementation Plan

## Status

Active draft (2026-04-18)

## Summary

This plan defines the implementation direction for the four-app target.

Implementation order:

1. stabilize `Identity` wrapper-app boot and domain ownership
2. stabilize `Zenith` wrapper-app boot and rename `acme` to `acme`
3. stabilize `Foundation` on `base` and `chronicle`
4. stabilize `Distributor` on `post`
5. complete `dev` and `net` audience coverage where still required
6. remove the root app

## Identity

### Goal

Use `sign.*` as the canonical IDP and make `Identity` the first fully wrapper-driven engine.

### Scope

- authentication
- verification and step-up
- session lineage
- token issuance and refresh
- login-critical identity state
- engine-owned models and DB logic
- engine-owned auth runtime wiring in `apps/identity`

## Zenith

### Goal

Use `acme` as the canonical Zenith surface for shared shell and shared preference flows.

### Scope

- shared shell and layout bootstrap
- public sign entry links
- `acme`-facing preference and session bootstrap
- `ZENITH_ACME_*` runtime wiring
- `app.*`, `org.*`, `com.*`, `dev.*`, `net.*`
- path flattening together with the `acme` to `acme` rename

## Foundation

### Goal

Use `base.*` as the canonical business and staff-admin surface.

### Scope

- contacts and inquiry flows
- staff and admin write surfaces
- Foundation-owned CMS and editorial tooling
- all public naming normalized to `base`, `FOUNDATION_BASE_*`, and `base_*`
- `chronicle` as the detailed Foundation record family

## Distributor

### Goal

Use `post.*` as the canonical delivery and API surface.

### Scope

- read and delivery APIs
- `post.*` host ownership
- distribution-safe public API contracts
- no admin-first assumptions

## Cross-Cutting Rules

- wrapper apps own runtime boot
- engines own domain code
- shared code is limited to `lib/`
- Rails `main_app.*` remains unchanged where it still exists during migration
- root app retirement is part of implementation, not a later optional cleanup
- internal path flattening is part of implementation, not a side proposal

## Related

- `plans/active/four-engine-migration-sequence.md`
- `plans/active/wrapper-app-architecture-plan.md`
- `plans/active/root-app-retirement-plan.md`
- `plans/active/controller-path-flattening-plan.md`
