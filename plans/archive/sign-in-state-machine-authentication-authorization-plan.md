# Sign-In State Machine Authentication And Authorization Plan

> **Updated by the current Identity Authority boundary:** `sign/id` owns sign-in identity entry,
> session-token issuance, and step-up evidence. `acme/www` owns Account, Selector, Dashboard, RP
> Authorization, and business authorization decisions that consume Sign results. Do not use older
> wording in this plan to restore the Acme aggregation model.

Status: implemented — archived 2026-06-12

## Purpose

Implement detailed sign-in authentication and authorization control around the existing DB-backed
sign-in cycles.

The goal is to make the sign-in sequence deterministic:

- the sign-in cycle state machine carries the current flow position;
- controllers use that state to route actors only through the documented sequence;
- Action Policy makes authorization decisions from already-resolved request authentication facts;
- sensitive post-sign-in actions, including withdrawal, remain gated by AAL2 step-up.

This plan does not replace the step-up authentication rebuild plan. It depends on it for scoped AAL2
verification.

## Source Material

- `docs/security/sign-in-sequence.md`
- `docs/security/authentication-assurance-levels.md`
- `docs/security/sign-withdrawal-and-membership.md`
- `docs/security/session-reset-policy.md`
- `docs/architecture/controller-lifecycle.md`
- `docs/architecture/controller-boundaries.md`
- `adr/actor-current-facade.md`
- `adr/authentication-assurance-level-boundaries.md`
- `adr/step-up-authentication-redesign.md`
- `adr/sign-withdrawal-and-membership-surface-policy.md`
- `plans/active/step-up-authentication-rebuild.md`
- `plans/active/withdrawal-state-machine-implementation-plan.md`

## Terminology

Current code uses `Actor.authn` for request-local authentication facts. This plan treats the
proposed `Action.authentication` wording as `Actor.authn` unless a later ADR introduces a separate
`Action` request object.

`Actor.authn` is an authentication result, not an authentication executor. Controllers and
authentication concerns resolve it before authorization. Policies read it and decide whether the
action is allowed.

## Non-Negotiable Boundaries

- Keep `app`, `com`, and `org` controllers, routes, helpers, translations, policies, and audit names
  surface-specific unless an existing shared abstraction already exists.
- Do not let a signed-in actor start a new sign-in sequence without first signing out.
- Do not skip the documented sign-in order: primary credential -> MFA when required -> session limit
  -> guardrail -> checkpoint -> selector -> session issuance -> welcome/return path or configuration
  page.
- Do not store request state in globals, class variables, or `Thread.current`.
- Do not put business logic in controllers.
- Do not let Action Policy perform authentication. Authentication must have run before policy
  checks.
- Withdrawal scheduling, recovery, and early termination entry points must require AAL2 step-up
  scope `withdrawal`.

## Existing State Carrier

Use the existing sign-in cycle models:

- `ClientSignInCycle`
- `VisitorSignInCycle`
- `OperatorSignInCycle`

Current target statuses:

| Status                     |  ID | Meaning                                                               |
| -------------------------- | --: | --------------------------------------------------------------------- |
| `PRIMARY_PENDING`          |  10 | Primary credential verification is in progress.                       |
| `MFA_PENDING`              |  20 | Sign-in MFA must complete before session-limit handling.              |
| `SESSION_LIMIT_PENDING`    |  30 | Session-limit handling must complete before guardrail/checkpoint.     |
| `GUARDRAIL_PENDING`        |  40 | Pre-activation guardrail checks must stop or clear.                   |
| `SESSION_ISSUANCE_PENDING` |  50 | Selector has committed and the active session can be issued.          |
| `CHECKPOINT_PENDING`       |  60 | Pre-activation checkpoint participants must stop or clear.            |
| `SELECTOR_PENDING`         |  65 | Activation candidate selection must complete before session issuance. |
| `DASHBOARD_PENDING`        |  70 | Legacy post-issuance dashboard participant state.                     |
| `RETURN_PENDING`           |  80 | Legacy post-issuance return-path consumption state.                   |
| `COMPLETED`                | 100 | The sign-in sequence has completed.                                   |
| `FAILED`                   | 900 | The sign-in sequence failed or was abandoned.                         |

