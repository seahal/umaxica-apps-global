# OIDC Session Model Note

This note captures the current preferred direction for OIDC, session handling, and access
validation.

## Direction

- use OpenID Connect for authentication
- use Authorization Code Flow with PKCE
- align implementation with OAuth 2.1 direction
- keep browser-visible state minimal
- prefer relying-party session cookies over browser-held auth tokens

## Role Split

### `sign.*`

`sign.*` is intended to act as the identity provider.

Responsibilities:

- primary authentication
- verification and step-up flows
- login/session-family state
- token issuance
- refresh-token validation
- authentication audit and anomaly handling
- management of login-critical verified identity attributes

Non-goals:

- product/domain authorization rules for every relying party
- broad business-domain profile ownership
- unrelated application state

### Relying-party surfaces

Surfaces such as `acme`, `core`, `docs`, `help`, and `news` are intended to be relying parties.

Responsibilities:

- redirect unauthenticated users to `sign.*`
- complete callback handling
- exchange authorization code for tokens over the back channel
- verify the returned identity result
- create and manage their own local session
- perform local authorization decisions for their own domain

## Session-First Model

The preferred model is session-first.

That means:

- the browser should primarily hold a relying-party session cookie
- the browser should not be the long-term holder of auth tokens
- access token / refresh token handling should remain server-side where reasonably possible

In practical terms:

1. the relying party detects that the user is not signed in
2. the relying party starts OIDC Authorization Code + PKCE
3. the user authenticates at `sign.*`
4. the relying party receives `code` and `state` at its callback
5. the relying party performs token exchange server-to-server
6. the relying party establishes its own session

## PKCE

The preferred PKCE method is `S256`.

The relying party:

- generates `code_verifier`
- derives `code_challenge`
- stores `code_verifier` in Rails session
- stores `state` in Rails session

The relying party should consume and clear those values after callback processing.

## Rails Session Use

Rails session is acceptable for temporary callback state such as:

- `oidc_code_verifier`
- `oidc_state`
- `oidc_return_to`

Those values should be deleted when they are no longer needed.

## Access Validation Model

### Token Access

Use token-only validation for low-risk access where brief post-sign-out validity is acceptable.

### Verified Access

Use state-backed checks for:

- side effects
- sensitive configuration changes
- actions that require a current non-revoked session lineage
- actions that may require `Verification` / `StepUp`

### Refresh Access

Refresh-token exchange must be state-backed and must not be purely token-only.

## Session Lifecycle Model

### Sign-out

Sign-out ends the current relying-party session and invalidates its related refresh/session state.

Short-lived access tokens may remain usable until expiry for token-only access unless a stronger
revocation model is required.

### Session Revoke

Session revoke invalidates a specific session lineage.

This is the appropriate model for session-management UI such as `/configuration/session` style
operations.

### Global Sign-out

Global sign-out should invalidate the wider login family rooted at the identity provider.

Immediate universal propagation is not required for the initial design. Eventual invalidation via
follow-up state checks is acceptable.

### Hard Revoke

Hard revoke is a stronger future capability for near-real-time invalidation of access tokens.

If required later, this likely implies a revoked `sid` / `jti` store backed by Redis or an
equivalent fast lookup system.

## Cookie Direction

### Authentication/session cookies

- prefer host-only semantics for auth/session cookies
- use `__Host-` cookies where applicable
- do not rely on cross-subdomain cookie sharing for auth session state

### Preference cookies

- may continue on a separate design path from auth/session cookies
- do not treat preference-cookie behavior as the model for auth-cookie behavior

## Authorization Boundary

This note is about authentication/session validity, not full product authorization.

- identity provider concerns: authentication, verification, session state, token issuance
- relying-party concerns: authorization for application/domain behavior

## Status

This note is a design-direction document, not a statement that every part of the repository already
implements the model exactly as described.
