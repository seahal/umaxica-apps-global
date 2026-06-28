# frozen_string_literal: true

require "test_helper"
require "jit_security_jwt_jwk"

module Jit
  module Security
    module Jwt
      class JwkTest < ActiveSupport::TestCase
        self.fixture_table_names = []

        setup do
          @key = OpenSSL::PKey::EC.generate("secp384r1")
          @public_jwk = JitSecurityJwtJwk.export_public(@key, kid: "kid-1")
        end

        test "exports public jwk without private material" do
          assert_equal "kid-1", @public_jwk.fetch("kid")
          assert_equal JitSecurityJwtJwk::ALGORITHM, @public_jwk.fetch("alg")
          assert_equal "sig", @public_jwk.fetch("use")
          assert_empty JitSecurityJwtJwk::PRIVATE_FIELDS & @public_jwk.keys
        end

        test "normalizes valid public jwk" do
          normalized = JitSecurityJwtJwk.normalize_public(@public_jwk.merge(extra: "ignored"))

          assert_equal @public_jwk, normalized
        end

        test "rejects public jwk with private material" do
          error =
            assert_raises(JitSecurityJwtJwk::Error) do
              JitSecurityJwtJwk.normalize_public(@public_jwk.merge("d" => "secret"))
            end

          assert_match(/private JWK material/, error.message)
        end

        test "rejects unexpected algorithm" do
          error =
            assert_raises(JitSecurityJwtJwk::Error) do
              JitSecurityJwtJwk.normalize_public(@public_jwk.merge("alg" => "HS256"))
            end

          assert_match(/alg must be ES384/, error.message)
        end

        test "rejects incomplete public jwk" do
          error =
            assert_raises(JitSecurityJwtJwk::Error) do
              JitSecurityJwtJwk.normalize_public(@public_jwk.except("x"))
            end

          assert_match(/missing x/, error.message)
        end

        test "imports valid public jwk material" do
          assert_kind_of OpenSSL::PKey::EC, JitSecurityJwtJwk.import_public_key(@public_jwk)
        end
      end
    end
  end
end
