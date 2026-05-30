# typed: false
# frozen_string_literal: true

require "test_helper"

class AppleAuthTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses, :client_apple_identity_statuses

  setup do
    OmniAuth.config.test_mode = true
    CloudflareTurnstile.test_mode = true
    @host = ENV.fetch("SIGN_SERVICE_URL", "id.umaxica.app")
    @callback_headers = social_callback_headers(@host)
  end

  teardown do
    OmniAuth.config.mock_auth[:apple] = nil
  end

  test "should create new user with unverified status on first login" do
    # IMPORTANT: Social login uses provider+uid ONLY, NOT email
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      {
        provider: "apple",
        uid: "apple_uid_new",
        info: {},
        credentials: {
          token: "apple_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    prepare_social_login(provider: "apple")

    post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp", state: @social_state),
         headers: browser_headers.merge(@callback_headers)

    assert_redirected_to sign_app_up_guardrail_url(ri: "jp")
    follow_redirect!

    user = ClientAppleIdentity.find_by(uid: "apple_uid_new").user

    assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, user.status_id
    assert_nil ClientEmail.find_by(user: user)
  end

  test "callback initializes preference timezone options when missing" do
    ComSettingRecord.connected_to(role: :writing) do
      AppPreferenceTimezone.delete_all
      AppPreferenceRegion.delete_all
      AppPreferenceLanguage.delete_all
      AppPreferenceTheme.delete_all
      AppPreferenceCookie.delete_all
      AppPreference.delete_all
      AppPreferenceTimezoneOption.delete_all
      AppPreferenceRegionOption.delete_all
      AppPreferenceLanguageOption.delete_all
      AppPreferenceThemeOption.delete_all
    end

    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      {
        provider: "apple",
        uid: "apple_uid_pref_#{SecureRandom.hex(4)}",
        info: {},
        credentials: {
          token: "apple_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    prepare_social_login(provider: "apple")

    post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp", state: @social_state),
         headers: browser_headers.merge(@callback_headers)

    assert_redirected_to sign_app_up_guardrail_url(ri: "jp")

    ComSettingRecord.connected_to(role: :writing) do
      assert AppPreferenceTimezoneOption.exists?(id: AppPreferenceTimezoneOption::ASIA_TOKYO)
      assert_predicate AppPreferenceTimezone, :exists?
    end
  end

  test "should sign in existing user normally" do
    user = Client.create!(status_id: ClientStatus::ACTIVE)
    ClientAppleIdentity.create!(
      user: user,
      uid: "apple_uid_existing",
      provider: "apple",
      token: "existing_token",
      token_expires_at: 1.week.from_now.to_i,
    )

    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      {
        provider: "apple",
        uid: "apple_uid_existing",
        info: {},
        credentials: {
          token: "new_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    prepare_social_login(provider: "apple")

    post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp", state: @social_state),
         headers: browser_headers.merge(@callback_headers)

    assert_redirected_to sign_app_up_guardrail_url(ri: "jp")

    assert_equal "Appleで登録を開始しました", flash[:notice]
  end

  # ============================================================================
  # Regression tests: Email-less social login
  # IMPORTANT: These tests verify that social login works WITHOUT email
  # ============================================================================

  test "Apple login without email in auth hash creates user successfully" do
    # Requirement: Social login MUST work with provider+uid ONLY, NO email
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      {
        provider: "apple",
        uid: "apple_uid_no_email_#{SecureRandom.hex(4)}",
        info: {}, # Deliberately empty - no email provided
        credentials: {
          token: "apple_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    prepare_social_login(provider: "apple")

    uid = OmniAuth.config.mock_auth[:apple].uid

    # Should create user and identity
    assert_difference("Client.count", 1) do
      assert_difference("ClientAppleIdentity.count", 1) do
        post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp", state: @social_state),
             headers: browser_headers.merge(@callback_headers)
      end
    end

    # Should redirect to success path, NOT /in/new (email registration)
    assert_redirected_to sign_app_up_guardrail_url(ri: "jp")
    follow_redirect!

    assert_predicate flash[:notice], :present?, "Should have success message"

    # Verify user and identity were created
    identity = ClientAppleIdentity.find_by(uid: uid)

    assert_not_nil identity, "ClientAppleIdentity identity should exist"
    assert_not_nil identity.user, "Client should be associated with identity"

    # CRITICAL: Verify NO email was saved
    user = identity.user

    assert_nil ClientEmail.find_by(user: user), "NO ClientEmail should exist for social login user"
  end

  test "Apple login without email does NOT save email to ClientAppleIdentity" do
    # Even though ClientAppleIdentity schema may have an email column (legacy),
    # we MUST NOT write to it during social login
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      {
        provider: "apple",
        uid: "apple_uid_verify_no_email_#{SecureRandom.hex(4)}",
        info: {}, # No email in auth hash
        credentials: {
          token: "apple_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    prepare_social_login(provider: "apple")

    uid = OmniAuth.config.mock_auth[:apple].uid

    post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp", state: @social_state),
         headers: browser_headers.merge(@callback_headers)

    assert_response :redirect

    identity = ClientAppleIdentity.find_by(uid: uid)

    assert_not_nil identity

    # Verify email column is NOT populated (if it exists in schema)
    # This ensures we don't accidentally write email even if the column exists
    if identity.respond_to?(:email)
      assert_nil identity.email, "ClientAppleIdentity.email should be nil"
    end
  end

  test "Google login without email creates user successfully" do
    # Same requirement applies to Google
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_app] = OmniAuth::AuthHash.new(
      {
        provider: "google_app",
        uid: "google_uid_no_email_#{SecureRandom.hex(4)}",
        info: { image: "https://example.com/image.jpg" }, # No email
        credentials: {
          token: "google_token",
          refresh_token: "refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    prepare_social_login(provider: "google_app")

    uid = OmniAuth.config.mock_auth[:google_app].uid

    assert_difference("Client.count", 1) do
      assert_difference("ClientGoogleIdentity.count", 1) do
        get sign_app_auth_callback_url(provider: "google_app", ri: "jp", state: @social_state),
            headers: browser_headers.merge(@callback_headers)
      end
    end

    assert_redirected_to sign_app_up_guardrail_url(ri: "jp")

    identity = ClientGoogleIdentity.find_by(uid: uid)

    assert_not_nil identity
    assert_nil ClientEmail.find_by(user: identity.user), "NO ClientEmail for Google login user"

    # Verify email column is NOT populated
    if identity.respond_to?(:email)
      assert_nil identity.email, "ClientGoogleIdentity.email should be nil"
    end
  end

  private

  def prepare_social_login(provider:)
    @social_state = seed_social_auth_session(provider: provider, intent: "login", ri: "jp")
  end
end
