# Acme / Sign / Core / Base / Port Implementation Plan

## Status

Active planning. The accepted boundary is `adr/acme-sign-core-base-port-boundary.md`.

## Summary

Implement the component split where Acme is the only IdP / Authorization Server, Sign is a special
RP, Core is the Next.js web RP/BFF, Base is the Rails foundation/control-plane subdomain, and Port
is the native bearer-token API Resource Server.

This plan replaces older Rails-only `acme/www` versus `sign/id` authority-inversion planning where
that planning conflicts with the accepted Acme / Sign / Core / Base / Port boundary.

## Implementation Changes

- Inventory current Rails routes, controllers, token services, cookie writers, and OIDC client
  configuration that still assume the older `acme/www` or `sign/id` authority model.
- Define Acme issuer, JWKS, `/authorize`, and `/token` behavior as the only token authority.
- Register client and audience names: `sign-rp`, `core-next-rp`, `base-rails-rp`, `app-ios-rp`,
  `app-android-rp`, and `port-api`.
- Implement or document Core's `__Host-core_sid` host-only cookie contract without `Domain=`.
- Split old Core responsibilities into Core, Base, and Port:
  - Core: Next.js web experience and BFF.
  - Base: Rails foundation/control-plane views and APIs.
  - Port: native bearer-token API surface.
- Keep browser bearer tokens server-side in Core; do not expose them to browser JavaScript.
- Make Base APIs validate appropriate server-side access credentials instead of trusting Core
  cookies or Rails browser sessions.
- Make Port validate Acme-issued Access Tokens with `aud = port-api` and never depend on Rails or
  Next.js sessions.
- Keep Web/Core API audiences separate from Port. Add `core-api` or `base-api` only when needed for
  server-side Web API calls.

## Test Plan

- Add architecture or configuration tests that Acme is the only configured issuer.
- Add cookie tests for Core's `__Host-core_sid` attributes once Core cookie implementation exists.
- Add negative API tests proving Resource Servers reject ID Tokens for authorization.
- Add Port token tests for signature, issuer, audience, time claims, scope, client id, and subject.
- Add negative tests proving browser/session cookies do not authenticate Port.
- Add integration tests for native Authorization Code + PKCE to Port access when implementation
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

## Open Items

- Final Acme, Sign, Base, and Port production hostnames.
- Port URL shape: `api.jp.example.com/port/v1`, `port.jp.example.com`, or another option.
- Exact Core-to-Base API audience naming if distinct Web server-side API audiences are required.
- Migration path from existing Rails-only identity authority code to the new component boundary.