Target transitions:

```text
PRIMARY_PENDING -> MFA_PENDING
PRIMARY_PENDING -> SESSION_LIMIT_PENDING
PRIMARY_PENDING -> GUARDRAIL_PENDING
MFA_PENDING -> SESSION_LIMIT_PENDING
MFA_PENDING -> GUARDRAIL_PENDING
SESSION_LIMIT_PENDING -> GUARDRAIL_PENDING
GUARDRAIL_PENDING -> CHECKPOINT_PENDING
CHECKPOINT_PENDING -> SELECTOR_PENDING
SELECTOR_PENDING -> SESSION_ISSUANCE_PENDING
SESSION_ISSUANCE_PENDING -> COMPLETED

Legacy compatibility only:
DASHBOARD_PENDING -> RETURN_PENDING
RETURN_PENDING -> COMPLETED

PRIMARY_PENDING -> FAILED
MFA_PENDING -> FAILED
SESSION_LIMIT_PENDING -> FAILED
GUARDRAIL_PENDING -> FAILED
SESSION_ISSUANCE_PENDING -> FAILED
CHECKPOINT_PENDING -> FAILED
SELECTOR_PENDING -> FAILED
DASHBOARD_PENDING -> FAILED
RETURN_PENDING -> FAILED
```

The implementation may allow no-op participant auto-advance when a participant stack is empty, but
that advance must still persist the explicit transition. For example, when guardrail has no blocking
items, the cycle moves from `GUARDRAIL_PENDING` to `CHECKPOINT_PENDING` rather than skipping the
state in memory only.

Target steps:

```text
primary
mfa
session_limit
guardrail
checkpoint
selector
session_issuance
completed
failed
```

`DASHBOARD_PENDING` and `RETURN_PENDING` remain legacy compatibility states for older post-issuance
cycles. New sign-in flows must not enter them; the active session is issued after selector and the
cycle completes from `SESSION_ISSUANCE_PENDING`.

`status_id` is the lifecycle authority. `step` is retained only as a readable, denormalized current
participant label for compatibility, diagnostics, and simple rendering. It must be synchronized from
status transitions and must not authorize a transition by itself.

## Authentication Contract

Before authorization:

1. The controller boundary verifies and decodes token/cycle/session inputs.
2. The current actor is resolved through the established controller lifecycle.
3. `Actor.authn` is populated with immutable request facts such as:
   - `login_public_id`;
   - `access_claims`;
   - `acr`;
   - `amr`.
4. Any sign-in cycle object needed by the action is loaded and validated against nonce, expiry,
   surface, actor, and token where applicable.
5. The action then calls Action Policy authorization.

Policies may read `Actor.authn`, current user, record, cycle state, token claims, and
surface-specific policy helpers. Policies must not send OTPs, verify WebAuthn challenges, issue
tokens, revoke sessions, mutate cycle state, or perform redirects.

## Authorization Contract

Use Action Policy as the authorization boundary.

Policy decisions should answer narrow questions:

- Is this action allowed for the current authenticated request facts?
- Is the current sign-in cycle in a status/step that permits this action?
- Does the cycle belong to the actor/session/token currently being handled?
- Is the actor allowed to proceed on this surface?
- Has the required AAL2 step-up already been satisfied for sensitive signed-in operations?

Action Policy should treat missing or null `Actor.authn` as unauthenticated unless the controller
action is explicitly open.

## Sequence Enforcement

Add a sign-in sequence guard that uses the state machine to decide:

- the expected participant for the current cycle state;
- whether the requested controller action is valid for that participant;
- whether the participant stack is empty, blocking, cleared, or renderable;
- the next participant or terminal destination.

Invalid direct access should not advance the state machine. The response should follow the
documented behavior:

- signed-in actor entering sign-in: reject with status and plain text;
- guardrail direct access without valid in-sequence state: reject with plain text;
- checkpoint/dashboard sequence access with valid state: render or advance according to stack;
- stale, expired, mismatched, or discarded cycle: reject and do not issue a session;
- unsafe return path: discard and continue to the default destination.

