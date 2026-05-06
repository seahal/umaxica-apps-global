# GH-578: Consolidate Preference System Around Current::Preference and JWT Snapshots

GitHub: #578

## Summary

Consolidate the preference system around `Current::Preference`, JWT preference snapshots, and the
agreed long-term database layout.

## Scope

- Add a `prf` claim to auth tokens for preference snapshot data.
- Introduce `Current::Preference` (already implemented — verify completeness).
- Reissue access tokens when preference-changing actions require it.
- Move `app` preference data to `principal` database.
- Move `org` preference data to `operator` database.
- Keep `com` in `preference` database unless later changed.
- Consolidate old preference models and associations.
- Remove obsolete compatibility shims after the migration is complete.
- Centralize preference reads/writes behind the agreed API and request lifecycle model.

## UI Follow-up

- AJAX dark mode toggle.
- AJAX cookie consent updates.

## Acceptance Criteria

- `Current::Preference` is the runtime source of truth for the intended flows.
- Preference JWT round-trip works correctly.
- Preference writes can trigger token reissue where needed.
- Planned DB moves for app/org preference data are implemented or broken into explicit sub-steps.
- Obsolete preference models/shims are removed once no longer needed.
- Dark mode and cookie consent updates work without full page reloads.

## Source

- `docs/todo/security_and_preference_plan.md`

## Implementation Status (2026-04-07)

**Status: PARTIALLY DONE**

Done:

- `Current::Preference` implemented as immutable value object.
- JWT `prf` claim integrated in `auth/token_claims.rb`.
- `Current::Preference.from_jwt()` reconstructs preference from JWT payload.

Remaining:

- Legacy preference models (AppPreference, ComPreference, OrgPreference + 48 related models) still
  exist.
- DB moves (app → principal, org → operator) not yet completed.
- Obsolete compatibility shims not yet removed.

## Improvement Points (2026-04-07 Review)

- Map current preference models, cookies, and JWT payload writers to the target architecture before
  changing storage. The codebase is already partially consolidated, so the remaining gaps need a
  current-state inventory.
- Split UI polish, token reissue rules, and database moves into separate subtracks. They have
  different validation paths and should not block each other.
