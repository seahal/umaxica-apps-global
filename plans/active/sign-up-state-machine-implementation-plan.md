# Sign Up State Machine Implementation Plan

Status: active planning

## Purpose

Implement sign-up as explicit state-machine driven flows for `app` and `com`.

`org` operator acquisition and lifecycle work is intentionally split out of this implementation
plan. This plan may still define shared interfaces that future `org` lifecycle work can reuse, but
it must not implement org public self-service sign-up or org operator mutation behavior.

This plan supersedes the narrower backlog proposal in
`plans/backlog/app-sign-up-sequence-ticket-plan.md` for future implementation direction. That
backlog file remains useful as historical context for early pending-principal cleanup, but it is too
app-only and too narrow for the accepted ADR.

## Source Material

- `adr/sign-up-authentication-handoff-and-social-rt.md`
- `adr/sign-com-no-social-login.md`
- `adr/authentication-assurance-level-boundaries.md`
- `docs/security/sign-up-sequence.md`
- `docs/security/sign-in-sequence.md`
- `plans/backlog/org-operator-acquisition-lifecycle-implementation-plan.md`
- `plans/backlog/sign-up-failure-recovery-plan.md`
- `plans/backlog/sign-in-failure-handling-plan.md`
- `plans/backlog/sign-sequence-security-review-followups.md`

## Non-Negotiable Boundaries

- `app` supports email, telephone, Google social, and Apple social sign-up.
- `com` supports email and telephone sign-up only. It must not gain social sign-up.
- `org` is out of scope for this implementation plan. Do not add org public self-service sign-up,
  operator creation, operator mutation, or org session issuance here.
- Sign-up checkpoint is separate from sign-in checkpoint.
- Sign-up finalization and sign-in/session issuance are separate failure domains.
- Durable sign-up completion must not be undone because later sign-in/session issuance failed.

## Scope

In scope:

- App email sign-up.
- App telephone sign-up.
- App Google social sign-up.
- App Apple social sign-up.
- Com email sign-up.
- Com telephone sign-up.
- `/sign/up/guardrail`.
- `/sign/up/checkpoint`.
- Birthdate checkpoint requirement.
- Telephone passkey and passcode checkpoint requirements.
- Social `rt` preservation through server-side auth session.
- Sign-up finalization to sign-in boundary handoff.
- Pending artifact ownership and cleanup rules for unfinished sign-up cycles.

Out of scope:

- General sign-in state machine internals beyond calling its boundary.
- Logout.
- Withdrawal cycle implementation.
- Org candidate inquiry route behavior.
- Org operator lifecycle request behavior.
- Org self-service operator registration.
- Adding social auth to `com`.

## PI, Contact Identifier, And AAL1 Entry Rules

App/com sign-up is allowed to create a durable actor only through accepted personal identifier,
contact identifier, and AAL1-capable method combinations.

Definitions for this plan:

- Personal identifier: data used to locate or disambiguate an account candidate during registration
  or login.
- Contact identifier: a personal identifier that can also receive notification or recovery messages.
- AAL1 method: a verifier or provider assertion that can establish the baseline signed-in boundary
  after sign-up finalization hands off to sign-in.

Email address:

- personal identifier: yes;
- contact identifier: yes;
- AAL1 method by itself: no;
- AAL1-capable when email OTP verification succeeds on `app` or `com`.

Telephone number:

- personal identifier: yes;
- contact identifier: yes;
- AAL1 method by itself: no;
- AAL1-capable only through a separate verifier such as passkey or passcode after telephone
  ownership is verified.

Passkey:

- personal identifier: no;
- contact identifier: no;
- AAL1 method: yes on `app` and `com` after successful registration and later assertion.

Passcode:

- personal identifier: no;
- contact identifier: no;
- AAL1 method: yes on `app` and `com` when active and sign-in capable.

Google social identity:

- personal identifier: yes;
- contact identifier: no;
- AAL1 method: yes on `app`;
- not available on `com`.

Apple social identity:

- personal identifier: yes;
- contact identifier: no;
- AAL1 method: yes on `app`;
- not available on `com`.

Accepted app sign-up entry methods:

| entry method | PI/contact submitted     | AAL1-capable method before finalization | required checkpoint          |
| ------------ | ------------------------ | --------------------------------------- | ---------------------------- |
| email        | email address            | email OTP                               | birthdate                    |
| telephone    | telephone number         | passkey and passcode                    | birthdate, passkey, passcode |
| google       | Google provider identity | Google provider assertion               | birthdate                    |
| apple        | Apple provider identity  | Apple provider assertion                | birthdate                    |

