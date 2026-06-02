# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Social
    class TemporarySignupGateTest < ActiveSupport::TestCase
      fixtures_none!

      test "signup is disabled when flag is unset" do
        env = {}

        assert_not TemporarySignupGate.signup_enabled?(environment: "test", env: env)
      end

      test "signup is enabled in development when flag is true" do
        env = { "ORG_GOOGLE_SIGNUP_ENABLED" => "true" }

        assert TemporarySignupGate.signup_enabled?(environment: "development", env: env)
      end

      test "signup is enabled in test when flag is true" do
        env = { "ORG_GOOGLE_SIGNUP_ENABLED" => "true" }

        assert TemporarySignupGate.signup_enabled?(environment: "test", env: env)
      end

      test "production signup flag fails fast" do
        env = { "ORG_GOOGLE_SIGNUP_ENABLED" => "true" }

        error =
          assert_raises(RuntimeError) do
            TemporarySignupGate.validate_production_configuration!(environment: "production", env: env)
          end

        assert_match(/ORG_GOOGLE_SIGNUP_ENABLED/, error.message)
        assert_match(/production/, error.message)
      end

      test "production signup is treated as disabled before boot validation" do
        env = { "ORG_GOOGLE_SIGNUP_ENABLED" => "true" }

        assert_not TemporarySignupGate.signup_enabled?(environment: "production", env: env)
      end

      test "provisioning is denied when allowlist is unset" do
        env = {}

        assert_not TemporarySignupGate.provisioning_allowed?("staff@example.test", env: env)
      end

      test "provisioning is allowed only when email is in allowlist" do
        env = { "ORG_GOOGLE_SIGNUP_ALLOWLIST" => "staff@example.test,other@example.test" }

        assert TemporarySignupGate.provisioning_allowed?("staff@example.test", env: env)
        assert_not TemporarySignupGate.provisioning_allowed?("missing@example.test", env: env)
      end

      test "allowlist matching is case insensitive" do
        env = { "ORG_GOOGLE_SIGNUP_ALLOWLIST" => "Staff@Example.Test" }

        assert TemporarySignupGate.provisioning_allowed?("staff@example.test", env: env)
        assert TemporarySignupGate.provisioning_allowed?("STAFF@EXAMPLE.TEST", env: env)
      end

      test "temporary signup gate does not own signin flag" do
        assert_not_respond_to TemporarySignupGate, :signin_enabled?
      end
    end
  end
end
