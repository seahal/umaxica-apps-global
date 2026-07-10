# Sign-Up Boundary Audit and Hard-Migration Plan

> Read-only audit. No runtime code, routes, models, views, registries, migrations, or tests were
> changed to produce this document. This is the only file written.

## Context

This audit answers a "grill me with docs" request: trace every existing sign-up flow end to end,
challenge stale assumptions, determine the real authority/provisioning boundary, propose one final
sign-up route + ceremony contract, and produce a hard-migration plan with exact files and tests.

The headline conclusion is **not** what the task premise expected. The premise imagines a chaotic
sign-up surface that still needs route cleanup (`/auth/*` removal, `/sign/up/*` adoption, social
de-duplication). That cleanup is **already done**. The routing layer is conformant. The real,
unfinished migration is the **identity-authority inversion**: today the **Sign** surface creates the
canonical actor and issues the central session, which **violates the accepted authority ADRs** that
name **Acme** as the sole Session/Account/Token/Authorization Authority and **Sign** as a
credential-ceremony gateway that may only return signed evidence. A partial inversion has already
landed for the social path; email/telephone/org have not been inverted.

Evidence is cited as `path:line`. Where the citation is a method/region rather than a single line,
the controller/service is named so it can be opened directly.

---

## 1. Executive summary

1. **Route namespace is already the target.** Human sign-up lives under `/sign/up/*`; social under
   `/social/:provider/{sign/in,sign/up,callback}`; OAuth authority under `/oauth/*`; RP launcher
   under `/oidc/authorization` + `/oidc/callback`. **No runtime `/auth/*` HTTP route exists**
   (`bin/rails routes | grep ' /auth'` is empty; confirmed across all `config/routes/*.rb`). The
   internal `Sign::App::Auth::*` Ruby namespace is _not_ an HTTP contract.
2. **The authoritative ceremony contract already exists** as accepted ADRs
   (`adr/identity-authority-boundary.md`, `adr/sign-residual-idp-surface-retirement.md`,
   `docs/security/social-callback-boundary.md`): Acme issues a one-shot, audience/purpose-bound
   ceremony **grant**; Sign returns a signed ceremony **result**; **Acme** consumes it and commits
   account/session state. There is nothing new to invent for the contract.
3. **The implementation contradicts the contract for everything except the social commit path.**
   Today **Sign** creates the durable `Client`/`Visitor`, creates `rp_account`, writes the sign-up
   audit, and then **Sign establishes the central session** itself (`AuthenticationBase#log_in` →
   `reset_session` + token record + refresh rotation + login cookies,
   `app/controllers/concerns/authentication_base.rb:344-416`). The authority docs explicitly
   classify this as a **migration gap**, not a competing source of truth
   (`docs/identity/authority-boundary.md:26-29`).
4. **Partial inversion already shipped for social.**
   `Acme::App::Social::AuthenticationsController#completion` consumes a signed
   `social_ceremony_result` via `IdentitySocialCeremonyFinalCommitter.call!` and provisions the
   durable graph with `IdentityGraphProvisioner.call!`
   (`app/controllers/acme/app/social/authentications_controller.rb`). The legacy Sign
   `omniauth_callbacks` path still exists in parallel — a dual path that must be collapsed.
5. **Surface policy is correct and must not be "symmetrized."** app = public (email, telephone,
   Google, Apple). com = public email/telephone only, **social-free**. org = **invitation-only**
   operator acquisition + lifecycle requests, **no public self-registration**. Palm = app-only
   native client that bounces to the Acme/Sign browser ceremony (`screen_hint: "signup"`), with **no
   native account-creation endpoint**. Do not add Palm com/org.
6. **Concrete defects found** (independent of the inversion):
   - `flash.now[:alert]` in `app/controllers/sign/org/sign/up/invitations_controller.rb` — direct
     violation of the AGENTS.md no-flash rule.
   - Stale `/social/:provider/callback` vocabulary is now the accepted contract in
     `adr/sign-up-authentication-handoff-and-social-rt.md:60` and the state-machine plan — the
     public callback paths are `/social/google/callback` and `/social/apple/callback`.
   - `docs/security/sign-up-sequence.md` still documents Sign-owned finalization while the freshly
     edited `docs/security/sign-in-sequence.md` already describes the Acme-owned ceremony model —
     the two are now internally inconsistent.
   - Org invitation token is stored in plaintext (`organization_invitations.code`), acceptance does
     **not** require AAL2, and the created `Operator` is `ACTIVE` with an auto-`VERIFIED` email.
   - Terms/consent are not versioned (`confirm_policy` is a transient checkbox; `consent_version` is
     a single UUID with no history).
7. **Verdict:** the current sign-up _routing_ architecture is acceptable and should be frozen. A
   **hard migration is required**, but it is the authority inversion (move identity creation +
   session issuance to Acme behind the grant/result contract), already tracked by
   `plans/active/identity-authority-inversion-first-slice.md` and
   `plans/active/acme-sign-core-base-port-implementation.md` — **not** a route rename. **No public
   `/auth/*` route exists.**

---

## 2. Current route inventory

Source: `bin/rails routes` (full dump captured during audit) + `config/routes/sign.rb`,
`config/sign_route_mapper.rb`, `config/routes/acme.rb`, `config/routes/palm.rb`.

### Sign — human sign-up ceremonies (host-scoped)