Accepted com sign-up entry methods:

| entry method | PI/contact submitted | AAL1-capable method before finalization | required checkpoint          |
| ------------ | -------------------- | --------------------------------------- | ---------------------------- |
| email        | email address        | email OTP                               | birthdate                    |
| telephone    | telephone number     | passkey and passcode                    | birthdate, passkey, passcode |

Rules:

- Telephone OTP verifies telephone ownership only. It must not be treated as satisfying AAL1.
- Telephone sign-up cannot finalize until the pending actor has an active passkey and an active
  sign-in-capable passcode.
- Social sign-up is `app` only. `com` must not expose social sign-up routes, callbacks, provider
  configuration, policy paths, or state-machine entry methods.
- Existing social provider identity means sign-in, not sign-up. Request params such as `entry` or
  `intent` must not decide account ownership.
- Every durable app/com actor created by sign-up must have at least one usable contact identifier
  and one AAL1-capable method by the time finalization completes.

## State Carrier

Use per-surface DB-backed sign-up cycle tickets as the target source of truth. Compatibility session
keys may remain temporarily while each controller is migrated.

Target records:

- app: `ClientSignUpCycle < AppTicketRecord`.
- com: `VisitorSignUpCycle < ComTicketRecord`.

These existing cycle records are the sign-up ticket carrier for this plan. They belong in the ticket
database because they are temporary sign flow state, not durable actor profile state. Pending
actors, contacts, credentials, and social identities stay in their existing surface principal
databases and are referenced from the ticket by id/public id as needed.

The ticket must record:

- surface;
- entry method;
- pending actor id when created;
- pending contact id or social identity id when created;
- completed requirement items;
- current step;
- safe return path;
- expiry time;
- terminal state;
- cleanup ownership marker.

### Ticket Columns

Use the same conceptual columns for app and com, with surface-specific foreign key names where
needed.

Common columns:

| column                      | type       | requirement                                                                       |
| --------------------------- | ---------- | --------------------------------------------------------------------------------- |
| `public_id`                 | string     | non-null, unique, URL-safe external id                                            |
| `entry_method`              | string     | non-null; app: `email`, `telephone`, `google`, `apple`; com: `email`, `telephone` |
| `step`                      | string     | non-null current sequence step                                                    |
| `status`                    | string     | non-null lifecycle status                                                         |
| `pending_actor_id`          | bigint     | nullable until a pending actor exists                                             |
| `pending_contact_type`      | string     | nullable; `email`, `telephone`, or `social_identity`                              |
| `pending_contact_id`        | bigint     | nullable until a pending contact/identity exists                                  |
| `social_provider`           | string     | nullable; app only, `google` or `apple`                                           |
| `completed_requirements`    | json/jsonb | non-null default empty object                                                     |
| `return_to`                 | string     | nullable safe internal path only                                                  |
| `cleanup_token`             | string     | non-null random ownership marker for cleanup                                      |
| `expires_at`                | datetime   | non-null                                                                          |
| `completed_at`              | datetime   | nullable                                                                          |
| `failed_at`                 | datetime   | nullable                                                                          |
| `cancelled_at`              | datetime   | nullable                                                                          |
| `discarded_at`              | datetime   | non-null retainable sentinel                                                      |
| `created_at` / `updated_at` | datetime   | non-null                                                                          |

Surface-specific aliases may be used if the codebase requires explicit actor names, for example
`principal_id` instead of `pending_actor_id`. If aliases are used, the model API should still expose
the shared protocol names `pending_actor`, `pending_contact`, and `entry_method`.

### Status And Step Values

`status` tracks the ticket lifecycle:

```text
PENDING
COMPLETED
FAILED
EXPIRED
CANCELLED
```

`step` tracks the current flow position:

```text
STARTED
CONTACT_PENDING
CONTACT_VERIFIED
SOCIAL_CALLBACK_PENDING
GUARDRAIL_PENDING
CHECKPOINT_PENDING
FINALIZING
FINALIZED
SIGN_IN_HANDOFF_PENDING
COMPLETED
```

`status` and `step` are separate. For example, a ticket can have `status = PENDING` and
`step = CHECKPOINT_PENDING`.

### Requirement State

