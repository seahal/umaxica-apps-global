# Health Check Endpoints

This application does not use Rails' default `/up` endpoint for orchestrator health checks. The
current health endpoints are surface-local and host-constrained:

- `GET /health`
- `GET /health/livenesses`
- `GET /health/readinesses`
- `GET /health/startups`

These are **internal-only checkpoints** for orchestrators and monitoring probes, not a user-facing
contract. Public traffic to them is blocked at the Cloudflare edge (see "Edge Access Policy" below).
User-facing availability and incident information is served by a single integrated status page
hosted as an external service, which is the source of truth users are directed to. See
`adr/internal-health-endpoint-edge-isolation.md`.

## Policy

1. Do not point Kubernetes, Docker Compose, load balancers, or monitoring probes at `/up`.
2. New infrastructure configuration must use the current `/health` endpoints and must preserve host
   constraints for the target surface.
3. Legacy `/edge/v0/health` and Sign `/web/v0/health` endpoints are retired and must not be used.

## Edge Access Policy

`/health` and every path beneath it are internal-only. Public traffic to them must be blocked at the
Cloudflare edge (the `cloudflare-tunnel` service in `compose.yaml` is the edge in front of the
origin). The decision is recorded in `adr/internal-health-endpoint-edge-isolation.md`.

Blocked paths (all surfaces, all hosts):

- `/health`
- `/health/livenesses`
- `/health/readinesses`
- `/health/startups`

The edge rule is configured and owned on the Cloudflare side; this repository does not hold the edge
configuration. The intended rule is a Cloudflare WAF / firewall block (return `403`/`404`, or a
Cloudflare Access policy) on requests whose path matches `/health` or `/health/*`, for public
traffic on every served host.

Internal probing is **not** affected by this block: orchestrators, the container engine, and
monitoring reach the origin directly (not through the public edge), so `liveness`, `readiness`, and
`startup` continue to work for infrastructure even while public access is blocked.

No application-layer guard enforces this today; it relies on the origin being unreachable publicly
behind the tunnel. If a future topology exposes the origin directly, revisit a Rails-layer guard for
`/health*`.

User-facing availability and incident status is served by a single integrated status page (external
service), not by these endpoints.

## Why `/up` Is Not Used

The application integrates `Authentication::Base` into the application controller hierarchy, where
controllers without an explicit authentication mode default to `deny_all`. Rails'
`Rails::HealthEndpoint` does not declare this application's authentication mode metadata, so
`GET /up` is not the supported health-check contract.

## Endpoint Roles

| Path                | Role                                                                    |
| ------------------- | ----------------------------------------------------------------------- |
| `/health`             | Plain-text snapshot of nested probe statuses.              |
| `/health/livenesses`  | Plain-text liveness probe. It must remain dependency-free. |
| `/health/readinesses` | Plain-text readiness probe for surface dependencies.       |
| `/health/startups`    | Plain-text startup probe for boot-time checks.             |

The former `/health/live` and `/health/ready` paths were removed outright (no compatibility shim);
`test/integration/edge_health_routes_test.rb` guards against their reintroduction. Infrastructure
probe configuration must point at the `liveness` / `readiness` paths.

All probe responses must avoid exposing internal topology, exception details, credentials, or full
dependency names. See `docs/reference/health-endpoints.md` for the plain-text contract.

## Related Edge And Firewall Boundary

Do not use Rails, Nginx, or task-local firewall rules as the primary control for public abuse
traffic. Public HTTP DoS and generic abuse controls are expected to live at CloudFront + AWS WAF,
with the ALB acting as an origin gate and ECS tasks accepting traffic only from the ALB security
group. See `adr/dos-and-firewall-controls-at-cdn-aws-edge-not-in-rails.md`.

## Related

- `app/controllers/concerns/health_check_rendering.rb`
- `app/services/health.rb`
- `docs/reference/health-endpoints.md`
- `test/integration/health_endpoints_test.rb`
- `test/integration/edge_health_routes_test.rb`
