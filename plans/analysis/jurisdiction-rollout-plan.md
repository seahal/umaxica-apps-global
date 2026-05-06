# Jurisdiction Rollout Plan For JP, US, And EU

## Agent Brief

Use this file with one dedicated AI agent.

Agent role:

- challenge the rollout order
- identify missing launch gates
- suggest a safer capability sequence for JP, US, and EU

Expected output from the agent:

- missing rollout dependencies
- risky launch assumptions
- better phase definitions
- capability gating improvements

Out of scope for this agent:

- detailed engine boundary refactor
- detailed audit schema design
- broad architecture redesign beyond rollout sequencing

## Summary

This note records the minimum rollout order for jurisdiction-aware SNS behavior across Japan, the
United States, and the European Union.

The aim is not full legal completeness in one phase. The aim is to prevent the most predictable
product, policy, and audit failures while the platform grows.

## Problem Statement

The repository already contains region and locale concepts, but it does not yet contain a clear
staged launch model for jurisdiction-dependent behavior.

Without a staged plan, the platform risks shipping international reach before it has:

- feature gating by jurisdiction
- defensible data movement rules
- moderation reason tracking
- privacy rights handling
- minor-related controls where required

## Current Repo Findings

- Locale loading is deploy-scoped through `REGION_CODE`.
- User-facing preference state includes region and language values.
- Shared activity logging exists, but it does not yet capture jurisdiction-specific decision data.
- Contact and auth flows include security and consent-related steps, but they do not form a full
  privacy-rights or notice-and-action framework.
- Telephone normalization and some defaults still assume Japan-first behavior.

Primary references:

- `/home/jit/workspace/config/initializers/locale.rb`
- `/home/jit/workspace/app/controllers/concerns/preference/global.rb`
- `/home/jit/workspace/app/controllers/concerns/preference/base.rb`
- `/home/jit/workspace/app/models/concerns/telephone_normalization.rb`
- `/home/jit/workspace/app/services/auth/audit_writer.rb`

## Risks If Unchanged

- EU users may be served without adequate notice, appeal, or deletion handling.
- US minor-related obligations may be missed because age treatment is not modeled.
- JP-first defaults may silently distort international account data.
- Product availability may expand faster than compliance and support operations.

## Target Direction

Use a staged rollout with launch-critical controls first.

### Stage 0: Before broad public launch

- define jurisdiction resolution inputs and fallback rules
- define a capability matrix for JP, US, and EU
- block unsupported combinations instead of guessing

### Stage 1: Launch-critical controls

- feature gating by jurisdiction
- auditable jurisdiction decision output
- data residency decision for the most sensitive stores
- moderation action reason codes
- complaint, review, and appeal case identifiers
- deletion and export request intake flow

### Stage 2: Safety and privacy maturity

- richer trust and safety case management
- retention schedules by evidence class
- operator workflows for regulator and law-enforcement requests
- improved child or teen handling where required by product scope

### Stage 3: Cross-region optimization

- refined residency routing
- jurisdiction-aware replication controls
- per-jurisdiction policy rollout toggles
- transparency and operations reporting

## Minimum Capability Matrix Topics

The first matrix should define behavior for:

- account creation
- sign-in and identity proofing
- posting and interaction
- direct messaging if enabled later
- recommendations and advertising use
- moderation and user reporting
- privacy rights intake
- export, deletion, and legal hold

## Open Questions

- Which features are allowed globally at first launch, and which must stay jurisdiction-limited?
- Is the product in scope for children or teens at launch?
- Which stores must become residency-aware in phase 1?
- Which operator workflows must be available before EU launch is considered real?

## Suggested Next Implementation Steps

1. Define the initial JP, US, and EU capability matrix.
2. Create issues for jurisdiction resolution, audit enrichment, and rights-request intake.
3. Gate unsupported features behind explicit deny decisions rather than silent fallback.
4. Add implementation tracks for moderation reasons, appeal flow, and deletion or export handling.
5. Review Japan-first defaults and remove them from flows that should be jurisdiction-neutral.

## Questions To Ask The Agent

- Which launch controls are missing for JP, US, or EU?
- Which phase is too optimistic or too broad?
- Which capability should be hard-blocked until later?
- Which operational workflows are mandatory before calling the rollout real?

## Session Recap

Recent discussion added a stronger assumption that the platform may be organized around
`Identity / Global / Regional` as the main boundary model.

Implications for rollout planning:

- the rollout model should assume that `Identity` carries identity and auth roots first
- `Global` is the public sign entry surface
- `Regional` is a likely home for content and interaction roots
- cross-boundary behavior cannot depend on loose Rails coupling; it needs an explicit orchestration
  model
- naming and rollout are linked, because unclear boundaries will produce unclear rollout gates

This note should therefore be read with a stronger focus on:

- what must remain globally unique
- what must remain regionally isolated
- which product flows cross the boundary and need a formal workflow

## Related Analyses

- [Redesign Direction](./redesign-direction.md)
- [Engine Boundary Plan](./engine-boundary-plan.md)
- [Audit And Evidence Plan](./audit-and-evidence-plan.md)
