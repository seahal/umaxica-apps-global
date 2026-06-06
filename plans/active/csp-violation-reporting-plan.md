# CSP Violation Report Intake Plan

## Status

Planned / Deferred.

## Summary

Implement a proper CSP violation report intake path later. The current endpoint should not be
treated as a security finding by itself, but CSP reports are useful operational and security
telemetry when handled safely.

This work should establish a minimal, safe, and maintainable foundation for receiving browser CSP
violation reports, normalizing them, reducing noise, and surfacing only meaningful patterns for
later investigation.

## Intent

- Accept CSP violation reports from browsers without requiring authentication or session state.
- Support both legacy CSP report formats and modern Reporting API style reports where practical.
- Treat all report payload fields as untrusted attacker-controlled input.
- Avoid reflecting report contents in responses or storing raw sensitive data unnecessarily.
- Normalize and classify reports before logging, counting, alerting, or persisting.
- Prefer aggregate observability over per-report notifications.
- Keep the first implementation conservative and non-invasive.

## Non-Goals For Initial Slice

- Do not build a full security incident pipeline.
- Do not add noisy Slack/email alerts for every report.
- Do not automatically mutate CSP allowlists based on received reports.
- Do not depend on user authentication, session cookies, or CSRF state.
- Do not store raw report JSON long-term unless a later design explicitly justifies it.

## Initial Implementation Direction

Add a Sign/Acme/Core-appropriate public report endpoint that accepts CSP violation reports and
returns a simple no-content response. The controller should delegate parsing, sanitization,
classification, and emission to small service objects.

The first pass should focus on safe intake and structured observability:

- parse defensively;
- cap request size;
- handle malformed JSON safely;
- strip or reduce URL query strings, fragments, samples, and other potentially sensitive fields;
- classify obvious browser-extension/noise cases separately from potentially meaningful application
  violations;
- emit structured logs or metrics with stable aggregation keys;
- add rate limiting or abuse protection suitable for a public write endpoint;
- add tests for malformed reports, legacy reports, Reporting API reports, sensitive-field stripping,
  and no raw reflection.

## Review Notes

The endpoint should be reviewed as a public unauthenticated ingestion endpoint. The main risks are
log injection, sensitive data retention, noisy alerting, unbounded storage, and DoS-style report
floods rather than direct XSS from the report endpoint itself.

This plan is intentionally abstract. Concrete route names, ownership surface, storage/sink
selection, alert thresholds, and CSP header migration strategy should be decided in a later
implementation slice.
