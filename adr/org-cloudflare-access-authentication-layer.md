# Org docs/help/info/news Authentication via Cloudflare Access

Accepted: 2026-06-29

## Context

The org surface is divided into two categories of endpoints by authentication posture:

1. **Operator-session surfaces** (`auth/org`, `base/org`, `core/org`) — require full Acme/Sign
   credential ceremonies and an Operator session, identical in depth to the `app` and `com`
   equivalents.

2. **Read-only content surfaces** (`docs/org`, `help/org`, `info/org`, `news/org`) — serve
   staff-readable content. These are planned to front a Next.js layer and do not require Operator
   session issuance or step-up ceremonies. They do require that access is restricted to org staff
   only.

Building a self-hosted identity provider, a credential ceremony flow, or a bespoke admin
authentication panel for category 2 is disproportionate. The same protection goal can be met at the
edge.

Cloudflare Tunnel already operates as the public edge for all surfaces. Cloudflare Access (Zero
Trust) can gate any tunnel-routed path with an identity check backed by an external IdP (Google
Workspace, Okta, etc.) without modifying the Rails application. The IdP connection is managed in the
Cloudflare dashboard; no self-hosted IdP is required.

The pattern is established: `adr/internal-health-endpoint-edge-isolation.md` shows the same
edge-owns-enforcement, repo-records-policy approach for health endpoints.

## Decision

1. **Scope**: Cloudflare Access (Zero Trust) is the authentication gate for the following
   org-surface paths only:
   - `/docs/*`
   - `/help/*`
   - `/info/*`
   - `/news/*`

2. Identity verification is delegated to a Cloudflare Access–connected external identity provider
   (e.g. Google Workspace). No self-hosted IdP is introduced.

3. Requests that pass Cloudflare Access carry a `CF-Access-Jwt-Assertion` header issued by
   Cloudflare. The Next.js layer or Rails origin may verify this JWT using Cloudflare's published
   certs endpoint. JWT verification details are documented in
   `docs/security/cloudflare-access-org-authentication.md`.

4. Edge enforcement configuration lives in the Cloudflare dashboard and is not stored in this
   repository. `docs/security/cloudflare-access-org-authentication.md` records the protected paths
   and the intended policy to keep it discoverable and auditable.

5. **Out of scope**: `auth/org`, `base/org`, and `core/org` are not covered by this decision. They
   continue to use Acme/Sign ceremony + Operator session authentication, identical to the `app` and
   `com` surfaces.

## Consequences

- Access control for org docs/help/info/news is delegated to the Cloudflare PaaS layer. Cloudflare
  SLA and incident windows directly affect staff reachability of these surfaces.
- IdP and Access policy changes are made in the Cloudflare dashboard and do not pass code review.
  `docs/security/cloudflare-access-org-authentication.md` is the traceability record for what is
  protected and how.
- No change to the Rails authentication pipeline. The Operator session lifecycle
  (`authenticate_operator!`, `OperatorPolicy`, etc.) is untouched by this decision.
- If a future requirement needs Operator-session-level authority on one of these paths, that path
  must be moved to `base/org` and a separate ADR must address it.
- Local development bypasses Cloudflare Access by design (the tunnel is not active locally). The
  bypass mechanism and any test overrides are documented in
  `docs/security/cloudflare-access-org-authentication.md`.

## Related

- `adr/internal-health-endpoint-edge-isolation.md`
- `adr/dos-and-firewall-controls-at-cdn-aws-edge-not-in-rails.md`
- `adr/read-only-content-surfaces-in-rails.md`
- `docs/security/cloudflare-access-org-authentication.md`
- `docs/architecture/docs-help-news-content-boundary.md`