| Verb           | Path                                                                                                       | Host           | Product/Surface | Controller#action                                             | Class                                     |
| -------------- | ---------------------------------------------------------------------------------------------------------- | -------------- | --------------- | ------------------------------------------------------------- | ----------------------------------------- |
| GET            | `/sign/up`                                                                                                 | id.umaxica.app | Sign/app        | `sign/app/sign/ups#show`                                      | canonical                                 |
| GET/POST       | `/sign/up/email`(+`/new`)                                                                                  | app            | Sign/app        | `sign/app/sign/up/emails#{new,create}`                        | canonical                                 |
| GET/PATCH      | `/sign/up/email/edit`,`/sign/up/email`                                                                     | app            | Sign/app        | `…/emails#{edit,update}`                                      | canonical (OTP)                           |
| GET/POST/PATCH | `/sign/up/telephone*`                                                                                      | app            | Sign/app        | `…/telephones#…`                                              | canonical                                 |
| GET            | `/sign/up/guard/{email,telephone,google,apple}`                                                            | app            | Sign/app        | `…/sign/up/guard/*#show`                                      | canonical                                 |
| GET/PATCH/POST | `/sign/up/check/{email,telephone,apple,google}/{otp,birthdate,passkey,passcode,confirmation,cancellation}` | app            | Sign/app        | `…/sign/up/check/**`                                          | canonical                                 |
| GET            | `/social/{google,apple}/sign/up`                                                                           | app            | Sign/app        | `sign/app/social/authentications#continue` (`entry: sign_up`) | canonical                                 |
| GET            | `/social/{google,apple}/sign/in`                                                                           | app            | Sign/app        | same `#continue` (`intent: login`)                            | canonical                                 |
| GET / GET+POST | `/social/google/callback`, `/social/apple/callback`                                                        | app            | Sign/app        | `sign/app/auth/omniauth_callbacks#omniauth`                   | **transitional** (see §7)                 |
| GET            | `/sign/up`                                                                                                 | id.umaxica.com | Sign/com        | `sign/com/sign/ups#show`                                      | canonical                                 |
| GET/POST/PATCH | `/sign/up/{email,telephone}*`, `/sign/up/check/**`, `/sign/up/guard/*`                                     | com            | Sign/com        | `sign/com/sign/up/**`                                         | canonical (no social)                     |
| GET            | `/sign/up`                                                                                                 | id.umaxica.org | Sign/org        | `sign/org/sign/ups#show`                                      | canonical (recruiting guidance, no actor) |
| GET/POST       | `/sign/up/invitations`(+`/new`)                                                                            | org            | Sign/org        | `sign/org/sign/up/invitations#{new,create}`                   | canonical (invitation-only)               |

### Acme — authority protocol + post-auth management (no sign-up)

- `/oauth/authorize`, `/oauth/token`, `/oauth/userinfo`, `/oauth/revoke`,
  `/.well-known/openid-configuration` — Acme OP/AS only.
- `/oidc/authorization`, `/oidc/callback` — RP launcher/callback (accepted `base-rails-rp`
  boundary).
- `/oidc/logout`, `POST /oidc/backchannel/logout` — Acme/RP logout.
- `/sign/out/new|edit`, `POST /sign/out`, `/sign/out/complete` — RP local sign-out (unchanged).
- Acme `accounts`/`organizations` controllers on app/com/org — **authenticated management only**
  (`authenticate_{client,visitor,operator}!`), **zero sign-up routes**
  (`app/controllers/acme/{app,com,org}/accounts_controller.rb`). The untracked
  `test/controllers/acme/*/accounts_controller_test.rb` files are management tests (they bootstrap
  an already-authenticated actor), not sign-up tests.
- `Acme::App::Social::AuthenticationsController#completion` — the **new Acme-owned social commit
  endpoint** (consumes ceremony result). This is the inversion target already partly built.

### Palm — native (app only)

- `config/routes/palm.rb` constrains to `PALM_SERVICE_URL` / `palm.app.localhost`. **No com/org.**
- `GET /palm/app/oidc/authorization` → `Palm::App::Auth::AuthorizationsController#show` calls
  `initiate_oidc_session!(screen_hint: "signup")` and redirects to the Acme/Sign browser ceremony
  for clients `app-ios-rp` / `app-android-rp`. `GET /palm/app/oidc/callback`, `…/api/v0/profile`
  (bearer), `/sign/out`. **No native account creation.**

**`/auth/*`:** none at runtime. Reported as compliant.

---

## 3. Surface sign-up availability matrix

| Surface          | Policy                                                                                           | Why                                                                 | Evidence                                                                                           |
| ---------------- | ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Acme app/com/org | **none** (no sign-up route)                                                                      | Acme is authority + post-auth management; ceremony UI lives on Sign | `acme/*/accounts_controller.rb` authenticated-only                                                 |
| Sign app         | **public**: email, telephone, Google, Apple                                                      | end-user registration surface                                       | routes §2; `adr/sign-up-authentication-handoff-and-social-rt.md:51-60`                             |
| Sign com         | **public, email+telephone only; social disabled**                                                | corporate/visitor entry; social explicitly withdrawn                | `adr/sign-com-no-social-login.md`; `VisitorSignUpFlow` `validates :social_provider, absence: true` |
| Sign org         | **invitation-only** operator acquisition; lifecycle requests; public page is recruiting guidance | operator creation is a privileged lifecycle event                   | `docs/security/sign-up-sequence.md:747-839`; `sign/org/sign/ups#new` creates no actor              |
| Core app/com/org | **none** (delegates to Sign/Acme)                                                                | Core/Base are RPs, never identity authorities                       | `adr/acme-sign-core-base-port-boundary.md`                                                         |
| Base app/com/org | **none** (RP launcher only)                                                                      | uses `base-rails-rp` → Acme `/oidc/callback`                        | `adr/acme-rp-boundary-naming.md:52-54`                                                             |
| Palm app         | **none native** (bounces to browser ceremony)                                                    | native bearer Resource Server; OAuth via system browser             | `palm/app/auth/authorizations_controller.rb`                                                       |

Do **not** add public org/com social sign-up or Palm com/org for symmetry.

---

## 4. Actor / resource provisioning matrix

