# Email OTP Audit — Sign-up / Sign-in / Step-up

Read-only audit of Umaxica's email OTP mechanisms (sign-up, sign-in, step-up). No source files were
modified.

## Context

The Umaxica Rails app has three surfaces (`app`, `org`, `com`) and a strict boundary between
**Acme** (the sole IdP / Authorization Server / token issuer) and **Sign** (the RP-style credential
gateway that hosts UI ceremonies). Email OTP is used as a credential factor in three separate flows:

1. **Sign-up** — bootstrap a brand-new account.
2. **Sign-in** — establish an authenticated session for an existing account (passwordless email
   code).
3. **Step-up** — raise the assurance of an already-authenticated session for a sensitive operation
   (settings change, withdrawal, etc.).

The audit covers route/boundary correctness, OTP generation/storage/verification correctness, mailer
hygiene, rate limiting, session/assurance state, CSRF/cookie posture, authorization, and test
coverage. All assertions cite concrete file:line evidence; gaps are flagged as gaps, not passes.

---

## 1. Executive Verdict

**PASS WITH GAPS**

The three flows are correctly separated at the architectural level, OTP generation uses a CSPRNG
(ROTP HOTP keyed with `ROTP::Base32.random_base32` + a `SecureRandom`-seeded counter), verification
is constant-time, mailer payloads are encrypted in transit through ActiveJob, attempts are tracked
under a row lock with a 15-minute lockout window, and Brakeman reports zero warnings. Acme remains
the only token issuer; Sign owns the credential ceremony but hands off via
`establish_signed_in_session!` → `log_in` whose token-record creation lives in Acme-side code paths.

However, several real gaps lower confidence:

- **G1 — Step-up resolver "fail-open" on missing bindings (Medium).**
  `StepUpResolver#session_bound?`, `#token_bound?`, `#purpose_bound?`, and `#audience_bound?` all
  return `true` when the requirement's expected binding is blank. The verification controller does
  pass a `session_binding`, but the resolver itself permits unguarded callers. Any future call site
  that forgets to populate `session_binding:` silently disables session pinning.
- **G2 — OTP "secret" is stored in plaintext (Medium / By Design).** `client_emails.otp_private_key`
  / `otp_counter` are written unhashed. A DB read recovers the live OTP, undermining the spirit of
  "raw OTP must not be stored". Stated mitigation is at-rest encryption, but the column is not
  encrypted via `encrypts ...` in the model.
- **G3 — Same physical OTP columns are reused across sign-up and sign-in (Medium).** Both
  `SignOtpCeremony` (sign-up) and `CommonOtp#generate_otp_for` (sign-in) write the same
  `otp_private_key` / `otp_counter` / `otp_expires_at` on `ClientEmail`. Purpose separation is
  enforced only at the calling site (different controllers, different status filters), not by a
  `purpose` column on the OTP record. The current code path is safe because sign-up uses the
  _pending_ `ClientEmail` (status `UNVERIFIED_WITH_SIGN_UP`) while sign-in looks up by `VERIFIED`
  status — but a regression in either lookup filter would create a cross-flow confused-deputy.
- **G4 — `enforce_email_flow!` skipped on sign-up OTP controller (Low/Info, needs verification).**
  `app/controllers/sign/app/sign/up/check/email/otps_controller.rb:14` does
  `skip_before_action :enforce_email_flow!` — needs explicit confirmation that another guard still
  enforces "must be in email-pending state" before issuing or verifying an OTP.
- **G5 — Missing tests for explicit cross-flow OTP reuse (PASS WITH GAPS).** Tests assert success
  and lockout paths but no test enumerates "OTP issued in sign-up cannot satisfy sign-in", "OTP
  issued in sign-in cannot satisfy step-up", and vice versa.
- **G6 — Step-up clear-on-logout assertion is implicit (Low).** Step-up freshness lives on
  `ClientToken.last_step_up_*` columns. Logout invokes `reset_session` and destroys/rotates the
  token row, so freshness is gone in practice, but there is no dedicated regression test asserting
  that revoking a token wipes step-up state.