## Step-Up Dependency

Step-up implementation is already planned in `plans/active/step-up-authentication-rebuild.md`.

For withdrawal and other sensitive post-sign-in actions, this plan relies on that work:

- AAL2 is recent and scoped.
- `withdrawal` is one of the accepted step-up scopes.
- `last_step_up_at` and `last_step_up_scope` live on the token, not the actor.
- Fresh sign-in is AAL1 only and must not automatically satisfy AAL2.
- The withdrawal flow must call `require_step_up!(scope: "withdrawal")` or the surface-specific
  equivalent before scheduling withdrawal, recovery, or early irreversible termination entry points.

This means sign-in completion must not set or imply `last_step_up_scope = "withdrawal"`.

## Design Decisions For Implementation

These decisions intentionally favor a clean implementation because this sign-in state-machine work
has not yet been deployed.

1. Cycle state granularity

   Use explicit lifecycle statuses for each sequence participant. Guardrail, checkpoint, selector,
   and session issuance must stay separate lifecycle states. Dashboard and return states are legacy
   compatibility states only.

2. Cycle ownership before token issuance

   The cycle tables have `principal_id` and `token_id`, but early sign-in states do not have an
   issued token yet. Use this binding rule:
   - Before primary credential verification: cycle is anonymous and bound by public cycle ID plus
     nonce.
   - After primary verification and before MFA: cycle is bound to `principal_id`; `token_id` remains
     nil.
   - After restricted token issuance for session-limit handling: cycle is bound to both
     `principal_id` and restricted `token_id`.
   - After active token issuance: cycle is bound to both `principal_id` and active `token_id`.

3. Cycle lookup input

   Use public cycle ID plus nonce before token issuance. After token issuance, require the cycle to
   match the current token as well. Existing session keys may carry the cycle locator during the
   request flow, but the DB cycle row is the authority. The lookup must reject expired, discarded,
   wrong-surface, wrong-actor, and wrong-token cycles.

   In this plan, "cycle locator" means the request-local handle used to find the current DB-backed
   sign-in cycle. It is not the authority. The authority is always the cycle row plus its persisted
   state and bindings.

   Use this transport:
   - before token issuance, store `sign_in_cycle_public_id` and nonce in the Rails session;
   - do not expose the nonce in URLs;
   - avoid hidden form fields for the nonce unless a later endpoint cannot use the Rails session;
   - after token issuance, require `cycle.token_id` to match the current token in addition to any
     session-held locator.

4. Session-limit bridge

   Replace `SessionLimitGate` and `session[:pending_login_*_id]` as the authoritative sign-in
   sequence mechanism. During implementation, delete or narrow those helpers after the cycle-backed
   session-limit controller is in place. The restricted token remains; the extra session gate does
   not.

5. MFA sign-in versus AAL2 step-up naming

   Sign-in MFA is part of AAL1 session establishment. AAL2 step-up is a separate scoped
   verification. Decide the code naming and policy naming so `MFA_PENDING` in the sign-in cycle
   cannot be mistaken for satisfying `last_step_up_scope`.

6. Guardrail participant representation

   Add an explicit guardrail sequence participant. It may render plain text rather than a full page,
   but the cycle must enter `GUARDRAIL_PENDING` before stopping or advancing. If direct access is
   exposed by route, invalid access is rejected with plain text.

   Implement guardrail with the same participant-stack shape described in
   `docs/security/sign-in-sequence.md` and `docs/security/sign-up-sequence.md`:
   - a participant has an ordered `stack` of requirement items;
   - blocking items must all clear before the sequence advances;
   - an empty stack advances without display;
   - optional items may be visible but must not block;
   - adding a future guardrail requirement should register a new item evaluator, not add a new route
     or insert ad hoc controller branching.

   The initial implementation does not need to invent every future guardrail item. It must provide
   the stack/evaluator mechanism and wire the currently known hard-stop cases through it.

