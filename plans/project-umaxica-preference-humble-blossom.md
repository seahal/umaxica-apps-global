# Preference Lifecycle Security Audit — Umaxica

## Context

This is an investigation/documentation task only (no code changes). The goal is to determine whether
the following security invariant holds across sign-in, sign-up, and sign-out on the app/org/com
surfaces:

> サインアウト後のブラウザPreferenceは、過去のprincipalから完全に切り離される。機密性の低い表示Preferenceはブラウザ内で継続できる。再サインイン時は既存principalと安全に統合される。サインアップ時は新規default値が既存ブラウザPreferenceを誤って上書きしない。Preferenceの値は認証・認可・principal識別へ逆流しない。

Three parallel Explore passes covered (1) Preference models/schema/dual-write, (2) sign-in/up/out
controllers across app/org/com, (3) preference-specific JWT claims and cookie attributes. Findings
below are cited to file:line; anything not directly observed is marked `Assumption`.

---

## 1. Confirmed architecture

Two tiers of Preference persistence, in separate physical databases, synced by explicit application
code (no DB replication):

- **Token-scoped ("source")**: `AppPreference` (`app_setting` DB), `ComPreference` (`com_setting`),
  `OrgPreference` (`org_setting`) — one row per browser/device, keyed by refresh-token/`jti`, not by
  user identity. `app/models/app_preference.rb:49` etc.
- **Principal-scoped ("mirror")**: `ClientPreference` (`app_principal`, belongs_to `Client`),
  `OperatorPreference` (`org_principal`, belongs_to `Operator`), `VisitorPreference`
  (`com_principal`, belongs_to `Visitor`) — 1:1 with account. `app/models/client_preference.rb:40`,
  `operator_preference.rb:40`, `visitor_preference.rb:40`.
- Each parent has ~11 child tables (language/timezone/region/theme/currency/date_format/
  time_format/motion/density/page_size/adult_content_gate) plus per-type option lookup tables.

```text
Browser
  ↓ (preference_access / preference_refresh / preference_dbsc cookies)
PreferenceToken JWT (SecurityJwtPreferenceTokenCodec, ES384, typ=preference-access-token)
  ↓
AppPreference / ComPreference / OrgPreference   (token-scoped, anonymous-capable)
  ↔ PreferenceAdoption#sync_preferences!  (login-time, per-key updated_at LWW)
ClientPreference / OperatorPreference / VisitorPreference  (principal-scoped mirror)
  ↓
Public non-HttpOnly cookies (ct/language/tz/cu/df/tf/mo/dn/ps/preference_consented)
  + JSON response payload (preference_response_payload)
```

Registry of key names / child types: `PreferenceClassRegistry::CHILD_RECORD_TYPES`
(`app/controllers/concerns/preference_class_registry.rb:7`). Inbound Strong Params allowlist:
`preference_core.rb:373-426`. Outbound allowlist: `preference_response_payload`
(`preference_core.rb:351`).

Preference JWT claims (`security_jwt_preference_token_codec.rb:126-140`):
`preferences, host, preference_type, public_id, jti, typ, iss, aud, iat, exp`. No role, org_id, or
PII claims; `public_id` is the _preference record's_ own id, not a principal/account id.

Cookie attributes: access/refresh/dbsc are HttpOnly (`preference_base.rb:1004-1010`, `:1044-1049`,
`:1051-1056`); public option cookies are explicitly non-HttpOnly, apex `domain: true`
(`preference_cookie_writer.rb:9-17`). `__Host-` prefix applied to access/refresh/dbsc names in
production only (`preference_cookie_name.rb:54-58`).

---

## 2. Central finding: sign-out does not detach or rotate preference tokens

- `authentication_cookie_store.rb:28-36` `clear_auth_cookies!` deletes only `ACCESS_COOKIE_KEY`,
  `REFRESH_COOKIE_KEY`, and the auth DBSC cookie. It never calls `clear_preference_auth_cookies!`.
- `auth/app/sign/outs_controller.rb:62-65` (`clear_sign_cleanup_state!`, same pattern in com/org)
  deletes only `AuthenticationBase::REFRESH_COOKIE_KEY`, then calls `logout_current_session!`.
