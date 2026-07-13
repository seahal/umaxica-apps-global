# Plan: Rails origin readiness for Cloudflare Access (browser) and Workers VPC (server-to-server) ingress

## Context

The future frontend (Next.js on Cloudflare Workers, separate repository) will reach this Rails app two ways:

1. Browser → Cloudflare Access → Cloudflare Tunnel → Podman private network → Rails
2. Worker → Workers VPC Service binding → Cloudflare Tunnel → Podman private network → Rails

This repository owns only the Rails/origin side. The task: verify and minimally adjust the Rails app + repo-owned Podman/cloudflared configuration so both ingress paths work, without weakening the existing host/surface security model. Documentation-driven; test-first for any behavior change.

## Repository Reality (evidence collected)

- **Rails 8.2.0.alpha** (rails/rails main, `load_defaults 8.2`), **Ruby 4.0.5**, Puma (`port ENV.fetch("PORT", 3000)`, default bind 0.0.0.0), dev runs `bin/dev` → foreman → `Procfile.dev`: `rails server -b 0.0.0.0 -p ${PORT:-3000}`.
- **Containers**: `compose.yaml` (project `umaxica-apps-global`), rootless Podman (`docs/operations/container-engine-podman-notes.md`). Networks: `backend`, `frontend`, `observability`, `outer`. Rails service is **`core`**, on `backend` + `frontend` (with many network aliases) + `observability` + `outer`. Base compose publishes **no host ports**; `.devcontainer/compose.override.yml` publishes `3000:3000`, `3036:3036`.
- **cloudflared already exists**: `cloudflare-tunnel` service in `compose.yaml` (lines ~466–477): image `cloudflare/cloudflared:latest`, `command: tunnel run --token ${CLOUDFLARED_TOKEN}`, on **`frontend`** network, `depends_on: core`. Token injected from git-ignored root `.env` (`${CLOUDFLARED_TOKEN}`). Tunnel ingress rules live in the Cloudflare dashboard (per ADR), documented in `plans/cloudflare-tunnel-edo-id-umaxica-app-cuddly-hickey.md` (origins `http://<surface>.<tld>.localhost:3000`).
- **Cloudflare Access is already an accepted ADR**: `adr/org-cloudflare-access-authentication-layer.md` (org read-only paths gated by Access; config in dashboard; Rails does NOT validate the JWT today). Also `adr/internal-health-endpoint-edge-isolation.md`, `adr/public-private-url-boundaries.md`, `adr/dos-and-firewall-controls-at-cdn-aws-edge-not-in-rails.md`.
- **Health**: custom per-surface `resource(:health)` + `namespace(:health){liveness,readiness,startup}` on every surface (no Rails built-in `/up`). Production: `config.silence_healthcheck_path = "/health"`, `config.host_authorization = { exclude: ->(req){ req.path == "/health" } }`.
- **Host Authorization**: production `config.hosts = [...]` explicit allowlist (boot-config host families + literals; contains duplicated base_* entries). Development `config.hosts.concat(boot hosts + public_tunnel_hosts + localhost_tunnel_hosts(:3000) + env_hosts from 34 PRIVATE_*/PUBLIC_*_URL vars)`. No wildcards/regex anywhere. Test env: none (middleware inactive).
- **Host routing**: `config/routes.rb` draws 9 domain files (base/auth/info/core/side/palm/help/docs/news); each uses literal `constraints host: [...]` per surface (app/com/org, plus net/dev for base/core). No catch-all route; unknown host → HostAuthorization block (prod/dev) and/or `RoutingError`. No surface middleware active (`app/middleware/core/surface_middleware.rb` referenced but absent).
- **Proxy/SSL**: `config.action_dispatch.trusted_proxies = TrustedProxiesConfig.parse(ENV["TRUSTED_PROXIES"])` (application.rb). Production: `assume_ssl = true`, `force_ssl = true`. Dev: neither. Secure cookies via `JitSessionCookieConfig`.
- **Tests**: 268 files use `host!`; canonical host-routing test `test/integration/sign/route_host_test.rb` (recognize_path per host incl. public cloudflared hosts); `content_surface_boundary_test.rb`, `read_only_surfaces_test.rb`, `health_endpoints_test.rb`, `cross_surface_isolation_test.rb`. Gaps: no HostAuthorization/forwarded-header/ssl tests; Info/Side/net/dev lack recognize_path-style host routing tests.

## Documentation Findings (developers.cloudflare.com, retrieved 2026-07-13)

