# Preference Architecture

## Purpose

The preference system has two different roles.

- `AppPreference`, `OrgPreference`, and `ComPreference` hold login-independent surface setting
  state.
- `UserPreference`, `OperatorPreference`, and `VisitorPreference` hold per-account local settings.

The system must keep these roles separate.

Preference setting writes are exposed through the `sign` surfaces. `acme` and `jump` consume
preference state as read-only runtime context through `Actor.preferences`.

## Scope

### Shared preference

Shared preference is the source of truth for login-independent surface preference state.

- It belongs to the `App` / `Org` / `Com` surfaces.
- It stores the current token-like preference state.
- It is used before login and after logout.
- It lives in `app_setting`, `org_setting`, or `com_setting`.

### Local preference

Local preference is the source of truth for account-local settings.

- It belongs to the `Client` / `Operator` / `Visitor` records.
- It stores per-account language, region, timezone, and theme settings.
- It is kept in each domain database.

## Synchronization Rules

The system uses explicit sync rules.

### Before login

- Write preference changes from the `sign` preference routes to `AppPreference`, `OrgPreference`, or
  `ComPreference`.
- Do not depend on local preference data.

### During login

- Write the same user-visible preference data to both shared preference and local preference.
- Keep the values aligned by explicit sync.
- If both sides already exist, reconcile by parent-record recency: the newer parent preference
  record wins as a whole record. This is intentional until the schema has per-field change metadata.

### During logout

- Write only to shared preference from the `sign` preference/logout boundary.
- Local preference remains as the account-local record.

### Sync failure handling

- Do not expose sync failure to the user as a product error.
- Keep the user-facing action successful when possible.
- Recover the state by writing back to the matching local preference when a shared/local sync fails.
- Emit a structured error log for later recovery and investigation.

Recovery target by surface:

- `App` -> `UserPreference`
- `Org` -> `OperatorPreference`
- `Com` -> `VisitorPreference`

Required log fields:

- `preference_type`
- `source`
- `target`
- `action`
- `error_class`
- `error_message`
- `owner_id`
- `surface` or `scope`
- `request_id` or another correlation key

## Data Sharing Rules

`App` / `Org` / `Com` preference data must not be treated as one shared row across all surfaces.

- Do not copy `App` data into `Org` or `Com`.
- Do not copy `Org` data into `App` or `Com`.
- Do not copy `Com` data into `App` or `Org`.

Each surface keeps its own preference state.

The local preference records also must stay isolated inside the matching principal bubble.

- `UserPreference` stays in the `app_principal` database.
- `OperatorPreference` stays in the `org_principal` database.
- `VisitorPreference` stays in the `com_principal` database.

## Shared Fields

The sync path should only move the allowlisted user-facing fields.

- `language`
- `region`
- `timezone`
- `theme`
- cookie consent fields when they are part of the active session state

## Promotional Email Unsubscribe

Promotional email opt-out is handled as a public, token-verified preference action on the sign
surfaces.

- The public path is `/preference/email/:id`, where `:id` is the email record `public_id`.
- The `token` query parameter is an HMAC generated from a dedicated
  `PROMOTIONAL_UNSUBSCRIBE_HMAC_SALT` secret.
- `app` uses the external HMAC scope `client` while it still updates the current `UserEmail`
  storage-backed model.
- `com` uses `VisitorEmail`; `org` uses `OperatorEmail`.
- `GET /preference/email/:id/edit` renders a confirmation page and does not change state.
- `DELETE /preference/email/:id` and Gmail one-click `POST /preference/email/:id` set `promotional`
  to `false` idempotently.

The sync path must not copy unrelated data.

- authentication secrets
- identity documents
- billing data
- moderation data
- message content
- operational audit payloads

## Request Context Parameters

The sign surfaces use the same request context contract for `app`, `org`, and `com`.

- `ri` carries the region.
- `lx` carries the language.
- `ct` carries the theme.
- `tz` carries the timezone.
- `cu`, `df`, `tf`, `mo`, `dn`, and `pp` carry optional display and locale-adjacent overlays.
- `pt` and `nt` carry redirect target lanes and are not propagated through ordinary preference
  navigation by default.

`ri` is mandatory request context. Current sign `app`, `org`, and `com` routes must carry a valid
`ri`. If `ri` is missing or invalid on a GET or HEAD request, the controller redirects to the same
route with a valid `ri` value. `ri` is request context, not a preference write path.

