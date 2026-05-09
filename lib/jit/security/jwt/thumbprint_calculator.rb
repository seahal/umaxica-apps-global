# typed: false
# frozen_string_literal: true

require "openssl"
require "base64"
require "json"

module Jit
  module Security
    module Jwt
      class ThumbprintCalculator
        def self.calculate(jwk)
          jwk = jwk.to_h if jwk.respond_to?(:to_h)
          jwk = jwk.transform_keys(&:to_s) if jwk.is_a?(Hash)
          ordered = {
            "crv" => jwk["crv"],
            "kty" => jwk["kty"],
            "x" => jwk["x"],
            "y" => jwk["y"],
          }.compact

          unless ordered.keys.sort == %w(crv kty x y)
            raise ArgumentError, "Invalid EC JWK: missing required fields"
          end

          json = JSON.generate(ordered)
          digest = OpenSSL::Digest.digest("SHA256", json)
          Base64.urlsafe_encode64(digest, padding: false)
        end

        def self.ath(access_token)
          digest = OpenSSL::Digest.digest("SHA256", access_token.to_s)
          Base64.urlsafe_encode64(digest, padding: false)
        end
      end
    end
  end
end
