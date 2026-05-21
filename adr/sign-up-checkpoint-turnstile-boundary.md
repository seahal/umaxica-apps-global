# Sign-Up Checkpoint Turnstile Boundary

Status: Accepted

Date: 2026-05-21

## Context

The sign-up surfaces use Cloudflare Turnstile at external entry points where an anonymous browser
moves from outside the system into a sign-up or sign-in flow. This includes contact submission and
other first-step entry forms that create or resume a sign-up sequence.

The planned sign-up checkpoint routes are different:

```ruby
namespace :checkpoint do
  resource :birthdate, only: :update
  resource :passcode, only: %i(new create)
  resource :passkey, only: %i(new create) do
    post :begin, on: :member
  end
end
```

These routes are not independent public entry points. They are later steps in a sign-up sequence
after the actor has already entered through a Turnstile-protected sign-up path, such as email,
telephone, or an approved social sign-up entry. The checkpoint owns pending-registration
requirements before durable account finalization, including birthdate collection, passkey
registration, and sign-in-capable passcode setup.

Adding another Turnstile requirement to every checkpoint credential setup would duplicate the entry
check without addressing the actual risk. The important boundary is whether the checkpoint action is
reachable only through a valid pending sign-up sequence.

## Decision

Do not require an additional Turnstile challenge on sign-up checkpoint `birthdate`, `passcode`, or
`passkey` actions solely because those actions collect registration data or create sign-in-capable
credentials.

Turnstile remains required at the external sign-up entry point before the sequence is created,
resumed, or advanced from anonymous contact/social input into pending registration.

Checkpoint actions must reject direct access unless all sequence gates are present and valid:

- a valid pending sign-up ticket, session, or equivalent sequence authority;
- the expected pending actor/contact state for the current surface;
- an outstanding checkpoint requirement that authorizes the requested action;
- no durable account finalization before required checkpoint items are cleared.

If a future route allows checkpoint `birthdate`, `passcode`, or `passkey` actions to be reached
directly, or from a path that did not pass through a Turnstile-protected sign-up entry, this
decision does not apply. That route must either add server-side Turnstile validation or introduce
another explicit anti-automation gate before the checkpoint mutation.

This decision does not apply to signed-in configuration management. Ordinary credential
registration, update, and deletion routes under configuration remain separate from sign-up
checkpoint setup and must follow the current step-up and Turnstile policy for their surface.

## Consequences

Reviews of checkpoint routes should focus on sequence gating, requirement authorization, and direct
access rejection instead of adding redundant Turnstile widgets to every checkpoint form.

Tests for checkpoint setup should cover both the valid sequence path and direct access without the
required pending sign-up authority.

The implementation may share checkpoint setup components across `app` and `com`, but each surface
must keep its own controller, route, session, and policy boundary unless an existing explicit shared
abstraction applies.

## Related

- `docs/security/turnstile.md`
- `docs/security/sign-up-sequence.md`
- `adr/sign-up-authentication-handoff-and-social-rt.md`
- `adr/authentication-assurance-level-boundaries.md`
