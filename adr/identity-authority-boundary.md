# Identity Authority Boundary

## Status

Accepted (2026-06-02)

## Context

Earlier ADRs described `sign/id` as the identity provider and `acme/www` as a relying-party
application surface. That model no longer matches the target identity architecture.

The current direction concentrates session, token, account, preference, authorization, downstream
token trust, dashboard, session management, audit interpretation, and step-up freshness in
`acme/www`. Keeping `sign/id` as an IdP while those responsibilities move to `acme/www` creates two
IdP-like centers and makes future authentication and authorization boundaries ambiguous.

This ADR is the source of truth for authority ownership. Older ADRs that describe an IdP/RP split,
sign-side sessions, sign-side refresh tokens, sign-side preference writes, sign-side account
lifecycle, sign-side downstream token issuance, or sign-side step-up freshness are superseded to
that extent.

## Decision

`acme/www` is the identity authority for application state:

- `acme/www` is the only Session Authority.
- `acme/www` is the Token Authority.
- `acme/www` is the Account Authority.
- `acme/www` is the Preference Authority.
- `acme/www` is the Authorization Authority.

`sign/id` is not the IdP. `sign/id` is the Credential Authority, Credential Gateway, and Credential
Ceremony Zone. It exists to run credential ceremonies that need stable browser-facing URLs and
provider callback URLs.

## sign/id Allowed Responsibilities

`sign/id` may own:

- credential inventory;
- short-lived credential ceremony state;
- Passkey / WebAuthn ceremonies;
- OTP and TOTP ceremonies;
- social login provider callbacks;
- credential enrollment;
- credential assertion;
- step-up credential ceremony execution;
- credential ceremony audit facts.

Credential ceremony audit facts are not session freshness. A recorded ceremony event does not make
the current acme session recently authenticated unless `acme/www` consumes a valid ceremony result
and updates acme-owned session state.

## sign/id Prohibited Responsibilities

`sign/id` must not own or implement:

- user sessions;
- refresh tokens;
- preference writes;
- dashboards;
- session-management UI;
- account lifecycle;
- downstream token issuance;
- authorization decisions;
- step-up freshness;
- `sudo`, `recent_auth`, or equivalent session-elevation state.

If a new feature needs session, token, account, preference, authorization, dashboard, downstream
token, or step-up freshness state, it belongs under `acme/www`, not `sign/id`.

## Ceremony Grant And Result Contract

`acme/www` requests credential ceremonies by issuing a ceremony grant to `sign/id`. `sign/id`
returns only a ceremony result to `acme/www`.

Ceremony grants and results must be:

- signed;
- audience-bound;
- purpose-bound;
- one-shot;
- short-lived;
- bound to an acme transaction or acme session where applicable.

A signed ceremony result proves only that a credential ceremony completed. It does not authorize an
application action by itself. `acme/www` consumes the result and decides whether to create a
session, link a credential, complete account state, authorize an operation, or record step-up
freshness.

Return targets, redirect parameters, and navigation tokens are not ceremony results. They must not
be used as authentication proof.

## Downstream Token Trust Boundary

`core`, `line`, and future downstream services must trust acme-issued downstream tokens for
application authorization and downstream access.

They must not trust sign-issued tokens for application authorization or downstream access. `sign/id`
may issue only credential ceremony artifacts within the ceremony contract described above.

## Guardrails

Future ADRs, plans, and implementation work must not reintroduce sign-side sessions, refresh tokens,
preference writes, dashboards, account lifecycle, downstream token issuance, authorization
decisions, or step-up freshness.

Any expansion of the Credential Gateway must show that the new behavior remains credential
ceremony-only. If the behavior requires application identity state, the owning surface is
`acme/www`.

## Follow-Up ADR Checklist

The following ADRs are still required to operationalize this authority boundary:

- acme session and token authority;
- sign/id credential gateway surface;
- delegated credential ceremony grant/result;
- step-up ceremony delegation;
- WebAuthn RP ID and origin boundary;
- social login callback boundary;
- acme preference authority;
- cookie domain and session isolation;
- downstream token authority;
- redirect transaction / ceremony result transport.
