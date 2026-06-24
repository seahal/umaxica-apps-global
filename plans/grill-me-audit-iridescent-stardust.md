# Grill-Me Audit: Sign-in Passkey / Secret Credential Entry Routes

**Scope:** `https://id.umaxica.{app,com,org}/sign/in/passkey/new?ri=jp`  
**Scope:** `https://id.umaxica.{app,com,org}/sign/in/secret_credential/new?ri=jp`  
**Worktree state:** Inspected as-is including staged deletions and modifications.

---

## Context

This is a read-only audit of the Sign RP surface for the two primary credential-based sign-in entry
paths. The worktree has significant in-flight changes: five ceremony delegation concerns deleted,
three services deleted, and all surface controllers modified. Findings cover both the steady-state
design and the in-progress work as it stands.

---

## 1. Routing

### 1.1 Host Constraints

Routes are correctly partitioned:

| Helper prefix                         | Controller namespace                     | Host constraint  |
| ------------------------------------- | ---------------------------------------- | ---------------- |
| `sign_app_sign_in_passkey*`           | `Sign::App::Sign::In::Passkeys`          | `id.umaxica.app` |
| `sign_com_sign_in_passkey*`           | `Sign::Com::Sign::In::Passkeys`          | `id.umaxica.com` |
| `sign_org_sign_in_passkey*`           | `Sign::Org::Sign::In::Passkeys`          | `id.umaxica.org` |
| `sign_app_sign_in_secret_credential*` | `Sign::App::Sign::In::SecretCredentials` | `id.umaxica.app` |
| `sign_com_sign_in_secret_credential*` | `Sign::Com::Sign::In::SecretCredentials` | `id.umaxica.com` |
| `sign_org_sign_in_secret_credential*` | `Sign::Org::Sign::In::SecretCredentials` | `id.umaxica.org` |

Surface isolation is correctly maintained at the routing layer.

### 1.2 Passkey Sub-Routes

Each surface defines three passkey routes:

```
GET  /sign/in/passkey/new          → passkeys#new        (entry form)
POST /sign/in/passkey/options      → passkey/options#create    (WebAuthn challenge generation)
POST /sign/in/passkey/verification → passkey/verifications#create (WebAuthn assertion)
```

The `options` and `verification` endpoints are sub-resources, not actions on `passkeys_controller`.
Each is a separate controller. This is intentional and correctly implemented.

### 1.3 Secret Credential Routes

```
GET  /sign/in/secret_credential/new  → secret_credentials#new
POST /sign/in/secret_credential      → secret_credentials#create
```

Standard RESTful resource pattern. No issues.

### 1.4 ri= Parameter at Route Level

No route-level constraints filter or validate `ri=`. The parameter is accepted by all routes and
validated downstream in `PreferenceGlobal#set_region` via `RequestContextContract`. The whitelist is
`%w(jp us)` with a silent fallback to `"jp"` for any invalid value. This is the designed behavior.

**Finding R-1 (Low):** `set_region` silently replaces an invalid `ri=` with `"jp"` and issues a
redirect. This means that for `GET /sign/in/passkey/new?ri=INVALID`, the user is redirected to
`/sign/in/passkey/new?ri=jp` before the form renders. The fallback redirect is correct for GET
requests. For POST requests (options, verification, secret_credential create), the `set_region`
guard skips the redirect for non-GET/HEAD unless `params[:ri].present?`, so an invalid `ri=` on a
POST bypasses the redirect path. The downstream `params[:ri]` is then passed unvalidated into
`establish_signed_in_session!`. The session establishment presumably stores the raw value; whether
it is validated there before being written to the session is not confirmed by this audit.

---

## 2. Controllers and Concerns

### 2.1 Inheritance Chain

All sign-in controllers correctly inherit from their surface-local `ApplicationController`, which
inherits from `ActionController::Base`. `BareController` is not in the chain. The inheritance
contract from `controller-inheritance.mdc` is satisfied.

```
Sign::App::Sign::In::PasskeysController
  → Sign::App::ApplicationController
    → ActionController::Base

Sign::App::Sign::In::SecretCredentialsController
  → Sign::App::ApplicationController
    → ActionController::Base
```

Same pattern for com and org surfaces.

### 2.2 Deleted Ceremony Delegation Concerns

