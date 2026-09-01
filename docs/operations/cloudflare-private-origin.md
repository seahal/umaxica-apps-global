# Cloudflare Private Origin Contract

This repository exposes Rails to Cloudflare Tunnel only through the Podman `frontend` network. The
same tunnel supports published browser hostnames and a future Workers VPC Service, but those ingress
paths do not change Rails authentication, authorization, or surface ownership.

The connector is attached only to this compose project's private `frontend` network. The Edge and
Global compose projects must not share a host Podman network. Edge Workers reach Rails through a
Cloudflare Workers VPC Service bound to this tunnel; they never resolve or dial the Rails container
over a cross-project container network.

## Invariants and Verification Gates

The private transport invariant is:

```text
same Podman frontend network
  -> same Podman DNS
  -> private origin alias
  -> Rails listener
  -> HTTP response
```

The gates are intentionally independent:

1. **Private transport**: `bin/tunnel-origin-check` starts a pinned ephemeral curl container on the
   exact compose `frontend` network used by the running `cloudflare-tunnel` container. It requests
   `GET /health` through every private surface alias and requires HTTP `200`.
2. **Host Authorization**: `ruby test/config/host_authorization_contract_test.rb` boots a separate
   Rails development process, constructs the middleware from the effective development settings,
   requests the non-excluded `/` path, accepts the private origins and the published site hostnames,
   and rejects both an unknown host and an Umaxica-owned hostname that no `PUBLIC_*_URL` names.
3. **Surface routing**: the route contract tests recognize non-health application resources for the
   private Host values and assert the matching `app`, `com`, `org`, `net`, or `dev` controller.
4. **Podman DNS aliases**: `podman compose config` must show the private aliases on `core`'s
   `frontend` network and no new host port publication. The connector never needs an inbound host
   port and must not be given one; the only publications in the stack are `core`'s loopback-bound
   `3000`/`3036`. See `docs/operations/development-host-port-exposure.md`.
5. **Workers VPC connector prerequisites**: cloudflared is pinned at the supported `2026.8.2`
   release, runs with QUIC, authenticates with the remotely managed tunnel token from the gitignored
   repository `.env`, and requires outbound UDP port 7844. See "Authenticating the Connector" below.
6. **Repository regression checks**: run the focused tests first, then the full Rails suite,
   coverage, and lint checks when the test databases are available.

`/health` is excluded from Rails Host Authorization in production. A successful Gate 1 request
therefore proves transport reachability only. It does not prove that the Host is accepted by
`ActionDispatch::HostAuthorization`, and it does not substitute for Gate 3 routing evidence.

## Development Scope

Development Rails is published through this tunnel under the browser-facing site names, behind
Cloudflare Access. The `core` container therefore carries two sets of `frontend` aliases — the
private `*.localhost` origins and the published site names — and development Host Authorization
accepts both families and nothing else. See the "Development Is Tunnel-Exposed Behind Access"
section of `docs/architecture/cloudflare-request-paths.md` for how each family reaches
`config.hosts`, and for the `FORCE_SECURE_COOKIES` trade-off between the tunnel path and the
plain-`http` local path.

Access is the control that keeps the development surface non-public, and it lives in the Cloudflare
account rather than in this repository — see "External Checks" below.

## Browser Traffic Through Access

Create the Cloudflare Access application before publishing its tunnel hostname. Enable Access
protection for the published route so cloudflared validates the Access assertion before proxying the
request. Rails application authorization remains responsible for every application permission;
Access does not replace it.

The accepted scope and the deferred Rails-side JWT validation decision remain in
`adr/org-cloudflare-access-authentication-layer.md`. Cloudflare documents the deployment ordering in
[Publish a self-hosted application](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/self-hosted-public-app/)
and the tunnel Access options in
[Origin configuration](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/origin-configuration/).

## Workers VPC Traffic

Configure the future VPC Service as HTTP. Its target hostname is a private alias resolvable on the
Podman `frontend` network. Use port `3000` for this development compose stack and port `8080` for
the production image. The Worker binding belongs to the Worker repository, not this Rails
repository.

