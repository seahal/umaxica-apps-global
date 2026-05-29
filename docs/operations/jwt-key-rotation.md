# JWT Key Rotation

## Scope

This runbook covers Auth access tokens, Preference tokens, OIDC ID Tokens, and issuer-surface JWKS.
Jump RT has additional redirect-specific steps in `docs/operations/jump-rt-key-rotation.md`.

## Runtime Model

`Jit::Security::Jwt::Registry` is the source of truth built at boot. Request handlers must not parse
keyset JSON, read credentials, read files, call KMS, or make network calls for local signing or JWKS
rendering.

Current private keys are loaded once. Current public JWKs are derived once from those private keys.
Legacy public keys are loaded as grace keys. Revoked kids are rejected even when stale public JWKS
documents still contain them.

`*_PUBLIC_KEYSET` must be public JWK Set JSON:

```json
{"keys":[{"kty":"EC","crv":"P-384","kid":"...","alg":"ES384","use":"sig","x":"...","y":"..."}]}
```

Do not store private DER, private PEM, or private JWK fields in public keysets.

## Required Key Names

Auth:

```text
AUTH_JWT_ACTIVE_KID
AUTH_JWT_PRIVATE_KEYSET
AUTH_JWT_PUBLIC_KEYSET
AUTH_JWT_REVOKED_KIDS
```

Preference:

```text
PREFERENCE_JWT_ACTIVE_KID
PREFERENCE_JWT_PRIVATE_KEYSET
PREFERENCE_JWT_PUBLIC_KEYSET
PREFERENCE_JWT_REVOKED_KIDS
```

Issuer-surface JWKS:

```text
JWT_<NAMESPACE>_ACTIVE_KID
JWT_<NAMESPACE>_PRIVATE_KEY
JWT_<NAMESPACE>_PUBLIC_KEYSET
JWT_<NAMESPACE>_REVOKED_KIDS
```

Production should source private material from the production secret backend. Rails credentials are
acceptable for development and test.

## Rotation Procedure

1. Generate a P-384 ES384 key.
2. Choose a globally unique `kid`.
3. Store the new private key in the secret backend.
4. Publish the new public JWK as a grace key.
5. Deploy and confirm boot validation passes.
6. Switch `ACTIVE_KID` to the new `kid`.
7. Deploy all signers.
8. Confirm new tokens use the new `kid`.
9. Keep old public keys until `max token TTL + leeway + CDN max stale`.
10. Remove old public keys after the grace window.

## Emergency Revocation

1. Add the compromised `kid` to the relevant `*_REVOKED_KIDS`.
2. Deploy verifiers first.
3. Install a new private key and active `kid`.
4. Remove the compromised public key from public JWKS.
5. Purge CDN JWKS caches.
6. Confirm compromised `kid` is rejected.

## Rollback

Keep old private key secret versions until rollback is closed. To roll back, restore the old
`ACTIVE_KID`, restore/select the matching private-key secret version, keep both public JWKs in JWKS
until both token populations expire, then deploy.
