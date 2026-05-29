# Jumper Current Jump Plan

## Status

Completed (2026-05-07).

> **Completion notes (2026-05-07):**
>
> - `Jumper < ActiveSupport::CurrentAttributes` exists at `app/models/jumper.rb` with exactly the
>   three intended attributes (`actor`, `actor_type`, `domain`). It does not carry `session`,
>   `token`, `preference`, `trace_id`, or `span_id`.
> - The shared actor concern lives at `app/models/concerns/current_actor.rb` as `CurrentActor` and
>   is included by both `Current` (`app/models/current.rb`) and `Jumper`. It provides `actor` /
>   `actor_type` defaults plus the `user?` / `staff?` / `customer?` / `unauthenticated?` /
>   `authenticated?` predicates and the `user` / `staff` / `customer` accessors.
> - `Jump::ApplicationController` (`app/controllers/jump/application_controller.rb`) inherits from
>   `ActionController::Base` rather than the project's root `ApplicationController`. This is a
>   deliberate deviation from the plan wording: the root `ApplicationController` is itself just
>   `ActionController::Base + protect_from_forgery`, so inheriting from `ActionController::Base`
>   directly produces an equivalent but leaner class with the jump-only includes (`::RateLimit`,
>   `::Session`, `::Finisher`).
> - The plan said `Jump::ApplicationController` should NOT include `CurrentSupport`. The
>   implementation honors this. The reset side of what `CurrentSupport` would have done is handled
>   by `after_action :purge_current` from `::Finisher` (`app/controllers/concerns/finisher.rb:7-9`),
>   which calls `Current.reset` — equivalent to the `_reset_current_state` callback `CurrentSupport`
>   would have installed, but without dragging in the rest of the `Current` population pipeline.
> - All six jump controllers inherit from the appropriate base: `Jump::App::RootsController`,
>   `Jump::Com::RootsController`, `Jump::Org::RootsController` inherit from
>   `Jump::ApplicationController`; the three `Jump::*::HealthsController` classes inherit from
>   `Jump::PublicController`, which is intentional — public health endpoints should not run the
>   jumper lifecycle.
> - Unit tests at `test/models/jumper_test.rb` cover default actor, actor predicates, accessors,
>   `Jumper.reset` clearing only `Jumper`, and `ActiveSupport::CurrentAttributes.clear_all` clearing
>   both. Integration tests at `test/integration/jump_lifecycle_test.rb` cover per-host jumper
>   domain handling, post-response reset, redirect success, redirect failure, and cookie-session
>   skip behavior.

**Original status:** Active draft (2026-05-06)

## Summary

Introduce `Jumper < ActiveSupport::CurrentAttributes` for the jump surface only. Do not change sign
or acme Current behavior in this pass. Share actor helper behavior through a concern so that
`Current` and `Jumper` can expose the same actor contract without inheritance.

`Jumper` is a provisional implementation name. Keep it for this pass, but keep the surface area
small so a later naming refactor can rename it together with any future sign/acme CurrentAttributes
classes.

## Scope

In:

- New `Jumper` request context for jump controllers.
- Shared actor helper concern for `Current` and `Jumper`.
- New `Jump::ApplicationController` that sets and resets `Jumper`.
- Jump controller inheritance updates.
- Unit and integration tests for `Jumper` and jump lifecycle.

Out:

- Splitting `Current` for sign or acme.
- Choosing names for future sign or acme CurrentAttributes classes.
- Moving `Current::Preference`.
- Adding token, session, preference, or observability fields to `Jumper`.
- Changing jump redirector DB behavior, allowed-host policy, public URL shape, or cookie-session
  skip behavior.

## Implementation

### 1. Shared actor concern

Add a model concern for CurrentAttributes actor behavior.

Expected behavior:

- declares or expects `actor` and `actor_type`
- default actor is `Unauthenticated.instance`
- default actor type is `:unauthenticated`
- authenticated actor types are exactly `:user`, `:staff`, and `:customer`
- exposes `user?`, `staff?`, `customer?`, `unauthenticated?`, `authenticated?`
- exposes `user`, `staff`, and `customer`, each returning `actor` only when its type matches

Update `Current` to include this concern and keep its existing attributes:

- `session`
- `token`
- `domain`
- `preference`
- `trace_id`
- `span_id`

`Current.preference` and its reset behavior must stay unchanged.

### 2. Add `Jumper`

Add `Jumper < ActiveSupport::CurrentAttributes`.

Use `Jumper` as the class name for this implementation pass. Do not create aliases or alternate
names. Do not introduce `Signature`, `Signer`, `Acmeer`, `AcmeCurrent`, `Sign::Current`, or
`Acme::Current` in this pass.

Attributes:

- `actor`
- `actor_type`
- `domain`

Include the shared actor concern.

Do not add:

- `session`
- `token`
- `preference`
- `trace_id`
- `span_id`

### 3. Add jump lifecycle

Add `Jump::ApplicationController`.

It should inherit from the root `ApplicationController` and set only the jump request context:

- before action sets `Jumper.domain = Core::Surface.current(request)`
- after action calls `Jumper.reset`

Do not include `CurrentSupport` in `Jump::ApplicationController`.

Update jump controllers to inherit from `Jump::ApplicationController`:

- `Jump::App::RootsController`
- `Jump::Com::RootsController`
- `Jump::Org::RootsController`
- `Jump::App::HealthsController`
- `Jump::Com::HealthsController`
- `Jump::Org::HealthsController`

Keep `Jump::ToRedirector` behavior unchanged, including:

- `disable_cookie_session`
- `GET /?to=:public_id`
- TLD-specific `JUMP_LINK_MODEL`
- destination allowlist validation
- `Referrer-Policy: no-referrer`
- `redirect_to(..., allow_other_host: true)`
- unavailable responses returning 404

## Tests

### Unit tests

Add `Jumper` tests:

- default actor is unauthenticated
- default actor_type is `:unauthenticated`
- user/staff/customer helpers work
- `Jumper.reset` clears `Jumper` state
- `Jumper.reset` does not clear `Current`
- `ActiveSupport::CurrentAttributes.clear_all` clears both `Current` and `Jumper`

Update existing `Current` tests only as needed for the concern extraction. They should still prove:

- existing actor helpers behave the same
- `Current.preference` defaults to `Current::Preference::NULL`
- `Current.reset` keeps the existing preference reset behavior

### Jump integration tests

Extend jump controller tests to verify lifecycle:

- app jump host sets `Jumper.domain` to `:app`
- com jump host sets `Jumper.domain` to `:com`
- org jump host sets `Jumper.domain` to `:org`
- `Jumper` is reset after the response
- existing redirect success and failure tests still pass
- cookie session skip behavior still applies

Prefer test-only controller observation over changing production responses. Do not expose `Jumper`
state in jump response bodies or headers.

## Verification

Run the focused tests:

```bash
bin/rails test test/models/current_test.rb \
               test/unit/current/current_attributes_test.rb \
               test/controllers/jump/to_controller_test.rb \
               test/controllers/jump/app \
               test/controllers/jump/com \
               test/controllers/jump/org
```

Then run the current support tests to catch accidental behavior changes:

```bash
bin/rails test test/unit/current/current_support_test.rb \
               test/controllers/concerns/current_support_included_do_test.rb
```

## Acceptance

- Jump uses `Jumper`, not `CurrentSupport`.
- Sign and acme behavior is unchanged.
- No sign or acme CurrentAttributes class is introduced.
- `Jumper` has only actor and domain request state.
- Shared actor helper behavior lives in a concern, not in a `Jumper < Current` inheritance chain.
- Existing jump redirector behavior is unchanged.
