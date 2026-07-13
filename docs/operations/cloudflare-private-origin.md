# Cloudflare Private Origin Contract

This repository exposes Rails to Cloudflare Tunnel only through the Podman `frontend` network. The
same tunnel supports published browser hostnames and a future Workers VPC Service, but those ingress
paths do not change Rails authentication, authorization, or surface ownership.

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
   requests the non-excluded `/` path, accepts the private origins, and rejects an unknown host.
3. **Surface routing**: the route contract tests recognize non-health application resources for
   the private Host values and assert the matching `app`, `com`, `org`, `net`, or `dev` controller.
4. **Podman DNS aliases**: `podman compose config` must show the private aliases on `core`'s
   `frontend` network and no new host port publication.
5. **Workers VPC connector prerequisites**: cloudflared is pinned at `2025.7.0`, runs with QUIC,
   receives its token through `TUNNEL_TOKEN`, and requires outbound UDP port 7844.
6. **Repository regression checks**: run the focused tests first, then the full Rails suite,
   coverage, and lint checks when the test databases are available.

`/health` is excluded from Rails Host Authorization in production. A successful Gate 1 request
therefore proves transport reachability only. It does not prove that the Host is accepted by
`ActionDispatch::HostAuthorization`, and it does not substitute for Gate 3 routing evidence.

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
Podman `frontend` network. Use port `3000` for this development compose stack and port `8080` for the
production image. The Worker binding belongs to the Worker repository, not this Rails repository.

The VPC Service target selects the private route. The hostname in the Worker's `fetch()` URL remains
the origin Host/SNI, so it must be a narrowly allowlisted Umaxica surface hostname and must match the
surface route constraint. See Cloudflare's
[VPC Services configuration](https://developers.cloudflare.com/workers-vpc/configuration/vpc-services/).

Cloudflare documents cloudflared `2025.7.0` or newer, QUIC, and outbound UDP 7844 for Workers VPC
tunnels in [Connect with Cloudflare Tunnel](https://developers.cloudflare.com/workers-vpc/configuration/tunnel/).
Do not switch this connector to HTTP/2 for Workers VPC DNS routing.

Access and Workers VPC are separate route types. Based on that separation, this repository does not
require `CF-Access-*` headers on the VPC path. This is an operational inference to confirm in the
Cloudflare account before rollout, not a Rails authentication bypass.

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

## External Checks

Repository checks cannot prove these Cloudflare-account and network controls:

- outbound UDP 7844 is allowed from the connector environment;
- the Access application exists before its published hostname;
- the published route enables Access validation;
- the VPC Service target, port, and Worker binding match this contract.

Treat each as blocked until verified in the deployment environment. Do not infer them from a local
`/health` response.

The pre-existing public alias spelling mismatch (`docs-jp.umaxica.app` in compose versus
`docs.jp.umaxica.app` in route constraints, with the same pattern for help and news) is unchanged by
this private-origin work and requires separate follow-up.
