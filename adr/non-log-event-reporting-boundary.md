# Non-Log Event Reporting Boundary

Accepted: 2026-06-18

## Context

`adr/application-logging-boundary.md` keeps application logging on `Rails.logger` and rejects custom
`Rails.event.info/warn/error/debug/record` shims as an application logging API. Some browser sensor
inputs still need a lightweight in-process observability path before they become structured
application log lines.

CSP violation reports are the first such input. They are browser-generated, cross-site sensor
reports. They are not business records, audit records, product analytics events, or database
persistence candidates.

## Decision

Use `Rails.event.notify` only for non-log observability events. Do not use `Rails.event` as the
application logging API.

Application logs continue to use `Rails.logger`. When a non-log observability event needs to become
a structured Rails log line, an in-process `Rails.event` subscriber may receive the event and write
the sanitized fixed-schema payload through `Rails.logger`.

CSP violation reports use this boundary:

- the controller concern is only the CSP report endpoint ingress adapter;
- the intake service parses, normalizes, scrubs, builds a fixed-schema payload, and calls
  `Rails.event.notify("security.csp_violation.reported", payload)`;
- the subscriber runs inside the Rails process and writes the event to the structured Rails log;
- raw CSP report bodies are not persisted in the application database.

## Consequences

- `Rails.event.notify` is permitted for non-log observability events only.
- `Rails.event` must not regain application logging convenience methods.
- CSP violation report handling remains synchronous and in-process; no subscriber daemon, job, or
  external monitoring integration is introduced.
- Application log sinks remain controlled by `Rails.logger`.

## Related

- `adr/application-logging-boundary.md`
- `docs/security/observability-boundary.md`
