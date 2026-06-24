# Audit Report: Acme Actor Session Token Contract — OIDC Token Exchange

**Prepared:** 2026-06-24 **Scope:** ClientToken, OperatorToken, VisitorToken creation paths across
app/com/org surfaces **Status:** Investigation only. No code was modified. **Related memo:**
`memos/2026-06-24-codex-rp-clienttoken-multiplicity-investigation.md`

**Implementation step (when approved):** Write this report to
`memos/2026-06-24-oidc-token-exchange-actor-session-token-audit.md`

---

## 1. Verdict

**CONFIRMED: OIDC token exchange creates new Acme actor session tokens.**

`OidcTokenExchangeService#create_token_record!`
(`app/services/oidc_token_exchange_service.rb:222–261`) calls `ClientToken.create!`,
`OperatorToken.create!`, or `VisitorToken.create!` directly during every successful authorization
code exchange.

**Session-limit gate bypass: CONFIRMED.** `create_token_record!` does not acquire
`with_actor_session_lock`, does not call `SignInSessionLimitManager`, and does not go through
`AuthenticationBase#log_in`. The only enforcement present on the OIDC path is a model-level
validation on token creation, which fires without a row-level lock and without the structured
limit-resolution flow available to browser logins.

---

## 2. Executive Summary

Acme has two distinct paths that create actor session token rows:

1. **Browser interactive login** (`AuthenticationBase#log_in` → `issue_login_tokens_within_lock` →
   `create_login_token_record`): enforces session limits, acquires `with_actor_session_lock`,
   creates a single new row per successful login.

2. **OIDC token exchange** (`OidcTokenExchangeService#consume_and_issue_tokens!` →
   `create_token_record!`): creates a new ClientToken/OperatorToken/VisitorToken row with no
   session-limit check, no actor lock, and no awareness of existing active tokens for the same
   actor.

The intended contract — that `ClientToken`, `OperatorToken`, and `VisitorToken` are Acme-owned actor
session roots minted only at browser login — is violated by path 2.

Authorization codes (`ClientAuthorizationCode`, etc.) store the actor's primary key but **not the
actor's existing session token id**. The exchange service therefore cannot reuse or reference the
existing Acme actor session. Every successful authorization code exchange mints an independent token
row, which:

- Is counted as an active session for limit enforcement purposes
- Is not automatically revoked when the user's browser session is revoked
- Can accumulate indefinitely across RP callback retries and multiple RP integrations
- Can cause false session-limit exhaustion for users with multiple RP connections

---

## 3. Current Flows

### 3.1 Interactive login / signup actor token creation

```
Browser → Acme sign-in controller
  └─ AuthenticationBase#log_in  (authentication_base.rb:347)
      └─ issue_login_tokens_within_lock  (authentication_base.rb:453)
          └─ with_actor_session_lock(resource)  (authentication_base.rb:384)
              └─ SignInSessionLimitManager (checks limits, decides active/restricted/reject)
                  └─ create_login_token_record  (authentication_base.rb:1929)
                      └─ token_class.create!(token_attributes)
```

- Enforces per-surface session limits (Client: 2 active + 1 restricted, Operator/Visitor: 1+1)
- Acquires row-level DB lock on actor record before counting
- Rescues `ActiveRecord::RecordInvalid` → raises `ConcurrentSessionLimitExceededError`
- Creates exactly one new token row per successful login

### 3.2 OIDC authorization (authorization code issuance)

```
Browser → OIDC authorization endpoint → consent verified
  └─ OidcAuthorizationCodeIssuer.call  (app/services/oidc_authorization_code_issuer.rb)
      └─ code_model.issue!(owner_attribute => resource, **code_attributes)
          └─ ClientAuthorizationCode / OperatorAuthorizationCode / VisitorAuthorizationCode created
             Fields stored: user_id/staff_id/visitor_id, code, code_challenge, redirect_uri,
                            client_id, scope, nonce, acr, auth_method, discarded_at (10s TTL)
             NOT stored: actor session token id
```

### 3.3 OIDC token exchange

