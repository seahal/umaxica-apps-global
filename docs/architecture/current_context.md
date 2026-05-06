# Current Context Architecture

## Purpose

This document defines the target request-context model for the four-engine architecture.

The old application-level `Current` object is not the target shape for the engine-isolated design.
Engine-local `Current` usage remains part of the design where request-scoped runtime state is
needed.

## Status

This is the target architecture direction as of 2026-04-16.

Implementation planning is still **TBC**.

Any future `plans/` documents for this area are temporary working material and may change before or
during implementation.

## Rules

### 1. Request current context is owned by the engine

Do not treat request-scoped state as one shared host-app global across all engines.

- `Identity` owns its request current context
- `Zenith` owns its request current context
- `Foundation` owns request current context where it is needed
- `Distributor` does not use shared `Current` by default

Use `Current` where the engine needs request-local runtime state.

The main reasons are:

- a request should not read actor, token, or preference state from another in-flight request
- request context should not depend on ad-hoc shared mutable state
- request-local state should reset with the request lifecycle

### 2. Foundation and Distributor do not use one current model for all entry points

The business and delivery surfaces have different runtime needs by entry point.

- `base.*` uses engine-local current context
- `post.*` does not use `Current` by default

When `post.*` needs request metadata, prefer explicit helpers or narrow request-scoped objects.

### 3. Shared code may share value objects, not one mutable request container

Small immutable value objects may be shared across engines if the contract is stable.

Examples:

- subject snapshot
- preference snapshot
- request metadata

Do not reintroduce a shared mutable `CurrentAttributes` object through an abstraction layer.

### 4. Prefer typed snapshots over database objects and raw token hashes

Current context should carry only the data needed by the current engine.

Prefer:

- subject type
- public identifier
- authenticated state
- selected preference fields
- request identifiers

Avoid using these as the primary shared contract:

- full Active Record actor objects
- raw JWT payload hashes
- unrelated cross-engine session state

## Current Adoption

### `Identity`

Use engine-local `Current` for request-scoped authentication and token context.

### `Zenith`

Use engine-local `Current` for request-scoped relying-party context such as subject and preference
snapshots.

## Foundation and Distributor Boundary Guidance

### `base.*`

`base.*` may use engine-local current context for business flows that need authenticated subject,
preference, and request boundary data.

### `post.*`

This entry point should remain simpler.

- no dependency on `Current`
- no assumption of authenticated actor state
- no shared token payload contract

If they need request metadata, keep it explicit and narrow.

## Related

- `adr/current-context-boundary-by-engine.md`
- `docs/architecture/engine.md`
