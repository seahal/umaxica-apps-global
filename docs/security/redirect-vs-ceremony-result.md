# Redirects Versus Ceremony Results

## Rule

Redirects move browsers. Ceremony results carry credential evidence.

Do not use redirect targets, `return_to`, `rt`, `pt`, `nt`, `xt`, OAuth `state`, OIDC `state`, or
provider callback navigation as proof that authentication, step-up, account linking, or sign-up
succeeded.

## Redirects

Redirect data may preserve safe navigation intent. It must be signed or registry-bound where the
existing redirect-target rules require it. It must not contain credential result facts.

## Ceremony Results

Ceremony results are signed security objects returned from `sign/id` to `acme/www`. They are
audience-bound, purpose-bound, one-shot, expiring, and transaction/session-bound where applicable.

`acme/www` consumes ceremony results and commits authority state.

## Related

- `docs/security/redirect_targets.md`
- `docs/security/ceremony-grant-result.md`
