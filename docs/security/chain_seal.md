# ChainSeal

ChainSeal is the compact signature envelope for signed audit-log chains. It is a library and concern
only; no production model currently includes it and no database migration exists yet.

## Compact Format

The internal string format is:

```text
$bc1$jcs-rfc8785$sha3-256$es384$<kid>$<prev_hash_hex>$<block_hash_hex>$<signature_b64u>
```

Rules:

- Fields are positional. Key-value fields are invalid.
- The delimiter is `$`.
- `kid` is the JWKS key id.
- `previous_hash` and `block_hash` are 64-character SHA3-256 hex strings.
- The genesis `previous_hash` is 64 zero hex characters.
- `signature` is an ES384 raw ECDSA signature, 96 bytes encoded as base64url without padding.

## Canonicalization And Hashing

Payloads are canonicalized with RFC8785/JCS through the `json-canonicalization` gem. Do not hash a
caller-provided JSON string directly and do not add a local JSON canonicalizer.

The block hash input is:

```text
previous_hash_hex ASCII bytes || canonical_payload UTF-8 bytes
```

The digest is `OpenSSL::Digest.new("SHA3-256")`. HMACs, salts, and secret peppers are not part of
the ChainSeal format.

The ES384 signing input is the 32 raw bytes decoded from `block_hash_hex`:

```text
signature = ES384.sign(hex_decode(block_hash_hex))
```

## JSON Export

External publication should parse the compact string and emit JSON with these keys:

```json
{
  "format": "bc1",
  "canonicalization_alg": "jcs-rfc8785",
  "hash_alg": "sha3-256",
  "signature_alg": "es384",
  "kid": "...",
  "previous_hash": "...",
  "block_hash": "...",
  "signature": "..."
}
```

Consumers must verify the compact fields against the original payload and the public JWKS key for
the matching `kid`.

## Current Scope

This implementation does not write audit records, choose event payloads, assign sequence numbers, or
manage database columns. Future Chronicle integration should keep audit writes append-oriented and
surface-specific, and should call ChainSeal from the service or recorder layer after the audit
payload is finalized.