`completed_requirements` stores compact booleans and timestamps for checkpoint-owned requirements.
It must not store raw secrets, OTP values, WebAuthn challenge bytes, passcodes, tokens, cookies, or
full request params.

Expected keys:

```json
{
  "birthdate": { "cleared": true, "cleared_at": "..." },
  "passkey": { "cleared": true, "cleared_at": "..." },
  "passcode": { "cleared": true, "cleared_at": "..." }
}
```

Email and social sign-up require only `birthdate`. Telephone sign-up requires `birthdate`,
`passkey`, and `passcode`.

### Indexes And Constraints

Add:

- unique index on `public_id`;
- index on `status, expires_at`;
- index on `pending_actor_id`;
- index on `cleanup_token`;
- model validation for accepted `entry_method` per surface;
- model validation for accepted `status` and `step`;
- model validation that `return_to`, when present, is a safe internal path;
- model validation that `social_provider` is blank on com.

Do not add cross-database foreign keys from ticket DB to principal DB. Validate ownership in model
and service code by loading the surface-local records explicitly.

### Expiry And Cleanup Ownership

Ticket expiry is the boundary for retry and cleanup. Cleanup may touch only artifacts that match all
of:

- belong to the same surface;
- are referenced by the ticket or by an explicit cycle ownership marker;
- are still pending/incomplete;
- match the ticket's cleanup ownership marker where such a marker is available.

Cleanup must not query broadly by email address, telephone number, or social UID alone.

## Shared Interface Contract

Although this plan implements only `app` and `com`, the reusable interfaces should avoid baking in
client-only or visitor-only assumptions. Future `org` lifecycle work may reuse these interfaces for
controlled operator invitation acceptance or operator lifecycle request progression.

Shared interfaces may include:

- a sign-up cycle ticket protocol;
- state-machine transition/result objects;
- participant evaluators for guardrail and checkpoint;
- checkpoint requirement evaluators;
- ownership and cleanup contracts;
- policy context objects;
- finalization result objects;
- Chronicle event payload builders.

Shared interfaces must remain surface-aware. They should accept explicit surface, actor class,
ticket class, and requirement registry inputs rather than discovering or mixing app/com/org state
implicitly.

This plan must finish the shared interface definitions that app/com need. It must not add unused org
routes, controllers, database tables, policies, or lifecycle behavior just to prove future reuse.

## Sequence States

Expected high-level states:

```text
STARTED
CONTACT_PENDING
CONTACT_VERIFIED
SOCIAL_CALLBACK_PENDING
GUARDRAIL_PENDING
CHECKPOINT_PENDING
FINALIZING
FINALIZED
SIGN_IN_HANDOFF_PENDING
COMPLETED
FAILED
EXPIRED
CANCELLED
```

Telephone sign-up must not treat telephone OTP success as durable account completion.

## State Machine API

Expose a surface-aware state machine service with a shared protocol and surface-specific
configuration.

Suggested entry point:

```ruby
SignUp::StateMachine.call(ticket:, event:, actor_context:, payload: {})
```

The state machine must be deterministic from:

- the current ticket;
- the requested event;
- explicit actor/authentication context;
- explicit payload values that have already been normalized by the controller/form object.

It must not read raw params, cookies, session keys, or controller instance variables directly.

### Events

Supported events:

| event                      | allowed from                              | effect                                                       |
| -------------------------- | ----------------------------------------- | ------------------------------------------------------------ |
| `start`                    | no ticket or terminal retry               | create/resume ticket at `STARTED`                            |
| `submit_contact`           | `STARTED`                                 | create/resume pending contact and move to `CONTACT_PENDING`  |
| `verify_contact`           | `CONTACT_PENDING`                         | verify OTP/contact ownership and move to `CONTACT_VERIFIED`  |
| `start_social_callback`    | `STARTED`                                 | mark app social flow as `SOCIAL_CALLBACK_PENDING`            |
| `complete_social_callback` | `SOCIAL_CALLBACK_PENDING`                 | classify provider identity as sign-up or sign-in handoff     |
| `enter_guardrail`          | `CONTACT_VERIFIED`                        | evaluate sign-up guardrail participant                       |
| `enter_checkpoint`         | `GUARDRAIL_PENDING` or `CONTACT_VERIFIED` | move to `CHECKPOINT_PENDING` when guardrail is clear         |
| `clear_requirement`        | `CHECKPOINT_PENDING`                      | mark one checkpoint requirement as clear                     |
| `finalize`                 | `CHECKPOINT_PENDING`                      | run finalization when all requirements are clear             |
| `handoff_to_sign_in`       | `FINALIZED`                               | call the sign-in boundary and store the handoff result class |
| `complete`                 | `SIGN_IN_HANDOFF_PENDING`                 | mark ticket `COMPLETED` after accepted sign-in handoff       |
| `fail`                     | any non-terminal step                     | mark ticket `FAILED`                                         |
| `expire`                   | any non-terminal step                     | mark ticket `EXPIRED`                                        |
| `cancel`                   | any non-terminal step                     | mark ticket `CANCELLED`                                      |