None of the findings reaches Critical. Cookie posture is correct (`__Host-`, `Secure`, `HttpOnly`,
`SameSite=Strict`); session fixation reset is wired (`authentication_base.rb:352`); CSRF is enforced
via `protect_from_forgery using: :header_or_legacy_token` on
`sign/app/application_controller.rb:31`. The single token issuer remains Acme.

---

## 2. Flow Map

### 2.1 Sign-up email OTP

| Concern                  | Location                                                                                                                                                                                                                     |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Entry route              | `POST /sign/up/email` → `config/routes/sign.rb:86`                                                                                                                                                                           |
| OTP request/verify route | `GET/POST/PATCH /sign/up/check/email/otp` → `config/routes/sign.rb:110`                                                                                                                                                      |
| Controller (entry)       | `app/controllers/sign/app/sign/up/emails_controller.rb:74-120` (`#create`)                                                                                                                                                   |
| Controller (OTP)         | `app/controllers/sign/app/sign/up/check/email/otps_controller.rb:16-50`                                                                                                                                                      |
| Ceremony service         | `app/services/sign_otp_ceremony.rb:29-78` — `validate_scope!` raises unless `purpose == :sign_up`                                                                                                                            |
| State machine            | `app/services/sign_up_state_machine.rb:5-228`                                                                                                                                                                                |
| Storage                  | `client_emails.otp_private_key/otp_counter/otp_expires_at/otp_attempts_count/locked_at` via `OtpLockable` (`app/models/concerns/otp_lockable.rb:51-91`)                                                                      |
| Mailer                   | `app/mailers/email/app/otp_mailer.rb:10-20`, enqueued from `sign_otp_ceremony.rb:160-163` with `OutboundSensitivePayload.encrypt_email_otp` envelope                                                                         |
| Verification             | `sign_otp_ceremony.rb:51-78` — `record.with_lock`, ROTP HOTP recompute, `ActiveSupport::SecurityUtils.secure_compare`, `clear_otp` on success, `increment_attempts!` on failure                                              |
| Final state              | Pending user created early (`UNVERIFIED_WITH_SIGN_UP`); on completion, finalizer raises status to `VERIFIED_WITH_SIGN_UP` and `establish_signed_in_session!` hands off to Acme `log_in` (`authentication_base.rb:2254-2315`) |
| Tests                    | `test/services/sign_up/*`, `test/integration/email_delivery_test.rb:26-54`, `test/models/concerns/otp_lockable_test.rb`, `test/concerns/common_otp_test.rb`                                                                  |

### 2.2 Sign-in email OTP

| Concern                | Location                                                                                                                                                                           |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Entry route            | `GET /sign/in/email/new`, `POST /sign/in/email`, `PATCH /sign/in/email` → `config/routes/sign.rb:127`                                                                              |
| Controller             | `app/controllers/sign/app/sign/in/emails_controller.rb` — `#new:71`, `#create:78`, `#update:116`                                                                                   |
| Auth gate              | `declare_authentication_mode!(:guest)` at `emails_controller.rb:62` — authenticated user is 400-rejected                                                                           |
| OTP issuance           | `CommonOtp#generate_otp_for` (`app/controllers/concerns/common_otp.rb:66-75`) — `ROTP::Base32.random_base32` + `SecureRandom.random_number(1<<64)`-seeded counter                  |
| Enumeration defense    | `email_validation.rb:21-37` (50 ms floor via `Process.clock_gettime(CLOCK_MONOTONIC)`); dummy path in `common_otp.rb:138-149` (`verify_dummy_otp`, `perform_dummy_otp_generation`) |
| Storage                | Same `ClientEmail.otp_*` columns (`OtpLockable`)                                                                                                                                   |
| Mailer                 | Same `Email::App::OtpMailer.deliver_later` with `OutboundSensitivePayload.encrypt_email_otp`                                                                                       |
| Verification           | `common_otp.rb:114-127` — `secure_compare_otp` (constant-time wrapper around `ActiveSupport::SecurityUtils.secure_compare`)                                                        |
| Session establishment  | `establish_signed_in_session!` → `log_in` → `create_login_token_record` + `set_login_auth_cookies` (`authentication_base.rb:359-405`, `2254-2315`) on the Acme code path           |
| Session fixation reset | `reset_session` is called inside the log-in path (`authentication_base.rb:352`)                                                                                                    |
| Tests                  | `test/controllers/sign/app/in/emails_controller_test.rb`, `..._security_test.rb`, `..._extra_test.rb`                                                                              |

