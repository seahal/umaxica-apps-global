# GH-659 Pre-Consent Event Allowlist

## Status

Backlog (2026-04-18)

## Summary

Define the minimum event allowlist that may be collected before optional analytics consent is
granted.

This is policy and observability work. It is not a Foundation versus Zenith ownership task.

## Scope

- define the minimum pre-consent allowlist
- keep scope limited to service delivery, security, and incident response
- confirm that product analytics stays disabled before `performant` consent

## Candidate Allowlist

- authentication success and failure
- OTP request and failure
- passkey verification success and failure
- OAuth callback success and failure
- rate-limit triggers
- Turnstile verification failures
- contact submission success and failure
- critical external API failures
- unhandled exceptions

## Deliverables

- written allowlist of pre-consent event classes
- short rationale for each class
- explicit rule that product analytics remains disabled before `performant` consent

## Inputs

- `docs/legal/analytics-consent-boundary.md`
- `docs/security/observability-boundary.md`
- `docs/reference/japan-saas-legal-triage.md`

## Acceptance

- the team has a concrete pre-consent allowlist
- the list excludes product analytics and marketing analytics
- the plan can be used as an implementation gate for future event work
