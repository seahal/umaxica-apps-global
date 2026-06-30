# Cloudflare Access Authentication for org docs/help/info/news

## Overview

The org surface's read-only content paths (`/docs/*`, `/help/*`, `/info/*`, `/news/*`) are
restricted to org staff via Cloudflare Access (Zero Trust) at the edge. No Operator session is
issued for these paths; authentication is handled entirely by Cloudflare before a request reaches
the origin.

See `adr/org-cloudflare-access-authentication-layer.md` for the rationale.

## Protected Paths

| Path prefix | Surface controller |
| ----------- | ------------------ |
| `/docs/*`   | `docs/org`         |
| `/help/*`   | `help/org`         |
| `/info/*`   | `info/org`         |
| `/news/*`   | `news/org`         |

## Out of Scope

`auth/org`, `base/org`, and `core/org` are **not** covered by Cloudflare Access. Those surfaces use
Acme/Sign ceremony + Operator session authentication, identical to the `app` and `com` surfaces.

## Authentication Flow

```
Browser
  │
  ▼
Cloudflare Access (Zero Trust)
  │  ← redirects unauthenticated users to the configured IdP login page
  ▼
Identity Provider (e.g. Google Workspace)
  │  ← user authenticates; Cloudflare validates the identity
  ▼
Cloudflare issues CF-Access-Jwt-Assertion (signed JWT)
  │
  ▼
Origin (Next.js / Rails)  ← receives request with CF-Access-Jwt-Assertion header
```

Unauthenticated requests are rejected at the Cloudflare edge and never reach the Rails origin or the
Next.js layer.

## CF-Access-Jwt-Assertion Header

Cloudflare injects this header on every request that has passed Access verification.

- **Header name**: `CF-Access-Jwt-Assertion`
- **Value**: a signed JWT issued by Cloudflare for the team domain

### Verification

To verify the token at the origin:

1. Fetch Cloudflare's public keys from the certs endpoint:
   `https://<team-name>.cloudflareaccess.com/cdn-cgi/access/certs`
2. Validate the JWT signature, `iss` (must equal `https://<team-name>.cloudflareaccess.com`), `aud`
   (must match the configured Application Audience tag), and `exp`.
3. Extract `email` or `sub` from the payload as the verified identity.

The team name and Application Audience tag are managed in the Cloudflare dashboard. Do not hardcode
them in application code; read them from environment configuration.

## Identity Provider

The connected IdP and its configuration live in the Cloudflare Zero Trust dashboard
(`Settings → Authentication → Login methods`). The selected IdP for these surfaces is recorded
there, not in this repository.

Changing the IdP or modifying Access policies does not require a code change or code review. When
the policy changes, update the **Protected Paths** table above to keep this document accurate.

## Local Development

Cloudflare Tunnel is not active in local development. These paths are therefore reachable without
authentication locally. No Rails-layer override or bypass flag is needed; the Access gate simply
does not exist in the local environment.

If an integration test needs to simulate a request that has passed Cloudflare Access, inject a
`CF-Access-Jwt-Assertion` header with a test-signed JWT and configure the JWT verifier to accept the
test signing key when `Rails.env.test?`.

## Operations

- Access policy configuration: Cloudflare Zero Trust dashboard → Access → Applications
- IdP configuration: Cloudflare Zero Trust dashboard → Settings → Authentication
- Audit log for Access decisions: Cloudflare Zero Trust dashboard → Logs → Access

Changes to the Access policy should be recorded here (protected paths table and any verification
parameters) so the intent remains traceable outside the Cloudflare dashboard.
