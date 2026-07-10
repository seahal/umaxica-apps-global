# Recovery Passcode Delivery: Investigation Report

## Context

The task is to implement recovery passcode delivery in three scenarios:

1. **Sign-up completion** — issue 10 recovery passcodes, show plaintext once.
2. **Settings: 0→1 strong credential** — after passkey/TOTP creation, top up to 10 active usable
   recovery passcodes (issue only the shortfall); do NOT require passcodes before creation.
3. **Settings: 1→n strong credentials** — same top-up behavior; require step-up before registration
   per current policy.

Invariants: never re-display existing passcodes, never store plaintext, show only newly generated
values, never log raw values, never make passcodes a precondition for the first passkey/TOTP.

This document reports the investigation findings and a recommended plan. **No implementation yet.**

---

## A. Executive Summary

| Question                                 | Answer                                                                                                                                                                                        |
| ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Existing kind/purpose to use?            | `RECOVERY = 3` (alias `ONE_TIME`) on `ClientSecretCredential` / `VisitorSecretCredential`                                                                                                     |
| New kind/purpose required?               | No — `RECOVERY` kind already exists with correct semantics                                                                                                                                    |
| Can current schema support top-up to 10? | Yes, with caveats (see below)                                                                                                                                                                 |
| Main blockers                            | (1) `SignRequiresRecoveryPasscodes` guard currently deadlocks 0→1 flow; (2) no bulk-issue service exists; (3) `IdentityOneTimeReveal` is single-value; (4) max global cap is 20, not per-kind |

---

## B. Evidence Table

### B.1 Documentation Basis

| Concern                     | Finding                                                                                   | File + Lines                                                           |
| --------------------------- | ----------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| Kind/purpose classification | `RECOVERY = 3`, alias `ONE_TIME`; `ALLOWED_FOR_SECRET_SIGN_IN = [PERMANENT, ONE_TIME]`    | `app/models/client_secret_credential_kind.rb:14–22`                    |
| Visitor kind                | Same `RECOVERY = 3`, same `ALLOWED_FOR_SECRET_SIGN_IN`                                    | `app/models/visitor_secret_credential_kind.rb:14–21`                   |
| Operator kind               | No `RECOVERY`; `ONE_TIME = NOTHING` (intentional — operators have no recovery passcodes)  | `app/models/operator_secret_credential_kind.rb:16–24`                  |
| Old spec (ADR)              | Hash-only; shown once on dedicated page; re-issuing revokes prior active passcodes        | `adr/sign-configuration-sprint-spec.md:84–93`                          |
| Sign-up doc constraint      | Passcode setup is checkpoint-owned after contact verify; do not reuse settings controller | `docs/security/sign-up-sequence.md:452–460`                            |
| Active security plan        | Recovery must leave `ALLOWED_FOR_SECRET_SIGN_IN`; separate restricted endpoint planned    | `plans/objective-recovery-secret-restricted-bootstrap-plan.md:143–176` |
| One-time reveal service     | `IdentityOneTimeReveal` — 15-min token, cache-backed, single consume, deletes on read     | `app/services/identity_one_time_reveal.rb:1–121`                       |

### B.2 Model / Data Design

| Concern                      | Finding                                                                                                                                                                                                               | File + Lines                                                                            |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| Primary model (app)          | `ClientSecretCredential`                                                                                                                                                                                              | `app/models/client_secret_credential.rb`                                                |
| Primary model (com)          | `VisitorSecretCredential`                                                                                                                                                                                             | `app/models/visitor_secret_credential.rb`                                               |
| Status constants             | `ACTIVE=1 EXPIRED=2 REVOKED=3 USED=4 DELETED=5 NOTHING=6`                                                                                                                                                             | `app/models/client_secret_credential_status.rb:14–22`                                   |
| Key fields                   | `uses_remaining` (default 1), `last_used_at`, `consumed_at`, `revoked_at`, `discarded_at`, `locked_at`, `password_digest`, `lookup_digest`, `safe_prefix`                                                             | `app/models/client_secret_credential.rb`                                                |
| Active usable count          | `SignRecoveryPasscodeRequirement#usable_unused_count` — ACTIVE + RECOVERY kind + `last_used_at IS NULL` + `uses_remaining > 0` + not discarded/purged                                                                 | `app/services/sign_recovery_passcode_requirement.rb:21–44`                              |
| Global max cap               | `MAX_SECRETS_PER_USER = 20` (all kinds combined, not per-kind)                                                                                                                                                        | `app/models/client_secret_credential.rb:65`                                             |
| "Acknowledged/saved by user" | **No explicit column.** One-time display is tracked by `IdentityOneTimeReveal` cache token consumption, not by a column on the credential. Schema cannot currently represent acknowledgement separately from display. | n/a                                                                                     |
| Bulk-issue                   | No bulk-issue service exists; `SignSecretIssue` and `ClientSecretCredentialsCreate` each issue one credential per call                                                                                                | `app/services/sign_secret_issue.rb`, `app/services/client_secret_credentials_create.rb` |
| Top-up count query           | Can compute shortfall as `10 - usable_unused_count(...)` using existing `SignRecoveryPasscodeRequirement`                                                                                                             | `app/services/sign_recovery_passcode_requirement.rb:7–11`                               |

