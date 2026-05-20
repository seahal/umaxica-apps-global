# ADR: Step-Up Authentication Mechanism Redesign

**Status:** Accepted (2026-05-11)

**Correction (2026-05-19):** The current route contract for `configuration_mfa` is
`/configuration/mfa/challenge` on every sign surface. WebAuthn challenge state remains in the Rails
session store; only email OTP step-up state uses the cache-backed `step_up_session:*` keys.

## Context

The step-up authentication mechanism gates sensitive operations (social-login unlink, withdrawal,
session revoke-all, credential management) behind a freshness check: "did the actor complete step-up
authentication within the last 15 minutes for this scope?" The original design was started during
the Rails engine migration era, then abandoned mid-implementation when that migration stalled. The
result was a half-built system with multiple regressions:

- `StepUp::AvailableMethods` and `StepUp::ConfiguredMethods` (`app/services/step_up/*.rb`) are
  byte-for-byte identical, so the fork between "needs bootstrap (no credentials)" and "needs step_up
  (has credentials)" in `Verification::Base#enforce_step_up_prereqs!` cannot distinguish the two
  states.
- `Sign::*::Verification::SetupsController#new` is a three-line stub that echoes `rt` into an
  instance variable. It does not filter by what is already configured, does not auto-bounce when all
  methods are configured, and is identical across surfaces despite per-surface method differences
  (e.g., org supports passkey only).
- Configuration registration controllers (`Configuration::PasskeysController#new`, etc.) do not
  honor `params[:rt]`, so the "setup → register → return to the original sensitive action" loop is
  silently broken. The user lands on `/configuration` instead of the action they were trying to do.
- `ClientStepUpSession` / `VisitorStepUpSession` / `OperatorStepUpSession` exist with full schemas
  (`status, attempt_count, verified_at, discarded_at, method`, `Retainable`) but no controllers wire
  them. Controllers store step-up state in cookie sessions instead. Two parallel mechanisms, only
  the cookie one is alive.
- Orphan views under `app/views/sign/{app,org}/step_up/` (8 files) reference `@step_up_session` /
  `@step_up_sessions` with no controller to render them.
- `ALLOWED_SCOPES` (in `Sign::AppVerificationBase` and equivalents) is missing `session_revoke_all`,
  which is used by all three surfaces' session controllers. Entering
  `/verification?scope=session_revoke_all&...` raises `ActionController::BadRequest`. The
  `configuration_mfa` regex matches `/configuration/mfa`, but the actual route is
  `/configuration/challenge`.
- `Sign::App::Configuration::GooglesController#destroy` does not exist and is not routed; Google
  identities cannot be unlinked (Apple can).

Because credentials cannot be cleanly removed and bootstrap users (social-login-only accounts with
zero step-up methods) hit an infinite redirect loop between `enforce_step_up_prereqs!` and the
registration controllers, the feature is effectively dark in production. This ADR records the
redesign decisions agreed in the 2026-05-11 design dialogue.

## Decision

### A. Persistence

- **A1.** The step-up ticket is stored in a temporary token-bound DB row, not in the session cookie
  store and not in actor profile state.
- **A2.** Each surface's step_up_session table is co-located with its current login/session token:
  - `ClientStepUpSession`: `mark` (`< AppTicketRecord`), keyed by `user_token_id`
  - `VisitorStepUpSession`: `symbol` (`< ComTicketRecord`), keyed by `visitor_token_id`
  - `OperatorStepUpSession`: `token` (`< OrgTicketRecord`), keyed by `staff_token_id`
- **A3.** The actor-side tables on `principal` / `guest` / `operator` are not created. StepUp rows
  are short-lived login/session tickets.

### B. Schema

- **B1.** One row per ticket. The `method` column becomes **nullable**. A ticket is created at
  gate-entry with `method = NULL, status = PENDING`, then updated when the user picks a method on
  `/verification`.
- **B2.** Per-token singleton with **upsert** semantics. At most one row per login/session token
  exists at any time. A new gate-entry overwrites the current token's row in place rather than
  inserting a new row and marking the old one `CANCELLED`.
- **B3.** `UNIQUE(<token>_id)` constraint enforces the singleton at the DB layer (replaces the
  previous non-unique `(<actor>_id, status)` index).
