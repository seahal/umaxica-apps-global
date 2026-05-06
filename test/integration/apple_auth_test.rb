# typed: false
# frozen_string_literal: true

require "test_helper"

class AppleAuthTest < ActionDispatch::IntegrationTest
  fixtures :user_statuses, :user_social_apple_statuses

  setup do
    OmniAuth.config.test_mode = true
    CloudflareTurnstile.test_mode = true
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @callback_headers = SocialCallbackTestHelper.callback_headers(@host)
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

    get sign_app_auth_callback_url(provider: "apple", ri: "jp"),
        headers: browser_headers.merge(@callback_headers)

    assert_redirected_to sign_app_configuration_url(ri: "jp")
    follow_redirect!

    user = UserSocialApple.find_by(uid: "apple_uid_new").user

    assert_equal UserStatus::UNVERIFIED_WITH_SIGN_UP, user.status_id
    assert_nil UserEmail.find_by(user: user)
  end

  test "callback initializes preference timezone options when missing" do
    SettingRecord.connected_to(role: :writing) do
      AppPreferenceTimezone.delete_all
      AppPreferenceRegion.delete_all
      AppPreferenceLanguage.delete_all
      AppPreferenceColortheme.delete_all
      AppPreferenceCookie.delete_all
      AppPreference.delete_all
      AppPreferenceTimezoneOption.delete_all
      AppPreferenceRegionOption.delete_all
      AppPreferenceLanguageOption.delete_all
      AppPreferenceColorthemeOption.delete_all
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

    get sign_app_auth_callback_url(provider: "apple", ri: "jp"),
        headers: browser_headers.merge(@callback_headers)

    assert_redirected_to sign_app_configuration_url(ri: "jp")

    SettingRecord.connected_to(role: :writing) do
      assert AppPreferenceTimezoneOption.exists?(id: AppPreferenceTimezoneOption::ASIA_TOKYO)
      assert_predicate AppPreferenceTimezone, :exists?
    end
  end

  test "should sign in existing user normally" do
    user = User.create!(status_id: UserStatus::ACTIVE)
    UserSocialApple.create!(
      user: user,
      uid: "apple_uid_existing",
      provider: "apple",
      token: "existing_token",
      expires_at: 1.week.from_now.to_i,
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

    get sign_app_auth_callback_url(provider: "apple", ri: "jp"),
        headers: browser_headers.merge(@callback_headers)

    assert_redirected_to sign_app_configuration_url(ri: "jp")

    assert_equal I18n.t("sign.app.social.sessions.create.already_registered", provider: "Apple"),
                 flash[:notice]
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

    uid = OmniAuth.config.mock_auth[:apple].uid

    # Should create user and identity
    assert_difference("User.count", 1) do
      assert_difference("UserSocialApple.count", 1) do
        get sign_app_auth_callback_url(provider: "apple", ri: "jp"),
            headers: browser_headers.merge(@callback_headers)
      end
    end

    # Should redirect to success path, NOT /in/new (email registration)
    assert_redirected_to sign_app_configuration_url(ri: "jp")
    follow_redirect!

    assert_predicate flash[:notice], :present?, "Should have success message"

    # Verify user and identity were created
    identity = UserSocialApple.find_by(uid: uid)

    assert_not_nil identity, "UserSocialApple identity should exist"
    assert_not_nil identity.user, "User should be associated with identity"

    # CRITICAL: Verify NO email was saved
    user = identity.user

    assert_nil UserEmail.find_by(user: user), "NO UserEmail should exist for social login user"
  end

  test "Apple login without email does NOT save email to UserSocialApple" do
    # Even though UserSocialApple schema may have an email column (legacy),
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

    uid = OmniAuth.config.mock_auth[:apple].uid

    get sign_app_auth_callback_url(provider: "apple", ri: "jp"),
        headers: browser_headers.merge(@callback_headers)

    assert_response :redirect

    identity = UserSocialApple.find_by(uid: uid)

    assert_not_nil identity

    # Verify email column is NOT populated (if it exists in schema)
    # This ensures we don't accidentally write email even if the column exists
    if identity.respond_to?(:email)
      assert_nil identity.email, "UserSocialApple.email should be nil"
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

    uid = OmniAuth.config.mock_auth[:google_app].uid

    assert_difference("User.count", 1) do
      assert_difference("UserSocialGoogle.count", 1) do
        get sign_app_auth_callback_url(provider: "google_app", ri: "jp"),
            headers: browser_headers.merge(@callback_headers)
      end
    end

    assert_redirected_to sign_app_configuration_url(ri: "jp")

    identity = UserSocialGoogle.find_by(uid: uid)

    assert_not_nil identity
    assert_nil UserEmail.find_by(user: identity.user), "NO UserEmail for Google login user"

    # Verify email column is NOT populated
    if identity.respond_to?(:email)
      assert_nil identity.email, "UserSocialGoogle.email should be nil"
    end
  end
end
