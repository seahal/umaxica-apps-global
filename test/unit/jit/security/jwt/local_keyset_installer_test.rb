# typed: false
# frozen_string_literal: true

require "test_helper"
require "jit/security/jwt/local_keyset_installer"

module Jit
  module Security
    module Jwt
      class LocalKeysetInstallerTest < ActiveSupport::TestCase
        fixtures_none!

        setup do
          @store_path = Rails.root.join("tmp/tests/local_jwt_keysets_#{SecureRandom.hex(8)}.json")
          @env_keys = local_jwt_env_keys
          @previous = @env_keys.index_with { |key| ENV[key] }
          @original_issuers = Registry.instance_variable_get(:@issuers)
          clear_local_jwt_env!
          ENV["PREFERENCE_JWT_AUDIENCES"] = "id.umaxica.app"
        end

        teardown do
          Registry.instance_variable_set(:@issuers, @original_issuers)
          @previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
          FileUtils.rm_f(@store_path)
        end

        test "reinstalling from the same local store keeps preference jwt signatures valid" do
          LocalKeysetInstaller.install!(store_path: @store_path)
          Registry.reload!

          token = Preference::Token.encode(
            { "ct" => "dr" },
            host: "id.umaxica.app",
            preference_type: "AppPreference",
            public_id: "pref-public",
            jti: "pref-jti",
          )

          assert_not_nil Preference::Token.decode(token, host: "id.umaxica.app")

          clear_local_jwt_env!
          ENV["PREFERENCE_JWT_AUDIENCES"] = "id.umaxica.app"
          LocalKeysetInstaller.install!(store_path: @store_path)
          Registry.reload!

          decoded = Preference::Token.decode(token, host: "id.umaxica.app")

          assert_not_nil decoded
          assert_equal "pref-public", decoded["public_id"]
          assert_equal "pref-jti", decoded["jti"]
        end

        test "reinstalling keeps surface-scoped preference jwt signatures valid" do
          ENV["PREFERENCE_JWT_AUDIENCES"] = "id.umaxica.org"
          LocalKeysetInstaller.install!(store_path: @store_path)
          Registry.reload!

          token = Preference::Token.encode(
            { "ct" => "dr" },
            host: "id.umaxica.org",
            preference_type: "OrgPreference",
            public_id: "org-pref-public",
            jti: "org-pref-jti",
            jwt_issuer_id: "surface:SIGN_ORG",
          )

          assert_not_nil Preference::Token.decode(
            token,
            host: "id.umaxica.org",
            jwt_issuer_id: "surface:SIGN_ORG",
          )

          clear_local_jwt_env!
          ENV["PREFERENCE_JWT_AUDIENCES"] = "id.umaxica.org"
          LocalKeysetInstaller.install!(store_path: @store_path)
          Registry.reload!

          decoded = Preference::Token.decode(
            token,
            host: "id.umaxica.org",
            jwt_issuer_id: "surface:SIGN_ORG",
          )

          assert_not_nil decoded
          assert_equal "org-pref-public", decoded["public_id"]
          assert_equal "org-pref-jti", decoded["jti"]
        end

        test "partial keyset env is repaired from local store as one matching set" do
          LocalKeysetInstaller.install!(store_path: @store_path)
          original_private_keyset = ENV.fetch("PREFERENCE_JWT_PRIVATE_KEYSET")
          original_public_keyset = ENV.fetch("PREFERENCE_JWT_PUBLIC_KEYSET")

          ENV["PREFERENCE_JWT_PRIVATE_KEYSET"] = nil

          LocalKeysetInstaller.install!(store_path: @store_path)

          assert_equal original_private_keyset, ENV["PREFERENCE_JWT_PRIVATE_KEYSET"]
          assert_equal original_public_keyset, ENV["PREFERENCE_JWT_PUBLIC_KEYSET"]
        end

        test "partial surface env is repaired from local store as one matching set" do
          LocalKeysetInstaller.install!(store_path: @store_path)
          original_private_key = ENV.fetch("JWT_SIGN_APP_PRIVATE_KEY")
          original_public_keyset = ENV.fetch("JWT_SIGN_APP_PUBLIC_KEYSET")

          ENV["JWT_SIGN_APP_PRIVATE_KEY"] = nil

          LocalKeysetInstaller.install!(store_path: @store_path)

          assert_equal original_private_key, ENV["JWT_SIGN_APP_PRIVATE_KEY"]
          assert_equal original_public_keyset, ENV["JWT_SIGN_APP_PUBLIC_KEYSET"]
          Registry.reload!

          assert Registry.private_key_for("surface:SIGN_APP")
          assert Registry.public_key_for("surface:SIGN_APP", ENV.fetch("JWT_SIGN_APP_ACTIVE_KID"))
        end

        test "install writes all local issuers to ignored tmp store" do
          LocalKeysetInstaller.install!(store_path: @store_path)

          store = JSON.parse(File.read(@store_path))
          expected_keys = %w(AUTH PREFERENCE) + Registry::SURFACE_NAMESPACES.map { |namespace| "JWT_#{namespace}" }

          assert_equal expected_keys.sort, store.keys.sort
          assert_equal 0o600, File.stat(@store_path).mode & 0o777
        end

        test "install writes only public jwk material to local public keysets" do
          LocalKeysetInstaller.install!(store_path: @store_path)

          store = JSON.parse(File.read(@store_path))
          public_keysets = [
            JSON.parse(store.fetch("AUTH").fetch("public_keyset")),
            JSON.parse(store.fetch("PREFERENCE").fetch("public_keyset")),
          ]
          Registry::SURFACE_NAMESPACES.each do |namespace|
            public_keysets << JSON.parse(store.fetch("JWT_#{namespace}").fetch("public_keyset"))
          end

          public_keysets.each do |keyset|
            keyset.fetch("keys").each do |jwk|
              assert_empty Jwk::PRIVATE_FIELDS & jwk.keys
              assert_equal "ES384", jwk.fetch("alg")
              assert_equal "sig", jwk.fetch("use")
            end
          end
        end

        test "malformed local store is regenerated into usable keys" do
          FileUtils.mkdir_p(File.dirname(@store_path))
          File.write(@store_path, "not-json")

          logged = []
          Rails.logger.stub(:warn, ->(message) { logged << message }) do
            LocalKeysetInstaller.install!(store_path: @store_path)
          end
          Registry.reload!

          assert(logged.any? { |message| message.include?("jwt.local_keyset_store.malformed") })
          assert Registry.private_key_for("preference")
          assert Registry.public_key_for("preference", ENV.fetch("PREFERENCE_JWT_ACTIVE_KID"))
        end

        test "generating fresh local keys warns that prior tokens will fail verification" do
          warnings = []
          Rails.logger.stub(:warn, ->(message) { warnings << message }) do
            LocalKeysetInstaller.install!(store_path: @store_path)
          end

          regenerated = warnings.select { |message| message.include?("jwt.local_keyset.regenerated") }

          assert_predicate regenerated, :present?,
                           "first install with no store should warn that local keys were minted"
          assert(regenerated.any? { |message| message.include?("PREFERENCE") })
          assert(regenerated.all? { |message| message.include?("will fail verification") })
        end

        test "reinstalling from an existing store does not warn about regeneration" do
          LocalKeysetInstaller.install!(store_path: @store_path)

          clear_local_jwt_env!
          ENV["PREFERENCE_JWT_AUDIENCES"] = "id.umaxica.app"

          warnings = []
          Rails.logger.stub(:warn, ->(message) { warnings << message }) do
            LocalKeysetInstaller.install!(store_path: @store_path)
          end

          assert_empty warnings.select { |message| message.include?("jwt.local_keyset.regenerated") },
                       "reusing persisted keys must not look like a key rotation"
        end

        test "explicit local jwt env values are not replaced" do
          ENV["PREFERENCE_JWT_ACTIVE_KID"] = "explicit-pref-kid"
          ENV["PREFERENCE_JWT_PRIVATE_KEYSET"] = '{"explicit-pref-kid":"private"}'
          ENV["PREFERENCE_JWT_PUBLIC_KEYSET"] = '{"keys":[]}'

          LocalKeysetInstaller.install!(store_path: @store_path)

          assert_equal "explicit-pref-kid", ENV["PREFERENCE_JWT_ACTIVE_KID"]
          assert_equal '{"explicit-pref-kid":"private"}', ENV["PREFERENCE_JWT_PRIVATE_KEYSET"]
          assert_equal '{"keys":[]}', ENV["PREFERENCE_JWT_PUBLIC_KEYSET"]
        end

        private

        def clear_local_jwt_env!
          @env_keys.each { |key| ENV.delete(key) }
        end

        def local_jwt_env_keys
          keys = %w(
            AUTH_JWT_ACTIVE_KID AUTH_JWT_PRIVATE_KEYSET AUTH_JWT_PUBLIC_KEYSET
            PREFERENCE_JWT_ACTIVE_KID PREFERENCE_JWT_PRIVATE_KEYSET PREFERENCE_JWT_PUBLIC_KEYSET
            PREFERENCE_JWT_AUDIENCES
          )
          Registry::SURFACE_NAMESPACES.each do |namespace|
            keys << "JWT_#{namespace}_ACTIVE_KID"
            keys << "JWT_#{namespace}_PRIVATE_KEY"
            keys << "JWT_#{namespace}_PUBLIC_KEYSET"
          end
          keys
        end
      end
    end
  end
end
