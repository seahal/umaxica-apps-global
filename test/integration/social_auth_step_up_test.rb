# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthStepUpTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses, :client_google_identity_statuses

  setup do
    @host = ENV.fetch("PRIVATE_SIGN_SERVICE_URL")
    @user = Client.create!(
      status_id: ClientStatus::ACTIVE,
      public_id: "soc_aal1_#{SecureRandom.hex(4)}",
      last_step_up_at: nil,
    )
  end

  test "social auth entry rejects step_up intent" do
    get auth_app_social_google_auth_in_url(intent: "step_up", ri: "jp"),
        headers: as_user_headers(@user, host: @host)

    assert_response :redirect
    assert_match %r{/social/google}, response.location
    assert_not_equal "step_up", session[SocialAuth::SOCIAL_INTENT_SESSION_KEY]
    assert_predicate session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY], :present?
    assert_nil @user.reload.last_step_up_at
  end

  test "social auth service rejects step_up intent even with a linked identity" do
    ClientGoogleIdentity.create!(
      user: @user,
      uid: "social_step_up_forbidden_google",
      provider: "google_app",
      token: "old_token",
      token_expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
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
      SocialAuthCoordinator.handle_callback(
        auth_hash: auth_hash,
        current_client: @user,
        intent: "step_up",
      )
    end

    assert_nil @user.reload.last_step_up_at
  end
end