- `authentication_logoutable.rb:25-43` `logout_current_session!`'s `ensure` block calls
  `clear_auth_cookies!`, `Actor.clear`, `reset_session` — no preference-cookie or preference-record
  touch anywhere in this path.
- Every call site of `clear_preference_auth_cookies!` (`preference_base.rb:1058-1066`) is a
  preference-refresh failure/replay/binding-denied branch (`preference_access_token_issuer.rb:40`,
  `preference_core.rb:634`, `preference_refresh_token_transport.rb:197`,
  `preference_base.rb:834/848/911`) — never a sign-out path.
- Net effect: the `preference_access`/`preference_refresh`/`preference_dbsc` cookies and the
  underlying `jti`/refresh-token binding to the (now-signed-out) principal's mirror preference
  record survive sign-out untouched. The next unauthenticated request on that browser continues to
  resolve preferences via the same still-valid token (`load_preference_record_from_refresh_token!`,
  e.g. `core/app/edge/v0/cookies_controller.rb:37`).
- What _is_ still true: the preference JWT itself carries no principal/account identifier (see §1) —
  so this is not principal-identity leakage into the JWT. But it is an **unrevoked
  token-fixation-adjacent condition**: nothing forces a new `jti`/refresh token at logout, so if
  `sync_preferences!`'s per-key merge later runs again at a future sign-in with the _same_ browser,
  the guest-period edits ride on the same preference row that was live during the authenticated
  session, rather than a freshly detached guest identity.

This directly contradicts the target invariant's "同期対象は失効/detach" expectation and is the top
finding of this audit.

---

## 3. Sign-in merge (`PreferenceAdoption`) — CONFIRMED by direct read

`app/controllers/concerns/preference_adoption.rb` (full file read, not just Explore summary):

- `adopt_preference_for!(resource)` (line 15), invoked from `authentication_base.rb:498` inside
  `issue_login_tokens_within_lock`. Rescues `StandardError` and only logs — **does not block login
  on merge failure** (lines 23-25).
- **`sync_preferences!` (lines 97-111) is confirmed to be whole-record, NOT per-key**: it compares
  `@preferences.updated_at` vs. `resource_pref.updated_at` exactly once (lines 98-101), then calls
  `copy_preference_values!` which iterates `CHILD_RECORD_TYPES` and unconditionally overwrites
  **every** child key on the loser side with the winner's value (lines 114-156), plus flat columns
  (`copy_flat_preference_values!`, line 153/253) and cookie-consent fields (line 154/218). There is
  no per-child `updated_at` read anywhere in this method — `target_child`'s own `updated_at` is
  never consulted, only overwritten (`touch_target!`, line 155/310).
  **`explicit_fields`/`PreferenceExplicitFields` is never referenced anywhere in this file** —
  confirmed absent, not merely unconfirmed.
- Net effect confirmed: a guest editing one field (e.g. theme) after the principal side was last
  touched will, on next sign-in, silently overwrite the principal's language/ timezone/currency/etc.
  back to whatever the guest-side row happened to hold — not just the one changed key. This is a
  **confirmed NG** against the task's per-key merge requirement (§2.3 of the brief), independent of
  the sign-out gap in §2 above.
- No `lock_version`/optimistic-locking column exists on any Preference model or child table
  (confirmed by grep across `app/models/*preference*` and `app/controllers/concerns/preference_*`).
  Timestamp-only comparison is exposed to clock skew, same-second ties, and dual-write
  near-simultaneity with no version/sequence counter to disambiguate.
- `force_underage_r18_stopper!` (line 158) forcibly sets `adult_content_gate` to `DENY` on both
  sides when the account is under 18 — correctly applied after the (currently wholesale) copy, so
  this override cannot be bypassed by merge direction.
- Cross-database option-ID remapping by option _name_ (`resolve_cross_db_option_id`, line 203) —
  necessary because anonymous-preference DB and principal-preference DB don't share option-table
  primary keys.

### Target semantics (decided)

Per your answers: sign-out should rotate to a fresh guest token carrying only safe/low-sensitivity
values (recommended option 1); sign-in merge should become genuinely per-key, using
`explicit_fields` as the authority rather than timestamps (recommended option 1); signup default-row
creation should never be treated as an explicit user choice, again via `explicit_fields`
(recommended option 1); the last-used sign-in-method badge is browser-scoped only, dual-write to
principal Preference is prohibited (recommended option 1). These four decisions drive the
remediation plan in §9 below.

