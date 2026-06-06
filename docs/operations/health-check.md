# Health Check Endpoints

This application does not use Rails' default `/up` endpoint for orchestrator health checks. The
current public health endpoints are surface-local and host-constrained:

- `GET /health`
- `GET /health/live`
- `GET /health/ready`
- `GET /health/startup`

## Policy

1. Do not point Kubernetes, Docker Compose, load balancers, or monitoring probes at `/up`.
2. New infrastructure configuration must use the current `/health` endpoints and must preserve host
   constraints for the target surface.
3. Legacy `/edge/v0/health` and Sign `/web/v0/health` endpoints are retired and must not be used.

## Why `/up` Is Not Used

The application integrates `Authentication::Base` into the application controller hierarchy, where
controllers without an explicit authentication mode default to `deny_all`. Rails'
`Rails::HealthEndpoint` does not declare this application's authentication mode metadata, so
`GET /up` is not the supported health-check contract.

## Endpoint Roles

| Path              | Role                                                             |
| ----------------- | ---------------------------------------------------------------- |
| `/health`         | HTML readiness snapshot for the current surface.                 |
| `/health/live`    | JSON liveness probe. It should remain dependency-free.           |
| `/health/ready`   | JSON readiness probe for dependencies relevant to the surface.   |
| `/health/startup` | JSON startup probe for boot-time checks relevant to the surface. |

All probe responses must avoid exposing internal topology, exception details, credentials, or full
dependency names.

## Related

- `app/controllers/concerns/health/controller.rb`
- `app/services/health/`
- `test/integration/health_endpoints_test.rb`
- `test/integration/edge_health_routes_test.rb`