7. Checkpoint and dashboard split

   Treat checkpoint, dashboard, and return handling as separate sequence participants with separate
   statuses. Dashboard is not just a redirect helper; it is the participant that separates ordinary
   dashboard access from sequence dashboard access.

8. Redirect versus reject rules

   Decide response behavior for each invalid access class:
   - direct access to a future participant;
   - replaying an earlier participant;
   - stale/expired/discarded cycle;
   - signed-in actor entering sign-in;
   - restricted session entering ordinary authenticated pages;
   - JSON/API callers.

   Use simple, low-information responses. Do not reveal whether the failure was due to wrong state,
   expired cycle, replay, wrong actor, wrong token, or wrong surface.

   Baseline behavior:
   - invalid sign-in sequence access returns a generic plain-text rejection;
   - JSON/API callers receive a generic forbidden/error code without internal state details;
   - normal empty-participant auto-advance may redirect as part of the valid sequence;
   - signed-in actor entering sign-in is rejected and is not redirected to dashboard;
   - restricted sessions may be routed only to the session-limit participant; other access is
     rejected or redirected using the same generic behavior already used for restricted sessions.

   Be strict. Reject abnormal sequence access instead of trying to repair it for the user. Avoid
   response differences that reveal whether the actor, token, state, surface, expiry, or nonce was
   the failing condition.

9. Action Policy subject records

   Authorize the sign-in cycle record for lifecycle actions. If participant-specific context is
   needed, wrap the cycle in a small value object, but the cycle remains the policy's authoritative
   record.

   Use explicit policy method names for security-sensitive readability:

   ```ruby
   show_primary?
   verify_primary?
   show_mfa?
   verify_mfa?
   manage_session_limit?
   run_guardrail?
   issue_session?
   show_checkpoint?
   complete_checkpoint?
   show_dashboard?
   consume_return?
   fail?
   ```

   Avoid a generic `advance?` as the only authorization method. Shared helpers may exist inside the
   policy, but controller call sites should name the participant-level permission being checked.

10. `Actor.authn` contents

Decide whether `Actor::Authentication` needs additional fields for this work, such as current token
public ID, sign-in cycle public ID, surface, or restricted-session marker. If added, define them as
immutable request facts populated before policy checks.

11. Before-action order

Decide exact callback order in surface bases and endpoint controllers:

```text
rate limit / self-defense
-> token/cycle decode
-> Actor.authn population
-> current actor/resource resolution
-> sign-in sequence guard
-> Action Policy authorization
-> action
-> Actor cleanup
```

Existing lifecycle code may not already match this order everywhere.

12. Surface parity scope

Implement all three sign-in surfaces in the same feature branch because the schema/status change
touches all three ticket databases. Keep controllers and tests surface-specific.

13. Withdrawal gate placement

Withdrawal already uses `verification_scope == "withdrawal"` in app/com controllers, and tests
directly mark `last_step_up_scope`. Withdrawal must require AAL2 scope `withdrawal`. If the
DB-backed step-up rebuild is not yet complete when withdrawal work begins, use the current token
freshness fields as the temporary enforcement point, then migrate that enforcement to the DB-backed
step-up session implementation. Fresh sign-in must not satisfy withdrawal.

Withdrawal-related sign-in guardrail behavior should be expressed as guardrail stack items where
relevant. If there is no blocking withdrawal-related action for the actor, the guardrail stack is
empty and the sequence advances.

14. Policy failure presentation

Decide whether policy denials in sign-in sequence return plain text, redirect to the expected
participant, or use existing error responders. Security-sensitive abnormal requests should prefer
explicit rejection over convenience redirects.

Policy denials in the sign-in sequence should use the same low-information rejection behavior as
invalid sequence access. They should not redirect to the expected participant when doing so would
reveal current internal state.

15. Audit and event boundaries

Decide which sequence transitions emit audit/risk events, and which are only cycle state changes. In
particular, distinguish failed primary auth, MFA challenge failure, restricted-session issue,
session promotion, guardrail stop, and completed sign-in.

16. Session issuance idempotency

