# typed: false
# frozen_string_literal: true

require "test_helper"

# Integration tests for auto-link when user is already logged in
# IMPORTANT: These tests verify that when a logged-in user completes OAuth callback,
# the social identity is automatically linked to current_user (NOT creating a new user)
class SocialAuthAutoLinkTest < ActionDispatch::IntegrationTest
  fixtures :user_statuses, :user_social_google_statuses, :user_social_apple_statuses

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @callback_headers = SocialCallbackTestHelper.callback_headers(@host)
  end

  teardown do
    OmniAuth.config.mock_auth[:google_app] = nil
    OmniAuth.config.mock_auth[:apple] = nil
  end

  # ============================================================================
  # a) Logged-in link success
  # ============================================================================
  test "logged-in user: Apple callback automatically links UserSocialApple" do
    # Create and login as user
    user = User.create!(status_id: UserStatus::ACTIVE, public_id: "user_#{SecureRandom.hex(4)}")
    UserToken.create!(user: user, user_token_kind_id: UserTokenKind::BROWSER_WEB)

    # Mock Apple auth (NO email)
    apple_uid = "apple_auto_link_#{SecureRandom.hex(4)}"
    setup_apple_mock_auth(uid: apple_uid)

    # Before: no UserSocialApple exists
    assert_equal 0, user.reload.user_social_apple ? 1 : 0

    # Simulate Apple callback as logged-in user
    get sign_app_social_start_url(provider: "apple", intent: "link", ri: "jp"),
        headers: @callback_headers.merge(as_user_headers(user, host: @host))
    get sign_app_auth_callback_url(provider: "apple", ri: "jp"),
        headers: @callback_headers.merge(as_user_headers(user, host: @host))

    # Should redirect to success path (configuration page)
    assert_response :redirect
    assert_redirected_to sign_app_configuration_url(ri: "jp")
    follow_redirect!

    # Should show link success message
    assert_match(/Apple/, flash[:notice])

    # CRITICAL: UserSocialApple should be created and linked to current_user
    user.reload

    assert_not_nil user.user_social_apple, "UserSocialApple should be linked to user"
    assert_equal apple_uid, user.user_social_apple.uid
    assert_equal "apple", user.user_social_apple.provider

    # Verify NO email was saved (if email column exists)
    if user.user_social_apple.respond_to?(:email)
      assert_nil user.user_social_apple.email
    end

    # Verify NO new User was created (should still be 1)
    assert_equal 1, User.where(id: user.id).count
  end

  test "logged-in user: Google callback automatically links UserSocialGoogle" do
    # Create and login as user
    user = User.create!(status_id: UserStatus::ACTIVE, public_id: "user_#{SecureRandom.hex(4)}")
    UserToken.create!(user: user, user_token_kind_id: UserTokenKind::BROWSER_WEB)

    # Mock Google auth (NO email)
    google_uid = "google_auto_link_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: google_uid)

    # Before: no UserSocialGoogle exists
    assert_nil user.reload.user_social_google

    # Simulate Google callback as logged-in user
    get sign_app_social_start_url(provider: "google_app", intent: "link", ri: "jp"),
        headers: @callback_headers.merge(as_user_headers(user, host: @host))
    get sign_app_auth_callback_url(provider: "google_app", ri: "jp"),
        headers: @callback_headers.merge(as_user_headers(user, host: @host))

    # Should redirect to success path
    assert_response :redirect
    follow_redirect!

    # CRITICAL: UserSocialGoogle should be created and linked to current_user
    user.reload

    assert_not_nil user.user_social_google, "UserSocialGoogle should be linked to user"
    assert_equal google_uid, user.user_social_google.uid
  end

  # ============================================================================
  # b) Idempotent (no increase on double call)
  # ============================================================================
  test "idempotent: calling Apple callback twice does not create duplicate" do
    user = User.create!(status_id: UserStatus::ACTIVE, public_id: "user_#{SecureRandom.hex(4)}")
    UserToken.create!(user: user, user_token_kind_id: UserTokenKind::BROWSER_WEB)

    apple_uid = "apple_idempotent_#{SecureRandom.hex(4)}"
    setup_apple_mock_auth(uid: apple_uid)

    # First callback
    get sign_app_social_start_url(provider: "apple", intent: "link", ri: "jp"),
        headers: @callback_headers.merge(as_user_headers(user, host: @host))
    get sign_app_auth_callback_url(provider: "apple", ri: "jp"),
        headers: @callback_headers.merge(as_user_headers(user, host: @host))

    assert_response :redirect

    user.reload
    first_identity = user.user_social_apple

    assert_not_nil first_identity
    first_identity_id = first_identity.id

    # Second callback with SAME uid and SAME user
    setup_apple_mock_auth(uid: apple_uid)
    get sign_app_social_start_url(provider: "apple", intent: "link", ri: "jp"),
        headers: @callback_headers.merge(as_user_headers(user, host: @host))
    get sign_app_auth_callback_url(provider: "apple", ri: "jp"),
        headers: @callback_headers.merge(as_user_headers(user, host: @host))

    assert_response :redirect

    # Should NOT create a new UserSocialApple
    user.reload

    assert_equal first_identity_id, user.user_social_apple.id, "Should reuse existing identity"

    # Total count should still be 1
    assert_equal 1, UserSocialApple.where(uid: apple_uid).count
  end

  # ============================================================================
  # c) Conflict
  # ============================================================================
  test "conflict: Apple uid already linked to different user raises error" do
    # Create userA and link Apple identity
    user_a = User.create!(status_id: UserStatus::ACTIVE, public_id: "userA_#{SecureRandom.hex(4)}")
    apple_uid = "apple_conflict_#{SecureRandom.hex(4)}"
    UserSocialApple.create!(
      user: user_a,
      uid: apple_uid,
      provider: "apple",
      token: "token_a",
      expires_at: 1.week.from_now.to_i,
      user_social_apple_status: user_social_apple_statuses(:active),
    )

    # Create userB and try to link SAME Apple uid
    user_b = User.create!(status_id: UserStatus::ACTIVE, public_id: "userB_#{SecureRandom.hex(4)}")
    UserToken.create!(user: user_b, user_token_kind_id: UserTokenKind::BROWSER_WEB)

    setup_apple_mock_auth(uid: apple_uid)

    # Callback as userB should fail with conflict
    get sign_app_social_start_url(provider: "apple", intent: "link", ri: "jp"),
        headers: @callback_headers.merge(as_user_headers(user_b, host: @host))
    get sign_app_auth_callback_url(provider: "apple", ri: "jp"),
        headers: @callback_headers.merge(as_user_headers(user_b, host: @host))

    # Should redirect with alert (conflict)
    assert_response :redirect
    assert_match(/conflict|linked|already|別のユーザー/i, flash[:alert] || "") if flash[:alert]

    # userB should NOT have UserSocialApple
    user_b.reload

    assert_nil user_b.user_social_apple, "userB should NOT have Apple identity"

    # userA should still have the identity
    user_a.reload

    assert_equal apple_uid, user_a.user_social_apple.uid
  end

  test "not logged in: Apple callback creates new user (login flow, not link)" do
    apple_uid = "apple_new_user_#{SecureRandom.hex(4)}"
    setup_apple_mock_auth(uid: apple_uid)

    user_count_before = User.count

    # Start OAuth flow to set up session state (required by SocialCallbackGuard)
    get sign_app_social_start_url(provider: "apple", intent: "login", ri: "jp"),
        headers: browser_headers.merge(@callback_headers)

    # Callback without login (no headers)
    get sign_app_auth_callback_url(provider: "apple", ri: "jp"),
        headers: browser_headers.merge(@callback_headers)

    assert_response :redirect

    # Should create NEW user (login flow)
    assert_equal user_count_before + 1, User.count

    # UserSocialApple should exist
    identity = UserSocialApple.find_by(uid: apple_uid)

    assert_not_nil identity
    assert_not_nil identity.user
  end

  private

  # IMPORTANT: Social login uses provider+uid ONLY, NOT email
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
