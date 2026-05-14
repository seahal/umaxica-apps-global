# ADR: Jumper Current Boundary

**Status:** Obsolete (2026-05-13)

> Superseded by `adr/actor-current-facade.md`.
>
> The provisional per-surface `CurrentAttributes` direction (`Jumper`, and later `Apexer` /
> `Signer`) is abandoned. Current request context will be exposed to application code through the
> unified `Actor` facade instead. This document is historical only.

## Context

The old engine-era Current boundary ADR is obsolete. The current application still has a single
`Current < ActiveSupport::CurrentAttributes` that mixes actor, token, session, preference, domain,
and observability state.

Using that one `Current` object across `jump`, `apex`, and `sign` would make the object larger and
would couple surfaces that have different runtime needs.

`jump` is the right first boundary because it is almost blank:

- it is host-constrained by `JUMP_CORPORATE_URL`, `JUMP_SERVICE_URL`, and `JUMP_STAFF_URL`
- it has no authenticated session requirement
- it intentionally skips cookie session state
- it redirects through `AppJumpLink`, `ComJumpLink`, or `OrgJumpLink`

At the same time, jump still needs request-local state that is thread-safe under Rails' executor and
Puma's concurrent request model.

## Decision

Introduce a separate jump request context named `Jumper`.

The name `Jumper` is a provisional implementation name for the jump-first pass. It is accepted for
this pass so implementation can proceed, but it is not a permanent naming decision for the full
`jump` / `sign` / `apex` CurrentAttributes family.

`Jumper` will be an independent `ActiveSupport::CurrentAttributes` class:

```ruby
class Jumper < ActiveSupport::CurrentAttributes
end
```

It must not inherit from `Current`. `Current` remains the existing sign/apex runtime context until a
separate decision replaces or splits it.

Actor helper behavior should be shared through a Rails concern, not inheritance. The shared concern
will support the three authenticated actor types:

- `:user`
- `:staff`
- `:customer`

The unauthenticated default remains `Unauthenticated` / `:unauthenticated` for compatibility and for
blank public surfaces such as jump.

For the first implementation pass, `Jumper` is jump-only and minimal:

- `actor`
- `actor_type`
- `domain`

`Jumper` will not include token, session, preference, or observability state in the first pass.

## Naming

`Jumper` remains the name for the first jump implementation.

The broader naming scheme is deferred. We considered names such as `Signature`, `Signer`, `Apexer`,
`ApexCurrent`, and namespace-based `Jump::Current` / `Sign::Current` / `Apex::Current`, but this ADR
does not adopt any of them.

Future work should revisit naming across all three surfaces together. Until that happens, do not
introduce sign or apex CurrentAttributes classes and do not rename `Jumper` as part of unrelated
work.

## Surface Scope

### Decided now

`jump` will use `Jumper`.

The implementation will add a `Jump::ApplicationController` that sets and resets `Jumper` for jump
requests. Existing jump redirect behavior remains unchanged.

### Deferred

`sign` and `apex` Current branching is intentionally deferred.

Future work may decide whether sign and apex should:

- keep using the current `Current`
- receive separate CurrentAttributes classes
- share only small concerns and value objects

This ADR does not decide that future shape.

## Consequences

- Jump gets an isolated request-local context without growing the existing `Current`.
- The actor helper contract can be reused without making `Jumper` a subclass of `Current`.
- Sign and apex continue to behave as they do today.
- Any future sign/apex split can be designed from observed usage instead of being forced by the jump
  implementation.

## Related

- `adr/current-context-boundary-by-engine.md` — obsolete engine-era predecessor
- `adr/preference-soft-bubble-doctrine.md` — current single-app preference runtime doctrine
- `adr/secure-jump-link-redirector.md` — current jump redirector behavior
- `plans/active/jumper-current-jump-plan.md` — implementation plan for the first jump pass