`SESSION_ISSUANCE_PENDING` is a single-use state. Token issuance must be strict:

- a cycle may issue at most one active or restricted token for the relevant sign-in completion
  boundary;
- token creation and `cycle.token_id` persistence must happen in one DB transaction where the
  involved records live on the same connection, or with an explicit compensating failure path where
  they do not;
- if `cycle.token_id` is already present, the controller must not issue a second token;
- replay at or after session issuance receives a generic rejection;
- successful token issuance immediately transitions the cycle out of `SESSION_ISSUANCE_PENDING`;
- tests must cover double-submit/reload behavior.

Recommended transaction boundary:

- inside DB transaction: token record creation, refresh token rotation/persistence, `cycle.token_id`
  persistence, and cycle transition;
- after the transaction commits: cookies, DBSC header, and response headers are written.

If any DB step fails, do not set cookies or headers.

17. Nonce rotation

Start simple:

- issue the nonce when the cycle is created;
- rotate the nonce when a credential boundary succeeds, such as primary credential success or MFA
  success;
- after token issuance, token binding becomes the primary continuation check.

18. Failed and rejected attempts

Use strict rejection, but avoid letting an attacker mutate a legitimate actor's cycle by guessing
handles.

- Invalid direct sequence access: generic reject.
- Wrong actor, wrong token, wrong surface, bad nonce, stale locator, or replay: generic reject
  without mutating the cycle.
- Ordinary input errors while the owner is on the correct participant: remain in the same state and
  render the participant's generic error.
- Attempt limit, explicit cancel, or owner-initiated terminal failure: transition to `FAILED`.
- Expired or discarded cycle: generic reject; cleanup may discard/lapse the cycle through normal
  retention code.

19. Schema rebuild

This sign-in state-machine work has not been deployed. Rebuild the affected status/reference state
cleanly instead of preserving compatibility migrations:

- remove the former coarse post-login status;
- add the target status IDs;
- update status reference `DEFAULTS`;
- update `STEPS`;
- update schema dumps;
- expect local rebuild through `bin/rails db:migrate:reset` or the equivalent multi-database reset
  path used by this app.

## Implementation Phases

### Phase 0: Inventory And Route/Action Matrix

**Depends on:** None

**Purpose:** Freeze the current moving parts before changing schema or controller flow.

**Work:**

1. Inventory sign-in entry controllers, challenge controllers, session-limit controllers, checkpoint
   controllers, dashboard/return helpers, social callback handoffs, and sign-up handoffs that call
   `establish_signed_in_session!`.
2. Build a route/action matrix for `app`, `com`, and `org`:
   - controller action;
   - expected target status;
   - policy method;
   - whether the action is pre-token or post-token;
   - whether the action can render, mutate, issue token, or only advance.
3. Record the matrix in this plan or in `notes/implementation/` if it is too large.

**Phase 0 note:** `notes/implementation/2026-05-20-sign-in-state-machine-phase-0-matrix.md`.

**Tests:** None required, but do not start Phase 1 until the matrix is clear enough to avoid
guessing during controller edits.

---

### Phase 1: Rebuild Sign-In Cycle State Model

**Depends on:** Phase 0

**Purpose:** Replace the former coarse post-login model with explicit DB-backed lifecycle states.

**Work:**

1. Update sign-in cycle status reference models for all three surfaces:
   - `ClientSignInCycleStatus`;
   - `VisitorSignInCycleStatus`;
   - `OperatorSignInCycleStatus`.
2. Remove the former coarse post-login status.
3. Add:
   - `GUARDRAIL_PENDING = 40`;
   - `SESSION_ISSUANCE_PENDING = 50`;
   - `CHECKPOINT_PENDING = 60`;
   - `SELECTOR_PENDING = 65`;
   - `DASHBOARD_PENDING = 70` legacy only;
   - `RETURN_PENDING = 80` legacy only;
   - `FAILED = 900`.
4. Update `ClientSignInCycle`, `VisitorSignInCycle`, and `OperatorSignInCycle`:
   - `STATUSES`;
   - `STATUS_NAMES`;
   - `STATUS_IDS`;
   - `STEPS`;
   - `TRANSITIONS`.