---

## 4. Sign-up inheritance — CONFIRMED

`ClientPreference`/`OperatorPreference`/`VisitorPreference` `set_defaults` runs `after_initialize`,
so a new row gets default values immediately at creation (`client_preference.rb`).
`create_resource_preference!` (`preference_adoption.rb:73-83`) creates the row and its 11 default
child records with `option_id: PreferenceClassRegistry.default_option_id(...)` (line 91) — these
defaults have a `created_at`/`updated_at` stamped at signup time, i.e. **newer** than almost any
pre-existing browser preference.

Because `sync_preferences!` (§3) is confirmed to be whole-record-`updated_at`-wins with no
`explicit_fields` consultation, the newly-created default row's `updated_at` will win against the
browser side in the vast majority of real signup timings (the row is created moments before
`sync_preferences!` runs, in the same `adopt_preference_for!` call at `authentication_base.rb:498`)
— this **confirms** the exact failure mode the task brief warned about: signup default values
silently overwriting a genuinely older browser preference (e.g. a language the user had explicitly
set for weeks before signing up). This is a **confirmed NG**, not a hypothetical.

`explicit_fields:jsonb` (`PreferenceExplicitFields`,
`app/models/concerns/preference_explicit_fields.rb:12`, present on
`AppPreference`/`ComPreference`/`OrgPreference` only — not on the principal-side mirror models)
exists precisely to mark values as user-chosen vs. auto-seeded (`mark_field_explicit!`, line 23),
but is written by other callers (theme/language/etc. edit endpoints via `preference_core.rb:302`)
and never read by `PreferenceAdoption`. This is the exact lever the remediation plan should wire in.

---

## 5. Last sign-in method badge

No such field/cookie/claim currently exists anywhere in the codebase (confirmed by all three Explore
passes independently). The only tangentially related things:

- `activity_log.rb` presenters
  (`app/presenters/{base,auth}/{app,com,org}/identity/activity_log.rb:60`) read an ad-hoc
  `auth_method` key out of an audit-log event's JSON context blob, purely for rendering a
  human-readable activity history row — not a preference, not queryable/settable outside that log
  render path.
- `last_used_at` timestamp columns exist on unrelated credential/passkey/OIDC-connection models
  (`client_secret_credential.rb:18/148`, `oidc_connection_record.rb:13`) — these describe credential
  usage recency, not "which method was used last for UX badge purposes."

This is a **greenfield design decision**, not an audit of existing broken behavior. See Grill-me §8
for the semantics question (principal-scoped vs. browser-scoped) that must be resolved before any
implementation is planned.

---

## 6. Data classification (draft — see grill-me before finalizing)

