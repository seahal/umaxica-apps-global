# Cloudflare Request Paths and Trust Boundaries

This document describes every request path that reaches Rails, the trust domain
each hop belongs to, and which component can forge which header. It exists because
Tailscale, Cloudflare Tunnel, Cloudflare Access, and Workers VPC are four distinct
trust domains that must not be conflated (see `docs/operations/remote-codex-over-tailscale.md`
for the Tailscale/development path in detail).

## Trust Domains

| Domain | Purpose | Never used for |
|---|---|---|
| Tailscale | Development and operator access to `core` over SSH | Production traffic, Rails authentication |
| Cloudflare Tunnel | Selected externally reachable Rails ingress | Service-to-service (Workers/Next.js) traffic |
| Workers VPC | Cloudflare Worker/Next.js -> Rails, service-to-service | Public browser traffic, operator access |
| Cloudflare Access | Perimeter for explicitly protected hostnames | Rails' primary identity system — Rails authentication and authorization remain authoritative regardless of Access |

## Request Paths

### 1. Public browser request through Cloudflare

```text
Browser --(HTTPS)--> Cloudflare edge --(QUIC tunnel)--> cloudflared (compose: cloudflare-tunnel)
  --(private `frontend` network)--> core (Rails)
```

- `cloudflared` is configured in `compose.custom.yaml` (`cloudflare-tunnel` service, image
  `cloudflare/cloudflared:2025.7.0`, `tunnel --protocol quic run`, token-based
  auth). The base `compose.yaml` must never define it — see the note at `compose.yaml:604-609`.
  It is the only component on the `frontend` network besides `core` itself.
- `core` never publishes a host port in the base `compose.yaml` — verified by
  `test/unit/security/tunnel_origin_isolation_test.rb`. This is the actual security
  boundary: nothing outside the compose project's private networks can reach Rails
  directly.
- Headers Cloudflare's edge sets and the client cannot override: `CF-Connecting-IP`,
  `CF-Ray`, `CF-IPCountry`. Headers the client *can* set and Cloudflare may append
  to (not replace) if already present: `X-Forwarded-For`.
- Rails currently derives `request.remote_ip` from `X-Forwarded-For` via
  `ActionDispatch::RemoteIp`, using the framework default `trusted_proxies` (RFC1918
  private ranges) — `config/application.rb`'s `TrustedProxiesConfig` machinery is a
  no-op today because `ENV["TRUSTED_PROXIES"]` is never set anywhere in the repo.
- **Verified property, not a desired one**: `ActionDispatch::RemoteIp` does not
  gate trust on whether the immediate peer (`REMOTE_ADDR`) is itself a trusted
  proxy — it only strips proxy-hop IPs found *within* the `X-Forwarded-For` chain.
  A request that reached Rails directly, bypassing `cloudflared`, could set an
  arbitrary `X-Forwarded-For` and have it trusted regardless of `trusted_proxies`
  value. See `test/unit/security/tunnel_origin_isolation_test.rb` for the
  reproducible proof (no live infrastructure required). **The real control is
  network isolation** (previous paragraph), not the `trusted_proxies` value itself.
