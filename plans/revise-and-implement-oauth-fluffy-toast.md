# OAuth Native-App Foundation: Patch #1 (registered-only auth method) + Patch #2 (public-client PKCE exchange)

## Context

The OIDC token endpoint decides a client's authentication method from a single field on
`OidcClientRegistry::VisitorAccount` called `token_endpoint_auth_method`, built in
`OidcClientRegistry.find` (`app/services/oidc_client_registry.rb:38`) as:

```ruby
token_endpoint_auth_method: config[:token_endpoint_auth_method] || default_auth_method(client_id.to_s)
```

`default_auth_method` (`:268-270`) returns `"client_secret_post"` when a secret resolves, else
`"none"`. This conflates the **registered** auth method (the security contract declared in client
config) with a **computed/effective** default derived from whether a secret happens to load at
runtime. Today nothing grants access on `"none"`, so it is latent. But once public-client (`"none"`)
token exchange exists (Patch #2), a confidential client whose secret fails to load would compute an
effective `"none"` and be silently treated as public — a client-impersonation hole.

This work lands two sequential patches:

- **Patch #1 (foundation safety):** remove the ambiguous `token_endpoint_auth_method` field from
  `VisitorAccount` entirely; expose `registered_token_endpoint_auth_method` plus predicates; route
  every `/token` security decision through the registered value only; quarantine the computed value
  as diagnostic-only metadata; confidential clients with missing/blank/wrong/failed-to-load secrets
  fail `invalid_client`. **Public-client exchange is NOT implemented in Patch #1** — explicit
  `"none"` clients must not pass token exchange yet.
- **Patch #2 (public-client exchange):** add the `/token` path for clients explicitly registered
  with `registered_token_endpoint_auth_method == "none"`, PKCE-only, with no weakening of
  confidential auth and no fallback/metadata `"none"` reaching the public path; advertise `"none"`
  in discovery only after the path works.

Neither patch changes redirect_uri validation, PKCE validation, authorization-code
TTL/locking/binding/single-use, or JWT/session/logout/regional propagation. No loopback redirect, no
http redirect_uri, no `build_redirect_uris` reuse for native clients. No real Palm client and no
Palm callback routes in this work (decision: the public-exchange path is exercised with a
test-constructed public `VisitorAccount` + `OidcClientRegistry.find` stub; real Palm registration
with real Universal/App Link domains is a follow-up).

## Security Invariants (the deliverable contract)

1. **Patch #1:** A client is **public iff** `token_endpoint_auth_method: "none"` is **explicitly
   registered** in its client config. A missing, blank, or failed-to-load secret must **never** make
   a confidential client public. Any computed/effective/default auth method is diagnostic-only and
   must never drive a token-endpoint security decision. All client-auth failures return
   `invalid_client`.
2. **Patch #2:** Only an explicit public client (`public_client? == true` **and**
   `registered_token_endpoint_auth_method == "none"`) may use the public-client token-exchange path,
   which authenticates the client **solely by PKCE** (S256) plus exact redirect_uri match and
   code↔client_id/redirect_uri binding — never by a secret or assertion. A public request carrying
   `client_secret`, `client_assertion`, or `client_assertion_type` is rejected. Fallback/metadata
   `"none"` never enables the public path.

## Files to Modify

