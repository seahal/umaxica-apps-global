# typed: false
# frozen_string_literal: true

require "test_helper"
require "jit_security_jwt_registry"

# The registry refuses malformed configuration by naming what is wrong and where,
# because a JWT issuer that boots with a broken key is a signing outage the first
# request discovers. These pin the validation arms that answer with a
# ConfigurationError rather than letting the bad value through.
module Jit
  module Security
    module Jwt
      class RegistryValidationTest < ActiveSupport::TestCase
        self.fixture_table_names = []

        test "an OIDC client namespace is upcased and an unknown one is refused by name" do
          assert_equal "SIGN_APP", JitSecurityJwtRegistry.send(:normalize_oidc_client_namespace, "sign_app")
          assert_equal "SIGN_APP", JitSecurityJwtRegistry.send(:normalize_oidc_client_namespace, :SIGN_APP)

          error =
            assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
              JitSecurityJwtRegistry.send(:normalize_oidc_client_namespace, "martian_surface")
            end

          assert_match(/martian_surface/, error.message)
        end

        test "an invalid public JWK is refused with the source that produced it" do
          error =
            assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
              JitSecurityJwtRegistry.send(:validate_public_jwk!, { "kty" => "EC" }, source: "auth:auth-kid")
            end

          assert_match(/auth:auth-kid/, error.message)
        end

        test "a surface issuer origin is known for every surface namespace" do
          JitSecurityJwtRegistry::SURFACE_NAMESPACES.each do |namespace|
            origin = JitSecurityJwtRegistry.send(:surface_issuer_origin, namespace)

            assert_match(%r{\Ahttps://}, origin, namespace)
          end

          assert_raises(KeyError) { JitSecurityJwtRegistry.send(:surface_issuer_origin, "MARTIAN_APP") }
        end
      end
    end
  end
end
