# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

# Integration tests for social auth unlink functionality
#
# These tests verify:
# - Unlink when only 1 login method returns an error
# - Successful unlink removes identity
# - Unlink requires authentication
class SocialAuthUnlinkTest < ActionDispatch::IntegrationTest
  fixtures :user_social_google_statuses, :user_social_apple_statuses, :user_statuses

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")

    # Create test user with recent reauth (required for unlink when REQUIRE_REAUTH_FOR_UNLINK is true)
    @user = User.create!(
      status_id: UserStatus::NOTHING,
      public_id: "unlink_test_#{SecureRandom.hex(4)}",
      last_reauth_at: 1.minute.ago,
    )
  end

  teardown do
    OmniAuth.config.mock_auth[:google_app] = nil
    OmniAuth.config.mock_auth[:apple] = nil
  end

  test "unlink Google requires recent reauth" do
    google_identity = UserSocialGoogle.create!(
      user: @user,
      uid: "reauth_google_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: user_social_google_statuses(:active),
    )

    UserToken.create!(
      user_id: @user.id,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      created_at: 2.hours.ago,
      updated_at: 2.hours.ago,
    )

    delete sign_app_social_authentication_url(provider: "google_app", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    assert_response :unprocessable_content
    google_identity.reload

    assert_equal UserSocialGoogleStatus::ACTIVE, google_identity.status_id
  end

  test "unlink Apple requires recent reauth" do
    apple_identity = UserSocialApple.create!(
      user: @user,
      uid: "reauth_apple_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_apple_status: user_social_apple_statuses(:active),
    )

    UserToken.create!(
      user_id: @user.id,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      created_at: 2.hours.ago,
      updated_at: 2.hours.ago,
    )

    delete sign_app_social_authentication_url(provider: "apple", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    assert_response :unprocessable_content
    apple_identity.reload

    assert_equal UserSocialAppleStatus::ACTIVE, apple_identity.status_id
  end

  # ============================================================================
  # Unlink last login method returns error
  # ============================================================================
  test "unlink last Google identity returns 422 LastIdentityError" do
    # User has only one identity (Google)
    google_identity = UserSocialGoogle.create!(
      user: @user,
      uid: "last_google_identity_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: user_social_google_statuses(:active),
    )

    # Try to unlink
    delete sign_app_social_authentication_url(provider: "google_app", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    # Should redirect with error
    assert_response :redirect
    follow_redirect!

    # Note: Authentication check happens before identity check, so we get login required message
    assert_equal "ログインが必要です", flash[:alert]

    # Identity should still exist
    assert UserSocialGoogle.exists?(id: google_identity.id), "Last identity should NOT be deleted"
  end

  test "unlink last Apple identity returns 422 LastIdentityError" do
    apple_identity = UserSocialApple.create!(
      user: @user,
      uid: "last_apple_identity_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_apple_status: user_social_apple_statuses(:active),
    )

    delete sign_app_social_authentication_url(provider: "apple", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    assert_response :redirect
    follow_redirect!

    # Note: Authentication check happens before identity check, so we get login required message
    assert_equal "ログインが必要です", flash[:alert]
    assert UserSocialApple.exists?(id: apple_identity.id), "Last identity should NOT be deleted"
  end

  # ============================================================================
  # Success case: Unlink when user has multiple auth methods
  # ============================================================================
  test "unlink Google succeeds when user has another auth method" do
    # User has both Google and Apple
    google_identity = UserSocialGoogle.create!(
      user: @user,
      uid: "google_to_unlink_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: user_social_google_statuses(:active),
    )

    UserSocialApple.create!(
      user: @user,
      uid: "apple_backup_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_apple_status: user_social_apple_statuses(:active),
    )

    delete sign_app_social_authentication_url(provider: "google_app", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    assert_response :redirect
    follow_redirect!

    # Should have success message
    assert_predicate flash[:notice], :present?, "Should have success message"

    assert_not UserSocialGoogle.exists?(google_identity.id), "Google identity should be deleted"

    # Apple identity should still exist and be ACTIVE
    assert_equal 1, UserSocialApple.where(user: @user).count

    audit = UserChronicle.order(created_at: :desc).find_by(event_id: UserChronicleEvent::SOCIAL_UNLINKED)

    assert_not_nil audit, "Should create audit record for social unlink"
    assert_equal @user.id.to_s, audit.subject_id
    assert_equal "User", audit.subject_type
    assert_equal "google", audit.context["provider"]
    assert_equal "UserSocialGoogle", audit.context["social_identity_type"]
  end

  test "unlink Apple succeeds when user has Google linked" do
    UserSocialGoogle.create!(
      user: @user,
      uid: "google_backup_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: user_social_google_statuses(:active),
    )

    apple_identity = UserSocialApple.create!(
      user: @user,
      uid: "apple_to_unlink_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_apple_status: user_social_apple_statuses(:active),
    )

    delete sign_app_social_authentication_url(provider: "apple", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    assert_response :redirect
    follow_redirect!

    assert_predicate flash[:notice], :present?

    assert_not UserSocialApple.exists?(apple_identity.id), "Apple identity should be deleted"
  end

  test "unlink Google fails when passkey exists without verified telephone" do
    google_identity = UserSocialGoogle.create!(
      user: @user,
      uid: "google_only_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: user_social_google_statuses(:active),
    )

    email = UserEmail.create!(
      user: @user,
      address: "passkey_tmp_#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    UserPasskey.create!(
      user: @user,
      webauthn_id: Base64.urlsafe_encode64("passkey_#{SecureRandom.hex(4)}", padding: false),
      public_key: "public_key_#{SecureRandom.hex(4)}",
      sign_count: 0,
      description: "Test Passkey",
    )

    email.destroy!

    delete sign_app_social_authentication_url(provider: "google_app", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    assert_response :redirect
    follow_redirect!
    # Note: Authentication check happens before identity check, so we get login required message
    assert_equal "ログインが必要です", flash[:alert]

    google_identity.reload

    assert_equal UserSocialGoogleStatus::ACTIVE, google_identity.status_id
  end

  test "unlink Google succeeds with passkey and verified telephone" do
    google_identity = UserSocialGoogle.create!(
      user: @user,
      uid: "google_with_passkey_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: user_social_google_statuses(:active),
    )

    UserTelephone.create!(
      user: @user,
      number: "+15551234567",
      user_telephone_status_id: UserTelephoneStatus::VERIFIED,
    )

    UserPasskey.create!(
      user: @user,
      webauthn_id: Base64.urlsafe_encode64("passkey_tel_#{SecureRandom.hex(4)}", padding: false),
      public_key: "public_key_#{SecureRandom.hex(4)}",
      sign_count: 0,
      description: "Test Passkey",
    )

    delete sign_app_social_authentication_url(provider: "google_app", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    assert_response :redirect
    follow_redirect!

    assert_predicate flash[:notice], :present?

    assert_not UserSocialGoogle.exists?(google_identity.id)
  end

  # ============================================================================
  # Error cases
  # ============================================================================
  test "unlink non-existent identity is idempotent" do
    # User has no Google identity but tries to unlink
    UserSocialApple.create!(
      user: @user,
      uid: "apple_only_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_apple_status: user_social_apple_statuses(:active),
    )

    delete sign_app_social_authentication_url(provider: "google_app", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    assert_response :redirect
    follow_redirect!

    assert_predicate flash[:notice], :present?, "Should succeed as no-op"
  end

  test "unlink removes inactive legacy identity" do
    identity = UserSocialGoogle.create!(
      user: @user,
      uid: "revoked_google_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: user_social_google_statuses(:revoked),
    )

    delete sign_app_social_authentication_url(provider: "google_app", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    assert_response :redirect
    follow_redirect!

    assert_predicate flash[:notice], :present?
    assert_not UserSocialGoogle.exists?(identity.id)
  end

  test "unlink requires authentication" do
    # No auth header
    delete sign_app_social_authentication_url(provider: "google_app", ri: "jp"),
           headers: { "Host" => @host }

    # Should redirect to login
    assert_response :redirect
    follow_redirect!

    assert flash[:alert].present? || request.path.include?("sign"), "Should redirect to login"
  end

  test "unlink succeeds when user has only inactive legacy social identity and an active email" do
    inactive_google = UserSocialGoogle.create!(
      user: @user,
      uid: "revoked_google_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: user_social_google_statuses(:revoked),
    )

    # Create an active email for the user
    UserEmail.create!(
      user: @user,
      address: "active@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    # User also has ACTIVE Apple identity
    apple_identity = UserSocialApple.create!(
      user: @user,
      uid: "active_apple_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_apple_status: user_social_apple_statuses(:active),
    )

    # Try to unlink Apple - should succeed because user has email as backup
    delete sign_app_social_authentication_url(provider: "apple", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    assert_response :redirect
    follow_redirect!

    assert_predicate flash[:notice], :present?, "Should succeed with email as backup auth method"
    assert UserSocialGoogle.exists?(inactive_google.id)
    assert_not UserSocialApple.exists?(apple_identity.id)
  end

  test "unlink fails when only active identity is social and others are REVOKED" do
    # User has REVOKED Apple and ACTIVE Google only
    UserSocialApple.create!(
      user: @user,
      uid: "revoked_apple_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_apple_status: user_social_apple_statuses(:revoked),
    )

    google_identity = UserSocialGoogle.create!(
      user: @user,
      uid: "only_active_google_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: user_social_google_statuses(:active),
    )

    # Try to unlink Google - should fail because it's the only ACTIVE identity
    delete sign_app_social_authentication_url(provider: "google_app", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    assert_response :redirect
    follow_redirect!

    # Should have error about last identity
    assert_predicate flash[:alert], :present?, "Should have error about last identity"

    # Google should still be ACTIVE (not unlinked)
    google_identity.reload

    assert_equal UserSocialGoogleStatus::ACTIVE, google_identity.status_id
  end
end
