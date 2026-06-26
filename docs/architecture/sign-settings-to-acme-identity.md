# Sign Settings To Acme Identity

## Summary

General Sign `/settings` identity and account-management screens are moving to Acme `/identity`.
Sign keeps only credential/provider ceremonies: passkeys, TOTP, Google, and Apple.

## Decision

- Sign `/settings` is deprecated as a general settings surface.
- Acme owns the moved identity/settings pages.
- Sign keeps only passkey, TOTP, Google, and Apple settings.
- Telephone registration moves to Acme `/identity/telephones`.
- Withdrawal moves to Acme `/identity/withdrawal`.
- `credentials` is not used for Acme identity routes.
- `recovery-secret` is separate from API secrets.

## Redirect And Deprecation

- Moved GET routes return 303 See Other redirect shims to Acme `/identity/*`
- Moved mutation routes return 410 Gone
- Unsafe methods are not redirected
- Secret credential rotation and removal remain intentionally unimplemented in Acme
  `/identity/secrets` for this migration closure and stay as 501 Not Implemented

## Scope Notes

- Sign RP/session/OIDC/logout architecture is unchanged in this migration
- The future conceptual RP model is Core / Base / Palm
- Sign temporary-session conversion is a separate follow-up
- Acme reads MFA inventory from a domain summary boundary, not by calling Sign controller flows
- Sign residual tests are boundary tests, not compatibility tests for the retired general settings
  UI

## Needs Decision

- Whether Acme should consume a Sign-owned credential summary API for MFA inventory
