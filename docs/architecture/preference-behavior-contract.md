# Preference Behavior Contract

This document records the expected behavior of Umaxica preference state across
anonymous, signed-in, signed-out, and surface-switching requests. Preferences
are UX state only. They must not be used as evidence for authentication,
authorization, user presence, step-up, operator status, account selection,
organization selection, avatar selection, or access to those records.

## Inventory

| Area | Current implementation |
| --- | --- |
| Surface preference roots | `AppPreference`, `ComPreference`, `OrgPreference` |
| Local actor preference roots | `ClientPreference`, `OperatorPreference`, `VisitorPreference` |
| Runtime read value | `Actor::Preference` |
| Shared read/write concerns | `PreferenceBase`, `PreferenceGlobal`, `PreferenceCore`, `PreferenceResourceSync`, `PreferenceAdoption`, `PreferenceWebCookieActions`, `PreferenceWebThemeActions` |
| Cookie/token helpers | `PreferenceCookieName`, `PreferenceCookieWriter`, `PreferenceToken`, preference access/refresh token transports |
| Web JSON endpoints | `/web/v0/cookie`, `/web/v0/theme` on base/auth/core app/com/org surfaces |
| HTML preference endpoints | Base app/com/org `/preference/*` controllers |
| Tests covering this contract | `test/controllers/base/preference_authority_slice_1f_test.rb`, `test/controllers/*/*/web/v0/cookie_controller_test.rb`, `test/integration/routes/core_route_contract_test.rb`, preference concern tests |

## Authority Order

Signed-in preference writes are database-canonical. A valid database-backed
preference record wins over request parameters, request-local overlays,
JavaScript-readable cookies, and client self-reporting.

Authority order for effective UX reads:

1. Signed-in database preference for the current actor and surface.
2. Valid preference access token for the current surface.
3. Guest-safe request overlay for the current request only.
4. Guest-safe JavaScript-readable display cookie.
5. Built-in defaults.

Request overlays and JavaScript-readable cookies may affect the current
rendered request, but they must not overwrite signed-in canonical database
preference records. Broken, stale, cross-surface, or missing cookies fall back
to guest-safe defaults or the signed-in database state.

## Merge Contract

Anonymous state may be adopted into signed-in state only for guest-safe UX
fields:

| Field | Anonymous to signed-in merge | Reason |
| --- | --- | --- |
| Language | Allowed | UX display preference |
| Timezone | Allowed | UX display preference |
| Theme | Allowed | UX display preference |
| Cookie banner display suppression | Allowed | Display helper only |
| Display region | Allowed only as a UX/display setting | Must not imply authorization or residency |

The following fields must never be overwritten from client-side anonymous
state:

| Field class | Merge rule |
| --- | --- |
| Account, organization, avatar, operator, member, admin, or staff context | Forbidden |
| Security preferences, step-up state, verification state, DBSC binding state | Forbidden |
| Consent audit evidence or legal consent record | Forbidden |
| Authorization, entitlement, user presence, or session state | Forbidden |

## Surface Matrix

| Surface | Model authority | Web cookie endpoint | Theme endpoint | HTML preference update | Notes |
| --- | --- | --- | --- | --- | --- |
| app | `AppPreference` plus actor-local app preference records | `/web/v0/cookie` | `/web/v0/theme` | Base app `/preference/*` | End-user UX only |
| com | `ComPreference` plus visitor/corporate preference records | `/web/v0/cookie` | `/web/v0/theme` | Base com `/preference/*` | Public/corporate UX only |
| org | `OrgPreference` plus operator/staff preference records | `/web/v0/cookie` | `/web/v0/theme` | Base org `/preference/*` | Staff UX only; not operator proof |

`base` owns OP, Authorization Server protocol routes, identity authority, and
the browser preference HTML authority. `auth` owns credential ceremony and
sign-related relying-party UI. `core` owns the Rails browser API/BFF boundary.
The cookie and theme JSON endpoints remain in `/web/v0` on each surface.

## State Transitions

| State | Expected behavior |
| --- | --- |
| Anonymous without cookie | Use defaults. `/web/v0/cookie` returns `show_banner: true` or `false` as a boolean. |
| Anonymous with valid preference cookie | Use only guest-safe values from the current-surface token/cookie. |
| Anonymous with invalid or stale cookie | Ignore the broken value and fall back to guest-safe defaults; do not raise to the user. |
| Login with existing DB preference | DB preference remains canonical; anonymous self-report cannot overwrite it. |
| Login without DB preference | Create or load the surface preference through the existing preference adoption/sync path; only guest-safe fields may be adopted. |
| Login with conflicting anonymous preference | DB canonical fields win. Only allowed guest-safe fields may be merged by an explicit sync path. |
| Signed-in update | Update allowlisted preference fields only, refresh the preference token, and keep authorization/CSRF protections. |
| Logout | Delete auth/session state. Keep only guest-safe display state such as language, timezone, and theme. Downgrade any personalized, account, org, avatar, operator, security, or context-looking state to guest-grade. |
| Logged-out revisit | Render from guest-safe cookie or defaults only; do not show previous-user personalized context. |
| app/com/org surface change | Surface-specific preference token and model must be used. Cross-surface cookies must not become canonical. |

## Cookie Consent

`GET /web/v0/cookie` returns a JSON object containing only a boolean banner
decision: `show_banner: true` or `show_banner: false`.

`PATCH /web/v0/cookie` performs the update side effect and returns `204 No
Content` on success. A JavaScript-visible `preference_consented` cookie is a
display helper for banner suppression. It is not legal consent evidence, not
authorization evidence, and not a security signal. Consent that needs audit or
legal retention must be stored in a durable database or event/audit record with
an explicit owner and retention policy.

## Security Negative Cases

Regression coverage should include:

| Case | Expected result |
| --- | --- |
| CSRF on preference-changing requests | Rejected by the normal Rails protections. |
| GET mutation | No preference database state changes. |
| Request parameter tampering | Invalid or unexpected values are ignored or rejected by allowlists. |
| Cookie tampering | Broken preference cookies do not overwrite DB state. |
| Stale cookie replay | Stale anonymous state does not beat signed-in DB canonical state. |
| Cross-surface cookie confusion | app/com/org preference tokens remain surface-specific. |
| Host confusion | Current host selects the current surface; cookies do not switch authority. |
| Logged-out previous-user leakage | Previous user context is not visible after logout. |
| Anonymous cookie overriding DB preference | Forbidden and covered by regression tests. |
| Mass assignment | Unexpected keys and nested params are not accepted as preference writes. |
| Invalid enum or option value | Rejected or normalized through the option table/allowlist. |
| Race during login sync | Unique constraints and explicit sync paths prevent duplicate canonical preferences. |
| Parallel PATCH updates | Last valid write may win, but writes must remain scoped and authorized. |
| Missing authorization on signed-in update | Rejected by the normal controller/policy pipeline. |
| Cache leakage | Effective preferences must not be cached across users or surfaces. |

## Maintainability Rules

Preference read, write, merge, cookie update, and logout downgrade behavior
must stay in shared concerns/services or model-level contracts, not copied into
surface controllers. Controller logic should remain HTTP-oriented.

When a new preference field is added, update:

1. The relevant model and option/reference table.
2. The read/write allowlist.
3. Anonymous-to-signed-in merge policy.
4. Logout downgrade policy.
5. Contract or regression tests for DB canonical versus cookie/request state.
6. This document when the field changes the behavior contract.
