# Restoration F1: Localization Preference Flow (`ri` / `lx` / `tz`)

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/localization-preference-flow.md`

## Goal

Region (`ri`), locale (`lx`), and timezone (`tz`) preferences flow through the documented precedence
(URL param > cookie > user pref > default). Apply uniformly across the global app.

## Key surface

`ApplicationController` `around_action` that sets I18n / Time.zone; the cookie jar setup; the user
preference model.

## Verification

Request specs covering each precedence rung.
