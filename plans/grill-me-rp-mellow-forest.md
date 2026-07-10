# Grill Me: RP Session Liveness Assurance Review

> **Scope:** Project Umaxica - Acme as the only IdP / Authorization Server, Sign as a special RP,
> Core as the Next.js web RP/BFF, Base as the Rails foundation/control-plane surface, and Palm as
> the native bearer-token API Resource Server.  
> **Date:** 2026-06-18  
> **Type:** Critical architecture review for Sign session liveness assurance.

## Executive Summary

The target behavior is **GET-based session liveness assurance** for sensitive Sign pages:

- verify whether the Acme authority session is still live
- fail closed when the check cannot confirm liveness
- keep this separate from step-up / recent reauthentication

The preferred implementation is **OIDC `prompt=none` via Acme `/authorize`**. The earlier
proprietary RP-to-Acme session-check API proposal is rejected.

### Rejected directions

- No `GET /internal/v0/sessions/:id/check`
- No `IdpSessionLivenessChecker`
- No `AcmeIdpSessionCheckService`
- No proprietary RP-to-Acme session check protocol
- No `last_idp_confirmed_at` persistence in token tables
- No fail-open timeout grace
- No `idp_*` helper names in Sign

## Decision

### Preferred path: `prompt=none`

For a sensitive Sign page:

1. call `sign_require_live_session!`
2. if the local Sign RP session is missing, use the existing login flow
3. if the local Sign RP session exists and liveness must be verified, redirect to Acme `/authorize`
4. include at least:
   - `response_type=code`
   - `client_id`
   - `redirect_uri`
   - `scope=openid`
   - `state`
   - `nonce`
   - `prompt=none`
5. on success, return to the original URL
6. on failure, keep the result fail-closed

### Failure semantics

- `login_required`
  - fail closed
  - purge the local Sign RP session
  - redirect to login/start
- `temporarily_unavailable`, timeout, network error, or Acme 5xx
  - fail closed
  - do not render the sensitive page
  - do not automatically purge the local Sign RP session
  - show or redirect to a recoverable authentication-check failure state

This is session liveness assurance only. It does not replace step-up.

## Why The Internal API Is Rejected

The proprietary internal API was a poor fit for this boundary because it:

- bypasses the IdP authority model instead of using it
- creates a Sign-to-Acme private protocol that is harder to reason about and harder to migrate
- duplicates what `prompt=none` already standardizes in OIDC
- invites caching and freshness semantics that can be mistaken for authority

SameSite concerns should be treated as an implementation risk to verify with browser tests, not as
justification for a custom Acme session-check endpoint.

## Naming

Use Sign-scoped helper names.

Preferred names:

- `sign_require_live_session!`
- `sign_live_session?`
- `sign_start_silent_session_check!`
- `sign_handle_silent_session_check_callback!`
- `sign_clear_session_due_to_authority_logout!`

Do not use `fresh` for this feature. Reserve `fresh` for step-up or recent reauthentication.

## Persistence

Reject persistent session-assurance timestamps in token tables.

Do not add `last_idp_confirmed_at` to:

- `client_tokens`
- `operator_tokens`
- `visitor_tokens`

If throttling is needed, use only short-lived volatile cache such as `Rails.cache` or SolidCache
keyed by Sign session identifier and scope. The cache is a throttle, not authority.

## Route Contract

No Acme internal session-check route should be added.

If a dedicated Sign-local route contract is needed, keep it Sign-local, for example:

- `GET /auth/session_check`
- `GET /auth/session_check/callback`

If the existing Sign auth callback flow is sufficient, no new route is required.

## Scope Separation

This feature answers:

- Is the Acme authority session still live?

This feature does not answer:

- Did the user recently re-authenticate?
- Did the user complete step-up?
- Can the user change passkeys, password, or TOTP?

High-risk mutation pages should keep or add a separate `sign_require_fresh_authentication!` gate
later.

## Test Plan

Add coverage for:

- local Sign session missing -> normal login redirect
- local Sign session present + Acme `prompt=none` success -> sensitive page allowed
- Acme `login_required` -> Sign session purged and login required
- Acme timeout or 5xx -> sensitive page denied, Sign session preserved
- helper names are `sign_*` and no `idp_*` helper names are introduced
- no `last_idp_confirmed_at` migration exists
- no Acme proprietary session-check route exists

## Outcome

The design should be documented as:

- OIDC `prompt=none` is the preferred direction
- proprietary Acme session-check API is rejected
- persistent `last_idp_confirmed_at` is rejected
- fail-open is rejected
- Sign helper names use `sign_*`
- session liveness is separate from fresh authentication