| Field                                | browser-local | principal Preference                                | dual-write       | JWT claim                     | JS-visible cookie            | HttpOnly required   | Preference-prohibited         | Chronicle-only |
| ------------------------------------ | ------------- | --------------------------------------------------- | ---------------- | ----------------------------- | ---------------------------- | ------------------- | ----------------------------- | -------------- |
| theme                                | Yes           | Yes                                                 | Yes              | Yes (short key `ct`)          | Yes                          | No                  | No                            | No             |
| language                             | Yes           | Yes                                                 | Yes              | Yes (`lx`)                    | Yes                          | No                  | No                            | No             |
| timezone                             | Yes           | Yes                                                 | Yes              | Yes (`tz`)                    | Yes                          | No                  | No                            | No             |
| currency                             | Yes           | Yes                                                 | Yes              | Yes (`cu`)                    | Yes                          | No                  | No                            | No             |
| locale/region                        | Yes           | Yes                                                 | Yes              | Yes (`ri`)                    | Yes                          | No                  | No                            | No             |
| accessibility (motion/density)       | Yes           | Yes                                                 | Yes              | Yes (`mo`/`dn`)               | Yes                          | No                  | No                            | No             |
| UI density                           | Yes           | Yes                                                 | Yes              | Yes (`dn`)                    | Yes                          | No                  | No                            | No             |
| last sign-in method (browser-scoped) | Proposed: Yes | Proposed: **No** (see §5, §8)                       | Proposed: **No** | Proposed: **No**              | Proposed: undecided (see §8) | Proposed: undecided | —                             | No             |
| principal ID                         | No            | N/A (it's the row owner FK, not a preference value) | No               | **No** (confirmed absent, §1) | No                           | —                   | Yes (as a preference _value_) | No             |
| resource ID                          | No            | N/A (FK only)                                       | No               | No                            | No                           | —                   | Yes                           | No             |
| email address                        | No            | No                                                  | No               | No                            | No                           | —                   | Yes                           | No             |
| telephone number                     | No            | No                                                  | No               | No                            | No                           | —                   | Yes                           | No             |
| organization ID                      | No            | No                                                  | No               | No                            | No                           | —                   | Yes                           | No             |
| group/role/authorization             | No            | No                                                  | No               | No                            | No                           | —                   | Yes                           | No             |
| authentication assurance / MFA state | No            | No                                                  | No               | No                            | No                           | —                   | Yes                           | No             |
| passkey credential info              | No            | No                                                  | No               | No                            | No                           | —                   | Yes                           | No             |
| provider account identifier          | No            | No                                                  | No               | No                            | No                           | —                   | Yes                           | No             |
| IP/geolocation                       | No            | No                                                  | No               | No                            | No                           | —                   | Yes                           | Yes            |
| login history                        | No            | No                                                  | No               | No                            | No                           | —                   | Yes                           | Yes            |

`adult_content_gate` is a special case: it is a Preference child field but is also a
security-relevant override target for `force_underage_r18_stopper!` — it should be treated as
dual-write but **not client-settable to a laxer value than the account's age eligibility permits**
(already enforced server-side in `preference_adoption.rb:158`, not purely a client preference).

---

## 7. Threat model — status against current code (see full per-threat table needed in

final report; summarized here)

- **5.1/5.2 Cross-account/detached-principal contamination**: **NG** per §2 — no detach, no rotation
  at sign-out. A shared-browser scenario where user A signs out and user B (or A again as guest)
  edits preferences reuses A's still-bound token until it happens to expire or fail verification on
  its own.
- **5.3 Token fixation**: **NG** — same preference refresh token persists across the sign-out
  boundary; nothing forces rotation at logout.
- **5.4 Replay**: **PARTIAL** — replay/reuse detection exists for the preference refresh token in
  general (`handle_preference_refresh_replay!`, grace window 30s, `single_use_token.rb:155-160`),
  but this protects against _stolen-token_ replay, not against the _legitimate-but-stale_
  sign-out-boundary case in §2, which isn't replay at all — it's simply never invalidated. Y
- **5.6 Timestamp ambiguity**: **PARTIAL/UNKNOWN** — no version/lock column exists anywhere
  (confirmed); granularity of the merge (parent-level vs per-key) is still an open verification item
  (§3).
- **5.8 JWT claim confusion**: **OK** — preference JWT has its own `typ`, `iss`, `aud`,
  required-claims set, decoded via a distinct codec/registry namespace
  (`security_jwt_preference_token_codec.rb`, `PreferenceJwtConfiguration`); no claim overlap with
  the main auth JWT was found.
- **5.9/5.10 Cookie scope / XSS impact**: **OK for the split itself** — HttpOnly is correctly
  applied to access/refresh/dbsc tokens; only display-value cookies are JS-visible, and those carry
  no identifiers, matching the `preference_response_payload` allowlist. `domain: true` apex-scoping
  on public cookies is a **PARTIAL** — worth confirming which subdomains can read them and whether
  that's broader than needed (open item).
- **5.13 Privilege contamination**: **OK** — no role/org/PII claim exists in the preference JWT
  (§1); `adult_content_gate` is the one field where a security decision (age eligibility) writes
  _into_ preference state rather than reading _from_ it, which is the correct direction but worth
  flagging explicitly as a documented exception.

---

## 8. Decisions (resolved via grill-me)

1. **Sign-out token rotation**: rotate to a fresh guest preference token at sign-out, copying only
   safe/low-sensitivity values (theme/language/timezone/currency/etc — no principal identifier ever
   existed in the JWT payload to strip in the first place, per §1). This requires wiring a
   rotate-with-safe-copy call into the sign-out path.
