# Logout And Session Management

## Authority

Logout is session mutation. `acme/www` owns logout, session revoke, revoke-all, session listing,
restricted session handling, device/session display, token-family revocation, and compromise state.

`sign/id` must not mutate logout or session state. If `/sign/out` is retained, it is redirect-only
to the acme logout flow.

## Redirect-Only Sign Route

A retained sign-side sign-out route may:

- inspect request context needed to choose the acme logout entry;
- preserve a safe navigation target through signed redirect primitives;
- redirect the browser to acme.

It must not revoke tokens, clear acme sessions, list sessions, write logout audit as the authority,
or store logout state.

## Related

- `docs/security/session-token-authority.md`
- `docs/security/redirect-vs-ceremony-result.md`
