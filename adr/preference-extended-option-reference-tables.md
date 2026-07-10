# Preference Extended Option Reference Tables

## Status

Accepted on 2026-05-14.

## Context

Preference values now include display, accessibility, and locale-adjacent options beyond language,
region, timezone, and theme. These values must behave consistently on the `app`, `org`, and `com`
sign surfaces while preserving each surface boundary and each preference database boundary.

## Decision

Currency, date format, time format, motion, density, and items-per-page settings are modeled as
fixed reference-table options, not booleans or unconstrained free-form values.

The shared preference records use child option records:

- `AppPreference`, `OrgPreference`, and `ComPreference`

The local preference records use the same child option records and also keep direct snapshot columns
for account-local reads:

- `UserPreference`
- `OperatorPreference`
- `VisitorPreference`

All six prefixes participate in `Preference::ClassRegistry`, so sync, adoption, reset, token
payload, and preference UI actions use one shared path instead of per-surface branching.

## Option Sets

- `currency`: `usd`, `jpy`; default `jpy`
- `date_format`: `iso`, `uk`, `us`; default `iso`
- `time_format`: `hour_24`, `hour_12`; default `hour_24`
- `motion`: `standard`, `reduced`; default `standard`
- `density`: `standard`, `compact`; default `standard`
- `items_per_page`: `10`, `20`, `50`, `100`, `infinity`; default `20`

## Consequences

- New preference types must be added through the registry and reference-table path.
- Surface-specific controllers should remain thin and only declare the preference screen they
  expose.
- Foreign keys must protect every child option record from pointing at an unknown option.
