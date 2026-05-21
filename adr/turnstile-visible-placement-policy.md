# Turnstile Visible Placement Policy

Status: Accepted

Date: 2026-05-21

## Context

Cloudflare Turnstile has two application-level presentation patterns:

- visible Turnstile for public browser entry points where an explicit challenge is acceptable;
- stealth Turnstile for signed-in or already-authenticated flows where the product should avoid
  adding visible friction.

The sign surfaces have several public-looking routes that should not all receive visible Turnstile.
Some are delegated to external identity providers, some are machine-facing unsubscribe endpoints
without a screen, and passkey sign-in has its own WebAuthn interaction model.

Without a placement policy, implementation reviews tend to debate each route independently and can
accidentally add Turnstile to the wrong layer.

## Decision

Use visible Turnstile on browser-rendered external-to-internal entry forms that submit directly to
this application and create, resume, verify, or mutate sign-up, sign-in, invitation, or external
email-preference state.

Do not add Turnstile to social login entry or callback routes for app Google, app Apple, or org
Google. Those flows are delegated to the external identity provider's authentication and abuse
controls. This applies to both `continue` routes and OmniAuth callback routes.

Do not add Turnstile to `POST /preference/email/:id`. That endpoint exists for List-Unsubscribe
style mail-client behavior, including clients such as Gmail where no application-rendered screen is
available. The normal user experience must use the browser-rendered unsubscribe confirmation page
instead.

Do not use visible Turnstile for passkey sign-in. Passkey sign-in uses the passkey/WebAuthn flow and
the stealth Turnstile path where Turnstile is required.

Sign-up checkpoint credential setup remains covered by
`adr/sign-up-checkpoint-turnstile-boundary.md`: checkpoint `birthdate`, `passcode`, and `passkey`
actions do not need additional Turnstile when they are reachable only through a valid
Turnstile-protected sign-up sequence.

## Consequences

Visible Turnstile placement reviews should begin with the route category rather than the controller
name. A route is a visible candidate only when this application renders the form and receives the
browser-submitted mutation.

Social login must rely on provider state validation, callback validation, account-linking policy,
and provider-side abuse controls instead of adding Turnstile at the local redirect boundary.

External email unsubscribe has two separate paths:

- browser confirmation page: visible Turnstile belongs on the form and server-side validation
  belongs on the destructive action;
- List-Unsubscribe POST endpoint: no Turnstile and not part of the normal product UI.

Documentation must keep the current visible placement table explicit so implementation work can be
checked before routes or controllers are changed.

## Related

- `docs/security/turnstile.md`
- `adr/sign-up-checkpoint-turnstile-boundary.md`
- `adr/sign-up-authentication-handoff-and-social-rt.md`