The following files are deleted in the current worktree:

- `app/controllers/concerns/sign_passkey_ceremony_delegation.rb` (D)
- `app/controllers/concerns/sign_secret_credential_ceremony_delegation.rb` (D)
- `app/controllers/concerns/sign_email_ceremony_delegation.rb` (D)
- `app/controllers/concerns/sign_telephone_ceremony_delegation.rb` (D)
- `app/controllers/concerns/sign_totp_ceremony_delegation.rb` (D)

The corresponding services are also deleted:

- `app/services/identity_passkey_ceremony_grant_issuer.rb` (D)
- `app/services/identity_secret_credential_ceremony_grant_issuer.rb` (D)
- `app/services/client_secret_credentials_issue_recovery.rb` (D)

**Finding C-1 (Critical — worktree risk):** A search for remaining references to these deleted
constants found no live references in `app/` (non-test) code, which is consistent with a clean
deletion. However, the fact that five ceremony delegation concerns and three services were all
deleted together in a single branch without a corresponding ADR, plan, or notes file creates a
documentation gap. If any call site was missed, the error will be a runtime `NameError`, not a
compile-time failure. Confirm with a full
`grep -rn 'SignPasskeyCeremonyDelegation\|SignSecretCredentialCeremonyDelegation\|IdentityPasskeyCeremonyGrantIssuer\|IdentitySecretCredentialCeremonyGrantIssuer\|ClientSecretCredentialsIssueRecovery' app/ --include='*.rb'`
at merge time.

### 2.3 Passkey Options Flow — params(:identifier) Behavior

**File:** `app/controllers/concerns/sign_passkey_options_flow.rb:51`

```ruby
def normalized_passkey_identifier
  params(:identifier).to_s.strip
end
```

`params()` is overridden in `AuthenticationBase` (`authentication_base.rb:117`):

```ruby
def params(*filters)
  raw_params = super()
  return raw_params if filters.empty?
  raw_params.expect(*filters)
end
```

Calling `params(:identifier)` therefore calls `raw_params.expect(:identifier)`, which raises
`ActionController::ParameterMissing` when the parameter is absent from the request. The outer
`rescue StandardError` in `options` catches this and renders `"errors.webauthn.options_failed"`.

**Finding C-2 (Low):** The intent is to return the identifier string or blank, check for blank, and
render `passkey_identifier_required_error_key` if absent. Because `params.expect()` raises on a
missing param, the blank check is unreachable for a completely absent `identifier` key. A client
that omits the identifier entirely receives `"errors.webauthn.options_failed"` (generic) instead of
`"errors.webauthn.identifier_required"` (specific). This is an error-classification defect, not a
security issue. `params[:identifier]` would match the intent.

### 2.4 Passkey Concerns Architecture

Controllers include a stack of fine-grained passkey concerns:

```
SignWebauthn
SignPasskeyAuthentication
SignPasskeyAuthenticationHelpers
SignPasskeyOptionsFlow
SignPasskeyVerificationFlow
SignPasskeySignInFlow
SignPasskeyLoginResultFlow
MinimumResponseBudget
SessionLimitGate
CloudflareTurnstile
```

Sub-controllers (`options`, `verifications`) compose these via `SignPasskeySignInEndpoint`. The
architecture is layered and each concern has a clear responsibility. No single concern is doing too
much.

**Finding C-3 (Low):** `MinimumResponseBudget` is activated only when `action_name == "options"`.
The verification endpoint does not apply a minimum response budget. Timing variation during
verification could leak information about challenge lookup latency, passkey lookup speed, or
signature verification outcome. Assess whether a minimum budget is also warranted on the
verification path.

### 2.5 Org Surface — MFA Handling Gap

App and Com controllers handle `:mfa_required` status in `handle_domain_specific_login_status`. Org
does not have an `:mfa_required` case for passkey sign-in.

**Finding C-4 (Medium):** If the Org surface ever enables MFA for operators, the passkey sign-in
path has no handler for `:mfa_required`. The fallback behavior (what happens with an unhandled
status) is not audited here, but could silently succeed or render an unexpected error. Confirm
whether operator MFA is intentionally excluded or just not yet implemented.

### 2.6 Secret Credential MFA Path — Missing Actor Guard

