# typed: false
# frozen_string_literal: true

require "test_helper"

class OmniauthCallbacksTest < ActionDispatch::IntegrationTest
  fixtures_only :client_google_identity_statuses, :client_apple_identity_statuses, :client_statuses,
                :client_totp_credential_statuses

  setup do
    OmniAuth.config.test_mode = true
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
    @host = ENV.fetch("SIGN_SERVICE_URL", "id.umaxica.app")
    host! @host
    @expected_redirect = %r{\Ahttps?://#{Regexp.escape(@host)}/.*}.freeze
  end

  teardown do
    OmniAuth.config.mock_auth[:google_app] = nil
    OmniAuth.config.mock_auth[:apple] = nil
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
    ClientTokenBindingMethod.ensure_defaults!
    ClientTokenDbscStatus.ensure_defaults!
    ClientTokenKind.ensure_defaults!
    ClientTokenStatus.ensure_defaults!
  end

  test "unknown Google identity enters sign up checkpoint instead of signing in" do
    # IMPORTANT: Social login uses provider+uid ONLY, NOT email
    OmniAuth.config.mock_auth[:google_app] = OmniAuth::AuthHash.new(
      {
        provider: "google_app",
        uid: "123456789",
        info: {
          image: "http://example.com/image.jpg",
        },
        credentials: {
          token: "token",
          refresh_token: "refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    state = start_social_auth_flow(provider: "google_app")

    assert_no_difference("Client.count") do
      assert_no_difference("ClientGoogleIdentity.count") do
        get sign_app_auth_google_app_callback_url(ri: "jp"),
            params: { state: state },
            headers: social_callback_headers(@host)
      end
    end

    assert_redirected_to sign_app_sign_up_guard_google_url(ri: "jp")
    follow_redirect!

    assert_redirected_to sign_app_sign_up_check_google_confirmation_url(ri: "jp")
    follow_redirect!

    assert_select "input[name=confirm_new_social_identity][required]"
  end

  test "google callback without region parameter is processed without regional redirect" do
    OmniAuth.config.mock_auth[:google_app] = OmniAuth::AuthHash.new(
      {
        provider: "google_app",
        uid: "google_no_region_#{SecureRandom.hex(4)}",
        info: {},
        credentials: {
          token: "token",
          refresh_token: "refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    state = start_social_auth_flow(provider: "google_app")

    get sign_app_auth_google_app_callback_url,
        params: { state: state },
        headers: social_callback_headers(@host)

    assert_response :redirect
    assert_not_includes response.location, "code="
  end

  test "unknown Apple identity enters sign up checkpoint instead of signing in" do
    # IMPORTANT: Social login uses provider+uid ONLY, NOT email
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      {
        provider: "apple",
        uid: "apple_uid_123",
        info: {},
        credentials: {
          token: "apple_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    state = start_social_auth_flow(provider: "apple")

    assert_no_difference("Client.count") do
      assert_no_difference("ClientAppleIdentity.count") do
        post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
             params: { state: state },
             headers: social_callback_headers(@host)
      end
    end

    assert_redirected_to sign_app_sign_up_guard_apple_url(ri: "jp")
    follow_redirect!

    assert_redirected_to sign_app_sign_up_check_apple_confirmation_url(ri: "jp")
    follow_redirect!

    assert_select "input[name=confirm_new_social_identity][required]"
  end

  test "unknown Apple GET callback enters sign up checkpoint instead of signing in" do
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      {
        provider: "apple",
        uid: "apple_get_callback_uid",
        info: {},
        credentials: {
          token: "apple_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    state = start_social_auth_flow(provider: "apple")

    assert_no_difference("Client.count") do
      assert_no_difference("ClientAppleIdentity.count") do
        get sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
            params: { state: state },
            headers: social_callback_headers(@host)
      end
    end

    assert_redirected_to sign_app_sign_up_guard_apple_url(ri: "jp")
    follow_redirect!

    assert_redirected_to sign_app_sign_up_check_apple_confirmation_url(ri: "jp")
    follow_redirect!

    assert_select "input[name=confirm_new_social_identity][required]"
  end

  test "apple social login with MFA enabled does not require additional MFA challenge" do
    user = Client.create!(birthdate: "2000-02-03", mfa_level_enabled: true)
    ClientTotpCredential.create!(
      user: user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      title: "totp",
    )
    ClientAppleIdentity.create!(
      user: user,
      uid: "apple_mfa_skip_uid",
      provider: "apple",
      token: "existing_token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      {
        provider: "apple",
        uid: "apple_mfa_skip_uid",
        info: {},
        credentials: {
          token: "apple_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    state = start_social_auth_flow(provider: "apple")

    post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
         params: { state: state },
         headers: social_callback_headers(@host)

    # The sign callback must not establish an MFA challenge or sign-side session
    # for an established social login; it emits the acme completion form only.
    # The MFA / session decision belongs to acme completion.
    assert_emits_acme_completion_only!
    assert_no_match(%r{/sign/in/challenge}, response.body)
    assert_nil session[:pending_mfa]
  end

  test "should sign in with existing Google user" do
    user = Client.create!(birthdate: "2000-02-03")
    ClientGoogleIdentity.create!(
      user: user,
      uid: "existing_uid",
      provider: "google_app",
      token: "existing_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    OmniAuth.config.mock_auth[:google_app] = OmniAuth::AuthHash.new(
      {
        provider: "google_app",
        uid: "existing_uid",
        info: {
          image: "http://example.com/image.jpg",
        },
        credentials: {
          token: "new_token",
          refresh_token: "new_refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    state = start_social_auth_flow(provider: "google_app")

    get sign_app_auth_google_app_callback_url(ri: "jp"),
        params: { state: state },
        headers: social_callback_headers(@host)

    # Established social login is acme authority: the sign callback emits a
    # one-shot completion form (evidence only) and the session is established on
    # acme completion, which redirects to the acme dashboard.
    assert_emits_acme_completion_only!

    submit_social_completion_if_present!

    assert_redirected_to acme_app_dashboard_url(ri: "jp", host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"))
  end

  test "existing Google identity without birthdate stays on login side" do
    user = Client.create!
    ClientGoogleIdentity.create!(
      user: user,
      uid: "existing_missing_birthdate_uid",
      provider: "google_app",
      token: "existing_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    OmniAuth.config.mock_auth[:google_app] = OmniAuth::AuthHash.new(
      {
        provider: "google_app",
        uid: "existing_missing_birthdate_uid",
        info: {},
        credentials: {
          token: "new_token",
          refresh_token: "new_refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    state = start_social_auth_flow(provider: "google_app")

    get sign_app_auth_google_app_callback_url(ri: "jp"),
        params: { state: state },
        headers: social_callback_headers(@host)

    assert_redirected_to sign_app_sign_in_url(ri: "jp")
    assert_not ClientToken.exists?(user_id: user.id), "ClientToken must not be created before birthdate checkpoint"
  end

  test "social login with MFA enabled does not require additional MFA challenge" do
    user = Client.create!(birthdate: "2000-02-03")
    user.update!(mfa_level_enabled: true)
    ClientTotpCredential.create!(
      user: user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      title: "totp",
    )
    ClientGoogleIdentity.create!(
      user: user,
      uid: "totp_required_uid",
      provider: "google_app",
      token: "existing_token",
      refresh_token: "existing_refresh",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    OmniAuth.config.mock_auth[:google_app] = OmniAuth::AuthHash.new(
      {
        provider: "google_app",
        uid: "totp_required_uid",
        info: { image: "http://example.com/image.jpg" },
        credentials: {
          token: "new_token",
          refresh_token: "new_refresh",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    state = start_social_auth_flow(provider: "google_app")

    get sign_app_auth_google_app_callback_url(ri: "jp"),
        params: { state: state },
        headers: social_callback_headers(@host)

    # The sign callback must not establish an MFA challenge or sign-side session
    # for an established social login; it emits the acme completion form only.
    assert_emits_acme_completion_only!
    assert_no_match(%r{/sign/in/challenge}, response.body)
    assert_nil session[:pending_mfa]
  end

  test "google login with missing user_token_kind does not crash callback" do
    ClientToken.delete_all
    ClientTokenKind.delete_all

    OmniAuth.config.mock_auth[:google_app] = OmniAuth::AuthHash.new(
      {
        provider: "google_app",
        uid: "missing_kind_uid",
        info: {
          image: "http://example.com/image.jpg",
        },
        credentials: {
          token: "token",
          refresh_token: "refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    state = start_social_auth_flow(provider: "google_app")

    get sign_app_auth_google_app_callback_url(ri: "jp"),
        params: { state: state },
        headers: social_callback_headers(@host)

    assert_response :redirect
  end

  test "google login with session limit exceeded redirects to session management" do
    # Create an existing user with Google social identity
    user = Client.create!(birthdate: "2000-02-03")
    ClientGoogleIdentity.create!(
      user: user,
      uid: "session_limit_uid",
      provider: "google_app",
      token: "existing_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    # Create 2 active sessions to hit the limit
    ClientToken.where(user_id: user.id).delete_all
    2.times do
      create_rotated_active_user_session(user, rotations: 3)
    end

    OmniAuth.config.mock_auth[:google_app] = OmniAuth::AuthHash.new(
      {
        provider: "google_app",
        uid: "session_limit_uid",
        info: { image: "http://example.com/image.jpg" },
        credentials: {
          token: "new_token",
          refresh_token: "new_refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    sessions_before = ClientToken.where(user_id: user.id).count

    state = start_social_auth_flow(provider: "google_app")

    get sign_app_auth_google_app_callback_url(ri: "jp"),
        params: { state: state },
        headers: social_callback_headers(@host)

    # Session-limit enforcement belongs to acme completion. The sign callback
    # emits the completion form only and must not create or restrict a sign-side
    # session token of its own.
    assert_emits_acme_completion_only!

    assert_equal sessions_before, ClientToken.where(user_id: user.id).count,
                 "sign must not establish a session token for an established social login"
    restricted = ClientToken.where(user_id: user.id, user_token_status_id: ClientTokenStatus::RESTRICTED)

    assert_equal 0, restricted.count
  end

  private

  # Pin the sign-side authority boundary for established social login: the sign
  # callback returns the one-shot acme completion form (signed result only) and
  # does not perform a sign-side session/redirect itself.
  def assert_emits_acme_completion_only!
    assert_response :ok
    assert_includes response.body, "social-completion-form"
    assert_includes response.body, "social_ceremony_result"
  end

  def create_rotated_active_user_session(user, rotations:)
    token = ClientToken.create!(user: user, user_token_status_id: ClientTokenStatus::ACTIVE)
    refresh = token.rotate_refresh_token!

    rotations.times do
      refresh = SignRefreshTokenService.call(refresh_token: refresh)[:refresh_token]
    end
  end

  def start_social_auth_flow(provider:)
    seed_social_auth_session(provider: provider, intent: "login", ri: "jp")
  end
end
