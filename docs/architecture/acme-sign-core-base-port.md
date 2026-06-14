# Acme, Sign, Core, Base, And Port Architecture

## Current Boundary

The accepted component model is:

| Component | Role                                           |
| --------- | ---------------------------------------------- |
| Acme      | IdP / Authorization Server                     |
| Sign      | Special relying party                          |
| Core      | Next.js web relying party and BFF              |
| Base      | Rails application foundation and control plane |
| Port      | Native bearer-token API Resource Server        |

Acme is the only login authority. Sign, Core, Base views, iOS, and Android authenticate through
Acme. APIs are Resource Servers, not relying parties.

## Responsibilities

Acme owns `/authorize`, `/token`, JWKS, ID Token issuance, Access Token issuance, issuer identity,
and subject identity.

Sign owns sign-related UI or special flows as a relying party. Sign is not an issuer.

Core owns the browser-facing web experience, receives the Acme callback, and serves the browser
credential boundary. `adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md`
supersedes the earlier `__Host-core_sid`-only model: Rails Core may consume `aud=core-browser`
access JWTs only from HttpOnly cookie transport, and the Next.js origin must receive no `Cookie`
header at all.

Base owns Rails-suitable foundation behavior: settings, preferences, account, profile, organization,
administration, complex mutations, audit-sensitive operations, and Rails views where Rails remains
the safer implementation boundary.

Port owns native API access for iOS, Android, and other native clients. It accepts only Acme-issued
bearer access tokens with the Port audience.

## Browser Flow

```text
Browser
-> Core / Next.js / jp.example.com
-> Acme /authorize
-> Core callback
-> Rails Core consumes the auth access cookie on /api/v0/*
```

The browser may hold a Core browser access JWT only through HttpOnly cookie transport. JavaScript
must not read access or refresh credentials. Next.js must not receive any `Cookie` header, including
access, refresh, OIDC transaction, preference, flash, analytics, or unrelated cookies.

Core browser credential cookies use the existing Rails auth cookie concern and names, not a
Core-only fork:

| Cookie | Purpose | Domain | Path | SameSite | Secure | HttpOnly |
| ------ | ------- | ------ | ---- | -------- | ------ | -------- |
| existing auth access cookie, `__Host-` prefixed in secure contexts | Access JWT | none | `/` | `Strict` | `true` | `true` |
| existing auth refresh cookie, `__Host-` prefixed in secure contexts | Opaque refresh | none | `/` | `Strict` | `true` | `true` |
| existing Rails/OIDC transaction state | OIDC transaction | existing ceremony controls | existing ceremony controls | existing ceremony controls | existing ceremony controls | existing ceremony controls |

The access JWT uses the `core-browser` audience and a short TTL. The refresh credential is opaque.
Do not split the auth ceremony into Core-only cookie concerns unless a later ADR accepts that drift.

Do not use `Domain=.example.com` for Core browser credentials. Cloudflare strips the entire `Cookie`
header before forwarding requests to the Next.js origin or `side.jp.umaxica.app`, and strips
`Set-Cookie` from Next.js and Side responses before they reach the browser.

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

Audience and transport are bound:

- `aud=core-browser` is accepted only from cookie transport.
- `aud=palm-api` or `aud=port-api` is accepted only from Authorization bearer transport.
- `aud=side-service` is service-token-only and never user-bound.

Reverse transport must be rejected. Because Core browser uses cookie transport, Rails CSRF
verification is mandatory for unsafe methods.

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

- `adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md`
- `adr/core-browser-credential-transport.md`
- `adr/acme-sign-core-base-port-boundary.md`
- `docs/security/cookie-domain-scope.md`
- `docs/security/downstream-token-authority.md`
