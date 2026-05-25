# Controller Boundary Exception Retirement

## Status

Historical. Superseded by `plans/active/controller-boundary-lifecycle-unification.md`, which was
itself deprecated by the 2026-05-24 emergency controller-boundary direction.

This file remains as historical exception inventory only. Do not use it as the active plan, and do
not use it to justify four-way controller inheritance.

## Context

`adr/static-and-guest-controller-boundaries.md` used to define four semantic controller boundaries:
`OpenController`, `BareController`, `PrivateController`, and `GuestController`. That ADR is now
deprecated.

Most controllers should move directly to one of those bases. A small set of security-sensitive
controllers is intentionally left out of the immediate migration because their current behavior is
not described by plain authentication presence alone. They combine the four base meanings with
protocol state, pending login state, restricted-session state, client authentication, DBSC, or
selective preference/cookie pipeline behavior.

Keeping these controllers as undocumented one-off implementations would make the access model harder
to audit. The intent of this plan is to retire the exception bucket by introducing named derivative
bases under the four accepted boundaries.

## Non-Goal

Do not introduce a fifth semantic boundary. Each exception must resolve to one of:

- `OpenController`
- `BareController`
- `PrivateController`
- `GuestController`

Derivative bases are allowed only to encode additional guard state within one of those four
contracts.

## Exception Inventory

### Social Authentication Entry And Unlink

Current shape:

- `app/controllers/sign/app/social/authentications_controller.rb`
- `app/controllers/sign/org/social/authentications_controller.rb`

Why it is exceptional:

- `continue` and `start` are open entry actions.
- `destroy` is private and requires step-up verification.

Target:

- Split open entry actions from private unlink actions, or move unlink to a private configuration
  controller.
- The open entry controller should derive from `OpenController`.
- The unlink controller should derive from `PrivateController`.

### Session-Limit Gate

Current shape:

- `app/controllers/sign/app/in/sessions_controller.rb`
- `app/controllers/sign/com/in/sessions_controller.rb`
- `app/controllers/sign/org/in/sessions_controller.rb`

Why it is exceptional:

- The route is open at the access-policy level.
- A request is valid only when it has a restricted session or a valid pending session-limit gate.
- Ordinary signed-in sessions are rejected.

Target:

- Add a surface-local `SessionGateController` derivative of `OpenController`.
- Keep the pending gate and restricted-session checks inside that derivative or a narrowly included
  concern.

### OAuth And OIDC Callbacks

Current shape:

- `app/controllers/sign/app/auth/omniauth_callbacks_controller.rb`
- `app/controllers/sign/org/auth/omniauth_callbacks_controller.rb`
- controllers including `app/controllers/concerns/oidc/callback.rb`

Why it is exceptional:

- The endpoint is open to provider callbacks.
- The actual guard is provider state, callback guard validation, PKCE verifier, nonce, and session
  state.

Target:

- Add an `OpenCallbackController` derivative of `OpenController`, or keep the guard concern but make
  the including controllers inherit from the appropriate open derivative.
- Preserve CSRF and callback guard behavior before changing inheritance.

### OAuth Token Exchange

Current shape:

- `app/controllers/sign/app/tokens_controller.rb`
- `app/controllers/sign/com/tokens_controller.rb`
- `app/controllers/sign/org/tokens_controller.rb`

Why it is exceptional:

- The endpoint does not authenticate a browser actor.
- CSRF uses `null_session`.
- The protocol authenticates clients through OAuth/OIDC parameters and token exchange validation.

Target:

- Add a `BareTokenController` or equivalent derivative of `BareController`.
- Keep token endpoint rate limiting, `null_session`, no-store response headers, and client
  authentication validation explicit.

### Edge Token, DBSC, And Preference Endpoints

Current shape:

- `app/controllers/sign/*/edge/v0/token/*_controller.rb`
- `app/controllers/apex/*/edge/v0/cookies_controller.rb`
- `app/controllers/apex/*/edge/v0/dbsc_controller.rb`
- controllers including `app/controllers/concerns/preference/edge.rb`

Why it is exceptional:

- The endpoints are open but use selected parts of token, cookie, DBSC, and preference state.
- They intentionally skip unrelated localization, preference-cookie setup, verification, or
  transparent refresh callbacks.

Target:

- Add surface-local `OpenEdgeController` / `PreferenceEdgeController` derivatives of
  `OpenController`.
- Centralize the intentional callback omissions in those derivative bases.
- Keep DBSC challenge and refresh-token behavior covered by narrow controller/request tests.

## Guardrails

- Do not move an exception controller to `BareController` if it reads actor, session, preference, or
  token state from the application authentication pipeline.
- Do not keep endpoint-local `public_strict!`, `auth_required!`, or `guest_only!` as the final
  expression of the boundary.
- Do not remove CSRF, callback, state, nonce, DPoP, DBSC, session-limit, or step-up checks while
  changing inheritance.
- Do not mix `app`, `com`, and `org` behavior into one shared controller unless the existing code
  already exposes a safe shared concern.
- Add or update focused tests before retiring each exception.

## Done Criteria

- Every controller in the exception inventory inherits from one of the four semantic bases or a
  named derivative of one of them.
- No exception remains on `ApplicationController` solely because its boundary is unclear.
- The docs in `docs/architecture/controller-boundaries.md` match the implemented derivative bases.
- The ADR exception list is either empty or points to a current follow-up plan.

## References

- `adr/static-and-guest-controller-boundaries.md`
- `docs/architecture/controller-boundaries.md`
