# Step-Up Authentication Mechanism Rebuild Plan

> **Deprecated by Identity Authority inversion where this plan assigns step-up freshness, session,
> or token authority to `sign/id`:** `acme/www` now owns Session, Token, Account, Preference,
> Authorization, and downstream-token authority. `sign/id` is ceremony-only. Physical DB movement is
> out of scope. Implementation details in this plan must not be used to reintroduce sign-side
> authority.

**Status:** Active (2026-05-11) — This file is a specification document that is a prerequisite for
implementation by another AI. The implementation is not done in this file.

**Refresh note (2026-05-19):** This plan still contains older descriptions that have been
implemented or superseded by later decisions. The current authoritative DB names are `app_ticket`,
`com_ticket`, and `org_ticket`. `settings_connection` and `operator_lifecycle` are step-up scopes
added by later features, so do not delete them. WebAuthn challenges should remain in the session
store; the Solid Cache move is treated as canceled.

## background

`adr/step-up-authentication-redesign.md` A work plan to implement the redesign decided on. All
design decisions are fixed on the ADR side, so this plan **In what order, which files, and how to
touch** handle only. If you have any doubts about the design, refer to the relevant section of ADR
and update ADR if necessary before proceeding with implementation.

## Related ADR / Plan

- `adr/step-up-authentication-redesign.md` — Basis of this plan ADR (must read)
- `adr/sign-configuration-sprint-spec.md` — `AuthMethodGuard.last_method?` (unlink side guard)
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md` — AAL guarantee for refresh token route
- `plans/backlog/restoration-a2-refresh-revoke-aal-hardening.md` — Implementation plan for the above
  ADR

## Current list of failures (reference)

Before proceeding with implementation, please understand the overall picture as these are currently
broken behaviors that will be resolved upon completion of this plan:

- `StepUp::AvailableMethods` and `StepUp::ConfiguredMethods` are the same implementation.
- `Verification::SetupsController#new` is a 3-line stub, neither surface differences nor registered
  method differences are reflected.
- Registered controller (`Configuration::PasskeysController#new/create` etc.) is `params[:rt]` don't
  read. setup → registration → bounce to the original sensitive operation has expired.
- `ClientStepUpSession` / `VisitorStepUpSession` / `OperatorStepUpSession` The model exists, but no
  controller is using it (the step-up state is stored in the cookie session).
- `app/views/sign/{app,org}/step_up/*.html.erb` (8 pieces in total) is an orphan without a
  controller.
- There is no `session_revoke_all` in `ALLOWED_SCOPES`, and from `session#destroy`
  `ActionController::BadRequest` when it comes to `/verification?scope=session_revoke_all`.
- `settings_mfa` regex and route of `ALLOWED_SCOPES` are on all surfaces. Align to
  `/settings/mfa/challenge`.
- `Sign::App::Settings::GooglesController#destroy` is not implemented, nor is it in routes (not
  covered by this plan. This will be dealt with in a separate task).

## How to cut PR

The following phases are **Basically independent PR in numerical order** Cut as. If the previous
phase written in the "Dependency" column of each phase has been merged, the subsequent phase may be
reversed. Tests are completed within a phase.

---

## Phase 1: DB location relocation and schema simplification

**Depends on:** None

**Purpose:** `*_step_up_sessions` table token It is maintained as a temporary login/session state on
the DB side and linked to the current token. `method` Make it nullable, add `UNIQUE(<token>_id)`,
and shorten `STATUSES`.

**work:**

1. Update token DB side schema:
   - `db/app_tickets_migrate/...` / `db/app_ticket_schema.rb` —
     `user_step_up_sessions.user_token_id`
   - `db/com_tickets_migrate/...` / `db/com_ticket_schema.rb` —
     `visitor_step_up_sessions.visitor_token_id`
   - `db/org_tickets_migrate/...` / `db/org_ticket_schema.rb` —
     `staff_step_up_sessions.staff_token_id`
   - The columns are the same as the current schema, but the differences are as follows:
     - `method` to `null: true`.
     - Since the `STATUSES` constraint is expressed using inclusion on the model side rather than on
       the DB, `status` remains a string.
     - `attempt_count` default 0, `discarded_at` default Equivalent to `Float::INFINITY`, similar to
       `purged_at`.
     - `UNIQUE(user_token_id)` / `UNIQUE(visitor_token_id)` / `UNIQUE(staff_token_id)` Added (full
       UNIQUE instead of partial index).
   - Do not create existing `(<actor>_id, status)` non-unique indexes.
