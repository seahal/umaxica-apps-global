# typed: false
# frozen_string_literal: true

require "test_helper"

class EmailVerificationFlowTest < ActionDispatch::IntegrationTest
  fixtures_only :client_statuses, :client_social_apple_statuses, :client_visibilities, :client_multi_factors,
                :client_multi_factor_statuses

  setup do
    CloudflareTurnstile.test_mode = true
    @host = ENV.fetch("SIGN_SERVICE_URL", "id.umaxica.app")
    @user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
  end

  test "social login flow does not trigger email verification and redirects to dashboard" do
    OmniAuth.config.test_mode = true
    # IMPORTANT: Social login uses provider+uid ONLY, NOT email
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      {
        provider: "apple",
        uid: "flow_uid",
        info: {},
        credentials: { token: "token", discarded_at: 1.week.from_now.to_i },
      },
    )

    state = seed_social_auth_session(provider: "apple", intent: "login", ri: "jp")

    # 1. Auth callback
    # We expect NO emails to be sent
    assert_no_emails do
      post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
           params: { state: state },
           headers: social_callback_headers(@host)
    end

    assert_response :redirect
    follow_redirect!

    # Verify we are on dashboard, NOT email verification page
    assert_equal sign_app_dashboard_path, path

    # Client status should still be UNVERIFIED_WITH_SIGN_UP if it was new,
    # but no ClientEmail should have been created from the IdP info
    user = ClientSocialApple.find_by(uid: "flow_uid").user

    assert_nil ClientEmail.find_by(user: user)
  end
end
