# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Social
    class OrgGoogleSigninGateTest < ActiveSupport::TestCase
      fixtures_none!

      test "signin is disabled when flag is unset" do
        assert_not OrgGoogleSigninGate.enabled?(env: {})
      end

      test "signin is enabled only by org google signin flag" do
        env = {
          "ORG_GOOGLE_SIGNIN_ENABLED" => "true",
          "ORG_GOOGLE_SIGNUP_ENABLED" => "false",
        }

        assert OrgGoogleSigninGate.enabled?(env: env)
      end

      test "signin gate is separate from temporary signup gate cleanup target" do
        refute_match(/TEMP\(org-google-social-gateway\)/, File.read(Rails.root.join("app/services/sign/social/org_google_signin_gate.rb")))
        assert_match(/TemporarySignupGate/, File.read(Rails.root.join("app/services/sign/social/temporary_signup_gate.rb")))
        refute_match(/OrgGoogleSigninGate/, File.read(Rails.root.join("app/services/sign/social/temporary_signup_gate.rb")))
      end
    end
  end
end
