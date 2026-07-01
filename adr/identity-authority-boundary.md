# Move non-ceremony Auth settings to Base identity without compatibility shims

## Status

Accepted (2026-07-01)

## Context

Earlier settings migration notes used the older Sign/Acme vocabulary and allowed redirect or
`410 Gone` compatibility behavior while moving general settings to identity routes. That direction
has caused regressions where identity, profile, session, activity, and lifecycle routes drift back
under Auth settings.

The current component vocabulary is Auth and Base for this Rails implementation slice:

- Auth is the credential gateway and credential ceremony host.
- Base is the Rails foundation/control-plane surface and owns identity management.

Auth may keep credential ceremony-backed settings. Auth must not remain a general identity settings
surface.

## Decision

- Auth `/settings` is deprecated as a general settings surface.
- Base identity owns non-ceremony identity, profile, session-management, activity, and lifecycle
  settings.
- Non-exception Auth settings routes must be removed with no redirect shim, no alias route, no
  compatibility controller, and no `410 Gone` compatibility endpoint.
- Retired Auth settings URLs must be unroutable.
- Base identity routes should use Rails `resource` / `resources` CRUD shapes where practical.
- Operation-style Auth settings routes such as `removal`, `revocation`, `options`, and
  `verification` must not be copied to Base identity when CRUD resource shape can express the
  action.

Auth settings exceptions:

| Surface | Auth settings routes that may remain |
| ------- | ------------------------------------ |
| `app`   | passkeys, TOTP, Google, Apple        |
| `com`   | passkeys                             |
| `org`   | passkeys, Entra                      |

Base identity owns:

- emails;
- telephones;
- birthdate;
- secrets and secret credentials;
- sessions and session-set revocation;
- revocations where still required as session/account-management resources;
- activities;
- withdrawal.

`operator_lifecycle_requests` are not an Auth settings exception and must not be casually rehomed
under Base identity. If the correct owner is unclear during the migration, the work should leave an
explicit TODO or implementation note for owner classification instead of treating route proximity as
authority.

## Consequences

- Existing Auth settings redirect shims for migrated identity resources are migration debt, not
  accepted compatibility.
- Existing Auth settings tests that assert redirects to Base identity must be replaced by route
  contract tests proving the old Auth URLs are unroutable.
- Base identity controller tests must be added before production route/controller migration, so the
  migration proceeds from red tests rather than from route edits.
- Auth sign-in, sign-up, step-up, social callback, OIDC, and retained credential ceremony routes are
  out of scope unless they are directly part of the retained settings exceptions.
- Org Entra settings should mirror the app Google/Apple settings pattern without breaking the
  existing org Entra sign-in ceremony route.

## Related

- `adr/acme-sign-core-base-port-boundary.md`
- `adr/sign-credential-gateway-surface.md`
- `docs/architecture/sign-settings-to-acme-identity.md`
- `docs/identity/authority-boundary.md`
- `docs/security/credential-gateway.md`
