# typed: false
# frozen_string_literal: true

require "test_helper"

class OmniauthCallbacksTest < ActionDispatch::IntegrationTest
  fixtures :user_social_google_statuses, :user_social_apple_statuses, :user_statuses,
           :user_one_time_password_statuses

  setup do
    OmniAuth.config.test_mode = true
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @expected_redirect = %r{\Ahttps?://#{Regexp.escape(@host)}/.*}.freeze
  end

  teardown do
    OmniAuth.config.mock_auth[:google_app] = nil
    OmniAuth.config.mock_auth[:apple] = nil
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "should sign in with Google" do
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

    get sign_app_auth_callback_url(provider: "google_app", ri: "jp"),
        headers: SocialCallbackTestHelper.callback_headers(@host)

    assert_redirected_to @expected_redirect
    follow_redirect!

    user = UserSocialGoogle.find_by(uid: "123456789").user

    assert_not_nil user
    assert UserToken.exists?(user_id: user.id), "UserToken should be created for Google login"
  end

  test "should sign in with Apple" do
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

    get sign_app_auth_callback_url(provider: "apple", ri: "jp"),
        headers: SocialCallbackTestHelper.callback_headers(@host)

    assert_redirected_to @expected_redirect
    follow_redirect!

    user = UserSocialApple.find_by(uid: "apple_uid_123").user

    assert_not_nil user
  end

  test "apple social login with MFA enabled does not require additional MFA challenge" do
    user = User.create!(multi_factor_enabled: true)
    UserOneTimePassword.create!(
      user: user,
      private_key: ROTP::Base32.random_base32,
      user_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE,
      title: "totp",
    )
    UserSocialApple.create!(
      user: user,
      uid: "apple_mfa_skip_uid",
      provider: "apple",
      token: "existing_token",
      expires_at: 1.week.from_now.to_i,
      user_social_apple_status: user_social_apple_statuses(:active),
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

    get sign_app_auth_callback_url(provider: "apple", ri: "jp"),
        headers: SocialCallbackTestHelper.callback_headers(@host)

    assert_response :redirect
    assert_match(%r{/configuration}, response.redirect_url)
    assert_nil session[:pending_mfa]
  end

  test "should sign in with existing Google user" do
    user = User.create!
    UserSocialGoogle.create!(
      user: user,
      uid: "existing_uid",
      provider: "google_app",
      token: "existing_token",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: user_social_google_statuses(:active),
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

    get sign_app_auth_callback_url(provider: "google_app", ri: "jp"),
        headers: SocialCallbackTestHelper.callback_headers(@host)

    assert_redirected_to @expected_redirect
    follow_redirect!

    provider_name = SocialIdentifiable.normalize_provider("google_app").humanize

    assert_equal I18n.t("sign.app.social.sessions.create.already_registered", provider: provider_name),
                 flash[:notice]
  end

  test "social login with MFA enabled does not require additional MFA challenge" do
    user = User.create!
    user.update!(multi_factor_enabled: true)
    UserOneTimePassword.create!(
      user: user,
      private_key: ROTP::Base32.random_base32,
      user_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE,
      title: "totp",
    )
    UserSocialGoogle.create!(
      user: user,
      uid: "totp_required_uid",
      provider: "google_app",
      token: "existing_token",
      refresh_token: "existing_refresh",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: user_social_google_statuses(:active),
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

    get sign_app_auth_callback_url(provider: "google_app", ri: "jp"),
        headers: SocialCallbackTestHelper.callback_headers(@host)

    assert_response :redirect
    assert_match(%r{/configuration}, response.redirect_url)
    assert_nil session[:pending_mfa]
  end

  test "google login with missing user_token_kind does not crash callback" do
    UserToken.delete_all
    UserTokenKind.delete_all

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

    get sign_app_auth_callback_url(provider: "google_app", ri: "jp"),
        headers: SocialCallbackTestHelper.callback_headers(@host)

    assert_response :redirect
  end

  test "google login with session limit exceeded redirects to session management" do
    # Create an existing user with Google social identity
    user = User.create!
    UserSocialGoogle.create!(
      user: user,
      uid: "session_limit_uid",
      provider: "google_app",
      token: "existing_token",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: user_social_google_statuses(:active),
    )

    # Create 2 active sessions to hit the limit
    UserToken.where(user_id: user.id).delete_all
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

    get sign_app_auth_callback_url(provider: "google_app", ri: "jp"),
        headers: SocialCallbackTestHelper.callback_headers(@host)

    assert_response :found
    assert_redirected_to sign_app_in_session_url(host: @host)
    assert_equal I18n.t("sign.app.in.session.restricted_notice"), flash[:notice]

    # A restricted token should have been created
    restricted = UserToken.where(user_id: user.id, status: UserToken::STATUS_RESTRICTED)

    assert_equal 1, restricted.count
  end

  private

  def create_rotated_active_user_session(user, rotations:)
    token = UserToken.create!(user: user, status: UserToken::STATUS_ACTIVE)
    refresh = token.rotate_refresh_token!

    rotations.times do
      refresh = Sign::RefreshTokenService.call(refresh_token: refresh)[:refresh_token]
    end
  end
end