5. Update `Cycle::SignIn` with explicit transition helpers:
   - `advance_sign_in_to_guardrail!`;
   - `advance_sign_in_to_checkpoint!`;
   - `advance_sign_in_to_selector!`;
   - `advance_sign_in_to_session_issuance!`;
   - `advance_sign_in_to_dashboard!`;
   - `advance_sign_in_to_return!`;
   - `complete_sign_in!`;
   - `fail_sign_in!`.
6. Ensure `step` is synchronized from transition helper calls and is never the authorization
   authority.
7. Update migrations/schema dumps cleanly. This work is not deployed, so rebuild the affected status
   state rather than adding compatibility shims.

**Tests:**

- Model transition tests for all surfaces.
- Invalid transition tests.
- `FAILED` transition tests.
- Expiry/discard behavior remains intact.

---

### Phase 2: Cycle Locator, Nonce, And Generic Rejection

**Depends on:** Phase 1

**Purpose:** Establish a single way for controllers to find and validate the active sign-in cycle.

**Work:**

1. Add a shared sign-in cycle locator concern/service that stores pre-token continuation in Rails
   session:
   - cycle public ID;
   - nonce.
2. Do not put nonce in URLs.
3. Load the cycle from DB and validate:
   - current surface;
   - not expired;
   - not discarded;
   - nonce match before token issuance;
   - actor match after primary credential binds `principal_id`;
   - token match after `token_id` is present.
4. Rotate nonce after credential boundary success:
   - primary success;
   - MFA success.
5. Implement one low-information rejection path for invalid sequence access.
6. Ensure wrong actor, wrong token, wrong surface, bad nonce, stale locator, and replay reject
   without mutating the cycle.

**Tests:**

- Successful pre-token lookup.
- Bad nonce rejects generically and does not mutate the cycle.
- Expired/discarded rejects generically.
- Wrong actor/token/surface rejects generically.
- Nonce rotates at primary and MFA success boundaries.

---

### Phase 3: Action Policy For Sign-In Cycle Participants

**Depends on:** Phase 2

**Purpose:** Make sign-in authorization explicit and readable through Action Policy.

**Work:**

1. Add sign-in cycle policies for the three record classes, or one shared policy shape if existing
   Action Policy lookup can support it cleanly.
2. Implement explicit participant permissions:
   - `show_primary?`;
   - `verify_primary?`;
   - `show_mfa?`;
   - `verify_mfa?`;
   - `manage_session_limit?`;
   - `run_guardrail?`;
   - `issue_session?`;
   - `show_checkpoint?`;
   - `complete_checkpoint?`;
   - `show_dashboard?`;
   - `consume_return?`;
   - `fail?`.
3. Policies read already-resolved facts only:
   - `Actor.authn`;
   - current actor/token;
   - cycle status/bindings.
4. Policy denials use the same low-information rejection path as invalid sequence access.

**Tests:**

- Policy allows each action only in its matching state.
- Missing/null `Actor.authn` denies where authentication is required.
- Wrong actor/token binding denies.
- Denials do not reveal internal state in responses.

---

### Phase 4: Selector And Session Issuance Single-Use Boundary

**Depends on:** Phase 3

**Purpose:** Make selector commit and `SESSION_ISSUANCE_PENDING` strict and idempotent.

**Phase 4 note:** `notes/implementation/2026-05-20-sign-in-state-machine-phase-4-session-issuer.md`.

**Work:**

1. Refactor `establish_signed_in_session!` / `log_in` integration so credential success creates or
   advances a pending cycle, and token issuance happens only after selector commit reaches
   `SESSION_ISSUANCE_PENDING`.
2. Ensure a cycle can issue at most one token:
   - reject if `cycle.token_id` is already present;
   - do not create another token on reload/double-submit.
3. Put DB writes in the transaction boundary:
   - token record creation;
   - refresh token persistence/rotation;
   - `cycle.token_id` update;
   - transition out of `SESSION_ISSUANCE_PENDING`.
