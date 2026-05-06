# Operational Logging Foundation

## Summary

This note records the first design direction for operational logging.

Operational logging is different from:

- audit logging
- product analytics

Its job is to help the team detect, investigate, and recover from failures and abnormal conditions.

## Purpose

Operational logs should support:

1. incident investigation
2. abnormality detection
3. retry and failure analysis
4. service health review

## Current Direction

Operational logs should be:

- structured
- machine-filterable
- safe for production use
- correlated by request or job identifiers

Prefer structured event logging over free-form text-only logging.

## What Operational Logs Should Answer

Operational logs should help answer questions such as:

- what failed?
- where did it fail?
- how often did it fail?
- which external dependency failed?
- which request or job is affected?
- is this failure increasing?

## Recommended Logging Shape

Prefer a structured event form such as:

- event name
- error class
- request_id
- actor_type
- actor_id when safe and appropriate
- path or endpoint
- dependency name
- latency
- status
- retry count

## Minimum Initial Event Categories

### 1. Authentication failures

Examples:

- login failure
- token refresh failure
- OTP verification failure
- passkey verification failure
- OAuth callback failure

### 2. External dependency failures

Examples:

- SMS delivery failure
- email delivery failure
- Turnstile verification failure
- OAuth provider failure

### 3. Request protection events

Examples:

- rate limit triggered
- invalid CSRF
- invalid OAuth state
- token mismatch

### 4. Background processing failures

Examples:

- job failed
- retry exhausted
- delivery failed

### 5. System exceptions

Examples:

- unhandled exception
- timeout
- database write failure

## Data Minimization Rule

Operational logs must not leak secrets or high-risk payloads.

Do not log:

- passwords
- raw OTP codes
- full tokens
- authorization headers
- message bodies
- full request params by default

## Correlation Rule

Every operational log should carry enough correlation data to connect it to a real failure path.

Prefer:

- `request_id` for request flows
- job identifier for background jobs
- optional trace correlation when OTEL is available

## Relationship To OTEL

Operational logs and OTEL are related but not identical.

- OTEL is technical telemetry and tracing
- operational logs are structured application events for failure review

They should share:

- vocabulary where useful
- request correlation

They should not be collapsed into one undifferentiated stream.

## Pending Follow-Up

1. define the minimum operational log event set
2. define the shared operational log fields
3. map high-value operational events to alerting thresholds
4. decide where each event should be emitted in the codebase

## Related

- `plans/backlog/gh659-pre-consent-event-allowlist.md`
