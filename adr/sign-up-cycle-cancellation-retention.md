# Sign-Up Cycle Cancellation Retention

Status: Accepted

Date: 2026-05-25

> **Supersession (2026-06-02):** This ADR's IdP/RP-centered authority model is superseded by
> `adr/identity-authority-boundary.md`. `acme/www` is now the Session, Token, Account, Preference,
> and Authorization Authority. `sign/id` is no longer the IdP; it is a Credential Gateway and
> Credential Ceremony Zone only. Historical implementation details in this ADR must not be used to
> reintroduce sign-side sessions, refresh tokens, preference writes, dashboards, account lifecycle,
> downstream token issuance, authorization decisions, or step-up freshness.

## Context

App and com sign-up flows use DB-backed sign-up cycles as the flow lifecycle authority. The
checkpoint route is a flow boundary and must not become the source of truth for business state,
immutability, or cleanup policy.

Cancellation must not physically destroy sign-up artifacts in the controller request. Immediate
deletion makes replay, race, audit, and recovery behavior harder to reason about. It also mixes HTTP
behavior with cleanup policy.

## Decision

`ClientSignUpCycle`, `VisitorSignUpCycle`, and `OperatorSignUpCycle` classify sign-up lifecycle by
`status_id`.

Cancelable sign-up states are limited to states before durable finalization starts:

- `STARTED`
- `CONTACT_PENDING`
- `CREDENTIAL_PENDING`
- `CONTACT_VERIFIED`
- `SOCIAL_CALLBACK_PENDING` when the surface supports it
- `GUARDRAIL_PENDING`
- `CHECKPOINT_PENDING`

`FINALIZING`, `FINALIZED`, `SIGN_IN_HANDOFF_PENDING`, and `COMPLETED` are not cancelable.

Cancel is idempotent for an already cancelled cycle. Replayed browser requests, double submits, and
mobile retries should not re-run destructive work.

Cancellation writes both lifecycle and retention fields:

- `status_id = CANCELLED`
- `cancelled_at = now` when the cycle has the column
- `discarded_at = now` for logical deletion
- `purged_at = now + retention delay` for later physical cleanup eligibility

The controller may initiate cancellation through a service, clear its local sequence carrier, and
redirect. It must not perform physical deletion or decide cleanup eligibility.

Physical cleanup is a separate cron or worker concern that selects rows whose purge time has lapsed.
Cleanup must be idempotent.

## Surface Boundaries

This decision applies to app/client and com/visitor sign-up cancellation.

Org/operator public self-service sign-up remains out of scope. Org operator acquisition continues to
use invitation and operator lifecycle routes. `OperatorSignUpCycle` may expose shared lifecycle
predicates for future reuse, but this decision does not add org public checkpoint cancellation or
operator creation behavior.

## Consequences

Cancelled email, telephone, social, and checkpoint credential artifacts can continue to occupy their
unique identifiers until the purge window expires. UI should tell the actor to retry registration
after a short delay.

Occurrence/audit records must remain independent of the physical deletion lifecycle.
