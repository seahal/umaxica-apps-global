# Logout State Machine Implementation Plan

> **Deprecated by Identity Authority inversion where this plan assigns logout, session, refresh, or
> token authority to `sign/id`:** `acme/www` now owns Session, Token, Account, Preference,
> Authorization, and downstream-token authority. `sign/id` is ceremony-only. Physical DB movement is
> out of scope. Implementation details in this plan must not be used to reintroduce sign-side
> authority.

Status: active planning

## Purpose

Implement logout and session revocation as explicit state-machine driven flows across `app`, `com`,
and `org`.

This plan owns sign-out/logout progression and token/session invalidation behavior. It does not own
sign-in sequence progression, sign-up finalization, or withdrawal cycle state, but it integrates
with all three.

## Source Material

- `adr/session-reset-on-privilege-transition.md`
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`
- `adr/cookie-domain-scope-by-surface.md`
- `docs/security/session-reset-policy.md`
- `docs/security/refresh-token-rotation.md`
- `docs/security/session-limit.md`
- `docs/security/sign-in-sequence.md`
- `plans/active/token-rotation-concurrency-hardening.md`
- `plans/backlog/restoration-a7-self-service-session-revoke.md`
- `plans/backlog/gh610-decouple-session-id-from-token.md`
- `plans/backlog/gh633-emergency-revoke-all-sessions.md`

## Non-Negotiable Boundaries

- Keep per-surface token models and cookie scopes separate.
- Rails `reset_session` remains limited to privilege-transition choke points.
- Raw tokens, cookies, authorization headers, and full request params must not be logged.
- OIDC logout must not accept arbitrary `post_logout_redirect_uri`; completion stays on the sign
  surface unless a signed RP logout request permits a known behavior.

## Scope

In scope:

- Ordinary current-session logout.
- OIDC/RP-initiated logout request handling.
- Self-service revoke current session.
- Self-service revoke other sessions.
- Restricted-session cancel and promotion interactions.
- Logout after session-limit management.
- Refresh-token invalidation on logout/revoke.
- Rails session reset at logout.
- Logout audit and telemetry.
- Shared result object for logout/revoke operations.

Out of scope:

- Emergency admin revoke-all implementation, except reserving integration points.
- Token rotation concurrency hardening internals beyond consuming its accepted behavior.
- Withdrawal cycle state, except session revocation during withdrawal.
- Sign-in sequence internals.

## State Carrier

Use token rows as durable session state. A separate short-lived logout cycle may be introduced only
when a multi-step OIDC/RP-initiated logout needs request verification or user-visible confirmation.

Durable state is stored in:

- `UserToken` for `app`;
- `VisitorToken` for `com`;
- `OperatorToken` for `org`.

The logout flow must distinguish:

- current session logout;
- selected session revoke;
- revoke other sessions;
- RP-initiated logout;
- restricted-session cancel;
- restricted-session promotion after revocation.

## Sequence States

Expected high-level states:

```text
REQUESTED
REQUEST_VERIFIED
TOKEN_REVOKE_PENDING
TOKEN_REVOKED
COOKIE_CLEAR_PENDING
RAILS_SESSION_RESET
COMPLETED
FAILED
REJECTED
```

Restricted-session management may use:

```text
RESTRICTED_MANAGEMENT_PENDING
ACTIVE_SESSION_REVOKED
RESTRICTED_PROMOTION_PENDING
RESTRICTED_PROMOTED
RESTRICTED_CANCELLED
```

## Logout Result Contract

All logout/revoke paths should return a common result shape:

```ruby
Logout::Result(
  status: :success | :invalid_request |
          :forbidden | :not_found | :token_revoke_failed,
  token:,
  revoked_tokens:,
  redirect_to:,
  response_status:,
  message:
)
```

Controllers map the result to HTTP behavior. Token services own token mutation.

Current-session logout now has the first slice of this contract in production code:

- `Authentication::Logoutable#logout_current_session!` returns `Logout::Result(status: :success)`.
- unauthenticated stale-tab `POST`/`DELETE /sign/out` is rejected by `authenticate!` and redirected
  to sign-in; it does not call the token revoke primitive, write a logout audit event, or render the
  signed-out page.

## Implementation Phases

1. Inventory current logout, session revoke, restricted-session cancel, OIDC logout, and refresh
   invalidation call sites.
2. Introduce a common logout/revoke result object without changing behavior.
3. Normalize current-session logout through one per-surface controller path and one shared concern
   or service boundary.
4. Normalize selected-session revoke and revoke-other behavior.
5. Wire `session_revoke_all` step-up scope where self-service revoke-all requires AAL2.
6. Implement RP/OIDC logout verification as a dedicated request-verified sequence.
7. Ensure `reset_session` placement follows `docs/security/session-reset-policy.md`.
8. Emit Chronicle and Rails event records for logout and revoke outcomes.
9. Remove obsolete direct token mutation from controllers after coverage is stable.

## Test Expectations

- Ordinary logout revokes the current token, clears auth cookies, and resets Rails session.
- Logout is rejected safely when the browser is already logged out.
- Revoke other sessions cannot revoke another actor's token.
- Restricted-session cancel revokes the restricted token and logs out.
- Restricted-session promotion happens only when active-session count permits it.
- OIDC/RP logout requires a valid signed logout request.
- Revoked refresh tokens cannot refresh.
- Refresh-token replay behavior remains unchanged.
- `app`, `com`, and `org` cookie scopes remain separate.

## Documentation Follow-Up

After implementation, update:

- `docs/security/session-reset-policy.md`
- `docs/security/refresh-token-rotation.md`
- `docs/security/session-limit.md`
- `docs/security/sign-in-sequence.md` if OIDC logout routing changes
