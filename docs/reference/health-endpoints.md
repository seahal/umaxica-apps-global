# Health Endpoints

Health endpoints return the shared runtime health contract from the `Health` service layer. Each
surface mounts `/health/livenesses`, `/health/readinesses`, and `/health/startups`, which render
plain text only (`ok` or `unavailable`, plus a trailing newline), plus `/health`, which renders a
four-line plain-text snapshot of those probes.

Every check (`Health::LivenessCheck`, `Health::ReadinessCheck`, `Health::StartupCheck`,
`Health::SnapshotCheck`) returns a `Health::CheckResult` (`app/services/health.rb`). The result
object owns the 200/503 decision (`http_status` / `ok?`); the controllers
(`HealthCheckRendering`, `app/controllers/concerns/health_check_rendering.rb`) render it as
plain text.

These endpoints are internal-only checkpoints for orchestrators and monitoring, not a user-facing
contract; public traffic to them is blocked at the edge. User-facing availability is served by a
separate integrated status page (external service). See
`adr/internal-health-endpoint-edge-isolation.md` and `docs/operations/health-check.md`.

## Plain-text contract

Probes never negotiate JSON or HTML. `Accept` is ignored; a format suffix (`.json`, `.html`,
`.txt`) is not routed.

`GET /health/livenesses`, `GET /health/readinesses`, and `GET /health/startups` each return a
single line:

```
ok
```

or, when the probe is not HTTP-200-worthy:

```
unavailable
```

`GET /health` returns four lines naming the aggregate and each nested probe:

```
status: ok
startup: ok
liveness: ok
readiness: ok
```

The public vocabulary is only `ok` / `unavailable`. That collapses the richer internal statuses
(`ok`, `degraded_acceptable`, `unready`, `starting`; `Health::STATUSES` in
`app/services/health.rb`). Exception classes, messages, credentials, topology, and the surface
label are never serialized.

## HTTP status codes

Status codes follow `Health::StatusPolicy.http_status` (`app/services/health.rb`): `ok` and
`degraded_acceptable` return `200`; `unready` returns `503`; `starting` returns `200` on the
**liveness** probe and `503` otherwise. Equivalently, `result.ok?` ⇒ `200`, else `503`.

## Caching

Every health response carries `Cache-Control: no-store`, set by
`HealthCheckRendering#disable_health_response_cache` as a `before_action`. A health response is a
verdict about one instance at one instant: a stored `200` keeps an orchestrator sending traffic to
an instance that has since failed readiness, and a stored `503` keeps traffic away from one that
has recovered. Rails would otherwise default these responses to
`max-age=0, private, must-revalidate`, which permits storage.
`test/integration/health_endpoints_test.rb` pins the header on all four endpoints and on a `503`
probe.
