# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"
require "jit_security_jwt_key_material"

module Jit
  module Security
    module Jwt
      class KeyMaterialTest < ActiveSupport::TestCase
        self.fixture_table_names = []

        setup do
          @key = OpenSSL::PKey::EC.generate("secp384r1")
          @encoded_key = Base64.strict_encode64(@key.to_der)
        end

        test "decodes base64 der ec private keys" do
          key = JitSecurityJwtKeyMaterial.decode_private_key(@encoded_key)

          assert_kind_of OpenSSL::PKey::EC, key
        end

        test "decodes pem ec private keys" do
          key = JitSecurityJwtKeyMaterial.decode_private_key(@key.to_pem)

          assert_kind_of OpenSSL::PKey::EC, key
        end

        test "parses private keyset json object" do
          keyset = JitSecurityJwtKeyMaterial.parse_private_keyset(JSON.generate("kid-1" => @encoded_key))

          assert_kind_of OpenSSL::PKey::EC, keyset.fetch("kid-1")
        end

        test "rejects malformed private keyset json" do
          error =
            assert_raises(JitSecurityJwtKeyMaterial::Error) do
              JitSecurityJwtKeyMaterial.parse_private_keyset("{")
            end

          assert_match(/invalid JSON/, error.message)
        end

        test "rejects non object private keyset json" do
          error =
            assert_raises(JitSecurityJwtKeyMaterial::Error) do
              JitSecurityJwtKeyMaterial.parse_private_keyset(JSON.generate([@encoded_key]))
            end

          assert_match(/JSON object/, error.message)
        end

        test "rejects invalid ec private key material" do
          error =
            assert_raises(JitSecurityJwtKeyMaterial::Error) do
              JitSecurityJwtKeyMaterial.decode_private_key("not-a-key")
            end

          assert_match(/invalid EC key material/, error.message)
        end
      end
    end
  end
end