2. Model related changes:
   - `ClientStepUpSession < AppTicketRecord`, `belongs_to :user_token`
   - `VisitorStepUpSession < ComTicketRecord`, `belongs_to :visitor_token`
   - `OperatorStepUpSession < OrgTicketRecord`, `belongs_to :staff_token`
   - Delete `has_one :step_up_session` on the actor side and place `has_one :step_up_session` on the
     token side.
   - Change `STATUSES = %w(PENDING VERIFIED CANCELLED EXPIRED)` to `%w(PENDING VERIFIED)`.
   - `validates :method, ..., inclusion: { in: METHODS }` Changed to
     `validates :method, inclusion: { in: METHODS }, allow_nil: true`.
3. Since it is assumed that it has not been deployed, step-up-session added to the actor DB side
   Migration is deleted/replaced without adding.
4. Check bind destination of `RetentionPurgeJob`: `Retainable` There shouldn't be any need to change
   the code since the arrangement that enters the purge target via Make sure the connection switch
   sees the token DB.
5. schema dump updated: `bin/rails db:schema:dump` to related DB, `db/app_principal_schema.rb`,
   `db/com_principal_schema.rb`, `db/org_principal_schema.rb`, `db/app_ticket_schema.rb`, Update
   `db/com_ticket_schema.rb`, `db/org_ticket_schema.rb` as necessary.

**test:**

- `test/models/user_step_up_session_test.rb` / `customer_step_up_session_test.rb` / Modified
  `staff_step_up_session_test.rb` for new DB.
- Assert that `ActiveRecord::RecordNotUnique` is issued due to violation of `UNIQUE(<token>_id)`.
- `method = nil` passes `validates`, `method = "passkey"` also passes, `method = "invalid"` Confirm
  that it is repelled by
- inclusion of `STATUSES` passes only in `PENDING` / `VERIFIED`, `CANCELLED` / `EXPIRED` Confirm
  that it is repelled by

**Rollback:** `bin/rails db:rollback` that the old schema can be restored in `down` for each
migration Check manually. Cannot be uploaded to CI (takes time).

---

## Phase 2: Service layer `StepUp::ConfiguredMethods` / `AvailableMethods` separation

**Dependency:** None (can be paralleled with Phase 1)

**Purpose:** byte-for-byte To differentiate the meanings of two services that are the same.

**work:**

1. `app/services/step_up/configured_methods.rb`:
   - The contents remain as they are (`email VERIFIED|VERIFIED_WITH_SIGN_UP`, `passkey ACTIVE`,
     `totp ACTIVE`).
   - **When viewed from the outside later, it will be easier to understand at a glance that it
     represents "permanent state only"** Include one or two lines of module comments.
2. `app/services/step_up/available_methods.rb`:
   - Changed signature to `call(subject, ticket: nil)`.
   - Call `Configured` and subtract the following from it:
     - `methods_in_cooldown(subject)`: Solid Cache Exclude method where
       `step_up_cooldown:{actor_type}:{actor_id}:{method}` key exists.
     - `ticket && ticket.attempt_count >= 5` returns an empty set.
   - Cooldown value constant `StepUp::Cooldowns = { email_otp: 60, passkey: 5, totp: 5 }.freeze`
     Defined by.
   - Cooldown is written in a separate module (`StepUp::CooldownStamp.call(actor, method)` etc.).
     The writing location will be called during step-up trial recording in Phase 4.
3. `step_up_supported_methods` by surface `Verification::Base` Assuming you have already separated
   on the side, `ConfiguredMethods` / `AvailableMethods` itself looks at all methods regardless of
   surface. The surface filter takes the intersection on the caller side
   (`Verification::Base#step_up_supported_methods`).
4. Add auxiliary modules such as `app/services/step_up/cooldowns.rb` under `step_up/`.

**test:**

- `test/services/step_up/configured_methods_test.rb`: Return correct set with or without 3-way
  method.
- `test/services/step_up/available_methods_test.rb`:
  - Base case matching Configured.
  - The corresponding method is removed when the cooldown key is entered.
  - `ticket.attempt_count >= 5` becomes an empty set (method cooldown is irrelevant).
  - Customer / Staff Each actor should move in the same way.

---

## Phase 3: Scope catalog bug fixes

**Depends:** Phase 2 (shares the premise of touching `Verification::Base`)

**Purpose:** Fixed two bugs in `ALLOWED_SCOPES`, renamed `manage_totp` → `settings_totp`.

**work:**

