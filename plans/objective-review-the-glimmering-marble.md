# Revised Actor Redesign Review

> Review-only deliverable. No code changed, no implementation proposed beyond the smallest safe
> corrective shape. Grounded in the current `Actor` subsystem as it exists in the repository today.

## Verdict

**PASS WITH CHANGES** — and three of the design's _stated directions_ are **FAIL** on their own
(remove `CurrentAttributes`; lazy `build_context` pull inside `Actor`; `surface` replacing `tld`).
The two-file _file layout_ is acceptable. The two-file _responsibility model as drawn in §4_ is not
— it cannot reconstruct authenticated state from `request` alone, and it deletes safety that nothing
replaces.

The redesign is salvageable with a small number of corrections. It is **not** implementable exactly
as specified.

## Executive Summary

The existing `Actor` is already a thin, Rails-native, request-local facade:
`Actor < ActiveSupport::CurrentAttributes` holding one immutable `Actor::Context` (`Data.define`, 13
fields), populated by a two-phase **push** from the controller pipeline (`set_current_context`
early, `set_current_actor` after auth), and torn down by a prepended `around_action`
`ensure Actor.clear`. Authorization (ActionPolicy) reads `Actor.authz`. There are 124 call sites.

The revised design keeps the _shape_ (class facade, immutable value object) but proposes four
changes that each remove or invert something load-bearing:

1. **Lazy pull** (`Actor.current ||= build_context` from a stored `request`) instead of the
   controller push. This **cannot work**: reconstructing `authn`/`authz`/ `preferences`/`step_up`
   requires token decode + DB lookup + DPoP/DBSC verification
   - _transparent refresh that writes cookies_. Those are controller-only side effects that must not
     happen inside a memoized `Actor.current`. **Blocking.**
2. **Remove `CurrentAttributes`** in favor of `RequestStore`. No benefit is stated; it is lateral at
   best and regressive (manual middleware ordering, manual test clearing, raise-on-missing instead
   of safe `NULL` empty). `CurrentAttributes` _is_ the Rails-native answer the design says it wants.
   **Blocking direction — keep `CurrentAttributes`.**
3. **`surface` replaces `tld`.** These are orthogonal axes. `tld` (`:app,:com,:org,:net,:dev`, 5
   tiers) drives tenant scoping and `Authz.surface`; the 8 values (`acme/sign/core/base/palm/...`)
   are route namespaces. Collapsing them loses the tier dimension 12 `Actor.tld` call sites and the
   policy layer depend on. **Blocking — they must coexist.**
4. **`ActorValuesContext` adds `claims`, `scopes`, `session`, `credential`** as top-level fields
   that _duplicate_ data already inside `authn`/`authz` (`access_claims`, `token_claims`,
   `login_public_id`). Two sources of truth → drift. **Non-blocking but must be cut.**

What is genuinely good: the file count, the immutable value object, the `transport`/`channel` axes
(with corrections), and the public predicate facade.

## What Is Sound

- **Two _files_ is fine.** `app/models/actor.rb` + `app/values/actor_values_context.rb` is a
  reasonable footprint. `app/values/` already exists and is autoloaded by Zeitwerk. Consolidating
  today's scattered `app/models/actor/*` value objects into one `ActorValuesContext` is coherent _as
  a container_.
- **Immutable value object** matches the existing pattern exactly (`Actor::Context` is already
  `Data.define` and frozen sub-objects with `NULL` singletons).
- **`transport` axis** (`:cookie`/`:bearer`/`:none`) maps cleanly onto existing
  `AuthAuthorizationHeader` bearer/DPoP detection + cookie presence, and onto the documented
  audience↔transport binding (`aud=core-browser`⇒cookie, `aud=palm-api`⇒bearer,
  `aud=side-service`⇒service).
- **Public predicate facade** (`authenticated?`, `operator?`, `client?`, `visitor?`, `anonymous?`)
  already exists and is used; keeping it Rails-like is acceptable.
- **`reset!` in an `ensure` block** is already the production pattern (`with_actor_lifecycle` /
  `prepend_around_action`), endorsed by `docs/architecture/controller-lifecycle.md`. Direction is
  correct.