- **Decision**: do not widen `trusted_proxies` to Cloudflare's public IP ranges —
  there is no evidence Rails ever receives a connection directly from those
  addresses (it only ever sees `cloudflared`'s private network address). Do not
  implement a custom `CF-Connecting-IP` reader either: Rails' `ActionDispatch::RemoteIp`
  has no configurable header name (verified — `forwarded_for`/`client_ip` are
  hardcoded to `X-Forwarded-For`/`Client-Ip` in Rack, not configurable), so
  honoring `CF-Connecting-IP` would require new custom middleware. Given the network
  isolation invariant already holds and is regression-tested, that additional
  middleware is not currently justified — revisit only if a feature specifically
  needs Cloudflare's more precise client-IP header.

### 2. Operator/browser request through Cloudflare Access

```text
Browser --(HTTPS, Access cookie/JWT)--> Cloudflare edge --(Access policy check)-->
  cloudflared --(originRequest.access JWT validation, if configured)--> core (Rails)
```

- Cloudflare Access is a perimeter, not Rails' identity system. Rails authentication
  and authorization (session/credential ceremonies, MFA, passkeys) remain
  authoritative for every request, Access-protected or not.
- `cloudflared` supports validating the Access JWT itself before proxying, via
  `originRequest.access` (`required`, `audTag`, `teamName`) per hostname. This is
  the preferred validation point — it runs before the request reaches Rails at all.
- **No hostname is currently designated as Access-protected in this repository.**
  This gate does not configure `originRequest.access` for any hostname because none
  was named. When one is, add the `access` block to that hostname's `originRequest`
  in the `cloudflared` configuration and record the hostname, `audTag`, and
  `teamName` here.
- Rails does not validate `Cf-Access-Jwt-Assertion` itself and should not, unless a
  specific feature needs to consume Access identity/claims directly — none does
  today. Adding Rails-side validation merely for "defense in depth" duplicates the
  connector-side check without a concrete requirement driving it.

### 3. Worker/Next.js request through Workers VPC

```text
Cloudflare Worker (fetch()) --(Workers VPC binding)--> VPC Service (bound to a Tunnel ID)
  --(private tunnel connection)--> core (Rails)
```

- Workers VPC binds to a Tunnel-registered VPC Service and proxies an absolute-URL
  `fetch()` request to the target host/port over that tunnel connection — it reuses
  the same Cloudflare Tunnel infrastructure as path 1, not a separate ingress.
  `cloudflared 2025.7.0`, already pinned in `compose.custom.yaml:12-13`, is the minimum
  version Workers VPC requires (comment already present at that line).
- This path does not currently exist in the repository — no VPC Service or Worker
  binding is configured. This section documents the intended architecture per your
  Q5 answer (Workers VPC is a distinct, retained trust domain, not a Tunnel
  replacement) for when that work is scoped.
- Authentication for this path, once implemented, should be evaluated on its own
  threat model (a Worker is a Cloudflare-controlled, non-browser client) rather than
  reusing the browser-facing Access flow.

### 4. Tailscale development access

```text
Mac (Tailscale client) --(Tailscale network)--> core userspace tailscaled
  +-- built-in Tailscale SSH --> global
  `-- HTTPS Serve --> Rails on 127.0.0.1:3000
```

- The binaries, supervisor, and state volume exist only in the development
  target and Dev Container overlay; they are absent from production. This path
  uses Tailscale SSH rather than OpenSSH or TCP port 22 forwarding. See
  `docs/operations/remote-codex-over-tailscale.md` and
  `docs/operations/claude-remote-control.md` (which remains independent).

## Header Trust Summary

| Header | Set by | Forgeable by a direct-access attacker (network isolation intact)? | Forgeable if network isolation is ever broken? |
|---|---|---|---|
| `CF-Connecting-IP` | Cloudflare edge only | No (Rails doesn't read it) | Yes, trivially — Rails has no way to distinguish a real edge from a direct attacker |
| `X-Forwarded-For` | Cloudflare edge (appends), `cloudflared` (passes through) | No — attacker cannot reach `core` at all | Yes — `ActionDispatch::RemoteIp` trusts it regardless of peer, per the verified property above |
| `Cf-Access-Jwt-Assertion` | Cloudflare Access, after policy evaluation | No (Rails doesn't validate it; connector should) | Cryptographically signed — not forgeable even with direct access, unlike the IP headers above |

## Non-Goals of This Document

- Does not implement Workers VPC or Access JWT validation for any hostname — none
  was designated. Update this document when one is.
- Does not add Rails-side `CF-Connecting-IP` support — no feature currently needs
  it, and adding custom middleware for it now would be unjustified scope.
