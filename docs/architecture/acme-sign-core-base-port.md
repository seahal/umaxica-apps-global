# Acme, Sign, Core, Base, And Port Architecture

## Current Boundary

The accepted component model is:

| Component | Role |
| --- | --- |
| Acme | IdP / Authorization Server |
| Sign | Special relying party |
| Core | Next.js web relying party and BFF |
| Base | Rails application foundation and control plane |
| Port | Native bearer-token API Resource Server |

Acme is the only login authority. Sign, Core, Base views, iOS, and Android authenticate through
Acme. APIs are Resource Servers, not relying parties.

## Responsibilities

Acme owns `/authorize`, `/token`, JWKS, ID Token issuance, Access Token issuance, issuer identity,
and subject identity.

Sign owns sign-related UI or special flows as a relying party. Sign is not an issuer.

Core owns the browser-facing web experience, receives the Acme callback, issues the Core web
session cookie, and calls downstream APIs from the server side.

Base owns Rails-suitable foundation behavior: settings, preferences, account, profile,
organization, administration, complex mutations, audit-sensitive operations, and Rails views where
Rails remains the safer implementation boundary.

Port owns native API access for iOS, Android, and other native clients. It accepts only Acme-issued
bearer access tokens with the Port audience.

## Browser Flow

```text
Browser
-> Core / Next.js / jp.example.com
-> Acme /authorize
-> Core callback
-> Core issues __Host-core_sid
-> Core server calls Base API or other non-Port web APIs as needed
```

The browser must not directly hold bearer access tokens. The browser holds only Core's host-only
session cookie.

Core's cookie contract:

| Attribute | Value |
| --- | --- |
| Name | `__Host-core_sid` |
| Domain | none |
| Path | `/` |
| Secure | `true` |
| HttpOnly | `true` |
| SameSite | `Lax` |

Do not use `Domain=.example.com` for Core browser sessions.

## Session And Cookie Boundary

Core and Base do not share cookies or sessions.

- Core session is not Base session.
- Core cookie is not Base cookie.
- Rails session is not Next.js session.
- Rails APIs must not trust a Next.js cookie.
- Next.js must not read Rails session cookies.

The shared person key across components is Acme `iss + sub`.

## Native And Port Flow

```text
iOS / Android
-> Acme /authorize
-> Acme /token
-> Port API with Authorization: Bearer
```

Native apps are public RPs using Authorization Code + PKCE. Port is a Resource Server. Port does not
use Rails sessions, Next.js sessions, or browser cookies.

Port validates:

- token signature;
- `iss` equals the Acme issuer;
- `aud` equals `port-api`;
- `exp`, `nbf`, and `iat`;
- scope;
- `client_id`;
- `sub`.

Port resolves users from Acme `iss + sub`.

## Token Boundary

ID Tokens are for RPs to verify login results. Access Tokens are for APIs and Resource Servers to
authorize API access.

APIs must not use ID Tokens for authorization.

## Names And URLs

Initial client and audience names:

- `sign-rp`
- `core-next-rp`
- `base-rails-rp`
- `app-ios-rp`
- `app-android-rp`
- `port-api`

Optional future API audiences for Core-to-Base server-side calls may use names such as `core-api` or
`base-api`.

URL direction:

- Acme: `acme.example.com` or equivalent.
- Sign: `sign.example.com` or equivalent.
- Core: `jp.example.com`.
- Base: `www.jp.example.com` or equivalent Rails foundation/control-plane subdomain.
- Port: undecided; candidates include `api.jp.example.com/port/v1` or `port.jp.example.com`.

Port URL selection remains open. The Port responsibility and bearer-token audience are fixed.

## Related

- `adr/acme-sign-core-base-port-boundary.md`
- `docs/security/cookie-domain-scope.md`
- `docs/security/downstream-token-authority.md`
