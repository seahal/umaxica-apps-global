# frozen_string_literal: true

require "test_helper"
require "jit_security_jwt_jwks"

module Jit
  module Security
    module Jwt
      class JwksTest < ActiveSupport::TestCase
        fixtures_none!

        setup do
          @key = OpenSSL::PKey::EC.generate("secp384r1")
          @public_jwk = JitSecurityJwtJwk.export_public(@key, kid: "kid-1")
        end

        test "parses jwk set objects" do
          parsed = JitSecurityJwtJwks.parse_public_collection(JSON.generate(keys: [@public_jwk]))

          assert_equal @public_jwk, parsed.fetch("kid-1")
        end

        test "parses jwk arrays" do
          parsed = JitSecurityJwtJwks.parse_public_collection(JSON.generate([@public_jwk]))

          assert_equal @public_jwk, parsed.fetch("kid-1")
        end

        test "rejects jwk set objects without keys array" do
          error =
            assert_raises(JitSecurityJwtJwks::Error) do
              JitSecurityJwtJwks.parse_public_collection(JSON.generate(keys: {}))
            end

          assert_match(/keys array/, error.message)
        end

        test "rejects invalid json" do
          error =
            assert_raises(JitSecurityJwtJwks::Error) do
              JitSecurityJwtJwks.parse_public_collection("{")
            end

          assert_match(/invalid JSON/, error.message)
        end

        test "rejects private material in collection" do
          error =
            assert_raises(JitSecurityJwtJwks::Error) do
              JitSecurityJwtJwks.parse_public_collection(JSON.generate(keys: [@public_jwk.merge("d" => "secret")]))
            end

          assert_match(/private JWK material/, error.message)
        end
      end
    end
  end
end
