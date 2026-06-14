# CSP Violation Report Intake Plan

## Status

Implemented in the working tree on 2026-06-14; retained in `plans/active` until the Rails test
database environment is stable enough to complete verification.

Current implementation:

- delegates controller handling to `CspViolationReportIntake`;
- accepts legacy `csp-report` and Reporting API `csp-violation` bodies;
- caps request bodies at 64 KiB;
- treats malformed and oversized bodies as no-log accepted intake outcomes;
- strips URL query strings and fragments;
- drops `script-sample` and does not log raw request payloads;
- classifies browser-extension noise separately from application violations;
- emits structured aggregation keys through `JitLogEvent`;
- applies Rails rate limiting to the public `create` action via the shared CSP concern.

Verification notes:

- Ruby syntax checks passed for the service, controller concern, and focused tests.
- First focused Rails run reached the tests and had no remaining assertion failures after the
  extension aggregation fix, but fixture loading hit a DB deadlock/foreign-key cleanup error.
- A follow-up focused run failed earlier because the test DB host `primary` could not be resolved.

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
