# OAuth Native-App Foundation Safety Patch #1: Registered vs. Effective `token_endpoint_auth_method`

## Context

The OIDC token endpoint determines a client's authentication method through a single field on
`OidcClientRegistry::VisitorAccount` called `token_endpoint_auth_method`. That field is built in
`OidcClientRegistry.find` as:

```ruby
token_endpoint_auth_method: config[:token_endpoint_auth_method] || default_auth_method(client_id.to_s)
```

and `default_auth_method` (`app/services/oidc_client_registry.rb:268-270`) returns:

```ruby
resolve_secret_credential(client_id).present? ? "client_secret_post" : "none"
```

This conflates two very different things:

1. The **registered** auth method declared in client config (the security contract).
2. A **computed/effective** default derived from whether a secret happens to resolve at runtime.

Today this is latent rather than exploitable: no code path grants access based on `"none"`, and
`OidcClientRegistry.authenticate` already returns `false` for a blank secret, so a confidential
client with a missing secret currently fails closed. **However**, the upcoming native-app work will
introduce public-client (`token_endpoint_auth_method: "none"`) token exchange. The instant that
branch exists, a confidential client whose secret fails to load (missing credential, blank value,
load error) would compute an effective `"none"` and be silently treated as a public client — a
client-impersonation vulnerability.

This patch is the foundation safety change: separate the **registered** auth method from any
**computed/effective** value, route all `/token` security decisions through the registered value
only, and ensure a confidential client with a missing/blank secret fails with `invalid_client`
instead of ever being mistaken for public.

This patch does **not** implement the Palm native client, public-client token exchange, or any
change to redirect_uri validation, PKCE, authorization-code TTL/locking/binding/single-use, or
JWT/session/logout/regional propagation.

## Security Invariant (the deliverable contract)

> A client is **public** if and only if `token_endpoint_auth_method: "none"` is **explicitly
> registered** in its client config. A missing, blank, or failed-to-load secret must **never** cause
> a confidential client to be treated as public. A computed/effective `"none"` (the absence of a
> registered method) is treated as **confidential** and fails client authentication with
> `invalid_client`.

## Files to Modify

- `app/services/oidc_client_registry.rb`
- `app/services/oidc_token_exchange_service.rb`
- `test/services/oidc/client_registry_test.rb`
- `test/services/oidc/token_exchange_service_test.rb`

## Implementation

### 1. `OidcClientRegistry` — expose the registered value and quarantine the computed one

**Add a dedicated registered accessor and predicates to `VisitorAccount`** (currently
`oidc_client_registry.rb:11-15`). Add a `registered_token_endpoint_auth_method` field that holds the
raw configured value (`nil` when unregistered), and add `public_client?` / `confidential_client?`
predicates so the security decision lives with the data:

```ruby
VisitorAccount =
  Data.define(
    :client_id, :client_secret, :redirect_uris, :aud, :resource_type,
    :name, :domains, :token_endpoint_auth_method,
    :registered_token_endpoint_auth_method, :jwt_namespace,
  ) do
    # A client is public ONLY when "none" is explicitly registered in config.
    # A nil/absent registered method (i.e. an effective/computed default) is
    # treated as confidential so a missing secret can never imply "public".
    def public_client?
      registered_token_endpoint_auth_method == "none"
    end

    def confidential_client?
      !public_client?
    end
  end
```

**Populate both fields in `find`** (`oidc_client_registry.rb:30-40`). Keep the existing effective
field for metadata/back-compat (discovery doc, registry tests), but carry the registered value
verbatim:

```ruby
registered_auth_method = config[:token_endpoint_auth_method]

VisitorAccount.new(
  ...
  token_endpoint_auth_method: registered_auth_method || effective_auth_method(client_id.to_s),
  registered_token_endpoint_auth_method: registered_auth_method,
  jwt_namespace: config[:jwt_namespace],
)
```