The VPC Service target selects the private route. The hostname in the Worker's `fetch()` URL remains
the origin Host/SNI, so it must be a narrowly allowlisted Umaxica surface hostname and must match
the surface route constraint. See Cloudflare's
[VPC Services configuration](https://developers.cloudflare.com/workers-vpc/configuration/vpc-services/).

Cloudflare documents cloudflared `2025.7.0` or newer, QUIC, and outbound UDP 7844 for Workers VPC
tunnels. Cloudflare supports cloudflared releases only for one year, so this repository pins the
current supported `2026.8.2` release rather than the minimum compatible release. See
[Connect with Cloudflare Tunnel](https://developers.cloudflare.com/workers-vpc/configuration/tunnel/).
Do not switch this connector to HTTP/2 for Workers VPC DNS routing.

Access and Workers VPC are separate route types. Based on that separation, this repository does not
require `CF-Access-*` headers on the VPC path. This is an operational inference to confirm in the
Cloudflare account before rollout, not a Rails authentication bypass.

## Authenticating the Connector

`cloudflare-tunnel` is a connector for the existing remotely managed tunnel. It reads the tunnel's
scoped connector token from `CLOUDFLARED_TOKEN` in the repository-local `.env`; Compose passes that
value to cloudflared as `TUNNEL_TOKEN`. This is not an account API key. It authorizes a connector to
run that tunnel, so it is still a secret and must not be committed, logged, or pasted into a command
argument.

Retrieve the token in the Cloudflare dashboard:

1. Go to **Networking > Tunnels**.
2. Open the development tunnel.
3. Select **Add a replica**.
4. Copy only the `eyJ...` token from the displayed installation command.
5. Store it in the repository root `.env` and restrict the file mode:

```dotenv
CLOUDFLARED_TOKEN=<paste the tunnel token here>
```

```bash
chmod 600 .env
```

If `.env` already contains other settings, add or replace only its `CLOUDFLARED_TOKEN` line. Never
commit `.env`; the repository, Docker, and container build ignore files all exclude it.

The connector has no Compose profile. Once `.env` contains the token, the standard Dev Container
lifecycle starts `core` and `cloudflare-tunnel` together:

```bash
devcontainer up --workspace-folder .
bin/tunnel-origin-check
```

Run these commands from a host terminal, not from inside `core`. A missing token fails during
Compose resolution with `CLOUDFLARED_TOKEN must be set in .env`; there is no anonymous or
browser-login fallback.

Do not leave a standalone `docker run ... tunnel run --token ...` connector running for this tunnel
at the same time. Inspect `docker ps` and `podman ps` on the host before switching to the Compose
sidecar.

To rotate or revoke the connector credential, refresh the token in the Cloudflare dashboard, replace
only the `CLOUDFLARED_TOKEN` value in `.env`, and recreate the connector. Removing the local value
alone does not revoke a copied token at Cloudflare:

```bash
podman compose -f compose.yaml --profile tunnel \
  up -d --force-recreate --no-deps cloudflare-tunnel
```

The connector reaches Rails directly over `frontend`. It has no `host.docker.internal` alias, no
Edge project network, and no supported route back through a host-published application port. Keep
the Cloudflare VPC Service pointed at an unambiguous Rails service address on `frontend`.

## Running the Transport Probe

Start `core` and `cloudflare-tunnel`, then run:

```bash
bin/tunnel-origin-check
```

The probe does not execute anything inside the cloudflared container and does not require that image
to contain a shell, curl, or wget. It discovers the connector container's actual compose-labeled
`frontend` network and attaches `curlimages/curl:8.16.0` by immutable digest to that same network.
Each line is explicitly labeled as transport evidence.

The probe pulls its pinned image on first use. Failure to pull the image, resolve an alias, connect
to Rails, or receive HTTP `200` makes the command fail nonzero.

Before probing origins it checks that the connector is `running` with a `RestartCount` of zero and
that cloudflared's own `/ready` endpoint answers `200`. A container id alone proves nothing: `ps -q`
still reports one between restarts, so without those gates a crash-looping connector reads as a
Rails or DNS fault instead.

## External Checks

Repository checks cannot prove these Cloudflare-account and network controls:

- outbound UDP 7844 is allowed from the connector environment;
- the Access application exists before its published hostname, including the development hostnames;
- the published route enables Access validation;
- the VPC Service target, port, and Worker binding match this contract;
- the Edge Worker uses the intended VPC Service binding, with `remote: true` for local development
  when the request must traverse Cloudflare;
- the tunnel has no replica in a network that cannot reach this Rails origin. Cloudflare may route
  traffic to any connector replica, so every replica for this tunnel must provide the same origin
  reachability.

Treat each as blocked until verified in the deployment environment. Do not infer them from a local
`/health` response.

The second and third items were verified for development on 2026-08-10 against the ten published
Rails hostnames: every unauthenticated external request returned an Access login redirect, a nonce
probe confirmed no such request reached the origin, and authenticated browser traffic was observed
arriving at Rails from a public client address. Evidence is in
`notes/implementation/2026-08-10-development-tunnel-access-verification.md`. That run covers
development only; the first and fourth items remain unverified, and production remains blocked on
all four. A dated verification run is evidence, not a substitute for re-checking after any account
change.

That run also found that `palm-jp.umaxica.app` currently carries an interactive Access application.
Palm is a bearer-token API surface whose authenticator rejects any request carrying a cookie, and
Access forwards its `CF_Authorization` cookie to the origin, so interactive Access breaks both
browser and native clients there. Resolve that before treating Palm as published.

The Docs, Help, and News families are not published through the tunnel. `PUBLIC_DOCS_*_URL` names a
private `*.localhost` origin and no `PUBLIC_HELP_*`/`PUBLIC_NEWS_*` value is set, so the former
`docs-jp.`/`help-jp.`/`news-jp.umaxica.*` aliases named hostnames that nothing configured and that
Host Authorization would reject; they are removed rather than left dangling. This also retires the
pre-existing spelling mismatch between those aliases and the `docs.jp.umaxica.app` route
constraints. Publishing any of the three means choosing the canonical hostname, setting the matching
`PUBLIC_*_URL`, and adding the alias — in that order.