| Concern                  | app                                                                                                | com                                                   | org                                             |
| ------------------------ | -------------------------------------------------------------------------------------------------- | ----------------------------------------------------- | ----------------------------------------------- |
| Authority identity       | `Client` (`AppPrincipalRecord`)                                                                    | `Visitor` (`ComPrincipalRecord`)                      | `Operator`                                      |
| Primary identifier       | email / telephone / Google uid / Apple uid                                                         | email / telephone                                     | invitation `email`                              |
| Identifier normalization | `JitUtilsEmailValidator.normalize` → HMAC blind index `IdentifierBlindIndex.bidx_for_email`        | same                                                  | n/a (invitation email)                          |
| Uniqueness scope         | partial unique index on `address_digest WHERE status <> DELETED` (`client_emails`)                 | same on `visitor_emails`                              | unique index on `organization_invitations.code` |
| Credential models        | `ClientPasskey`, `ClientSecret`, `ClientGoogleIdentity`, `ClientAppleIdentity`                     | `VisitorPasskey`, `VisitorSecret`                     | operator passkey/secret via settings            |
| Profile/preference       | `rp_account` created at finalization; `*_preference` (consent fields)                              | same                                                  | n/a                                             |
| Session/token            | `ClientToken` (referenced by flow `token_id`)                                                      | visitor token                                         | operator session via org sign-in                |
| Flow/ticket carrier      | `ClientSignUpFlow < AppTicketRecord` (app_ticket DB)                                               | `VisitorSignUpFlow < ComTicketRecord` (com_ticket DB) | `OrganizationInvitation`                        |
| Initial status           | pending → `…_WITH_SIGN_UP` → finalized                                                             | same                                                  | `Operator ACTIVE` immediately                   |
| Verification state       | `*EmailStatus`/`*TelephoneStatus` enum incl. `VERIFIED_WITH_SIGN_UP=7`                             | same                                                  | operator email auto-`VERIFIED`                  |
| Who creates              | **Sign today** (`SocialAuthSignupFinalizer`, `finalize_sign_up_from_checkpoint!`) — should be Acme | **Sign today**                                        | `OrgOperatorLifecycleInvitationAcceptance`      |
| Who establishes session  | **Sign today** (`AuthenticationBase#log_in`) — should be Acme                                      | **Sign today**                                        | org sign-in (separate)                          |

The nine distinct operations the task asks not to conflate are genuinely distinct here: (1)
authority identity = `Client`/`Visitor`/`Operator`; (2) credential enrollment = passkey/secret/
social identity rows; (3) product profile = `rp_account` + preference; (4) org membership = operator
↔ organization; (5) org creation = lifecycle request; (6) preferences/consent = `*_preference`; (7)
OAuth client relationship = `base-rails-rp`/`app-ios-rp` etc.; (8) session = `ClientToken` +
cookies; (9) verification record = email/telephone status + OTP record.

---

## 5. Current end-to-end sequences

### 5.1 Direct browser email (app/com)

`GET /sign/up/email/new` (build empty email, no actor) → `POST /sign/up/email`
(`CloudflareTurnstile` validate, create/resume pending email verification + flow ticket, redirect) →
`GET /sign/up/email/edit` (OTP form, rejects if ticket missing/expired) → `PATCH /sign/up/email`
(verify HOTP via `SignOtpCeremony#verify!`; **existing-account branch redirects to sign-in**; new
account marks `VERIFIED_WITH_SIGN_UP`, advances flow) → `/sign/up/guard/email` →
`/sign/up/check/email/birthdate` (encrypted birthdate) → `finalize` → **Sign** establishes session →
welcome → `rt`/dashboard. State machine: `SignUpStateMachine` events `submit_contact` →
`verify_contact` → `enter_guardrail` → `enter_checkpoint` → `clear_requirement(:birthdate)` →
`finalize` → `handoff_to_sign_in` → `complete`.

### 5.2 Telephone (app/com)

As above but `POST` creates pending `Client`/`Visitor` + telephone + flow ticket; OTP verifies
**ownership only** (never finalizes); checkpoint requires birthdate **+ passkey + passcode** before
`finalize`. Confirmed in `docs/security/sign-up-sequence.md:461-485,722-745`.

### 5.3 OAuth-authorize continuation

`Sign::App::SignUpsController#show`: with `?login_challenge=…` it resumes the pending Acme
authorization transaction via `OidcAuthorizationTransactionService.find_by_login_challenge!` and
stores `session[:oidc_authorization_login_challenge]`; without it, `normalize_to_acme_authorize!`
starts a fresh Acme authorize. The `ClientOidcAuthorizationTransaction` is the carrier. After
finalization the same `login_challenge` drives code issuance through the sign-in boundary. So
sign-up **does** resume the exact validated authorization transaction; it does not mint a second
authorize. **The `reset_session` in `log_in` preserves
`oidc_code_verifier/oidc_state/oidc_nonce/oidc_pt`** (`authentication_base.rb`
`OIDC_RP_SESSION_KEYS`, `restore_oidc_rp_session_state!`).

### 5.4 Social (app only)

`GET /social/:provider/sign/{in,up}` → `…/social/authentications#continue` stores intent/entry/`rt`
**server-side** (entry derived from referer/param, not trusted for ownership) → provider →
`/social/:provider/callback`. Ownership is decided by **DB state**: `SocialAuthLoginHandler#call`
looks up `identity_class.lock.find_by(uid:, provider:)`; a linked `identity.user` → sign-in; an
orphaned/absent identity → `pending_social_signup`
(`app/services/social_auth_login_handler.rb:18-50`). New-identity creation is
`SocialAuthSignupFinalizer` inside `AppPrincipalRecord.transaction` (creates `Client` + provider
identity, raises `identity_conflict` if the uid is already linked). **Acme-side commit path** exists
in parallel: `Acme::App::Social::AuthenticationsController#completion` →
`IdentitySocialCeremonyFinalCommitter.call!(result_token:)` → `IdentityGraphProvisioner.call!`.

### 5.5 Invitation (org)

`POST /sign/up/invitations` validates Turnstile then
`OrgOperatorLifecycleInvitationAcceptance.call`. `OrganizationInvitation`: 32-char
`SecureRandom.alphanumeric` **plaintext** `code` (unique index), 7-day `expires_at`, one-time via
`consumed_at` (+ row lock). Acceptance creates `Operator ACTIVE` + `operator_emails` with
`confirm_policy: true, status VERIFIED, undeletable: true`. **No AAL2** at acceptance. No public
self-registration route exists (`resources :invitations` only).

### 5.6 Passkey-first sign-up

