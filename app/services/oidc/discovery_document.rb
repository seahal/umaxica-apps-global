# typed: false
# frozen_string_literal: true

module Oidc
  module DiscoveryDocument
    module_function

    def for_resource_type(resource_type)
      issuer = Oidc::Issuer.for_resource_type(resource_type)

      {
        issuer: issuer,
        authorization_endpoint: Oidc::Issuer.authorization_endpoint(resource_type),
        token_endpoint: Oidc::Issuer.token_endpoint(resource_type),
        userinfo_endpoint: Oidc::Issuer.userinfo_endpoint(resource_type),
        jwks_uri: Oidc::Issuer.jwks_uri(resource_type),
        revocation_endpoint: Oidc::Issuer.revocation_endpoint(resource_type),
        end_session_endpoint: Oidc::Issuer.end_session_endpoint(resource_type),
        response_types_supported: ["code"],
        grant_types_supported: ["authorization_code"],
        subject_types_supported: ["public"],
        id_token_signing_alg_values_supported: [Authentication::TokenService::JWT_ALGORITHM],
        token_endpoint_auth_methods_supported: ["client_secret_post"],
        code_challenge_methods_supported: ["S256"],
        scopes_supported: %w(openid profile email),
        claims_supported: %w(sub iss aud exp iat auth_time nonce acr amr sid email email_verified name),
      }
    end
  end
end