2. **Sign-in merge granularity**: per-key merge required, using `explicit_fields` as the
   authoritative signal rather than timestamps.
3. **Signup default-row disambiguation**: `explicit_fields` is authoritative — a principal-side key
   that was never marked explicit must never win against a browser-side value, regardless of
   `updated_at`.
4. **Last sign-in method badge**: browser-scoped only; dual-write to principal Preference is
   prohibited.

---

## 9. Executive verdict (draft, pending memo write-up)

| Item                                          | Verdict                                                                             | Evidence                                                                                                                                                                                                       |
| --------------------------------------------- | ----------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ゲスト/principal Preferenceの分離             | OK                                                                                  | Separate DBs/models, §1                                                                                                                                                                                        |
| サインアウト時のdetach                        | **NG**                                                                              | §2 — no code path touches preference cookies/tokens at logout                                                                                                                                                  |
| サインアウト時のtoken rotation                | **NG**                                                                              | §2 — same finding                                                                                                                                                                                              |
| サインアウト後のprincipal書き込み防止         | PARTIAL                                                                             | JWT carries no principal id (§1), but the _token itself_ stays bound to the same row that will be re-adopted at next login — not a direct write-to-principal risk, but violates the intended teardown boundary |
| 安全なPreference値の継承                      | OK today (mechanically) / **NG** target-gap                                         | Values persist across sign-out today only because nothing is torn down (§2), not by design — remediation must make this intentional                                                                            |
| サインイン時のマージ                          | **NG**                                                                              | §3 confirmed: whole-record `updated_at`-wins, not per-key                                                                                                                                                      |
| サインアップ時のブラウザPreference継承        | **NG**                                                                              | §4 confirmed: fresh default row's `updated_at` beats older browser prefs                                                                                                                                       |
| default値と明示的変更の区別                   | **NG**                                                                              | `explicit_fields` exists but is never read by `PreferenceAdoption` (§3, §4)                                                                                                                                    |
| per-key conflict resolution                   | **NG**                                                                              | Same as merge finding                                                                                                                                                                                          |
| cross-browser/cross-account contamination防止 | **NG**                                                                              | Direct consequence of §2                                                                                                                                                                                       |
| JWT claim境界                                 | OK                                                                                  | §1 — distinct issuer/audience/typ, no PII/role/org claims                                                                                                                                                      |
| Cookie scope                                  | OK (access/refresh/dbsc) / PARTIAL (public cookies, apex domain scope not narrowed) | §1, §6                                                                                                                                                                                                         |
| PII排除                                       | OK                                                                                  | Confirmed absent from JWT claims and registry allowlist                                                                                                                                                        |
| Chronicleとの責務分離                         | OK                                                                                  | §1 Explore pass 3 — durable audit table separate from `Rails.logger`, matches ADR                                                                                                                              |
| last sign-in method badgeの保存先             | N/A (not yet implemented)                                                           | Design decided in §8; see remediation §10                                                                                                                                                                      |

---

## 10. Minimal remediation plan (design only — no code changes made)

1. **Sign-out rotation** — target file: `app/controllers/concerns/authentication_logoutable.rb`
   (`logout_current_session!`, lines 25-43) and the per-surface
   `sign/outs_controller.rb#clear_sign_cleanup_state!`. Add a call, before or alongside
   `clear_auth_cookies!`, to rotate the current preference token: read safe fields off
   `@preferences` (theme/language/timezone/currency/date_format/time_format/motion/
   density/page_size — NOT cookie-consent flags, which are themselves a legal-consent state tied to
   disclosure at a point in time and should be re-affirmed by the new guest identity per typical
   consent-lifecycle practice), then call something equivalent to `create_new_preference_record!`
   (already exists, `preference_refresh_token_transport.rb:113-162`) seeded with those values, and
   clear the old cookies via the existing `clear_preference_auth_cookies!`
   (`preference_base.rb:1058-1066`). Needs no migration or schema change — reuses existing methods.