**File:** `app/controllers/sign/app/sign/in/secret_credentials_controller.rb`

In `handle_mfa_login`:

```ruby
user = mfa_user
verification = verify_secret_credential_for_sign_in(user: user, ...)
if verification.secret_credential        # ← no `user &&` guard
  handle_successful_mfa(user, verification.secret_credential)
```

The standard login path (`handle_standard_login`) does check `user &&`:

```ruby
if user && verification.secret_credential
  process_standard_login(user)
```

**Finding C-5 (Low):** In the MFA path, if `mfa_user` returns `nil` (the user was deleted between
the MFA session being set and the second-factor submission), and if
`verify_secret_credential_for_sign_in` somehow returns a non-nil credential for a nil user (which
would be a bug in that method), `handle_successful_mfa(nil, ...)` would be called and could crash or
behave unexpectedly. The standard path's `user &&` guard is the correct pattern. The MFA path should
be consistent.

### 2.7 Secret Credential — Identifier Validation Too Permissive

App and Com surfaces accept any string containing `@` or `+` as a valid identifier:

```ruby
# identifier_detection concern
def identifier_present_and_valid
  return if identifier.include?("@") || identifier.include?("+")
  errors.add(:identifier, :invalid)
end
```

**Finding C-6 (Low):** `test@`, `+`, and `@@` all pass this check. The intent is to distinguish
email from telephone by format hint, not to validate either format fully. However, a value like `@`
passing validation and then failing during normalization or blind-index lookup adds unnecessary
noise to error flows. A minimal regex anchoring the prefix/suffix would narrow the surface.

### 2.8 Cloudflare Turnstile Extraction Asymmetry

| Surface                 | Token extraction path                                                                 |
| ----------------------- | ------------------------------------------------------------------------------------- |
| App (secret_credential) | Private `turnstile_response_param` → `params.expect("cf-turnstile-response")`         |
| Com (secret_credential) | Inline `params("cf-turnstile-response").to_s` (in form, not in validation)            |
| Org (secret_credential) | `CloudflareTurnstile` concern → `request.request_parameters["cf-turnstile-response"]` |
| All passkey controllers | `CloudflareTurnstile` concern → `request.request_parameters["cf-turnstile-response"]` |

**Finding C-7 (Low):** Three different code paths extract the Turnstile token across surfaces and
credential types. All ultimately read the same request key, but the inconsistency creates
maintenance risk: if the key name changes, three paths need updating. The org and passkey path via
the concern is the most centralized. App and Com should delegate extraction to the concern rather
than duplicating it.

---

## 3. Models and Persistence

### 3.1 Actor / Passkey Model Mapping

| Surface | Actor Model | Passkey Model     | Identifier Lookup             |
| ------- | ----------- | ----------------- | ----------------------------- |
| App     | `Client`    | `ClientPasskey`   | Email / telephone blind index |
| Com     | `Visitor`   | `VisitorPasskey`  | Email / telephone blind index |
| Org     | `Operator`  | `OperatorPasskey` | Direct `public_id` lookup     |

Surfaces are correctly isolated at the model layer. No cross-surface model access was found.

### 3.2 Challenge Actor ID Keys

The challenge metadata uses different actor ID keys per surface:

| Surface | Key stored in challenge |
| ------- | ----------------------- |
| App     | `"user_id"`             |
| Com     | `"visitor_id"`          |
| Org     | `"staff_id"`            |

**Finding M-1 (Low):** The key name divergence is necessary because each surface's challenge
normalization looks for a surface-specific key. However, the normalization step
(`normalize_passkey_actor_id`) adds an implicit coupling: if the wrong challenge is ever correlated
with the wrong surface (e.g., due to a routing misconfiguration), the key lookup would produce nil
silently rather than a type error. A surface identifier stored in the challenge alongside the actor
ID would allow explicit rejection of cross-surface challenge replay attempts.

### 3.3 Secret Credential Verification Paths (Legacy vs. New-Axis)

Two verification paths coexist:

- **Legacy (`verify_for_secret_credential_sign_in!`)**: Direct `has_secure_password`
  `authenticate()`. No constant-time comparison at the status/kind check layer before the password
  verification.
