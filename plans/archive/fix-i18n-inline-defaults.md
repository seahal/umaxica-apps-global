# Fix Inline `default:` Strings In `t()` / `I18n.t()` Calls

## Status

Superseded (2026-04-17)

## Why This Plan Was Retired

This plan is no longer suitable as an implementation source of truth.

Problems found during later review:

- example file paths no longer matched the engine-based repository layout
- several listed violations had already been fixed
- the listed examples did not represent the full current violation set
- the regression-test strategy was left open-ended

## What Remains Valid

The underlying rule remains valid:

- literal string defaults in `t()` / `I18n.t()` are prohibited
- locale text must live in YAML files
- `default: :fallback_key` and `default: nil` remain allowed exceptions

## Replacement Source Of Truth

Use current repository search results plus the accepted rule note:

- `adr/notes/i18n-inline-default-literal-rule.md`

Do not use the old example file list in this retired plan as an implementation checklist.