The implementation may split events into command classes if that fits local style, but external
callers should see one consistent result contract.

### Transition Rules

Common rules:

- A terminal ticket cannot transition except through an explicit new `start` that creates a new
  ticket.
- A ticket cannot move backward to contact submission after contact verification.
- A ticket cannot enter checkpoint until contact or social identity verification has succeeded.
- A ticket cannot finalize until all required checkpoint requirements for its entry method are
  clear.
- A telephone ticket cannot finalize unless passkey and passcode requirements are clear.
- A social callback for an existing provider identity exits sign-up and returns a sign-in handoff
  classification instead of creating sign-up artifacts.
- A `com` ticket cannot use social events or social entry methods.
- Expired tickets reject mutation before any side effect is attempted.

### Result Object

All events return a result object:

```ruby
SignUp::Result(
  status:,
  ticket:,
  step:,
  response:,
  errors:,
  next_event:,
  sign_in_handoff:,
  cleanup_required:,
  audit_events:
)
```

`status` values:

```text
ok
advanced
blocked
invalid_transition
unauthorized
expired
failed
completed
sign_in_handoff_accepted
sign_in_handoff_stopped
sign_in_handoff_failed
```

Field meanings:

- `ticket`: the current ticket after the transition attempt.
- `step`: the current step after the transition attempt.
- `response`: symbolic response instruction such as `render`, `redirect`, or `plain_text`.
- `errors`: user-safe errors or validation messages.
- `next_event`: optional expected next event for controller routing.
- `sign_in_handoff`: normalized boundary result class only; sign-up code must not inspect sign-in
  internals.
- `cleanup_required`: whether sign-up recovery cleanup should run for pre-finalization failure.
- `audit_events`: symbolic Chronicle events to emit after commit.

Controllers map the result to HTTP behavior. They must not infer new state by re-reading params or
recomputing route order.

### Service Boundaries

The state machine may call explicit services for side effects:

- pending actor/contact creation;
- OTP verification result recording;
- checkpoint requirement persistence;
- passkey/passcode setup completion;
- finalization transaction;
- sign-in boundary handoff;
- cleanup scheduling.

Each side-effect service must return a typed result. State-machine transitions should commit ticket
state and side effects in transactions where practical, but must not wrap external provider
callbacks or sign-in boundary internals in a transaction it does not own.

## Controller Shape

Keep existing app/com route intent where practical, but move progression decisions behind the
ticket, policy, and state-machine contracts.

### Shared Controller Concerns

Introduce a shared concern only for protocol-level behavior that is identical across app and com.
Suggested concern:

- `Sign::Up::SequenceControllerSupport`

Responsibilities:

- load ticket by `public_id` or sequence-bound session key;
- reject missing/expired/terminal ticket for sequence-only actions;
- build policy context;
- call Action Policy;
- call `SignUp::StateMachine`;
- map `SignUp::Result` to HTTP response;
- keep compatibility with existing session keys during migration.

The concern must not know concrete app/com model names through constants hidden in the concern.
Surface controllers pass configuration explicitly, for example actor class, ticket class,
requirement registry, and route helpers.

### App Email Controllers

Existing route intent:

- `GET /sign/up/email/new`
- `POST /sign/up/email`
- `GET /sign/up/email/edit`
- `PATCH /sign/up/email`

Target event mapping:

| action   | state-machine event      | notes                                                           |
| -------- | ------------------------ | --------------------------------------------------------------- |
| `new`    | `start`                  | create/resume app email ticket; reject signed-in actor          |
| `create` | `submit_contact`         | validate Turnstile and email form first                         |
| `edit`   | none or read-only `show` | require ticket at `CONTACT_PENDING`                             |
| `update` | `verify_contact`         | OTP success moves toward guardrail/checkpoint, not finalization |

