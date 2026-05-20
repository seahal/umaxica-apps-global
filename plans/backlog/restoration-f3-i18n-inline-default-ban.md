# Restoration F3: i18n Inline `default:` Literal Ban

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `notes/i18n-inline-default-literal-rule.md`

## Goal

Forbid inline `default:` literal strings on `t(...)` / `I18n.t` calls. Enforce via lint rule (custom
rubocop cop or equivalent) so missing keys surface in the locale files instead of hiding behind
defaults.

## Key surface

Lint configuration; sweep through `app/views/`, `app/helpers/`, `app/controllers/` to remove inline
defaults; fill gaps in `config/locales/`.

## Verification

Lint passes; full text of every used key is present in `en` and `ja` (or whichever locales are in
scope).

## Related

- `plans/backlog/restoration-h5-japanese-hardcoded-string-sweep.md` — overlapping hardcoded JP
  string sweep.
