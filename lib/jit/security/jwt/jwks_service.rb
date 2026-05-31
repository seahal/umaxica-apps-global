# typed: false
# frozen_string_literal: true

require "jwt"
require "json"
require "jit/security/jwt/jwk"
require "jit/security/jwt/registry"

module Jit
  module Security
    module Jwt
      module JwksService
        module_function

        REQUIRED_JWK_FIELDS = Jwk::REQUIRED_PUBLIC_FIELDS
        PRIVATE_JWK_FIELDS = Jwk::PRIVATE_FIELDS

        def jwk_set(namespace = nil)
          return Registry.jwks_for("auth") if namespace.blank?

          Registry.jwks_for("surface:#{Registry.normalize_namespace(namespace)}")
        end

        def public_keys_for(namespace)
          jwk_set(namespace).fetch(:keys)
        end

        def normalized_public_jwk(entry)
          Jwk.normalize_public(entry)
        rescue Jwk::Error
          nil
        end
      end
    end
  end
end