1. `ALLOWED_SCOPES`(`app/controllers/concerns/sign/app_verification_base.rb` and same com / org
   equivalent concern) to the basic scope and subsequent additional scope of ADR § D. 9 cases are
   not fixed. `settings_connection` and `operator_lifecycle` will be left for use by existing
   functions.

   ```ruby
   ALLOWED_SCOPES = {
     "social_unlink"           => %r{\A/social/},
     "session_revoke_all"      => %r{\A/settings/sessions},
     "withdrawal"              => %r{\A/settings/withdrawal},
     "settings_email"     => %r{\A/settings/emails},
     "settings_telephone" => %r{\A/settings/telephones},
     "settings_passkey"   => %r{\A/settings/passkeys},
     "settings_mfa"       => %r{\A/settings/mfa/challenge},
     "configuration_secret"    => %r{\A/settings/secrets},
     "settings_totp"      => %r{\A/settings/totps},
   }.freeze
   ```

2. `verification_scope` of `app/controllers/sign/app/settings/totps_controller.rb` Changed from
   `"manage_totp"` to `"settings_totp"`.
3. grep the `verification_scope` string for all controllers and use `StepUp::ScopeCatalog` Check to
   see if anything that came off is left behind.
4. surface Another concern(`app_verification_base` / `com_verification_base` /
   `org_verification_base`) `ALLOWED_SCOPES` If it is possible to share the same content, cut it out
   in one place and include it using include (leave the design decision to the implementation side,
   there is no need to force it into commonality).

**test:**

- `VerificationsController` integration test for each surface shows all 9 catalog scopes are
  accepted only when the return-target token is valid for the current session, surface, and flow.
  Invalid or mismatched `rt` must not start a reusable step-up continuation.
- Added one integration test for session destruction route including `session_revoke_all`.

---

## Phase 4: DB-backed `Verification::Base` and bootstrap helper

**Depends:** Phase 1, Phase 2, Phase 3

**Purpose:** Switch from cookie route to DB route, add `require_step_up_unless_bootstrap!`, Align
the branch of `enforce_step_up_prereqs!` with ADR § F.

**work:**

1. `app/controllers/concerns/verification/base.rb`:
   - Cookie-based judgment for `verification_satisfied?` has been **removed**.
   - Process to upsert the current token `step_up_session` when the sensitive operation gate fires.
     Added to `require_step_up!` (specific method name is at the discretion of the implementer, but
     `find_or_initialize_by` base).
   - Rewrite `start_step_up_session!` (currently in `VerificationStepUpSessionStore`) to DB upsert.
     Writes to `session[STEP_UP_SESSION_KEY]` have been deleted.
   - Added `require_step_up_unless_bootstrap!(scope:)`. In the current accepted ADR actor
     `multi_factor_status_id = 5` instead of `ConfiguredMethods.empty?` Use (`UNCONFIGURED`) for
     bootstrap determination:
     ```ruby
     def require_step_up_unless_bootstrap!(scope:)
       return true if step_up_bootstrap_unconfigured?
       require_step_up!(scope: scope)
     end
     ```
   - Branch `enforce_step_up_prereqs!` to setup only when `multi_factor_status_id = 5`. ACTIVE+ If
     Available is empty (all cooldown / lockout), usually go to `/verification`.
   - `step_up_satisfied?` remains `actor_token.last_step_up_at` (The success fact is held on the
     token side). VERIFIED in the step_up_session line is an auxiliary record.
   - Unify the TTL constant with `STEP_UP_TTL = STEP_UP_TTL = 15.minutes`. `VERIFICATION_GET_TTL` /
     `VERIFICATION_POST_TTL` has been deleted.
2. `app/controllers/concerns/sign/verification_step_up_session_store.rb`:
   - Rewritten cookie operations to DB upserts.
   - `current_step_up_session` returns the current token `step_up_session`.
   - Removed all references to old `session[STEP_UP_SESSION_KEY]`. `session[EMAIL_OTP_SESSION_KEY]`
     is Solid Move via Cache (Phase 5).
3. `app/controllers/concerns/sign/{app,com,org}_verification_base.rb`:
   - Leave `STEP_UP_TTL = 15.minutes` (or consolidate it in one place).
   - Removed `EMAIL_OTP_SESSION_KEY` reference.
4. Inside `consume_step_up_session!` (`VerificationStepUpLifecycle`):
   - `actor_token.update!(last_step_up_at: Time.current, last_step_up_scope: scope)`
   - Delete pending `step_up_session` row.
   - `clear_step-up_state!` deletes email OTP cache state. WebAuthn challenge is session Handled by
     one-time-use / TTL on the store side.
