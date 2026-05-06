# Terms

This document defines the preferred terms for authentication, verification, session lifecycle, and
access handling in this repository.

## Session Lifecycle

### Sign-out

The normal logout operation performed from a single relying-party surface.

Effects:

- ends the current relying-party browser session
- invalidates the relying-party-side refresh/session state for that surface
- does not require immediate invalidation of already-issued short-lived access tokens

### Session Revoke

An administrative or user-initiated operation that invalidates a specific sign-in session or device
session.

Effects:

- revokes the targeted session row and related refresh capability
- prevents future state-backed access through that session lineage
- does not imply immediate hard invalidation of already-issued short-lived access tokens

### Global Sign-out

A sign-out operation intended to terminate the wider SSO login family rather than only a single
relying-party surface.

Effects:

- invalidates the identity-provider-side login family
- should cause relying-party sessions to become invalid on follow-up checks
- may be implemented as eventual invalidation rather than instant propagation

### Hard Revoke

Immediate revocation intended to stop access tokens as well as refresh/session state.

Effects:

- requires explicit revoked-token or revoked-session tracking
- typically implies a shared store such as Redis or an equivalent fast revocation store
- is stronger than ordinary sign-out or session revoke

## Access Validation

### Token Access

Access validated primarily from the signed access token itself.

Typical use:

- low-risk, read-oriented access
- requests where stateless verification is acceptable

Notes:

- may remain valid briefly after sign-out until the access token expires

### Verified Access

Access that requires state-backed validation in addition to token-level validation.

Typical use:

- side-effectful operations
- security-sensitive actions
- actions that may require current session validity checks
- actions that may require verification or step-up checks

### Refresh Access

Access to refresh-token exchange or any equivalent token re-issuance path.

Typical use:

- refresh token rotation
- re-issuance of short-lived access tokens

Notes:

- always requires state-backed validation

## Verification State

### StepUp Required

The current access attempt requires additional verification before it may proceed.

Typical examples:

- re-authentication for sensitive settings changes
- destructive or account-critical actions

### Verified

The user or staff member has satisfied the currently required verification level for the current
scope and time window.

### Verification Expired

The previous verification is no longer current for the required scope or TTL and must be re-done.

## Identity Roles

### Identity Boundary

The boundary that authenticates the subject, manages the core login state, and issues tokens.

### Zenith Boundary

The acme shared-entry surface that delegates identity work to the Identity boundary and then
establishes the shared shell state.

### Foundation Boundary

The boundary for `base.*` business and admin flows that depend on shared identity and own the main
business-side write stores.

### Distributor Boundary

The boundary for `post.*` delivery and API flows that depend on shared identity where required but
own the publication-side read and delivery contract.
