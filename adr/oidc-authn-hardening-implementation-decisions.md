# OIDC AuthN Hardening - Decision Record

## What

Hardening OIDC authentication, aligning OIDC claims, making `Current.actor` fail-fast, and adding
acceptance tests.

## Why

- `Current.actor` currently accepts arbitrary values, which is a security problem
- The OIDC claim contract (`subject_type`, `acr`, `amr`) has already been decided at the design
  level but not implemented
- There is insufficient attacker-oriented test coverage

## Who

- Implementation: AI agent (this session)
- Impacted models: `User`, `Staff`, `Customer`, `Unauthenticated`
- Impacted surfaces: all relying parties under `sign.*`, `core`, `acme`, and `docs`

## When

- Existing tokens will be invalidated immediately on production deploy (breaking change introduced
  by required claims)
- Existing tokens are expected to age out naturally because they are short-lived

## Where

| Change target                | File                                                      |
| ---------------------------- | --------------------------------------------------------- |
| Current guard logic          | `app/models/current.rb`                                   |
| AuthorizationCode column add | `db/migrate/*_add_auth_context_to_authorization_codes.rb` |
| TokenClaims                  | `app/services/auth/token_claims.rb`                       |
| TokenService                 | `app/services/auth/token_service.rb`                      |
| TokenExchangeService         | `app/services/oidc/token_exchange_service.rb`             |
| AuthorizeService             | `app/services/oidc/authorize_service.rb`                  |
| Authentication::Base         | `app/controllers/concerns/authentication/base.rb`         |
| Oidc::Callback               | `app/controllers/concerns/oidc/callback.rb`               |
| Tests                        | Corresponding test files                                  |

## How

### Phase 1: Make `Current` fail fast

- Allow only `User`, `Staff`, and `Customer` instances, or `Unauthenticated.instance`, in
  `Current.actor=`
- Allow only `:user`, `:staff`, `:customer`, and `:unauthenticated` in `Current.actor_type=`
- Invalid values should immediately raise `ArgumentError` (TODO: replace with a dedicated exception
  class)

### Phase 2: Add OIDC claims

- Add `auth_method` and `acr` columns to AuthorizationCode
- Add `subject_type`, `acr`, and `amr` parameters to `Auth::TokenClaims.build`
- Add `acr` and `amr` parameters to `Auth::TokenService.encode`
- Add `"customer"` to `VALID_ACTOR_TYPES`
- Add `subject_type`, `acr`, and `amr` to `TokenService.decode` required claims
- Support CustomerToken in `Oidc::TokenExchangeService` + ID token verification + nonce verification
- Store `auth_method` and `acr` in AuthorizationCode in `Oidc::AuthorizeService`

### Phase 3: Support acr/amr on all token issuance paths

- `log_in`: normalize auth_method to amr and pass it through (email -> `["email_otp"]`, passkey ->
  `["passkey"]`, etc.)
- `build_refreshed_session`: pass `acr="aal1"` (refresh should downgrade)
- `reissue_access_token!`: preserve the existing acr/amr
- `Oidc::TokenExchangeService`: read auth_context from AuthorizationCode and set acr/amr

### amr normalization rules

| auth_method           | amr                 |
| --------------------- | ------------------- |
| `"email"`             | `["email_otp"]`     |
| `"passkey"`           | `["passkey"]`       |
| `"social"` + Google   | `["google"]`        |
| `"social"` + Apple    | `["apple"]`         |
| `"secret"` (recovery) | `["recovery_code"]` |

For step-up, add verification methods: `["email_otp", "totp"]`, `["google", "passkey"]`

## Decision points and rationale

### 1. Breaking change to `required_claims`

- **Decision**: Invalidate existing tokens immediately
- **Rationale**: Existing tokens are short-lived (a few minutes), so they will naturally expire
  after deployment

### 2. How to derive amr

- **Decision**: Normalize it in the caller and pass it through
- **Rationale**: `TokenClaims.build` should remain a pure builder and should not infer the
  authentication method

### 3. Persisting auth_context

- **Decision**: Add `auth_method` and `acr` columns to AuthorizationCode
- **Rationale**: This ensures the authentication context is preserved during the OIDC code exchange

### 4. Where to validate nonce

- **Decision**: Validate it in `TokenExchangeService`
- **Rationale**: ID token signature verification and nonce validation should be completed as part of
  the token exchange

### 5. Customer support

- **Decision**: Add `customer` to `VALID_ACTOR_TYPES`
- **Rationale**: The specification clearly defines Customer as a permitted actor