- **Workers VPC "VPC Services"** (workers-vpc/configuration/vpc-services/): a VPC Service's configured target hostname + `http_port` control *routing only*. The **Host header (and SNI) the origin receives comes from the `fetch()` URL hostname**; the port in the fetch URL is ignored. ⇒ The existing host-constraint surface routing survives Workers VPC unchanged: the future Worker fetches `http://<surface>.<tld>.localhost/...` URLs while the VPC Service target is any one resolvable private hostname.
- **Workers VPC "Cloudflare Tunnel"** (workers-vpc/configuration/tunnel/): requires cloudflared ≥ **2025.7.0**, **QUIC** transport (`--protocol auto|quic`), outbound **UDP 7844**. Troubleshooting doc: `http2` transport works for Zero Trust but **breaks Workers VPC DNS resolution**. Target hostname must be resolvable from the private-network side (cloudflared's resolver).
- **One tunnel serves both paths** simultaneously: published public hostnames (browser/Access) and Workers VPC service routing; VPC routing is independent of public-hostname ingress rules.
- **Tunnel tokens** (cloudflare-one run-parameters / tunnel tokens): token may be supplied via `TUNNEL_TOKEN` env var instead of a CLI argument (keeps it off process listings).
- **Access self-hosted apps** (self-hosted-public-app): "We recommend creating an Access application before setting up the tunnel route" — otherwise the published hostname is public during the gap.
- **"Protect with Access"** (origin parameters, `access.required` + `access.teamName` per published application route): cloudflared validates the Access JWT before proxying; per "Validate JWTs" doc, origin-side validation is then optional ("Unless your application is connected to Access through Cloudflare Tunnel, your application must validate the token"). Matches the accepted ADR deferring Rails-side JWT validation.
- **Access does not gate Workers VPC traffic** (inferred from route-type separation; no single verbatim statement — flag in ops doc as an inference to confirm, and do NOT require CF-Access-* headers on the VPC path).

## Key gap found in compose.yaml

`core`'s `frontend` network aliases (compose.yaml:177–208) include only `info.{app,com,org}.localhost` among the private `*.localhost` origins, plus public `auth/www/side-jp/info/core-jp/jpx/palm-jp/docs-jp/help-jp/news-jp.umaxica.*` names. The tunnel plan doc targets origins like `http://base.app.localhost:3000`, `http://auth.app.localhost:3000`, `docs/news/help/core/palm.*.localhost` — **none of which resolve from the cloudflared container today**. This is the main reachability gap for both ingress paths. The `cloudflare-tunnel` service also uses `cloudflared:latest` with the token on the command line and no protocol pin — needs ≥2025.7.0 + QUIC assurance for Workers VPC.

## Architecture answer (smallest Rails-side change)

**Rails application code: zero changes.** Host-constrained routing, per-surface `/health` endpoints, explicit `config.hosts` allowlists, and env-driven trusted proxies already satisfy both paths. Because the Workers VPC Host header comes from the Worker's `fetch()` URL, the existing surface contract works unmodified — the VPC Service target just needs to be one resolvable private hostname (a Podman DNS alias), with `http_port` 3000 (dev) / 8080 (prod image). The real gaps are compose-level (missing aliases, unpinned cloudflared, token on argv, no QUIC pin), four missing `:3000` entries in development `config.hosts`, missing focused tests, and missing operator docs.

## Ordered steps

### Step 0 — Baseline (Gate 6 anchor)
Run `bin/rails test` and `COVERAGE=true bin/rails test` once; record runs/assertions/failures/errors/skips and line+branch coverage. Note: `vp test --coverage` is **not** a command in this repo — SimpleCov via `COVERAGE=true` is the supported coverage path (test/test_helper.rb:16–30).

### Step 1 — Test-first: Host Authorization contract (Gate 2)
New `test/config/host_authorization_contract_test.rb`:
- **A (behavior)**: construct `ActionDispatch::HostAuthorization` directly with a representative tunnel/VPC host list (`docs.app.localhost`, `base.app.localhost:3000`, `auth.umaxica.app`, …) and the production-style `exclude: ->(req){ req.path == "/health" }`; drive with `Rack::MockRequest`. Assert: allowed hosts → 200, `evil.example.com` → blocked, `/health` passes even with a bad Host.
- **B (source invariant, expected RED)**: read `config/environments/development.rb` and assert every private tunnel origin host appears, including the four currently missing `:3000` entries: `auth.com.localhost:3000`, `auth.org.localhost:3000`, `base.net.localhost:3000`, `base.dev.localhost:3000`.
- **C (ratchet)**: assert production.rb keeps the `/health`-only exclude and contains no `config.hosts.clear` / universal matcher.

### Step 2 — Green: `config/environments/development.rb`
Add the four missing `:3000` entries to `localhost_tunnel_hosts` (dedupe any doubles). No other Rails config change. Re-run Step 1.

### Step 3 — Test-first: VPC-style host recognition (Gate 3)
Extend existing route-contract tests in `test/integration/routes/` (repo pattern: host → controller map + `recognize_path`):
- `docs_route_contract_test.rb`, `news_route_contract_test.rb`, `help_route_contract_test.rb`: add `<x>.{app,com,org}.localhost` → `<x>/{app,com,org}/roots` (exactly the Host a Worker `fetch("http://docs.app.localhost/…")` yields; no Access headers on this path).
- `base_route_contract_test.rb`: ensure `base.net.localhost` / `base.dev.localhost` recognition is asserted.
Expected: mostly green (literal constraints exist in `config/routes/*`); any red is a genuine routing gap to fix with a one-line literal constraint addition, not to paper over.

### Step 4 — `compose.yaml` (Gates 1, 4, 5)
1. **core `frontend` aliases**: add the missing private origins matching the `PRIVATE_*_URL`/`PUBLIC_EDGE_*` env contract: `base.{app,com,org,net,dev}.localhost`, `auth.{app,com,org}.localhost`, `core.{app,com,org}.localhost`, `docs/help/news.{app,com,org}.localhost`, `palm.app.localhost`, `edge.{app,com,org}.localhost`. Keep existing aliases.
2. **cloudflare-tunnel service**: pin image to a released tag ≥ 2025.7.0 (comment: Workers VPC minimum); `command: tunnel --protocol quic run` (comment: http2 breaks Workers VPC DNS resolution; QUIC needs outbound UDP 7844); supply token via `TUNNEL_TOKEN: "${CLOUDFLARED_TOKEN}"` env and drop `--token` from argv; remove the unused `CLOUDFLARED_TOKEN` env entry. Nothing committed as a secret; `.env` stays the injection point.
3. No new host-port publishing anywhere (base compose stays port-free).
Validate with `podman compose config`.

### Step 5 — Repo-owned reachability check (Gates 1 & 4 evidence)
New `bin/tunnel-origin-check` (executable shell): for each surface origin, `podman compose exec cloudflare-tunnel wget -S -O- --header="Host: <host>" "http://<alias>:3000/health"`; PASS/FAIL per host; nonzero exit on failure. wget precedent: `plans/cloudflare-tunnel-edo-id-umaxica-app-cuddly-hickey.md` verification step; verify `which wget` in the image once at implementation time, fall back to documenting `podman compose exec core curl` if absent.

### Step 6 — Operator documentation (English, per AGENTS.md language policy)
New `docs/operations/cloudflare-private-origin.md`:
- **Browser/Access path**: create the Access application *before* publishing the hostname; enable "Protect with Access" (`access.required` per published route) so cloudflared validates the Access JWT at the connector — which is why Rails-level JWT validation stays deferred (link `adr/org-cloudflare-access-authentication-layer.md`). State what it protects (published-hostname L7) and what it doesn't (application authorization remains Umaxica's own auth stack).
- **Workers VPC path**: VPC Service = HTTP type, target hostname = a compose `frontend` alias (routing only, must resolve from cloudflared), `http_port` 3000 dev / 8080 prod; Host/SNI come from the Worker fetch URL (must be an allowlisted surface host); binding lives in the future Worker repo. Workers VPC traffic is *not* gated by Access (inferred from route-type separation in CF docs — flagged as inference). Transport reachability ≠ authorization; existing app auth boundaries unchanged.
- **Shared prerequisites**: cloudflared ≥ 2025.7.0, QUIC / outbound UDP 7844 (external firewall prerequisite — BLOCKED EXTERNALLY if unverifiable), one tunnel serves both route types, token via `TUNNEL_TOKEN`.
- Note the pre-existing hyphen/dot public-hostname drift (`docs-jp.umaxica.app` aliases vs `docs.jp.umaxica.app` route literals) as a known follow-up, unchanged here.

