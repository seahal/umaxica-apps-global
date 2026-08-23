# Cloudflare Private Origin Contract

This repository exposes Rails to Cloudflare Tunnel only through the Podman `frontend` network. The
same tunnel supports published browser hostnames and a future Workers VPC Service, but those ingress
paths do not change Rails authentication, authorization, or surface ownership.

The connector itself is not `frontend`-only. `compose.custom.yaml` also attaches it to
`umaxica-edge-tunnel`, an `external: true` network created and owned by the Edge compose project,
because the Next.js Core origin runs there and shares no network with this project otherwise. That
attachment is what makes Edge-bound ingress rules resolve; it grants no new path to Rails, which
stays reachable only over `frontend`, and Edge Core stays unreachable from `frontend`.

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
5. **Workers VPC connector prerequisites**: cloudflared is pinned at `2025.7.0`, runs with QUIC,
   authenticates with credentials written by an in-container browser login (no `TUNNEL_TOKEN`, no
   host `.env` entry), names its tunnel in argv, and requires outbound UDP port 7844. See
   "Authenticating the Connector" below: `tunnel login` alone is not sufficient.
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
tunnels in
[Connect with Cloudflare Tunnel](https://developers.cloudflare.com/workers-vpc/configuration/tunnel/).
Do not switch this connector to HTTP/2 for Workers VPC DNS routing.

Access and Workers VPC are separate route types. Based on that separation, this repository does not
require `CF-Access-*` headers on the VPC path. This is an operational inference to confirm in the
Cloudflare account before rollout, not a Rails authentication bypass.

## Authenticating the Connector

`cloudflared` splits its authentication across two artefacts, and neither of them decides which
tunnel to serve:

| Artefact             | Written by                                                  | Role                      |
| -------------------- | ----------------------------------------------------------- | ------------------------- |
| `cert.pem`           | `cloudflared tunnel login`                                  | account certificate       |
| `<TUNNEL_NAME>.json` | `cloudflared tunnel token --cred-file` (or `tunnel create`) | per-tunnel credentials    |
| tunnel name          | `compose.custom.yaml` argv                                  | which tunnel `run` serves |

`tunnel run` needs all three. A connector given only `cert.pem` exits immediately with
`"cloudflared tunnel run" requires the ID or name of the tunnel to run`, so the tunnel name is
written into the connector's `command` in `compose.custom.yaml`. It is an account-scoped identifier,
not a credential.

The credentials live in the `cloudflared-credentials` named volume rather than a tmpfs. A tmpfs is
discarded together with the one-shot container that would write it, and `podman compose exec` cannot
reach a connector that is crash-looping for want of that same credential, so the ephemeral variant
left no reachable way to authenticate. The volume is Podman-managed: it is not in the repository
tree, not in `.env`, and not in any host bind mount.

Bootstrap once per credential volume, then start the connector:

```bash
COMPOSE="podman compose -f compose.yaml -f .devcontainer/compose.override.yml -f compose.custom.yaml"

$COMPOSE --profile tunnel-bootstrap run --rm cloudflared-login
$COMPOSE --profile tunnel-bootstrap run --rm cloudflared-credentials
bin/tunnel-preflight
$COMPOSE --profile tunnel up -d cloudflare-tunnel
```

`bin/tunnel-preflight` refuses to pass unless the tunnel is named, the external Edge network exists,
and both credential files are in the volume. Run it before every `up`: a connector that starts
without them exits within milliseconds, and Podman applies no backoff to a restart policy.

To revoke, delete the volume; the next bootstrap starts from an unauthenticated state:

```bash
podman volume rm umaxica-apps-global-dc_cloudflared-credentials
```

The connector is behind the `tunnel` Compose profile, so a development session that needs no edge
ingress never creates it and cannot be affected by its misconfiguration.

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
- the Edge compose project is running, so `umaxica-edge-tunnel` exists before the connector is
  created. The network is `external: true` here, so bringing the Edge stack down removes it and the
  connector then fails to start rather than degrading to Rails-only reachability;
- every Edge-bound tunnel ingress rule names an unambiguous address. Podman registers a service name
  as a network alias, so `core` resolves both on `frontend` (Rails) and on `umaxica-edge-tunnel`
  (Edge Core) once the connector joins both. Ingress lives in the Cloudflare account, not in this
  repository.

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
