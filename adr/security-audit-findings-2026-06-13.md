# Security Audit Findings — 2026-06-13

> Audit date: 2026-06-13 Scope: Authentication, authorization, session management, OAuth/OIDC,
> multi-tenant boundaries Findings addressed in this ADR: FINDING-01, FINDING-02, FINDING-03,
> FINDING-04

---

## Summary

A targeted security audit of the authentication and authorization layer identified four findings
with High or Critical severity. This ADR records the fix decisions for each finding and the
rationale behind the chosen implementation paths.

---

## FINDING-01 [Critical] — Policy subclass silently removes org ownership check

### Problem

`OperatorLifecycleRequestPolicy` defined a method named `operator?` that returned
`user.is_a?(Operator)`. This shadowed `ApplicationPolicy#operator?`, which calls
`has_role?("operator", organization: organization)` — a check that requires org membership. Because
the policy only received a class (not a record instance) for `authorize!(OperatorLifecycleRequest)`,
the `organization` context was `nil`, and the base method would have raised `NoMethodError`
(Operator has no `has_role?`). The subclass override silently removed all org ownership enforcement.

As a result, any authenticated Operator could create a JOIN lifecycle request for any organization
by supplying a foreign `organization_id` in params.

### Decision

1. **Rename the shadowing method** in `OperatorLifecycleRequestPolicy` from `operator?` to
   `lifecycle_actor?` to eliminate the accidental override. The new name clearly expresses "is this
   user a participant in this lifecycle flow" rather than "is this user an org member."

2. **Add org ownership enforcement in the service layer** (`OrgOperatorLifecycleRequestCreate`) via
   an `org_owner_authorized?` guard that runs before any persistence. This is the correct layer for
   the JOIN action check because:
   - The policy receives a class (`OperatorLifecycleRequest`), not a record with an org attribute.
   - The service is where the `organization_id` attribute is first interpreted in its domain
     context.
   - The 4-eyes approval model (`approve?`, `execute?` → `different_operator?`) is intentional
     global design and is NOT an org-scoping gap; do not add org checks to those methods.

3. **Org check scope**: Only JOIN requests check org ownership. WITHDRAW, SUSPEND, and TERMINATE
   requests target the actor or a named operator and have no org-scoping requirement at the service
   layer (the target is resolved by other means).

### Test coverage added

`test/services/org/operator_lifecycle/request_create_test.rb`:

- `creates join request when actor owns the organization`
- `join request is rejected when actor does not own the organization`
- `join request is rejected when the organization does not exist`

---

## FINDING-02 [High] — Credential destroy does not revoke existing sessions

### Problem

When a client destroys a secret credential (password), the existing `ClientToken` records for that
user were not revoked. An attacker who had already stolen a session token retained access for up to
14 days (the refresh token TTL). The `session_version` increment path that
`AuthenticationLogoutAllSessions` contains is a no-op for `Client` because the column does not exist
on that model; the token-revocation path (marking each `ClientToken` as `REVOKED`) is what actually
terminates sessions.

### Decision

Call
`AuthenticationLogoutAllSessions.call(resource: current_client, reason: "credential_destroyed")` in
the `destroy` action of `SecretCredentialsController`, immediately after
`ClientSecretCredentialsDestroy.call` succeeds. Record an audit event for the forced sign-out.

This path:

- Revokes all `ClientToken` records for the user via `AuthenticationLogoutCurrentSession` per token.
- Does not call `reset_session` (which clears the flash); the redirect with flash notice runs
  normally after revocation.
- Does not call `logout_all_sessions_for!` (which wraps `reset_session` in `ensure`).

**Why call it from the controller, not the service?** `ClientSecretCredentialsDestroy` is a domain
service focused on credential state. Session revocation is an authentication lifecycle
responsibility. Coupling them inside the service would blur the domain boundary and duplicate logic
already owned by the authentication concern.

### Test coverage added

`test/integration/sign/app/credential_removal_constraints_test.rb`:

- `destroying a secret credential revokes all existing client tokens` (regression guard)

**Pre-existing test fix**: The same file had `assert_difference("ClientSecretCredential.count", -1)`
which was already failing because `ClientSecretCredentialsDestroy` soft-deletes via `discard_now!`
rather than hard-deleting. The count never decreases. The assertion was replaced with
`assert_predicate secret_credential.reload, :lapsed?` which correctly verifies the soft-delete
outcome.

---

## FINDING-03 [High] — Social auth account linking does not reject email_verified=false

