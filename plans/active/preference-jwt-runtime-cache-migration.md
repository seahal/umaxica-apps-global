# Preference JWT Runtime Cache Migration

> **Deprecated by Identity Authority inversion where this plan assigns preference or token authority
> to `sign/id`:** `acme/www` now owns Session, Token, Account, Preference, Authorization, and
> downstream-token authority. `sign/id` is ceremony-only. Physical DB movement is out of scope.
> Implementation details in this plan must not be used to reintroduce sign-side authority. Existing
> sign-side tables/models do not imply sign-side authority.

## Status

Active.

## Purpose

Restore the preference architecture to the intended one-way runtime read flow:

```text
DB -> access-token JWT prf -> Actor.preferences
```

The database remains the source of truth and storage boundary. The access-token JWT is the Rails
runtime read cache. `Actor.preferences` is the request-local immutable runtime preference. It is
initialized from the JWT preference claim, then valid explicit `lx`, `ct`, and `tz` request params
are overlaid for the current request only.

## Non-Goals

- Do not change the access-token / refresh-token issuing foundation.
- Do not change production cookie security rules, including subdomain scope and `__Secure-`
  prefixes.
- Do not make JS-readable cookies authoritative for Rails request reads.
- Do not issue JWTs from `Actor.preferences`.
- Do not write the database from `Actor.preferences`.
- Do not repair missing or malformed normal request preference JWTs by reading preference records in
  a generic `before_action`.

## Rules

- Rails normal runtime reads must use `Actor.preferences`.
- `Actor.preferences` should be built from the access-token `prf` claim in the normal path, then
  rebuilt with valid request-local `lx`, `ct`, and `tz` overlays when those params were explicitly
  present.
- `ri` is mandatory request context and must be present as a valid URL context value.
- `lx`, `ct`, and `tz` are optional request-local context overrides. They are not write paths.
- If `lx=en` is present while the JWT says `lx=ja`, the request renders with
  `Actor.preferences.language == "en"`, but the database and JWT stay `ja`.
- Rails may write JS-readable preference cookies for browser, Hono, edge, or UI compatibility. Rails
  must not read those cookies as preference input.
- Database access is limited to new preference creation, valid refresh-token recovery or rotation,
  logged-in HTML preference edit entry refresh, explicit preference updates, explicit reset/delete,
  login-time adoption or sync, and repair/admin flows.
- A missing, broken, or malformed preference access-token in a normal authenticated request is a
  token failure. It should raise or fail through the normal authentication path instead of falling
  back to database lookup.

## Target Lifecycle

Controller bases that participate in authenticated preference context should converge on this
ordering:

```text
rate limit
-> verify/decode access token
-> refresh preference token from DB for logged-in HTML preference edit entry when applicable
-> initialize Actor from token state
-> overlay valid request-local lx/ct/tz onto Actor.preferences
-> apply locale/timezone/theme from Actor.preferences
-> controller action
-> ensure Actor.clear
```

The side-effect reflection step must read `Actor.preferences` only. It should not inspect
`params[:lx]`, `params[:ct]`, `params[:tz]`, JS-readable cookies, `@preferences`, or raw JWT claims
directly.

The edit-entry DB refresh applies only to logged-in HTML preference edit screens. It copies the
actor-local preference DB value into the current surface preference and reissues the preference
access-token JWT before `Actor.preferences` is initialized. It is not enabled for normal pages,
JSON/web endpoints, or unauthenticated preference paths.

## Current Gaps

- `Preference::AccessTokenTransport#load_access_token_payload` still treats the JWT as a database
  lookup ticket by resolving `public_id` against the preference database on the normal path.
- `ActorSupport#resolved_current_preference` still prefers resource-associated database preference
  records over the JWT `prf` claim.
- `Preference::Global#cookie_context` can override JWT-derived request context with `@preferences`
  record values.
- Some locale/theme/timezone reflection code still reads params, cookies, JWT payload, and
  controller instance variables directly instead of resolving through `Actor.preferences`.
- Current code treats request params as side-effect inputs in multiple places instead of applying
  them once as an `Actor.preferences` request overlay.
- Current code has DB recovery behavior in the normal access-token transport path. The target is to
  raise/fail normal requests and keep DB recovery in explicit refresh/write/repair flows.

## Migration Steps

1. Split normal access-token payload decoding from database-backed record loading.
2. Keep database-backed access-token record loading only for refresh, write, repair, and maintenance
   flows.
3. Change `ActorSupport#resolved_current_preference` to prefer JWT `prf` for the normal request
   path.
4. Add a single request-overlay step that rebuilds `Actor.preferences` with valid explicit `lx`,
   `ct`, and `tz` values. This step must not write DB/JWT/cookies.
5. Move locale, timezone, and theme side-effect reflection to read only from `Actor.preferences`.
6. Keep the logged-in HTML preference edit entry refresh as an explicit DB -> JWT sync before
   `Actor.preferences` initialization.
7. Remove `@preferences` database override from normal request-context resolution.
8. Remove Rails runtime reads from JS-readable preference cookies.
9. Make missing, broken, or malformed normal request preference JWTs fail instead of falling back to
   database lookup.
10. Keep dedicated preference write endpoints on the DB -> JWT path: write DB, reload/preload the
    record, issue a new access-token JWT, and write compatibility cookies when needed.
11. Add tests that prove normal app/com/org requests do not read preference records when a valid
    access-token `prf` claim is present.

## Verification

- Unit tests for `ActorSupport` proving JWT-first preference resolution.
- Unit tests for the request overlay proving `lx`, `ct`, and `tz` affect only `Actor.preferences`
  for the current request.
- Unit tests or controller tests proving logged-in HTML preference edit entry copies actor-local DB
  values into the current surface preference token before `Actor.preferences` initialization.
- Unit tests for `Preference::AccessTokenTransport` proving normal decode does not query preference
  records.
- Controller or integration tests for `app`, `com`, and `org` proving `ri` remains mandatory and
  `lx` / `ct` / `tz` remain optional request-local context only.
- Controller tests proving side-effect reflection reads `Actor.preferences` and not params, cookies,
  `@preferences`, or raw JWT claims directly.
- Regression tests for explicit preference writes proving DB changes reissue the preference
  access-token JWT.
