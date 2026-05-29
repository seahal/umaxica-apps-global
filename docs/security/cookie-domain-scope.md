# Cookie Domain Scope

## Current Behavior

Cookie domain scope is split by surface and is intentional. Do not "normalize" the two surfaces to
the same `domain:` value — the asymmetry is the design.

| Cookie group                                | Setter                                                                                                         | `domain:`      | Scope                                        | HttpOnly                                              |
| ------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | -------------- | -------------------------------------------- | ----------------------------------------------------- |
| Authentication access / refresh / device-id | `app/controllers/concerns/authentication/cookie_service.rb`, `app/controllers/concerns/authentication/base.rb` | `false`        | **Host-only** (not shared across subdomains) | `true`                                                |
| Preference refresh / DBSC / device-id       | `app/controllers/concerns/preference/base.rb` (`preference_cookie_options`)                                    | default `true` | **Acme** (`.example.com`, all subdomains)    | `true`                                                |
| Preference theme/locale, consent flag       | `preference/base.rb:649`, `preference/consented_buffer.rb:24`                                                  | default `true` | **Acme**                                     | `false` (intentionally JS-readable, not a credential) |

The mechanism is `Core::CookieOptions.for`: `domain: true` (default) calls `Core::CookieDomain.for`
and produces an apex-scoped cookie; `domain: false` omits the `domain` attribute and produces a
host-only cookie.

Preference credential cookies are apex-scoped but their names are surface-scoped:
`app_preference_*`, `com_preference_*`, and `org_preference_*`. This prevents an `AppPreference`
refresh token from being interpreted as a `ComPreference` or `OrgPreference` refresh token on
another host under the same apex. The legacy unscoped access cookie name is read only as a
compatibility fallback when the JWT `preference_type` matches the current surface.

## Cross-Subdomain SSO

Cross-subdomain SSO is carried by the **preference** refresh token, which is apex-scoped. The
**authentication** access/refresh tokens are host-only and are deliberately not shared across
subdomains.

## Accepted Risk Scope

The accepted-risk note in `app/lib/core/cookie_domain.rb:71-74` ("auth cookies are readable by ALL
subdomains ... mitigated by httponly") applies only to the **apex-scoped preference cookie group**.
It does **not** apply to the authentication tokens, which are host-only and therefore more strictly
isolated. The note's "mitigated by httponly" reasoning covers the apex-scoped token cookies
(`httponly: true`); the apex-scoped `httponly: false` cookies are non-credential preference values
(theme/locale, consent flag), so credential exposure reasoning is unaffected.

## Related

- `adr/cookie-domain-scope-by-surface.md` — decision and rationale.
- `docs/security/refresh-token-rotation.md`
- `docs/reference/subdomains.md`