### 2.3 Step-up email OTP

| Concern              | Location                                                                                                                                                                                                                                                                                  |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Routes               | `GET/POST /verification/emails`, `PATCH /verification/emails/:nonce`, `POST /verification/emails/:nonce/redeliveries` (sign surface)                                                                                                                                                      |
| Controller           | `app/controllers/sign/app/verification/emails_controller.rb:1-137`                                                                                                                                                                                                                        |
| Auth precondition    | Step-up requires the caller already to hold an authenticated session — verification base concerns are mounted on the authenticated controller hierarchy; `acme_step_up_intent.rb` issues a grant JWT only after the actor is resolved (`identity_step_up_ceremony_grant_issuer.rb:4-41`)  |
| Session record       | `ClientStepUpSession(user_token_id UNIQUE, scope, status, attempt_count, discarded_at)` — bound 1:1 to the authenticated `ClientToken` (`app/models/client_step_up_session.rb:1-53`)                                                                                                      |
| Ceremony transaction | `ClientStepUpCeremonyTransaction(transaction_id, grant_jti, result_jti, status, expires_at, ...)` — pending → consumed lifecycle, audience `https://id.umaxica.app/step-up-ceremony`                                                                                                      |
| OTP issuance         | `SignAppVerificationBase#send_email_otp!` (`sign_app_verification_base.rb:171-196`) — generates HOTP, stores `{secret_credential, counter}` in `Rails.cache` (key `step_up_session:<id>:email_otp`, TTL = session `discarded_at`, 15 min)                                                 |
| Mailer               | Same `Email::App::OtpMailer` with `OutboundSensitivePayload.encrypt_email_otp` envelope                                                                                                                                                                                                   |
| Verification         | `sign_app_verification_base.rb:209-234` — recompute HOTP, `secure_compare`, consume                                                                                                                                                                                                       |
| Result token         | `IdentityStepUpCeremonyResultIssuer` — JWT (audience `https://www.umaxica.app/step-up-ceremony-result`), consumed by `IdentityStepUpCeremonyFreshnessCommitter`                                                                                                                           |
| Freshness write      | `client_tokens.last_step_up_at / last_step_up_scope / last_step_up_aal / last_step_up_method / last_step_up_session_public_id` (+ optional purpose/audience) — `identity_step_up_ceremony_freshness_committer.rb:55-71`                                                                   |
| Enforcement          | `StepUpResolver` checks scope, AAL, method, TTL, session/token/purpose/audience bindings (`step_up_resolver.rb:56-69`); guard DSL `step_up(scope:, required_aal:)` in `verification_step_up_guard.rb:13-36`                                                                               |
| TTL                  | 15 minutes for session (`SignAppVerificationBase` `STEP_UP_TTL`), 15 minutes for transaction (`IdentityStepUpCeremonyTransaction::DEFAULT_TTL`), 15 minutes for freshness (`StepUpRequirement::DEFAULT_TTL`)                                                                              |
| Tests                | `test/integration/step_up_authentication_test.rb`, `test/integration/app_step_up_verification_enforcer_test.rb`, `test/controllers/sign/app/verification/emails_controller_test.rb`, `test/services/step_up/resolver_test.rb`, `test/services/identity/step_up_ceremony_contract_test.rb` |

---

## 3. Findings Table

### F1 — Step-up resolver fails open when caller omits bindings — **Medium**

- **Category:** Authorization / Step-up assurance binding
- **Evidence:** `app/services/step_up_resolver.rb:102-131`
  ```
  def session_bound?
    expected = requirement.session_binding
    return true if expected.blank?
    ...
  end
  ```
  Same shape for `token_bound?`, `purpose_bound?`, `audience_bound?`.
