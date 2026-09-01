# typed: false
# frozen_string_literal: true

require "test_helper"
require "jit_security_jwt_issuer_builder"

# Every parse and import the issuer builder performs is re-raised as its own
# error carrying the configuration source that produced it. Without that, a
# broken key reaches the operator as a JWK library error with no indication of
# which environment variable to fix, and the issuer is a signing outage the first
# request discovers.
module Jit
  module Security
    module Jwt
      class IssuerBuilderConfigurationErrorsTest < ActiveSupport::TestCase
        self.fixture_table_names = []

        test "an unparsable private keyset is refused with the variable that holds it" do
          error =
            assert_raises(JitSecurityJwtIssuerBuilder::Error) do
              JitSecurityJwtIssuerBuilder.parse_private_keyset("{not json", source: "JWT_AUTH_PRIVATE_KEYSET")
            end

          assert_match(/JWT_AUTH_PRIVATE_KEYSET/, error.message)
        end

        test "an unparsable public JWK collection is refused with the variable that holds it" do
          error =
            assert_raises(JitSecurityJwtIssuerBuilder::Error) do
              JitSecurityJwtIssuerBuilder.parse_public_jwk_collection("{not json", source: "JWT_AUTH_PUBLIC_KEYSET")
            end

          assert_match(/JWT_AUTH_PUBLIC_KEYSET/, error.message)
        end

        test "an undecodable private key is refused with the variable that holds it" do
          error =
            assert_raises(JitSecurityJwtIssuerBuilder::Error) do
              JitSecurityJwtIssuerBuilder.decode_private_key("not-a-key", source: "JWT_AUTH_PRIVATE_KEY")
            end

          assert_match(/JWT_AUTH_PRIVATE_KEY/, error.message)
        end

        test "a public JWK that cannot be imported is refused as a configuration error" do
          assert_raises(JitSecurityJwtIssuerBuilder::Error) do
            JitSecurityJwtIssuerBuilder.import_public_key({ "kty" => "EC" })
          end
        end

        # A private key whose public half disagrees with the published JWK would
        # sign tokens no verifier accepts, so the mismatch is refused at boot.
        test "a private key that disagrees with its published JWK is refused by kid" do
          key = OpenSSL::PKey::EC.generate("secp384r1")
          other = OpenSSL::PKey::EC.generate("secp384r1")
          published = JitSecurityJwtJwk.export_public(other, kid: "auth-2026")

          error =
            assert_raises(JitSecurityJwtIssuerBuilder::Error) do
              JitSecurityJwtIssuerBuilder.merge_keys(
                private_keys: { "auth-2026" => key },
                public_jwks: { "auth-2026" => published },
                current_kid: "auth-2026",
                revoked_kids: [],
              )
            end

          assert_match(/"auth-2026" does not match configured public JWK/, error.message)
        end

        test "a private key that agrees with its published JWK merges into one active record" do
          key = OpenSSL::PKey::EC.generate("secp384r1")
          published = JitSecurityJwtJwk.export_public(key, kid: "auth-2026")

          merged =
            JitSecurityJwtIssuerBuilder.merge_keys(
              private_keys: { "auth-2026" => key },
              public_jwks: { "auth-2026" => published },
              current_kid: "auth-2026",
              revoked_kids: [],
            )

          assert_equal %w(auth-2026), merged.keys
          assert_equal "active", merged.fetch("auth-2026").state
          assert merged.fetch("auth-2026").private_key
        end
      end
    end
  end
end