4. Write cookies, DBSC header, and response headers only after the DB transaction succeeds.
5. Preserve sign-in MFA as AAL1 session establishment. Do not set AAL2 `last_step_up_scope`.

**Tests:**

- Selector commit transitions the cycle to `SESSION_ISSUANCE_PENDING`.
- Successful issuance transitions the cycle to `COMPLETED` and sets `token_id`.
- Double-submit/reload does not issue a second token.
- Failed DB transaction does not set cookies/headers.
- Fresh sign-in does not satisfy withdrawal step-up.

---

### Phase 5: Cycle-Backed Session Limit

**Depends on:** Phase 4

**Purpose:** Replace `SessionLimitGate` / `pending_login_*_id` as the authoritative session-limit
sequence state.

**Phase 5 note:** `notes/implementation/2026-05-20-sign-in-state-machine-phase-5-session-limit.md`.

**Work:**

1. Move session-limit flow to `SESSION_LIMIT_PENDING`.
2. Keep restricted tokens, but bind the restricted token to the sign-in cycle via `cycle.token_id`.
3. Remove or narrow `SessionLimitGate` so it is no longer authoritative.
4. Ensure restricted sessions can access only the session-limit participant until promoted or
   cancelled.
5. On successful promotion, advance to `GUARDRAIL_PENDING`.
6. On cancel, transition to `FAILED` and revoke the restricted token.

**Tests:**

- Session-limit pending actor cannot skip to guardrail/checkpoint/dashboard.
- Restricted token is bound to the cycle.
- Promotion advances the cycle.
- Cancel transitions to `FAILED`.
- Existing hard-limit rejection uses generic low-information behavior.

---

### Phase 6: Guardrail Participant Stack

**Depends on:** Phase 5

**Purpose:** Implement guardrail as a sequence participant with stack/evaluator behavior.

**Phase 6 note:** `notes/implementation/2026-05-20-sign-in-state-machine-phase-6-guardrail.md`.

**Work:**

1. Add a guardrail participant/evaluator abstraction:
   - ordered stack;
   - blocking items;
   - cleared state;
   - empty-stack auto-advance.
2. Wire known hard-stop cases through guardrail items instead of controller branches.
3. If the stack is empty, persist transition to `CHECKPOINT_PENDING`.
4. If any blocking item remains, render generic plain text and do not issue a session.
5. Keep withdrawal-related sign-in stops as guardrail items when relevant.

**Tests:**

- Empty guardrail stack advances.
- Blocking guardrail stack stops with generic plain text.
- Guardrail stop does not issue a token.
- Adding multiple blocking items requires all to clear before advance.

---

### Phase 7: Checkpoint And Selector Participants

**Depends on:** Phase 6

**Purpose:** Make pre-activation checkpoint and selector routing deterministic before session
issuance.

**Phase 7 note:** `notes/implementation/2026-05-20-sign-in-state-machine-phase-7-post-issuance.md`.

**Work:**

1. Move checkpoint handling to `CHECKPOINT_PENDING`.
2. Move activation candidate selection to `SELECTOR_PENDING`.
3. Auto-commit selector only when there is exactly one valid activation candidate.
4. Persist selector completion before active token/session issuance.
5. Keep ordinary dashboard access independent from sequence continuation.
6. Store return intent on the cycle and validate the final destination only after activation.
7. Discard unsafe return paths.

**Tests:**

- Empty checkpoint stack advances.
- Blocking checkpoint remains at checkpoint until cleared.
- Empty selector stack is impossible; selector must have one auto-commit candidate or render/reject.
- Selector completion is first-commit-wins; replay with the same selection is idempotent and a
  different selection is rejected.
- Ordinary dashboard access does not consume `rt`.
- Safe return path is consumed only after activation.
- Unsafe return path is discarded.

---

### Phase 8: Surface Controller Wiring

**Depends on:** Phases 2-7

**Purpose:** Wire all sign-in routes to the cycle/policy/participant implementation without mixing
surfaces.

**Phase 8 note:**
`notes/implementation/2026-05-20-sign-in-state-machine-phase-8-controller-wiring.md`.

