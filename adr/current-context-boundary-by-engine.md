# ADR: Split Request Current Context by Engine Boundary

> **Status update (2026-04-26):** Obsolete. Per `adr/split-into-regional-and-global-repos.md`
> (2026-04-25), the Rails Engine strategy is abandoned and this repository is now a single Rails app
> (the **global** side of the global / regional split). Engine-local `Current` boundaries
> (`Identity` / `Global` / `Regional`) no longer apply. `Current` design for the single-app model
> should be addressed in a separate ADR if needed. Treat this document as historical only.

**Status:** Accepted (2026-04-16)

## Context

The current implementation uses one shared `Current < ActiveSupport::CurrentAttributes>` in the host
application.

That object currently mixes:

- authenticated actor state
- token payload state
- request boundary state
- preference state
- observability state

This design does not fit the current target architecture well.

The platform now treats `Identity`, `Global`, and `Regional` as independent engine boundaries with
`isolate_namespace` and deployment-mode isolation. A single shared `Current` encourages hidden
cross-engine assumptions and makes it too easy to keep request state coupled across boundaries.

At the same time, the application still needs a request-local context mechanism.

This is important in threaded app-server environments such as Puma:

- multiple requests may run at the same time
- actor, token, preference, and request metadata from one in-flight request must not be read
  accidentally from another in-flight request
- ad-hoc state stored on long-lived shared objects is too easy to misuse

For that reason, `CurrentAttributes` remains a valid pattern for request-scoped runtime state. The
problem is not using `Current`. The problem is using one shared host-level `Current` across all
engine boundaries.

Within `Regional`, the four entry points do not have the same runtime needs:

- `base.*` needs request-scoped business context
- `docs.*` does not plan to use `Current`
- `help.*` does not plan to use `Current`
- `news.*` does not plan to use `Current`

## Decision

We will move away from one shared request `Current` object and adopt engine-local current context.

### Engine-local current objects

- `Identity` owns its own current context
- `Global` owns its own current context
- `Regional` owns its own current context only for `base.*`

`docs.*`, `help.*`, and `news.*` in `Regional` will not depend on `Current`.

If those entry points need request metadata, they should use explicit controller helpers or other
small request-scoped objects instead of a full `CurrentAttributes` container.

### Shared interface shape

We may share small immutable value objects across engines when the data shape is stable.

Allowed shared building blocks include:

- subject snapshot value objects
- preference value objects
- request metadata value objects

The shared interface is for values, not for a shared mutable global request container.

### Actor and token handling

Engine-local current context should prefer typed snapshots over full Active Record objects and raw
JWT payload hashes.

This means:

- do not make a cross-engine shared `Current.actor` the main contract
- do not make a cross-engine shared `Current.token` hash the main contract

When a request needs authenticated subject data, use an explicit subject context shape with the
minimum fields required for that engine.

## Consequences

### Positive

- Engine boundaries become explicit in request context code.
- Request-local state remains isolated from other concurrent requests more safely than ad-hoc shared
  mutable state.
- `Regional` can keep `base.*` stateful without forcing the same pattern on content surfaces.
- `docs.*`, `help.*`, and `news.*` stay simpler and avoid accidental auth coupling.
- Shared value objects remain portable without reviving one global `Current`.

### Negative

- Existing shared concerns and tests will need refactoring.
- Some current helper APIs will need compatibility shims during migration.
- The final typed shape for subject and token context is not fully settled yet.

## Notes

- This ADR defines the target boundary and ownership model.
- The execution sequence and migration steps are still **TBC**.
- Any future `plans/` documents for this work are working drafts only and may be revised later.

## Related

- `adr/three-engine-consolidation.md`
- `adr/engine-isolate-namespace-adoption.md`
- `docs/architecture/engine.md`
