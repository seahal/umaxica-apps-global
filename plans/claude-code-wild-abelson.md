# Actor Interface Review

> Review task only. No code changed. No files created beyond this report (the plan-file is the only
> writable surface in plan mode). Findings are grounded in the current `develop` tree.

## Verdict

**FAIL** (as literally specified). The _interface vocabulary_ is largely salvageable, but the
proposed file layout, constant names, and three of the Hard Constraints contradict a substantial,
already-shipped `Actor` subsystem. Implementing the proposal verbatim would collide with existing
constants and silently fork a 76-call-site source of truth. It becomes **PASS WITH CHANGES** only if
reframed as "evolve the existing `Actor`", not "introduce a new `Actor`".

## Executive Summary

The proposal is written as if `Actor` were a greenfield concept. It is not.

- `app/models/actor.rb` **already exists** and is `class Actor < ActiveSupport::CurrentAttributes`.
- `Actor::Context` **already exists** as an immutable `Data.define` value object — i.e. the exact
  role the proposal assigns to the new `ActorValuesContext`.
- A populated namespace `app/models/actor/` already exists (`authentication`, `authz`,
  `configuration`, `preference`, `selected_context`, `step_up`).
- `Actor` is referenced in ~76 files and bound/cleared via `Actor.install_context!` / `Actor.clear`
  across many controller concerns (`actor_support`, `authentication_base`,
  `core_browser_api_boundary`, `finisher`, `verification_base`, etc.).

Three Hard Constraints directly contradict this reality:

- **HC6** "Do not use `Current.actor` as source of truth" / **HC7** "Do not make `Actor` a
  process-global singleton" — the _current_ `Actor` **is** a `CurrentAttributes` singleton and
  **is** the source of truth. The proposal cannot both honor HC6/HC7 and reuse the name `Actor`
  without rewriting the existing subsystem.
- The scope list forbids creating `Actor::Context` and `Actor::Resolver`. `Actor::Context` **already
  exists**. Forbidding a construct that already ships is incoherent; the review cannot "stay flat"
  by avoiding it.

So the real decision the proposal hides is: **replace** the existing `CurrentAttributes`-based
`Actor`, or **wrap/rename** it. That decision must be made before any of the per-question critiques
matter. Everything below assumes it gets surfaced.

## Confirmed Good Decisions

- **Facade + immutable value object split is correct** — and already partially realized (`Actor`
  class methods delegating to an immutable `Actor::Context`). The proposal's instinct matches the
  codebase's existing grain.
- **`request_store` (1.7.0) is present** in `Gemfile.lock`, so `ActorRequestStore` has a real
  backing if that path is chosen.
- **Flat Zeitwerk layout is valid.** `app/values/` and `app/stores/` autoload as root namespaces
  (Rails autoloads every `app/*` dir except `assets`/`javascript`/`views`).
  `app/values/actor_values_context.rb -> ActorValuesContext` and
  `app/stores/actor_request_store.rb -> ActorRequestStore` resolve correctly. `app/values/` already
  exists (only `.keep`); `app/stores/` is new but fine. **No need for nested `Actor::Resolver` /
  `ActorStores::RequestStore` on autoload grounds** — flat is safe here.
- **Lazy / request-local intent is sound** and matches HC8/HC9 goals.
- **Predicate vocabulary partially already exists and matches**: `operator?`, `client?`, `visitor?`,
  `authenticated?`, `anonymous?` are already defined on the current `Actor` with the same meanings.
  Reusing them is low-risk.

## Blocking Issues

1. **Constant collision / unacknowledged rewrite (B1).** `app/models/actor.rb -> Actor` already
   exists. The proposal must explicitly state it is _replacing_ the `CurrentAttributes`
   implementation, and own the migration of ~76 call sites and ~17 `install_context!`/`clear`
   binding sites. As written it reads like a parallel definition, which is impossible (same
   constant) or a silent breaking rewrite.