- **Expected:** Step-up freshness must always be bound to the active session/token. A missing
  binding should be treated as a _failure_, not as "no constraint".
- **Actual:** Caller controls whether binding is enforced.
  `app/controllers/concerns/verification_base.rb:129` passes
  `session_binding: current_session_token&.public_id`, so the production call path is safe — but any
  caller that omits it (or where `current_session_token` is `nil`) silently disables session
  pinning, allowing a step-up earned in browser A to be accepted as fresh in browser B that shares
  the same token row in some edge case.
- **Exploit scenario:** A future controller adding step-up enforcement (or a cron/background path)
  forgets `session_binding:`, and freshness from another tab/device is accepted.
- **Fix:** Require `requirement.session_binding` to be present; treat blank as `false`. Same for
  `token_bound?` once `last_step_up_session_public_id` is universally populated (it already is on
  the freshness commit path).
- **Regression test:** Construct a token with `last_step_up_*` set, call
  `StepUpResolver.call(token:, scope:, ... session_binding: nil)` and assert `satisfied: false`.

### F2 — OTP key & counter persisted unhashed (raw OTP is derivable from DB row) — **Medium / By Design**

- **Category:** OTP storage / defense-in-depth
- **Evidence:** `app/models/concerns/otp_lockable.rb:51-65` —
  `update!(otp_private_key:, otp_counter:, otp_expires_at:)` without hashing or
  `encrypts :otp_private_key`. No `encrypts ...` declaration in `app/models/client_email.rb`.
- **Expected:** "Stored OTP verifier material should be hashed or otherwise non-reversible." HOTP
  cannot be hashed in the strict sense because verification is stateful — but it can be wrapped in
  `ActiveRecord::Encryption` (key derived from `Rails.application.secret_key_base`) so a SQL leak
  does not expose live OTPs.
- **Actual:** Anyone with read access to `client_emails` for the OTP window can compute the live
  6-digit code with `ROTP::HOTP.new(otp_private_key).at(otp_counter.to_i)`.
- **Exploit scenario:** SQLi/log dump within the 12-minute window yields a working OTP, bypassing
  email delivery entirely. Mitigated by short TTL, attempt lockout, and the lockout/race-condition
  window for the 5-attempt cap.
- **Fix:** Add `encrypts :otp_private_key, deterministic: false` (and ideally `:otp_counter`) on
  `ClientEmail`, `VisitorEmail`, `ClientTelephone`, `VisitorTelephone`. Verify via
  `Rails.application.eager_load!; ClientEmail.encrypted_attributes` that the column is in the
  encrypted set.
- **Regression test:** Persist an OTP, read the raw column via `connection.execute`, and assert it
  does _not_ equal the in-memory `otp_private_key`.

### F3 — Cross-flow OTP record reuse depends on calling-site filter — **Medium**

- **Category:** Purpose scoping
- **Evidence:**
  - `app/services/sign_otp_ceremony.rb:148-155` (sign-up) writes the same physical columns as
  - `app/controllers/concerns/common_otp.rb:66-75` (sign-in).
  - `client_emails` has no `purpose` / `kind` discriminator on the OTP itself.
- **Expected:** "OTPs must be scoped to the correct purpose: sign_up, sign_in, or step_up" and "OTP
  from sign-up must not work for sign-in or step-up."
- **Actual:** Separation is implicit — sign-up only ever issues against a `ClientEmail` belonging to
  a `UNVERIFIED_WITH_SIGN_UP` user, while sign-in only ever looks up by `address_digest` filtered to
  a `LOGIN_ALLOWED` status. Today these two record sets do not overlap. The boundary collapses if
  either lookup is widened or if a status transition leaves a window where both criteria match the
  same row.
- **Exploit scenario:** A future status-set refactor (or a bug in
  `find_email_with_timing_protection`) returns a sign-up `ClientEmail` to the sign-in lookup. The
  sign-up OTP would verify a sign-in cycle, granting an attacker a session under the wrong actor.
- **Fix:** Add a `last_otp_purpose` (or per-flow OTP table) and have `OtpLockable#get_otp` only
  return the credential when caller's `purpose` matches the stored purpose. Step-up already uses a
  separate cache scope, so the change applies only to email-record OTP.