Not implemented as an entry method. Passkey is a **checkpoint-owned** requirement _after_ telephone
OTP (`/sign/up/check/telephone/passkey`), never a first-factor account-creation path. Do not invent
passkey-first sign-up.

### 5.7 Palm app

`GET /palm/app/oidc/authorization` → `initiate_oidc_session!(screen_hint: "signup")` (system
browser) → Acme `/oauth/authorize` → Sign ceremony → `/palm/app/oidc/callback` (PKCE/state) → bearer
token in secure storage. No native sign-up form; no duplicate Palm callback business logic.

---

## 6. Authority and ownership findings

| #   | Question                         | Answer **today (code)**                                                                           | Answer **authoritative (ADR target)**                          |
| --- | -------------------------------- | ------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| 1   | Creates canonical identity       | Sign (`SocialAuthSignupFinalizer`, `finalize_sign_up_side_effect!`)                               | **Acme** consuming ceremony result                             |
| 2   | Writes primary identifier        | Sign                                                                                              | Acme                                                           |
| 3   | Normalizes/enforces uniqueness   | `IdentifierBlindIndex` + partial unique index (DB)                                                | unchanged DB constraint; commit owned by Acme                  |
| 4   | Enrolls first credential         | Sign (passkey/secret/social identity rows)                                                        | Sign **executes ceremony**, Acme **commits link**              |
| 5   | Verifies email/telephone         | Sign (`SignOtpCeremony`)                                                                          | Sign (ceremony) → evidence to Acme                             |
| 6   | Accepts social identity          | Sign callback; Acme `#completion` (partial)                                                       | **Acme** account lookup/link decision                          |
| 7   | Account linking                  | Sign today; Acme `#completion` partial                                                            | **Acme** (`social-callback-boundary.md:21-27`)                 |
| 8   | Product profile (`rp_account`)   | Sign at finalize; `IdentityGraphProvisioner` on Acme social                                       | **Acme**                                                       |
| 9   | Org membership                   | `OrgOperatorLifecycleInvitationAcceptance`                                                        | unchanged (org lifecycle)                                      |
| 10  | Org creation                     | lifecycle request (AAL2)                                                                          | unchanged                                                      |
| 11  | Terms/consent                    | Sign form `confirm_policy` (transient)                                                            | Sign captures; Acme records authoritatively                    |
| 12  | Activates identity               | Sign (status → `…_WITH_SIGN_UP`)                                                                  | **Acme**                                                       |
| 13  | Establishes central session      | **Sign** (`log_in`/`reset_session`/token/refresh/cookies)                                         | **Acme — sole Session Authority**                              |
| 14  | Resumes `/oauth/authorize`       | Sign carries `login_challenge`; Acme issues code                                                  | Acme (correct)                                                 |
| 15  | Decides post-sign-up destination | Sign handoff → welcome                                                                            | **Acme** (`sign-in-sequence.md`: welcome/dashboard Acme-owned) |
| 16  | Deletes failed provisional       | `SignUpTermination` + `SignUpArtifactCleanup` (Sign)                                              | acceptable (ceremony state); actor cleanup follows owner       |
| 17  | Audits sign-up                   | Chronicle events from Sign flow                                                                   | Sign ceremony audit + Acme commit audit                        |
| 18  | Sends verification/invite email  | Sign (`SignOtpCeremony#deliver!`); `OrgInvitationService`                                         | unchanged                                                      |
| 19  | Rate-limit / bot protection      | Cloudflare Turnstile at entry + 30s OTP cooldown                                                  | unchanged                                                      |
| 20  | Idempotency/replay               | flow `public_id`, `checkpoint_version` optimistic lock, OTP `clear_otp`, invitation `consumed_at` | unchanged                                                      |

**Decomposition of the "both Acme and Sign" answer:** Sign **runs the credential ceremony and
produces signed evidence**; Acme **consumes the evidence and commits identity/session/account**. The
violation today is that Sign also commits (rows 1, 8, 12, 13, 15).

---

## 7. Acme ↔ Sign sign-up boundary

**Accepted contract** (`adr/identity-authority-boundary.md:79-99`,
`docs/security/social-callback-boundary.md`, `docs/security/ceremony-grant-result.md`): Acme issues
a signed, audience-bound, purpose-bound, one-shot, short-lived **grant**; Sign executes and returns
a signed **result**; Acme commits. Sign must not issue sessions/tokens or make account-link
decisions.

**Current state:**

