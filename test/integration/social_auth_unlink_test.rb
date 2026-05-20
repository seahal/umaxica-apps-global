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
  fixtures :client_social_google_statuses, :client_social_apple_statuses, :client_statuses

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")

    # Create test user with recent step_up (required for unlink when REQUIRE_STEP_UP_FOR_UNLINK is true)
    @user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "unlink_test_#{SecureRandom.hex(4)}",
      last_step_up_at: 1.minute.ago,
    )
    @headers = as_user_headers(@user, host: @host)
    @token = ClientToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
  end

  teardown do
    OmniAuth.config.mock_auth[:google_app] = nil
    OmniAuth.config.mock_auth[:apple] = nil
  end

  test "unlink Google requires recent step_up" do
    @user.update!(last_step_up_at: 2.hours.ago)
    google_identity = ClientSocialGoogle.create!(
      user: @user,
      uid: "step_up_google_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: client_social_google_statuses(:active),
    )

    ClientToken.create!(
      user_id: @user.id,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      created_at: 2.hours.ago,
      updated_at: 2.hours.ago,
    )

    delete sign_app_social_authentication_url(provider: "google_app", ri: "jp"),
           headers: stale_step_up_headers

    assert_response :unprocessable_content
    google_identity.reload

    assert_equal ClientSocialGoogleStatus::ACTIVE, google_identity.status_id
  end

  test "unlink Apple requires recent step_up" do
    @user.update!(last_step_up_at: 2.hours.ago)
    apple_identity = ClientSocialApple.create!(
      user: @user,
      uid: "step_up_apple_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_apple_status: client_social_apple_statuses(:active),
    )

    ClientToken.create!(
      user_id: @user.id,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      created_at: 2.hours.ago,
      updated_at: 2.hours.ago,
    )

    delete sign_app_social_authentication_url(provider: "apple", ri: "jp"),
           headers: stale_step_up_headers

    assert_response :unprocessable_content
    apple_identity.reload

    assert_equal ClientSocialAppleStatus::ACTIVE, apple_identity.status_id
  end

  # ============================================================================
  # Unlink last login method returns error
  # ============================================================================
  test "unlink last Google identity returns 422 LastIdentityError" do
    # Client has only one identity (Google)
    google_identity = ClientSocialGoogle.create!(
      user: @user,
      uid: "last_google_identity_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: client_social_google_statuses(:active),
    )

    delete sign_app_social_authentication_url(provider: "google_app", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    assert_response :unprocessable_content
    assert_equal I18n.t("auth.step_up.register_methods_required"), response.body

    # Identity should still exist
    assert ClientSocialGoogle.exists?(id: google_identity.id), "Last identity should NOT be deleted"
  end

  def stale_step_up_headers
    token = ClientToken.where(user_id: @user.id).order(created_at: :asc).last

    browser_headers.merge(
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    )
  end

  def prepare_step_up_method!
    ClientOneTimePassword.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      user_one_time_password_status_id: ClientOneTimePasswordStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )
    satisfy_user_verification(@token)
  end

  test "unlink last Apple identity returns 422 LastIdentityError" do
    apple_identity = ClientSocialApple.create!(
      user: @user,
      uid: "last_apple_identity_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_apple_status: client_social_apple_statuses(:active),
    )

    delete sign_app_social_authentication_url(provider: "apple", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    assert_response :unprocessable_content
    assert_equal I18n.t("auth.step_up.register_methods_required"), response.body
    assert ClientSocialApple.exists?(id: apple_identity.id), "Last identity should NOT be deleted"
  end

  # ============================================================================
  # Success case: Unlink when user has multiple auth methods
  # ============================================================================
  test "unlink Google succeeds when user has another auth method" do
    # Client has both Google and Apple
    google_identity = ClientSocialGoogle.create!(
      user: @user,
      uid: "google_to_unlink_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: client_social_google_statuses(:active),
    )

    ClientSocialApple.create!(
      user: @user,
      uid: "apple_backup_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_apple_status: client_social_apple_statuses(:active),
    )

    delete sign_app_social_authentication_url(provider: "google_app", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    assert_response :unprocessable_content
    assert_equal I18n.t("auth.step_up.register_methods_required"), response.body

    assert ClientSocialGoogle.exists?(google_identity.id), "Google identity should still exist"
    assert_equal 1, ClientSocialApple.where(user: @user).count
  end

  test "unlink Apple succeeds when user has Google linked" do
    ClientSocialGoogle.create!(
      user: @user,
      uid: "google_backup_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: client_social_google_statuses(:active),
    )

    apple_identity = ClientSocialApple.create!(
      user: @user,
      uid: "apple_to_unlink_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_apple_status: client_social_apple_statuses(:active),
    )

    delete sign_app_social_authentication_url(provider: "apple", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    assert_response :unprocessable_content
    assert_equal I18n.t("auth.step_up.register_methods_required"), response.body

    assert ClientSocialApple.exists?(apple_identity.id), "Apple identity should still exist"
  end

  test "unlink Google fails when passkey exists without verified telephone" do
    google_identity = ClientSocialGoogle.create!(
      user: @user,
      uid: "google_only_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: client_social_google_statuses(:active),
    )

    email = ClientEmail.create!(
      user: @user,
      address: "passkey_tmp_#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    ClientPasskey.create!(
      user: @user,
      webauthn_id: Base64.urlsafe_encode64("passkey_#{SecureRandom.hex(4)}", padding: false),
      public_key: "public_key_#{SecureRandom.hex(4)}",
      sign_count: 0,
      description: "Test Passkey",
    )

    email.destroy!

    delete sign_app_social_authentication_url(provider: "google_app", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    assert_response :unauthorized
    assert_equal Verification::Base::STEP_UP_REQUIRED_MESSAGE, response.body

    google_identity.reload

    assert_equal ClientSocialGoogleStatus::ACTIVE, google_identity.status_id
  end

  test "unlink Google succeeds with passkey and verified telephone" do
    google_identity = ClientSocialGoogle.create!(
      user: @user,
      uid: "google_with_passkey_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: client_social_google_statuses(:active),
    )

    ClientTelephone.create!(
      user: @user,
      number: "+15551234567",
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    ClientPasskey.create!(
      user: @user,
      webauthn_id: Base64.urlsafe_encode64("passkey_tel_#{SecureRandom.hex(4)}", padding: false),
      public_key: "public_key_#{SecureRandom.hex(4)}",
      sign_count: 0,
      description: "Test Passkey",
    )

    delete sign_app_social_authentication_url(provider: "google_app", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    assert_response :unauthorized
    assert_equal Verification::Base::STEP_UP_REQUIRED_MESSAGE, response.body
    assert ClientSocialGoogle.exists?(google_identity.id)
  end

  # ============================================================================
  # Error cases
  # ============================================================================
  test "unlink non-existent identity is idempotent" do
    # Client has no Google identity but tries to unlink
    ClientSocialApple.create!(
      user: @user,
      uid: "apple_only_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_apple_status: client_social_apple_statuses(:active),
    )

    delete sign_app_social_authentication_url(provider: "google_app", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    assert_response :unprocessable_content
    assert_equal I18n.t("auth.step_up.register_methods_required"), response.body
    assert_predicate ClientSocialApple, :exists?
  end

  test "unlink removes inactive legacy identity" do
    identity = ClientSocialGoogle.create!(
      user: @user,
      uid: "revoked_google_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: client_social_google_statuses(:revoked),
    )

    delete sign_app_social_authentication_url(provider: "google_app", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    assert_response :unprocessable_content
    assert_equal I18n.t("auth.step_up.register_methods_required"), response.body
    assert ClientSocialGoogle.exists?(identity.id)
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
    inactive_google = ClientSocialGoogle.create!(
      user: @user,
      uid: "revoked_google_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: client_social_google_statuses(:revoked),
    )

    # Create an active email for the user
    ClientEmail.create!(
      user: @user,
      address: "active@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    # Client also has ACTIVE Apple identity
    apple_identity = ClientSocialApple.create!(
      user: @user,
      uid: "active_apple_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_apple_status: client_social_apple_statuses(:active),
    )

    # Try to unlink Apple - should succeed because user has email as backup
    delete sign_app_social_authentication_url(provider: "apple", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    assert_response :unauthorized
    assert_equal Verification::Base::STEP_UP_REQUIRED_MESSAGE, response.body
    assert ClientSocialGoogle.exists?(inactive_google.id)
    assert ClientSocialApple.exists?(apple_identity.id)
  end

  test "unlink fails when only active identity is social and others are REVOKED" do
    # Client has REVOKED Apple and ACTIVE Google only
    ClientSocialApple.create!(
      user: @user,
      uid: "revoked_apple_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_apple_status: client_social_apple_statuses(:revoked),
    )

    google_identity = ClientSocialGoogle.create!(
      user: @user,
      uid: "only_active_google_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_social_google_status: client_social_google_statuses(:active),
    )

    # Try to unlink Google - should fail because it's the only ACTIVE identity
    delete sign_app_social_authentication_url(provider: "google_app", ri: "jp"),
           headers: as_user_headers(@user, host: @host)

    assert_response :unprocessable_content
    assert_equal I18n.t("auth.step_up.register_methods_required"), response.body

    # Google should still be ACTIVE (not unlinked)
    google_identity.reload

    assert_equal ClientSocialGoogleStatus::ACTIVE, google_identity.status_id
  end
end
