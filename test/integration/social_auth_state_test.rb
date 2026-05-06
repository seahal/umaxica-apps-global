# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthStateTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  SOCIAL_FLOW_ID_SESSION_KEY = :social_auth_flow_id
  fixtures :users, :user_statuses, :user_social_google_statuses, :user_social_apple_statuses

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
  end

  teardown do
    OmniAuth.config.mock_auth[:google_app] = nil
    OmniAuth.config.mock_auth[:apple] = nil
  end

  test "login callbacks succeed without app-managed state" do
    uid = "google_login_no_state_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: uid)

    get sign_app_social_start_url(provider: "google_app", intent: "login", ri: "jp"),
        headers: { "Host" => @host }

    assert_response :redirect

    user_count_before = User.count

    get sign_app_auth_callback_url(provider: "google_app", ri: "jp"),
        headers: SocialCallbackTestHelper.callback_headers(@host)

    assert_response :redirect
    assert_equal user_count_before + 1, User.count
    assert UserSocialGoogle.exists?(uid: uid)
  end

  test "link fails when flow context is missing" do
    user = users(:one)
    setup_apple_mock_auth(uid: "apple_link_missing_flow_#{SecureRandom.hex(4)}")

    get sign_app_auth_callback_url(provider: "apple", ri: "jp"),
        headers: SocialCallbackTestHelper.callback_headers(@host).merge(as_user_headers(user, host: @host))

    assert_response :redirect
    assert_includes(
      [sign_app_configuration_apple_url(ri: "jp"), sign_app_configuration_url(ri: "jp")],
      response.location,
    )
    follow_redirect!

    assert_predicate flash[:alert], :present?
  end

  test "link fails when flow context is expired" do
    user = users(:one)
    setup_apple_mock_auth(uid: "apple_link_expired_flow_#{SecureRandom.hex(4)}")

    get sign_app_social_start_url(provider: "apple", intent: "link", ri: "jp"),
        headers: as_user_headers(user, host: @host)

    assert_response :redirect

    travel_to 6.minutes.from_now do
      get sign_app_auth_callback_url(provider: "apple", ri: "jp"),
          headers: SocialCallbackTestHelper.callback_headers(@host).merge(as_user_headers(user, host: @host))
    end

    assert_response :forbidden
  end

  private

  def setup_google_mock_auth(uid:)
    OmniAuth.config.mock_auth[:google_app] = OmniAuth::AuthHash.new(
      provider: "google_app",
      uid: uid,
      info: { image: "https://example.com/image.jpg" },
      credentials: {
        token: "google_token_#{SecureRandom.hex(8)}",
        refresh_token: "refresh_token",
        expires_at: 1.week.from_now.to_i,
      },
    )
  end

  def setup_apple_mock_auth(uid:)
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: uid,
      info: {},
      credentials: {
        token: "apple_token_#{SecureRandom.hex(8)}",
        expires_at: 1.week.from_now.to_i,
      },
    )
  end
end
