# Test Specification

## Scope

This document defines how the Rails platform is verified across the current boundary model:

- `app` for end-user product and account flows
- `org` for staff and organization workflows
- `com` for public and corporate workflows

## References

- `docs/spec/srs.md`
- `docs/architecture/hld.md`
- `docs/architecture/dds.md`
- `docs/tasks/checklist.md`

## Test Approach

- Ruby tests cover controllers, models, services, and surface-specific routing.
- JS tests cover surface scripts and UI helpers.
- Integration tests cover redirects, host constraints, and public versus authenticated flows.
- Security tests cover auth, redirect safety, encryption, CSRF, verification, and request
  throttling.
- Performance checks focus on health endpoints, sign-in paths, and contact flows.

## Boundary Matrix

| Boundary | Primary focus                                                       |
| -------- | ------------------------------------------------------------------- |
| `app`    | End-user auth, account, preference, and product flows               |
| `org`    | Staff auth, organization workflows, authorization, and audit writes |
| `com`    | Public/corporate pages, visitor preference, and guest-safe flows    |

## Core Cases

- host mismatch returns 404
- redirect targets stay on the allow-list
- sign-in and passkey flows write the expected cookies and tokens
- staff and organization flows validate authorization before writes
- public/corporate flows preserve guest-safe access
- database ownership matches the surface or cross-cutting base record

## Non-Functional Checks

- health endpoints stay fast
- lint and test suites remain green
- audit and security checks run before release
- docs and plans stay synchronized with the current surface/repository boundary model
