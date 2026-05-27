# Architecture

## Overview

This is a multi-surface Ruby on Rails application.

Surfaces:

- app (end-user application)
- org (staff / organization)
- com (public / corporate)

Each surface MUST be treated as an independent boundary.

---

## Controller Responsibilities

Controllers MUST:

- Handle HTTP concerns only
- Delegate business logic to models/services
- Enforce authentication, authorization, and verification

Controllers MUST NOT:

- Contain heavy business logic
- Access other surfaces directly
- Bypass pipeline concerns

---

## Data Layer

- ActiveRecord is used
- Direct SQL is forbidden unless explicitly justified
- Bulk operations must be carefully reviewed

---

## Separation of Concerns

- Controllers: request/response
- Models: domain logic
- Policies: authorization
- Concerns: cross-cutting behavior

Rails concerns MUST stay small and low side-effect:

- Define reusable behavior in the concern.
- Do not make including a concern install callbacks, expose helpers, mutate sessions/cookies/state,
  change authorization, or trigger other runtime side effects unless an existing, reviewed pattern
  explicitly requires it.
- Make the including controller, model, service, or other class opt in to side effects explicitly.
- Keep concern methods private by default. Expose public methods only when the including class or
  external callers need a stable public contract, and make that boundary intentional.

## Working Notes

- Use `notes/implementation/` for implementation decisions, plan deviations, compromises, and
  handoff context discovered while carrying out a plan.
- Use `memos/` for exploratory notes, rough analysis, and provisional observations that do not
  affect implementation.
- Keep notes and memos out of stable docs, plans, and ADRs until they are ready to be promoted.

---

## Non-Negotiable Rules

DO NOT:

- Mix surfaces (app/org/com)
- Share state across requests
- Store request data in class variables

ALWAYS:

- Respect boundaries
- Keep logic deterministic