- **New-axis (`SignSecretVerify.call`)**: `ActiveSupport::SecurityUtils.secure_compare` on
  `lookup_digest` before password verification. Auto-locks credential after `max_failures`.

**Finding M-2 (Medium):** The legacy path relies solely on BCrypt/Argon2 timing for security. While
those algorithms are inherently slow, the surrounding status/kind checks before `authenticate()` are
not constant-time. A consistent `lookup_digest` approach across both paths would close this gap. The
legacy path should be treated as deprecated and removed rather than maintained in parallel
indefinitely.

### 3.4 Operator Secret Credential — No Uses Remaining Column

`OperatorSecretCredential` has no `uses_remaining` column. The model's
`usable_for_secret_credential_sign_in?` simply checks status, kind, and expiration. This differs
from `ClientSecretCredential` and `VisitorSecretCredential` which have `uses_remaining` for one-time
credentials.

**Finding M-3 (Informational):** Operators cannot have one-time-use secret credentials. This is
presumably intentional (operators do not use recovery codes). Confirm this is documented as an
explicit design decision rather than an omission.

---

## 4. Views and Frontend Behavior

### 4.1 ri= Propagation in Views

| View                      | ri= in back link             | ri= in form/data attributes   |
| ------------------------- | ---------------------------- | ----------------------------- |
| App passkey new           | Yes (`params[:ri].presence`) | Yes (data-\* attributes)      |
| Com passkey new           | Yes (`params[:ri].presence`) | Yes (data-\* attributes)      |
| Org passkey new           | Yes (`params[:ri]`)          | **No**                        |
| App secret_credential new | **No**                       | N/A (form field, not data-\*) |
| Com secret_credential new | **No**                       | N/A                           |
| Org secret_credential new | Yes (`params[:ri]`)          | N/A                           |

**Finding V-1 (Medium):** Inconsistent. App and Com passkey views pass `ri=` in the WebAuthn
JavaScript data attributes (used for the POST to `/sign/in/passkey/options`). Org passkey view omits
`ri=` from data attributes, only including it in the back link. This means that when the JavaScript
posts the options request from `id.umaxica.org`, `ri=` is not forwarded, and the `options` endpoint
receives no `ri=`. The `ri=` value used during verification may then differ from what was present
when the user arrived at the form.

**Finding V-2 (Medium):** App and Com secret_credential `new` views do not preserve `ri=` in any
form field or back link. A user arriving at `/sign/in/secret_credential/new?ri=jp` loses the region
context the moment they interact with the page. The POST to `/sign/in/secret_credential` will carry
`params[:ri]` only if the JavaScript explicitly appends it, which the views do not do. Org correctly
includes `ri=` in the back link (but not as a hidden form field, so the POST also loses it).

### 4.2 No Hidden Field for ri= in Secret Credential Forms

None of the secret credential `new` views include `ri=` as a hidden form input. The controller reads
`params[:ri]` at POST time, but the form does not submit it.

**Finding V-3 (High):** For all three surfaces, the POST to `secret_credentials#create` will have no
`ri=` parameter unless the browser carries it in the query string (which standard form submission
does not do for POST). The controller calls
`establish_signed_in_session!(user, ri: params[:ri], ...)`, and `params[:ri]` will be nil. Session
establishment and MFA flow will have no region context. If ri is used to determine region-specific
redirect paths post-login, users will be sent to the wrong region or the default region ("jp")
regardless of their intended region.

---

## 5. Security

### 5.1 Timing Attack — Identifier Enumeration

For both passkey and secret credential flows, a non-existent identifier fails faster than a valid
one with a wrong credential (the latter goes through full BCrypt/Argon2 verification or WebAuthn
signature verification). `MinimumResponseBudget` is applied to the passkey `options` endpoint only.

**Finding S-1 (Medium):** The secret credential `create` action has no minimum response budget. An
attacker submitting credentials for non-existent vs. existent identifiers can detect existence via
response time. The Turnstile gate and rate limiting reduce the practical risk, but the timing oracle
remains. A minimum response time on the `create` action would close this.

### 5.2 CSRF Protection

All controllers inherit from `ActionController::Base` via `Sign::*::ApplicationController`. The
authenticity token check is active by default. No `skip_forgery_protection` or
`skip_before_action :verify_authenticity_token` was found in scope.

