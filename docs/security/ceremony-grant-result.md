# Ceremony Grant And Result

## Purpose

Credential ceremonies delegated to `sign/id` must not smuggle session, account, token, preference,
or authorization mutations through redirects or provider state. They use an explicit grant/result
boundary.

## Ceremony Grant

`acme/www` issues the ceremony grant. The grant must be:

- short-lived;
- audience-bound to `sign/id`;
- purpose-bound to a single ceremony purpose;
- one-shot;
- bound to an acme transaction;
- bound to an acme session when the ceremony is session-scoped.

The grant authorizes ceremony execution only. It does not authorize `sign/id` to commit account,
session, preference, token, authorization, or freshness state.

## Ceremony Result

`sign/id` returns a signed ceremony result. The result must be:

- signed by `sign/id`;
- audience-bound to `acme/www`;
- purpose-bound to the original grant purpose;
- one-shot and replay-detectable;
- bound to the original acme transaction and session where applicable;
- expiring;
- limited to credential ceremony evidence.

`acme/www` validates and consumes the result once. Only acme commits any user session, refresh,
account, preference, downstream token, authorization, or step-up freshness change.

## Redirects Are Not Results

Redirect targets, `rt`, `return_to`, OAuth `state`, and navigation parameters are navigation
mechanisms. They are not authentication or credential result transport. A redirect may carry the
browser to a result-consumption endpoint, but the signed ceremony result is the security object.

## Related

- `docs/security/redirect-vs-ceremony-result.md`
- `docs/security/credential-gateway.md`
