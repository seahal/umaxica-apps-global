# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"
require "jit_security_jwt_key_source"

module Jit
  module Security
    module Jwt
      class KeySourceTest < ActiveSupport::TestCase
        self.fixture_table_names = []

        test "reads env values before credentials" do
          source = JitSecurityJwtKeySource.new(
            env: { "AUTH_JWT_PRIVATE_KEYSET" => "env-value" },
            credentials: Object.new.tap do |credentials|
              def credentials.option(*)
                raise RuntimeError, "credentials should not be read when env is present"
              end
            end,
          )

          assert_equal "env-value", source.value(:AUTH_JWT_PRIVATE_KEYSET)
        end

        test "falls back to credentials for blank env values" do
          credentials = Minitest::Mock.new
          credentials.expect(:option, "credential-value", [:AUTH_JWT_PRIVATE_KEYSET])

          source = JitSecurityJwtKeySource.new(
            env: { "AUTH_JWT_PRIVATE_KEYSET" => "" },
            credentials: credentials,
          )

          assert_equal "credential-value", source.value(:AUTH_JWT_PRIVATE_KEYSET)
          credentials.verify
        end

        test "fetch mirrors env fetch with stringified keys" do
          source = JitSecurityJwtKeySource.new(env: { "AUTH_JWT_ACTIVE_KID" => "kid" }, credentials: nil)

          assert_equal "kid", source.fetch(:AUTH_JWT_ACTIVE_KID, nil)
          assert_nil source.fetch(:MISSING, nil)
        end

        test "csv splits and trims env lists" do
          source = JitSecurityJwtKeySource.new(env: { "AUTH_JWT_AUDIENCES" => " one, two ,,three " }, credentials: nil)

          assert_equal %w(one two three), source.csv(:AUTH_JWT_AUDIENCES)
        end
      end
    end
  end
end