- **Regression test:** Issue an OTP via `SignOtpCeremony` (sign-up) on a record, then attempt to
  verify the same code through the sign-in path and assert it is rejected (and vice versa).

### F4 — `skip_before_action :enforce_email_flow!` on sign-up OTP controller — **Low / Needs Confirmation**

- **Category:** Authorization / flow integrity
- **Evidence:** `app/controllers/sign/app/sign/up/check/email/otps_controller.rb:14`
- **Expected:** The OTP request/verify endpoint must require an in-progress sign-up ticket in the
  email-pending state.
- **Actual:** A specific flow-enforcement filter is skipped. The controller still calls
  `SignOtpCeremony` which raises `ArgumentError` unless `subject` is a `ClientSignUpFlow` with
  `pending_contact_type == "email"` (`sign_otp_ceremony.rb:84-92`), and `show:16-23` validates the
  session-bound email. Confirm a malformed/expired ticket cannot reach `#create`/`#update` without
  that filter — e.g., direct POST after the user manually progresses the ticket past
  `CONTACT_PENDING`.
- **Fix:** Either restore `:enforce_email_flow!` for `:show, :create, :update` or document the
  explicit substitute guard (likely `before_action :require_pending_email_contact!`).
- **Regression test:** Drive the state machine into a non-email-pending state, POST to
  `/sign/up/check/email/otp`, assert 4xx or redirect rather than OTP issuance.

### F5 — `clear_otp` retains `otp_private_key` between flows — **Info**