**Quarantine the computed default (requirement #3).** Rename `default_auth_method` →
`effective_auth_method` and add a comment stating it is **metadata only and never a security
decision**; the security decision uses `registered_token_endpoint_auth_method` / `public_client?`.
Update the `private_class_method` list accordingly (`oidc_client_registry.rb:290-292`).

**Make the assertion auth branch use the registered value** (`oidc_client_registry.rb:71-76`).
Change `authenticate_assertion` to gate on the registered value so a computed value can never
authorize private_key_jwt:

```ruby
return false unless client&.registered_token_endpoint_auth_method == "private_key_jwt"
```

(`authenticate` at `:63-69` already fails closed on a blank secret — no change needed there; the
blank-secret guard is the existing safety net we are formalizing.)

### 2. `OidcTokenExchangeService` — branch on the registered value, fail with `invalid_client`

**`authenticated_client?`** (`oidc_token_exchange_service.rb:56-60`): look up the client once, and
add an explicit confidential-only guard. Public-client token exchange is intentionally **not**
implemented in this patch, so any client that is not explicitly registered as public must go through
secret/assertion authentication:

```ruby
def authenticated_client?
  client = OidcClientRegistry.find(client_id)
  return false unless client

  return authenticated_client_assertion? if client_assertion.present? || client_assertion_type.present?

  # Public-client (token_endpoint_auth_method: "none") token exchange is not yet
  # supported. A confidential client with a missing/blank secret must fail here,
  # never fall through to a public path.
  return false if client.public_client?

  OidcClientRegistry.authenticate(client_id, client_secret)
end
```

**Error code (requirement #4).** Change the client-authentication failure in `call`
(`oidc_token_exchange_service.rb:29`) from `invalid_request` to `invalid_client`, matching RFC 6749
§5.2 and `OidcTokenRevocationService` (which already returns `invalid_client`):

```ruby
return failure("invalid_client", "OIDC client authentication failed") unless authenticated_client?
```

This unifies all client-auth failures (missing/blank/wrong secret, bad assertion, and the dormant
public-fallback guard) under `invalid_client`. The `grant_type` check above it stays
`invalid_request`; PKCE/redirect/code errors are unchanged.

## Tests

### `test/services/oidc/client_registry_test.rb`

- **Registered accessor is exposed:**
  `find("core_app").registered_token_endpoint_auth_method == "private_key_jwt"`;
  `find("docs_app").registered_token_endpoint_auth_method` is `nil` (no registered method) while its
  effective `token_endpoint_auth_method == "none"`.
- **Explicit `"none"` is distinguishable from fallback `"none"` (requirement #6.4 & #6.5):**
  construct two `VisitorAccount` instances directly — one with
  `registered_token_endpoint_auth_method: "none"` (assert `public_client?`), one with
  `registered_token_endpoint_auth_method: nil` + `token_endpoint_auth_method: "none"` (assert
  `confidential_client?`, `!public_client?`). Also assert `find("docs_app").confidential_client?`
  (real registry fallback-none is confidential).
- Existing `authenticate` blank/nil-secret tests (`:115-118`) already cover the confidential
  missing-secret → `false` registry behavior; leave them.

### `test/services/oidc/token_exchange_service_test.rb`

- **Confidential client with valid secret succeeds (requirement #6.1):** preserved by the existing
  happy-path test (`:19-40`, stubs `authenticate` → true). No change beyond confirming it still
  passes.
- **Confidential client with missing secret fails `invalid_client` (#6.2):** `core_app`,
  `client_secret: nil`, no stub → `result.error == "invalid_client"`.
- **Confidential client with blank secret fails `invalid_client` (#6.3):** `core_app`,
  `client_secret: ""`, no stub → `invalid_client`.
- **Fallback/default `"none"` never accepted as public auth (#6.4):** `docs_app` (registered method
  `nil`, effective `"none"`) with no secret → `invalid_client`, proving the effective `"none"` is
  treated as confidential, not public. (Auth fails at the gate before code lookup, so no
  authorization code setup is needed.)
- **Update existing assertions to the new error code:** `:142` (wrong client_secret) and `:86`
  (assertion wrong-audience) change from `invalid_request` to `invalid_client`.

## Verification

```bash
bin/rails test test/services/oidc/client_registry_test.rb
bin/rails test test/services/oidc/token_exchange_service_test.rb
# Broader OIDC/token-endpoint coverage (shared behavior):
bin/rails test test/controllers/acme/oauth_oidc_authority_test.rb \
               test/services/oidc_token_revocation_service_coverage_test.rb \
               test/services/oidc/discovery_document_test.rb
```

Confirm: happy-path confidential exchange still succeeds; missing/blank/wrong secret returns
`invalid_client`; `docs_app` (fallback-none) returns `invalid_client`; discovery doc and
private_key_jwt registry tests unaffected.

## Follow-up Work (explicit public native clients — out of scope here)

1. **Register the Palm native client** with an explicit `token_endpoint_auth_method: "none"` in
   `OidcClientRegistry.build_clients`.
2. **Implement public-client token exchange:** add the `client.public_client?` success branch in
   `OidcTokenExchangeService#authenticated_client?` (skip secret auth, rely on PKCE), keeping the
   confidential path untouched.
3. **Mandatory PKCE for public clients** (S256 only) at the public-client branch.
4. **Advertise `"none"`** in `OidcDiscoveryDocument#token_endpoint_auth_methods_supported`
   (`app/services/oidc_discovery_document.rb:22`) once public exchange ships.
5. **Native redirect_uri handling** (loopback / custom scheme) — separate patch, explicitly excluded
   from the redirect_uri-validation freeze of this patch.
6. **Registry tests for a real registered-`"none"` client** once one exists, complementing the
   data-level predicate tests added here.

```

```
