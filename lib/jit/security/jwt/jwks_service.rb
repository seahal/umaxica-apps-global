# typed: false
# frozen_string_literal: true

require "jwt"
require "json"

module Jit
  module Security
    module Jwt
      module JwksService
        module_function

        REQUIRED_JWK_FIELDS = %w(kty crv kid alg use x y).freeze
        PRIVATE_JWK_FIELDS = %w(d p q dp dq qi oth k).freeze

        def jwk_set(namespace = nil)
          return legacy_auth_jwk_set if namespace.blank?

          { keys: public_keys_for(namespace) }
        end

        def public_keys_for(namespace)
          raw = ENV["JWT_#{namespace}_PUBLIC_KEYSET"].to_s
          return [] if raw.blank?

          parsed = JSON.parse(raw)
          return [] unless parsed.is_a?(Array)

          parsed.filter_map { |entry| normalized_public_jwk(entry) }
        rescue JSON::ParserError
          []
        end

        def active_kid_for(namespace)
          ENV["JWT_#{namespace}_ACTIVE_KID"].presence
        end

        def legacy_auth_jwk_set
          kid = Keyring.active_kid
          public_key = Keyring.public_key_for(kid)
          return { keys: [] } unless public_key

          jwk = JWT::JWK.new(public_key, kid: kid)
          exported = jwk.export
          exported[:use] = "sig"
          exported[:alg] = Authentication::TokenService::JWT_ALGORITHM

          { keys: [exported] }
        end

        def normalized_public_jwk(entry)
          return nil unless entry.is_a?(Hash)

          jwk = entry.stringify_keys.slice(*REQUIRED_JWK_FIELDS)
          return nil unless REQUIRED_JWK_FIELDS.all? { |field| jwk[field].present? }
          return nil if PRIVATE_JWK_FIELDS.any? { |field| entry.key?(field) || entry.key?(field.to_sym) }
          return nil unless jwk["alg"] == Authentication::TokenService::JWT_ALGORITHM
          return nil unless jwk["use"] == "sig"

          jwk
        end
      end
    end
  end
end
