# Withdrawal State Machine Implementation Plan

> **Updated by the current Identity Authority boundary:** Account withdrawal lifecycle belongs to
> `acme/www`; step-up, logout, refresh, and session-token revocation belong to `sign/id`. Acme must
> consume Sign step-up/logout results instead of owning those identity mutations directly.

Status: implemented, keep as regression checklist

## Purpose

Implement app/com withdrawal as an explicit DB-backed lifecycle state machine while keeping `org`
operator membership changes in the operator lifecycle request path.

This plan owns account withdrawal lifecycle state. It does not own sign-in, sign-up, or logout
sequence progression, but it invokes logout/session revocation behavior when withdrawal is
scheduled.

## Source Material

- `adr/sign-withdrawal-and-membership-surface-policy.md`
- `adr/authentication-assurance-level-boundaries.md`
- `adr/step-up-authentication-redesign.md`
- `docs/security/sign-withdrawal-and-membership.md`
- `docs/security/authentication-assurance-levels.md`
- `docs/security/session-reset-policy.md`
- `plans/active/step-up-authentication-rebuild.md`

## Non-Negotiable Boundaries

- `app` and `com` may share withdrawal business behavior, but keep controllers, routes, policies,
  helpers, translations, and audit event names surface-specific.
- `org` must not gain self-service destructive withdrawal without a new accepted ADR.
- Withdrawal requires AAL2 step-up scope `withdrawal`.
- Self-service withdrawal does not physically delete account rows.
- Retention/anonymization happens after the recovery window.

## Scope

In scope:

- App self-service withdrawal.
- Com self-service withdrawal.
- Shared withdrawal lifecycle model behavior for app/com.
- Surface-specific withdrawal cycle status reference tables.
- Withdrawal cycle events for configuration history.
- Step-up gate integration.
- Other-session revocation while preserving the allowed continuation session.
- Recovery window enforcement.
- Retention job pickup contract for termination/anonymization.
- Org informational/lifecycle request boundary documentation in code paths touched by this work.

Out of scope:

- Org self-service withdrawal.
- Direct-message implementation.
- Operator lifecycle execution internals, except ensuring org routes point there.
- Emergency hard delete UI.
- Sign-up/sign-in state machine implementation.

## State Carrier

Use DB-backed withdrawal cycle records.

Target records:

- `ClientWithdrawalCycle`
- `VisitorWithdrawalCycle`

Status reference tables:

- `ClientWithdrawalCycleStatus`
- `VisitorWithdrawalCycleStatus`

Event records:

- `ClientWithdrawalCycleEvent`
- `VisitorWithdrawalCycleEvent`

The actor row remains source of truth for access and retention:

- `withdrawal_started_at`;
- `deactivated_at` where still used by current code;
- `discarded_at`;
- `purged_at`;
- `terminated_at`.

## Statuses

Use the status model documented in `docs/security/sign-withdrawal-and-membership.md`:

| Status       |  ID | Meaning                                                 |
| ------------ | --: | ------------------------------------------------------- |
| `NOTHING`    |   0 | Placeholder / no meaningful procedure state             |
| `REQUESTED`  |  10 | Actor entered the withdrawal flow                       |
| `CLOSING`    |  20 | Actor explicitly confirmed withdrawal scheduling        |
| `DISCARDED`  |  30 | Logical deletion is active and `purged_at` is scheduled |
| `RECOVERED`  |  40 | Actor recovered before `purged_at`                      |
| `TERMINATED` | 100 | Actor has been anonymized and cannot recover            |
| `FAILED`     | 900 | Withdrawal procedure failed                             |

## Transitions

Allowed transitions:

```text
NOTHING -> REQUESTED
REQUESTED -> CLOSING
CLOSING -> DISCARDED
DISCARDED -> RECOVERED
DISCARDED -> TERMINATED
REQUESTED -> FAILED
CLOSING -> FAILED
DISCARDED -> FAILED
```

`REQUESTED` means the actor opened the withdrawal flow. `CLOSING` means the actor explicitly agreed
to schedule withdrawal.

`REQUESTED` must not set `withdrawal_started_at`, `deactivated_at`, `discarded_at`, or `purged_at`,
and must not revoke sessions. Actor lifecycle timestamps and other-session revocation begin only
when confirmation advances the procedure through `CLOSING` to `DISCARDED`.

## Access Contract

After `withdrawal_started_at`:

- RP/OIDC actions reject the actor.
- Normal sign/acme access is constrained to allowed withdrawal/status/recovery surfaces.
- Other sessions are revoked.
- The current MFA-verified session may continue only as the withdrawal-continuation session until a
  separate withdrawal ticket exists.

After `discarded_at`:

- normal access stops;
- recovery is unavailable for the first hour;
- recovery is available after one hour and before `purged_at`;
- retention jobs may terminate/anonymize only after `purged_at`.

## Implementation Phases

1. Inventory app/com withdrawal controllers, models, policies, routes, timestamps, and tests.
2. Add or verify cycle status reference tables and event records per surface.
3. Extract shared model concern behavior for transition validation and timestamp mutation.
4. Extract shared controller concern behavior only for HTTP flow that is identical across app/com.
5. Keep surface-specific controllers for route helpers, current actor helpers, translations, and
   audit names.
6. Require AAL2 step-up scope `withdrawal` at schedule/recover/early-termination entry points as
   applicable.
7. Revoke other sessions through the logout/session revoke boundary when withdrawal is scheduled.
8. Enforce allowed continuation-session behavior.
9. Add recovery window checks and retention job pickup contract.
10. Ensure org withdrawal routes, if present, remain informational or lifecycle-request entry points
    only.

## Test Expectations

- App and com have equivalent withdrawal behavior with separate surface tests.
- Opening withdrawal creates `REQUESTED` without scheduling account withdrawal.
- Confirming withdrawal transitions through `CLOSING` to `DISCARDED` and sets actor timestamps.
- Other sessions are revoked while allowed continuation session behavior is preserved.
- RP/OIDC actions reject closing, discarded, and terminated actors.
- Recovery before one hour is rejected.
- Recovery after one hour and before `purged_at` succeeds.
- Recovery after `purged_at` is rejected.
- Retention termination/anonymization runs only after `purged_at`.
- Org routes do not perform self-service destructive withdrawal.

## Documentation Follow-Up

After implementation, update:

- `docs/security/sign-withdrawal-and-membership.md`
- `docs/security/authentication-assurance-levels.md` only if credential transition rules change
- `adr/sign-withdrawal-and-membership-surface-policy.md` only if accepted product behavior changes
