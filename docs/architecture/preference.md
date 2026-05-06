# Preference Architecture

## Purpose

The preference system has two different roles.

- `AppPreference`, `OrgPreference`, and `ComPreference` hold shared login and boundary state.
- `UserPreference`, `StaffPreference`, and `CustomerPreference` hold per-account local settings.

The system must keep these roles separate.

## Scope

### Shared preference

Shared preference is the source of truth for login-state data and cross-surface state.

- It belongs to the `App` / `Org` / `Com` surfaces.
- It stores the current token-like preference state.
- It is used before login and after logout.

### Local preference

Local preference is the source of truth for account-local settings.

- It belongs to the `User` / `Staff` / `Customer` records.
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
- `Org` -> `StaffPreference`
- `Com` -> `CustomerPreference`

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

The local preference records also must stay isolated.

- `UserPreference` stays in the principal database.
- `StaffPreference` stays in the principal database.
- `CustomerPreference` stays in the guest database.

## Shared Fields

The sync path should only move the allowlisted user-facing fields.

- `language`
- `region`
- `timezone`
- `theme`
- cookie consent fields when they are part of the active session state

The sync path must not copy unrelated data.

- authentication secrets
- identity documents
- billing data
- moderation data
- message content
- operational audit payloads

## Implementation Notes

- `Preference::ClassRegistry` decides which preference class is active.
- `Preference::Adoption` performs the login-time sync between shared and local preference.
- `Preference::Core` reads and updates the current preference snapshot.
- `Preference::StorageAdapter` handles dual-read and dual-write while the setting DB path is active.

## Open Questions

- Should shared preference keep a full history, or only the latest state?
- Should logout clear the local copy, or only stop writing to it?
- Should `App`, `Org`, and `Com` use the same shared schema forever, or should each surface keep a
  separate shape?
- Should activity records stay in the setting database, or move to a separate audit surface later?
- Should sync recovery always use the surface-matched local preference, or should the action type
  decide first?
