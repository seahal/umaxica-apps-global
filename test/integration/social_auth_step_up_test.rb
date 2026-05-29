# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthStepUpTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses, :client_social_google_statuses

  setup do
    @host = ENV.fetch("SIGN_SERVICE_URL", "id.umaxica.app")
    @user = Client.create!(
      status_id: ClientStatus::ACTIVE,
      public_id: "soc_aal1_#{SecureRandom.hex(4)}",
      last_step_up_at: nil,
    )
  end

  test "social auth entry rejects step_up intent" do
    post continue_sign_app_social_authentication_url(provider: "google_app", intent: "step_up", ri: "jp"),
         headers: as_user_headers(@user, host: @host)

    assert_response :redirect
    assert_match %r{/auth/google_app}, response.location
    assert_equal "step_up", session[SocialAuthConcern::SOCIAL_INTENT_SESSION_KEY]
    assert_predicate session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY], :present?
    assert_nil @user.reload.last_step_up_at
  end

  test "social auth service rejects step_up intent even with a linked identity" do
    ClientSocialGoogle.create!(
      user: @user,
      uid: "social_step_up_forbidden_google",
      provider: "google_app",
      token: "old_token",
      token_expires_at: 1.week.from_now.to_i,
      user_social_google_status: client_social_google_statuses(:active),
    )
    auth_hash = OmniAuth::AuthHash.new(
      provider: "google_app",
      uid: "social_step_up_forbidden_google",
      info: {},
      credentials: {
        token: "new_token",
        expires_at: 1.week.from_now.to_i,
      },
    )

    assert_raises(SocialAuth::UnauthorizedError) do
      SocialAuthService.handle_callback(
        auth_hash: auth_hash,
        current_client: @user,
        intent: "step_up",
      )
    end

    assert_nil @user.reload.last_step_up_at
  end
end
