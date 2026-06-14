# Acme / Sign / Core / Base / Palm Implementation Plan

## Status

Active planning. The accepted boundary is `adr/acme-sign-core-base-port-boundary.md`.

## Summary

Implement the component split where Acme is the only IdP / Authorization Server, Sign is a special
RP, Core is the Next.js web RP/BFF, Base is the Rails foundation/control-plane subdomain, and Palm
is the native bearer-token API Resource Server.

This plan replaces older Rails-only `acme/www` versus `sign/id` authority-inversion planning where
that planning conflicts with the accepted Acme / Sign / Core / Base / Palm boundary.

Palm is the canonical native API name formerly tracked as Port. Existing filenames containing
`port` are retained for link stability until a separate rename pass is accepted.

## Implementation Changes

- Inventory current Rails routes, controllers, token services, cookie writers, and OIDC client
  configuration that still assume the older `acme/www` or `sign/id` authority model.
- Define Acme issuer, JWKS, `/authorize`, and `/token` behavior as the only token authority.
- Register client and audience names: `sign-rp`, `core-next-rp`, `base-rails-rp`, `app-ios-rp`,
  `app-android-rp`, and `palm-api`.
- Keep Core browser credential cookies host-only without `Domain=`. Follow
  `adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md` for the current Rails
  Core cookie-carried JWT and Next.js zero-cookie contract.
- Split old Core responsibilities into Core, Base, and Palm:
  - Core: Next.js web experience and BFF.
  - Base: Rails foundation/control-plane views and APIs.
  - Palm: native bearer-token API surface.
- Keep browser bearer tokens server-side in Core; do not expose them to browser JavaScript.
- Make Base APIs validate appropriate server-side access credentials instead of trusting Core
  cookies or Rails browser sessions.
- Make Palm validate Acme-issued Access Tokens with `aud = palm-api` and never depend on Rails or
  Next.js sessions.
- Do not decide Palm's concrete native implementation flow until native app registration, provider
  console settings, and external documentation are checked.
- Keep Palm-specific device credential, token binding, refresh transport, and session transport APIs
  out of OAuth/OIDC endpoint namespaces. Use API namespaces such as `/api/v0/device/*`,
  `/api/v0/token/*`, or `/api/v0/session/*` when those APIs are designed.
- Do not encode iOS/Android differences in route paths. Express platform differences through
  `client_id`, `redirect_uri`, PKCE, client registry metadata, device credential metadata,
  attestation type, or token binding method.
- Keep Web/Core API audiences separate from Palm. Add `core-api` or `base-api` only when needed for
  server-side Web API calls.

## Test Plan

- Add architecture or configuration tests that Acme is the only configured issuer.
- Add cookie tests for Core browser credential attributes and Next.js zero-cookie forwarding once
  the Core cookie implementation exists.
- Add negative API tests proving Resource Servers reject ID Tokens for authorization.
- Add Palm token tests for signature, issuer, audience, time claims, scope, client id, and subject.
- Add negative tests proving browser/session cookies do not authenticate Palm.
- Add integration tests for native Authorization Code + PKCE to Palm access when implementation
  reaches that layer.
- Add regression tests for any retained compatibility URLs before removing old route behavior.

## Guardrails

- Do not restore Sign as an IdP or token issuer.
- Do not make Core authenticate to Sign.
- Do not share cookies or sessions between Core and Base.
- Do not use `Domain=.example.com` for Core's session cookie.
- Do not put bearer tokens in browser-visible storage.
- Do not use ID Tokens for API authorization.
- Do not call APIs RPs when their role is to validate access tokens as Resource Servers.
- Do not use `Port` or `port-api` for new code, configuration, routes, or plans.
- Do not add Palm-specific OAuth/OIDC paths such as `/oauth/callback/ios`,
  `/oauth/callback/android`, `/ios/oauth/callback`, or `/android/oauth/callback`.
- Do not call Palm local credentials, device binding credentials, or transport credentials
  OAuth/OIDC access tokens.

## Open Items

- Final Acme, Sign, Base, and Palm production hostnames.
- Palm production URL shape.
- Palm native flow implementation policy.
- Current Palm `/oauth/callback*` reserved native callback stubs: classify before removal or
  consolidation. They are inert compatibility stubs, not formal Palm OAuth/OIDC entry points, and
  must not be deleted before checking native app registration, provider console settings, external
  documentation, and access logs.
- Exact Core-to-Base API audience naming if distinct Web server-side API audiences are required.
- Migration path from existing Rails-only identity authority code to the new component boundary.