```
RP → POST /oauth/token (grant_type=authorization_code)
  └─ AcmeOauthTokenEndpoint controller  (app/controllers/concerns/acme_oauth_token_endpoint.rb:8)
      └─ OidcTokenExchangeService.call(...)  (app/services/oidc_token_exchange_service.rb:27)
          ├─ authenticated_client?
          ├─ find_code  → lock.find_by(code)  [one of three AuthorizationCode models]
          ├─ validate_code  (usable? = !expired? && !consumed?)
          ├─ validate_authorized_scopes
          ├─ verify_pkce  (SHA-256 of code_verifier vs code_challenge)
          ├─ validate_dpop_proof  [if DPoP header present]
          └─ consume_and_issue_tokens!(authorization_code, dpop_jkt)  (line 138)
              ├─ authorization_code.consume!       ← marks consumed_at
              ├─ OidcConnectionRecorder.call(...)  ← idempotent upsert
              ├─ create_token_record!(...)         ← NEW ACTOR SESSION TOKEN ROW (line 155)
              │   └─ ClientToken.create!  OR  OperatorToken.create!  OR  VisitorToken.create!
              ├─ token_record.rotate_refresh_token!
              ├─ AuthenticationTokenService.encode(...)  ← JWT access token
              ├─ OidcIdTokenIssuer.call(...)             ← JWT ID token
              └─ return {access_token, refresh_token, id_token}
```

**No `with_actor_session_lock` call. No `SignInSessionLimitManager` call. No `log_in` call.**

### 3.4 RP callback / session establishment

The RP receives access_token + refresh_token + id_token. The RP establishes its own session using
these credentials. The Acme-side actor session root is the OIDC-created token row, not the user's
browser session token.

### 3.5 Logout / revocation

```
Browser → Acme sign-out endpoint
  └─ AuthenticationLogoutCurrentSession
      └─ revoke!(browser ClientToken)
          └─ token_status_id = REVOKED, discarded_at = now
          (device session cascade if applicable)

OIDC-created ClientToken rows: NOT revoked. Remain ACTIVE.
RP access tokens: still valid until the OIDC-created token is independently revoked or expires.
```

---

## 4. Evidence Tables

### 4.1 Actor token creation

| Model         | Method                                      | File                           | Line | Caller                           | Flow                     | Session-limit gate? | Lock?                           | Creates new row? |
| ------------- | ------------------------------------------- | ------------------------------ | ---- | -------------------------------- | ------------------------ | ------------------- | ------------------------------- | ---------------- |
| ClientToken   | `create!` (via `create_login_token_record`) | authentication_base.rb         | 1947 | `issue_login_tokens_within_lock` | Interactive login/signup | Yes                 | Yes (`with_actor_session_lock`) | Yes              |
| OperatorToken | `create!` (via `create_login_token_record`) | authentication_base.rb         | 1947 | `issue_login_tokens_within_lock` | Interactive login/signup | Yes                 | Yes                             | Yes              |
| VisitorToken  | `create!` (via `create_login_token_record`) | authentication_base.rb         | 1947 | `issue_login_tokens_within_lock` | Interactive login/signup | Yes                 | Yes                             | Yes              |
| OperatorToken | `create!`                                   | oidc_token_exchange_service.rb | 234  | `create_token_record!`           | OIDC token endpoint      | **No**              | **No**                          | Yes              |
| VisitorToken  | `create!`                                   | oidc_token_exchange_service.rb | 243  | `create_token_record!`           | OIDC token endpoint      | **No**              | **No**                          | Yes              |
| ClientToken   | `create!`                                   | oidc_token_exchange_service.rb | 252  | `create_token_record!`           | OIDC token endpoint      | **No**              | **No**                          | Yes              |

### 4.2 Session-limit gate

| Path                                            | `with_actor_session_lock`?       | `SignInSessionLimitManager`? | `log_in`? | RecordInvalid handling?                      |
| ----------------------------------------------- | -------------------------------- | ---------------------------- | --------- | -------------------------------------------- |
| `AuthenticationBase#log_in`                     | Yes (authentication_base.rb:384) | Yes                          | —         | Raises `ConcurrentSessionLimitExceededError` |
| `OidcTokenExchangeService#create_token_record!` | **No**                           | **No**                       | **No**    | Unhandled → propagates as 500                |

