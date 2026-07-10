# Restoration B2: SettingPreference — Remove Polymorphic Owner

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/setting-preference-remove-polymorphic-owner.md`

## Goal

Replace the polymorphic owner association with explicit FK columns (per-owner-type table or
per-owner-type FK column on a single table — follow the ADR's choice).

## Key surface

`SettingPreference` model, fixtures, any code that creates/queries preferences.

## Verification

Migration is reversible. Existing preference records (if any) round-trip through the new shape. No
model still references the polymorphic `owner_type` / `owner_id` columns after the migration.

## Adaptation notes

Make the fixtures valid against the new shape as part of this work.
