# Downstream Token Authority

## Authority

`acme/www` is the downstream-token Authority.

`core`, `line`, and future downstream services must trust acme-issued downstream tokens only. They
must not trust sign-issued session, access, refresh, or downstream tokens.

## Requirements

Downstream tokens must be:

- issued by acme;
- audience-bound to the downstream service;
- purpose-bound to the downstream action or API family where applicable;
- short-lived;
- verifiable by the downstream service through acme JWKS or the current acme verification channel.

## Non-Goals

- Do not use credential ceremony results as downstream tokens.
- Do not let `sign/id` mint tokens for `core`, `line`, or future downstream services.
- Do not infer downstream authority from physical token table placement.

## Related

- `docs/security/session-token-authority.md`
