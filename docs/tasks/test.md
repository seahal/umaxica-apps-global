# Test Specification

## Scope

This document defines how the Rails platform is verified across the current boundary model:

- `Identity` for identity and authentication
- `Zenith` for the shared shell and coordination surface
- `Foundation` for `base.*`
- `Distributor` for `post.*`

## References

- `docs/spec/srs.md`
- `docs/architecture/hld.md`
- `docs/architecture/dds.md`
- `docs/tasks/checklist.md`

## Test Approach

- Ruby tests cover controllers, models, services, and boundary-specific routing.
- JS tests cover surface scripts and UI helpers.
- Integration tests cover cross-boundary redirects, host constraints, and public versus staff flows.
- Security tests cover auth, redirect safety, encryption, and request throttling.
- Performance checks focus on health endpoints, sign-in paths, and contact flows.

## Boundary Matrix

| Boundary      | Primary hosts | Coverage focus                                               |
| ------------- | ------------- | ------------------------------------------------------------ |
| `Identity`    | `sign.*`      | Auth, passkeys, token flows, audit writes                    |
| `Zenith`      | acme labels   | cross-surface coordination, shared preferences, host routing |
| `Foundation`  | `base.*`      | business operations and admin flows                          |
| `Distributor` | `post.*`      | content and API delivery                                     |

## Core Cases

- host mismatch returns 404
- redirect targets stay on the allow-list
- sign-in and passkey flows write the expected cookies and tokens
- foundation contact and admin flows validate input and persist encrypted data
- distributor delivery flows respect the public/read-only contract
- cross-boundary helpers use native engine routing proxies
- database ownership matches the engine assigned to the record class

## Non-Functional Checks

- health endpoints stay fast
- lint and test suites remain green
- audit and security checks run before release
- docs and plans stay synchronized with the current four-engine boundary model
