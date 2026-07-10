# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Jit
  module Security
    module Jwt
      class ThumbprintCalculatorTest < ActiveSupport::TestCase
        test "calculate returns base64url sha256 thumbprint for valid ec jwk" do
          ec = OpenSSL::PKey::EC.generate("prime256v1")
          jwk = JWT::JWK.new(ec).export

          result = JitSecurityJwtThumbprintCalculator.calculate(jwk)

          assert_predicate result, :present?
          assert_no_match(/=+$/, result)
          assert_no_match(%r{[+/]}, result)
        end

        test "calculate raises for missing required fields" do
          assert_raises(ArgumentError) do
            JitSecurityJwtThumbprintCalculator.calculate({ "kty" => "EC" })
          end
        end

        test "ath returns base64url sha256 of access token" do
          token = "test_access_token"
          result = JitSecurityJwtThumbprintCalculator.ath(token)

          expected = Base64.urlsafe_encode64(
            OpenSSL::Digest.digest("SHA256", token),
            padding: false,
          )

          assert_equal expected, result
        end

        test "ath handles empty string" do
          result = JitSecurityJwtThumbprintCalculator.ath("")
          expected = Base64.urlsafe_encode64(
            OpenSSL::Digest.digest("SHA256", ""),
            padding: false,
          )

          assert_equal expected, result
        end
      end
    end
  end
end