- `app/services/oidc_client_registry.rb` (Patch #1)
- `app/services/oidc_token_exchange_service.rb` (Patch #1 + #2)
- `app/services/oidc_discovery_document.rb` (Patch #2)
- `test/services/oidc/client_registry_test.rb` (Patch #1)
- `test/services/oidc/token_exchange_service_test.rb` (Patch #1 + #2)
- `test/services/oidc/discovery_document_test.rb` (Patch #2)

Keep the two patches as two logical commits (Patch #1, then Patch #2).

---

## Patch #1 — Registered-only auth method

### 1. `OidcClientRegistry::VisitorAccount` — remove ambiguous field, add registered value + predicates

Replace the `Data.define` (`oidc_client_registry.rb:11-15`). **Drop `token_endpoint_auth_method`
entirely** (so `respond_to?(:token_endpoint_auth_method)` is false). Add
`registered_token_endpoint_auth_method` (raw config value, `nil` when unregistered) and
`metadata_token_endpoint_auth_method` (the quarantined effective/diagnostic value). Add the
predicates so the security decision lives with the data:

```ruby
VisitorAccount =
  Data.define(
    :client_id, :client_secret, :redirect_uris, :aud, :resource_type,
    :name, :domains, :registered_token_endpoint_auth_method,
    :metadata_token_endpoint_auth_method, :jwt_namespace,
  ) do
    # Security predicates derive ONLY from the registered method. A client is
    # public iff "none" is explicitly registered in config; an absent registered
    # method is confidential, so a missing/blank secret can never imply "public".
    def public_client?
      registered_token_endpoint_auth_method == "none"
    end

    def confidential_client?
      !public_client?
    end

    def private_key_jwt_client?
      registered_token_endpoint_auth_method == "private_key_jwt"
    end
  end
```

`metadata_token_endpoint_auth_method` is **diagnostic/metadata only** — never read by any token
security path. Document this with a comment on the field/helper.

### 2. Populate both fields in `find` (`oidc_client_registry.rb:30-40`)

```ruby
registered_auth_method = config[:token_endpoint_auth_method]

VisitorAccount.new(
  client_id: client_id.to_s,
  client_secret: resolve_secret_credential(client_id.to_s),
  redirect_uris: config[:redirect_uris],
  aud: config[:aud],
  resource_type: config[:resource_type],
  name: config[:name],
  domains: domains_from_redirect_uris(config[:redirect_uris]),
  registered_token_endpoint_auth_method: registered_auth_method,
  metadata_token_endpoint_auth_method: registered_auth_method || metadata_auth_method(client_id.to_s),
  jwt_namespace: config[:jwt_namespace],
)
```

The per-client config keys (`build_clients`, the `token_endpoint_auth_method: "private_key_jwt"`
lines) are the **registered** source of truth and stay unchanged.

### 3. Quarantine the computed default

Rename `default_auth_method` → `metadata_auth_method` (`:268-270`) and add a comment: _"Diagnostic/
metadata only. Never a token-endpoint security decision — use
`registered_token_endpoint_auth_method` / `public_client?` for that."_ Update the
`private_class_method` list (`:290-292`) accordingly.

### 4. Gate assertion auth on the registered value (`oidc_client_registry.rb:71-76`)

```ruby
def authenticate_assertion(client_id, assertion, token_url:)
  client = find(client_id)
  return false unless client&.private_key_jwt_client?

  OidcClientAssertionJwt.valid?(client_id: client_id, assertion: assertion, token_url: token_url)
end
```

`authenticate` (`:63-69`) already fails closed on a blank secret — no change.

### 5. `OidcTokenExchangeService#authenticated_client?` — confidential-only, fail `invalid_client`

Look the client up once; reject the public path (not yet implemented in Patch #1):

```ruby
def authenticated_client?
  client = OidcClientRegistry.find(client_id)
  return false unless client

  return authenticated_client_assertion? if client_assertion.present? || client_assertion_type.present?

  # Patch #1: public-client (registered "none") exchange is NOT implemented. A
  # confidential client with a missing/blank secret must fail here, never fall
  # through to a public path. (Patch #2 adds the explicit public branch.)
  return false if client.public_client?

  OidcClientRegistry.authenticate(client_id, client_secret)
end
```

Change the failure in `call` (`oidc_token_exchange_service.rb:29`) from `invalid_request` to
`invalid_client` (RFC 6749 §5.2; matches `OidcTokenRevocationService`). The `grant_type` check above
stays `invalid_request`; PKCE/redirect/code errors unchanged.

### Patch #1 tests

`test/services/oidc/client_registry_test.rb`:

- `assert_not OidcClientRegistry.find("core_app").respond_to?(:token_endpoint_auth_method)`.
- `find("core_app").registered_token_endpoint_auth_method == "private_key_jwt"` (replaces the old
  `token_endpoint_auth_method` assertion at `:141`; keep the `jwt_namespace` assertion).
- `find("docs_app").registered_token_endpoint_auth_method` is `nil`;
  `find("docs_app").public_client?` is `false`; `find("docs_app").confidential_client?` is `true`.
- Directly construct a `VisitorAccount` with `registered_token_endpoint_auth_method: "none"` →
  `public_client?` true.
- Directly construct a `VisitorAccount` with `registered_token_endpoint_auth_method: nil` and a
  blank/`nil` `client_secret` → `public_client?` false (`confidential_client?` true).

`test/services/oidc/token_exchange_service_test.rb`:

- Valid confidential client still succeeds (existing happy-path `:19-40`, unchanged).
- Missing secret → `invalid_client` (`core_app`, `client_secret: nil`, no stub).
- Blank secret → `invalid_client` (`core_app`, `client_secret: ""`, no stub).
- Wrong secret → `invalid_client` (update existing `:128-143` from `invalid_request`).
- `docs_app` (fallback-`"none"`, no secret) → `invalid_client` (proves effective `"none"` is treated
  confidential; auth fails at the gate, no code setup needed).
- Explicit registered `"none"` client does **not** pass token exchange in Patch #1: stub
  `OidcClientRegistry.find` to return a public `VisitorAccount`; with no secret/assertion →
  `invalid_client`.
- `client_assertion` from a non-`private_key_jwt` client → `invalid_client` (e.g. `docs_app` sending
  an assertion). Update the existing wrong-audience assertion test `:86` from `invalid_request` to
  `invalid_client`.

---

## Patch #2 — Public-client PKCE-only token exchange

### 1. `OidcTokenExchangeService` — add the explicit public branch

```ruby
def authenticated_client?
  client = OidcClientRegistry.find(client_id)
  return false unless client

  return authenticated_client_assertion? if client_assertion.present? || client_assertion_type.present?

  return public_client_authenticated? if client.public_client?

  OidcClientRegistry.authenticate(client_id, client_secret)
end

# Explicit public clients (registered "none") authenticate by PKCE only. They
# must present no confidential credential. PKCE S256, exact redirect_uri match,
# and code<->client_id/redirect_uri binding are still enforced downstream by the
# unchanged validate_code / verify_pkce path.
def public_client_authenticated?
  client_secret.blank?
end
```

Notes:

- A public request carrying `client_assertion`/`client_assertion_type` is already routed to the
  assertion branch above, where `private_key_jwt_client?` is false → `invalid_client`. A public
  request carrying `client_secret` is rejected here. So all three confidential credentials are
  rejected for public clients (requirement #3).
- `code_verifier` presence and S256 match are enforced by the existing `verify_pkce` (`:93-98`) +
  model `verify_pkce`; redirect_uri exact match and code binding by the existing `validate_code`
  (`:83-91`); TTL/lock/single-use unchanged. Public clients therefore inherit full PKCE/binding
  enforcement with no new code.
- plain PKCE remains rejected: authorize only issues S256 codes and `verify_pkce` computes SHA256.

### 2. Discovery advertises `"none"` (`app/services/oidc_discovery_document.rb:22`)

```ruby
token_endpoint_auth_methods_supported: %w(private_key_jwt client_secret_post none),
```

(Keep existing methods; append `"none"` now that the public path works. No http/loopback redirect
support is implied.)

### Patch #2 tests

Use a test helper that builds a public `VisitorAccount` and stubs `OidcClientRegistry.find` to
return it for a fixed public `client_id` (e.g. `"public_native_test"`), while issuing the
authorization code against that `client_id`/`redirect_uri` with an S256 challenge (mirror the
existing `issue_code!` + `with_authenticated_client` patterns). The public account uses
`registered_token_endpoint_auth_method: "none"`, `resource_type: "client"`, and an explicit HTTPS
redirect_uri (no http, no loopback, not via `build_redirect_uris`).

`test/services/oidc/token_exchange_service_test.rb`:

- **Success:** explicit `"none"` client + valid code + exact redirect_uri + valid S256
  `code_verifier` → `success?`.
- **Failures:** missing `client_id`; missing `code_verifier`; wrong `code_verifier`; redirect_uri
  mismatch; client_id mismatch; expired code; reused code; plain-PKCE code; public client sending
  `client_secret`; public client sending `client_assertion`/`client_assertion_type`;
  fallback/metadata `"none"` (`docs_app`) → `invalid_client`.
- **Confidential regression:** confidential client with valid secret still succeeds; blank/missing/
  wrong secret still `invalid_client`; `private_key_jwt` client still requires registered
  `private_key_jwt`.

`test/services/oidc/discovery_document_test.rb`:

- `token_endpoint_auth_methods_supported == %w(private_key_jwt client_secret_post none)` (update
  `:16`); assert discovery implies no http/loopback redirect support (it carries no redirect data —
  assert the document has no loopback/http redirect keys, i.e. the change is auth-methods-only).

---

## Verification

```bash
# Patch #1
bin/rails test test/services/oidc/client_registry_test.rb
bin/rails test test/services/oidc/token_exchange_service_test.rb

# Patch #2 (same files, plus discovery)
bin/rails test test/services/oidc/discovery_document_test.rb

# Broader OIDC/token-endpoint coverage (shared behavior)
bin/rails test test/controllers/acme/oauth_oidc_authority_test.rb \
               test/services/oidc_token_revocation_service_coverage_test.rb
```

Confirm: confidential happy-path still succeeds; missing/blank/wrong secret and `docs_app`
fallback-`"none"` return `invalid_client`; explicit-`"none"` client fails in Patch #1 and succeeds
(PKCE-only) in Patch #2; public client sending any confidential credential fails; discovery lists
`"none"` only after Patch #2; private_key_jwt registry tests unaffected;
`respond_to?(:token_endpoint_auth_method)` is false. Note
`test/integration/oidc_rp_browser_flow_test.rb` is a pre-existing, unrelated failure (per
`notes/implementation/2026-06-14-palm-app-only.md`) and is out of scope.

## Follow-up Work (out of scope here)

1. Register the real Palm native client after the exact claimed HTTPS / Universal Links / App Links
   redirect URI is known.
2. Add the Palm callback/fallback route.
3. Keep Palm native redirect URIs explicit claimed HTTPS only.
4. Do not support loopback redirects for Palm.
5. Do not support `http` redirect_uri for Palm.
6. Do not reuse `build_redirect_uris` for native clients.
7. Keep OAuth `client_id` distinct from access-token `aud`.
8. Do not implement RAR / RFC 9396 `authorization_details` in Patch #1 or Patch #2. Reserve
   `authorization_details`, `authorization_detail`, `authorization_data`, `authz_details`,
   `authz_detail`, `details`, `locations`, `actions`, `datatypes`, `privileges`, and RAR-like
   `resources` for future standards work; do not use them for Umaxica private claims, params,
   database columns, services, or internal APIs.
9. Use Umaxica-specific names such as `access_mode`, `permission_version`, `policy_version`,
   `region`, `surface`, `tenant_id`, `membership_id`, `sid`, and `jti` for proprietary token or
   authorization context. Prefix private claims with `umx_` when they could plausibly collide with a
   current or future OAuth/OIDC extension.
