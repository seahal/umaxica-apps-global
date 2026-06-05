# Sign In State Machine Implementation Plan

> **Updated by the current Identity Authority boundary:** Sign-in identity entry and session-token
> issuance paths belong to `sign/id`. `acme/www` consumes Sign results for Account, Selector,
> Dashboard, RP Authorization, and other business authority. Do not use older wording in this plan
> to restore the Acme aggregation model.

Status: active planning

## Purpose

Implement the sign-in sequence as an explicit state machine while preserving the current sign-in
surface boundaries for `app`, `com`, and `org`.

This plan owns sign-in flow progression only. It does not own sign-up finalization, logout token
revocation, or withdrawal lifecycle state, but it provides the sign-in boundary that sign-up uses
after durable account completion.

## Source Material

- `adr/sign-up-authentication-handoff-and-social-rt.md`
- `adr/authentication-assurance-level-boundaries.md`
- `adr/step-up-authentication-redesign.md`
- `adr/actor-current-facade.md`
- `docs/security/sign-in-sequence.md`
- `docs/security/session-limit.md`
- `docs/security/session-reset-policy.md`
- `plans/backlog/sign-in-failure-handling-plan.md`
- `plans/backlog/sign-sequence-security-review-followups.md`

## Non-Negotiable Boundaries

- Keep `app`, `com`, and `org` controllers, routes, policies, sessions, and state separate.
- `Actor.authn` exposes normalized authentication facts. It must not own route progression.
- Action Policy owns authorization decisions.
- Chronicle owns security-significant history.
- Controllers ask the state machine for the current transition/result rather than encoding route
  order directly.

## Scope

In scope:

- Email OTP sign-in where supported.
- Telephone entry plus actual verifier routing where supported.
- Passkey sign-in.
- TOTP sign-in where supported.
- Passcode sign-in.
- Social sign-in on supported surfaces.
- MFA challenge entry when primary sign-in requires it.
- Session-limit handling and restricted-session handoff.
- Sign-in guardrail.
- Session issuance.
- Sign-in checkpoint.
- Dashboard participant and safe `rt` continuation.
- Signed-in actor re-entry rejection.
- Common sign-in boundary result object.

Out of scope:

- Sign-up checkpoint and sign-up recovery.
- Logout / OIDC logout implementation.
- App/com withdrawal cycle.
- Org operator lifecycle implementation.
- Step-up rebuild internals beyond consuming its stable boundary and result.

## State Carrier

Use a short-lived sign sequence state carrier per surface. The implementation may start with a
compatibility wrapper over existing Rails session keys, but the target contract must be independent
of controller-local branching.

The carrier must record:

- surface;
- actor type and actor id after primary credential success;
- entry method;
- current participant;
- safe return path;
- session-limit gate id or nonce when present;
- MFA pending state reference when present;
- expiry time;
- terminal state;
- active sign sequence id exposed in `Actor.authn` only as a fact, not as progression authority.

## Sequence States

Expected high-level states:

```text
STARTED
PRIMARY_VERIFIED
MFA_PENDING
SESSION_LIMIT_PENDING
GUARDRAIL_PENDING
SESSION_ISSUED
CHECKPOINT_PENDING
DASHBOARD_PENDING
COMPLETED
FAILED
EXPIRED
```

The exact persisted enum names may differ, but transitions must preserve this ordering.

## Participant Contract

Guardrail, checkpoint, and dashboard are sequence participants.

Each participant returns:

- `stack`: ordered requirement items;
- `blocking?`: whether any item prevents advance;
- `cleared?`: whether all required items are cleared;
- `response`: render/redirect/plain-text stop information;
- `next`: next participant when cleared.

Expected behavior:

- Guardrail with blocking items returns plain text and does not issue a session.
- Checkpoint with blocking items renders checkpoint after session issuance.
- Dashboard consumes `rt` only when reached as a sequence participant, not on ordinary dashboard
  access.

## Sign-In Boundary Result

All sign-in methods must return a common result shape:

```ruby
SignIn::Result(
  status: :success | :mfa_required | :session_limit_pending |
          :session_limit_hard_reject | :guardrail_blocked |
          :login_forbidden | :credential_failed | :invalid_request,
  actor:,
  token:,
  sequence_id:,
  redirect_to:,
  response_status:,
  message:
)
```

Controllers map this result to HTTP behavior. They must not perform sign-up cleanup.

## Implementation Phases

1. Inventory all direct `log_in`, `complete_sign_in_or_start_mfa!`, session-limit, checkpoint, and
   dashboard redirect call sites across `app`, `com`, and `org`.
2. Introduce the common sign-in result object and adapt one low-risk method per surface.
3. Add the sequence carrier abstraction and compatibility reads from existing session state.
4. Implement guardrail as a real participant before session issuance.
5. Move checkpoint routing behind the participant contract.
6. Split ordinary dashboard access from dashboard-as-sequence-participant behavior.
7. Normalize social sign-in callback result handling to the common result object.
8. Normalize failure handling so durable actor data is never deleted by sign-in failure.
9. Remove obsolete controller-local route-order decisions after coverage is stable.

## Test Expectations

- Signed-in actor attempting sign-in gets status code plus plain text, with no redirect and no
  forced logout.
- Each sign-in method returns the common result statuses.
- Session-limit restricted flow still allows session management and promotion.
- Session-limit hard rejection stops at guardrail semantics.
- Guardrail direct access without valid sequence state is rejected with plain text.
- Checkpoint advances only with valid sequence state.
- Dashboard consumes `rt` only as a sequence participant.
- Social sign-in existing-identity failure keeps account and identity rows.
- `app`, `com`, and `org` coverage stays surface-local.

## Documentation Follow-Up

After implementation, update:

- `docs/security/sign-in-sequence.md`
- `docs/security/session-limit.md` if restricted-session behavior changes
- `docs/security/session-reset-policy.md` if reset choke points change
