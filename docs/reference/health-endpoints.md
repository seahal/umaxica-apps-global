# Health Endpoints

Health endpoints return the shared runtime health contract from the `Health` service layer. Each
surface mounts `/health/liveness`, `/health/readiness`, and `/health/startup`, which render JSON
only, plus `/health`, which renders an HTML snapshot for browsers and the same JSON snapshot for
JSON clients.

Every check (`Health::LivenessCheck`, `Health::ReadinessCheck`, `Health::StartupCheck`,
`Health::SnapshotCheck`) returns a `Health::CheckResult` (`app/services/health.rb`). The result
object owns serialization (`as_public_json`) and the 200/503 decision (`http_status` / `ok?`); the
controllers (`HealthCheckRendering`, `app/controllers/concerns/health_check_rendering.rb`) only
render it.

## JSON contract

All endpoints return the same four fixed top-level keys:

```json
{
  "status": "ok",
  "check": "readiness",
  "dependencies": { "database": "ok" },
  "details": {
    "surface": "sign app",
    "generated_at": "2026-05-29T00:17:52.131Z",
    "revision": "114fe4bd-6ee1-4f37-bf61-8e3ce208684a"
  }
}
```

Field reference:

- `status` — `"ok"` when the result is HTTP-200-worthy, otherwise `"unavailable"`. This collapses
  the richer internal vocabulary (`ok`, `degraded_acceptable`, `unready`, `starting`;
  `Health::STATUSES` in `app/services/health.rb`) into the public two-state contract.
- `check` — the probe that produced the result: `"liveness"`, `"readiness"`, `"startup"`, or
  `"health"` (the snapshot).
- `dependencies` — per-probe dependency map:
  - liveness / startup → `{}` (no external dependencies).
  - readiness → `{ "database": "ok" | "failed" }`. Only the non-sensitive public status is exposed;
    exception classes, messages, and topology are never serialized.
  - snapshot (`/health`) → `{ "liveness": {…}, "readiness": {…}, "startup": {…} }`, each value the
    nested public JSON of that probe.
- `details` — non-sensitive metadata only: `surface` (the profile surface label), `generated_at`
  (UTC ISO 8601 with milliseconds and a trailing `Z`), `revision` (from `Rails.app.revision`,
  omitted when blank), and the internal `status` when the result is degraded. **Never** exception
  classes, messages, credentials, or topology.

## HTTP status codes

Status codes follow `Health::StatusPolicy.http_status` (`app/services/health.rb`): `ok` and
`degraded_acceptable` return `200`; `unready` returns `503`; `starting` returns `200` on the
**liveness** probe and `503` otherwise. Equivalently, `result.ok?` ⇒ `200`, else `503`.
