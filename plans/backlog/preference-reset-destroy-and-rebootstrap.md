# Preference Reset Destroy and Rebootstrap

## Status

Backlog. Do not implement during the current QA stabilization pass unless explicitly promoted.

## Problem

The current sign preference reset flow behaves like "restore defaults":

- shared surface preference rows (`AppPreference`, `ComPreference`, `OrgPreference`) stay in place;
- actor-local preference rows (`ClientPreference`, `VisitorPreference`, `OperatorPreference`) stay
  in place when present;
- child preference rows stay in place and their `option_id` values are updated to defaults;
- consent fields are updated to false/nil;
- a new preference access token is issued for the same preference record.

The desired next-phase behavior is closer to "destroy current preference state and bootstrap a new
visit":

- remove or retire the current shared preference record for the active surface;
- when signed in, remove or retire the matching actor-local preference record;
- clear preference access, refresh, DBSC, and request-context cookies;
- then create a fresh preference record using the same path used for a new visitor.

## Desired Behavior

For each sign surface:

- app: reset destroys/retires `AppPreference`; if signed in, also destroys/retires
  `ClientPreference`.
- com: reset destroys/retires `ComPreference`; if signed in, also destroys/retires
  `VisitorPreference`.
- org: reset destroys/retires `OrgPreference`; if signed in, also destroys/retires
  `OperatorPreference`.

After old state is cleared, the flow should:

- clear surface-scoped preference cookies:
  - `<surface>_preference_access`;
  - `<surface>_preference_refresh`;
  - `<surface>_preference_dbsc`, when present.
- clear preference context cookies/overlays for values such as `ct`, `tz`, `lx`, and `ri` where they
  are stored in browser cookies.
- reset controller instance state such as `@preferences`, `@preference_payload`,
  `@refresh_token_value`, `@refresh_presented_digest`, and `@refresh_public_id`.
- create a new preference record via the existing new-visitor path, preferably
  `create_new_preference_record!` after state has been cleared.
- issue fresh refresh/access cookies for the new record.
- redirect to the same-surface `/preference`.

## Existing Hooks to Reuse

The current preference concerns already contain most of the rebootstrap path:

- `ensure_preferences_record`
- `load_preference_record_from_refresh_token!(create_if_missing: true)`
- `create_new_preference_record!`
- `create_preference_options`
- `set_refresh_token_cookie`
- `issue_access_token_from`
- `clear_preference_auth_cookies!`

Prefer extracting a reset-specific orchestration method over duplicating record creation or cookie
issuance logic.

Important caveat: `ensure_preferences_record` returns existing `@preferences` when set. A reset flow
that wants a new record must clear controller state before calling the bootstrap path, or call
`create_new_preference_record!` explicitly after old state has been retired.

## Design Decisions Needed

- Decide whether "destroy" means physical deletion or lifecycle retirement/discard.
- Confirm foreign-key and dependent behavior for shared preference child records.
- Confirm actor-local preference deletion semantics for signed-in users:
  - app: `ClientPreference`;
  - com: `VisitorPreference`;
  - org: `OperatorPreference`.
- Confirm whether deleting actor-local preference should immediately recreate actor-local defaults,
  or whether it should be recreated lazily on the next signed-in preference write/adoption event.
- Confirm exact cookie names for context cookies carrying `ct`, `tz`, `lx`, and `ri`.
- Confirm audit event vocabulary:
  - old shared preference retired;
  - actor-local preference retired, when applicable;
  - new preference token created;
  - reset completed.

## Implementation Sketch

1. Add a reset orchestration method, for example `destroy_and_rebootstrap_preference_state!`.
2. Capture the current shared preference and current actor-local preference.
3. Authorize the write using the existing preference write pipeline.
4. Retire/delete actor-local preference first when signed in.
5. Retire/delete shared preference and dependent child records according to the chosen deletion
   model.
6. Clear preference auth cookies and context cookies.
7. Clear controller preference instance variables.
8. Call the existing bootstrap path to create a new shared preference and issue cookies.
9. Redirect to the same-surface preference index.

## Tests

Add focused controller/integration coverage for app, com, and org:

- anonymous reset retires the old shared preference, clears old cookies, creates a new shared
  preference, issues new access/refresh cookies, and redirects to `/preference`;
- signed-in reset also retires the actor-local preference;
- `ct`, `tz`, `lx`, and `ri` cookie/context state is cleared;
- old access/refresh cookies cannot resolve the retired preference after reset;
- new preference has default child rows and default consent false values;
- redirect target remains same-surface `/preference`, not `/`, `/dashboard`, or a cross-surface
  path.

## Non-Goals

- Do not change ordinary preference update behavior.
- Do not change sign-in preference adoption semantics except where reset explicitly requires it.
- Do not broaden this into a full preference model cleanup; keep larger schema/model work in the
  existing preference backlog plans.