### Step 7 — Final verification (Gate 6)
`bin/rails test` + `COVERAGE=true bin/rails test` compared to Step 0 baseline; `bin/rubocop` on changed files; `podman compose config`. Report gates 1–6 individually (PASS / FAIL / BLOCKED EXTERNALLY — e.g., UDP 7844 egress and dashboard config are external).

## Files to touch
- `compose.yaml` — aliases + cloudflared service hardening
- `config/environments/development.rb` — four host entries
- `test/config/host_authorization_contract_test.rb` — new
- `test/integration/routes/{docs,news,help,base}_route_contract_test.rb` — extend host maps
- `bin/tunnel-origin-check` — new
- `docs/operations/cloudflare-private-origin.md` — new

## Explicitly not done
No Worker/wrangler artifacts, no Rails Access-JWT middleware (ADR defers it), no `config.hosts.clear`/wildcards, no new routes, no committed credentials, no new published host ports.

## Verification
- Gate 1/4: `bin/tunnel-origin-check` from the cloudflared container (not host `localhost`).
- Gate 2: `bin/rails test test/config/host_authorization_contract_test.rb`.
- Gate 3: `bin/rails test test/integration/routes/`.
- Gate 5: compose diff + docs (version/QUIC/alias/port evidence); UDP 7844 egress = external prerequisite.
- Gate 6: full suite + coverage vs baseline, rubocop clean.
