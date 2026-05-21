# Database Boundaries

## Purpose

This document records the accepted database connection naming model for surface-owned data.

## Naming Model

Surface-owned database connections use `surface_role` names.

| Surface | Principal       | Ticket       | Zenith       | Signal       | Setting       |
| ------- | --------------- | ------------ | ------------ | ------------ | ------------- |
| `app`   | `app_principal` | `app_ticket` | `app_zenith` | `app_signal` | `app_setting` |
| `org`   | `org_principal` | `org_ticket` | `org_zenith` | `org_signal` | `org_setting` |
| `com`   | `com_principal` | `com_ticket` | `com_zenith` | `com_signal` | `com_setting` |

Role meanings:

- `principal`: authenticated principal, credentials, and principal-side state.
- `ticket`: login/session/OIDC ticket persistence.
- `zenith`: Zenith/RP-facing account, identity binding, and local projection state.
- `signal`: notification-origin state for email, web push, banners, and related channels.
- `setting`: login-independent surface setting and preference state.

## Current Migration State

The implemented target mapping is:

| Current     | Target          |
| ----------- | --------------- |
| `principal` | `app_principal` |
| `mark`      | `app_ticket`    |
| `resident`  | `app_zenith`    |
| `operator`  | `org_principal` |
| `token`     | `org_ticket`    |
| `personnel` | `org_zenith`    |
| `guest`     | `com_principal` |
| `symbol`    | `com_ticket`    |
| `visitor`   | `com_zenith`    |
| `setting`   | `com_setting`   |

The session-side preference families use the surface setting databases:

| Target        | Tables                                |
| ------------- | ------------------------------------- |
| `app_setting` | `app_preferences`, `app_preference_*` |
| `org_setting` | `org_preferences`, `org_preference_*` |
| `com_setting` | `com_preferences`, `com_preference_*` |

The current `notification` connection will split into three surface signal databases:

| Target       | Tables                                         |
| ------------ | ---------------------------------------------- |
| `app_signal` | `client_notifications`, `member_notifications` |
| `org_signal` | `operator_notifications`                       |
| `com_signal` | `visitor_notifications`                        |

## Unchanged Cross-Cutting Databases

These database names remain independent cross-cutting or infrastructure boundaries:

- `cache`
- `queue`
- `storage`
- `search`
- `occurrence`
- `chronicle`
- `avatar`
- `redirector`

## Rules

- Do not introduce new surface-owned one-word connection names.
- Do not use runtime actor names as database connection names.
- Keep table renames separate from connection-name work unless an explicit migration plan requires
  both.
- Keep login-independent surface settings in the matching `*_setting` database.
- Keep actor-local preferences in the matching `*_principal` database.

## Related

- `adr/surface-database-connection-naming.md`
- `adr/actor-db-naming-policy.md`