### 4.3 Authorization code data

| Field                                  | ClientAuthorizationCode | OperatorAuthorizationCode | VisitorAuthorizationCode |
| -------------------------------------- | ----------------------- | ------------------------- | ------------------------ |
| actor primary key                      | `user_id` ✓             | `staff_id` ✓              | `visitor_id` ✓           |
| actor session token id                 | **absent**              | **absent**                | **absent**               |
| `code` (unique)                        | ✓                       | ✓                         | ✓                        |
| `code_challenge` (PKCE)                | ✓                       | ✓                         | ✓                        |
| `consumed_at` (single-use)             | ✓                       | ✓                         | ✓                        |
| `discarded_at` (10s TTL)               | ✓                       | ✓                         | ✓                        |
| `redirect_uri`                         | ✓                       | ✓                         | ✓                        |
| `client_id`                            | ✓                       | ✓                         | ✓                        |
| `scope`, `nonce`, `acr`, `auth_method` | ✓                       | ✓                         | ✓                        |

**The absence of an actor session token id means the exchange service has no way to reference or
reuse the existing Acme actor session. New token creation is structurally forced by the schema.**

### 4.4 Revocation behavior

| Action                                           | Revokes browser ClientToken? | Revokes OIDC-created ClientToken? | RP access still valid?            |
| ------------------------------------------------ | ---------------------------- | --------------------------------- | --------------------------------- |
| Browser logout (single session)                  | Yes                          | **No**                            | **Yes, until OIDC token expires** |
| Account-wide revoke (`AccountSessionRevocation`) | Yes                          | Yes (all tokens)                  | No                                |
| OIDC token itself expires (`discarded_at`)       | —                            | Yes                               | No                                |
| RP calls revocation endpoint (if wired)          | —                            | Depends on implementation         | No                                |

### 4.5 Test coverage

| Area                 | Test file                                                             | Coverage                                     | Gap                                                                                                    |
| -------------------- | --------------------------------------------------------------------- | -------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| OIDC token exchange  | `test/services/oidc/token_exchange_service_test.rb`                   | Code consumption, connection recording, DPoP | **No test asserts that zero actor session tokens are created; no test counts token rows before/after** |
| Session limits       | `test/services/sign_in/session_limit_manager_test.rb`                 | Browser login limits                         | OIDC path not covered                                                                                  |
| Social auth callback | `test/controllers/concerns/social_callback_guard_included_do_test.rb` | CSRF/state                                   | No session token creation assertion                                                                    |
| Account revocation   | `test/services/account_session_revocation_test.rb`                    | All-token purge                              | Does not test OIDC-created token isolation                                                             |
| Interactive login    | `test/controllers/sign/app/in/emails_controller_test.rb`              | Browser login                                | No cross-path comparison                                                                               |

---

## 5. Contract Violations

### Violation 1: OIDC token exchange mints new Acme actor session tokens

**Evidence:** `oidc_token_exchange_service.rb:155–161` calls `create_token_record!`, which calls
`ClientToken.create!` / `OperatorToken.create!` / `VisitorToken.create!` at lines 234, 243, 252. No
path through `AuthenticationBase#log_in` or `with_actor_session_lock`.

**Why it matters:** Contracts 3 and 4 state RP access must be derived from an existing Acme actor
session, and the OIDC token endpoint must not create new actor session tokens.

**Security impact:** OIDC-created tokens are independent session roots. Revoking the browser session
leaves them active. Global revocation requires an out-of-band mechanism (account-wide purge, not
single-session logout).

**Functional impact:** Session limit counts rise. With 2 browser sessions at limit and one OIDC
exchange, a third ACTIVE token row is created without lock, potentially hitting model-level
validation and crashing with a 500 instead of a graceful limit-resolution flow.

