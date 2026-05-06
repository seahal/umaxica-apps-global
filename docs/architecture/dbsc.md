# Device Bound Session Credentials (DBSC)

## Specification

The DBSC implementation in this application is based on the W3C Web Application Security Working
Group specification:

- **W3C DBSC Specification**: <https://w3c.github.io/webappsec-dbsc/>

## Purpose

DBSC binds session cookies to a device-specific key pair. Even if a session cookie is stolen, it
cannot be used on a different device because the server requires proof-of-possession of the private
key that is bound to the session.

## Implementation

The server-side DBSC implementation lives in `app/services/dbsc/`:

| File                                        | Purpose                                               |
| ------------------------------------------- | ----------------------------------------------------- |
| `app/services/dbsc/registration_service.rb` | Registers a device key pair and binds it to a session |
| `app/services/dbsc/verification_service.rb` | Verifies device proof-of-possession on requests       |
| `app/services/dbsc/record_adapter.rb`       | Persistence adapter for DBSC state                    |

Token tables (`user_tokens`, `staff_tokens`) store DBSC-related columns:

- `dbsc_public_key` (JSONB) — the device's public key
- `dbsc_challenge` — challenge value for registration
- `dbsc_session_id` — session binding identifier

## Relationship to DPoP

DBSC and DPoP (RFC 9449) serve similar purposes (proof-of-possession) but target different flows:

| Mechanism | Flow                                | Binding target                     |
| --------- | ----------------------------------- | ---------------------------------- |
| DBSC      | Browser cookie-based sessions       | Session cookie bound to device key |
| DPoP      | API access via Authorization header | Access token bound to client key   |

Both are used in this application. DBSC protects Hotwire/Turbo browser sessions. DPoP protects
Next.js and API client token usage.

## Client Token Strategy

See `docs/architecture/dpop.md` § Client Token Strategy for the full matrix of token transport and
binding mechanisms across all client types (Rails HTML, Next.js, iOS / Android).

## Related

- `docs/architecture/dpop.md` — DPoP specification, implementation, and client token strategy
- `adr/engine-isolate-namespace-adoption.md` — engine architecture
- GitHub #731 — DPoP server-side support
- GitHub #733 — OIDC standard endpoints