- **B4.** `STATUSES` reduced to `%w(PENDING VERIFIED)`. `CANCELLED` is unnecessary because overwrite
  replaces the old ticket; `EXPIRED` is unnecessary because `discarded_at < Time.current` is
  computed at read time.
- **B5.** Email OTP secret/counter state lives in cache, keyed by
  `step_up_session:{step_up_session_id}:email_otp`, with TTL ≤ `STEP_UP_TTL`. WebAuthn challenge
  bytes remain in the Rails session store and continue to use the existing one-time-use / TTL
  challenge lifecycle.

### C. Judgement logic

- **C1. `ConfiguredMethods(actor)`** — existence of a credential record in counting status,
  surface-aware:
  - app: `email VERIFIED|VERIFIED_WITH_SIGN_UP`, `passkey ACTIVE`, `totp ACTIVE`
  - com: `email VERIFIED|VERIFIED_WITH_SIGN_UP`, `passkey ACTIVE`
  - org: `passkey ACTIVE`
- **C2. `AvailableMethods(actor, ticket: nil) ⊆ ConfiguredMethods(actor)`**. Subtract:
  - Methods currently in cooldown (per-method last attempt within window).
  - **All** methods, if `ticket && ticket.attempt_count >= 5` (ticket-scoped lockout).
- **C3.** Cooldown windows:

  | method      | window | rationale                                             |
  | ----------- | ------ | ----------------------------------------------------- |
  | `email_otp` | 60 s   | SES rate-limit / anti-spam / delivery-cost protection |
  | `passkey`   | 5 s    | WebAuthn assertion replay / double-click protection   |
  | `totp`      | 5 s    | TOTP code reuse / double-submit protection            |

  All three cooldowns are required as defense-in-depth. The 5 s windows are below normal human
  interaction speed, so they are invisible to users in practice.

- **C4.** Lockout is **ticket-scoped only**. `attempt_count` is a monotonic counter on the ticket
  spanning all method switches. At `attempt_count >= 5` the ticket refuses further step-up attempts;
  a new ticket via overwrite is required. Account-wide lockout is intentionally out of scope and may
  be layered on later if abuse is observed.
- **C5.** TTL is unified at **15 minutes** for `STEP_UP_TTL` (token freshness for repeat operations)
  and `STEP_UP_TTL` (`step_up_session.discarded_at` window). The previous
  `VERIFICATION_POST_TTL = 30.minutes` and `VERIFICATION_GET_TTL = 15.minutes` distinction is
  dropped in favor of one value.
- **C6.** `ConfiguredMethods` and `AvailableMethods` results are recomputed every request and not
  cached across the request lifecycle. This bounds the TOCTOU window to a single request.
- **C7.** Runtime bootstrap gating is driven by the persisted actor MFA status column, not by each
  controller independently recomputing credential presence. The credential records still determine
  the cached status, but controllers read the cache:
  - `multi_factor_status_id = 5` (`UNCONFIGURED`) means the actor has no surface-counting step-up
    method and may enter only the configured bootstrap-exempt registration actions without step-up.
  - `multi_factor_status_id = 1` (`ACTIVE`) means the actor has at least one surface-counting
    step-up method and sensitive configuration pages require step-up.
  - `multi_factor_status_id = 0` (`NOTHING`) is a placeholder only. Runtime checks must raise if it
    appears, because it indicates an implementation or data synchronization bug.

### D. Scope catalog (nine scopes)

| scope                     | path regex                       |
| ------------------------- | -------------------------------- |
| `social_unlink`           | `\A/social/`                     |
| `session_revoke_all`      | `\A/configuration/sessions`      |
| `withdrawal`              | `\A/configuration/withdrawal`    |
| `configuration_email`     | `\A/configuration/emails`        |
| `configuration_telephone` | `\A/configuration/telephones`    |
| `configuration_passkey`   | `\A/configuration/passkeys`      |
| `configuration_mfa`       | `\A/configuration/mfa/challenge` |
| `configuration_secret`    | `\A/configuration/secrets`       |
| `configuration_totp`      | `\A/configuration/totps`         |

`session_revoke_all` is newly added (fixes the missing-scope `BadRequest` bug).
`configuration_mfa`'s regex is corrected to match the actual route. `manage_totp` is renamed
`configuration_totp` for naming consistency. Each `verification_scope` in the registration
controllers must be updated to match.

