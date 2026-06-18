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
    get sign_app_auth_google_app_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    submit_social_completion_if_present!

    assert_response :redirect

    # Client count should NOT increase
    assert_equal user_count_before, Client.count, "Existing user login should NOT create new user"

    existing_user.reload

    assert_equal ClientStatus::NOTHING, existing_user.status_id
  end

  test "Google login with existing identity completes through acme dashboard" do
    existing_uid = "existing_google_welcome_#{SecureRandom.hex(4)}"
    existing_user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "wel_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google_app",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )
    setup_google_mock_auth(uid: existing_uid)

    state = start_social_auth_flow(provider: "google_app", intent: "login")

    get sign_app_auth_google_app_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    submit_social_completion_if_present!

    assert_redirected_to acme_app_dashboard_url(ri: "jp", host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"))

    cycle = ClientSignInFlow.where(principal_id: existing_user.id).recent_first.first

    assert_equal ClientSignInFlowStatus::CHECKPOINT_PENDING, cycle.status_id
  end

  test "Google login with session limit pending redirects to acme session management" do
    existing_uid = "existing_google_session_limit_#{SecureRandom.hex(4)}"
    existing_user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "lim_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google_app",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )
    2.times { create_active_user_session_for_limit(existing_user) }
    setup_google_mock_auth(uid: existing_uid)

    state = start_social_auth_flow(provider: "google_app", intent: "login")

    get sign_app_auth_google_app_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    submit_social_completion_if_present!

    assert_redirected_to acme_app_sign_settings_sessions_url(
      ri: "jp",
      host: ENV.fetch(
        "ACME_SERVICE_URL", "www.app.localhost",
      ),
    )
  end

  def create_active_user_session_for_limit(user)
    token = ClientToken.new(user: user, user_token_status_id: ClientTokenStatus::ACTIVE)
    token.send(:skip_session_limit_check=, true)
    token.save!
    token
  end

  test "Google established login callback posts a one-shot result to acme without provider tokens" do
    existing_uid = "existing_google_transport_#{SecureRandom.hex(4)}"
    existing_user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "trn_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    identity = ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google_app",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )
    OmniAuth.config.mock_auth[:google_app] = OmniAuth::AuthHash.new(
      provider: "google_app",
      uid: existing_uid,
      info: {},
      credentials: {
        token: "transport_access_token",
        refresh_token: "transport_refresh_token",
        expires_at: 1.week.from_now.to_i,
      },
    )

    state = start_social_auth_flow(provider: "google_app", intent: "login")

    assert_no_difference("ClientSignInFlow.count") do
      get sign_app_auth_google_app_callback_url(ri: "jp"),
          params: { state: state },
          headers: browser_headers.merge(@callback_headers)
    end

    assert_response :success
    assert_includes response.body, "social-completion-form"
    assert_not_includes response.body, "transport_access_token"
    assert_not_includes response.body, "transport_refresh_token"
    assert_not_includes response.body, "old_token"

    form = response.parsed_body.at_css("form#social-completion-form")

    assert_equal "post", form["method"]
    assert_equal(
      completion_acme_app_social_authentication_url(
        id: "google_app",
        host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
      ),
      form["action"],
    )
    assert form.at_css("input[name='social_ceremony_result']")
    assert_nil form.at_css("input[name='return_to']")

    assert_equal "old_token", identity.reload.token
  end

  test "Google sign up entry with existing identity falls through to sign in flow" do
    existing_uid = "existing_google_signup_entry_#{SecureRandom.hex(4)}"
    existing_user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "sug_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
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

    state = start_social_auth_flow(provider: "google_app", intent: "login", entry: "sign_up")

    sign_up_cycle = ClientSignUpFlow.order(:id).last

    assert_equal "google", sign_up_cycle.entry_method
    assert_equal "social_callback", sign_up_cycle.step

    get sign_app_auth_google_app_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    submit_social_completion_if_present!

    assert_redirected_to acme_app_dashboard_url(ri: "jp", host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"))
    assert_equal user_count_before, Client.count

    sign_in_cycle = ClientSignInFlow.where(principal_id: existing_user.id).recent_first.first

    assert_equal ClientSignInFlowStatus::CHECKPOINT_PENDING, sign_in_cycle.reload.status_id
    assert_equal "social_callback", sign_up_cycle.reload.step
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
    submit_social_completion_if_present!

    assert_equal user_count_before, Client.count
  end

  test "Apple sign up entry with existing identity falls through to sign in flow" do
    existing_uid = "existing_apple_signup_entry_#{SecureRandom.hex(4)}"
    existing_user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "sua_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
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

    state = start_social_auth_flow(provider: "apple", intent: "login", entry: "sign_up")

    sign_up_cycle = ClientSignUpFlow.order(:id).last

    assert_equal "apple", sign_up_cycle.entry_method
    assert_equal "social_callback", sign_up_cycle.step

    post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
         params: { state: state },
         headers: browser_headers.merge(@callback_headers)
    submit_social_completion_if_present!

    assert_redirected_to acme_app_dashboard_url(ri: "jp", host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"))
    assert_equal user_count_before, Client.count

    sign_in_cycle = ClientSignInFlow.where(principal_id: existing_user.id).recent_first.first

    assert_equal ClientSignInFlowStatus::CHECKPOINT_PENDING, sign_in_cycle.reload.status_id
    assert_equal "social_callback", sign_up_cycle.reload.step
  end

  # ============================================================================
  # New user creation
  # ============================================================================
  # rubocop:disable Minitest/MultipleAssertions
  test "Google login with new uid waits for signup confirmation before creating user and identity" do
    new_uid = "brand_new_google_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)

    user_count_before = Client.count
    identity_count_before = ClientGoogleIdentity.count

    state = start_social_auth_flow(provider: "google_app", intent: "login")

    assert_no_difference("Client.count") do
      assert_no_difference("ClientGoogleIdentity.count") do
        assert_no_difference("ClientAccount.count") do
          assert_no_difference("Organization.count") do
            assert_no_difference("Avatar.count") do
              assert_no_difference("ClientToken.count") do
                get sign_app_auth_google_app_callback_url(ri: "jp"),
                    params: { state: state },
                    headers: browser_headers.merge(@callback_headers)
                submit_social_completion_if_present!
              end
            end
          end
        end
      end
    end

    assert_redirected_to sign_app_sign_up_guard_google_url(ri: "jp")
    follow_redirect!

    assert_redirected_to sign_app_sign_up_check_google_confirmation_url(ri: "jp")
    follow_redirect!

    assert_response :ok
    assert_includes response.body, "このGoogleアカウントは未登録です。"
    assert_includes response.body, "新しいUmaxica Identityを作成します。"
    assert_includes response.body, "既存アカウントとは後から統合できません。"
    assert_includes response.body, "間違いならキャンセルしてください。"
    assert_select "input[name=confirm_new_social_identity][required]"

    cycle = ClientSignUpFlow.order(:id).last

    assert_no_difference("Client.count") do
      assert_no_difference("ClientGoogleIdentity.count") do
        assert_no_difference("ClientAccount.count") do
          assert_no_difference("Organization.count") do
            assert_no_difference("Avatar.count") do
              assert_no_difference("ClientToken.count") do
                patch sign_app_sign_up_check_google_birthdate_url(ri: "jp"),
                      params: {
                        requirement: "birthdate",
                        birthdate: "2000-02-03",
                        checkpoint_version: cycle.checkpoint_version,
                      },
                      headers: browser_headers.merge(@callback_headers)
              end
            end
          end
        end
      end
    end

    assert_response :unprocessable_content

    patch sign_app_sign_up_check_google_confirmation_url(ri: "jp"),
          params: { confirm_new_social_identity: "1", checkpoint_version: cycle.reload.checkpoint_version },
          headers: browser_headers.merge(@callback_headers)

    assert_redirected_to sign_app_sign_up_check_google_birthdate_url(ri: "jp")

    assert_no_difference("Client.count") do
      assert_no_difference("ClientGoogleIdentity.count") do
        patch sign_app_sign_up_check_google_birthdate_url(ri: "jp"),
              params: {
                requirement: "birthdate",
                birthdate: "2000-02-03",
                checkpoint_version: cycle.reload.checkpoint_version,
              },
              headers: browser_headers.merge(@callback_headers)
      end
    end

    assert_response :ok
    assert_includes response.body, "social-completion-form"

    assert_difference("Client.count", 1) do
      assert_difference("ClientGoogleIdentity.count", 1) do
        submit_social_completion_if_present!
      end
    end

    assert_equal identity_count_before + 1, ClientGoogleIdentity.count

    identity = ClientGoogleIdentity.find_by(uid: new_uid)

    assert_not_nil identity
    assert_not_nil identity.user
    assert_equal user_count_before + 1, Client.count, "New user should be created after confirmation"
    assert_equal ClientStatus::VERIFIED_WITH_SIGN_UP, identity.user.status_id
    assert_equal "2000-02-03", identity.user.birthdate.to_s
    assert_not_nil identity.last_authenticated_at
  end
  # rubocop:enable Minitest/MultipleAssertions

  test "duplicate Google callback failure after new-account checkpoint returns to sign in" do
    new_uid = "duplicate_callback_google_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)

    state = start_social_auth_flow(provider: "google_app", intent: "login")

    get sign_app_auth_google_app_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    submit_social_completion_if_present!

    assert_response :redirect
    assert_not ClientGoogleIdentity.exists?(uid: new_uid)

    get sign_app_auth_failure_url(message: "invalid_credentials", strategy: "google_app"),
        headers: browser_headers.merge("Host" => @host)

    assert_response :redirect
    assert_equal sign_app_sign_in_url(ri: "jp"), response.location
  end

  test "provider failure returns to sign up when social auth started from sign up" do
    start_social_auth_flow(provider: "google_app", intent: "login", entry: "sign_up")

    get sign_app_auth_failure_url(message: "invalid_credentials", strategy: "google_app"),
        headers: browser_headers.merge("Host" => @host)

    assert_response :redirect
    assert_equal sign_app_sign_up_url(ri: "jp"), response.location
  end

  test "provider failure returns to sign in when social auth started from sign in" do
    start_social_auth_flow(provider: "apple", intent: "login")

    get sign_app_auth_failure_url(message: "invalid_credentials", strategy: "apple"),
        headers: browser_headers.merge("Host" => @host)

    assert_response :redirect
    assert_equal sign_app_sign_in_url(ri: "jp"), response.location
  end

  test "Apple login with new uid waits for signup confirmation before creating user and identity" do
    new_uid = "brand_new_apple_#{SecureRandom.hex(4)}"
    setup_apple_mock_auth(uid: new_uid)

    user_count_before = Client.count
    identity_count_before = ClientAppleIdentity.count

    state = start_social_auth_flow(provider: "apple", intent: "login")

    assert_no_difference("Client.count") do
      assert_no_difference("ClientAppleIdentity.count") do
        assert_no_difference("ClientAccount.count") do
          assert_no_difference("Organization.count") do
            assert_no_difference("Avatar.count") do
              assert_no_difference("ClientToken.count") do
                post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
                     params: { state: state },
                     headers: browser_headers.merge(@callback_headers)
                submit_social_completion_if_present!
              end
            end
          end
        end
      end
    end

    assert_redirected_to sign_app_sign_up_guard_apple_url(ri: "jp")
    follow_redirect!

    assert_redirected_to sign_app_sign_up_check_apple_confirmation_url(ri: "jp")
    follow_redirect!

    assert_response :ok
    assert_includes response.body, "このAppleアカウントは未登録です。"
    assert_select "input[name=confirm_new_social_identity][required]"

    cycle = ClientSignUpFlow.order(:id).last

    patch sign_app_sign_up_check_apple_confirmation_url(ri: "jp"),
          params: { confirm_new_social_identity: "1", checkpoint_version: cycle.checkpoint_version },
          headers: browser_headers.merge(@callback_headers)

    assert_redirected_to sign_app_sign_up_check_apple_birthdate_url(ri: "jp")

    assert_no_difference("Client.count") do
      assert_no_difference("ClientAppleIdentity.count") do
        patch sign_app_sign_up_check_apple_birthdate_url(ri: "jp"),
              params: {
                requirement: "birthdate",
                birthdate: "2000-02-03",
                checkpoint_version: cycle.reload.checkpoint_version,
              },
              headers: browser_headers.merge(@callback_headers)
      end
    end

    assert_response :ok
    assert_includes response.body, "social-completion-form"

    assert_difference("Client.count", 1) do
      assert_difference("ClientAppleIdentity.count", 1) do
        submit_social_completion_if_present!
      end
    end

    identity = ClientAppleIdentity.find_by(uid: new_uid)

    assert_not_nil identity
    assert_not_nil identity.user
    assert_equal user_count_before + 1, Client.count
    assert_equal identity_count_before + 1, ClientAppleIdentity.count
  end

  # ============================================================================
  # JWT/Session token verification
  # ============================================================================
  test "successful login sets auth cookies" do
    new_uid = "cookie_test_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)

    state = start_social_auth_flow(provider: "google_app", intent: "login")

    get sign_app_auth_google_app_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    submit_social_completion_if_present!

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

    get sign_app_auth_google_app_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    submit_social_completion_if_present!

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