**Phase 8 follow-up:** credential entry, MFA handoff, social login, sign-up/session-establishment
handoff, and session-limit promotion now create or continue DB-backed sign-in cycle locators through
`Authentication::Base`.

**Work:**

1. Update `app`, `com`, and `org` sign-in controllers to use the cycle locator and policy checks.
2. Keep route helpers, translations, current actor helpers, and audit names surface-specific.
3. Update sign-up and social callback handoffs that enter sign-in session issuance.
4. Ensure signed-in actor re-entry to sign-in is rejected, not redirected.
5. Ensure controller before-action order follows the lifecycle contract as closely as the current
   bases permit.

**Tests:**

- Surface-specific integration coverage for app/com/org sign-in.
- Signed-in actor re-entry rejection.
- Wrong-surface cycle rejection.
- Social/sign-up handoff coverage where they enter sign-in issuance.

---

### Phase 9: Withdrawal AAL2 Verification Check

**Depends on:** Phase 8 and the current step-up enforcement available in the branch

**Purpose:** Verify that the sign-in work does not weaken withdrawal.

**Phase 9 note:**
`notes/implementation/2026-05-20-sign-in-state-machine-phase-9-withdrawal-aal2.md`.

**Work:**

1. Ensure fresh sign-in remains AAL1 and does not satisfy AAL2.
2. Ensure app/com withdrawal scheduling, recovery, and early termination entry points require scope
   `withdrawal`.
3. Use current token freshness fields if the DB-backed step-up rebuild is not complete yet.
4. Preserve the migration path to DB-backed step-up sessions from
   `plans/active/step-up-authentication-rebuild.md`.

**Tests:**

- Fresh sign-in cannot schedule withdrawal.
- Valid recent `withdrawal` step-up can schedule/recover where allowed.
- Wrong step-up scope is rejected.
- Expired step-up freshness is rejected.

---

### Phase 10: Documentation And Cleanup

**Depends on:** Phase 9

**Purpose:** Remove obsolete flow code and align stable docs with implemented behavior.

**Phase 10 note:** `notes/implementation/2026-05-20-sign-in-state-machine-phase-10-docs-cleanup.md`.

**Work:**

1. Confirm stable code and docs no longer describe the old coarse post-login state as current.
2. Remove or narrow obsolete `SessionLimitGate` and `pending_login_*_id` paths where DB-backed cycle
   locators are authoritative.
3. Update stable docs only after behavior is implemented.
4. Add implementation notes for any deliberate deviation from this plan.
5. Run narrow tests first, then broader sign-in/security suites.

**Tests:**

- Relevant model tests.
- Surface-specific sign-in integration tests.
- Session-limit tests.
- Withdrawal step-up tests.
- Broader `bin/rails test` when feasible.

## Test Expectations

- Each surface has separate sign-in sequence tests.
- Signed-in actors cannot start a new sign-in sequence.
- Primary credential success advances only to the next allowed state.
- MFA-required actors cannot skip MFA.
- Actors that do not require MFA do not visit the MFA participant.
- Session-limit pending actors cannot skip session management.
- Guardrail renders plain text and does not issue or advance a normal session.
- Checkpoint advances when its stack is empty or cleared.
- Dashboard consumes safe return paths only when reached as the sequence participant.
- Ordinary dashboard access does not consume `rt`.
- Unsafe return paths are discarded.
- Expired, discarded, mismatched, or wrong-surface cycles are rejected.
- Action Policy denies actions when `Actor.authn` is missing, stale, or mismatched.
- Withdrawal scheduling/recovery/early termination requires AAL2 step-up scope `withdrawal`.
- Fresh sign-in alone does not satisfy withdrawal step-up.

## Documentation Follow-Up

After implementation, update:

- `docs/security/sign-in-sequence.md`
- `docs/security/authentication-assurance-levels.md` only if AAL semantics change
- `docs/security/sign-withdrawal-and-membership.md` if withdrawal entry behavior changes
- relevant ADRs only if accepted behavior changes
