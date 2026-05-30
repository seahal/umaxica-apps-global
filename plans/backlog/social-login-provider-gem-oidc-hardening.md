# Social Login Provider Gem OIDC Hardening

Status: backlog

## Context

Security review of the Apple and Google social-login paths found several risks that are mostly
inherited from the current OmniAuth provider gems rather than from the local Rails linking/session
code. Do not fix these opportunistically inside unrelated social-login work; treat them as a
provider-boundary hardening track.

Current provider gems observed during the review:

- `omniauth-google-oauth2` 1.2.2
- `omniauth-apple` 1.4.0
- `json-jwt` 1.17.0

## Provider-Gem Findings

### Google ID token signature verification

`omniauth-google-oauth2` decodes the ID token without signature verification, then verifies selected
claims. The local application must not assume Google `extra.id_info` was produced from a
JWKS-verified ID token.

Follow-up options:

- Replace or wrap the provider strategy with a Google ID token verifier that verifies the signature
  against Google's JWKS or official Google auth library before any `sub` claim is trusted.
- Remove fallback trust in unsigned `extra.id_info.sub` unless a verified-claims boundary is added.
- Track upstream gem behavior before deciding whether to patch locally, upgrade, or replace the gem.

### Apple nonce verification is provider-controlled

`omniauth-apple` verifies nonce only when the returned ID token advertises nonce support. This is
not strong enough for the local session-issuance boundary.

Follow-up options:

- Add a local Apple ID token verification boundary that requires a nonce claim and validates it
  against a nonce issued before redirecting to Apple.
- Consider replacing the provider strategy if upstream behavior cannot be configured to make nonce
  mandatory.

### ID token freshness policy

The provider gems do not enforce the local application's desired maximum ID token age. Google does
not verify `iat`; Apple only checks that `iat` is not in the future.

Follow-up options:

- Add local verified-claims freshness checks for `iat` and, where present, `auth_time`.
- Decide the maximum acceptable provider assertion age for AAL1 social login.

### Apple JWKS cache ownership

`json-jwt`'s default `JSON::JWK::Set::Fetcher.cache` is effectively no-cache. This is mostly an
availability and operational-resilience issue, not an immediate account-takeover issue.

Follow-up options:

- Configure a Rails-owned TTL cache for Apple JWKS.
- Add kid-miss refresh behavior and avoid unbounded synchronous request-path network dependency.

## Test Expectations

- Forged Google `extra.id_info.sub` cannot create, link, or sign in a social identity.
- Google ID tokens with wrong signature, `alg: none`, wrong `iss`, wrong `aud`, expired `exp`,
  future `nbf`, and stale `iat` are rejected before account linking or session issuance.
- Apple ID tokens with missing nonce, mismatched nonce, reused nonce, wrong signature, wrong `iss`,
  wrong `aud`, expired `exp`, future `iat`, and stale `iat` are rejected before account linking or
  session issuance.
- Apple JWKS cache behavior is covered without real network calls.

## Non-Goals

- Do not change the social-login surface scope: app supports Google and Apple, org supports Google,
  com supports no social login.
- Do not use provider email as an authentication or account-linking boundary.
- Do not treat social login as AAL2.
