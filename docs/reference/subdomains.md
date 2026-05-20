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

Host and origin environment variables should name the surface or service directly. Current route
fragments use variables such as:

- `APEX_SERVICE_URL`
- `APEX_STAFF_URL`
- `APEX_CORPORATE_URL`
- `APEX_DEVELOPER_URL`
- `APEX_NETWORK_URL`

Do not introduce engine-prefixed URL names such as `IDENTITY_SIGN_APP_URL`,
`FOUNDATION_BASE_ORG_URL`, or `DISTRIBUTOR_POST_APP_URL` for new runtime code in this repository.