For the passkey `options` and `verification` sub-controllers, which are pure JSON endpoints, Rails
CSRF protection applies. The Turnstile check provides a second gate for the options endpoint. No
issues found.

### 5.3 Rate Limiting

All sign-in endpoints apply identical rate limits across surfaces:

- Burst: 5 requests/minute per IP
- Sustained: 20 requests/15 minutes per IP

Scope keys are surface-specific (`sign_app_sign_in`, `sign_com_sign_in`, `sign_org_sign_in`). No
cross-surface rate limit sharing.

**Finding S-2 (Low):** Rate limits are IP-scoped only. An attacker behind a CDN or NAT can exhaust
per-IP limits on behalf of legitimate users (DoS). An identifier-scoped rate limit in parallel would
mitigate this. This is a design-level tradeoff, not an oversight, but should be acknowledged.

### 5.4 Session Limit Gate

All surfaces call `session_limit_hard_reject_for?(actor)` before allowing sign-in to proceed. The
check is placed after identifier lookup but before credential verification, which means a locked-out
user does not go through credential verification at all.

**Finding S-3 (Informational):** The early session limit rejection leaks the fact that the
identifier exists and has sessions active (since a non-existent actor would fail at identifier
lookup, not at the session limit gate). The error messages for both cases should be identical from
the client's perspective. Confirm that `render_session_limit_hard_reject` and the
`identifier_not_found` error path use the same HTTP status and response structure.

### 5.5 WebAuthn Origin Validation

The passkey verification flow calls `validate_webauthn_origin!()` before processing the WebAuthn
assertion. A `SignWebauthn::OriginValidationError` renders a `403 Forbidden`. The trusted origins
list is validated at the concern level, not per-surface.

**Finding S-4 (Informational):** Confirm that `TRUSTED_ORIGINS` in `SignWebauthn` is
surface-specific (or at minimum does not accidentally allow a credential registered on `app` to be
asserted on `org`). A shared origin list would be a cross-surface authentication bypass risk.

### 5.6 Verified PII Requirement

All surfaces check `has_verified_pii?` on the actor before allowing passkey sign-in. A missing
verification renders a generic error to avoid disclosing PII verification status.

No issues found.

### 5.7 Sign Count Enforcement

The WebAuthn gem enforces sign count by default. `SignWebauthn::SignCountVerificationError` is
explicitly rescued and handled. This prevents cloned authenticator attacks.

No issues found.

### 5.8 Challenge Lifecycle

Challenges are stored with a purpose tag (`:authentication`) and TTL. The verification step uses an
atomic fetch-and-delete (`with_challenge`). Replaying the same challenge will return
`SignWebauthn::ChallengeNotFoundError` on the second attempt.

No issues found.

---

## 6. Performance

### 6.1 Blind Index Lookup (App/Com)

App and Com surfaces look up actors by `IdentifierBlindIndex.bidx_for_email()` or
`bidx_for_telephone()`. These involve HMAC computation on every options request. The computation is
fast but not free.

No issues found beyond normal operational cost.

### 6.2 Org — Direct public_id Lookup

Org normalizes and queries `Operator.find_by(public_id: ...)` directly. No blind index required. The
`public_id` column should have a unique index for this to be O(1). Not confirmed here but assumed
given the pattern.

### 6.3 No N+1 Observed

`active_passkeys_for_actor(actor)` fetches all active passkeys for the actor in a single query
before generating the WebAuthn options. No evidence of N+1 in the challenge or passkey lookup paths.

---

## 7. Logging and Observability

### 7.1 Error Logging Asymmetry (Secret Credential)

| Surface | Logs identifier_type | Logs identifier_present | Logs actor ID |
| ------- | -------------------- | ----------------------- | ------------- |
| App     | Yes                  | Yes                     | user_id       |
| Com     | Yes                  | Yes                     | visitor_id    |
| Org     | No                   | Yes                     | No field      |

**Finding L-1 (Low):** Org does not log `identifier_type` or the actor ID on failure. Incident
investigation on the Org surface will have less signal than on App or Com. The Org controller should
align its logging structure with the other surfaces.

### 7.2 No ri= in Authentication Events

The `JitLogEvent` authentication events (login_failed, login_succeeded) do not include the `ri=`
parameter. If region-specific issues are investigated, there is no log signal to correlate events by
region.