### E. Per-surface configuration

| surface | step-up methods                  | bootstrap-exempt registration actions                                                                                                                                                 |
| ------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| app     | `email_otp` / `passkey` / `totp` | `Configuration::Emails::RegistrationsController` `{new, create, edit, update}`, `Configuration::PasskeysController` `{new, create}`, `Configuration::TotpsController` `{new, create}` |
| com     | `email_otp` / `passkey`          | `Configuration::Emails::RegistrationsController` `{new, create, edit, update}`, `Configuration::PasskeysController` `{new, create}`                                                   |
| org     | `passkey`                        | `Configuration::PasskeysController` `{new, create}`                                                                                                                                   |

`step_up_supported_methods` returns the corresponding set per surface.

For com: the `namespace :verification` `resource :totp` route, the `namespace :configuration`
`resources :totps` route, `Sign::Com::Verification::TotpsController`, and any com TOTP views are
removed.

For org: the email registration routes remain (for credential management) but are **not**
bootstrap-exempt. Org users must register a passkey as their first method.

Telephone registration and passcode-management controllers are not bootstrap-exempt on any surface
because they are not step-up methods.

### F. Bootstrap

- **F1.** Trigger: the actor's persisted `multi_factor_status_id` is `UNCONFIGURED` (`5`). The
  status is calculated from the same narrow surface-aware credential definition as
  `ConfiguredMethods(actor)`: only step-up-eligible credentials count. Social-login identities,
  telephones, and passcodes do not satisfy this check.
- **F2.** Exemption helper:

  ```ruby
  def require_step_up_unless_bootstrap!(scope:)
    return true if step_up_bootstrap_unconfigured?
    require_step_up!(scope: scope)
  end
  ```

  applied as `before_action` on the actions listed in E. Both `new` and `create` (and `edit` /
  `update` for email/telephone OTP confirmation) re-evaluate the persisted MFA status to bound the
  TOCTOU window to a single request. The status is refreshed by credential lifecycle callbacks.

- **F3.** Re-bootstrap is permitted. If credential lifecycle changes recalculate
  `multi_factor_status_id` back to `UNCONFIGURED` for any reason (admin revocation, status downgrade
  due to email bounce, data fix), the actor re-enters bootstrap mode. Operational ratchet-locks are
  intentionally not enforced; recovery via fresh registration is the fallback.
- **F4.** No audit event or notification is emitted specifically for bootstrap completion. Standard
  credential-registration audit events continue to fire.
- **F5.** Sign-up flow stays separate. `Sign::App::Up::TelephonesController#passkey_registration`
  continues to handle the pstep-up "create account + first passkey" wizard. Bootstrap covers the
  post-auth case where an existing account (e.g., social-login-only) reaches zero configured
  methods. Future sign-up paths (additional social providers, invitations, SAML) can evolve
  independently.

### G. Setup-after-registration return flow (X')

After a bootstrap registration completes successfully, the registration controller:

1. Decodes `params[:rt]` (base64-url-encoded internal path) with `safe_internal_path` validation.
2. Sets `flash[:notice]` with a key that names the next operation (for example,
   `t("sign.app.configuration.bootstrap.proceed_to_action")` — exact key to be defined by the
   implementer).
3. Calls `safe_redirect_to(decoded_rt, fallback: <surface>_configuration_path(ri: params[:ri]))`.

At the original sensitive endpoint, `require_step_up!` fires again. This time
`ConfiguredMethods.empty?` is false, so the user is sent to `/verification` (not setup) and
completes step_up with the freshly-registered credential. The original action then proceeds.

### H. Removals

- com `verification.totp` route and `configuration.totps` route
- `app/controllers/sign/com/verification/totps_controller.rb`
- com TOTP views, if any
- `app/views/sign/app/step_up/*.html.erb` (4 files) — orphan
- `app/views/sign/org/step_up/*.html.erb` (4 files) — orphan
- `STATUSES` literal members `CANCELLED` and `EXPIRED` in the three step_up_session models
- The `(<actor>_id, status)` non-unique index, replaced by `UNIQUE(<token>_id)`

Out of scope for this ADR (tracked separately):

