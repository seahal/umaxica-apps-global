# Cookie Domain Scope

## Current Behavior

Credential cookie names are role-based host-local transport slots. The cookie name describes the
transport role, not the logical credential kind.

| Role                | Secure context name         | Insecure dev/test name |
| ------------------- | --------------------------- | ---------------------- |
| Auth access         | `__Host-auth_access`        | `auth_access`          |
| Auth refresh        | `__Host-auth_refresh`       | `auth_refresh`         |
| Auth DBSC / binding | `__Host-auth_dbsc`          | `auth_dbsc`            |
| Preference access   | `__Host-preference_access`  | `preference_access`    |
| Preference refresh  | `__Host-preference_refresh` | `preference_refresh`   |
| Preference DBSC     | `__Host-preference_dbsc`    | `preference_dbsc`      |

New credential cookie writes are host-only. They use `Path=/`; secure contexts use `Secure` and the
`__Host-` prefix. They never carry a `Domain` attribute.

Cookie names must not include `global`, `regional`, `app`, `com`, `org`, `core`, or `palm`. For
example, Acme's `__Host-auth_access`, Sign's `__Host-auth_access`, and Core/Base browser hosts'
`__Host-auth_access` are separate cookies because the browser stores them per host.

## JS-Readable Preference Mirrors

Rails may write JS-readable cookies only for non-secret UI and request-context mirrors:

- `ct` - color theme code used by browser theme bootstrapping.
- `language` - language code; kept under this name for Hono compatibility.
- `tz`, `cu`, `df`, `tf`, `mo`, `dn`, `ps` - timezone and display preference mirrors.
- `preference_consented` - compact consent-banner state for AJAX/browser UI.

These cookies are apex-scoped (e.g. `.umaxica.app`) so that all subdomains within a surface can read
them for theme bootstrapping, Hono compatibility, and edge rendering. They are written with
`domain: true` via `CoreCookieOptions.for`, which resolves to the apex domain for the current
surface.

These cookies are compatibility mirrors. Rails request code must not treat them as authoritative
preference input; normal runtime reads come from the preference access-token projection and
`Actor.preferences`. The mirrors are JS-readable because they contain only values already visible in
the UI or URL/request context. They must not carry session ids, access tokens, refresh tokens,
preference JWTs, DBSC values, authorization grants, ceremony secrets, one-time tokens, raw
credentials, or credential/session authority data.

CSRF tokens stay in the existing meta/header flow, not in these mirror cookies. `ri` remains URL
request context and is not mirrored into a cookie.

Preference credential cookies are host-only and use the role names in the table above. Surface and
record separation is resolved from host/surface context and the database preference record, not from
the cookie name.

Browser-visible hosts and internal Rails/pod origins should be described with the `PUBLIC_` and
`PRIVATE_` boundary vocabulary in docs and config. That keeps cookie transport discussions separate
from host-ownership discussions.

## Compatibility Window

New writes use only `preference_access`, `preference_refresh`, and `preference_dbsc` in insecure
contexts, or their `__Host-` names in secure contexts.

Legacy `{app,com,org}_preference_*` names and old `__Secure-preference_*` names are short-term
read/delete compatibility only. A successful preference reissue or refresh deletes the legacy names.
Application code must not add new direct references to `app_preference_access`,
`com_preference_refresh`, `org_preference_dbsc`, or similar literal cookie names.

## Authority and Transport Boundaries

Credential kind is enforced by issuer, audience, validator contract, client classification, and
transport binding:

- Acme is the only Authorization Server and token authority.
- Sign is a special RP. It does not own issuer, token, or refresh authority.
- `SignRefreshTokenService` is a legacy compatibility subclass; new refresh authority references
  should use `AcmeRefreshTokenService`.
- Core browser credentials use the `core-browser` audience from cookie transport.
- Palm API tokens use the `palm-api` audience from `Authorization: Bearer`.
- Core browser cookie validators reject `palm-api`.
- Palm bearer validators reject `core-browser`.
- Palm controllers do not read auth or preference cookies and do not issue browser session cookies.
- Acme/Sign do not issue or consume Core/Base regional browser cookies.

Because `__Host-` requires `Path=/`, refresh cookies are not path-restricted. Refresh endpoint
exclusivity is a server-side transport and endpoint contract.

## Related

- `adr/cookie-domain-scope-by-surface.md` — decision and rationale.
- `docs/security/refresh-token-rotation.md`
- `docs/reference/subdomains.md`