### B.3 Services

| Service                           | File                                                 | Issues      | Revokes old | Returns raw        | Audit                            |
| --------------------------------- | ---------------------------------------------------- | ----------- | ----------- | ------------------ | -------------------------------- |
| `SignSecretIssue`                 | `app/services/sign_secret_issue.rb`                  | 1/call      | No          | Yes (Result)       | event log (safe_prefix only)     |
| `SignSecretRevoke`                | `app/services/sign_secret_revoke.rb`                 | 0           | 1/call      | No                 | event log                        |
| `SignSecretRotate`                | `app/services/sign_secret_rotate.rb`                 | 1 new       | 1 old       | Yes (new only)     | implicit                         |
| `ClientSecretCredentialsCreate`   | `app/services/client_secret_credentials_create.rb`   | 1/call      | No          | Yes (Result)       | Chronicle: `USER_SECRET_CREATED` |
| `SignRecoveryPasscodeRequirement` | `app/services/sign_recovery_passcode_requirement.rb` | 0           | 0           | No                 | None (read-only)                 |
| `IdentityOneTimeReveal`           | `app/services/identity_one_time_reveal.rb`           | cache token | n/a         | No — wraps payload | None                             |

No service exists that issues multiple recovery passcodes in bulk or implements a top-up-to-N
pattern.

### B.4 Controller Flows

| Concern                             | Finding                                                                                                                                         | File + Lines                                                               |
| ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| Recovery guard concern              | `SignRequiresRecoveryPasscodes#require_recovery_passcodes_for_mfa_registration!` — returns 403 if fewer than 2 usable unused recovery passcodes | `app/controllers/concerns/sign_requires_recovery_passcodes.rb:9–17`        |
| App passkey controller              | Guard applied on `new create options verification` actions via `before_action`                                                                  | `app/controllers/sign/app/settings/passkeys_controller.rb:34–37`           |
| App TOTP controller                 | Guard applied on `new create` actions                                                                                                           | `app/controllers/sign/app/settings/totps_controller.rb:20–23`              |
| Com passkey controller              | Same guard with `VisitorSecretCredential`                                                                                                       | `app/controllers/sign/com/settings/passkeys_controller.rb`                 |
| Org passkey controller              | Same guard with `OperatorSecretCredential` (but Operator has no RECOVERY kind — mismatch to verify)                                             | `app/controllers/sign/org/settings/passkeys_controller.rb`                 |
| Secret credentials controller (app) | No recovery guard; gated by `ensure_verified_recovery_identity_for_registration!` + step-up                                                     | `app/controllers/sign/app/settings/secret_credentials_controller.rb:18–23` |
| One-time display                    | `IdentityOneTimeReveal` issues a short-lived cache token; view reads/consumes it once                                                           | `app/services/identity_one_time_reveal.rb:14–67`                           |
| Current UI for multiple passcodes   | No existing UI shows multiple newly issued passcodes in one step — current flow is single-passcode                                              | (no multi-passcode view found)                                             |

### B.5 Deadlock / Guard Risk

**Current state creates a deadlock for the 0→1 scenario:**

1. User has: signed-in session, no recovery passcodes, no TOTP, no passkey.
2. To create first passkey: `require_recovery_passcodes_for_mfa_registration!` checks for ≥ 2 usable
   unused recovery passcodes → returns 403.
3. To create recovery passcodes via settings: `secret_credentials_controller` requires
   `has_verified_recovery_identity?` (contact verified) + step-up. This is reachable, but the UX is
   broken: the user must first manually navigate to secret credentials, create 2+, then return to
   passkey registration.
4. During sign-up, the sequence doc says passcodes are issued as a sign-up checkpoint — but the
   current guard would still fire on the settings path after sign-up if somehow skipped.

**Files and actions affected:**

- `app/controllers/sign/app/settings/passkeys_controller.rb` — `new`, `create`, `options`,
  `verification`
- `app/controllers/sign/app/settings/totps_controller.rb` — `new`, `create`
- `app/controllers/sign/com/settings/passkeys_controller.rb` — `new`, `create`, `options`,
  `verification`
- `app/controllers/sign/org/settings/passkeys_controller.rb` — same

### B.6 Limits and Invariants