After `verify_contact`, controller routes to sign-up guardrail/checkpoint according to the result.
It must not call account finalization directly.

### App Telephone Controllers

Existing route intent:

- `GET /sign/up/telephone/new`
- `POST /sign/up/telephone`
- `GET /sign/up/telephone/edit`
- `PATCH /sign/up/telephone`
- existing passkey registration route, temporarily retained as checkpoint-owned setup

Target event mapping:

| action                   | state-machine event      | notes                                                      |
| ------------------------ | ------------------------ | ---------------------------------------------------------- |
| `new`                    | `start`                  | create/resume app telephone ticket; reject signed-in actor |
| `create`                 | `submit_contact`         | validate Turnstile and telephone form first                |
| `edit`                   | none or read-only `show` | require ticket at `CONTACT_PENDING`                        |
| `update`                 | `verify_contact`         | OTP verifies telephone ownership only                      |
| passkey setup completion | `clear_requirement`      | clears `passkey` requirement                               |
| passcode confirmation    | `clear_requirement`      | clears `passcode` requirement                              |

Telephone OTP success must move to guardrail/checkpoint. It must not finalize the actor and must not
issue a session.

### App Social Controllers

Existing route intent:

- app sign-up page starts Google or Apple through existing social auth infrastructure;
- Google callback: `GET /auth/google_app/callback`;
- Apple callback: `POST /auth/apple/callback`.

Target event mapping:

| action            | state-machine event                  | notes                                                                    |
| ----------------- | ------------------------------------ | ------------------------------------------------------------------------ |
| social continue   | `start` then `start_social_callback` | store provider, entry method, callback state, and safe `rt` server-side  |
| provider callback | `complete_social_callback`           | classify existing identity as sign-in handoff or new identity as sign-up |

For a new app social identity, callback completion creates/links pending artifacts and routes to
sign-up guardrail/checkpoint. For an existing identity, the controller exits sign-up and hands to
the sign-in boundary according to provider identity state.

### Com Email Controllers

Use the same event mapping as app email with `VisitorSignUpCycle`.

Com email must require birthdate checkpoint before finalization. It must not gain social entry
methods.

### Com Telephone Controllers

Use the same event mapping as app telephone with `VisitorSignUpCycle`.

Com telephone must be rebuilt to use guardrail/checkpoint and the common post-finalization handoff.
It must not redirect directly to `root_path` after telephone OTP.

### Guardrail And Checkpoint Controllers

Add per-surface participant controllers:

- app: `/sign/up/guardrail`, `/sign/up/checkpoint`
- com: `/sign/up/guardrail`, `/sign/up/checkpoint`

Target event mapping:

| action                | state-machine event                   | notes                                                                     |
| --------------------- | ------------------------------------- | ------------------------------------------------------------------------- |
| guardrail `show`      | `enter_guardrail`                     | returns plain text when blocked; advances when clear                      |
| checkpoint `show`     | `enter_checkpoint`                    | renders required checkpoint items                                         |
| checkpoint `update`   | `clear_requirement`                   | clears birthdate/passkey/passcode item                                    |
| checkpoint completion | `finalize`, then `handoff_to_sign_in` | finalization and sign-in boundary call remain in one Rails action/request |

Direct participant access without valid ticket state must be rejected with a status code and
plain-text response. It must not redirect to dashboard or consume `rt`.

## Checkpoint Requirements

Email sign-up:

- birthdate.

Social sign-up:

- birthdate.

Telephone sign-up:

- birthdate;
- active passkey for the pending actor;
- active sign-in-capable passcode for the pending actor.

The checkpoint owns these requirements. A requirement may use a dedicated subroute, but the sequence
state remains `CHECKPOINT_PENDING` until all required items are clear.

## Authentication And Authorization Design

Sign-up implementation must keep these responsibilities separate:

- the state machine owns flow progression;
- `Actor.authn` exposes normalized authentication facts for the current request;
- Action Policy owns authorization decisions;
- controllers load context, invoke the state machine, call policy authorization, and render the
  result.

### State Machine Responsibility

The sign-up state machine decides whether the requested transition is valid for the current ticket.
It answers questions such as:

- whether email or telephone contact verification has been submitted;
- whether OTP verification has succeeded;
- whether guardrail can be evaluated;
- whether checkpoint can be entered;
- whether each checkpoint requirement is clear;
- whether finalization is allowed;
- whether the sequence has expired, failed, or reached a terminal state.

