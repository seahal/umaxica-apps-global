# GH-629: Review Re-Login Preference Reconciliation Strategy

GitHub: #629

## Summary

Decide whether re-login preference reconciliation should remain `updated_at`-based or move to a
field-level merge strategy.

## Problem

Current reconciliation compares session-like preference side with actor-owned preference side using
record recency. This is not a field-level merge.

Example risk:

- One side changes `theme`.
- The other side changes `region`.
- A later re-login may overwrite one based only on record recency.

## Questions to Answer

- Is whole-record `updated_at` reconciliation acceptable as product behavior?
- Should reconciliation become field-level for: language, region, timezone, theme, cookie consent?
- If field-level merge is required, what metadata is needed?

## Notes

This is a domain-rule change, separate from the database migration work (GH-628).

## Implementation Status (2026-04-07)

**Status: CLOSED 2026-05-10**

`Preference::Adoption` concern implements `updated_at`-based field-by-field sync (language, region,
timezone, theme, cookie consent). The open question — whether to keep `updated_at`-based
reconciliation or move to true field-level merge — remains unanswered.

2026-05-10 decision:

- Keep parent-record `updated_at` reconciliation as accepted behavior for now.
- The newer parent preference record wins as a whole record during re-login reconciliation.
- True field-level merge is deferred until the schema stores per-field change metadata for language,
  region, timezone, theme, and cookie consent.
- Decision recorded in `adr/preference-relogin-reconciliation-record-recency.md`.
- `docs/architecture/preference.md` now documents the login-time reconciliation rule.
- Regression coverage asserts that a newer actor-side preference wins as a whole record, not as a
  partial field merge.

## Improvement Points (2026-04-07 Review)

- Completed: decision record added and regression coverage fixed around the selected rule.
