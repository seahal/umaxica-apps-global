# typed: false
# frozen_string_literal: true

require "jwt"
require "json"
require "jit/security/jwt/registry"

module Jit
  module Security
    module Jwt
      module JwksService
        module_function

        REQUIRED_JWK_FIELDS = %w(kty crv kid alg use x y).freeze
        PRIVATE_JWK_FIELDS = %w(d p q dp dq qi oth k).freeze

        def jwk_set(namespace = nil)
          return Registry.jwks_for("auth") if namespace.blank?

          Registry.jwks_for("surface:#{Registry.normalize_namespace(namespace)}")
        end

        def public_keys_for(namespace)
          jwk_set(namespace).fetch(:keys)
        end

        def normalized_public_jwk(entry)
          return nil unless entry.is_a?(Hash)

          jwk = entry.stringify_keys.slice(*REQUIRED_JWK_FIELDS)
          return nil unless REQUIRED_JWK_FIELDS.all? { |field| jwk[field].present? }
          return nil if PRIVATE_JWK_FIELDS.any? { |field| entry.key?(field) || entry.key?(field.to_sym) }
          return nil unless jwk["alg"] == Authentication::TokenService::JWT_ALGORITHM
          return nil unless jwk["use"] == "sig"
          return nil unless jwk["kty"] == "EC"
          return nil unless jwk["crv"] == "P-384"

          jwk
        end

      end
    end
  end
end