The state machine must not answer user authorization questions by itself. It may expose sequence
ownership facts, such as ticket id, pending actor id, pending contact id, surface, and current step,
so Action Policy can use them.

### `Actor.authn` Responsibility

`Actor.authn` is the request-local authentication fact snapshot. It may expose facts useful to
policy and controller code, such as:

- surface;
- current signed-in actor id when present;
- signed-in status;
- current AAL;
- satisfied methods;
- login/session public id;
- restricted-session status;
- active sign sequence id when a sequence-bound request is in progress.

It must not own sign-up route progression. The current step, completed checkpoint requirements,
pending contact ownership, and cleanup ownership remain on the sign-up cycle ticket.

Pending sign-up requests are not ordinary authenticated actor sessions. If a pending actor exists,
the ticket owns that pending actor relationship until finalization. Policy code may compare the
ticket's pending actor/contact ids with the request context, but it must not treat a pending actor
as fully signed in.

### Action Policy Responsibility

Action Policy decides whether the current request may view or mutate a sign-up resource. Examples:

- whether this request may view the sign-up checkpoint for this ticket;
- whether this request may submit a birthdate for this pending actor;
- whether this request may start passkey registration for the pending actor;
- whether this request may confirm passcode storage;
- whether this request may finalize the pending sign-up;
- whether direct access to a participant route is rejected because the sequence context is invalid;
- whether an already signed-in actor is forbidden from starting sign-up.

Policies should consume:

- `Actor.authn` facts;
- sign-up ticket ownership facts;
- current step / participant facts exposed by the state machine;
- surface-local actor/contact models.

Policies must not inspect raw request params as the authority for actor lifecycle decisions. Social
sign-in versus sign-up remains determined by provider identity database state.

### Policy API

Use Action Policy for all authorization decisions around sign-up tickets and sequence-owned
resources.

Suggested policy classes:

| policy                         | record                  | purpose                                               |
| ------------------------------ | ----------------------- | ----------------------------------------------------- |
| `SignUp::TicketPolicy`         | sign-up ticket          | start/resume/view/mutate a ticket                     |
| `SignUp::ParticipantPolicy`    | participant context     | enter guardrail or checkpoint                         |
| `SignUp::RequirementPolicy`    | requirement context     | view or clear birthdate/passkey/passcode requirements |
| `SignUp::FinalizationPolicy`   | finalization context    | finalize pending actor                                |
| `SignUp::SocialCallbackPolicy` | social callback context | accept app social callback into sign-up               |

The implementation may use surface-specific subclasses when local model names or route contracts
make that clearer, for example:

- `Sign::App::SignUp::TicketPolicy`;
- `Sign::Com::SignUp::TicketPolicy`.

If subclasses are used, they must preserve the shared policy method names.

Expected policy methods:

```ruby
start?
resume?
show?
submit_contact?
verify_contact?
enter_guardrail?
enter_checkpoint?
clear_requirement?
finalize?
handoff_to_sign_in?
cancel?
```

Requirement-specific methods may be added when useful:

```ruby
clear_birthdate?
register_passkey?
confirm_passcode?
```

### Policy Context Objects

Policies should receive explicit context objects instead of raw params.

Suggested context shapes:

```ruby
SignUp::PolicyContext(
  surface:,
  actor_authentication:,
  ticket:,
  step:,
  entry_method:
)

SignUp::RequirementContext(
  surface:,
  actor_authentication:,
  ticket:,
  requirement:,
  pending_actor:,
  pending_contact:
)

SignUp::FinalizationContext(
  surface:,
  actor_authentication:,
  ticket:,
  pending_actor:,
  completed_requirements:
)
```

Context objects may be plain value objects. They must not perform database writes.

### Policy Rules

Baseline policy rules:

- An already signed-in actor cannot start or resume app/com sign-up.
- A missing, expired, terminal, or cross-surface ticket cannot enter participant routes.
- A ticket can be mutated only by the browser/request context that owns the sequence state.
- A pending actor/contact can be viewed or mutated only through the ticket that owns it.
- `com` tickets cannot authorize social sign-up events or social callback handling.
- A requirement can be cleared only when the ticket is at `CHECKPOINT_PENDING` and that requirement
  belongs to the ticket's entry method.
- Finalization is authorized only when the ticket owns the pending actor and all required checkpoint
  requirements are clear.
- Handoff to sign-in is authorized only after durable sign-up finalization.

