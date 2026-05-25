# Bare / Guest Controller Flag Retirement

## Status

Historical. Superseded by `plans/active/controller-boundary-lifecycle-unification.md`, which was
itself deprecated by the 2026-05-24 emergency controller-boundary direction.

This file remains as historical flag-retirement inventory only. Do not use it as the active plan,
and do not use it to justify four-way controller inheritance.

## Context

`adr/static-and-guest-controller-boundaries.md` used to accept `OpenController`, `BareController`,
`PrivateController`, and `GuestController` as the controller-boundary names for access semantics.
That ADR is now deprecated. This plan is retained only as historical context for legacy static-style
and guest-only endpoint-local flags.

The codebase is still transitional. Some controllers still declare boundary behavior with local
flags such as `public_strict!` and `guest_only!`, and compatibility bases such as `PublicController`
and `StaticController` may remain while the rename is in progress.

## Intent

The historical intent was to finish the base-class migration so controller inheritance expressed the
boundary contract:

- `BareController` inheritance means the endpoint does not need endpoint-local `public_strict!`.
- `GuestController` inheritance means the endpoint does not need endpoint-local `guest_only!`.

After all call sites are migrated, retire the endpoint-local flag pattern and remove the legacy DSL
where it is no longer needed.

## Scope

- Add or keep boundary-local `BareController` classes for `sign` and `apex`.
- Keep bare-tier behavior duplicated per boundary unless a small concern becomes clearly useful.
- Migrate lightweight static-style endpoints from `PublicController`, `OpenController`, or
  `ApplicationController + public_strict!` to their boundary's `BareController`.
- Add `GuestController` bases for surfaces that still repeat guest-only behavior locally.
- Migrate guest-only endpoints from `ApplicationController + guest_only!` or
  `before_action :reject_logged_in_session` to the appropriate `GuestController`.
- Remove redundant endpoint-local `public_strict!` and `guest_only!` declarations after migration.
- Retire compatibility constants and DSL methods only after no remaining references require them.

## Candidate First Pass

Bare candidates:

- health endpoints
- robots endpoints
- sitemap endpoints
- CSP violation report endpoints, after confirming POST behavior and CSRF expectations
- JSON health endpoints under `edge/v0` and `web/v0`, after confirming old deferred scope

Guest candidates:

- sign root entry controllers
- sign-in entry controllers
- sign-up entry controllers
- credential-entry controllers that reject already-authenticated actors

## Guardrails

- Do not introduce a shared cross-boundary bare superclass unless a later ADR accepts it.
- Do not mix `app`, `org`, and `com` surface behavior.
- Preserve existing status codes and messages when replacing local `guest_only!` declarations.
- Preserve CSRF and rate-limit behavior for bare endpoints.
- Use narrow controller/request tests for migrated endpoints before removing compatibility behavior.

## Current Guest Migration Note

`Sign::Com::GuestController` and `Sign::Org::GuestController` can exist as boundary-local bases, but
moving `roots`, `ins`, or `ups` controllers under those bases currently changes logged-in redirect
behavior in the existing controller tests. The observed failure is that logged-in requests that
previously redirected to the dashboard return `200 OK` after the intermediate guest base is
inserted.

Before endpoint-local `guest_only!` / `reject_logged_in_session` declarations are removed from those
controllers, fix or document the authentication DSL/test-bypass behavior so inherited guest bases
preserve the same logged-in redirect contract as endpoint-local declarations.

## References

- `adr/static-and-guest-controller-boundaries.md`
- `plans/backlog/controller-boundary-exception-retirement.md`
- `adr/public-controller-base.md`
- `adr/three-tier-controller-base.md`
