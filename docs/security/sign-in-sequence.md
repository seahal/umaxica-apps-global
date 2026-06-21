# Sign-In Sequence

## Authority

Sign-in has two boundaries:

- `sign/id` hosts unauthenticated sign-in entry points and executes credential ceremonies.
- `acme/www` consumes the ceremony result and commits session, actor/session, OIDC, and token state.

Sign-in completion means the credential ceremony is complete on sign and the session commit is
complete on acme. A credential ceremony alone is not a signed-in session.

Logical authority moves now; physical storage may remain where it is. Existing sign-side tables,
models, services, controllers, route names, or namespaces do not imply sign-side authority.

## Sign/ID Responsibilities

`sign/id` may:

- host unauthenticated sign-in entry points;
- collect identifiers needed to start a credential ceremony;
- execute passkey/WebAuthn, OTP, TOTP, passcode, and social callback ceremonies where supported;
- host MFA ceremony steps that are part of sign-in credential proof;
- consume or introspect an acme session only to decide whether a ceremony is needed;
- keep credential inventory and short-lived ceremony state;
- return a signed, one-shot ceremony result to acme.

`sign/id` must not:

- create, rotate, continue, revoke, list, or display user sessions;
- issue access tokens, refresh tokens, OIDC tokens, or downstream tokens;
- store step-up freshness, `recent_auth`, `sudo`, or `last_step_up_at`;
- redirect to a sign dashboard as signed-in authority;
- commit actor/session state;
- decide authorization for product behavior.

Acme's own browser flow uses the shared browser RP client id `base-rails-rp`. The first
`/oauth/authorize` login step establishes Acme authority for code issuance. The later
`/oidc/callback` step validates state, PKCE, nonce, and ID token claims, then establishes the local
product browser session on the same host. That callback is an intentional RP boundary, not a second
authority issuer.

## Acme/WWW Responsibilities

`acme/www` owns:

- session creation and continuation;
- actor/session state;
- sign-in guardrails that depend on account/session/product policy;
- session-limit decisions and session-management UI;
- dashboard and post-auth navigation as authenticated product surfaces;
- OIDC authorization, token issuance, and JWKS authority;
- refresh token family issuance and rotation;
- downstream token issuance;
- step-up freshness confirmation when sign-in is not enough for a later sensitive action.

`core`, `line`, and future downstream services must trust acme-issued downstream tokens, not
sign-issued tokens.

## Ceremony Result Flow

The sign-in flow uses the credential grant/result boundary:

1. The browser enters a sign/id unauthenticated sign-in route.
2. sign/id executes the requested credential ceremony.
3. sign/id returns a signed ceremony result that is audience-bound to acme, purpose-bound, one-shot,
   expiring, and bound to the acme transaction or session where applicable.
4. acme validates and consumes the result.
5. acme commits or rejects session creation and actor/session state.
6. acme performs post-auth navigation, dashboard routing, OIDC continuation, or downstream token
   issuance as acme-owned behavior.

Redirect targets, OAuth/OIDC `state`, Jump `rt`, and local return paths are navigation state. They
must not carry authentication result facts. The signed ceremony result is the security object.

## Sequence Vocabulary

The old sign-in state-machine vocabulary remains useful only as ceremony or compatibility routing
vocabulary:

| Vocabulary                   | Current meaning                                                                     |
| ---------------------------- | ----------------------------------------------------------------------------------- |
| Primary credential           | The first credential ceremony executed by sign/id.                                  |
| MFA challenge during sign-in | Additional credential ceremony before sign returns evidence to acme.                |
| Guardrail                    | A policy stop. If it depends on session/account/product state, acme owns it.        |
| Checkpoint                   | A required pre-session or post-auth requirement. acme owns session/account effects. |
| Selector                     | Acme-owned actor/session selection before session commit.                           |
| Session issuance             | Acme-owned session creation, never sign-owned.                                      |
| Welcome/dashboard            | Acme-owned post-auth navigation or product surface.                                 |

Existing DB-backed sign-in cycle rows may remain physically where they are during migration. They do
not make sign the session authority.

## Surface Inventory

The supported credential methods remain surface-aware:

| Surface | sign/id ceremony methods                                            | acme-owned commit                                            |
| ------- | ------------------------------------------------------------------- | ------------------------------------------------------------ |
| `app`   | email OTP, passkey, TOTP where implemented, passcode, Google, Apple | Client session, account/session state, OIDC/token issuance   |
| `com`   | email OTP, passkey, passcode                                        | Visitor session, account/session state, OIDC/token issuance  |
| `org`   | passkey, passcode                                                   | Operator session, account/session state, OIDC/token issuance |

Org production sign-in does not use external social providers. Google, Apple, Microsoft, and other
external social providers are not org sign-in methods.

## Signed-In Re-Entry

If a browser already has an acme session, sign/id may introspect or consume that fact only to decide
whether a credential ceremony is needed. It must not create a second sign-owned session, redirect to
a sign dashboard as authority, or mutate acme session state.

## OIDC And Token Authority

OIDC survives, but OIDC is acme authority.

Protocol endpoints or route namespaces may remain in compatibility locations during migration. That
does not make sign/id the token authority. Acme owns OIDC authorization, token issuance, ID tokens,
access tokens, refresh tokens, JWKS authority, and downstream token issuance.

## Related

- `docs/identity/authority-boundary.md`
- `docs/security/credential-gateway.md`
- `docs/security/ceremony-grant-result.md`
- `docs/security/session-token-authority.md`
- `docs/security/redirect-vs-ceremony-result.md`