Ownership proof may use the ticket `public_id`, session-bound nonce, cleanup ownership marker, or
another explicit sequence binding chosen during implementation. It must not rely only on a pending
actor id in params.

### Controller Authorization Contract

Every controller action that views or mutates sign-up state must call Action Policy before invoking
a mutating state-machine event.

Expected shape:

```ruby
before_action :load_sign_up_ticket, only: %i(show update)
before_action :authorize_sign_up_ticket!, only: %i(show update)

def update
  result = SignUp::StateMachine.call(
    ticket: @sign_up_ticket,
    event: :clear_requirement,
    actor_context: Actor.authn,
    payload: requirement_form.to_payload,
  )

  render_sign_up_result(result)
end
```

The exact method names can follow local controller style, but the order should remain:

1. Load explicit sequence state.
2. Build policy context from `Actor.authn` and the ticket.
3. Authorize with Action Policy.
4. Normalize params into a form/payload.
5. Invoke the state machine.
6. Render the result.

### Controller And Before Action Responsibility

Controllers should remain HTTP-oriented. Their before actions may:

- load the sign-up cycle ticket;
- reject missing or expired sequence state before sequence-only participant actions;
- initialize or refresh `Actor.authn` facts available for the request;
- call `authorize!` or the local Action Policy equivalent;
- prepare form objects or view models.

Before actions should not embed business authorization rules as ad hoc conditionals. When a
condition decides whether the request is allowed to view or mutate sign-up state, put that condition
in policy and have the before action call the policy.

Controller actions should:

- validate and normalize params;
- call the state machine transition;
- call finalization or checkpoint requirement services when the transition permits it;
- map state-machine and policy results to render, redirect, or plain-text rejection;
- avoid deciding the next route by hardcoded controller-local order.

## Finalization Contract

Sign-up finalization runs only after all required sign-up requirements are complete.

The finalization unit:

- promotes or finalizes the pending actor;
- creates `rp_account` when missing;
- persists verified contact or social identity state;
- writes the sign-up audit event;
- returns a finalization result without choosing the final route.

Then, in the same Rails action/request, the controller enters the sign-in boundary:

```text
sign-up finalization -> sign-in boundary -> guardrail -> session issuance -> checkpoint -> dashboard -> rt
```

No redirect, render, or HTTP reload occurs between sign-up finalization and the sign-in boundary.

From the sign-up implementation's point of view, the handoff stops at calling the sign-in boundary
and receiving its result. Sign-up code must not know the internal sign-in route order, session-limit
details, checkpoint implementation, dashboard handling, or `rt` completion logic. Those belong to
the sign-in plan.

The sign-up user experience may still present a failed post-finalization sign-in as "sign-up did not
complete successfully", but implementation ownership remains separate. Sign-up classifies the result
only as:

- sign-up finalization failed before durable account completion;
- durable sign-up completed and sign-in boundary accepted the handoff;
- durable sign-up completed but sign-in boundary returned a failure/stop result.

Only the first case belongs to sign-up recovery. The third case is sign-in failure handling, even if
the UI copy is shown from a sign-up completion screen or controller.

## Failure Domains

Before durable finalization:

- use sign-up failure recovery;
- clean only artifacts owned by the current sign-up cycle;
- do not clean active actors or existing identities.

After durable finalization:

- use sign-in failure handling;
- keep actor, account, contact, credential, and social identity data.

Social sign-in versus sign-up is decided by provider identity database state, not request params.

## Implementation Phases

1. Extend sign-up cycle ticket models and migrations.
   - Extend `ClientSignUpCycle < AppTicketRecord`.
   - Extend `VisitorSignUpCycle < ComTicketRecord`.
   - Add accepted `entry_method`, `status`, `step`, safe `return_to`, expiry, and requirement
     validations.
   - Add unit tests for model validation, expiry, terminal state, and surface-specific social
     restrictions.

2. Add shared value objects and service contracts.
   - Add `SignUp::Result`.
   - Add policy context value objects.
   - Add state-machine command/result protocol.
   - Add requirement registry for app/com entry methods.

3. Add Action Policy coverage.
   - Add ticket, participant, requirement, finalization, and social callback policies.
   - Prove signed-in actors cannot start or resume sign-up.
   - Prove cross-surface and cross-ticket access is denied.

