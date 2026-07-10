# Session And Token Authority

> **Supersession (2026-06-12):** Use `adr/acme-sign-core-base-port-boundary.md` and
> `docs/architecture/acme-sign-core-base-port.md` for the target component model. Acme is the only
> IdP / Authorization Server, Core owns the browser web session, Base does not share Core cookies or
> sessions, and Palm uses bearer access tokens only. Older `acme/www` session/token language is
> historical where it conflicts with that boundary.

## Current Authority

`acme/www` owns all user sessions, refresh token families, OAuth/OIDC token authority, access-token
issuance, downstream token issuance, session management, logout, revoke, compromise state, and
step-up freshness confirmation.

`sign/id` must not issue, refresh, rotate, revoke, list, or display user sessions. It must not issue
refresh tokens, access tokens, downstream tokens, or step-up freshness.

## Physical Storage

Logical authority moves now; physical DB movement is out of scope. Existing sign-side token tables,
models, services, or controller names do not imply sign-side authority. During migration they are
compatibility placement only unless a current ADR explicitly says otherwise.

## Downstream Trust

`core`, `line`, and future downstream services trust acme-issued downstream tokens only. They must
reject sign-issued session, access, and downstream tokens.

## Step-Up Freshness

`sign/id` may execute the credential ceremony for step-up. `acme/www` decides whether the signed
result satisfies the requested purpose and stores any resulting freshness on the acme session.

## Related

- `docs/security/logout-session-management.md`
- `docs/security/downstream-token-authority.md`
- `docs/security/step-up-ceremony-delegation.md`
