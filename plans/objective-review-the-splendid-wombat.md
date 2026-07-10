# Revised Actor Redesign Review

> Review-only deliverable. No code is changed. This file is the report. Evidence is drawn from the
> existing subsystem, not from the proposal text.

## Verdict

**FAIL** — as literally specified (two files, `CurrentAttributes` removed, raw `RequestStore`,
renamed `subject`/`session`/`surface`/`transport`/`channel` facade).

The proposal is not safe or coherent against the current codebase, and three of its defining
decisions are net regressions or direct violations of an **accepted ADR**. There is a salvageable
core (the `transport` / `channel` axes and an immutable value object), which is why the report ends
with a narrower shape that would PASS. But the required changes negate the proposal's premises, so
this is FAIL, not PASS-WITH-CHANGES.

## Executive Summary

The objective frames this as a greenfield-ish cleanup of an undeployed `Actor`. The reality on disk
is the opposite of greenfield:

1. `Actor` is governed by **`adr/actor-current-facade.md` (Accepted, 2026-05-13)**, which is
   source-of-truth decision material (AGENTS.md priority #3). That ADR makes three of the proposal's
   choices forbidden-by-name:
   - It mandates `Actor` is **backed by `ActiveSupport::CurrentAttributes`**. The proposal removes
     `CurrentAttributes`.
   - It states **`Actor.surface` and `Actor.domain` are removed and "must not be restored as
     compatibility aliases"**; `Actor.tld` is the _only_ surface API. The proposal re-introduces
     `Actor.surface`.
   - It states **`Actor.session` reads are removed** in favor of `Actor.authn.login_public_id`, and
     **`Actor.token` is removed**. The proposal re-introduces `Actor.session` and a raw
     `credential`/`claims` surface. "May be overridden because not deployed" lowers _data_-migration
     risk. It does **not** lower the cost of silently contradicting an accepted ADR. Overriding it
     is allowed, but only via an explicit **superseding ADR**, not inside a redesign that quietly
     renames the API the ADR pinned.

2. The "two files" claim is a **fiction about where resolution lives**, not a real simplification.
   Today the facade (`app/models/actor.rb`) is already tiny and pure: it receives a pre-built
   immutable snapshot. The actual work — JWT decode/verify, resource lookup, host→surface
   resolution, preference-JWT + overlay, step-up TTL/binding — lives in
   `app/controllers/concerns/actor_support.rb` (425 lines), `app/services/host_context_resolver.rb`,
   `app/services/step_up_resolver.rb`, and the per-area value objects under `app/models/actor/`. The
   proposal forbids concerns, services, and resolvers, then hand-waves resolution into a
   `build_context` method **inside `Actor`**. That is exactly the god-object outcome the objective
   says it wants to avoid. The two-file count is only reachable by either (a) cramming all
   resolution into `Actor` (god object), or (b) keeping a controller-boundary installer — i.e. a
   third+ file that already exists. The proposal's own constraints are internally contradictory.

3. Removing `CurrentAttributes` for raw `RequestStore.store` is a **safety regression**. The
   unstated problem `CurrentAttributes` supposedly causes is never named, and it is already solving
   the precise hazards the proposal then has to re-solve by hand (Puma thread reuse, test leakage,
   aborted/streamed requests).

## What Is Sound

- **Separating `transport` (cookie/bearer/none) from `channel` (browser/native/server).** This is
  the strongest idea. Today these are computed ad hoc via `AuthAuthorizationHeader.scheme` and
  `core_browser_api_boundary.rb`. Promoting them to first-class _resolved_ fields is a real
  improvement and is ADR-compatible (the ADR removes `surface`/`domain`/`session`/`token`, but says
  nothing against new resolved axes).
- **Keeping the context an immutable value object** matches the established pattern: the existing
  `Actor::Context`, `Actor::Authz`, and `Actor::StepUp` already use `Data.define`, and
  `Actor::Authentication` already freezes `access_claims` recursively.
- **Anonymous as a dedicated null object** is already how it works (`Unauthenticated.instance`), and
  it is better than `subject: nil`. The proposal's instinct to question `subject: nil` is correct —
  keep the null object.
- **Guaranteed reset in `ensure`** is already implemented as
  `prepend_around_action :with_actor_lifecycle` → `ensure Actor.clear`. The direction is right; the
  proposal just weakens it (see Blocking #4).
- **`Actor.authenticated?` as a read-only _type_ predicate** (not enforcement) is fine and already
  exists; it does not mix in authorization.

## Blocking Issues

### B1. Resolution has no home → forced god object (proves two-file is unsafe)

`build_context` must decode/verify a JWT, look up Client/Operator/Visitor, resolve preferences from
the Preference JWT plus `lx`/`ct`/`tz` overlay, resolve step-up via `StepUpResolver`, and resolve
surface from host. With concerns/services/resolvers forbidden, all of that lands inside `Actor`.
That is a god object that does I/O, token crypto, and DB lookups from a model class — unreviewable
and untestable in isolation. **The two-file design is unsafe for resolution.** Smallest alternative
is in "Recommended Minimal Implementation Shape" below.

### B2. Removing `CurrentAttributes` is an unjustified safety regression

`CurrentAttributes` already provides, for free, every isolation property the proposal then
re-implements manually:

- **Puma thread reuse:** Rails' executor resets `CurrentAttributes` at request boundaries regardless
  of whether your `ensure` ran. Raw `RequestStore.store` leaks across requests on a reused thread
  unless `RequestStore::Middleware` is correctly inserted — a cross-tenant identity leak if
  misconfigured. The current `resets do self.context = Context.empty end` is the safe default.
- **Test isolation:** Rails resets `CurrentAttributes` around each test and around each ActiveJob
  execution. `RequestStore` does not; you must teardown by hand in every test, and the 41 files /
  124 call sites currently rely on the automatic reset.
- **Aborted/streamed requests:** executor reset still fires; an `ensure`-only model does not. The
  proposal does not state what problem `CurrentAttributes` causes. Absent that, this is change for
  its own sake that deletes a working safety net.

### B3. `Actor.current` raising `MissingRequestContext` breaks existing safe-degradation

Today `Actor.context` falls back to `Context.empty` and every reader returns a `::NULL` value
object, so off-request reads degrade gracefully. Real call sites depend on this:

- `app/services/analytics_consent_guard.rb` default arg `preference: Actor.preferences`
- `app/helpers/sign/common_helper.rb` reads `Actor.preferences.date_format`
- `app/policies/application_policy.rb#current_token` → `Actor.authz.token_claims` Switching to
  "raise when unbound" turns any partial/helper/policy read outside a bound request (and any
  `BareController` path that transitively touches a shared partial) into a 500. **Return
  anonymous/empty context; do not raise.**

### B4. Re-introducing `Actor.surface` / `Actor.session` / `Actor.token` violates an accepted ADR

`adr/actor-current-facade.md` removes these _by name_ and forbids restoring them. The proposal
restores `surface` and `session` and adds a raw `claims`/`credential` surface. Either drop them or
write a superseding ADR first. Silently overriding accepted decision material is exactly what
AGENTS.md says to stop and flag.

### B5. `surface` conflates two orthogonal existing axes and loses information

The proposal's `surface` enum (`:acme, :sign, :core, :base, :palm, :help, :docs, :news`) lists
**services/engines**, but `Actor.tld` today carries the **user-facing boundary**
(`:app, :com, :org, :net, :dev`, from `CoreSurface.detect` on the host subdomain). These are
independent: a request is _both_ `core` (engine) _and_ `app` (tld). Collapsing them into one
`surface` field destroys the tld, which is load-bearing for policy/audience checks
(`application_policy.rb#domain_app?/org?/com?`, audience scoping) and for surface-boundary
enforcement. If a service axis is wanted, add it as a **new** field; do not overwrite `tld`.

### B6. `bind_request!(request)` is the wrong shape (pulls resolution into the model)

The existing writer API is **eager push of a built snapshot** (`install_context!(**value_objects)`
from `actor_support.rb`). The proposed `bind_request!(request)` stores the **raw request** and
defers a lazy `build_context` — which is the mechanism that forces B1's god object. These are not
aliases; they are opposite data-flow models. Keep eager push of pre-built value objects.

## Non-blocking Risks

- **Flattening the value objects into one `ActorValuesContext` is a cohesion regression.** The
  proposal's `claims`/`scopes`/`authn`/`authz`/`step_up`/`configuration`/`preferences`/`selection`
  fields duplicate today's cohesive sub-objects (`claims`/`scopes` already live inside
  `Actor::Authentication#access_claims` and `Actor::Authz#token_claims`). Flattening also discards
  the per-object `::NULL` null-object pattern that makes off-request reads safe. Compose the
  existing value objects; don't inline them.
- **`Actor.operator?` substituting for authorization.** `Actor.operator?` answers _actor type_
  (authentication); `authorize!`/ActionPolicy answers _may they do X_. `if Actor.operator?` as an
  access gate silently bypasses `application_policy.rb`. Allowed for display/type-branching; must
  not replace policy. Needs a documented rule (ideally a lint).
- **Bang readers (`Actor.subject!`, `Actor.session!`, `Actor.tenant!`).** Unnecessary given the
  null-object model — they re-introduce scattered nil/raise handling the `::NULL` objects exist to
  remove. Do not add.
- **`browser?`/`native?` wired to transport instead of channel.** A native webview can carry
  cookies; a BFF carries a bearer but is `server`, not `native`. Wire
  `browser?`⟸`channel==:browser`, `native?`⟸`channel==:native`, `cookie?`⟸`transport==:cookie`,
  `bearer?`⟸`transport==:bearer`. The proposal's instinct to keep the axes separate is right; the
  predicates must honor it.
- **Stale context after mid-request credential revocation.** With an immutable snapshot the fix is
  re-install a fresh context (as `authentication_logoutable.rb` / `finisher.rb` already do via
  `Actor.clear`), not mutate in place. Preserve a mid-request reset path.
- **`app/values` autoload.** `app/values` is not a default Rails autoload path in this repo today
  (value objects currently live under `app/models/actor/`). Placing `ActorValuesContext` in
  `app/values` requires confirming the autoload/eager-load config or it will be a boot-time
  `NameError` only under eager load (production), not in dev.

## Recommended Minimal Implementation Shape

If the team wants the _genuine_ wins (transport/channel) without the regressions, the smallest safe
shape is **not** two files and **not** `RequestStore`:

1. **Keep `Actor < ActiveSupport::CurrentAttributes`** storing one immutable snapshot. Unchanged
   from today; do not remove the safety net.
2. **Keep the facade pure.** `Actor` only reads/writes the snapshot. No request object, no
   `build_context`, no I/O inside `Actor`. This is the only god-object guardrail that actually
   holds.
3. **Keep the controller-boundary installer** (`actor_support.rb` or equivalent) as the _one_ place
   that resolves and calls `Actor.install_context!(...)` with pre-built value objects. This is the
   "resolver/installer" the ADR already sanctions — it is not a new abstraction.
4. **Keep the layered value objects** (`Actor::Authentication`, `Actor::Authz`, `Actor::Preference`,
   `Actor::StepUp`, `Actor::SelectedContext`, `Actor::Configuration`) with their `::NULL` objects.
   If a unified `ActorValuesContext` is desired, make it a `Data.define` that **composes** these,
   not one that flattens them.
5. **Add only what is new:** `transport` (`:cookie/:bearer/:none/:unknown`) and `channel`
   (`:browser/:native/:server/:unknown`) as resolved snapshot fields, plus `Actor.transport`,
   `Actor.channel`, and the four predicates wired as above.
6. **Do not rename existing readers.** Keep `Actor.tld`, `Actor.authn.login_public_id`,
   `Actor.authz.policy_user`, `Actor.whoami`. If `subject`/`session`/`surface` vocabulary is truly
   wanted, write a superseding ADR first, then mechanically migrate all 124 sites in a dedicated
   change.

This touches ~2 files for the new behavior (the value object(s) and the installer) plus predicate
additions on the facade — a smaller, safer delta than the proposed rewrite, with zero ADR conflict.

## Required Guardrails

- **Facade purity rule:** `Actor` may not reference `request`, decode tokens, or hit the DB.
  Resolution lives only in the controller-boundary installer.
- **No raise on unbound:** `Actor.current`/readers return the empty/anonymous snapshot off-request
  (jobs, mailers, model callbacks, tests, `BareController`). Optionally add `Actor.bound?` as a
  _non-raising_ predicate for code that wants to branch.
- **Authorization stays in policy:** ban `Actor.operator?`/`Actor.client?` as access gates; require
  `authorize!`. Document and, if possible, lint.
- **Reset is `prepend_around_action` + executor:** keep both the explicit `ensure` reset and the
  `CurrentAttributes` `resets do … end`; never rely on `ensure` alone.
- **Axis integrity:** `transport` ≠ `channel`; never derive `browser?`/`native?` from transport.
- **Deep-freeze nested claims/scopes** (follow `Actor::Authentication`'s recursive freeze).
- **ADR discipline:** any reuse of `surface`/`session`/`token`/`domain` names requires a superseding
  ADR, not an alias.

## Existing Code That Must Be Overridden Or Preserved

**Must be preserved (load-bearing; breaking these breaks the app):**

- `app/models/actor.rb` — `CurrentAttributes` backing + `Context.empty` fallback +
  `install_context!`/`clear`.
- `app/models/actor/{authentication,authz,preference,step_up,selected_context,configuration}.rb` —
  value objects with `::NULL`. `application_policy.rb` reads
  `Actor.authz.token_claims`/`policy_user`; `sign_in/sequence_policy.rb` reads `Actor.tld`.
- `app/controllers/concerns/actor_support.rb` — the installer the ADR mandates. Resolution must stay
  here.
- `app/services/host_context_resolver.rb`, `app/services/step_up_resolver.rb` — actual resolution
  logic.
- `Actor.tld` (not `surface`), `Actor.authn.login_public_id` (not `session`), `Actor.whoami`,
  `Actor.authz.*` — pinned by the accepted ADR and read across 124 sites / 41 files.
- `BareController` inheriting `ActionController::Base` and **not** binding Actor; health/robots
  controllers rely on Actor-free operation.

**May be overridden / added (with an ADR addendum for renames):**

- Add resolved `transport` + `channel` fields and predicates (no ADR conflict).
- `install_context!`/`clear` may _alias_ to `reset!` for ergonomics; do **not** replace the
  eager-push model with lazy `bind_request!(request)`.
- The `# FIXME: cofniguration … cleaned up` note in `actor.rb` is a legitimate, separate cleanup.

**Likely call sites to break under the literal proposal:** all readers of `Actor.tld`,
`Actor.authn.*`, `Actor.authz.*`, `Actor.preferences` — i.e. `application_policy.rb`,
`sign_in/sequence_policy.rb`, `actor_support.rb`,
`authentication_*`/`preference_*`/`core_browser_api_boundary.rb` concerns, `sign/common_helper.rb`,
`analytics_consent_guard.rb`. A `surface`/`session`/`subject` rename is a 124-site break and must be
a deliberate, ADR-backed migration — never a side effect.

## Open Questions

1. **What concrete defect does `CurrentAttributes` cause?** No problem is stated. Without one, B2
   stands and the removal should be dropped.
2. **Is the accepted ADR being superseded?** If yes, a new ADR must land _first_ (per AGENTS.md
   conflict-handling). If no, `surface`/`session`/`token` are off the table.
3. **Service axis vs tld:** is a `:core/:sign/:acme/:palm` axis actually needed at the Actor layer,
   or is it already implied by the controller tree? If needed, it is a _new_ field, not a rename of
   `tld`.
4. **`app/values` autoload:** confirmed in `config/application.rb` eager-load paths, or do value
   objects stay under `app/models/actor/`?
5. **Migration mode:** the strict recommendation is a **compatibility bridge keeping the current
   API**, adding only transport/channel. Does the team accept that, or insist on a hard rename
   (which then requires Q2 + a one-shot 124-site migration)?
