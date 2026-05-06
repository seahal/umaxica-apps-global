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

**Status: IMPLEMENTED (design decision pending)**

`Preference::Adoption` concern implements `updated_at`-based field-by-field sync (language, region,
timezone, theme, cookie consent). The open question — whether to keep `updated_at`-based
reconciliation or move to true field-level merge — remains unanswered.

## Improvement Points (2026-04-07 Review)

- Add concrete product examples that show where record-level reconciliation is acceptable and where
  field-level merge is required.
- Turn the open questions into an explicit decision record once the desired behavior is chosen, then
  add regression tests for the selected merge rule.