- **Category:** Hygiene
- **Evidence:** `app/models/concerns/otp_lockable.rb:78-91` — counter reset, expiry set to
  `-infinity`, but `otp_private_key` is intentionally kept ("the column is NOT NULL and the key is
  safe to reuse").
- **Expected:** A reused key is harmless because `get_otp` short-circuits on `otp_expired?` and a
  fresh `store_otp` rotates the key. Verified: `get_otp` returns `nil` if
  `otp_expires_at <= Time.current` (`otp_lockable.rb:93-97`).
- **Actual / Fix:** No defect. Note for future readers that the key is durable across issuances;
  rotation depends on every issuance calling `store_otp` which always rewrites `otp_private_key` to
  a fresh `ROTP::Base32.random_base32`. If a future code path mutates only `otp_counter` while
  leaving the key in place across flows, that would re-introduce cross-issuance correlation. Worth a
  model-level test.

### F6 — Enumeration defense relies on a 50 ms latency floor — **Info**

- **Category:** Timing / enumeration
- **Evidence:** `app/controllers/concerns/email_validation.rb:21-37`,
  `app/controllers/concerns/common_otp.rb:138-149` (`verify_dummy_otp`,
  `perform_dummy_otp_generation`).
- **Expected / Actual:** 50 ms is a small budget on a noisy network and on a host under load.
  Empirical statistical attacks across many requests could still see signal. Mitigation: rate-limits
  at 5/min IP burst and 20/15-min sustained (`emails_controller.rb:21-60`) make sufficient sampling
  expensive. Combined with the dummy generator emitting a real `ROTP::Base32.random_base32` call,
  residual leak is low.
- **Fix:** Not blocking. Consider tightening to a randomized jitter window (e.g.,
  `50 ms ± uniform(0..20 ms)`) so distribution doesn't reveal a sharp floor.

---

## 4. Missing Tests

### Sign-up

- Sign-up OTP request when sign-up ticket is _not_ in email-pending state (F4 regression).
- Sign-up OTP submitted with the correct code but the wrong ticket / wrong email subject
  (`destination_mismatch` path is covered indirectly — confirm explicit test exists).
- Reuse of an already-consumed sign-up OTP (post-`clear_otp`).

### Sign-in

- Cross-flow rejection: issue OTP via sign-up path on a `ClientEmail`, then submit it through
  `/sign/in/email` and assert rejection.
- Account enumeration: dummy path returns identical status/redirect to existing-path success.
- Session-fixation reset: assert `request.session.id` differs before/after
  `establish_signed_in_session!`.
- Cookie attributes: assert `__Host-` prefix in production-config integration test;
  `SameSite=Strict`, `Secure`, `HttpOnly`.
- Hard session-limit pre-check rejects without sending OTP.

### Step-up

- Step-up freshness rejected when `session_binding` is blank (F1 regression).
- Step-up freshness rejected after `reset_session` / token revocation (F6).
- Cross-flow rejection: step-up cached OTP cannot be replayed against sign-in or sign-up.
- Step-up TTL expiry: freshness `last_step_up_at + 15.min < now` ⇒ `satisfied: false`.
- Step-up email resend cooldown (60 s) enforced per session.

### Shared OTP infrastructure

- `OtpLockable#increment_attempts!` race: two parallel verifications under `with_lock` produce a
  single lockout.
- `OtpLockable` does not return a verifier when `locked?` even within the validity window.
- Mailer payload encryption: `OutboundSensitivePayload.encrypt_email_otp` round-trips correctly;
  ActiveJob-serialized params do not contain the plaintext code.
- `ROTP::Base32.random_base32` and `SecureRandom.random_number` are the only sources used; no
  `Kernel#rand` regression.

---

## 5. Commands Run

| Command                                                 | Result                                                                                                                                                               |
| ------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bundle exec brakeman --quiet --no-pager --no-progress` | OK — 0 warnings across 734 controllers, 488 models, 327 templates (13 s)                                                                                             |
| `bin/rails routes` (filtered)                           | OK — Sign hosts `/sign/up/...`, `/sign/in/...`, `/verification/...`; Acme hosts `/verification` (`acme/app/verifications#show/completion`) and `/settings/totps/...` |
| Static reads of OTP services, models, controllers       | Confirmed CSPRNG sources, `secure_compare`, row-locked attempt increments, mailer-payload encryption                                                                 |
| `bin/rails test`                                        | **Not executed** — would exceed audit scope and may mutate test DBs. Existing test files for each flow are enumerated above.                                         |
| `bin/rubocop`                                           | **Not executed** — style only, not security-relevant for this audit.                                                                                                 |

---

## 6. Final Recommendation

**Fix implementation gaps, then add tests** — in this order:

1. **F1 (Medium):** Tighten `StepUpResolver` so blank `session_binding` ⇒ `satisfied: false`.
   Smallest blast radius; ~10 lines in `app/services/step_up_resolver.rb`. Add the F1 regression
   test.
2. **F2 (Medium):** Apply `encrypts :otp_private_key` (and ideally `:otp_counter`) to `ClientEmail`,
   `VisitorEmail`, `ClientTelephone`, `VisitorTelephone`. Migration is column-encryption only; no
   schema change. Pair with the round-trip test described in §4.
3. **F3 (Medium):** Add an `otp_purpose` discriminator to the OTP record (or split into per-flow OTP
   tables) so cross-flow reuse becomes structurally impossible. Larger change — write a dedicated
   proposal under `plans/backlog/` rather than bundling here.
4. **F4 (Low):** Verify the substitute guard for the skipped `:enforce_email_flow!`; restore the
   filter or document the substitute.
5. **Tests only:** Land the missing-test list in §4 as a single follow-up PR after items 1–2 ship.

No flow redesign is required. The Sign / Acme boundary, the cookie posture, the rate limits, the
constant-time comparison, and the row-locked attempt counter are all sound. The remaining work is
hardening defaults and codifying purpose separation that today depends on calling-site discipline.

---

## Verification (post-fix)

When the F1 and F2 fixes ship:

- `bin/rails test test/services/step_up/resolver_test.rb` — new blank-binding regression must fail
  before the fix, pass after.
- `bin/rails test test/models/client_email_encryption_test.rb` (new) — assert encrypted column
  round-trip.
- `bin/rails test test/integration/step_up_authentication_test.rb` — existing suite still green.
- `bin/rails test test/controllers/sign/app/in/emails_controller_test.rb` — existing suite still
  green.
- `bundle exec brakeman --quiet --no-pager` — still 0 warnings.
- Manual: issue an OTP, dump `client_emails` row, confirm `otp_private_key` is ciphertext.
