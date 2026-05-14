# Preference Architecture

## Purpose

The preference system has two different roles.

- `AppPreference`, `OrgPreference`, and `ComPreference` hold shared login and boundary state.
- `UserPreference`, `OperatorPreference`, and `VisitorPreference` hold per-account local settings.

The system must keep these roles separate.

## Scope

### Shared preference

Shared preference is the source of truth for login-state data and cross-surface state.

- It belongs to the `App` / `Org` / `Com` surfaces.
- It stores the current token-like preference state.
- It is used before login and after logout.

### Local preference

Local preference is the source of truth for account-local settings.

- It belongs to the `User` / `Operator` / `Visitor` records.
- It stores per-account language, region, timezone, and theme settings.
- It is kept in each domain database.

## Synchronization Rules

The system uses explicit sync rules.

### Before login

- Write preference changes to `AppPreference`, `OrgPreference`, or `ComPreference`.
- Do not depend on local preference data.

### During login

- Write the same user-visible preference data to both shared preference and local preference.
- Keep the values aligned by explicit sync.
- If both sides already exist, reconcile by parent-record recency: the newer parent preference
  record wins as a whole record. This is intentional until the schema has per-field change metadata.

### During logout

- Write only to shared preference.
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

The local preference records also must stay isolated inside the matching preference bubble.

- `UserPreference` stays in the principal database.
- `OperatorPreference` stays in the operator database.
- `VisitorPreference` stays in the setting database.

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
- `app` uses the external HMAC scope `client` while it still updates the current `UserEmail` model.
- `com` uses `VisitorEmail`; `org` uses `OperatorEmail`.
- `GET /preference/email/:id/edit` renders a confirmation page and does not change state.
- `DELETE /preference/email/:id` and Gmail one-click `POST /preference/email/:id` set
  `promotional` to `false` idempotently.

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

`ri` is special because it is required request context. A valid explicit `ri` request parameter wins
for the current request. If `ri` is missing or invalid on a GET or HEAD request, the controller
redirects to the same route with a valid `ri` value. The redirect value comes from persisted
preference context when available, then falls back to `jp`. Persisted preference must not override a
valid explicit `ri`.

`lx`, `ct`, and `tz` are optional request context. They are only propagated when explicitly present
and valid. If they are missing, the request uses persisted preference context, then safe defaults,
without adding those optional keys back to generated URLs. On GET and HEAD requests, invalid or blank
optional context parameters are removed from the query string by redirect.

Supported optional request values:

- `lx`: `ja`, `en`
- `ct`: `li`, `dr`, `sy`, or their long forms `light`, `dark`, `system`
- `tz`: `utc`, `etc/utc`, `jst`, `asia/tokyo`

Examples:

- `/configuration?ri=jp&lx=en` uses English for that request.
- `/configuration?ri=jp&lx=kr` redirects to `/configuration?ri=jp`.
- `/configuration?ri=jp&ct=purple&tz=Mars/Base` redirects to `/configuration?ri=jp`.
- `/configuration` redirects to `/configuration?ri=jp`, but does not add `lx`, `ct`, or `tz`.

## Implementation Notes

- `Preference::ClassRegistry` decides which preference class is active.
- `Preference::Adoption` performs the login-time sync between shared and local preference.
- `Preference::Core` reads and updates the current preference snapshot.
- `Preference::StorageAdapter` handles dual-read and dual-write while the setting DB path is active.
- `Actor::Preference` is the runtime read interface for request code. It is built from the
  actor-side preference record when one exists, otherwise from the access-token `prf` claim, then
  falls back to safe defaults. Request code reads the resolved value through `Actor.preference`.
- Auth access tokens carry the preference snapshot in the `prf` claim with stable short keys.
  Localization and theme use `lx`, `ri`, `tz`, and `ct`. Extended options use `cu` for currency,
  `df` for date format, `tf` for time format, `mo` for motion, `dn` for density, and `ipp` for
  items per page.
- Region request context uses explicit-parameter precedence. A valid `ri` request parameter wins
  for that request. If `ri` is missing, the system falls back to the persisted preference context,
  then to the default region `jp`. Persisted preference must not override an explicitly supplied
  `ri`.
- Preference-changing HTML and JSON actions that update language, region, timezone, theme, currency,
  date format, time format, motion, density, items per page, cookie consent, or explicit resets must
  reload the shared preference record and reissue the preference access token before returning the
  response.
- Extended option values are fixed reference-table rows with foreign keys for each shared/local
  preference prefix: `App`/`User`, `Org`/`Staff`, and `Com`/`Visitor`.
- The `/web/v0/theme` and `/web/v0/cookie` JSON endpoints provide the no-full-page-reload update
  path for dark mode and cookie consent. They update the matching preference record when a valid
  preference access token identifies it, then issue a fresh preference access token.

## Remaining Follow-ups

- Re-login reconciliation strategy is recorded in
  `adr/preference-relogin-reconciliation-record-recency.md`.
- Legacy duplicate model and bridge cleanup is tracked in
  `plans/backlog/legacy-preference-models-retirement-plan.md`.
- Future database placement changes must be handled by their own migration plans; this document
  describes the current accepted layout.

## Open Questions

- Should shared preference keep a full history, or only the latest state?
- Should logout clear the local copy, or only stop writing to it?
- Should `App`, `Org`, and `Com` use the same shared schema forever, or should each surface keep a
  separate shape?
- Should activity records stay in the setting database, or move to a separate audit surface later?
- Should sync recovery always use the surface-matched local preference, or should the action type
  decide first?
