# Health Endpoints

Health endpoints return the shared runtime health contract from `Health`. Each surface mounts
`/health/live`, `/health/ready`, and `/health/startup`, which render JSON via
`Health::Report#as_public_json` (`app/services/health/report.rb:34`). `/health` renders the HTML
snapshot template.

JSON responses use:

```json
{
  "status": "ok",
  "surface": "sign",
  "probe": "ready",
  "generated_at": "2026-05-29T00:17:52.131Z",
  "revision": "114fe4bd-6ee1-4f37-bf61-8e3ce208684a",
  "checks": [{ "kind": "database", "status": "ok" }]
}
```

Field reference:

- `status` — lowercase health status. One of `ok`, `degraded_acceptable`, `unready`, `starting`
  (`Health::STATUSES`, `app/services/health/check/result.rb:5`).
- `surface` — the profile surface label, such as `sign`, `acme`, or `core`
  (`profile.surface_label`).
- `probe` — the probe that produced the report: `live`, `ready`, or `startup`.
- `generated_at` — UTC ISO 8601 with milliseconds and a trailing `Z` (`generated_at.iso8601(3)`).
- `revision` — comes from `Rails.app.revision`. Omitted from the payload when blank
  (`as_public_json` calls `.compact`).
- `checks` — array of per-dependency results, each `{ "kind": ..., "status": ... }`
  (`Health::Check::Result#as_public_json`). Empty for the `live` probe.

HTTP status codes follow `Health::StatusPolicy.http_status`
(`app/services/health/status_policy.rb:6`): `ok` and `degraded_acceptable` return `200`; `unready`
returns `503`; `starting` returns `200` on the `live` probe and `503` otherwise.