- `Sign::App::Configuration::GooglesController#destroy` is missing and `resource :google` does not
  include `destroy`. Adding Google unlink symmetric to Apple is a follow-up.

## Rationale

**Why DB-backed.** Cookie-based step-up state cannot participate in revoke-all-sessions, cannot be
observed across devices for audit, and cannot persist `attempt_count` for ticket-scoped lockout. The
existing schemas (with `Retainable`, `attempt_count`, `verified_at`) already encode these
capabilities; reviving them is cheaper than designing a parallel mechanism on top of the cookie
store.

**Why co-located with the token.** A pending step-up ticket is login/session state: it must be
consumable only by the browser session that started it, and it must not let another session for the
same actor view, overwrite, or consume the ticket. Keeping the ticket beside the token also avoids
cross-DB logical references.

**Why upsert with `UNIQUE(<token>_id)`.** Carrying multiple PENDING tickets per token adds
implementation complexity (when to cancel which, how to choose which ticket to verify against)
without a clear UX win. Separate tokens for the same actor can still run independent step-up flows.
Upsert also lets us drop `CANCELLED` from the status enum entirely.

**Why narrow Configured definition.** Bootstrap exists because the user has nothing to step_up
**with**. Social-login identities cannot issue a step-up challenge; passcodes are AAL1 sign-in
methods, not session-elevation methods. Counting them in `Configured` would force a
social-login-only user to "step_up with their Google identity" — there is no such flow.

**Why ticket-scoped lockout only.** Account-scoped lockout is harsher on legitimate users (one stray
child / cat at the keyboard locks the whole account) and adds another piece of state
(`User.step_up_locked_until` or equivalent). Ticket-scoped is the minimum that prevents unbounded
brute-force within a single sensitive operation. If session-theft brute-force across scopes becomes
an observed pattern, account-scoped can be layered on later.

**Why 15 minutes uniformly.** Splitting GET vs POST windows complicates the spec without a clear
operational benefit. 15 minutes is long enough for ordinary form-completion latency and short enough
to keep step-up meaningful.

**Why re-bootstrap allowed.** A strict ratchet (`bootstrap_completed_at` flag) protects against a
credential-downgrade-then-rebootstrap attack vector, but the downgrade itself requires either
operator action or a slow natural process. The safety benefit is small, and the cost of a strict
ratchet — users losing all access after operator-led revocation must go through a manual support
path — is large. The implementer-mistake recovery argument carried decisive weight in the dialogue.

**Why X' (auto-bounce with flash) for setup return.** Z (drop to `/configuration`) makes the user
re-navigate to the action they were already trying to do — a UX regression from the intended "one
credential and you can proceed" experience. Y (explicit confirmation page) adds a click and a "no"
branch to design. X (silent auto-bounce) is jarring. X' adds one flash line and inherits the same
code path as X.

## Consequences

- The implementation plan is captured in `plans/active/step_up-step-up-rebuild.md`. Implementation
  will be carried out by a separate AI agent in phases.
- Schema migrations keep the step-up tables on the three token databases (`mark`, `symbol`, `token`)
  and key them by token id.
- Controllers in `configuration/` namespaces gain a new `before_action` helper and now honor
  `params[:rt]` on `create`. Existing tests that assert post-create redirect destination must be
  updated.
- `ALLOWED_SCOPES` and the per-controller `verification_scope` values must be kept in lockstep with
  the table in section D. A test asserting the cross-reference is recommended.
- The `manage_totp` → `configuration_totp` rename requires updating one constant and one
  `verification_scope` return value. No external URL changes.
- com no longer has TOTP routes or controllers. Any external bookmarks pointing to
  `/configuration/totps` on the com host break with 404. Acceptable because the feature was never
  advertised on com.
- The `/verification/setup/new?ri=...&rt=...` URL is unchanged. Existing inbound bookmarks (from the
  user's question — `https://id.umaxica.app/verification/setup/new?ri=jp&rt=...`) continue to work.

## Related

- `adr/sign-configuration-sprint-spec.md` — earlier sprint that introduced
  `AuthMethodGuard.last_method?` (the unlink-side guard complementary to step-up).
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md` — refresh-path AAL guarantees that this
  ADR's `step_up_satisfied?` depends on.
- `plans/active/step_up-step-up-rebuild.md` — the implementation plan that operationalizes this ADR.
