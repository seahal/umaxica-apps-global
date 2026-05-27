# Traces and Metrics Routing via Alloy

Accepted: 2026-05-28

## Context

The repository ships a `compose.yaml` that already includes `tempo`, `prometheus`,
`grafana`, `loki`, and an `alloy` service, plus a separate `otel-collector` service.
The Rails application has `opentelemetry-sdk`, `opentelemetry-exporter-otlp`, and
`opentelemetry-instrumentation-all` declared in `Gemfile` with `require: false`. None
of these are wired up: no initializer exists, no span has ever been exported, and the
two agents (`alloy` and `otel-collector`) duplicate roles with no documented split.

Logs are out of scope for this decision. Application log policy is owned by
`application-logging-boundary.md`. Rails logs continue to be emitted to stdout.

Three boundaries already shape this design:

- The `app` / `com` / `org` surface separation must be preserved end-to-end; mixing
  surfaces is forbidden by `AGENTS.md`.
- PII, cookies, authorization headers, session ids, DBSC device ids, OTP codes, and
  step-up tokens must never leave the process inside telemetry payloads.
- The Rails container runs multiple process roles under `bin/dev` (web, jobs,
  scheduler). Their performance characteristics differ and must not be aggregated.

## Decision

### Single observability agent

Alloy is the only observability agent in this repository. The `otel-collector`
service is retired. All Rails OTLP traffic is sent to `alloy` on the `observability`
docker network. The Rails container's `depends_on` points at `alloy`, not
`otel-collector`.

### Routing

- Traces: Rails OTLP exporter → Alloy OTLP receiver → Tempo → Grafana.
- Metrics: Rails-emitted metrics use OTLP push to Alloy. Infrastructure-owned
  metrics (Postgres, Valkey, Kafka, container stats) are exposed by purpose-built
  exporters and scraped by Alloy. Alloy then writes everything to Prometheus via
  `prometheus.remote_write`. Grafana reads from Prometheus.
- Logs: out of scope. Rails continues to write to stdout. Future migration to
  Alloy → Loki is tracked separately and explicitly not addressed here.

### Phased environment scope

The first phase targets **development only**.

- `development`: OpenTelemetry SDK enabled, OTLP exporter pointing at `alloy:4318`,
  sampler at 1.0, all selected instrumentations enabled.
- `test`: OpenTelemetry SDK fully disabled via `OTEL_SDK_DISABLED=true` and an
  initializer early-return. No exporter, no batch processor, no background threads.
- `production`: deferred. Production wiring is not part of this ADR and must be
  introduced by a follow-up ADR that addresses sampling, retention, multi-instance
  service identity, and PII review on the live data path.

### Service identity

`service.name` is assigned per process role, not per Rails application. Initial
allocation:

- `umaxica-core-web` — Puma / Rails server
- `umaxica-core-jobs` — Solid Queue worker
- `umaxica-core-scheduler` — Solid Queue dispatcher
- `umaxica-core-console` — Rails console / runner (SDK disabled by default)

Resource attributes always include:

- `service.namespace=umaxica`
- `service.instance.id` (hostname or pod identity)
- `deployment.environment` (`development` initially; `test` disables SDK)
- `service.version` from the build `COMMIT_HASH`

Surface (`app` / `com` / `org`) is **not** part of `service.name`. It is recorded as
a span attribute (`umaxica.surface`) so that surface boundary remains a request-level
concern and does not fragment the service catalog.

### Instrumentation policy

`opentelemetry-instrumentation-all` is loaded but `use_all` is forbidden.
Instrumentations are enumerated explicitly (`c.use 'OpenTelemetry::Instrumentation::Rack'`,
etc.) so that any new instrumentation entering the dependency graph requires an
explicit code change. `db.statement` capture remains on the SDK default — placeholders
only, never bind values.

### PII redaction is two-stage

Personally identifiable and security-sensitive data must not reach storage even if a
single configuration mistake occurs. Redaction runs in two independent places:

1. **In-process SpanProcessor** in the Rails application. It strips cookie headers,
   authorization headers, set-cookie, URL query strings, and known sensitive
   attributes before the span is handed to the exporter. This is the application's
   responsibility: data leaves the process already cleaned.
2. **Alloy processor** (`otelcol.processor.attributes` and/or `otelcol.processor.transform`).
   It re-applies redaction on the agent side as defense in depth. New instrumentations
   that forget to filter, or future attribute additions in upstream gems, are caught
   here.

Both stages must be kept in sync. The list of redacted attribute keys lives in code
and in Alloy configuration; divergence is treated as a defect.

### Process and compose layout

- The observability service group (`alloy`, `tempo`, `prometheus`, `grafana`, and
  later `loki`) is gated behind a docker compose profile so that contributors not
  working on observability can run the application stack without it.
- Tempo, Prometheus, and (later) Loki must have explicit retention configured.
  Unbounded retention on local volumes is treated as a misconfiguration.
- The Tempo container's host port publication exists only for direct inspection
  during bring-up. Application traffic always goes via Alloy. Once the routing is
  stable, the Tempo host publication is removed.
- Grafana provisioning is mounted read-only. Default credentials are taken from
  environment variables, not committed defaults, and the admin credentials are
  treated as development-only.

### Request identifier preservation

`X-Request-Id` (ActionDispatch::RequestId) and the W3C `traceparent` `trace_id` are
both retained. `request_id` continues to identify the request for operational and
support purposes. `trace_id` becomes the primary key for traces in Tempo. Each span
carries the request_id as an attribute, and the Rails request environment carries
the current `trace_id` so it can be surfaced on error pages and in audit records.

In preparation for the eventual logs migration, Rails stdout output is expected to
include `trace_id` and `request_id` even though logs are not currently shipped to a
backend. This keeps the future Loki migration limited to agent configuration.

## Consequences

- The `otel-collector` service is removed from `compose.yaml`. The `core` service's
  `depends_on` is rewired to `alloy`.
- A development-only initializer is introduced that configures the SDK, the OTLP
  exporter, the in-process PII redaction SpanProcessor, and an explicit
  instrumentation allow-list. `test` short-circuits this initializer.
- Process roles under `bin/dev` (and equivalent production launchers) set
  `OTEL_SERVICE_NAME` per role. Mixing process roles into a single service identity
  is a regression.
- Alloy configuration carries the second redaction stage. Adding a new attribute on
  the application side requires reviewing whether Alloy's redaction list needs to
  be updated.
- The Tempo and Prometheus retention settings are required configuration, not
  optional tuning. Volumes without retention are treated as a bug.
- Metrics work is scoped to a follow-up change. Traces are landed first; metrics
  are introduced after the trace path is stable.
- A production rollout requires a new ADR. This decision does not authorize enabling
  the SDK outside development.

## Related

- `adr/application-logging-boundary.md` — log path is owned separately and is not
  changed by this decision.
- `adr/cookie-domain-scope-by-surface.md`,
  `adr/device-session-dbsc-device-id-boundary.md`,
  `adr/signed-return-targets-only.md` — sources of attribute names and values that
  must never appear in telemetry payloads.
- `plans/backlog/audit-log-write-points-and-otel-mapping.md` — informs the eventual
  span-attribute naming for audit-relevant events.
