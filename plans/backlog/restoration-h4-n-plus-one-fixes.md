# Restoration H4: N+1 Fixes (Audit High)

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `../../adr/audit-findings-2026-03-30.md` (High severity)

## Goal

Fix the N+1 sites the audit lists. Use `includes` / `preload` per case.

## Key surface

Listing controllers / serializers the audit names.

## Verification

Each fix has a test that asserts query count (`assert_queries` or equivalent) before / after.
