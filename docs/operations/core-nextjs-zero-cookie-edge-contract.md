# Core Next.js Zero-Cookie Edge Contract

## Purpose

This repository does not currently contain deployable Cloudflare ruleset, Worker, or Terraform
configuration for the Core web edge. The Core browser JWT cookie transport is therefore disabled by
default and must not be enabled in production until the external Cloudflare configuration enforces
this contract and verification evidence is recorded.

## Public Core Host

Canonical public Core host for this boundary:

- `jp.umaxica.app`

Current Rails defaults previously used `www.jp.umaxica.app` in some Core configuration. The edge
configuration must route `jp.umaxica.app` according to this contract, or a later ADR must explicitly
choose a different canonical host before production enablement.

## Request Routing

For `jp.umaxica.app`:

| Path            | Origin           | Cookie forwarding               |
| --------------- | ---------------- | ------------------------------- |
| `/api/v0/*`     | Rails Core       | keep `Cookie`                   |
| `/auth/*`       | Rails Core       | keep `Cookie`                   |
| `/sso/*`        | Rails Core       | keep `Cookie`                   |
| `/settings`     | Base Rails       | explicit Base credential policy |
| `/settings/*`   | Base Rails       | explicit Base credential policy |
| `/health`       | blocked publicly | no public origin                |
| `/health/*`     | blocked publicly | no public origin                |
| `/_next/*`      | Next.js Core     | remove entire `Cookie` header   |
| all other paths | Next.js Core     | remove entire `Cookie` header   |

For `side.jp.umaxica.app`:

| Path        | Origin     | Cookie forwarding             |
| ----------- | ---------- | ----------------------------- |
| `/api/v0/*` | Rails Side | remove entire `Cookie` header |

Selective auth-cookie stripping is not sufficient. The Next.js and Side origins must receive no
`Cookie` header at all.

## Response Header Rules

| Origin          | Response rule                                                     |
| --------------- | ----------------------------------------------------------------- |
| Rails Core/Base | allow `Set-Cookie` only on intended auth/session/preference paths |
| Next.js Core    | remove every `Set-Cookie` header                                  |
| Side            | remove every `Set-Cookie` header                                  |

Next.js toast, flash, and other UI state must use non-cookie state such as client memory, browser
storage, a URL nonce, hydration-time Rails API result, or non-sensitive public state.

## Manual Verification

Before setting `CORE_BROWSER_JWT_COOKIE_ENABLED=1` in production, record evidence for all of these:

1. A request to `https://jp.umaxica.app/_next/...` with a synthetic `Cookie` header reaches the
   Next.js origin without a `Cookie` header.
2. A request to a page route on `https://jp.umaxica.app/...` with a synthetic `Cookie` header
   reaches the Next.js origin without a `Cookie` header.
3. A response from Next.js that attempts to emit `Set-Cookie` reaches the browser without
   `Set-Cookie`.
4. A request to `https://jp.umaxica.app/api/v0/...` reaches Rails Core with the credential cookie
   header intact.
5. Requests to `https://jp.umaxica.app/oidc/callback`, `/sign/out`, `/sign/out/complete`,
   `/web/v0/...`, and `/edge/v0/...` reach Rails Core with required cookies intact.
6. A request to `https://side.jp.umaxica.app/api/v0/...` with a synthetic `Cookie` header reaches
   Side without a `Cookie` header, and Side rejects any bypassed request that still contains one.
7. Public requests to `/health` and `/health/*` are blocked at the edge or return only the approved
   no-leak public behavior from `adr/internal-health-endpoint-edge-isolation.md`.

## Cloudflare Access Interaction

Development published `jp.umaxica.{app,com,org}` through Cloudflare Tunnel behind a Cloudflare Access
application on 2026-08-10. Rails Core answers every path on those hostnames today; the Next.js origin
does not exist yet, so the split above is not in force. Evidence:
`notes/implementation/2026-08-10-development-tunnel-access-verification.md`.

Two consequences for the work that implements this contract.

Access issues a `CF_Authorization` cookie scoped to the Core hostname, and the edge forwards it to
whichever origin serves the request. It is therefore covered by the "remove entire `Cookie` header"
rows above, not exempt from them. Verification items 1 and 2 must be run with an Access session
active, not only with a synthetic `Cookie` header, or they will pass while the real cookie still
reaches Next.js.

The `core-jp` application sets `http_only_cookie_attribute` to `false`, which makes `CF_Authorization`
readable by JavaScript on the Core origin, and spans `app`, `com`, and `org` in one application with
one policy and a shared session, so one authenticated session admits a principal to all three realms.

Both are accepted for development and are not defects there. Both block treating `jp.umaxica.org` as
production-ready: the cookie attribute collides with this boundary's invariant that JavaScript cannot
read credential material, and the shared application prevents governing or revoking staff access
independently of the end-user and corporate realms, which `AGENTS.md` requires to stay separate. Set
`http_only_cookie_attribute` to `true` and give `jp.umaxica.org` its own application with its own
policy before the staff realm carries production traffic. Open, not actioned.

## Production Blocker

`CORE_BROWSER_JWT_COOKIE_ENABLED` must remain unset or false in production until the route table,
request stripping, response stripping, and health blocking above are deployed and verified.
