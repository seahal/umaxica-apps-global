# Restoration F2: Theme Preference Cookie + Param Contract (`ct`)

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/theme-preference-cookie-and-param-contract.md`

## Goal

Theme (`ct`) preference uses the cookie + param contract documented in the ADR.

## Key surface

`ApplicationController`, layout that reads the resolved theme, cookie writer.

## Verification

Request spec that flips theme via param, confirms cookie is written, and that subsequent requests
pick up the cookie.
