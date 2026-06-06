# Cookie Domain Scope

> **Partially superseded by Identity Authority inversion:** Cookie scope does not imply logical
> authority. `acme/www` is the Session, Token, Account, Preference, Authorization, and
> downstream-token Authority. `sign/id` is ceremony-only. Existing sign-side physical tables/models
> do not imply sign-side authority.

## Current Behavior

Cookie domain scope is split by surface and is intentional. Do not "normalize" the two surfaces to
the same `domain:` value — the asymmetry is the design.

| Cookie group                                | Setter                                                                              | `domain:`      | Scope                                        | HttpOnly                                              |
| ------------------------------------------- | ----------------------------------------------------------------------------------- | -------------- | -------------------------------------------- | ----------------------------------------------------- |
| Authentication access / refresh / device-id | `app/controllers/concerns/authentication/cookie_service.rb` (`auth_cookie_options`) | `false`        | **Host-only** (not shared across subdomains) | `true`                                                |
| Preference refresh / DBSC / device-id       | `app/controllers/concerns/preference/base.rb` (`preference_cookie_options`)         | default `true` | **Acme** (`.example.com`, all subdomains)    | `true`                                                |
| Preference theme/locale, consent flag       | `preference/base.rb` (`set_color_theme`), `preference/consented_buffer.rb`          | default `true` | **Acme**                                     | `false` (intentionally JS-readable, not a credential) |

The mechanism is `Core::CookieOptions.for`: `domain: true` (default) calls `Core::CookieDomain.for`
and produces an apex-scoped cookie; `domain: false` omits the `domain` attribute and produces a
host-only cookie.

## JS-Readable Preference Mirrors

Rails may write JS-readable cookies only for non-secret UI and request-context mirrors:

- `ct` - color theme code used by browser theme bootstrapping.
- `language` - language code; kept under this name for Hono compatibility.
- `tz`, `cu`, `df`, `tf`, `mo`, `dn`, `ps`, `r18s` - timezone and display preference mirrors.
- `preference_consented` - compact consent-banner state for AJAX/browser UI.

These cookies are compatibility mirrors. Rails request code must not treat them as authoritative
preference input; normal runtime reads come from the preference access-token projection and
`Actor.preferences`. The mirrors are JS-readable because they contain only values already visible in
the UI or URL/request context. They must not carry session ids, access tokens, refresh tokens,
preference JWTs, DBSC values, authorization grants, ceremony secrets, one-time tokens, raw
credentials, or credential/session authority data.

CSRF tokens stay in the existing meta/header flow, not in these mirror cookies. `ri` remains URL
request context and is not mirrored into a cookie.

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

The accepted-risk note in `app/services/core/cookie_domain.rb:84-87` ("auth cookies are readable by
ALL subdomains ... mitigated by httponly") applies only to the **apex-scoped preference cookie
group**. It does **not** apply to the authentication tokens, which are host-only and therefore more
strictly isolated. The note's "mitigated by httponly" reasoning covers the apex-scoped token cookies
(`httponly: true`); the apex-scoped `httponly: false` cookies are non-credential preference values
(theme/locale, consent flag), so credential exposure reasoning is unaffected.

## Related

- `adr/cookie-domain-scope-by-surface.md` — decision and rationale.
- `docs/security/refresh-token-rotation.md`
- `docs/reference/subdomains.md`