2. **`ActorValuesContext` duplicates `Actor::Context` (B2).** The codebase already has the immutable
   value object. Introducing a second, differently-named one with a _narrower_ field set
   (`subject/tenant/session/credential/surface/transport/claims/scopes`) drops fields the app
   actively depends on: `actor_type`, `authn`, `authz`, `configuration`, `preferences`, `selection`,
   `step_up`, `trace_id`, `span_id`. Either the new value object must absorb those, or the proposal
   is a data-loss regression. The scope list's ban on `Actor::Context` is therefore unworkable.

3. **HC6/HC7 are unsatisfiable under the chosen name without a full cutover (B3).** If `Actor` must
   stop being a `CurrentAttributes` singleton, every `Actor.install_context!`, `Actor.clear`,
   `Actor.tld`, `Actor.authz.policy_user`, `Actor.preferences.cookie`, etc. changes semantics. That
   is a cross-surface auth-adjacent migration, not an "interface review" deliverable. The constraint
   and the scope are in tension.

4. **`reset!` vs RequestStore-wide clear (B4).** The app currently relies on `CurrentAttributes`
   auto-reset per request (Rails executor) plus explicit `Actor.clear` at logout/boundary crossings
   (`core_browser_api_boundary`, `authentication_logoutable`). A new `ActorRequestStore` introduces
   a _second_ lifecycle. If `Actor.reset!` clears the whole `RequestStore.store`, it can wipe
   unrelated request-local state owned by other code; if it clears only actor keys, the two reset
   mechanisms can drift. The reset contract must be defined as "actor-namespaced keys only" and
   reconciled with the existing per-request executor reset. **Must block** until specified.

5. **`surface`/`transport`/`browser?`/`native?`/`cookie?`/`bearer?` are new dimensions with no
   existing source (B5).** Today surface lives as `Actor.tld` and transport is implied by the
   controller concern (cookie vs bearer vs Core BFF). The proposal introduces them as first-class
   fields but does not say who populates them or how `tld` maps to `surface`. Without that,
   `browser?`/`native?` etc. are undefined behavior. This is the one genuinely new and useful part
   of the proposal — but it is unspecified, so it blocks.

## Non-blocking Risks

- **`browser? == cookie?` and `native? == bearer?` conflation.** Device/agent and
  credential-transport are two axes. Core BFF is explicitly "Rails-owned browser cookie, Next.js
  must not receive user credential" — a browser request whose transport, from the Rails app's view,
  is still cookie, but where the _downstream_ caller is Next.js. Collapsing browser/native onto
  cookie/bearer will misclassify Core. Keep transport and channel as separate dimensions; derive
  `browser?` from channel, not from `cookie?`.
- **`subject` rename vs existing `actor`/`account`.** The current model distinguishes `actor` (the
  principal object, defaulting to `Unauthenticated.instance`) from `account`. The proposal's single
  `subject` flattens this. Risk of losing the actor/account distinction that `actor_type`,
  preference association resolution, and policy_user rely on.
- **Forcing construction on every predicate.** If `Actor.operator?` forces full `build_context`
  (which today runs token decode, step-up resolution, preference JWT hydration, selection resolution
  — see `actor_support.rb`), public endpoints pay auth cost merely by asking a cheap question. Need
  a non-forcing `bound?`/`resolved?` and a cheap-path for type predicates.
- **`claims`/`scopes` deep-freeze.** Nested hashes from JWT payloads must be deep-frozen or the
  "immutable value object" guarantee is cosmetic. Today `Actor::Authentication` holds
  `access_claims` as a plain hash — already a latent mutability hole.
- **`if Actor.operator?` as authorization.** Exposing global type predicates invites policy bypass
  (`if Actor.operator?` instead of Pundit/ActionPolicy). The codebase already routes policy through
  `Actor.authz.policy_user` / `current_policy_user`. New predicates widen the bypass surface.