5. The process of incrementing `attempt_count` for each method validation failure path
   (`verify_email_otp!` / `verify_totp!` / passkey verify). `attempt_count >= 5` at
   `AvailableMethods.call(actor, ticket:)` returns an empty set, so the higher-level display control
   closes naturally.

**test:**

- `step_up_session` on DB is properly upsert at gate-entry (existing lines are overwritten when
  re-entering in another scope).
- Pass through when `require_step_up_unless_bootstrap!` is `multi_factor_status_id = 5`, when `1`
  Confirm that it enters the `require_step_up!` route using controller test.
- `AvailableMethods` is empty in `attempt_count >= 5`, `/verification` The message
  "Re-authentication is temporarily suspended" appears on the screen (integration test).

---

## Phase 5: Challenge state organization (B-2)

**Depends on:** Phase 4

**Purpose:** Email OTP's secret/counter is sent to the cache side. WebAuthn challenge is session Use
store as normal and do not move to Solid Cache.

**work:**

1. Key name convention: `step_up_session:#{step_up_session.id}:#{method}`, TTL is less than or equal
   to `STEP_UP_TTL`.
2. `Sign::AppVerificationBase#send_email_otp!` / `verify_email_otp!` Solid Rewritten via Cache.
   Completely removed `session[EMAIL_OTP_SESSION_KEY]` reference.
3. The passkey challenge issuance maintains `session[:passkey_challenges]`.
4. Treat old instructions to move WebAuthn challenges to Solid Cache as revoked.

**test:**

- email OTP Send → Retransmission within 60 seconds will be prevented by cooldown.
- email OTP secret disappeared from Solid Cache `verify_email_otp!` returns a "resubmit required"
  error.
- The passkey challenge must be expired by the TTL / one-time-use rule in the session store.

---

## Phase 6: Bootstrap exemption of registered controller and restoration of `rt`

**Depends on:** Phase 4

**Purpose:** ADR § Re-upholster `before_action` according to the table in E, and when create is
completed, `params[:rt]` X' redirect according to

**Work (app example. com/org is also expanded to the same type):**

1. `app/controllers/sign/app/settings/passkeys_controller.rb`:
   - `before_action -> { require_step_up_unless_bootstrap!(scope: "settings_passkey") }, only: %i(new create)`
   - `before_action -> { require_step_up!(scope: "settings_passkey") }, only: %i(edit update destroy)`
   - Added a branch that respects `rt` in redirect when `create` succeeds (see
     `bootstrap_return_path` below).
2. `app/controllers/sign/app/settings/totps_controller.rb`:
   - Same. Use `settings_totp` scope.
3. `app/controllers/sign/app/settings/emails/registrations_controller.rb`:
   - 4 All actions `require_step_up_unless_bootstrap!` to before_action.
   - Respect `rt` when final confirmation (`update`) is successful.
4. `app/controllers/sign/com/settings/{passkeys,emails/registrations}_controller.rb`:
   - Same type as app (com has no TOTP, deleted in Phase 7).
5. `app/controllers/sign/org/settings/passkeys_controller.rb`:
   - Bootstrap exemption is only passkey.
   - org's email registration controllers **does not exempt bootstrap** (`require_step_up!` only).
6. Put the common helper in `Verification::Base` or a new concern. It must validate `rt` through the
   return-target token primitive; do not decode raw Base64 paths:

   ```ruby
   def bootstrap_return_path(default_path)
     return_target = ReturnTargetToken.resolve(
       params[:rt],
       session: current_session_public_id,
       surface: Actor.tld,
       flow: "step_up_bootstrap",
     )

     return_target&.path.presence || default_path
   end
   ```

7. On each successful create/update:
   ```ruby
   safe_redirect_to(
     bootstrap_return_path(sign_app_settings_path(ri: params[:ri])),
     fallback: sign_app_settings_path(ri: params[:ri]),
     notice: I18n.t("sign.app.settings.bootstrap.proceed_to_action"),
   )
   ```
   (The i18n key will be newly created by the implementer. com / org will also create a key of the
   same type.)

**test:**

- `/settings/passkeys/new` with bootstrap = true(`multi_factor_status_id = 5`) Confirm with
  controller test that it can be inserted into the .
- In the same situation, after `create` succeeds, redirect to the URL specified by a valid,
  session-bound `rt` and set `flash[:notice]`. Invalid, replayed, cross-surface, or cross-flow `rt`
  falls back safely.
- bootstrap = Confirm that the step-up gate fires when trying to enter the same URL with
  false(`multi_factor_status_id = 1`).
