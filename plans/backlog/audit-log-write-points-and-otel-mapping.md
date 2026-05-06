# Audit Log Write Points And OTEL Mapping

## Summary

This note records the current design direction for where audit logs should be written and how they
should relate to OTEL traces.

The goal is to avoid:

- writing audit logs too early at request entry
- mixing technical telemetry and business audit records
- depending on model callbacks that lose business intent

## Current Decision

Audit logs should be written where the business outcome becomes clear.

Preferred order:

1. service or domain operation layer
2. controller only when the action is inherently controller-driven
3. avoid model callbacks as the primary audit write point

## Write Point Rule

### Preferred write point

Write the audit event when the operation result is decided.

Examples:

- a passkey was successfully registered
- a session was revoked
- a contact form was successfully submitted

This usually means:

- controller gathers request context
- service performs the business operation
- service writes the audit event through a shared recorder

### Controller responsibility

The controller should provide request-scoped context such as:

- actor
- request_id
- IP address
- user agent
- host or route if needed

The controller should not become the main place where audit semantics are decided.

### Model callback warning

Do not use model callbacks as the default audit write point.

Reasons:

- they lose request context easily
- they do not clearly show business intent
- they may fire from many code paths
- they are harder to reason about in tests and maintenance

## Suggested Recorder Shape

Use a shared recorder interface so write points stay consistent.

Example shape:

- `AuditContext`
  - actor
  - request_id
  - ip_address
  - user_agent
- `AuditRecorder.record(...)`
  - event_id
  - subject
  - result
  - context

## OTEL Relationship

OTEL and audit logs should stay separate.

- OTEL answers: what happened technically?
- audit logs answer: what business action was performed, by whom, on what target?

They should be linked by:

- `request_id`
- later, optionally `trace_id`

Do not force one event name to serve both systems.

## First Three Mapping Examples

### Example 1: Login

#### OTEL family

- `auth.login.request`

#### Audit events

- `auth.login.succeeded`
- `auth.login.failed`

#### Write point

Controller-driven flow is acceptable here if no deeper service boundary exists.

Preferred design:

- controller resolves request context
- authentication service decides success or failure
- service or controller-adjacent recorder writes the audit event

#### Correlation

- same `request_id` as the HTTP request trace

### Example 2: Passkey registration

#### OTEL family

- `auth.passkey.registration`

#### Audit events

- `auth.passkey.registered`
- `auth.passkey.registration_failed`

#### Write point

Write when the passkey registration result is final.

Preferred design:

- controller passes request context
- passkey service performs registration
- service writes the audit event after success or failure is known

#### Correlation

- same `request_id`
- later optional `trace_id`

### Example 3: Contact submission

#### OTEL family

- `contact.create.request`

#### Audit events

- `contact.submitted`
- `contact.submission_failed`

#### Write point

Write when the contact record and any required side effects are complete enough to count as a real
submission attempt.

Preferred design:

- controller gathers request context
- contact submission service validates and persists
- service writes the audit event with the resulting subject

#### Correlation

- same `request_id`

## Practical Rule

When deciding where to write an audit log:

- if the event is only a technical step, keep it in OTEL
- if the event represents a meaningful business action, write an audit record
- if the action result is not yet known, wait

## Next Follow-Up

This note should later feed:

1. the initial audit event list
2. the audit recorder API
3. implementation issues for authentication, account settings, and staff actions

## Minimum Initial Audit Event Set

The first audit event set should stay small.

The goal is to cover actions that are:

- security-sensitive
- account-affecting
- operationally important

### Group 1: Authentication

Start with:

- `auth.login.succeeded`
- `auth.login.failed`
- `auth.logout.completed`
- `auth.session.revoked`
- `auth.otp.verified`
- `auth.otp.failed`
- `auth.passkey.registered`
- `auth.passkey.removed`
- `auth.oauth.linked`
- `auth.oauth.unlinked`
- `auth.oauth.failed`

Reason:

