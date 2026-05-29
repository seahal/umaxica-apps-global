# typed: false
# frozen_string_literal: true

require "test_helper"
require "jit/security/jwt/registry"

module Jit
  module Security
    module Jwt
      class RegistryTest < ActiveSupport::TestCase
        fixtures_none!

        setup do
          @original_issuers = Registry.instance_variable_get(:@issuers)
          @auth_key = OpenSSL::PKey::EC.generate("secp384r1")
          @auth_legacy_key = OpenSSL::PKey::EC.generate("secp384r1")
          @preference_key = OpenSSL::PKey::EC.generate("secp384r1")
          @preference_legacy_key = OpenSSL::PKey::EC.generate("secp384r1")
          @surface_key = OpenSSL::PKey::EC.generate("secp384r1")
        end

        teardown do
          Registry.instance_variable_set(:@issuers, @original_issuers)
        end

        test "loads configured keys once into immutable issuer records" do
          with_registry_inputs do
            issuers = Registry.reload!

            assert_equal "auth-kid", issuers.fetch("auth").current_kid
            assert_equal "pref-kid", issuers.fetch("preference").current_kid
            assert_equal "sign-app-kid", issuers.fetch("surface:SIGN_APP").current_kid
            assert_predicate issuers.fetch("surface:SIGN_APP").jwks.fetch(:keys), :present?
            assert Registry.public_key_for("auth", "auth-legacy-kid")
            assert Registry.public_key_for("preference", "pref-legacy-kid")
          end
        end

        test "namespace-less jwks includes auth active and grace public keys" do
          with_registry_inputs do
            Registry.reload!

            kids = Jit::Security::Jwt::JwksService.jwk_set.fetch(:keys).map { |jwk| jwk.fetch("kid") }

            assert_includes kids, "auth-kid"
            assert_includes kids, "auth-legacy-kid"
          end
        end

        test "rejects malformed public jwk json at registry load" do
          with_registry_inputs("JWT_SIGN_APP_PUBLIC_KEYSET" => "not-json") do
            error = assert_raises(Registry::ConfigurationError) { Registry.reload! }

            assert_match(/JWT_SIGN_APP_PUBLIC_KEYSET contains invalid JSON/, error.message)
          end
        end

        test "rejects current public jwk that does not match current private key" do
          wrong_key = OpenSSL::PKey::EC.generate("secp384r1")
          wrong_jwk = Registry.export_public_jwk(wrong_key, kid: "sign-app-kid")

          with_registry_inputs("JWT_SIGN_APP_PUBLIC_KEYSET" => JSON.generate([wrong_jwk])) do
            error = assert_raises(Registry::ConfigurationError) { Registry.reload! }

            assert_match(/active public JWK does not match active private key/, error.message)
          end
        end

        test "does not expose revoked kids in jwks and refuses their public keys" do
          with_registry_inputs("JWT_SIGN_APP_REVOKED_KIDS" => "legacy-kid") do
            Registry.reload!

            assert_nil Registry.public_key_for("surface:SIGN_APP", "legacy-kid")
            kids = Registry.jwks_for("surface:SIGN_APP").fetch(:keys).map { |jwk| jwk.fetch("kid") }

            assert_not_includes kids, "legacy-kid"
          end
        end

        test "rejects duplicate non-default kids across issuers" do
          with_registry_inputs("PREFERENCE_JWT_ACTIVE_KID" => "auth-kid") do
            error = assert_raises(Registry::ConfigurationError) { Registry.reload! }

            assert_match(/duplicate JWT kid/, error.message)
          end
        end

        test "rejects default active kid unless explicitly allowed" do
          with_registry_inputs(
            "AUTH_JWT_ACTIVE_KID" => "default",
            "JWT_ALLOW_INSECURE_DEFAULT_KID" => nil,
          ) do
            error = assert_raises(Registry::ConfigurationError) { Registry.reload! }

            assert_match(/active kid must not be "default"/, error.message)
          end
        end

        test "does not retain invalid registry after failed reload" do
          with_registry_inputs do
            valid_records = Registry.reload!

            with_env("JWT_SIGN_APP_PUBLIC_KEYSET" => "not-json") do
              assert_raises(Registry::ConfigurationError) { Registry.reload! }
            end

            assert_same valid_records, Registry.instance_variable_get(:@issuers)
          end
        end

        private

        def with_registry_inputs(extra_env = {})
          legacy_jwk = Registry.export_public_jwk(OpenSSL::PKey::EC.generate("secp384r1"), kid: "legacy-kid")
          env = {
            "AUTH_JWT_ACTIVE_KID" => "auth-kid",
            "PREFERENCE_JWT_ACTIVE_KID" => "pref-kid",
            "PREFERENCE_JWT_AUDIENCES" => "example.com",
            "JWT_SIGN_APP_ACTIVE_KID" => "sign-app-kid",
            "JWT_SIGN_APP_PUBLIC_KEYSET" => JSON.generate([legacy_jwk]),
          }.merge(extra_env)
          Jit::Security::Jwt::Registry::SURFACE_NAMESPACES.each do |namespace|
            next if namespace == "SIGN_APP"

            env["JWT_#{namespace}_ACTIVE_KID"] = nil
            env["JWT_#{namespace}_PUBLIC_KEYSET"] = nil
            env["JWT_#{namespace}_REVOKED_KIDS"] = nil
          end
          env["AUTH_JWT_PRIVATE_KEYSET"] =
            JSON.generate((env["AUTH_JWT_ACTIVE_KID"] || "auth-kid") => base64_der(@auth_key))
          env["AUTH_JWT_PUBLIC_KEYSET"] =
            JSON.generate(keys: [Registry.export_public_jwk(@auth_legacy_key, kid: "auth-legacy-kid")])
          env["PREFERENCE_JWT_PRIVATE_KEYSET"] =
            JSON.generate((env["PREFERENCE_JWT_ACTIVE_KID"] || "pref-kid") => base64_der(@preference_key))
          env["PREFERENCE_JWT_PUBLIC_KEYSET"] =
            JSON.generate(keys: [Registry.export_public_jwk(@preference_legacy_key, kid: "pref-legacy-kid")])

          creds = {
            :AUTH_JWT_PRIVATE_KEYSET => JSON.generate(
              (env["AUTH_JWT_ACTIVE_KID"] || "auth-kid") => base64_der(@auth_key),
            ),
            :AUTH_JWT_PUBLIC_KEYSET => JSON.generate(
              keys: [Registry.export_public_jwk(
                @auth_legacy_key,
                kid: "auth-legacy-kid",
              )],
            ),
            :PREFERENCE_JWT_PRIVATE_KEYSET => JSON.generate(
              (env["PREFERENCE_JWT_ACTIVE_KID"] || "pref-kid") => base64_der(@preference_key),
            ),
            :PREFERENCE_JWT_PUBLIC_KEYSET => JSON.generate(
              keys: [Registry.export_public_jwk(
                @preference_legacy_key,
                kid: "pref-legacy-kid",
              )],
            ),
            "JWT_SIGN_APP_PRIVATE_KEY" => base64_der(@surface_key),
          }

          with_env(env) do
            Rails.app.creds.stub(:option, ->(key, default: nil) { creds.fetch(key, default) }) do
              yield
            end
          end
        end

        def with_env(values)
          previous = {}
          values.each do |key, value|
            previous[key] = ENV[key]
            value.nil? ? ENV.delete(key) : ENV[key] = value
          end
          yield
        ensure
          previous.each do |key, value|
            value.nil? ? ENV.delete(key) : ENV[key] = value
          end
        end

        def base64_der(key)
          Base64.strict_encode64(key.to_der)
        end
      end
    end
  end
end
