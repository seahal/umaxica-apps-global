# Org Operator Acquisition And Lifecycle Implementation Plan

Status: deprecated

Deprecated: 2026-06-02

Deprecation reason: This backlog plan makes an unknown `org` social identity non-provisioning and
keeps operator acquisition outside public social signup. That remains the production target, but it
temporarily conflicts with the current decision to permit `org` Google signup as a QA-only temporary
gateway behind an explicit environment flag.

Successor plan: `plans/active/org-com-google-social-temporary-gateway-plan.md`.

## Purpose

Track future `org` operator acquisition and lifecycle work separately from the app/com sign-up state
machine implementation.

The current app/com sign-up plan may provide reusable sequence, participant, policy-context, and
finalization interfaces. This plan decides how, or whether, org should use those interfaces for
operator candidate intake, controlled invitation acceptance, and operator lifecycle requests.

## Source Material

- `adr/sign-up-authentication-handoff-and-social-rt.md`
- `adr/sign-withdrawal-and-membership-surface-policy.md`
- `adr/authentication-assurance-level-boundaries.md`
- `docs/security/sign-up-sequence.md`
- `docs/security/sign-withdrawal-and-membership.md`
- `plans/active/sign-up-state-machine-implementation-plan.md`

## Current Product Boundary

`org` is not an app/com-style public self-service sign-up surface.

Current accepted behavior:

- public `org` sign-up entry is candidate/recruiting guidance;
- public `org` sign-up must not create an `Operator`;
- public `org` sign-up must not issue an org session;
- operator creation, mutation, withdrawal, and membership adjustment are controlled lifecycle
  operations;
- lifecycle requests require an existing authenticated operator and appropriate step-up scope.

## Relationship To App/Com Sign-Up Interfaces

Future org implementation may reuse shared interfaces from the app/com sign-up state-machine work:

- sequence transition/result objects;
- guardrail/checkpoint participant evaluators;
- policy context objects;
- Chronicle event payload builders;
- finalization result objects.

Org reuse must be explicit and surface-aware. It must not inherit app/com public self-service
behavior by sharing a controller concern or route shape.

## Possible Future Scope

In scope for a future active version of this plan:

- candidate inquiry handoff from org sign surface to com/corporate intake;
- controlled operator invitation acceptance for pre-approved lifecycle requests;
- operator lifecycle request creation, approval, rejection, execution, and audit;
- step-up scope enforcement for operator lifecycle actions;
- guardrail stops for invalid, expired, rejected, or already-used lifecycle requests;
- reuse of app/com shared state-machine interfaces where appropriate.

Out of scope until a new ADR accepts it:

- public self-service operator creation;
- org social sign-up from unknown provider identities;
- destructive self-service operator withdrawal;
- issuing org sessions from public candidate inquiry.

## Implementation Notes For Future Work

- Start from accepted org product behavior, not from app/com sign-up route symmetry.
- Treat unknown social identities as non-provisioning until a lifecycle request or invitation says
  otherwise.
- Keep org controllers, policies, sessions, and state separate from app/com.
- Prefer reusing app/com interface contracts only after checking that the contract does not assume a
  public self-service actor.
