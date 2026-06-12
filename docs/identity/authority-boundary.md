# Identity Authority Boundary

> **Supersession (2026-06-12):** The target component model is now
> `docs/architecture/acme-sign-core-base-port.md` and `adr/acme-sign-core-base-port-boundary.md`.
> Acme is the only IdP / Authorization Server, Sign is a special RP, Core is the Next.js web RP/BFF,
> Base is the Rails foundation/control-plane subdomain, and Port is the native bearer-token API
> Resource Server. This document remains historical Rails migration context where it describes
> `acme/www` and `sign/id`.

## Current Boundary

`acme/www` is the Session, Token, Account, Preference, Authorization, and downstream-token
Authority.

`sign/id` is not the IdP. It is a Credential Gateway and Credential Ceremony Zone.

Logical authority moves now; physical DB movement is out of scope. Existing sign-side tables,
models, namespaces, and route names do not imply sign-side authority.

## Implementation Status

This document describes the accepted authority boundary. The implementation is still being inverted.
Some existing `sign/id` routes and controllers may remain reachable as compatibility routes until
the active implementation slices move or redirect them.

Compatibility routes must not be treated as new authority assignments. If implementation currently
mutates session, refresh, preference, dashboard, withdrawal, token, account, or step-up freshness
state from a sign-side route, that behavior is a migration gap tracked by the Identity Authority
inversion plans, not a competing source of truth.

The first implementation slice is limited to route/controller classification, acme authority entry
points, and sign-to-acme redirects or delegates for authority surfaces. It does not physically move
tables and does not implement the full ceremony grant/result protocol.

## Acme/WWW Authority

`acme/www` owns:

- user session creation, continuation, rotation, revocation, logout, and device/session listing;
- refresh token families, replay handling, compromise state, and token rotation;
- OAuth/OIDC token authority and downstream token issuance;
- account lifecycle, including sign-up finalization, recovery, withdrawal, and restoration;
- preference writes, settings, dashboards, and session-management UI;
- authorization decisions and step-up freshness confirmation.

`core`, `line`, and future downstream services trust acme-issued downstream tokens. They must not
trust sign-issued session, access, or downstream tokens.

## Sign/ID Gateway

`sign/id` may:

- host unauthenticated sign-in and sign-up entry points;
- execute credential ceremonies for passkey/WebAuthn, OTP, TOTP, social callbacks, sign-in, sign-up,
  credential enrollment, credential assertion, and step-up;
- keep credential inventory and short-lived ceremony state;
- consume or introspect an acme session only to decide whether a ceremony is needed;
- write ceremony audit records.

`sign/id` must not:

- issue sessions, refresh tokens, access tokens, downstream tokens, or step-up freshness;
- own preference writes, settings, dashboards, session-management UI, account lifecycle, withdrawal,
  or authorization decisions;
- treat physical sign-side tables or models as proof of sign-side authority.

## Result Boundary

Delegated credential work crosses the boundary through an acme-issued ceremony grant and a signed
ceremony result.

The grant is short-lived, audience-bound, purpose-bound, one-shot, and bound to an acme transaction
or session when applicable. The sign result is evidence only. `acme/www` consumes the result,
decides whether it satisfies the purpose, and commits any session, account, preference, token,
authorization, or freshness state.

## Related

- `adr/identity-authority-boundary.md`
- `adr/acme-session-and-token-authority.md`
- `adr/sign-credential-gateway-surface.md`
- `plans/identity-authority-inversion-implementation.md`
- `docs/security/credential-gateway.md`
- `docs/security/session-token-authority.md`