| Question                          | Answer                                                                                                                                                                                                         |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Max per-user                      | `MAX_SECRETS_PER_USER = 20` (global, all kinds)                                                                                                                                                                |
| Is 10 recovery passcodes safe?    | Yes — 10 recovery + typical LOGIN + API < 20. But issuing 10 at once must check remaining headroom (`20 - existing_count`) and cap the batch.                                                                  |
| Per-kind limit?                   | No per-kind limit exists.                                                                                                                                                                                      |
| Minimum required today            | 2 (for MFA registration guard)                                                                                                                                                                                 |
| Target minimum for top-up         | 10 (proposed)                                                                                                                                                                                                  |
| What must change for top-up to 10 | (1) New service or loop to issue N passcodes in one transaction; (2) update minimum constant or add separate top-up constant; (3) remove/adjust guard for 0→1 case; (4) UI to display N newly issued passcodes |

### B.7 Tests

| Test area                                         | File                                                             | Status                                  |
| ------------------------------------------------- | ---------------------------------------------------------------- | --------------------------------------- |
| Recovery guard + passkey registration             | `test/controllers/sign/app/settings/passkeys_controller_test.rb` | Exists — tests 403 when < 2 passcodes   |
| Recovery guard + TOTP registration                | `test/controllers/sign/app/settings/totps_controller_test.rb`    | Exists — tests 403 when 0 or 1 passcode |
| Com passkey + recovery guard                      | `test/controllers/sign/com/settings/passkeys_controller_test.rb` | Exists                                  |
| Recovery passcode issue (bulk/top-up)             | Not found                                                        | **Missing**                             |
| Sign-up passkey flow + recovery issuance          | Not found                                                        | **Missing**                             |
| Top-up after passkey/TOTP 0→1                     | Not found                                                        | **Missing**                             |
| Top-up after passkey/TOTP 1→n                     | Not found                                                        | **Missing**                             |
| 0→1 passkey without prior passcodes (no deadlock) | Not found                                                        | **Missing**                             |
| Display multiple newly issued passcodes           | Not found                                                        | **Missing**                             |
| Plaintext not re-displayed                        | Not found                                                        | **Missing**                             |

---

## C. Recommended Implementation Plan

### C.1 Guiding Constraint

The active security plan (`plans/objective-recovery-secret-restricted-bootstrap-plan.md`) intends to
**remove RECOVERY from `ALLOWED_FOR_SECRET_SIGN_IN`** (separate restricted flow). That change is out
of scope here. Do not touch `ALLOWED_FOR_SECRET_SIGN_IN`.

This plan addresses only the three issuance scenarios. The restricted-bootstrap security work is a
separate tracked item.

### C.2 Minimal File Changes

**Step 1 — New top-up service: `RecoveryPasscodeTopUp`**

Create `app/services/recovery_passcode_top_up.rb`.

- Takes: `actor`, `credential_class`, `target_count: 10`, `now:`
- Calls `SignRecoveryPasscodeRequirement#usable_unused_count` to get current count.
- Computes shortfall = `target_count - current_count` (clamp to 0..headroom where headroom =
  `MAX_SECRETS - actor.secret_credentials.count`).
- Issues `shortfall` new RECOVERY credentials via `SignSecretIssue` in a loop (or single transaction
  wrapper).
- Returns `Result(new_credentials: [...], raw_values: [...])` — raw values for one-time display.
- Does **not** revoke existing active recovery passcodes.
- Writes Chronicle event for each issuance (reuse `ClientChronicleEvent::USER_SECRET_CREATED` or the
  recovery-specific equivalent if it exists).

**Step 2 — Adjust the before-action guard for 0→1 case**

In `app/controllers/concerns/sign_requires_recovery_passcodes.rb`:

- Add a method `recovery_passcodes_required?` — default `true`.
- Override in passkey/TOTP controllers to return `false` when this is the first strong credential
  (i.e., current passkey/TOTP count is 0 before registration starts).
- Change `require_recovery_passcodes_for_mfa_registration!` to short-circuit when
  `recovery_passcodes_required?` returns false.

Alternative (simpler): add a helper `first_strong_credential_registration?` in each relevant
controller and skip the before_action conditionally. Check passkey count + TOTP count before the
`new` action fires.

**Step 3 — Post-registration top-up hook**

In each settings passkey/TOTP controller, after successful registration:

- Call `RecoveryPasscodeTopUp.call(actor:, credential_class:, now:)`.
- If `result.new_credentials.any?`, store raw values via `IdentityOneTimeReveal` and redirect to
  recovery passcode display page.
- If no shortfall (already have 10+), skip display.

The passkey/TOTP controllers that need this hook:

- `app/controllers/sign/app/settings/passkeys_controller.rb` — success branch of `create` action
- `app/controllers/sign/app/settings/totps_controller.rb` — `finish_totp_ceremony!`
- `app/controllers/sign/com/settings/passkeys_controller.rb` — same
- (Org: Operator has no RECOVERY kind — confirm and skip or guard)

**Step 4 — Multi-passcode display view**

`IdentityOneTimeReveal` stores a single value. For multiple raw values, either:

- Store an array serialized as JSON as the reveal payload (simplest — `IdentityOneTimeReveal`
  doesn't constrain payload type), or
- Issue one reveal token per passcode (worse UX).

Store array. Create or update the recovery passcode display view to render a list.

Likely files:

- `app/views/shared/recovery_passcodes/` — new `issued.html.erb` (or extend `show`)
- Route: confirm there is a `show`/`new` action for recovery passcode display under the
  secret_credentials controller or a dedicated controller.

**Step 5 — Sign-up flow passcode issuance**

Per `docs/security/sign-up-sequence.md:452–460`, passcode setup is a dedicated sign-up checkpoint.

- Locate the sign-up checkpoint controller (not yet identified — needs further investigation).
- After contact verification checkpoint passes, call `RecoveryPasscodeTopUp` with
  `target_count: 10`.
- Show newly issued passcodes via `IdentityOneTimeReveal` multi-value token.
- Mark checkpoint cleared only after user views the display page (reveal token consumed).

### C.3 Tests to Add / Update

- `test/services/recovery_passcode_top_up_test.rb` — bulk issue, shortfall calculation, cap at 20,
  no re-issue of existing, returns raw values
- `test/controllers/sign/app/settings/passkeys_controller_test.rb` — 0→1 passkey succeeds without
  prior recovery passcodes; top-up issued afterward
- `test/controllers/sign/app/settings/totps_controller_test.rb` — same pattern
- `test/controllers/sign/com/settings/passkeys_controller_test.rb` — same for com
- View tests / integration: newly issued plaintext shown once; second access returns 404/nil
- Sign-up checkpoint test (once controller is located)

### C.4 Migration

No schema changes required. All necessary columns (`uses_remaining`, `last_used_at`, `consumed_at`,
`revoked_at`, `discarded_at`, `password_digest`, `lookup_digest`, `safe_prefix`) already exist.

### C.5 Compatibility Risks

| Risk                                                                                                | Mitigation                                                                                                      |
| --------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `MAX_SECRETS_PER_USER = 20` cap — issuing 10 at sign-up could fail if near limit                    | `RecoveryPasscodeTopUp` must compute headroom before issuing; cap batch to min(shortfall, headroom)             |
| Active security plan will later remove RECOVERY from `ALLOWED_FOR_SECRET_SIGN_IN`                   | This plan does not touch `ALLOWED_FOR_SECRET_SIGN_IN`; the restricted-bootstrap work is tracked separately      |
| `IdentityOneTimeReveal` currently designed for one value — storing array requires confirm it's safe | Payload is stored in Rails encrypted cache; array is safe if serialized (JSON); verify no size limit issues     |
| Org surface: `OperatorSecretCredential` has no RECOVERY kind                                        | Guard and top-up must be skipped for org; the existing org passkeys controller includes the guard — needs audit |

---

## D. Ready for Implementation

### Files that will likely need edits

```
# New file
app/services/recovery_passcode_top_up.rb

# Guard adjustment — 0→1 bypass
app/controllers/concerns/sign_requires_recovery_passcodes.rb

# Post-registration top-up hook
app/controllers/sign/app/settings/passkeys_controller.rb
app/controllers/sign/app/settings/totps_controller.rb
app/controllers/sign/com/settings/passkeys_controller.rb
app/controllers/sign/org/settings/passkeys_controller.rb   # verify/skip Operator

# Multi-passcode display
app/services/identity_one_time_reveal.rb                   # confirm array payload works
app/views/shared/recovery_passcodes/issued.html.erb        # new or updated view

# Sign-up checkpoint (location to be confirmed — needs one more investigation step)
# Candidates: app/controllers/sign/app/sign/up/ or sign/app/checkpoints/
```

### Open questions before implementation begins

1. **Sign-up checkpoint controller location**: Where exactly is the sign-up checkpoint that should
   trigger the initial 10-passcode issuance? `docs/security/sign-up-sequence.md` references it but
   the controller file was not located in this investigation.

2. **Org surface**: Does `sign/org/settings/passkeys_controller.rb` include
   `SignRequiresRecoveryPasscodes`? If so, does the `OperatorSecretCredential` RECOVERY kind check
   work correctly (Operator has no RECOVERY kind)? This must be confirmed before editing.

3. **`IdentityOneTimeReveal` array payload**: Confirm the encrypted cache store has no practical
   size constraint that would block storing 10 × 32-char raw values as JSON (~350 bytes).