2. **Per-key merge** — target file: `preference_adoption.rb#sync_preferences!` (97-111) and
   `copy_preference_values!` (114-156). Replace the whole-record `updated_at` comparison with a
   per-`CHILD_RECORD_TYPES`-entry decision: if the principal side's corresponding `explicit_field?`
   (currently only tracked on `AppPreference`/`ComPreference`/`OrgPreference`, not on the mirror
   models — needs a parallel `explicit_fields` column or equivalent flag on
   `ClientPreference`/`OperatorPreference`/`VisitorPreference`, i.e. **a migration is required** for
   this) is true, the principal value wins; otherwise the browser value wins if present.
   `force_underage_r18_stopper!` remains an unconditional post-merge override.
3. **Signup default disambiguation** — same mechanism as (2): `create_resource_preference_options!`
   (`preference_adoption.rb:85-94`) must mark newly-seeded default child rows as NOT explicit, so
   the per-key merge in (2) naturally treats them as losing to any existing browser value.
4. **Last sign-in method badge** — new browser-scoped-only field. Given the decision to forbid
   dual-write to principal Preference, this should NOT be added to the existing
   `AppPreference`/`ComPreference`/`OrgPreference` JWT payload (that record round-trips through
   `PreferenceAdoption` at login, which is exactly the dual-write path being forbidden). Recommend a
   **separate signed (not encrypted, not JS-readable via HttpOnly) Rails cookie**, scoped per
   sign-in surface (app/org/com kept separate, not shared), written only on successful
   primary-authentication completion (never on MFA step, never on step-up), with an explicit
   allowlist of valid values and TTL. This keeps it fully outside the existing Preference JWT/DB
   path — no schema change to Preference tables, no migration needed, new controller-level cookie
   write only at the point sign-in success is recorded (`authentication_base.rb:518` `LOGGED_IN`
   audit site is the natural anchor).

Each step above needs: migration plan (only step 2 requires one — new column on the 3 mirror
models), backward compatibility (steps 1/3/4 need none since they're additive behavior; step 2 needs
the new column defaulted to a safe value for existing rows — recommend defaulting existing principal
values to "explicit" so no existing user's already-diverged data gets silently overwritten by a
stale browser row on next login), rollout order (2 and 3 must ship together since 3 depends on the
same flag semantics introduced in 2; 1 and 4 are independent), and regression tests per §11 below.

---

## 11. Test plan (draft list, matches brief §9.8 checklist)

- Guest Preference edit persists without a principal.
- Signup inherits pre-existing browser values for keys the browser had explicitly set;
  default-seeded principal values never override an existing browser value.
- Sign-in merge: per-key, not whole-record — one browser-changed key updates only that key on the
  principal side, leaving other principal-side explicit values untouched.
- Same-timestamp tie: with per-key/explicit-flag merge, tie-breaking no longer depends on timestamp
  ordering at all, removing this class of flakiness.
- Multiple browsers signing into the same principal: last browser to sign in should not clobber keys
  the principal had explicitly set from another browser, if per-key explicit-flag merge is
  implemented as designed.
- Different principal signs in on a browser previously used by another principal: confirm the
  rotated guest identity (post sign-out fix) is what's adopted, not a stale binding.
- Shared browser: sign-out then guest edit then different principal signs in — confirms the sign-out
  rotation (item 1) actually breaks the chain described in §2.
- Sign-out rotates the preference token (new cookie/jti; old token cookie deletion confirmed via
  existing `clear_preference_auth_cookies!` assertions).
- Replayed pre-sign-out preference token is rejected after rotation.
- No principal identifier ever appears in a guest/post-signout preference JWT (already true today
  per §1 — regression-guard test to keep it true).
- Last sign-in method badge: written only on successful primary auth, never on MFA failure or
  step-up; never present in principal Preference records; scoped per surface.
- Preference write failures do not affect authentication success (already true per
  `adopt_preference_for!`'s rescue at line 23-25 — regression-guard test to keep it true, since
  making it fail-open on the security-relevant merge-authority column changes in item 2 must not be
  allowed to silently regress into "any merge failure breaks login").

---

## 12. Documentation plan

Per repository convention, write the full audit report (verdict table, evidence matrix, threat
model, state-transition diagrams/tables, remediation steps) as a dated Japanese memo under `memos/`
(not `memo/`) — see [[feedback_save_plan_reports_to_memos]] and [[feedback_japanese_docs]]. This
plan file is the working scratchpad; the memo is the durable deliverable once this plan is approved.
