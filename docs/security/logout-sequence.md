# Logout Sequence

## Authority

Logout is acme/www session mutation.

`acme/www` owns current-session logout, all-session logout, session revoke, session-management UI,
refresh-token family mutation, device binding cleanup, step-up freshness cleanup, and logout audit.

`sign/id` must not revoke sessions, rotate or revoke refresh tokens, clear acme sessions, list
sessions, display session-management UI, or write authoritative logout state.

Logical authority moves now; physical storage may remain where it is. Existing sign-side tables,
models, services, controllers, or namespaces do not imply sign-side authority.

## Sign/ID Redirect-Only Boundary

If `/sign/out` is retained, it is redirect-only to the acme logout flow.

A retained sign-side route may:

- inspect request context needed to choose the acme logout entry;
- clear ceremony-local state that belongs only to the current sign credential ceremony;
- preserve safe navigation intent through signed redirect primitives;
- redirect the browser to acme logout.

It must not:

- revoke the current session;
- revoke other sessions;
- revoke or rotate refresh tokens;
- clear acme session cookies as the authority;
- update device/session rows;
- clear step-up freshness;
- render an authoritative signed-out result;
- write authoritative logout or session audit.

## Acme Current-Session Logout

Current-session logout signs out one browser session. It must not revoke every active session for
the actor unless the user selected an all-session action.

The acme current-session logout flow is responsible for:

1. resolving the current acme session;
2. validating the logout request and any signed navigation target;
3. revoking or expiring the current session record;
4. revoking, rotating, or retiring the current refresh token family state as required by policy;
5. clearing device binding state tied to the session, including DBSC/device binding material where
   applicable;
6. clearing session-bound step-up freshness;
7. clearing acme auth cookies and request-local actor state;
8. writing authoritative logout audit and security records;
9. returning the signed-out response or redirecting to a validated navigation target.

Physical sign-out cycle tables may continue to exist during migration. They are compatibility
storage only unless current docs and ADRs explicitly assign the state to acme.

## All-Session Logout And Session Management

All-session logout, selected-session revoke, restricted-session promotion, device/session listing,
and session-management UI are acme authority.

`sign/id` may not host session-management UI except as a redirect to acme. It may not promote a
restricted session, revoke another session, or decide whether a session may continue.

## Stale Sign Routes

A stale `/sign/out` form submission must not pretend logout ran on sign. The safe behavior is to
redirect to acme logout or acme sign-in handling, depending on whether an acme session is still
present.

If no acme session is present, sign may clear ceremony-local state and redirect. It must not create
a logout cycle or write authoritative logout audit.

## Related

- `docs/identity/authority-boundary.md`
- `docs/security/logout-session-management.md`
- `docs/security/session-token-authority.md`
- `docs/security/redirect-vs-ceremony-result.md`
