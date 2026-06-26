# Move general Sign settings to Acme identity while keeping credential/provider ceremonies in Sign

## Status

Proposed

## Decision

- Sign `/settings` is deprecated as a general settings surface.
- Sign keeps only passkey, TOTP, Google, and Apple ceremonies.
- All other identity/settings flows move to Acme `/identity`.
- Telephone registration belongs to Acme `/identity/telephones`.
- Withdrawal belongs to Acme `/identity/withdrawal`.
- Core / Base / Palm are the conceptual future RP surfaces.
- Sign temporary-session conversion is out of scope for this change.
- Sign RP/session/OIDC/logout architecture is unchanged here.
- Moved GET routes use redirect shims.
- Moved mutation routes return 410 Gone.
- Unsafe methods are never redirected.
- Acme reads MFA inventory from a summary or domain-service boundary; Sign remains the ceremony
  surface for passkeys, TOTP, Google, and Apple.