- **BareController not binding Actor** is already true and correct; bare endpoints (health, robots,
  jwks) never read Actor.

## Blocking Issues

### B1. Lazy `build_context` from `request` cannot reconstruct authenticated state

`§4`'s `Actor.current → request_store[...] ||= build_context` with `build_context` "from request and
existing auth/session/credential state" is architecturally impossible from inside `Actor`. The
current `set_current_actor` path proves why: it depends on `safe_current_resource` (loaded by
`AuthenticationClient/Operator/Visitor`), `transparent_refresh_access_token` (**writes cookies**
before actor load), token decode/verification (`AuthenticationCurrentResourceResolver`, DPoP/DBSC),
and request-local preference overlay applied _after_ the snapshot. `Actor` holding only `request`
has none of this and must not perform cookie-writing side effects lazily. **Fix:** keep the **push**
model. The controller pipeline resolves and installs the context; `Actor` stores and exposes it. Do
not invert to pull.

### B2. Removing `CurrentAttributes` removes safety with no stated gain

`CurrentAttributes` already provides: framework-driven reset per request via the Rails executor
(correct under Puma thread reuse), automatic per-test clearing (every test runs in the executor),
and safe `Context.empty`/`NULL` reads when unbound. Switching to `RequestStore.store` requires you
to re-earn all three by hand (middleware presence/order, explicit test clearing, and a chosen
missing-context policy). `request_store` is present but used only by geocoder/mobility — adopting it
for Actor is new surface for no benefit. **Fix:** keep `Actor < ActiveSupport::CurrentAttributes`.
It already satisfies "not a process-global singleton," request-local, thread-safe, auto-reset.

### B3. `surface` cannot replace `tld`

`tld` (`CoreSurface::SURFACES = %i[app com org net dev]`) is the auth/tenant tier and is written
into `Actor::Authz.surface`; 12 sites read `Actor.tld`. The 8 proposed `surface` values are route
namespaces. A single request to `core/app` has **both** `surface=:core` and `tld=:app`. Collapsing
them deletes the tier axis the policy layer and tenant scoping need. **Fix:** keep `tld` (or rename
consistently everywhere) **and** add `surface` as a distinct axis. They coexist permanently, not
"temporarily."

### B4. Forbidding `app/services/*`/concerns assumes resolution has no home

The prohibition reads as "introduce no _new_ support files." But resolution already lives in
`ActorSupport`, `StepUpResolver`, and `HostContextResolver`, and it must stay there (it needs
controller state — see B1). If the rule is read literally as "resolution must move into `Actor`,"
`Actor` becomes a god object that reimplements authentication. That is unsafe and out of scope for
an Actor redesign. **Fix:** explicitly scope the constraint to _new_ files. Existing resolver
concern/services remain the population path; `Actor` stays a facade.

## Non-blocking Risks

- **N1 — Duplicate fields in `ActorValuesContext`.** `claims`, `scopes`, `session`, `credential`
  duplicate `authn.access_claims` / `authz.token_claims` / `authn.login_public_id`. Cut them; expose
  via `authn`/`authz` (or thin delegators) to keep one source of truth.
- **N2 — `channel` derived from `transport` is redundant.** Today browser/native is _inferred_ from
  cookie/bearer. If `channel` just mirrors `transport` it adds nothing. Derive `channel` from
  **audience** instead (`aud=core-browser`⇒`:browser`, `aud=palm-api`⇒`:native`,
  `aud=side-service`⇒`:server`). Then `browser?`/`native?` read `channel`, not `transport` —
  answering §6 directly: **yes, base `browser?`/`native?` on `channel`, not transport/bearer.**
- **N3 — Rename churn.** `install_context!`→`bind_request!` and `clear`→`reset!` touch 17 sites and
  contradict `controller-lifecycle.md` ("use the domain-facing `Actor.clear`").
  `bind_request!(request)` also signals the wrong (pull) model. Prefer keeping
  `install_context!`/`clear`; if renamed, keep old names as aliases and update the doc in the same
  change.
- **N4 — `ActionController::Live` streaming.** `ensure reset!` and thread-local storage interact
  badly with streamed responses (action runs in a separate thread). Pre-existing caveat; flag, don't
  fix here.
