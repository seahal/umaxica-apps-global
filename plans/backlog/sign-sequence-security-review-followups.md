# Sign Sequence Security Review Follow-ups

Status: backlog

## Purpose

Record security follow-ups found while comparing the current sign implementation against the
documented sign-in and sign-up sequence model.

This file is a planning record only. It does not change the accepted sequence behavior in `docs/` or
`adr/`.

## Reference Decisions

- `docs/security/sign-in-sequence.md`
- `docs/security/sign-up-sequence.md`
- `adr/sign-up-authentication-handoff-and-social-rt.md`
- `plans/backlog/sign-in-failure-handling-plan.md`
- `plans/backlog/sign-up-failure-recovery-plan.md`

## Security Findings To Preserve

### Sign-up Completion Ignores Sign-in Result

Several sign-up completion paths call the sign-in/session issuance boundary but do not branch on its
result. A failure such as `login_forbidden`, hard session-limit rejection, DPoP validation failure,
or future guardrail block can be followed by welcome-bulletin creation and normal post-auth routing.

Observed call-site classes:

- app email sign-up completion;
- app telephone sign-up completion;
- app telephone passkey completion;
- com email sign-up completion;
- com telephone sign-up completion.

Required direction:

- every sign-up finalization path must receive and classify the sign-in boundary result;
- only successful session issuance may continue to checkpoint, dashboard, or `rt`;
- sign-in/session issuance failure after durable sign-up completion belongs to sign-in failure
  handling and must not delete completed account data.

### Guardrail Is Not Yet A Real Boundary

The docs define guardrail as the stop point before normal session issuance. The implementation still
has most stop decisions inside existing login/session-limit result handling, and the sign-in
sequence routing currently starts at checkpoint/dashboard.

Required direction:

- introduce a guardrail participant for sign-in and sign-up;
- represent cooldown, ban/suspension, and hard session-limit stops as guardrail items where
  appropriate;
- return plain text for blocking guardrail items;
- reject direct guardrail access without valid sequence state.

### Sequence-only Routes Need State Checks

The documented model treats guardrail, checkpoint, and dashboard as sequence participants rather
than ordinary pages. Direct access without valid sequence state must not advance a return path or
dashboard handoff.

Required direction:

- define the valid sequence state for `/sign/{in,up}/guardrail`;
- define the valid sequence state for `/sign/{in,up}/checkpoint`;
- define whether `/dashboard` is a public authenticated destination, a sequence participant, or
  both, and separate those modes if needed;
- reject invalid direct participant access with a status code and plain text rather than redirect.

### Social Login Failure Should Use The Same Stop Semantics

Social sign-in/sign-up already treats Google and Apple as AAL1 methods only, not AAL2 step-up
methods. Its failure handling should still align with the common sign-in boundary.

Required direction:

- keep `login` and `link` as the only social intents;
- continue to decide sign-in versus sign-up from provider identity state, not request params;
- map `login_forbidden`, session-limit hard rejection, and future guardrail blocks to the common
  stop behavior instead of ad hoc redirects.

## Docs-only Security Review

The current docs establish the right high-level security properties:

- signed-in actors must not start sign-in or sign-up again;
- abnormal re-entry returns a status code and plain text, not redirect or forced sign-out;
- guardrail blocks before normal session issuance;
- checkpoint is for allowed flows that still need setup or notices;
- guardrail, checkpoint, and dashboard are extensible participants with all-pass requirement items;
- `rt` is preserved only when it is a safe same-origin path and never skips participants;
- sign-up finalization and sign-in failure are separate failure domains.

Docs that should be tightened before implementation:

- sign-in checkpoint should explicitly say that "no checkpoint content, advance" applies only when
  the request has valid sequence state;
- dashboard should explicitly distinguish ordinary authenticated dashboard access from dashboard as
  a post-auth sequence participant;
- guardrail/session-limit wording should clarify that a restricted session, if issued, is a
  deliberate session-limit outcome and not a bypass of guardrail;
- the participant contract should name the state carrier, such as a future sequence ticket/session
  record, before routes are implemented.

## Implementation Requirements To Carry Forward

When this plan becomes active, implementation should include:

1. A common sign-in boundary result object used by email, telephone, passkey, secret, TOTP, and
   social paths.
2. A common sign-up finalization wrapper that calls sign-up finalization first, then the sign-in
   boundary, and branches on every returned status.
3. Route/state checks for guardrail, checkpoint, and dashboard participant access.
4. Plain-text non-redirect responses for abnormal re-entry and guardrail stops.
5. Tests for all affected app/com/org sign-in entry points and app/com sign-up completion paths.
6. Regression tests proving sign-in failure after durable sign-up completion does not delete actor,
   account, contact, credential, or social identity rows.

## Non-goals

- Do not implement sign-up cleanup in this plan; use the separate sign-up failure recovery plan.
- Do not delete durable account data to recover from sign-in/session issuance failure.
- Do not make `intent`, `entry`, or `rt` params authoritative for actor lifecycle decisions.