- **Background jobs / mailers / model callbacks** calling `Actor.current` — must return
  anonymous/raise deterministically, never silently inherit a leaked thread-local.

## Recommended Minimal Design

Do **not** introduce a parallel `Actor`. Evolve what exists.

```
app/models/actor.rb            # KEEP. Stays the facade (class methods delegating
                               # to an immutable context). Decide explicitly
                               # whether it remains CurrentAttributes-backed or
                               # moves to a RequestStore-backed store.
app/models/actor/context.rb    # PROMOTE existing inline Actor::Context Data
                               # object to its own file; it already IS the
                               # immutable value object the proposal wants.
                               # (Do NOT create app/values/actor_values_context.rb —
                               #  it duplicates this.)
```

If, and only if, HC6/HC7 (drop the `CurrentAttributes` singleton) are a hard product requirement:

```
app/stores/actor_request_store.rb   -> ActorRequestStore  # RequestStore-backed,
                                                           # actor-namespaced keys only
```

…and treat it as a **migration project** with its own plan, not an interface review: swap `Actor`'s
storage from `CurrentAttributes` to `ActorRequestStore` behind the _unchanged_ public API, keep
`Actor::Context` as the value object, and add the new `surface`/`transport`/channel fields to that
context. The ~76 call sites and ~17 binding sites stay working because the facade API is preserved.

New dimensions to add to the existing context (the actually-novel, worthwhile part): `surface` (from
existing `tld`), `transport` (`:cookie`/`:bearer`), `channel` (`:browser`/`:native`) as a _separate_
axis from transport.

## Guardrails

- `Actor` is request-local read-facade only. No business logic, no AR table, no service-object role.
  (Matches HC1–HC5.)
- Public API is the **only** way in; `bind_request!`/`install_context!`/`reset!`/`clear` are
  controller-lifecycle-internal — keep them out of models, jobs, mailers, views.
- `reset!`/`clear` clears **actor-namespaced keys only**, never the whole `RequestStore.store`.
- Exactly one binding mechanism. Do not run a `RequestStore` reset and a `CurrentAttributes`
  executor reset against the same data — pick one backing store.
- Type predicates (`operator?` etc.) must **not** be used as authorization. Authorization stays on
  Pundit/ActionPolicy via `current_policy_user` / `Actor.authz.policy_user`. Add a lint/review rule
  against `if Actor.operator?` guarding privileged actions.
- `claims`/`scopes` deep-frozen at context construction.
- `Actor.current` outside a bound request returns the **anonymous/empty** context (mirrors today's
  `Context.empty`), never raises and never returns leaked state. `BareController` stays free of
  `Actor` unless a concrete need appears (HC10).
- Channel (`browser?`/`native?`) is derived from a `channel` field, not from transport
  (`cookie?`/`bearer?`); Core BFF must classify correctly.
- New `surface`/`transport`/`channel` fields are populated only in the controller lifecycle
  (`actor_support`-equivalent), never lazily from deep auth work triggered by a predicate.

## Open Questions (truly blocking)

1. **Replace or rename?** Is this proposal meant to _replace_ the existing
   `Actor < ActiveSupport::CurrentAttributes`, or did it assume `Actor` was unused? This single
   answer determines whether it is an interface tweak or a cross-surface migration. (Strong
   recommendation: replace storage behind the existing API; do not add a second `Actor`.)
2. **Are HC6/HC7 (drop the CurrentAttributes singleton) a real requirement, or aspirational?** If
   real, the deliverable is a migration plan, not an interface review, and the ~76 call sites must
   be scoped.
3. **Field set:** must the new context retain
   `authn/authz/configuration/preferences/selection/step_up/trace_id/span_id`? (It must, unless
   those are being relocated — otherwise B2 is a regression.)
4. **Who owns `Actor.reset!`'s scope** relative to the existing per-request executor reset and the
   explicit `Actor.clear` at auth boundaries?

```

```