**Finding L-2 (Informational):** Consider including `ri` in authentication log events for
observability.

---

## 8. Tests and Coverage

### 8.1 Missing Test: Com Secret Credential Sign-In

`test/controllers/sign/com/in/secret_credentials_controller_test.rb` does not exist.

**Finding T-1 (High):** The `id.umaxica.com` secret credential sign-in path has no controller test.
The Com controller has differences from App (no MFA path, different actor model, inline Turnstile
extraction). None of these are covered. Success, failure, rate limit, Turnstile failure, and session
limit cases are all untested.

### 8.2 Test File for Org Secret Credential

`test/controllers/sign/org/in/secret_credentials_controller_test.rb` exists (251 lines) but was not
deeply audited. Verify that the new `public_id` identifier format, the session limit path, and the
`pt:` forwarding in `establish_signed_in_session!` are covered.

### 8.3 Test for Passkey — App in_passkey_authentication_flow

`test/controllers/sign/app/in/passkey/authentication_flow_test.rb` exists. This is the highest-
confidence test for the passkey happy path. Confirm it covers:

- Challenge ID mismatch (wrong challenge for actor)
- Expired challenge
- Sign count replay
- Session limit hard reject
- Verified PII missing

### 8.4 Deleted Services — Test Isolation

`client_secret_credentials_issue_recovery.rb` was deleted. The test helper
`issue_new_axis_secret_credential!` in
`test/controllers/sign/app/in/secret_credentials_controller_test.rb:461` uses `SignSecretIssue.call`
directly rather than the deleted service — so the test infrastructure is intact.

**Finding T-2 (Informational):** Confirm the deleted ceremony delegation concerns are not referenced
in any test fixtures, test helpers, or support files. A
`grep -rn 'SignPasskeyCeremonyDelegation\|SignSecretCredentialCeremonyDelegation' test/` should
return empty.

### 8.5 ri= Propagation Not Tested

No test was found that verifies `ri=jp` is correctly forwarded from the sign-in form through
WebAuthn options POST → verification POST → session establishment → MFA redirect. Given the view
inconsistencies found in section 4, this path is not tested end-to-end.

**Finding T-3 (Medium):** Add integration-level tests that assert `ri=` is present in the redirect
URL after successful sign-in, for both passkey and secret credential paths, on all three surfaces.

---

## 9. Flow Behavior

### 9.1 Normal Flow — Passkey

```
GET /sign/in/passkey/new?ri=jp
  → set_region validates ri=jp (whitelisted)
  → renders new.html.erb with ri=jp in data attributes (app/com only; org: back link only)

POST /sign/in/passkey/options
  → Turnstile stealth check
  → identifier normalized, looked up, actor fetched
  → WebAuthn challenge generated, stored with TTL
  → returns { challenge_id, options }

POST /sign/in/passkey/verification
  → challenge fetched atomically and deleted
  → actor ID extracted from challenge metadata
  → WebAuthn credential built and verified
  → sign count updated
  → establish_signed_in_session! called
  → redirect to MFA, session limit gate, or success
```

### 9.2 Normal Flow — Secret Credential

```
GET /sign/in/secret_credential/new?ri=jp
  → renders new.html.erb (ri= NOT preserved in form on app/com)

POST /sign/in/secret_credential (ri= is nil on app/com due to V-3)
  → Turnstile validation
  → form validated
  → actor looked up by identifier
  → session limit check
  → secret credential verified (new-axis: lookup_digest → password hash)
  → establish_signed_in_session! called with ri=nil (on app/com)
  → MFA required → set_pending_mfa! (stores ri=nil)
  → redirect to MFA with ri=nil → wrong region context
```

### 9.3 Abnormal Flow — Org Passkey ri= Drop

```
GET /sign/in/passkey/new?ri=jp  (id.umaxica.org)
  → renders new.html.erb
  → back link: /sign/in/emails?ri=jp ✓
  → data attributes for JS: NO ri= ✗

JS POST /sign/in/passkey/options (no ri= in request body)
JS POST /sign/in/passkey/verification (no ri=)
  → establish_signed_in_session! called with ri=nil
  → post-login redirect uses nil ri → defaults to "jp" in path helper
```

---

## Summary of Findings

