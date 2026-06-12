# Sign Credential Gateway Surface

## Status

Accepted (2026-06-02)

> **Supersession (2026-06-12):** The target component model is now defined by
> `adr/acme-sign-core-base-port-boundary.md`. Sign is a special RP and Acme is the only IdP /
> Authorization Server. This ADR remains historical context for credential ceremony risks, but its
> `sign/id` credential-gateway ownership model is superseded where it conflicts with Sign as a
> special RP.

## Context

`adr/identity-authority-boundary.md` redefines `sign/id` as a Credential Gateway and Credential
Ceremony Zone. This ADR refines the permitted surface of that gateway.

The purpose of `sign/id` is to concentrate credential ceremonies that need fixed URLs, provider
callbacks, browser origin handling, or credential-specific security controls. It is not an IdP, an
account service, a session service, a preference service, an authorization service, or a token
service.

## Decision

`sign/id` may own credential inventory and short-lived credential ceremony state.

Allowed `sign/id` responsibilities are:

- WebAuthn/passkey registration and assertion ceremony execution;
- OTP and TOTP ceremony execution;
- social provider callback validation;
- credential enrollment ceremonies;
- credential assertion ceremonies;
- step-up credential ceremony execution;
- credential inventory needed to perform those ceremonies;
- short-lived ceremony state needed to bind challenge, purpose, audience, and transaction;
- ceremony audit records describing credential ceremony attempts and outcomes.

Prohibited `sign/id` responsibilities are:

- account lifecycle decisions, including account creation, closure, withdrawal, restoration, or
  membership lifecycle;
- social account linking decisions;
- preference writes or preference management UI;
- dashboard surfaces;
- authorization decisions for product behavior;
- user session creation, continuation, rotation, reset, revocation, listing, or display;
- refresh token family ownership;
- downstream token issuance;
- `recent_auth`, `sudo`, `last_step_up_at`, AAL freshness, or equivalent session-freshness storage.

## Ceremony Grant And Result Boundary

`sign/id` must receive an `acme/www` issued ceremony grant before executing a delegated ceremony.
The grant must be short-lived, audience-bound, purpose-bound, one-shot, and bound to an `acme/www`
transaction or session where the ceremony is session-scoped.

`sign/id` returns a signed ceremony result to `acme/www`. The result is evidence only. `acme/www`
validates the result, consumes it once, and performs any account, session, freshness, authorization,
preference, or token change.

## Audit Boundary

`sign/id` audit records are ceremony audit records only. They may record credential ceremony
attempts, provider callback validation, challenge lifecycle, ceremony result issuance, and
credential inventory changes.

`sign/id` ceremony audit records must not become the source of truth for user session freshness,
sudo state, authorization state, account lifecycle, preference state, or downstream token issuance.

## Consequences

Any ADR or implementation that treats a `sign/id` route as an application-session route must be read
as historical unless it is limited to credential ceremony execution. Fixed provider callback URLs
and WebAuthn origins justify `sign/id` ceremony routes; they do not justify moving identity
authority back to `sign/id`.

Future `sign/id` features must prove that they are credential ceremony features. If the feature
requires account lifecycle, user sessions, preferences, dashboards, authorization decisions,
downstream token issuance, or persistent step-up freshness, it belongs in `acme/www` or needs a new
ADR that explicitly changes the authority boundary.

## Related

- `adr/identity-authority-boundary.md`
- `adr/acme-session-and-token-authority.md`
- `adr/sign-prefix-routing.md`
- `adr/sign-configuration-sprint-spec.md`
- `adr/sign-up-authentication-handoff-and-social-rt.md`
- `adr/step-up-authentication-redesign.md`
