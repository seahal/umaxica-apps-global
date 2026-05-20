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

## 2026-05-07 What to leave as current differences and improvements

Most of this issue is already in progress.

Confirmed:

- `Current::Preference` is already implemented.
- There are tests around `Auth::TokenService` and token claims.
- preference DB placement is at least app / org / com / The major moves of the customer are
  reflected in the current schema.

This document should not be left as a "grand plan to unify the entire preference" but as a parent
memo for any remaining improvements.

Improvements to leave:

- Clarify the conditions for reissuing access token/preference snapshot when preference changes.
- Converting dark mode/cookie consent to AJAX will be made independent as a UI improvement.
- Deleting obsolete shim / bridge / duplicate model Handled by
  `plans/backlog/legacy-preference-models-retirement-plan.md` side.
- Do not add new DB moves to this document. Changes to DB placement are divided into individual
  plans.

## Closed Scope (2026-05-10)

**Status: CLOSED**

The runtime consolidation range of `gh578` is closed as satisfied by the current implementation.

Confirmed:

- `Current::Preference` has been implemented as a request runtime read interface.
- Auth access token `prf` claim is issued by `Auth::TokenClaims`.
- `CurrentSupport` takes precedence over actor-side preference record, otherwise JWT `prf` claim,
  otherwise use safe default.
- The preference change action of `Preference::Core` reloads the shared preference and access
  Reissue the token.
- JSON endpoint of `/web/v0/theme` and `/web/v0/cookie` is dark mode / cookie Exists as a
  no-full-page-reload update path for consent.
- The current DB arrangement is `app` -> `principal`, `org` -> `operator`, `com` -> `setting`,
  `customer_preferences` is also on the `setting` side.
- `docs/architecture/preference.md` to current layout, JWT `prf`, token reissue rule, AJAX Updated
  according to the actual situation of endpoint.

The rest are not covered by this plan:

- The product decision for Re-login reconciliation is Handled by
  `plans/backlog/gh629-preference-reconciliation-strategy.md`.
- Deleting obsolete shim / bridge / duplicate model Handled by
  `plans/backlog/legacy-preference-models-retirement-plan.md`.
- New DB migrations are handled in separate migration plans.
