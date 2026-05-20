# Cookie Domain Scope By Surface

## Status

Accepted on 2026-05-17.

## Context

`Core::CookieDomain.for` can return an apex-scoped domain (e.g. `.example.com`). A cookie set with
that domain is readable by **every subdomain** on the apex. A cookie set with no `domain` attribute
is **host-only** and is readable only by the exact host that set it.

`Core::CookieOptions.for` controls this through the `domain:` keyword:

- `domain: true` (default) -> calls `Core::CookieDomain.for` -> apex-scoped, cross-subdomain.
- `domain: false` -> no `domain` attribute -> host-only, not shared across subdomains.

A recurring misreading is that the accepted-risk note in `app/lib/core/cookie_domain.rb:71-74`
("auth cookies are readable by ALL subdomains ... mitigated by httponly") applies to **all** refresh
tokens, including the authentication surface. It does not. The two surfaces deliberately use
opposite domain scoping.

## Decision

Domain scoping is split by surface and is intentional:

- **Authentication surface tokens are host-only.** The access and refresh token cookies (and the
  device-id cookie) are set with `domain: false`. They are **not** shared across subdomains. The
  `cookie_domain.rb` accepted-risk note does **not** apply to them.
- **Preference surface cookies are apex-scoped.** The preference refresh token, DBSC, and device-id
  cookies are set with the default `domain: true`, so they are apex-scoped and readable by all
  subdomains. Their credential cookie names are surface-scoped (`app_preference_*`,
  `com_preference_*`, `org_preference_*`) so one surface does not consume another surface's
  preference record. **Cross-subdomain SSO is carried by the preference refresh token, not by the
  authentication refresh token.** The `cookie_domain.rb` accepted-risk note applies here.

The accepted cross-subdomain XSS risk in `cookie_domain.rb:71-74` is therefore scoped to the
apex-scoped **preference** cookie group only. It is mitigated for the token cookies by
`httponly: true`. The same apex scope also carries non-token preference cookies with
`httponly: false` (theme/locale, consent flag); those are intentionally JS-readable values, not
credentials, so the "mitigated by httponly" reasoning for credentials is not weakened.

Do not change either surface's `domain:` value to "make them consistent". The asymmetry is the
decision: authentication is isolated per host; preference is shared for SSO.

## Evidence

- `app/lib/core/cookie_options.rb:8-24` — `domain:` keyword gates `Core::CookieDomain.for`.
- `app/lib/core/cookie_domain.rb:71-81` — apex scoping and the accepted-risk note.
- `app/controllers/concerns/authentication/cookie_service.rb:56-66` — authentication cookies use
  `domain: false`.
- `app/controllers/concerns/authentication/base.rb:1199-1217` — authentication cookie / deletion
  options use `domain: false`.
- `app/controllers/concerns/preference/base.rb` — `preference_cookie_options` omits `domain:`, so
  the preference refresh / DBSC / device-id cookies are apex-scoped with `httponly: true`; the
  credential cookie names are derived through `Preference::CookieName` with the current surface.
- `app/controllers/concerns/preference/base.rb:649` and
  `app/controllers/concerns/preference/consented_buffer.rb:24` — apex-scoped, intentionally
  `httponly: false` non-token preference cookies.

## Consequences

- An XSS on any subdomain cannot read the authentication access/refresh tokens (host-only).
- An XSS on any subdomain still cannot read the preference token cookies because they are
  `httponly: true`, but a subdomain compromise widens exposure for the apex-shared preference
  cookies, as documented in `cookie_domain.rb`.
- Any future SSO requirement for the authentication surface must be designed explicitly; it must not
  be obtained by flipping authentication cookies to `domain: true`.

## Related

- `docs/security/cookie-domain-scope.md` — current behavior reference.
- `docs/security/refresh-token-rotation.md`
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`
- `adr/theme-preference-cookie-and-param-contract.md`
