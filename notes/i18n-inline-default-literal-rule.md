# ADR Note: Inline I18n Default Literal Rule

## Status

Accepted note (2026-04-17)

## Summary

Literal string defaults in `t()` / `I18n.t()` are prohibited in repository code.

Examples of prohibited usage:

- `t("some.key", default: "Inline text")`
- `I18n.t("some.key", default: "Inline text")`

Allowed exceptions:

- `default: :fallback_key`
- `default: nil` when the caller explicitly handles `nil`

## Reason

Translation text must remain auditable and centralized in locale YAML files under `config/locales/`.

Inline literal defaults make translation coverage difficult to audit and can hide missing keys from
normal translation validation.

## Scope

This rule applies to repository code, including:

- `app/`
- `engines/`
- `lib/`
- views and helpers where `t()` or `I18n.t()` is used

The implementation scope must be defined from current repository search results, not from a stale
example list in an old plan.

## Implementation Guidance

- Treat the current code search result as the source of truth for violations.
- Do not rely on historical file examples or pre-engine-split paths.
- Move inline literal translation text into locale YAML files.
- Keep the translation key stable where possible.

## Migration-Phase Handling

Inline I18n default literal cleanup is handled opportunistically during migration work.

Rules for the migration phase:

- when a touched file contains a prohibited literal `default:` value, correct it as part of the same
  change
- untouched files do not block unrelated migration work
- new code must not introduce new literal string defaults
- if migration work exposes a broken or missing translation contract in a touched file, fix it in
  the same change instead of carrying the violation forward

## Regression Policy

For the current cleanup phase, a dedicated regression test is optional and may be deferred.

This cleanup can be handled as a broad, potentially breaking contract correction. Temporary breakage
during the migration is acceptable as long as the final result removes literal inline defaults from
the intended scope.

## Related

- `AGENTS.md`
- `plans/archive/fix-i18n-inline-defaults.md`
