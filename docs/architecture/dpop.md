# OAuth 2.0 Demonstrating Proof of Possession (DPoP)

## Specification

The DPoP implementation in this application is based on the following specifications:

- **RFC 9449 — OAuth 2.0 Demonstrating Proof of Possession (DPoP)**:
  <https://datatracker.ietf.org/doc/html/rfc9449>
- **RFC 7638 — JSON Web Key (JWK) Thumbprint**: <https://datatracker.ietf.org/doc/html/rfc7638>

## Purpose

DPoP binds access tokens to a client-generated asymmetric key pair. Even if an access token is
intercepted, it cannot be used without the corresponding private key. The client proves possession
of the private key by signing a DPoP proof JWT on each request.

## Design Decisions

- **JTI replay detection is not applied at the access token level.** DPoP proof validation on API
  requests is stateless (signature + htm + htu + iat + ath + cnf.jkt). No Redis lookup per request.
- **JTI replay detection is applied to refresh token and re-auth operations.** These are
  low-frequency and security-critical.
- **This conforms to RFC 9449** where JTI checking is SHOULD, not MUST.
- **Supported algorithms:** ES256 and ES384 only (no RSA).
- **Primary use case:** Next.js frontend to Rails API communication via Authorization header.

## Implementation

Server-side DPoP support lives in `app/services/dpop/`:

| File                                            | Purpose                                                   |
| ----------------------------------------------- | --------------------------------------------------------- |
| `app/services/dpop/proof_validator.rb`          | Core DPoP proof JWT validation (RFC 9449 Section 4.3)     |
| `app/services/dpop/request_verifier.rb`         | Per-request DPoP verification orchestrator                |
| `app/services/dpop/jti_replay_guard.rb`         | Redis-backed JTI deduplication (refresh and re-auth only) |
| `lib/jit/security/jwt/thumbprint_calculator.rb` | RFC 7638 JWK Thumbprint and `ath` computation             |

Token tables (`user_tokens`, `staff_tokens`, `customer_tokens`) store:

- `dpop_jkt` (string) — Base64url-encoded SHA-256 thumbprint of the client's public key

JWT access tokens include:

- `cnf.jkt` claim — the same thumbprint, embedded in the token for binding verification

## Proof Validation Steps

1. JWT header: `typ == "dpop+jwt"`, `alg` in {ES256, ES384}, `jwk` present (public key only)
2. Verify signature using the embedded `jwk`
3. `htm` matches HTTP method
4. `htu` matches HTTP URI (scheme + authority + path)
5. `iat` within acceptable time window
6. If access token provided: `ath == Base64url(SHA256(access_token))`
7. `cnf.jkt` in the access token matches the thumbprint of the proof's `jwk`

## Relationship to DBSC

DPoP and DBSC (W3C Device Bound Session Credentials) serve similar purposes but target different
flows:

| Mechanism | Flow                                | Binding target                     |
| --------- | ----------------------------------- | ---------------------------------- |
| DBSC      | Browser cookie-based sessions       | Session cookie bound to device key |
| DPoP      | API access via Authorization header | Access token bound to client key   |

Both are used in this application. DBSC protects Hotwire/Turbo browser sessions. DPoP protects
Next.js and API client token usage.

## Client Token Strategy

Each client type uses a different combination of token transport and proof-of-possession mechanism,
based on its threat model:

| Client        | Access Token                        | Refresh Token                | Proof-of-Possession |
| ------------- | ----------------------------------- | ---------------------------- | ------------------- |
| Rails HTML    | HttpOnly cookie                     | HttpOnly cookie              | DBSC                |
| Next.js       | DPoP JWT Bearer (Authorization hdr) | HttpOnly cookie              | DPoP                |
| iOS / Android | In-memory bearer                    | Secure storage (Keychain/KS) | DPoP (optional)     |

**Notes:**

- `device_id` is a device identifier used for session management and token family tracking. It is
  not a proof-of-possession mechanism.
- DBSC binds cookies to a device key pair (proof-of-possession at the transport layer).
- DPoP binds bearer tokens to a client key pair (proof-of-possession at the application layer).

### Refresh Token Rotation Family

The primary defense against refresh token theft is **rotation family management** (RFC 6749 Section
10.4):

- Each refresh token use issues a new refresh token and invalidates the previous one.
- All tokens in a family share a `token_family` identifier.
- If a previously invalidated refresh token is presented (replay), the server revokes the entire
  family and forces re-authentication.
- This detects token theft regardless of client type or transport mechanism.

Rotation family management is the core security invariant. DBSC and DPoP add defense-in-depth but
are not substitutes for rotation.

### Native App DPoP Readiness

Native apps (iOS / Android) do not require DPoP at this time. However, the server-side
infrastructure is designed to accept DPoP proofs from any client:

- Token tables (`user_tokens`, `staff_tokens`, `customer_tokens`) already store `dpop_jkt`.
- `DPoP::ProofValidator` and `DPoP::RequestVerifier` are client-agnostic.
- The `cnf.jkt` claim in JWT access tokens works regardless of client type.

The current policy is **optional DPoP** for native clients:

- If a native client sends a DPoP proof header, the server validates it and enforces binding.
- If no DPoP proof is present, the server accepts the token as a standard Bearer token.

When native apps adopt DPoP, the private key should be stored in platform secure hardware (iOS
Secure Enclave / Android Keystore). This prevents token exfiltration from being exploitable even if
the access token itself is leaked.

DPoP enforcement for native clients can be made mandatory in a future phase without server-side
changes.

## Related

- `docs/architecture/dbsc.md` — DBSC specification and implementation
- GitHub #573 — Original DPoP plan
- GitHub #731 — DPoP server-side implementation (DB + model + service)
- GitHub #732 — DPoP web-side design proposal (Next.js proof generation)
- GitHub #733 — OIDC standard endpoints
