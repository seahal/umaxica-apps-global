# Acme, Sign, Core, Base, And Port Boundary

## Status

Accepted (2026-06-12)

## Context

Earlier decisions used `acme/www` and `sign/id` to describe a Rails-hosted identity authority
inversion. That language no longer matches the target product and deployment vocabulary.

The accepted component names are now:

- Acme
- Sign
- Core
- Base
- Port

The withdrawn names `Deck` and `Bare` must not be used for this architecture.

## Decision

Acme is the only Identity Provider and Authorization Server. Acme owns the issuer, subject identity,
OIDC/OAuth authorization endpoints, JWKS, and token issuance.

Sign is a special relying party. It may keep sign-related UI and special flows, but it is not an
Identity Provider and must not be a token issuer.

Core is the Next.js web relying party and browser-facing BFF. Core owns the web experience on a host
such as `jp.example.com`, receives the Acme callback, issues its own host-only web session cookie,
and calls server-side APIs from the Core server.

Base is a new Rails application foundation and control-plane subdomain split out of the older Core
concept. Base owns Rails-suitable application foundation behavior such as settings, preferences,
account, profile, organization, administration, complex mutations, audit-sensitive operations, and
work that should stay in Rails until Core is ready to own it. Base may render Rails views on a host
such as `www.jp.example.com`.

Port is the native API Resource Server for iOS, Android, and other native clients. Port does not use
browser cookies or Rails/Next.js sessions. Port authenticates only Acme-issued access tokens
presented with `Authorization: Bearer`.

## Component Classification

| Component | Classification |
| --- | --- |
| Acme | IdP / Authorization Server |
| Sign | Special RP |
| Core | Next.js web RP / BFF |
| Base | Rails foundation/control plane; RP for Rails views, Resource Server for APIs |
| Port | Native bearer-token API Resource Server |
| iOS / Android | Public RPs |

APIs are Resource Servers, not RPs. An RP initiates an authorization request and receives a
callback. A Resource Server validates access tokens and returns API responses.

## Web Boundary

The web path is:

```text
Browser -> Core / Next.js -> Acme /authorize -> Core callback -> Core server-side API calls
```

Browsers must not directly hold bearer access tokens. The browser holds only Core's host-only web
session cookie:

| Attribute | Value |
| --- | --- |
| Name | `__Host-core_sid` |
| Domain | none |
| Path | `/` |
| Secure | `true` |
| HttpOnly | `true` |
| SameSite | `Lax` |

`Domain=.example.com` must not be used for Core's browser session cookie.

Core and Base do not share cookies or sessions:

- Core session is not Base session.
- Core cookie is not Base cookie.
- Rails session is not Next.js session.
- Rails APIs must not trust a Next.js cookie.
- Next.js must not read a Rails session cookie.

The shared identity key is Acme `iss + sub`, not a shared browser cookie.

## Native And Port Boundary

Native applications are public RPs. The native path is:

```text
iOS / Android -> Acme /authorize -> Acme /token -> Port API
```

Native applications use Authorization Code + PKCE. They call Port with an Acme-issued access token:

```json
{
  "iss": "https://acme.example.com",
  "sub": "acct_xxxxx",
  "aud": "port-api",
  "client_id": "app-ios-rp",
  "scope": "port.read port.write",
  "exp": 1234567890
}
```

Port validates signature, issuer, `aud = port-api`, time claims, scope, client id, and subject, then
resolves the current user from Acme `iss + sub`.

## Client And Audience Names

The initial client and audience vocabulary is:

- `sign-rp`
- `core-next-rp`
- `base-rails-rp`
- `app-ios-rp`
- `app-android-rp`
- `port-api`

If Core needs to call Rails/Base APIs as a distinct API audience, use separate audiences such as
`core-api` or `base-api`. Do not mix Web/Core server-side APIs with the native Port API surface.

## Token Use

ID Tokens are for RPs to verify login results. Access Tokens are for Resource Servers to authorize
API access. APIs must not use ID Tokens for authorization.

## URL Direction

The URL direction is:

- Acme: `acme.example.com` or equivalent.
- Sign: `sign.example.com` or equivalent.
- Core: `jp.example.com`.
- Base: `www.jp.example.com` or another Rails foundation/control-plane subdomain.
- Port: undecided; candidates include `api.jp.example.com/port/v1` or `port.jp.example.com`.

Port URL selection is intentionally deferred. The responsibility, token audience, and bearer-token
boundary are decided first.

## Supersession

This ADR supersedes prior identity-authority material where that material treats `acme/www` as the
combined Rails Session, Token, Account, Preference, Authorization, and downstream-token authority or
treats `sign/id` as a credential-gateway host in the same Rails authority model.

Historical material remains useful for implementation risks, security vocabulary, migration notes,
and Rails controller lifecycle constraints. It must not override this component naming and
responsibility model.

## Guardrails

Do not:

- treat Sign as an IdP;
- make Core authenticate to Sign;
- share cookies or sessions between Core and Base;
- use `Domain=.example.com` for Core's session cookie;
- let browser JavaScript hold bearer tokens;
- use ID Tokens for API authorization;
- make API controllers depend on Rails browser sessions;
- make iOS or Android depend on the Core BFF for API access;
- call an API a relying party when it is validating access tokens as a Resource Server.

## Related

- `docs/architecture/acme-sign-core-base-port.md`
- `plans/active/acme-sign-core-base-port-implementation.md`
- `adr/identity-authority-boundary.md`
- `adr/acme-session-and-token-authority.md`
- `adr/sign-residual-idp-surface-retirement.md`