| ID  | Severity                | Area        | Summary                                                                                                              |
| --- | ----------------------- | ----------- | -------------------------------------------------------------------------------------------------------------------- |
| V-3 | **High**                | Views       | Secret credential `new` views (all surfaces) omit `ri=` as a hidden form field; POST loses region context            |
| C-1 | **Critical (worktree)** | Concerns    | Five deleted ceremony delegation concerns with no ADR/plan; confirm no missed call sites at merge                    |
| T-1 | **High**                | Tests       | No test file for `Sign::Com::Sign::In::SecretCredentials` controller                                                 |
| C-4 | **Medium**              | Controllers | Org passkey sign-in has no `:mfa_required` handler; future MFA enablement would silently misroute                    |
| M-2 | **Medium**              | Models      | Legacy secret credential verification path lacks constant-time status/kind checks; no sunset plan                    |
| S-1 | **Medium**              | Security    | Secret credential `create` has no minimum response budget; timing oracle for identifier existence                    |
| V-1 | **Medium**              | Views       | Org passkey `new` view omits `ri=` from WebAuthn JS data attributes; region context dropped at POST time             |
| V-2 | **Medium**              | Views       | App/Com secret_credential `new` views omit `ri=` from back link                                                      |
| T-3 | **Medium**              | Tests       | No end-to-end test that `ri=` survives the full sign-in flow through session establishment                           |
| C-2 | Low                     | Controllers | `params(:identifier)` raises on missing param → generic error instead of specific identifier-required error          |
| C-3 | Low                     | Controllers | `MinimumResponseBudget` not applied to passkey verification endpoint; only on options                                |
| C-5 | Low                     | Controllers | App MFA path missing `user &&` guard before `handle_successful_mfa` (inconsistent with standard path)                |
| C-6 | Low                     | Controllers | Identifier validation accepts any string with `@` or `+`; `test@` and `+` pass                                       |
| C-7 | Low                     | Controllers | Turnstile token extracted via three different code paths across surfaces                                             |
| M-1 | Low                     | Models      | Challenge metadata stores actor ID but no surface identifier; cross-surface challenge replay not explicitly rejected |
| M-3 | Informational           | Models      | Org has no one-time-use secret credentials (no `uses_remaining`); confirm intentional                                |
| S-2 | Low                     | Security    | Rate limiting is IP-scoped only; no per-identifier limit                                                             |
| S-3 | Informational           | Security    | Session limit rejection leaks actor existence; confirm same response shape as identifier-not-found                   |
| S-4 | Informational           | Security    | Confirm `TRUSTED_ORIGINS` is surface-scoped to prevent cross-surface credential assertion                            |
| L-1 | Low                     | Logging     | Org secret credential failure events omit `identifier_type` and actor ID                                             |
| L-2 | Informational           | Logging     | `ri=` not included in authentication log events                                                                      |
| T-2 | Informational           | Tests       | Confirm deleted ceremony delegation concerns have no test references                                                 |

---

## Verification

This is a read-only audit. No changes were made. To confirm findings before acting:

```sh
# C-1: Confirm no remaining references to deleted concerns/services
grep -rn 'SignPasskeyCeremonyDelegation\|SignSecretCredentialCeremonyDelegation\|IdentityPasskeyCeremonyGrantIssuer\|IdentitySecretCredentialCeremonyGrantIssuer\|ClientSecretCredentialsIssueRecovery' app/ --include='*.rb'

# T-1: Confirm missing test file
ls test/controllers/sign/com/in/

# T-2: Confirm deleted concerns not in tests
grep -rn 'SignPasskeyCeremonyDelegation\|SignSecretCredentialCeremonyDelegation' test/ --include='*.rb'

# V-3: Confirm ri= absent in secret_credential form
grep -n 'ri' app/views/sign/app/sign/in/secret_credentials/new.html.erb
grep -n 'ri' app/views/sign/com/sign/in/secret_credentials/new.html.erb
grep -n 'ri' app/views/sign/org/sign/in/secret_credentials/new.html.erb

# C-2: Confirm params(:identifier) behavior
grep -n 'normalized_passkey_identifier\|params(:identifier' app/controllers/concerns/sign_passkey_options_flow.rb
grep -n 'def params' app/controllers/concerns/authentication_base.rb
```