**Recommended fix direction:** `create_token_record!` should be replaced with logic that reuses the
existing actor session token (requires storing actor session token id in the authorization code).
Alternatively, the OIDC path should issue only RP-scoped artifacts (e.g. an OIDC access token
derived from the existing token's public_id) without creating a new row.

---

### Violation 2: Authorization codes carry no actor session token reference

**Evidence:** `client_authorization_codes` table has `user_id` but no
`client_token_id`/`actor_token_id`. Same for `operator_authorization_codes` (no `operator_token_id`)
and `visitor_authorization_codes` (no `visitor_token_id`).

**Why it matters:** Contract 5 states RP-specific state must be anchored to the existing Acme actor
session. Without a stored reference, token exchange cannot look up the original session.

**Security impact:** Creates structural dependency on always-new token creation; fix requires schema
change.

**Functional impact:** Even if `create_token_record!` were changed to reuse tokens, the code
contains no information to identify which token to reuse.

**Recommended fix direction:** Add `client_token_id` (nullable FK) to `client_authorization_codes`,
similarly for operator and visitor. Populate it at authorization code issuance time (when the
actor's session is already known from the Acme session cookie). Token exchange then reads the
existing token id from the code and associates RP artifacts with it rather than creating a new row.

---

### Violation 3: Session-limit gate bypass on OIDC token endpoint

**Evidence:** `create_token_record!` (oidc_token_exchange_service.rb:222) does not call
`with_actor_session_lock` (authentication_base.rb:384), does not call `SignInSessionLimitManager`,
and does not rescue `ConcurrentSessionLimitExceededError`.

**Why it matters:** Contract is that session limits are enforced uniformly. OIDC path bypasses the
limit logic entirely, allowing tokens to accumulate beyond the enforced limits until model
validation fires.

**Security impact:** Moderate. Does not allow authentication bypass; does allow session count
inflation. Excess token rows survive until expiry.

**Functional impact:** High. Users with active sessions at the limit who authenticate via OIDC
receive either silent token accumulation (if model validation allows it) or an unhandled 500 (if
model validation rejects it), with no graceful session-limit resolution flow.

**Recommended fix direction:** After introducing actor session token reuse on the OIDC path,
session-limit logic becomes moot for the exchange endpoint (no new row is created). If a new row is
ever intentionally created by the OIDC path, it must go through the same lock and limit machinery as
`create_login_token_record`.

---

### Violation 4: Browser logout does not revoke OIDC-derived access

**Evidence:** `AuthenticationLogoutCurrentSession` (authentication_logout_current_session.rb)
revokes the specific token row used by the browser session. OIDC-created token rows are separate
records with separate primary keys. No cascade connects them.

**Why it matters:** Contract 6 states that revoking an Acme actor session must make all derived RP
access unusable on the next validation.

**Security impact:** High. A user who logs out of the browser retains live RP access tokens backed
by the OIDC-created token rows until those tokens expire. If the OIDC refresh token is held by the
RP, the RP can continue to refresh access tokens indefinitely.

**Functional impact:** User-visible logout does not actually terminate RP sessions. Users expecting
a "log out everywhere" behavior from a single browser logout will not get it.

**Recommended fix direction:** If OIDC-created tokens are collapsed into the existing browser
session token (fix for violation 1), this automatically becomes non-issue — revoking the browser
token also revokes the shared RP anchor. If separate rows are retained for RP tracking, a cascade
must explicitly revoke all OIDC-associated token rows when the parent session is revoked.

---

### Violation 5: Authorization code single-use enforcement does not prevent token accumulation on retry

**Evidence:** `authorization_code.consume!` sets `consumed_at` and `validate_code` rejects already-
consumed codes. However, if the authorization code is consumed and `create_token_record!` succeeds
but the HTTP response is lost (network timeout), the token row exists but the client never received
the tokens. The client cannot retry (code is consumed). The orphaned token row counts against the
session limit and cannot be claimed.

**Why it matters:** Contracts 2 and 5. Retry non-idempotency means transient network failures
produce stranded token rows.

**Security impact:** Low (orphaned rows expire eventually). Contributes to session-limit exhaustion.

**Functional impact:** Medium. Users who experience network failure during OIDC token exchange end
up with a used-up authorization code, a stranded active token row, and no usable RP session. They
must re-authorize.

**Recommended fix direction:** Token creation should be transactionally coupled with code
consumption. If the session reuse design is adopted (fix for violation 1), no new row is created at
exchange time and this problem disappears. If rows are still created, consider wrapping consumption
and token creation in a single transaction so partial failure is detectable.

---

## 6. Security Impact

### Session-limit bypass

`create_token_record!` bypasses the session-limit gate. OIDC exchanges can create token rows beyond
the per-actor active session limit. However, model-level validation on `ClientToken.create!` may
catch this (fires without lock → race risk). Impact: moderate. The limit is not fully enforceable on
the OIDC path.

### False session-limit exhaustion

Each OIDC authorization code exchange adds one ACTIVE token row. If a user authorizes 3 RP
applications, that is 3 additional token rows beyond the browser session token. The `ClientToken`
active limit is 2. The 4th token creation (3rd RP) will likely hit model validation and crash the
OIDC endpoint with a 500 for that RP, locking the user out of OIDC until an existing token expires.
This is observable and is the likely root cause of the issue in the prior memo.

### Duplicate actor session roots

Every successful OIDC authorization code exchange is an independent session root. If an actor has N
OIDC clients, they have N+1 independent token rows (N OIDC + 1 browser). Revoking one has no effect
on the others.

### Broken global revocation

Browser logout revokes one row. OIDC rows remain. Account-wide revocation
(`AccountSessionRevocation`) revokes all rows but is not triggered by a normal browser logout. There
is a window — potentially lasting the OIDC token TTL — during which revoked users retain valid RP
access tokens.

### Retry non-idempotency

Described in Violation 5. Low security impact (consumed codes cannot be replayed), moderate
functional impact.

### Confused-deputy risk: Acme actor session token vs OIDC protocol token

`create_token_record!` creates what is nominally an "Acme actor session token" but labels it with
OIDC fields (`oidc_client_id`, `oidc_scope`, `oidc_sid`, `oidc_jti`). The model name (`ClientToken`)
implies a browser session root, but the OIDC path creates rows that are actually RP-specific
protocol artifacts. The dual use of the same model for two distinct semantic purposes creates
confusion: is an OIDC-created `ClientToken` a "session" that counts against the user's session
limit? (Yes, currently.) Should it? (Unclear by design.)

### Race conditions

`create_token_record!` is called inside `connection_class.connected_to(role: :writing)` but without
acquiring `with_actor_session_lock`. Concurrent OIDC exchanges for the same actor could race to
create token rows simultaneously. Both may pass model-level validation if they read the count before
either commits.

---

## 7. Functional Impact

### Signup/signin failure due to unexpected session count

The prior memo (`2026-06-24-codex-rp-clienttoken-multiplicity-investigation.md`) documents exactly
this: sign-up created a ClientToken via the browser path, then the RP callback created a second via
OIDC exchange. The session count hit the limit, producing a spurious session-limit error for a
brand-new user.

### Logout not invalidating RP access

A user who clicks "Sign out" in the browser application retains live RP access until OIDC tokens
expire. For long-lived refresh tokens (OIDC `OPERATOR_REFRESH_TOKEN_TTL`,
`CLIENT_REFRESH_TOKEN_TTL`), this window may be days.

### Inconsistent app/com/org behavior

All three actor types (Client/Operator/Visitor) are affected identically: `create_token_record!`
contains branches for all three (oidc_token_exchange_service.rb:231–260). No surface has divergent
behavior on this path. The vulnerability is symmetric across surfaces.

### Token row multiplication

Each RP authorization produces one new token row per exchange. A user authorizing 10 RP clients
would accumulate 10 OIDC token rows over time. These inflate the active session count and can
trigger limit enforcement unexpectedly.

### Difficult debugging

`ClientToken` rows created by interactive login and by OIDC exchange look similar in the database.
The OIDC-created rows can be identified by non-null `oidc_client_id`, but this is not surfaced in
session management UIs. Support investigation requires direct DB queries.

---

## 8. Recommended Fix Direction

_Do not implement yet. Design direction only._

### Preferred direction: actor session token reuse

1. **Schema change**: Add `client_token_id` (nullable FK, `bigint`) to `client_authorization_codes`.
   Add `operator_token_id` to `operator_authorization_codes`. Add `visitor_token_id` to
   `visitor_authorization_codes`.

2. **Authorization code issuance**: At authorization code issuance time
   (`OidcAuthorizationCodeIssuer.call`), the Acme session is already established (the actor is
   logged in). Read the current actor session token id from the Acme session cookie and store it in
   the authorization code.

3. **Token exchange**: In `OidcTokenExchangeService#consume_and_issue_tokens!`, after consuming the
   code, read `authorization_code.client_token_id` (or equivalent) and look up the existing
   `ClientToken`. Do not call `create_token_record!`. Associate the OIDC connection and OIDC
   attributes directly with the existing token row (or with a new RP-specific record keyed on the
   existing token).

4. **OIDC artifacts**: The JWT access token and ID token already embed `session_public_id` from the
   token record. If the existing token record's `public_id` is used, RP token validation
   automatically inherits the actor session's revocation state.

5. **RP connection recording**: `OidcConnectionRecorder` is already idempotent
   (find_or_initialize_by). No change needed.

6. **Revocation**: With session reuse, revoking the actor session token automatically invalidates
   all OIDC access tokens derived from it on next validation (they embed the token's `public_id`).

7. **Tests to add** (not implement now):
   - Assert that OIDC token exchange creates zero new `ClientToken` rows.
   - Assert that the access token's `session_public_id` matches the pre-existing browser session
     token.
   - Assert that browser logout causes OIDC access token validation to fail.
   - Assert that OIDC token exchange at session limit does not produce a 500.

### Alternative (simpler, lower risk): OIDC-specific token type

If schema changes to authorization codes are too risky, an alternative is to introduce a distinct
model (`ClientOidcToken` or similar) that is not counted against session limits and has a clear
cascade-revoke relationship to its parent `ClientToken`. This is higher structural cost but avoids
touching the authorization code schema. Mentioned as alternative only; evaluate against the
preferred direction before choosing.

---

## 9. Open Questions

| Question                                                                                                     | Evidence needed                                                                                                          |
| ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| Does access token validation check `ClientToken` status on every request, or is it JWT-only?                 | Read `AuthenticationTokenService.decode` / RP-side token introspection endpoint. Determines severity of revocation gap.  |
| What is the actual TTL for OIDC-created `ClientToken` rows (`CLIENT_REFRESH_TOKEN_TTL`)?                     | Read `app/services/security_token_lifetimes.rb`. Determines how long the revocation gap lasts.                           |
| Does `ClientToken` model-level validation count OIDC-created rows against the session limit?                 | Read `client_token.rb` validation logic (line ~41). Determines whether session-limit exhaustion is immediate or gradual. |
| Is there an OIDC backchannel logout endpoint? If so, does it revoke the right token rows?                    | Search for `backchannel_logout` in routes and controllers.                                                               |
| Are OIDC refresh tokens usable after the `ClientToken` row is revoked?                                       | Read `refresh_tokenable.rb` validation; check whether revocation status is checked on refresh.                           |
| Is the `OidcConnectionRecorder` re-activation of revoked connections (line: `revoked_at = nil`) intentional? | Re-activation on next exchange may resurrect revoked RP relationships silently. Needs design review.                     |
| Do org/com OIDC flows have a separate token endpoint controller or do they share `AcmeOauthTokenEndpoint`?   | Read routes.rb; check for surface-specific token endpoint inheritance.                                                   |

---

## Summary for Implementation

The single file that embodies the entire problem is:

**`app/services/oidc_token_exchange_service.rb`**, method `create_token_record!` (lines 222–261).

It creates actor session tokens where it should be consuming and decorating an existing one. The
structural blocker is that **authorization code models carry no actor session token id**. The schema
must be extended before the service can be fixed. The fix is a two-part migration + service change,
not a single-method edit.