### Problem

`SocialAuthVerifiedProviderAssertion` validated provider identity, UID presence, credential
freshness, and claim freshness — but did not check `email_verified`. If a provider returned
`email_verified: false`, the auth hash was accepted and the identity linkage proceeded.

The immediate risk is low because the primary identity key is `uid + provider` (not email), and
Google UIDs cannot be spoofed. The finding is rated High because future code paths that match
accounts by email (e.g., a new provider integration or a "link by email" fallback) would inherit an
account-takeover vulnerability if email_verified is never enforced at the assertion boundary.

### Decision

Add an `email_explicitly_unverified?` guard in `SocialAuthVerifiedProviderAssertion#call`. The rule
is:

- `email_verified: false` (boolean) → reject (raise `SocialAuth::ProviderError`)
- `email_verified: "false"` (string) → reject (case-insensitive comparison)
- `email_verified: nil` (claim absent) → allow; some providers omit the claim entirely, and the
  identity key is uid+provider, not email
- `email_verified: true` (boolean) → allow

The check is placed in `SocialAuthVerifiedProviderAssertion` rather than `SocialAuthLinkHandler`
because it belongs with the other provider-level assertion rules (provider match, UID presence,
credential freshness). Any code path that calls the assertion service gets the check for free.

### Test coverage added

`test/services/social_auth_verified_provider_assertion_test.rb` (new file, 8 tests):

- `valid auth hash with email_verified true passes assertion`
- `valid auth hash without email_verified claim passes assertion`
- `auth hash with email_verified false raises ProviderError`
- `auth hash with email_verified string false raises ProviderError`
- `mismatched provider raises ProviderError`
- `missing uid raises ProviderError`
- `expired credentials raise ProviderError`
- `stale iat claim raises ProviderError`

---

## FINDING-04 [High] — No mechanism to detect missing authorize! calls

### Problem

ActionPolicy 0.7.6 does not provide `after_action :verify_authorized` out of the box. Without a
mechanism to detect missing `authorize!` calls, a new controller action that forgets to call
`authorize!` will pass authentication (via `enforce_access_policy!`) but skip object-level
authorization. The gap is structural: no current tooling catches it at test time or CI time.

### Decision

**No new structural mechanism is added at this time.** The rationale:

1. The existing `test/unit/security/action_policy_usage_test.rb` already asserts that
   `enforce_access_policy!` is present as a `before_action` on all surface controllers. This
   prevents authentication bypass but does not cover authorization gaps.

2. Adding `after_action :verify_authorized` to all surface `ApplicationController` classes is the
   right long-term fix but requires auditing all existing actions for correctness before it can be
   enabled without breaking existing tests.

3. The `ClientSecretCredentialPolicy` already has explicit test coverage for both owner-allows and
   non-owner-denies cases (`test/policies/client_secret_credential_policy_test.rb`).

**Near-term recommendation**: Adopt a convention that policy tests covering "non-owner may not
manage" and "owner may manage" are required for any policy with controller-facing `authorize!`
calls. This is currently done informally; a future ADR should make it formal and enforceable.

**Long-term recommendation**: Enable `after_action :verify_authorized` per surface (Acme, Sign)
after an audit sweep confirms all actions either call `authorize!` or are intentionally bare
(`BareController` children). Track as a backlog item.

---

## Files Changed

| File                                                                 | Type | Change                                                                         |
| -------------------------------------------------------------------- | ---- | ------------------------------------------------------------------------------ |
| `app/policies/operator_lifecycle_request_policy.rb`                  | Fix  | Renamed `operator?` → `lifecycle_actor?`; updated all callers within the file  |
| `app/services/org_operator_lifecycle_request_create.rb`              | Fix  | Added `org_owner_authorized?` guard for JOIN action                            |
| `app/controllers/acme/app/settings/secret_credentials_controller.rb` | Fix  | Added `AuthenticationLogoutAllSessions.call` in `destroy` action               |
| `app/services/social_auth_verified_provider_assertion.rb`            | Fix  | Added `email_explicitly_unverified?` check                                     |
| `test/services/org/operator_lifecycle/request_create_test.rb`        | Test | Three new tests for FINDING-01                                                 |
| `test/integration/sign/app/credential_removal_constraints_test.rb`   | Test | New regression test for FINDING-02; fixed pre-existing `assert_difference` bug |
| `test/services/social_auth_verified_provider_assertion_test.rb`      | Test | New file, 8 tests for FINDING-03                                               |
