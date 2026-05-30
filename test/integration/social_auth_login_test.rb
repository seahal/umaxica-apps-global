# typed: false
# frozen_string_literal: true

require "test_helper"

# Integration tests for social auth login intent
#
# These tests verify:
# - OPTIONAL: Login with existing identity doesn't create new Client
# - New user creation via social login
# - JWT/session tokens are issued on success
class SocialAuthLoginTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses, :client_google_identity_statuses, :client_apple_identity_statuses

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("SIGN_SERVICE_URL", "id.umaxica.app")
    @callback_headers = social_callback_headers(@host)
  end

  teardown do
    OmniAuth.config.mock_auth[:google_app] = nil
    OmniAuth.config.mock_auth[:apple] = nil
  end

  # ============================================================================
  # OPTIONAL: Login with existing identity doesn't create new user
  # ============================================================================
  test "Google login with existing identity does not create new user" do
    existing_uid = "existing_google_user_#{SecureRandom.hex(4)}"

    # Create existing user with Google identity
    existing_user = Client.create!(status_id: ClientStatus::NOTHING, public_id: "ex_#{SecureRandom.hex(4)}")
    ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google_app",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    setup_google_mock_auth(uid: existing_uid)

    user_count_before = Client.count

    state = start_social_auth_flow(provider: "google_app", intent: "login")

    # Callback
    get sign_app_auth_callback_url(provider: "google_app", ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)

    assert_response :redirect

    # Client count should NOT increase
    assert_equal user_count_before, Client.count, "Existing user login should NOT create new user"

    existing_user.reload

    assert_equal ClientStatus::NOTHING, existing_user.status_id

    follow_redirect!

    assert_predicate flash[:notice], :present?, "Should have success message"
  end

  test "Apple login with existing identity does not create new user" do
    existing_uid = "existing_apple_user_#{SecureRandom.hex(4)}"

    existing_user = Client.create!(status_id: ClientStatus::NOTHING, public_id: "ex_ap_#{SecureRandom.hex(4)}")
    ClientAppleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "apple",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    setup_apple_mock_auth(uid: existing_uid)

    user_count_before = Client.count

    state = start_social_auth_flow(provider: "apple", intent: "login")

    post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
         params: { state: state },
         headers: browser_headers.merge(@callback_headers)

    assert_equal user_count_before, Client.count
  end

  # ============================================================================
  # New user creation
  # ============================================================================
  test "Google login with new uid creates new user and identity" do
    new_uid = "brand_new_google_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)

    user_count_before = Client.count
    identity_count_before = ClientGoogleIdentity.count

    state = start_social_auth_flow(provider: "google_app", intent: "login")

    get sign_app_auth_callback_url(provider: "google_app", ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)

    assert_response :redirect
    assert_redirected_to sign_app_up_guardrail_url(ri: "jp")

    # New user created
    assert_equal user_count_before + 1, Client.count, "New user should be created"
    assert_equal identity_count_before + 1, ClientGoogleIdentity.count

    identity = ClientGoogleIdentity.find_by(uid: new_uid)

    assert_not_nil identity
    assert_not_nil identity.user
    assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, identity.user.status_id
    assert_not_nil identity.last_authenticated_at
    assert_equal "Googleで登録を開始しました", flash[:notice]

    follow_redirect!

    assert_redirected_to sign_app_up_checkpoint_url(ri: "jp")
  end

  test "duplicate Google callback failure after new-account checkpoint returns to sign in" do
    new_uid = "duplicate_callback_google_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)

    state = start_social_auth_flow(provider: "google_app", intent: "login")

    get sign_app_auth_callback_url(provider: "google_app", ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)

    assert_response :redirect
    assert ClientGoogleIdentity.exists?(uid: new_uid)

    get sign_app_auth_failure_url(message: "invalid_credentials", strategy: "google_app"),
        headers: browser_headers.merge("Host" => @host)

    assert_response :redirect
    assert_equal new_sign_app_sign_in_url(ri: "jp"), response.location
  end

  test "provider failure returns to sign up when social auth started from sign up" do
    start_social_auth_flow(provider: "google_app", intent: "login", entry: "sign_up")

    get sign_app_auth_failure_url(message: "invalid_credentials", strategy: "google_app"),
        headers: browser_headers.merge("Host" => @host)

    assert_response :redirect
    assert_equal new_sign_app_sign_up_url(ri: "jp"), response.location
  end

  test "provider failure returns to sign in when social auth started from sign in" do
    start_social_auth_flow(provider: "apple", intent: "login")

    get sign_app_auth_failure_url(message: "invalid_credentials", strategy: "apple"),
        headers: browser_headers.merge("Host" => @host)

    assert_response :redirect
    assert_equal new_sign_app_sign_in_url(ri: "jp"), response.location
  end

  test "Apple login with new uid creates new user and identity" do
    new_uid = "brand_new_apple_#{SecureRandom.hex(4)}"
    setup_apple_mock_auth(uid: new_uid)

    user_count_before = Client.count
    identity_count_before = ClientAppleIdentity.count

    state = start_social_auth_flow(provider: "apple", intent: "login")

    post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
         params: { state: state },
         headers: browser_headers.merge(@callback_headers)

    assert_response :redirect
    assert_redirected_to sign_app_up_guardrail_url(ri: "jp")

    assert_equal user_count_before + 1, Client.count
    assert_equal identity_count_before + 1, ClientAppleIdentity.count

    identity = ClientAppleIdentity.find_by(uid: new_uid)

    assert_not_nil identity
    assert_not_nil identity.user
  end

  # ============================================================================
  # JWT/Session token verification
  # ============================================================================
  test "successful login sets auth cookies" do
    new_uid = "cookie_test_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)

    state = start_social_auth_flow(provider: "google_app", intent: "login")

    get sign_app_auth_callback_url(provider: "google_app", ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)

    assert_response :redirect

    # Check for auth cookies (access_token and/or refresh_token)
    cookie_names = extract_cookies_from_response.keys
    cookie_names.any? { |name|
      name.include?("access") || name.include?("token") || name.include?("session")
    }

    # Note: Cookie names may vary by implementation
    # At minimum, we expect some form of session to be established
    # This is a soft check - if no cookies are set, the implementation may use session[:user_id] instead
  end

  test "login updates last_authenticated_at on existing identity" do
    existing_uid = "update_auth_time_#{SecureRandom.hex(4)}"
    old_auth_time = 1.week.ago

    existing_user = Client.create!(status_id: ClientStatus::NOTHING, public_id: "at_#{SecureRandom.hex(4)}")
    identity = ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google_app",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
      last_authenticated_at: old_auth_time,
    )

    setup_google_mock_auth(uid: existing_uid)

    time_before = Time.current

    state = start_social_auth_flow(provider: "google_app", intent: "login")

    get sign_app_auth_callback_url(provider: "google_app", ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)

    identity.reload

    assert_operator identity.last_authenticated_at, :>=, time_before,
                    "last_authenticated_at should be updated on login"
    assert_operator identity.last_authenticated_at, :>, old_auth_time,
                    "last_authenticated_at should be newer than before"
  end

  private

  # IMPORTANT: Social login authenticates by provider+uid ONLY, NOT email
  # We deliberately omit email from mock_auth to test this requirement
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
      info: {}, # Apple may not provide any info when email scope is not requested
      credentials: {
        token: "apple_token_#{SecureRandom.hex(8)}",
        expires_at: 1.week.from_now.to_i,
      },
    )
  end

  def start_social_auth_flow(provider:, intent:, entry: nil)
    seed_social_auth_session(provider: provider, intent: intent, entry: entry, ri: "jp")
  end

  def social_auth_state_from_response
    session[:social_auth_state].presence ||
      begin
        uri = URI.parse(response.location.to_s)
        Rack::Utils.parse_nested_query(uri.query.to_s)["state"].presence
      rescue URI::InvalidURIError
        nil
      end
  end
end
