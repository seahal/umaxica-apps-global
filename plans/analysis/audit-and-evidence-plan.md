# Audit And Evidence Plan For Global SNS Operations

## Agent Brief

Use this file with one dedicated AI agent.

Agent role:

- challenge the current audit design
- identify evidence gaps for incidents, moderation, and privacy rights
- propose a stronger audit contract

Expected output from the agent:

- missing fields
- risky best-effort write points
- retention classification improvements
- stronger evidence model recommendations

Out of scope for this agent:

- engine extraction decisions
- jurisdiction rollout order
- broad architecture redesign outside evidence concerns

## Summary

This note records the current audit state and the evidence model that the platform should add before
it claims strong security, moderation, and privacy accountability.

The repository already has a meaningful audit foundation. The main issue is not absence. The issue
is that the current audit data is still optimized for application events, not for regulator-facing,
incident-facing, and user-rights-facing evidence.

## Problem Statement

A global SNS needs evidence that supports:

- security investigations
- moderation review
- privacy rights handling
- regulator response
- internal accountability

Current audit writes show important intent, but they do not yet guarantee the evidence quality,
completeness, or structured meaning needed for those outcomes.

## Current Repo Findings

- `Auth::AuditWriter` supports best-effort writes so auth flows do not fail when audit writes fail.
- `AuthorizationAudit` logs authorization failures and attempts to create activity records.
- Activity tables already store actor, subject, event, level, IP address, timestamps, and generic
  context fields.
- Multiple audit families exist for user, staff, preference, contact, document, and timeline
  activity.
- Current models and helpers do not enforce a shared evidence envelope for request ID, jurisdiction,
  legal basis, moderation reason, appeal chain, or retention policy.

Primary references:

- `/home/jit/workspace/app/services/auth/audit_writer.rb`
- `/home/jit/workspace/app/controllers/concerns/authorization_audit.rb`
- `/home/jit/workspace/app/models/user_activity.rb`
- `/home/jit/workspace/app/models/staff_activity.rb`
- `/home/jit/workspace/db/activity_migrate/20251225183919_create_universal_audit_tables.rb`

## Risks If Unchanged

- Critical actions may succeed even when audit persistence fails, with no durable recovery plan.
- Different audit families may encode context differently and become hard to compare.
- Moderation and privacy workflows may lack evidence fields needed to explain why a decision was
  made.
- Retention may remain too broad, too narrow, or impossible to justify because evidence classes are
  not distinguished.
- Incident reviewers may have timestamps and IPs but still miss the decision chain.

## Target Direction

Define a minimum shared evidence envelope for high-value actions.

Recommended common fields:

- `request_id`
- `actor_type`
- `actor_id`
- `subject_type`
- `subject_id`
- `jurisdiction`
- `surface`
- `realm`
- `decision_code`
- `reason_code`
- `case_id`
- `legal_basis`
- `retention_policy_id`
- `occurred_at`
- `ip_address`

Recommended event groups:

- authentication and session lifecycle
- security-sensitive account changes
- moderation actions and appeals
- privacy rights requests and outcomes
- data export, deletion, restriction, and disclosure handling

Recommended write-point rule:

- write the evidence where the business outcome becomes final
- keep telemetry and audit evidence related but separate
- use best-effort semantics only where explicitly accepted and observable

## Open Questions

- Which event types must be blocking on audit persistence, and which may remain best-effort?
- How should retention differ between security evidence, moderation evidence, and privacy request
  evidence?
- Which fields should be encrypted at rest, and which must remain indexable?
- How should the system reconstruct or replay missing evidence when non-blocking writes fail?

## Suggested Next Implementation Steps

1. Define the minimum audit envelope and event taxonomy in one shared contract.
2. Add explicit required fields for moderation, privacy, and cross-border decisions.
3. Classify audit events by retention and operational importance.
4. Identify which current best-effort write paths need compensating alerts or retry handling.
5. Open implementation issues for auth evidence hardening, moderation evidence, and privacy rights
   evidence.

## Questions To Ask The Agent

- Which current audit events are not regulator-grade evidence?
- Which actions should fail closed if evidence cannot be written?
- Which fields are required for moderation, appeal, deletion, and export cases?
- How should evidence classes differ by retention and storage sensitivity?

## Session Recap

Recent discussion did not directly redesign the audit model, but it changed the likely boundary
shape that audit evidence will need to follow.

Working implications:

- `Identity / Global / Regional` is becoming the main candidate for boundary design
- audit records may need a clearer rule for which evidence belongs to Activity, which belongs to
  Journal, which belongs to Chronicle, and which must be correlated across boundaries
- if subdomains become entry labels rather than architecture boundaries, audit evidence should avoid
  overloading subdomain names as the main ownership key

This makes it more important to define:

- Activity, Journal, and Chronicle evidence classes
- cross-boundary correlation identifiers
- retention and replay rules when one boundary succeeds and another lags

## Related Active Checklist

The near-term implementation checklist for model-layer work lives in:

- `/home/jit/workspace/plans/active/model-layer-audit-evidence-checklist.md`

## Related Analyses

- [Redesign Direction](./redesign-direction.md)
- [Engine Boundary Plan](./engine-boundary-plan.md)
- [Jurisdiction Rollout Plan](./jurisdiction-rollout-plan.md)