- **N5 — Stale context after mid-request credential revocation.** The snapshot is resolved once; a
  revocation later in the same request is not reflected. Acceptable (matches today), but document
  that `Actor.current` is a request snapshot, not live.

## Recommended Minimal Implementation Shape

Keep the two files, keep the engine, correct the model:

```text
app/models/actor.rb              # Actor < ActiveSupport::CurrentAttributes (facade)
app/values/actor_values_context.rb  # immutable Data value object (the consolidated Context)
```

- `Actor` stays `CurrentAttributes` with one `attribute :context`,
  `resets do self.context = ActorValuesContext.empty end`. **Push** API retained
  (`install_context!`); `reset!`/`bind_request!` at most thin aliases.
- `ActorValuesContext = Data.define(...)` with: `subject` (today's `actor`), `actor_type`, `tenant`,
  `tld`, `surface`, `transport`, `channel`, `authn`, `authz`, `configuration`, `preferences`,
  `selection`, `step_up`, `trace_id`, `span_id`. **Drop** `claims`, `scopes`, `session`,
  `credential` (N1). Provide `self.empty` returning all-`NULL`/`nil`. Anonymous = `subject: nil` +
  `actor_type: :unauthenticated` (matches `Unauthenticated.instance` today; a dedicated anonymous
  object is optional sugar, not required).
- Resolution stays in the existing `ActorSupport` concern + `StepUpResolver` /
  `HostContextResolver`. No god object.
- The six existing `Actor::*` value classes either remain as the typed contents of the fields, or
  are folded into `actor_values_context.rb`; both are fine. Do not duplicate their data at the top
  level.

If a future need to drop `CurrentAttributes` is ever justified, that is a separate decision with its
own justification — not part of this redesign.

## Required Guardrails

- **G1 — `Actor.operator?`/`client?`/`visitor?` are role hints, never authorization.**
  ActionPolicy + un-skippable `enforce_access_policy!` remain the only authorization gate. Add a
  class-level comment and, ideally, a grep/lint forbidding `if Actor.operator?` as a guard around
  protected behavior. Answers §7.
- **G2 — Keep `Actor.authz`.** `ApplicationPolicy` reads `Actor.authz.policy_user` and
  `Actor.authz.token_claims` via `current_policy_user`/`current_token`. Removing it breaks
  authorization. Answers §8: authz **stays**.
- **G3 — Missing-context policy = safe empty, not raise.** With `CurrentAttributes`, unbound reads
  return `ActorValuesContext.empty` (all `NULL`). Keep that. A raise-on-missing
  (`MissingRequestContext`) would break the many `if defined?(Actor)` reads and any Bare/job/mailer
  path. Reserve raising for explicit bang accessors only (G4).
- **G4 — No broad bang accessors.** Anonymous is a normal state (open/bare/guest endpoints), so
  `Actor.subject!`/`session!`/`tenant!` would raise routinely. Introduce them only at call sites
  where authentication is already enforced, if at all.
- **G5 — Validate `surface`/`transport`/`channel` at construction.** Raise on invalid enum values
  inside `ActorValuesContext.new` (fail fast; the values are a closed set). Freeze nested
  `claims`/`scopes` if they survive.
- **G6 — `reset!` stays in a prepended `around_action … ensure`** (already the pattern).
  Logout/boundary transitions keep their explicit `Actor.clear`.
- **G7 — `app/values` eager-load.** Currently autoloaded but not eager-loaded (only `app/errors`
  is). If `ActorValuesContext` is read on hot paths, add it to `eager_load_paths` to avoid
  first-request autoload cost in production.

## Existing Code That Must Be Overridden Or Preserved

**Preserve (load-bearing):**

- `Actor < ActiveSupport::CurrentAttributes` and `resets do … end` (B2).
- Two-phase push: `ActorSupport#set_current_context` / `#set_current_actor`, and the resolver
  methods (`resolved_current_authentication/authz/preference/selection/ step_up`) (B1, B4).
- `StepUpResolver`, `HostContextResolver` services (B4).
- `Actor.authz` field + `ApplicationPolicy`/`current_policy_user`/`current_token` wiring;
  ActionPolicy subject key `user` (do **not** rename per `controller-lifecycle.md`) (G2).
- `tld` axis + `CoreSurface` (B3).
- `prepend_around_action :with_actor_lifecycle` ⇒ `ensure Actor.clear`; logout/ cookie-clear
  `Actor.clear` paths.
- `BareController < ActionController::Base` with no Actor binding.

**May be overridden (system undeployed):**

- Field naming: `actor`→`subject`, `tld` kept but `surface`/`transport`/`channel` added.
- Consolidating `Actor::{Authentication,Authz,Configuration,Preference, SelectedContext,StepUp}` and
  `Actor::Context` into `ActorValuesContext` (without duplicating their data).
- Optional `install_context!`→`bind_request!` / `clear`→`reset!` rename _with_ aliases + doc update
  (N3).

**Likely-breaking call sites to plan for:**

- `Actor.authn` (53) and `Actor.preferences` (18) — any field reshaping ripples widest here.
- `Actor.tld` (12) — protect against B3.
- `Actor.install_context!` (9) / `Actor.clear` (8) — protect against rename churn.
- `ApplicationPolicy` authz reads — protect against G2.

## Failure-Mode Classification

| Failure mode                               | Classification                  | Rationale                                                          |
| ------------------------------------------ | ------------------------------- | ------------------------------------------------------------------ |
| `Actor.current` outside request            | acceptable                      | returns `empty`/`NULL` under `CurrentAttributes`                   |
| `Actor.current` in background job          | acceptable                      | returns `empty`; jobs must pass actor explicitly, not read ambient |
| `Actor.current` in mailer                  | acceptable                      | same as job                                                        |
| `Actor.current` in model callback          | needs guard                     | discouraged (ambient coupling); allow read-only, never write       |
| `Actor.current` in tests without bind      | acceptable                      | returns `empty`; executor auto-clears between tests                |
| `Actor.current` after reset                | acceptable                      | returns `empty`                                                    |
| `Actor.current` before bind                | acceptable                      | returns `empty` (do **not** raise — G3)                            |
| `Actor.current` from BareController        | acceptable                      | returns `empty`; Bare never binds, never depends                   |
| `Actor.reset!` skipped                     | needs guard                     | rely on framework executor reset + `ensure`; don't hand-roll       |
| `RequestStore` unavailable                 | n/a if `CurrentAttributes` kept | eliminated by B2; otherwise **must block**                         |
| `app/values` not autoloaded                | needs guard                     | autoloaded today; eager-load on hot paths (G7)                     |
| `ActorValuesContext` mutable               | must block                      | must be `Data`/frozen                                              |
| `claims`/`scopes` mutable                  | must block                      | freeze, or remove the fields (N1)                                  |
| `surface`/`transport`/`channel` invalid    | must block                      | validate + raise at construction (G5)                              |
| `browser?` conflated with `cookie?`        | needs guard                     | base `browser?` on `channel`, not transport (N2)                   |
| `native?` conflated with `bearer?`         | needs guard                     | base `native?` on `channel`, not transport (N2)                    |
| authorization bypass via `Actor.operator?` | must block                      | predicate is a role hint only; ActionPolicy is the gate (G1)       |
| stale context after mid-request revocation | acceptable                      | snapshot semantics, documented (N5)                                |

## Open Questions

1. **Is the `install_context!`→`bind_request!` rename worth 17-site churn + a doc edit, given the
   name implies the rejected pull model?** Recommendation: no.
2. **Where does `channel` come from authoritatively** — audience claim (preferred), client
   registration, or transport fallback? Needs one source.
3. **Do `help`/`docs`/`news`/`palm` surfaces need `transport`/`channel` at all,** or only
   `acme`/`sign`/`core`/`base`? (Read-only tri-partitioned surfaces may not.)
4. **Should the six `Actor::*` value classes be folded into one file, or kept and merely
   _referenced_ by `ActorValuesContext`?** Both satisfy "two files" for the facade; folding is more
   invasive.
5. **Eager-load `app/values` now or defer** until a hot-path read is confirmed?

```

```
