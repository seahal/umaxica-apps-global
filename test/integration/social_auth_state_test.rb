# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthStateTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  SOCIAL_FLOW_ID_SESSION_KEY = :social_auth_flow_id
  fixtures :clients, :client_statuses, :client_google_identity_statuses, :client_apple_identity_statuses

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("SIGN_SERVICE_URL", "log.umaxica.app")
    @previous_id_service_url = ENV["ID_SERVICE_URL"]
    ENV["ID_SERVICE_URL"] = @host
    SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)
    SocialCallbackGuard.instance_variable_set(:@allowed_request_origins, nil)
  end

  teardown do
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.mock_auth[:apple] = nil
    if @previous_id_service_url.nil?
      ENV.delete("ID_SERVICE_URL")
    else
      ENV["ID_SERVICE_URL"] = @previous_id_service_url
    end
    SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)
    SocialCallbackGuard.instance_variable_set(:@allowed_request_origins, nil)
  end

  test "login callbacks reject missing app-managed state" do
    uid = "google_login_no_state_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: uid)

    seed_social_auth_session(provider: "google", intent: "login", ri: "jp")

    user_count_before = Client.count

    get auth_app_social_google_callback_url(ri: "jp"),
        headers: social_callback_headers(@host)

    assert_response :forbidden
    assert_equal user_count_before, Client.count
    assert_not ClientGoogleIdentity.exists?(uid: uid)
  end

  test "google callback without ri rejects missing app-managed state before regional redirect" do
    uid = "google_callback_no_ri_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: uid)

    seed_social_auth_session(provider: "google", intent: "login", ri: "jp")

    get auth_app_social_google_callback_url,
        headers: social_callback_headers(@host)

    assert_response :forbidden
    assert_not ClientGoogleIdentity.exists?(uid: uid)
  end

  test "link rejects when flow context is missing" do
    user = clients(:one)
    setup_apple_mock_auth(uid: "apple_link_missing_flow_#{SecureRandom.hex(4)}")

    post auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
         headers: social_callback_headers(@host).merge(as_user_headers(user, host: @host))

    assert_response :forbidden
  end

  test "link fails when flow context is expired" do
    user = clients(:one)
    setup_apple_mock_auth(uid: "apple_link_expired_flow_#{SecureRandom.hex(4)}")

    seed_social_auth_session(provider: "apple", intent: "link", user: user, ri: "jp")
    state = social_auth_state_from_response

    travel_to 6.minutes.from_now do
      post auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
           params: { state: state },
           headers: social_callback_headers(@host).merge(as_user_headers(user, host: @host))
    end

    assert_response :forbidden
  end

  private

  def setup_google_mock_auth(uid:)
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google",
      uid: uid,
      info: { image: "https://example.com/image.jpg" },
      credentials: {
        token: "google_token_#{SecureRandom.hex(8)}",
        refresh_token: "refresh_token",
        discarded_at: 1.week.from_now.to_i,
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
        discarded_at: 1.week.from_now.to_i,
      },
    )
  end
end
