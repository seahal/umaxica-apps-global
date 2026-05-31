# frozen_string_literal: true

require "test_helper"
require "jit/security/jwt/key_source"

module Jit
  module Security
    module Jwt
      class KeySourceTest < ActiveSupport::TestCase
        fixtures_none!

        test "reads env values before credentials" do
          source = KeySource.new(
            env: { "AUTH_JWT_PRIVATE_KEYSET" => "env-value" },
            credentials: Object.new.tap do |credentials|
              def credentials.option(*)
                raise "credentials should not be read when env is present"
              end
            end,
          )

          assert_equal "env-value", source.value(:AUTH_JWT_PRIVATE_KEYSET)
        end

        test "falls back to credentials for blank env values" do
          credentials = Minitest::Mock.new
          credentials.expect(:option, "credential-value", [:AUTH_JWT_PRIVATE_KEYSET])

          source = KeySource.new(
            env: { "AUTH_JWT_PRIVATE_KEYSET" => "" },
            credentials: credentials,
          )

          assert_equal "credential-value", source.value(:AUTH_JWT_PRIVATE_KEYSET)
          credentials.verify
        end

        test "fetch mirrors env fetch with stringified keys" do
          source = KeySource.new(env: { "AUTH_JWT_ACTIVE_KID" => "kid" }, credentials: nil)

          assert_equal "kid", source.fetch(:AUTH_JWT_ACTIVE_KID, nil)
          assert_nil source.fetch(:MISSING, nil)
        end

        test "csv splits and trims env lists" do
          source = KeySource.new(env: { "AUTH_JWT_AUDIENCES" => " one, two ,,three " }, credentials: nil)

          assert_equal %w(one two three), source.csv(:AUTH_JWT_AUDIENCES)
        end
      end
    end
  end
end