`lx`, `ct`, `tz`, `cu`, `df`, `tf`, `mo`, `dn`, and `pp` are optional request context. They are only
propagated when explicitly present and valid. The runtime preference subset may override the current
request's locale, theme, timezone, or display reflection by applying a request-local overlay to
`Actor.preferences`, but these parameters do not update the database or access-token JWT. If they
are missing, Rails request code should read the already resolved value from `Actor.preferences`,
without adding those optional keys back to generated URLs. On GET and HEAD requests, invalid or
blank optional context parameters are removed from the query string by redirect.

Supported optional request values:

- `lx`: `ja`, `en`
- `ct`: `li`, `dr`, `sy`, or their long forms `light`, `dark`, `system`
- `tz`: `utc`, `etc/utc`, `asia/tokyo`
- `tf`: `12`, `24`, or their long forms `hour_12`, `hour_24`
- `mo`: `st`, `rd`, or their long forms `standard`, `reduced`
- `dn`: `st`, `cp`, or their long forms `standard`, `compact`

Examples:

- `/configuration?ri=jp&lx=en` uses English for that request.
- `/configuration?ri=jp&lx=kr` redirects to `/configuration?ri=jp`.
- `/configuration?ri=jp&ct=purple&tz=Mars/Base` redirects to `/configuration?ri=jp`.
- `/configuration` redirects to the same route with a valid `ri`, but does not add `lx`, `ct`, or
  `tz`.

## Runtime Read Contract

Preference data flows in one direction for Rails runtime reads:

```text
Preference JWT payload (*_preference_access) -> Actor.preferences
```

The database is the durable storage boundary (SSoT) used by explicit preference write and
token-refresh flows. The **Preference JWT** (`*_preference_access` cookie) is its signed projection
and the Rails runtime read cache for normal requests. `Actor.preferences` is the immutable
request-local runtime preference value exposed to controllers, views, and services.

> **2026-05-30:** The hydration source changed from the auth access-token `prf` claim to the
> Preference JWT payload. The `prf` claim never mirrored the DB (it was built from the NULL+overlay
> value), so it was dead transport and is no longer read; its production is removed on the auth side
> in a separate task. The Preference JWT is decoded by `set_preferences_cookie`, which the
> controller lifecycle runs before `set_current_actor`, so hydration is a read-only, no-extra-DB
> step.

In a normal request, `Actor.preferences` is built in two stages:

1. Build the base preference from the Preference JWT payload (`preference_payload_preferences`), via
   `Actor::Preference.from_jwt`. When no Preference JWT cookie exists (Bearer/OIDC APIs and
   endpoints that skip `set_preferences_cookie`), fall back to `Actor::Preference::NULL`.
2. Overlay valid request-local `lx`, `ct`, and `tz` values when they were explicitly present in the
   request.

The overlay changes only the current request's runtime preference. It is not a preference write.

### Language resolution and dynamic region seeding

Child preference records are always created with a default option on first visit, so a saved value
cannot, by itself, distinguish an explicit user choice from an auto-seeded default. The
`explicit_fields` jsonb marker on `app/com/org_preferences` records which fields the user set on
purpose; it rides along in the payload as the `explicit` list. The effective language is resolved by
priority:

1. `?lx` request param (request-local; never written to DB/JWT).
2. An explicitly set language (present in `explicit_fields`) — wins over `?ri`.
3. `?ri`-derived dynamic seeding for users who have not set a language (`jp` -> ja, `us` -> en).
4. Default (`ja`).

Example:

```text
Preference JWT: lx=ja, ct=sy, tz=Asia/Tokyo
request params:   lx=en
Actor.preferences: language=en, theme=sy, timezone=Asia/Tokyo
```

The page renders in English for that request. The database and access-token JWT remain Japanese
until an explicit preference write path changes them and reissues a token.

Do not reverse this flow.

- Do not issue preference JWTs from `Actor.preferences`.
- Do not write the database from `Actor.preferences`.
- Do not read JS-readable preference cookies as Rails runtime input.
- Do not treat request context params as preference writes.
- Do not copy request-local `lx`, `ct`, or `tz` overlays back to the database or JWT.

`acme` and `jump` are runtime readers of this value. They must not persist preference settings, and
they must not treat request context, RP rendering, jump redirects, or read-side token consumption as
preference writes.

JS-readable preference cookies such as `language`, `ct`, and `tz` may be written by Rails for
compatibility with browser, Hono, edge, or UI code. Rails request code must not trust them as
preference input.

Database reads and writes are allowed only in bounded flows:

- new preference creation
- valid refresh-token rotation that intentionally reissues the preference JWT
- logged-in HTML preference edit entry refresh
- explicit `sign` preference update endpoints
- explicit `sign` preference reset or delete endpoints
- login-time adoption or sync
- repair, admin, or maintenance tasks