- **Social:** the contract is _partially live_ — `IdentitySocialCeremonyFinalCommitter` + Acme
  `#completion` + `IdentityGraphProvisioner` implement the Acme-commit half, but the Sign
  `omniauth_callbacks#omniauth` path (and `SocialAuthSignupFinalizer` invoked outside the committer)
  can still create durable rows. **Dual path → collapse to the committer.** This exact gap is named
  in `plans/identity-authority-inversion-implementation.md` ("Sign app social callback/sign-up code
  … must not create durable Client/provider identity/ClientAccount records before … the approved
  finalization point").
- **Email/telephone/org:** no grant/result split yet — Sign finalizes and Sign issues the session.

The `/social/:provider/callback` route is classified **transitional**: the URL stays (provider
redirect binding), but its controller must shrink to "validate provider + return ceremony evidence,"
delegating the commit to Acme.

---

## 8. Identity creation vs credential enrollment vs product provisioning

These are already separate operations in code and must stay separate after inversion:

- **Identity creation:** insert `Client`/`Visitor`/`Operator` (authority row).
- **Credential enrollment:** insert `ClientPasskey`/`ClientSecret`/provider identity (ceremony
  output).
- **Product provisioning:** `rp_account` + `*_preference` (`IdentityGraphProvisioner.call!`).
- **Session issuance:** `ClientToken` + cookies (currently Sign; target Acme).

After inversion: Sign emits a ceremony result describing _which credential was proven_; Acme creates
the authority row, links the credential, provisions the product graph, and issues the session — all
on the Acme commit side, in Acme-owned transactions.

---

## 9. Duplicate identity / account-linking findings

- **Email/telephone:** uniqueness is enforced at the DB via a **partial unique index on the HMAC
  blind index** (`address_digest`, `WHERE status <> DELETED`) — not controller-only. Normalization
  via `JitUtilsEmailValidator.normalize` before digest. Good.
- **Existing-account on OTP:** the email OTP `update` branch redirects an existing verified account
  back to sign-in instead of creating a duplicate. Good (privacy-preserving continuation).
- **Social:** linkage is strictly by `(provider, uid)`. **No email-based auto-link** — there is no
  secondary "find user by email" merge. `SocialAuthSignupFinalizer` raises `identity_conflict` if
  the uid is already bound. This satisfies "do not auto-link by untrusted email."
- **Residual risk to track (not a code change in this audit):** an orphaned provider identity routes
  to sign-up; the inversion must ensure the **Acme** commit re-checks `(provider, uid)` under lock
  at commit time (not only at Sign callback time) to avoid a race creating two authority rows. Use
  the existing `…lock.find_by` pattern on the Acme side.
- **Concurrency:** flow `checkpoint_version` optimistic lock + `with_lock`/`with_cycle_lock` guard
  requirement clearing and cleanup. DB unique indexes are the backstop under race.

No path was found that silently merges accounts by email.

---

## 10. Verification and activation policy

- **app/com email:** email OTP (`SignOtpCeremony`, HOTP, 12-min TTL, `clear_otp` one-time, 30s
  resend cooldown, attempt lockout) is required before finalization; status →
  `VERIFIED_WITH_SIGN_UP`.
- **app/com telephone:** telephone OTP proves ownership only; **passkey + passcode** also required
  before finalization.
- **org:** invitation acceptance auto-marks the operator email `VERIFIED` (no OTP) — acceptable for
  a pre-issued invitation, but see §11/§12 caveats.
- **Provisional vs active:** sign-up creates **pending** actor/contact rows first; they become
  active only at finalization. Abandoned provisionals are logically discarded immediately and
  physically purged after `SignUpTermination::PHYSICAL_PURGE_DELAY = 30.minutes`; cleanup touches
  **only ticket-owned pending artifacts** (`SignUpArtifactCleanup`), never active
  actors/credentials.

---

## 11. Terms / consent findings

- `confirm_policy` is a **transient** acceptance checkbox (`attr_accessor`, validated
  `acceptance: true` on create) — **not persisted as a versioned record**.
- `*_preference` has `consent_version` (single UUID), `consented` (boolean), `consented_at` — there
  is **no terms-version history table** and no server-authoritative mapping of accepted version →
  document hash.
- Birthdate **is** server-validated (`YYYY-MM-DD`, future rejected) and **encrypted** at rest
  (`has_birthdate` `encrypts :birthdate`).
- **Finding:** consent is captured but not auditable to a specific terms version. If versioned
  consent is a requirement, it is currently a gap. Do not invent the requirement; record it as an
  open decision (§25).

---

## 12. Anti-abuse / enumeration findings

- **Turnstile** is enforced at external entry points (email/telephone `create`, social entry, org
  invitation `create`) and intentionally **not** re-required on checkpoint subroutes
  (`adr/sign-up-checkpoint-turnstile-boundary.md`; `docs/security/turnstile.md`).
- **OTP brute-force:** attempt counter + lockout in `SignOtpCeremony#verify!`; 30s send cooldown.
- **Enumeration:** existing-email OTP path returns a sign-in continuation rather than "already
  exists" — good. Social does not confirm account existence.
- **Gaps to track:** no explicit per-IP/per-identifier `rate_limit` on sign-up `create` actions
  beyond Turnstile + OTP cooldown (OIDC token endpoints do use `rate_limit`); **invitation token is
  plaintext** and acceptance has no rate limit, so a 32-char random space is the only brute-force
  barrier. The `flash.now[:alert]` in the invitations controller is both a rule violation and a UI
  inconsistency.

---

## 13. Transaction / state inventory

| State object                         | Owner          | Store                                      | TTL/one-time                                        | Links                                         |
| ------------------------------------ | -------------- | ------------------------------------------ | --------------------------------------------------- | --------------------------------------------- |
| `ClientSignUpFlow`                   | Sign/app       | app_ticket DB                              | `expires_at`; terminal states; `checkpoint_version` | `principal_id`→Client, `token_id`→ClientToken |
| `VisitorSignUpFlow`                  | Sign/com       | com_ticket DB                              | same; social forbidden                              | `principal_id`→Visitor                        |
| `ClientOidcAuthorizationTransaction` | Acme authorize | identity DB                                | bound to `login_challenge`                          | resumes `/oauth/authorize`                    |
| OTP record (`SignOtpCeremony`)       | Sign           | contact row                                | 12 min, `clear_otp` one-time                        | bound to email/telephone                      |
| Social auth session                  | Sign           | server-side session                        | per round-trip; cleared on failure                  | provider/state/nonce/`rt`                     |
| `OrganizationInvitation`             | org            | identity DB                                | 7 days, `consumed_at` one-time                      | org + `invited_by`                            |
| Social ceremony result token         | Acme           | signed token                               | one-shot, audience-bound                            | `IdentitySocialCeremonyFinalCommitter`        |
| OIDC RP session keys                 | RP             | session (preserved across `reset_session`) | per flow                                            | code_verifier/state/nonce/pt                  |

These are kept distinct (no single generic `state` blob). `completed_requirements` JSON stores only
compact `{cleared, cleared_at}` booleans — **no secrets/OTP/challenge bytes** — matching the plan's
prohibition. Cross-host Acme↔Sign state is carried by signed tokens / `login_challenge`, **not** a
shared Rails cookie.

---

## 14. Session-establishment and OAuth-continuation findings

- **Today:** Sign establishes the session. `AuthenticationBase#log_in` (`:344-416`) does
  `reset_session` (fixation protection), restores OIDC RP keys, clears prior login cookies, creates
  the token record, ensures a device session, rotates the refresh token, sets login cookies, sets
  `current_attributes`, and writes `LOGGED_IN`. `handoff_to_sign_in_flow!`
  (`sign_up_sequence_controller_support.rb`) calls
  `establish_signed_in_session!(bootstrap_actor:true)`.
- **Target:** Acme is the **sole Session Authority** (`adr/identity-authority-boundary.md:33`);
  session issuance must move behind the Acme commit. `AcmeSwitcherAuthority` already reads
  Acme-selected context (`selected_account_public_id`, etc.) post-login — the selector/session
  ownership is meant to be Acme's.
- **Fixation:** `reset_session` is present and correct; the keys that must survive it
  (`oidc_code_verifier/state/nonce/pt`) are explicitly preserved/restored. Surface isolation is by
  host (`id.umaxica.{app,com,org}`) and per-surface DB; flows do not share tickets/sessions.

---

## 15. Already-existing / stale / retry decision table

| Situation                             | Current behavior                                                                           | Correct under contract                            |
| ------------------------------------- | ------------------------------------------------------------------------------------------ | ------------------------------------------------- |
| Visit sign-up while signed in         | rejected with status + plain text (no redirect, no sign-out)                               | keep                                              |
| Identifier already exists (email OTP) | continue to sign-in, no duplicate, no existence disclosure                                 | keep                                              |
| Stale/expired flow ticket             | sequence-only actions rejected (status + plain text), no mutation                          | keep                                              |
| Retry after creation, before redirect | idempotent: `public_id` + terminal states + DB unique indexes prevent dup actor/credential | keep                                              |
| Suspended/deactivated actor           | not replaced; existing recovery policy applies                                             | keep                                              |
| Duplicate social callback             | `(provider, uid)` lock + `identity_conflict`                                               | keep; re-check on **Acme** commit after inversion |

---

## 16. `/sign/up/complete` decision

**Do not add `/sign/up/complete`.** There is no Sign-owned terminal sign-up state: finalization
hands directly to the sign-in boundary, and the post-auth terminal surface is **`/welcome` →
dashboard/`rt`, owned by Acme** (`docs/security/sign-in-sequence.md`). Adding a Sign completion page
would re-create a Sign-owned post-auth surface, which the authority ADRs forbid. "Sign-out has
`/complete`" is not a valid reason. Email-verification-pending and checkpoint-pending are already
modeled as flow steps (`CONTACT_PENDING`, `CHECKPOINT_PENDING`), not as a terminal completion route.

---

## 17. Database consistency and concurrency risks

- Identity creation spans **multiple databases** (principal DB for actor/credentials; ticket DB for
  flow). The plan correctly forbids cross-DB FKs and validates ownership in code. **A single
  cross-DB transaction is impossible**; do not propose one.
- After inversion, the **Acme commit** must own the principal-DB transaction (actor + credential
  link
  - `rp_account`), while ceremony/flow state stays in the ticket DB. Use the existing
    per-cycle/`with_lock` patterns and DB unique indexes as the atomic backstop.
- Email delivery, provider calls, and audit are side effects outside the transaction — already
  modeled via `SignUpArtifactCleanup` (batch, `FOR UPDATE SKIP LOCKED`, `MAX_CLEANUP_ATTEMPTS=10`)
  and Chronicle. Keep them out of the commit transaction.

---

## 18. Docs / ADR contradictions

| Document                                                         | Claim                                                                         | Code/ADR evidence                                                                                           | Resolution                                                                                     |
| ---------------------------------------------------------------- | ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `adr/sign-up-authentication-handoff-and-social-rt.md:60`         | social callbacks at `/social/google/callback`, `POST /social/apple/callback`  | actual routes `/social/:provider/callback`; no `/auth/*`; `google_app` legacy (`authority-boundary.md:36`)  | **updated** ADR route references to `/social/*`; mark `google_app` historical                  |
| `docs/security/sign-up-sequence.md`                              | Sign promotes Client, creates `rp_account`, "sign-in boundary" issues session | `identity-authority-boundary.md`: Acme is Session/Account Authority; `sign-in-sequence.md` already inverted | **supersede/update** to ceremony grant/result + Acme commit; mark current text "migration gap" |
| `plans/.../sign-up-state-machine-implementation-plan.md:558-564` | social callbacks `/social/google/callback`, `/social/apple/callback`          | same as above                                                                                               | **updated** to `/social/*`                                                                     |
| `docs/identity/authority-boundary.md` vs implementation          | Acme owns sign-up finalization                                                | Sign finalizes + issues session today                                                                       | already self-labeled migration gap (`:26-29`); track in inversion slices                       |
| `adr/sign-up-authentication-handoff-and-social-rt.md` header     | superseded by `identity-authority-boundary.md` for authority model            | route inventory still cited downstream                                                                      | **retain** as historical; do not use its authority model                                       |

No contradiction silently preserved: the route names are correct in code; only the **docs/ADRs**
carry stale `/auth/*` strings, and only the **finalization owner** lags the accepted authority
model.

---

## 19. Proposed final route matrix

**Keep the current routes. Freeze the namespace. Change owners, not paths.**

| Verb             | Path                                                                                | Owner                                 | Purpose                                                        | Mutation        | Auth mode            | Consumes                          | Final redirect      |
| ---------------- | ----------------------------------------------------------------------------------- | ------------------------------------- | -------------------------------------------------------------- | --------------- | -------------------- | --------------------------------- | ------------------- |
| GET              | `/sign/up`                                                                          | Sign app/com                          | entry hub                                                      | read            | guest                | flow (resume) / `login_challenge` | render              |
| GET/POST         | `/sign/up/email`(+`/new`)                                                           | Sign app/com                          | submit email                                                   | mutate          | guest                | Turnstile, flow                   | `…/email/edit`      |
| GET/PATCH        | `/sign/up/email/edit`, `/sign/up/email`                                             | Sign app/com                          | email OTP                                                      | mutate          | guest                | OTP, flow                         | guard/check         |
| GET/POST/PATCH   | `/sign/up/telephone*`                                                               | Sign app/com                          | telephone + SMS OTP                                            | mutate          | guest                | Turnstile, OTP, flow              | check               |
| GET              | `/sign/up/guard/*`                                                                  | Sign app/com                          | plain-text stop                                                | read            | guest                | flow                              | none (advance/stop) |
| GET/PATCH/POST   | `/sign/up/check/**` (birthdate, passkey, passcode, otp, confirmation, cancellation) | Sign app/com                          | checkpoint setup                                               | mutate          | guest (ticket-bound) | flow, requirement                 | finalize→sign-in    |
| GET              | `/social/{google,apple}/sign/{in,up}`                                               | Sign app                              | social start (intent server-side)                              | read            | guest                | session intent                    | provider            |
| GET(/POST apple) | `/social/{google,apple}/callback`                                                   | Sign app (**ceremony evidence only**) | provider callback                                              | mutate→evidence | guest                | provider state                    | **Acme commit**     |
| POST/GET         | Acme social `#completion` (commit)                                                  | **Acme app**                          | consume ceremony result, link/create, provision, issue session | mutate          | guest→authenticated  | result token                      | welcome             |
| GET/POST         | `/sign/up/invitations`(+`/new`)                                                     | Sign org                              | invitation acceptance                                          | mutate          | guest                | Turnstile, invitation             | org sign-in         |
| GET              | `/sign/up` (org)                                                                    | Sign org                              | recruiting guidance (no actor)                                 | read            | guest                | —                                 | com/recruiting      |

- **No** `/sign/up/new` symmetry, **no** `/sign/up/complete`, **no** `/sign/up/edit` staged
  resource, **no** mutation on GET, **no** sign-up state in query string (carried by
  `public_id`/session/token).
- Core/Base: no sign-up routes (RP launchers only). Palm app: `/palm/app/oidc/authorization` →
  browser ceremony; no native sign-up route. **No Palm com/org.**

---

## 20. Legacy route removal / migration table

| Route/behavior                                                 | Classification | Action                                                               | Removal condition                          |
| -------------------------------------------------------------- | -------------- | -------------------------------------------------------------------- | ------------------------------------------ |
| `/social/:provider/callback` Sign commit logic                 | **replace**    | shrink to ceremony-evidence; commit moves to Acme `#completion`      | once Acme commit path is the only writer   |
| Sign `SocialAuthSignupFinalizer` durable writes                | **replace**    | invoke only via `IdentitySocialCeremonyFinalCommitter` (Acme commit) | when email/telephone also inverted         |
| Sign `AuthenticationBase#log_in` session issuance from sign-up | **replace**    | session issuance behind Acme commit                                  | when Acme owns session for sign-up handoff |
| `/social/google/callback` and `/social/apple/callback`         | **keep**       | accepted callback vocabulary; route exists                           | no route change                            |
| Org invitations `flash.now[:alert]`                            | **replace**    | inline page feedback (no flash) per AGENTS.md                        | immediate (rule violation)                 |
| Compatibility session progression keys                         | **remove**     | after each migrated controller has coverage (plan phase 12)          | per-controller coverage                    |

A compatibility route is justified here **only** for `/social/:provider/callback` (external provider
redirect-URI binding) and the WebAuthn-bound `id.*` host
(`sign-residual-idp-surface-retirement.md`). No other compatibility sign-up route is warranted;
tests alone do not justify keeping one.

---

## 21. Concern / service extraction recommendation

The needed abstractions already exist and should be the migration seam, not new code:

- `SignUp::StateMachine` / `SignUpResult` — flow progression (keep).
- `SignUpSequenceControllerSupport` — shared controller seam (keep; route its `finalize`/`handoff`
  through an **Acme commit service** instead of Sign `log_in`).
- `IdentitySocialCeremonyFinalCommitter` + `IdentityGraphProvisioner` — the Acme commit seam (extend
  from social to email/telephone).
- `SignUpTermination` / `SignUpArtifactCleanup` — compensation (keep).
- Add only: a generic **`SignUp::CeremonyResult`** (email/telephone analogue of the social result
  token) and an **Acme finalization service** that consumes it. Do not add org self-service code.

---

## 22. Implementation phases (future work — not executed here)

1. **Freeze routing**: add regression tests asserting no `/auth/*`, no Palm com/org, no com social,
   no public org sign-up, GET-mutation absence (see §24). No route changes.
2. **Fix violations**: replace `flash.now` in org invitations with inline feedback; correct stale
   `/social/google/callback` and `/social/apple/callback` doc/ADR/plan references as the frozen
   callback vocabulary.
3. **Reconcile docs**: rewrite `docs/security/sign-up-sequence.md` to the ceremony grant/result +
   Acme-commit model, matching the already-updated `sign-in-sequence.md`.
4. **Collapse the social dual path**: make Acme `#completion` the only durable writer; reduce the
   Sign callback to evidence; re-check `(provider, uid)` under lock on the Acme side.
5. **Invert email/telephone finalization**: introduce `SignUp::CeremonyResult` + Acme finalization
   service; move identity activation, `rp_account`, and **session issuance** to Acme commit; Sign
   `finalize` returns evidence only.
6. **Move session issuance off Sign**: route `establish_signed_in_session!` for sign-up handoff
   through the Acme Session Authority; keep `reset_session` fixation + OIDC-key preservation.
7. **Harden org invitation** (separate decision): hash the token at rest, add acceptance rate limit,
   decide AAL2-at-acceptance.
8. **Remove compatibility session keys** once each migrated controller has coverage.
9. **Versioned consent** (if accepted): persist accepted terms version + document hash on Acme
   commit.

Each phase is independently shippable and maps to the active inversion slices.

---

## 23. Exact files likely to change (future implementation)

- Sign sign-up controllers: `app/controllers/sign/{app,com}/sign/up/**` (email, telephone, check/_,
  guard/_), `app/controllers/sign/{app,com}/sign/ups_controller.rb`.
- Social: `app/controllers/sign/app/social/authentications_controller.rb`,
  `app/controllers/sign/app/auth/omniauth_callbacks_controller.rb`,
  `app/services/social_auth_login_handler.rb`, `app/services/social_auth_signup_finalizer.rb`.
- Acme commit: `app/controllers/acme/app/social/authentications_controller.rb`,
  `app/services/identity_social_ceremony_final_committer.rb`,
  `app/services/identity_graph_provisioner.rb` (+ new email/telephone finalizer).
- Shared seam: `app/controllers/concerns/sign_up_sequence_controller_support.rb`,
  `app/controllers/concerns/authentication_base.rb` (session issuance ownership),
  `app/services/sign_up_state_machine.rb`.
- Org: `app/controllers/sign/org/sign/up/invitations_controller.rb` (flash fix, hardening),
  `app/services/org_operator_lifecycle_invitation_acceptance.rb`,
  `app/models/organization_invitation.rb`.
- Docs/ADR: `docs/security/sign-up-sequence.md`,
  `adr/sign-up-authentication-handoff-and-social-rt.md`,
  `plans/active/sign-up-state-machine-implementation-plan.md`.

---

## 24. Test plan (exact paths)

**Route contract** (`test/routing/` or request tests):

- assert `/sign/up`, `/sign/up/email`, `/sign/up/telephone`,
  `/social/:provider/{sign/in,sign/up,callback}` resolve per surface/host; assert **no** `/auth/*`
  route; assert Palm com/org and com social and public org sign-up are unreachable; assert no GET
  mutation on sign-up. Files: `test/controllers/sign/{app,com,org}/sign/up/**_test.rb`,
  `test/controllers/acme/{app,com,org}/accounts_controller_test.rb` (already present),
  `test/controllers/palm/app/**`.
- negative: authority endpoints absent on non-Acme products; social routes absent on com/org.

**Transaction/state:** `test/models/{client,visitor}_sign_up_flow_test.rb` — TTL, terminal states,
one-time, wrong surface, social-absence on com, `checkpoint_version` concurrency.

**Identity creation:** uniqueness via `address_digest` partial index, normalization, concurrent
duplicate, provisional→active, idempotent retry, rollback, default `rp_account`.

**Email verification:** `test/services/sign_otp_ceremony_test.rb` — valid/expired/consumed/lockout/
resend-cooldown/already-verified/enumeration-safe.

**Social:** existing vs new identity, `identity_conflict`, same email/different provider, unverified
provider email, no email auto-link, callback replay, app-only, **Acme `#completion` is the sole
durable writer**.

**Invitation:** `test/controllers/sign/org/sign/up/invitations_controller_test.rb`,
`test/services/org_operator_lifecycle_invitation_acceptance_test.rb` —
valid/expired/revoked/consumed/ wrong-recipient/existing-identity/membership-idempotency/**no
flash**/AAL2 decision.

**Session/OAuth continuation:** sign-up with `login_challenge` resumes the exact transaction;
**Acme** (not Sign) issues the session after inversion; code issued once; RP callback completes;
`reset_session` preserves OIDC keys; app/com/org isolation.

**Regression:** sign-in and sign-out contracts unchanged; `/social/*` intact; no `/auth/*`; Acme
self-RP boundary (`base-rails-rp`) intact; Palm app-only.

---

## 25. Risks and unresolved decisions

1. **Inversion ordering** — invert social-commit-only first (lowest risk, partly done) vs all
   methods together. Risk: dual-write window where both Sign and Acme can create rows.
2. **Session-authority move** — relocating `log_in`/session issuance off Sign is the highest-risk
   change; must preserve `reset_session` fixation and OIDC-key continuity.
3. **Org invitation hardening** — plaintext token + no AAL2 at acceptance + immediate `ACTIVE`
   operator. Decision: hash token? require AAL2 at acceptance? rate-limit acceptance?
4. **Versioned consent** — adopt a terms-version + document-hash record, or leave the boolean?
   Server authority is currently weak.
5. **Sign-up `create` rate limiting** — rely on Turnstile + OTP cooldown, or add per-identifier
   `rate_limit` like the OIDC token endpoints?

---

## 26. Recommended default for each unresolved decision

1. **Invert social first**, then email/telephone; collapse the social dual path before touching
   email — smallest blast radius, matches the active first-slice plan.
2. **Move session issuance last**, behind a single Acme finalization service, keeping the existing
   `reset_session` + `OIDC_RP_SESSION_KEYS` preservation verbatim.
3. **Harden the invitation**: hash the token at rest, add an acceptance rate limit; keep AAL2 on
   _lifecycle requests_ (issuance) rather than acceptance, since the invite is pre-approved — but
   record the email-binding gap.
4. **Adopt versioned consent** (terms version + document hash recorded on the Acme commit) — cheap
   and audit-relevant; capture on Sign, persist on Acme.
5. **Add a per-identifier `rate_limit`** on sign-up `create` actions to complement Turnstile,
   mirroring the OIDC token-endpoint pattern.

---

## 27. Final statement

- **Is the current sign-up architecture acceptable?** The **routing/namespace** architecture is
  acceptable and should be frozen. The **authority** architecture is **not** acceptable: Sign
  creates the canonical identity and issues the central session, contradicting the accepted ADRs
  that make Acme the sole Session/Account Authority.
- **Is a hard migration required?** **Yes** — but it is the **authority inversion** (move identity
  creation, account linking, product provisioning, and session issuance to Acme behind the ceremony
  grant/result contract), already partially landed for social and tracked in active inversion
  slices. It is **not** a route migration; routes stay.
- **Does any public `/auth/*` route exist?** **No.** No runtime `/auth/*` HTTP route exists. The
  only `/auth/*` strings are stale references in
  `adr/sign-up-authentication-handoff-and-social-rt.md` and the state-machine plan, which must be
  corrected to `/social/*`.

## Verification (for the future implementation)

- `bin/rails routes | grep -E ' /auth(/| )'` → must stay empty.
- `bin/rails routes -g 'sign/up'` and `-g 'social'` → unchanged paths after inversion.
- `rg "flash" app/controllers/sign/org/sign/up/invitations_controller.rb` → must become empty.
- `rg "/auth/google_app/callback|/auth/apple/callback" adr docs plans` → should only surface
  historical/archive notes, not current contract docs or active plans.
- Narrow tests first: `bin/rails test test/controllers/sign/app/sign/up/...` then social, then the
  Acme commit tests; broaden to sign-in/sign-out regression once the inversion seam is wired.
