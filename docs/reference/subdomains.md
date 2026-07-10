# Subdomain Map

Subdomain labels are entry points. They are not Rails Engine boundaries.

## Current Public Surfaces

| Surface | Default local host  | Purpose                        |
| ------- | ------------------- | ------------------------------ |
| `app`   | `www.app.localhost` | End-user product surface       |
| `org`   | `www.org.localhost` | Staff and organization surface |
| `com`   | `www.com.localhost` | Public and corporate surface   |

Identity provider hosts use the `id.*` label for the same audience families:

| Audience | Default local host |
| -------- | ------------------ |
| `app`    | `id.app.localhost` |
| `org`    | `id.org.localhost` |
| `com`    | `id.com.localhost` |

Development and network-only hosts may exist for operational endpoints, but they are not separate
Rails Engines.

## Canonical ENV Naming

URL environment variables should use the smallest boundary name that makes the ownership clear.

- `PUBLIC_*` means a browser-visible or externally reachable URL.
- `PRIVATE_*` means a Rails-internal, pod-internal, or service-internal URL.

Current runtime code still contains surface/service names for compatibility, but new docs and new
runtime config should prefer the public/private boundary language instead of inventing another
surface-prefixed URL family.

Examples of the older compatibility style that still exists in code:

- `ACME_SERVICE_URL`
- `ACME_STAFF_URL`
- `ACME_CORPORATE_URL`
- `ACME_DEVELOPER_URL`
- `ACME_NETWORK_URL`

Do not introduce engine-prefixed URL names such as `IDENTITY_SIGN_APP_URL`,
`FOUNDATION_BASE_ORG_URL`, or `DISTRIBUTOR_POST_APP_URL` for new runtime code in this repository.