- TOCTOU simulation: Obtain the form with GET, create a credential using another route, and then
  check that POST enters the step-up route (integration test).

---

## Phase 7: Renewal of `SetupsController`

**Depends on:** Phase 2, Phase 6

**Purpose:** Display links for "unregistered methods only" for each surface. If all are registered
`/verification` Bounce immediately.

**work:**

1. `app/controllers/sign/{app,com,org}/verification/setups_controller.rb`:
   - Calculate `configured_step_up_methods` and `step_up_supported_methods` with `new` action.
   - If `step_up_supported_methods - configured_step_up_methods` is empty, `/verification`
     Immediately redirect to (`safe_redirect_to verification_redirect_path(...)`).
   - If it is not empty, only the difference set is packed into `@missing_methods`.
   - Preserve `params[:rt]` only as an opaque return-target token. Do not decode it in the setup
     controller or view.
2. view `app/views/sign/{app,com,org}/verification/setups/new.html.erb`:
   - Loop through `@missing_methods` and display only links. telephone ​​Link removed (ADR § Not
     applicable for bootstrap according to E).
   - View for org only has passkey 1 link.
   - Pass `ri: params[:ri], rt: @rt` to each link.
3. Removed TOTP link from com setup view (Phase Since controller and routes will disappear in
   version 8, we will only need to modify the view side here).

**test:**

- `/verification/setup/new` returns 200 with credential 0, 3 types(app)/ 2 types(com)/ To draw one
  type of (org) link.
- If you enter URL with one item already registered, the link for the registered method will
  disappear.
- If you enter URL with all types registered, you will be redirected to `/verification` (302).

---

## Phase 8: com TOTP deletion and orphan view removal

**Depends:** Phase 7 (404 link remains if the TOTP link in setup view is not deleted first)

**Purpose:** Physically delete the code and clean up the orphan view according to the policy of not
handling TOTP on com (ADR § E).

**work:**

1. com side block of `config/routes/sign.rb`:
   - Delete `resource :totp, only: %i(new create)` line in `namespace :verification`.
   - Delete `resources :totps, ...` line in `namespace :settings`.
2. File deletion:
   - `app/controllers/sign/com/verification/totps_controller.rb`
   - `app/views/sign/com/verification/totps/` (for each directory, if it exists)
   - `app/views/sign/app/step_up/{index,new,show,edit}.html.erb`
   - `app/views/sign/org/step_up/{index,new,show,edit}.html.erb`
3. i18n key:
   - Make sure that `sign.app.step-up.*` / `sign.org.step-up.*` is not referenced elsewhere and
     Removed from `config/locales/`.
   - com's TOTP related i18n keys are also deleted if they are not referenced.

**test:**

- com's `/settings/totps` returns 404 (routing test).
- There are no other require / render references to the deleted file (grep + CI).

---

## Phase 9: Integrity and documentation

**Depends:** Phase 1~8

**Purpose:** Final check after completion of all phases.

**work:**

1. "Implementation" of `adr/sign-configuration-sprint-spec.md` Status table shows the specifications
   (step-up) implemented in this ADR. Check if the changes (DB migration, bootstrap restoration) are
   reflected. Add if necessary.
2. `docs/spec/authentication-authorization-requirements-phase-1.md` Make step-up related
   descriptions consistent with ADR.
3. Move this plan from `plans/active/` to `plans/archive/` (after all phases are completed).

**test:**

- End-to-end integration test for key user flows 3 scenarios:
  - **Bob Scenario**: `/settings/apple#destroy` with an account created only with social-login Step
    on , setup → passkey registration → automatic bounce → step-up → Apple unlink completed.
  - **Frank scenario**: passkey + email already registered `/settings/withdrawal` → step-up →
    Withdrawal starts.
  - **Eve scenario**: 5 consecutive failures with only one passkey → ticket lockout →
    `/verification` "Re-authentication temporarily suspended" is displayed.

---

## Checklist before implementation (for another AI)

- [ ] `adr/step-up-authentication-redesign.md` I read the entire text and understood the decisions
      and reasons.
- [ ] Existing `app/services/step_up/*.rb`, `app/controllers/concerns/verification/base.rb`, Read
      `app/controllers/concerns/sign/{app,com,org}_verification_base.rb`
- [ ] 3 Understood the schema dump generation procedure for each DB (`principal`, `guest`,
      `operator`)
- [ ] Test DB is ready (`bin/rails db:test:prepare`)
- [ ] I understand the policy of cutting PR by phase.
- [ ] Comply with the prohibitions of AGENTS.md (`permit!`, `skip_before_action`, `html_safe`, etc.)