Normal authenticated request setup must not recover a missing, broken, or malformed preference
access-token by reading the preference database. Treat that as an authentication / token failure and
raise or fail the request through the normal error path. Database recovery belongs to a dedicated
refresh, write, repair, or administrative flow, not to generic `before_action` runtime setup.

Logged-in HTML preference edit screens are a bounded exception to the normal runtime path. Before
they initialize `Actor.preferences` and apply locale, timezone, or theme side effects, they may read
the actor-local preference database, copy that value into the current surface preference, and issue
a fresh preference access-token JWT. This keeps preference editing screens from showing stale values
when the same signed-in actor changed preferences in another browser or device. Request-local `lx`,
`ct`, and `tz` overlays are still applied only after this DB -> JWT refresh and are not copied back
to the database or JWT.

## Implementation Notes

- `Preference::ClassRegistry` decides which preference class is active.
- `Preference::Adoption` performs the login-time sync between shared and local preference.
- `Preference::Core` reads and updates the current preference snapshot.
- Surface preference records use the `app_setting`, `org_setting`, or `com_setting` database
  connection.
- `Actor::Preference` is the runtime read interface for request code. In the normal request path it
  is built from the access-token `prf` claim, then valid request-local `lx`, `ct`, and `tz` values
  are overlaid when explicitly present. Request code reads the resolved effective value through
  `Actor.preferences`.
- Auth access tokens carry the preference snapshot in the `prf` claim with stable short keys.
  Localization and theme use `lx`, `ri`, `tz`, and `ct`. Extended options use `cu` for currency,
  `df` for date format, `tf` for time format, `mo` for motion, `dn` for density, and `ipp` for items
  per page.
- `prf` is an application private claim, not a JWT Registered Claim. The nested `ver` key records
  the preference snapshot schema version. Current code emits `ver: 1` only; it does not reject or
  migrate tokens based on this value.
- Region request context is mandatory. A valid `ri` request parameter wins for that request. If `ri`
  is missing, the system redirects to a valid `ri` value; optional context keys are not backfilled
  into URLs. `lx`, `ct`, and `tz` are optional; when valid and present they affect only the current
  request's `Actor.preferences` overlay.
- Preference-changing HTML and JSON actions that update language, region, timezone, theme, currency,
  date format, time format, motion, density, items per page, cookie consent, or explicit resets must
  reload the shared preference record and reissue the preference access token before returning the
  response.
- Logged-in HTML preference edit screens must refresh the current surface preference token from the
  actor-local preference DB before `Actor.preferences` is initialized for the request. This is a
  screen-entry sync, not a generic fallback for broken JWTs.
- Preference access tokens carry a `jti` claim. Do not check the `jti` against the database in the
  normal Rails runtime read path; doing so turns the JWT into a database lookup ticket instead of a
  runtime cache. Database-backed `jti` checks belong only to refresh, write, repair, or other
  explicitly bounded flows.
- Extended option values are fixed reference-table rows with foreign keys for each shared/local
  preference prefix: `App`/`User`, `Org`/`Staff`, and `Com`/`Visitor`. The `User` and `Staff`
  prefixes are storage compatibility names for the current app and org local preference tables;
  runtime actors are `Client` and `Operator`.
- The `/web/v0/theme` and `/web/v0/cookie` JSON endpoints provide the no-full-page-reload update
  path for dark mode and cookie consent. They update the matching preference record when a valid
  preference access token identifies it, then issue a fresh preference access token.
- Shared preference credential cookie names are scoped by surface (`app_preference_*`,
  `com_preference_*`, `org_preference_*`) even though their domain remains apex-scoped. This keeps
  `AppPreference`, `ComPreference`, and `OrgPreference` token lifecycles independent on the same
  acme. The legacy unscoped access cookie is accepted only when its JWT `preference_type` matches
  the current surface.

## Remaining Follow-ups

- Re-login reconciliation strategy is recorded in
  `adr/preference-relogin-reconciliation-record-recency.md`.
- Legacy duplicate model cleanup is tracked in
  `plans/backlog/legacy-preference-models-retirement-plan.md`; the obsolete `user_app_preferences`
  and `staff_org_preferences` bridges have been retired.
- Future database placement changes must be handled by their own migration plans; this document
  describes the current accepted layout.

## Open Questions

- Should shared preference keep a full history, or only the latest state?
- Should logout clear the local copy, or only stop writing to it?
- Should `App`, `Org`, and `Com` use the same shared schema forever, or should each surface keep a
  separate shape?
- Should activity records stay near the `com_setting` database, or move to a separate audit surface
  later?
- Should sync recovery always use the surface-matched local preference, or should the action type
  decide first?