4. Add state-machine core without wiring all controllers.
   - Implement transition validation.
   - Implement terminal/expired ticket behavior.
   - Implement requirement clearing logic.
   - Implement typed side-effect service stubs where needed.

5. Add app/com participant routes and controllers.
   - Add `/sign/up/guardrail`.
   - Add `/sign/up/checkpoint`.
   - Implement direct-access rejection before adding full flow wiring.

6. Migrate app telephone first.
   - Create/resume ticket on entry.
   - Move telephone submission and OTP verification to ticket flow.
   - Keep pending actor/contact in principal DB.
   - Route OTP success to guardrail/checkpoint.
   - Do not finalize or issue a session from OTP success.

7. Move app telephone passkey/passcode setup under checkpoint.
   - Treat existing passkey registration route as checkpoint-owned during migration.
   - Add passcode issuance/confirmation requirement.
   - Finalize only after birthdate, passkey, and passcode are clear.

8. Migrate app email.
   - Move email submission and OTP verification to ticket flow.
   - Add birthdate checkpoint before finalization.
   - Replace direct `create_user_and_login` style completion with finalization plus sign-in boundary
     handoff.

9. Migrate app social.
   - Create social sign-up ticket before provider redirect.
   - Preserve safe `rt` in server-side social auth state.
   - Classify provider callback by database identity state.
   - Route new identities to birthdate checkpoint.
   - Route existing identities out of sign-up to sign-in handoff classification.

10. Migrate com email and telephone.
    - Reuse the same protocol with `VisitorSignUpCycle`.
    - Add birthdate checkpoint for com email.
    - Add birthdate/passkey/passcode checkpoint for com telephone.
    - Remove direct `root_path` completion from com telephone.
    - Add regression coverage proving social remains unavailable on com.

11. Add cleanup and expiry behavior.
    - Cleanup only ticket-owned pending artifacts.
    - Release abandoned telephone/email retry blockers where safe.
    - Do not clean active actors, durable contacts, existing credentials, or existing social
      identities.

12. Remove compatibility session progression.
    - Remove old credential-specific progression keys after each migrated controller has coverage.
    - Keep only session state that is still required for provider callback integrity, OTP cooldown,
      or WebAuthn challenge handling.

13. Documentation and handoff.
    - Update stable docs when implemented behavior changes.
    - Archive or supersede outdated backlog plan notes after implementation lands.

## Test Expectations

Model tests:

- ticket validates accepted entry methods per surface;
- ticket rejects social entry methods on com;
- ticket validates status and step values;
- ticket rejects unsafe `return_to`;
- expired and terminal tickets cannot mutate;
- requirement state never stores secret values.

State-machine tests:

- invalid transitions are rejected without side effects;
- contact verification cannot be skipped;
- checkpoint cannot be entered before contact/social verification;
- finalization cannot run before required checkpoint items clear;
- telephone finalization requires birthdate, passkey, and passcode;
- social existing identity exits sign-up and does not create sign-up artifacts;
- com social events are rejected.

Policy tests:

- participant access requires valid same-surface ticket state;
- requirement mutation requires ticket ownership and correct step;
- finalization requires ticket ownership and complete requirements;
- signed-in actor re-entry is denied;
- cross-ticket and cross-surface access is denied;
- com social callback/sign-up is denied.

Controller tests:

- app email finalizes only after email OTP and birthdate;
- app telephone finalizes only after telephone OTP, birthdate, passkey, and passcode;
- app Google and Apple preserve safe `rt` and require birthdate for new identities;
- existing social identity follows sign-in, not sign-up cleanup;
- com email and telephone mirror the app sequence shape without social auth;
- com social sign-up routes remain unreachable;
- direct guardrail/checkpoint access without valid state returns status code plus plain text;
- sign-in/session issuance failure after durable sign-up does not delete completed account data.

Cleanup tests:

- abandoned app telephone sign-up can release the number through owned cleanup;
- cleanup touches only artifacts owned by the current ticket;
- cleanup does not delete active actors, durable contacts, existing credentials, or existing social
  identities.

Shared interface tests:

- app and com use the same state-machine protocol;
- app and com do not share ticket records, sessions, routes, or pending actor state;
- shared concerns receive explicit surface configuration rather than inferring global state.

## Documentation Follow-Up

After implementation, update:

- `docs/security/sign-up-sequence.md`
- `docs/security/sign-in-sequence.md` if handoff behavior changes
- `adr/sign-up-authentication-handoff-and-social-rt.md` only if accepted decisions change