- these actions matter for security review
- they are often investigated during account incidents
- they are easy to understand as business actions

### Group 2: Account And Security Setting Changes

Start with:

- `user.email.added`
- `user.email.removed`
- `user.telephone.added`
- `user.telephone.removed`
- `user.secret.created`
- `user.secret.regenerated`
- `user.secret.deleted`
- `auth.mfa.enabled`
- `auth.mfa.disabled`
- `preference.reset.completed`

Reason:

- these actions change account recovery or control surfaces
- they affect who can access the account later
- they are high-value for support and incident review

### Group 3: Staff And Operations Actions

Start with:

- `staff.user.status_changed`
- `staff.session.revoked`
- `staff.contact.updated`
- `staff.contact.deleted`
- `staff.sensitive_record.viewed`

Reason:

- these are actions where operator accountability matters
- these actions often need later explanation
- staff access should be easier to review than ordinary user behavior

## What To Exclude From The First Set

Do not include the following in the first audit event set:

- page views
- generic feature usage
- low-risk read events by ordinary users
- product funnel analytics
- retention analytics

These belong to product analytics or behavior analysis, not the first audit foundation.

## Practical Start Rule

Use this rule when deciding whether an event belongs in the first audit set:

- if losing the event would hurt incident review, support response, or accountability, include it
- if the event is mainly useful for product analysis, exclude it from the first audit set

## Audit Event Naming Rule

Audit event names should stay:

- stable
- explicit
- business-oriented
- independent from UI wording

### Naming format

Use a dotted lowercase form:

- `domain.object.action`
- `domain.object.action.result` when success and failure must be separated

Examples:

- `auth.login.succeeded`
- `auth.login.failed`
- `auth.passkey.registered`
- `user.email.added`
- `user.secret.regenerated`
- `staff.contact.updated`
- `staff.user.status_changed`

### Naming rules

1. prefer business meaning over technical implementation detail
2. prefer explicit verbs such as `added`, `removed`, `revoked`, `linked`, `failed`
3. keep the prefix stable by domain, such as `auth`, `user`, `staff`, `contact`, `session`
4. do not encode transport detail such as controller name, HTTP verb, or route path in the event id
5. do not reuse OTEL span names directly as audit event ids

### Result handling

When success and failure are both important, use separate events:

- `auth.login.succeeded`
- `auth.login.failed`

Do not overload one event id with a free-form result string unless there is a clear reason.

### Why this rule

This makes audit records easier to:

- query
- aggregate
- reason about
- keep stable across UI and controller refactors

## Minimum Audit Log Columns

The first audit table design should keep a small required set.

### Required columns

- `actor_id`
- `actor_type`
- `subject_id`
- `subject_type`
- `event_id`
- `occurred_at`
- `request_id`
- `ip_address`
- `context`

### Column meaning

#### Actor

- `actor_id`
- `actor_type`

These identify who performed the action.

#### Subject

- `subject_id`
- `subject_type`

These identify the target of the action.

The subject can be:

- the same as the actor
- another account
- a contact record
- a passkey
- a session-related record

#### Event

- `event_id`

This identifies the type of business action.

Use either:

- a stable string event key
- or a foreign key to an event master table

Either approach is acceptable as long as the event vocabulary stays stable.

#### Time

- `occurred_at`

This records when the action happened.

#### Request correlation

- `request_id`

This links the audit record to:

- application logs
- OTEL traces
- support investigation flow

#### Source context

- `ip_address`
- `context`

`context` should be a small structured payload, usually `jsonb`.

Suggested contents:

- user agent
- host
- route or endpoint name
- result metadata when needed

### Data minimization rule

Do not store secrets or unnecessary sensitive payloads in audit context.

Avoid:

- passwords
- raw OTP values
- full tokens
- authorization headers
- message bodies
- large request payload copies

### Initial design preference

The first version should prefer:

- append-oriented writes
- small structured context
- request correlation
- stable event ids

Detailed tamper resistance can be added later.
