# Subdomain Map

Subdomain labels are entry points. They are not the same thing as engine boundaries.

## Host Labels

- `sign` -> public sign entry surface owned by Identity
- `base` -> foundation operations and management surface (formerly `core` / `ww`)
- `acme` -> zenith shared entry surface
- `post` -> distributor API and delivery surface

## Audience Tiers

Each host label is combined with an audience tier to form the full hostname.

| Tier  | Purpose                                   | Example (base)       |
| ----- | ----------------------------------------- | -------------------- |
| `app` | Public end-user surface                   | `base.app.localhost` |
| `org` | Service operator and admin surface        | `base.org.localhost` |
| `com` | Corporate and public-information surface  | `base.com.localhost` |
| `dev` | Developer and operational tooling surface | `base.dev.localhost` |
| `net` | Private internal-service API surface      | `base.net.localhost` |

### Notes

- `app`, `org`, and `com` are public-facing audience categories.
- `dev` is for human operational use.
- `net` is for non-public internal API communication between services.
- `net` should not be treated as a general public browser surface.

## Full Hostname Matrix

| Host label | `app`                | `org`                | `com`                | `dev`                | `net`                |
| ---------- | -------------------- | -------------------- | -------------------- | -------------------- | -------------------- |
| (acme)     | `app.localhost`      | `org.localhost`      | `com.localhost`      | `dev.localhost`      | `net.localhost`      |
| `sign`     | `id.app.localhost`   | `id.org.localhost`   | `id.com.localhost`   | `sign.dev.localhost` | `sign.net.localhost` |
| `base`     | `base.app.localhost` | `base.org.localhost` | `base.com.localhost` | `base.dev.localhost` | `base.net.localhost` |
| `post`     | `post.app.localhost` | `post.org.localhost` | `post.com.localhost` | `post.dev.localhost` | `post.net.localhost` |

## Canonical ENV Naming

Host and origin environment variables use this canonical format:

- `ENGINE_HOSTLABEL_AUDIENCE_URL`

Examples:

- `IDENTITY_SIGN_APP_URL`
- `ZENITH_ACME_ORG_URL`
- `FOUNDATION_BASE_COM_URL`
- `DISTRIBUTOR_POST_APP_URL`
- `DISTRIBUTOR_POST_DEV_URL`
- `DISTRIBUTOR_POST_NET_URL`
