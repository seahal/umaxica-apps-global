# Application Logging Boundary

Accepted: 2026-05-21

## Context

The application previously had a `structured_logging.rb` initializer that mixed several concerns:

- JSON formatting for the Rails application logger
- convenience methods on `Rails.event`
- forwarding `Rails.event` emissions back into `Rails.logger`
- product analytics consent filtering

This made access logs, application logs, event reporting, and analytics consent look like one
pipeline even though they have different purposes.

## Decision

Access logs stay on Lograge. Lograge owns request-completion logging and emits one normalized JSON
object per request.

Application logs use `Rails.logger`. Code that needs to write operational application logs should
call `Rails.logger.debug/info/warn/error/fatal` directly. Existing event-style application log calls
are migrated to logger calls.

Application logs are for developers and infrastructure operators. They should support debugging,
incident response, operational visibility, and failure diagnosis. They are not the authoritative
record for important business, security, compliance, or accountability events.

Purchase events, audit logs, compliance records, and similarly important events must be explicitly
specified before implementation. The specification must identify the event schema, owner, retention
expectation, and access path. Teams must consider from the start whether such events belong in a
durable datastore instead of, or in addition to, application logs.

Structured application logging should be provided by a logging gem or a dedicated logger formatter,
not by ad hoc `Rails.event` monkey patches. Until that dependency is selected, application event
messages are formatted through the small `LogEvent` helper and sent through `Rails.logger`.

`Rails.event` is not the application logging API. It may be reconsidered later for non-log event
reporting, but it must not be required for ordinary application log output.

## Consequences

- Access log shape remains controlled by `config/initializers/lograge.rb`.
- Application log output remains controlled by the configured Rails logger.
- Important purchase, audit, security, and compliance events require explicit specification and
  durable storage consideration before implementation.
- Application code no longer depends on custom `Rails.event.info/warn/error/debug/record` methods.
- Future structured logging work can replace `LogEvent` and the Rails logger formatter without
  changing the access-log pipeline.
- Product analytics consent filtering must be redesigned separately if product analytics events are
  reintroduced.

## Related

- Current operations doc: `docs/security/observability-boundary.md`
