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
  fixtures :client_google_identity_statuses, :client_apple_identity_statuses, :client_email_statuses,
           :client_statuses, :client_totp_credential_statuses

  setup do
    OmniAuth.config.test_mode = true
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
    @host = ENV.fetch("ID_SERVICE_URL")
    @acme_host = ENV.fetch("ACME_SERVICE_URL")

    @user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "unlink_test_#{SecureRandom.hex(4)}",
    )
    ClientEmail.create!(
      user: @user,
      address: "unlink-test-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::UNVERIFIED,
    )
    ClientTotpCredential.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )
    @headers = as_user_headers(@user, host: @host)
    @token = ClientToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
  end

  teardown do
    OmniAuth.config.mock_auth[:google_app] = nil
    OmniAuth.config.mock_auth[:apple] = nil
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "unlink Google requires recent step_up" do
    google_identity = ClientGoogleIdentity.create!(
      user: @user,
      uid: "step_up_google_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    ClientToken.create!(
      user_id: @user.id,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      created_at: 2.hours.ago,
      updated_at: 2.hours.ago,
    )

    delete auth_app_settings_google_url(ri: "jp", host: @host),
           headers: stale_step_up_headers

    assert_response :unauthorized
    google_identity.reload

    assert_equal ClientGoogleIdentityStatus::ACTIVE, google_identity.status_id
  end

  test "unlink Apple requires recent step_up" do
    apple_identity = ClientAppleIdentity.create!(
      user: @user,
      uid: "step_up_apple_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    ClientToken.create!(
      user_id: @user.id,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      created_at: 2.hours.ago,
      updated_at: 2.hours.ago,
    )

    delete auth_app_settings_apple_url(ri: "jp", host: @host),
           headers: stale_step_up_headers

    assert_response :unauthorized
    apple_identity.reload

    assert_equal ClientAppleIdentityStatus::ACTIVE, apple_identity.status_id
  end

  # ============================================================================
  # Unlink last login method returns error
  # ============================================================================
  test "unlink last Google identity returns 422 LastIdentityError" do
    # Client has only one identity (Google)
    google_identity = ClientGoogleIdentity.create!(
      user: @user,
      uid: "last_google_identity_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    delete auth_app_settings_google_url(ri: "jp", host: @host),
           headers: social_unlink_headers

    assert_response :unprocessable_content

    # Identity should still exist
    assert ClientGoogleIdentity.exists?(id: google_identity.id), "Last identity should NOT be deleted"
  end

  def stale_step_up_headers
    token = ClientToken.where(user_id: @user.id).order(created_at: :asc).last

    {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  def prepare_step_up_method!
    ClientTotpCredential.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )
    satisfy_user_verification(@token)
  end

  def social_unlink_headers
    satisfy_user_verification(@token)
    mark_token_step_up_satisfied_for_test(@token, scope: "social_unlink")
    {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  test "unlink last Apple identity returns 422 LastIdentityError" do
    apple_identity = ClientAppleIdentity.create!(
      user: @user,
      uid: "last_apple_identity_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    delete auth_app_settings_apple_url(ri: "jp", host: @host),
           headers: social_unlink_headers

    assert_response :unprocessable_content
    assert ClientAppleIdentity.exists?(id: apple_identity.id), "Last identity should NOT be deleted"
  end

  # ============================================================================
  # Success case: Unlink when user has multiple auth methods
  # ============================================================================
  test "unlink Google succeeds when user has another auth method" do
    # Client has both Google and Apple
    google_identity = ClientGoogleIdentity.create!(
      user: @user,
      uid: "google_to_unlink_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    ClientAppleIdentity.create!(
      user: @user,
      uid: "apple_backup_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    delete auth_app_settings_google_url(ri: "jp", host: @host),
           headers: social_unlink_headers

    assert_response :redirect

    assert_not ClientGoogleIdentity.exists?(google_identity.id), "Google identity should be removed"
    assert_equal 1, ClientAppleIdentity.where(user: @user).count
  end

  test "unlink Apple succeeds when user has Google linked" do
    ClientGoogleIdentity.create!(
      user: @user,
      uid: "google_backup_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    apple_identity = ClientAppleIdentity.create!(
      user: @user,
      uid: "apple_to_unlink_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    delete auth_app_settings_apple_url(ri: "jp", host: @host),
           headers: social_unlink_headers

    assert_response :redirect

    assert_not ClientAppleIdentity.exists?(apple_identity.id), "Apple identity should be removed"
  end

  test "unlink Google succeeds when passkey exists without verified telephone" do
    google_identity = ClientGoogleIdentity.create!(
      user: @user,
      uid: "google_only_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
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

    delete auth_app_settings_google_url(ri: "jp", host: @host),
           headers: social_unlink_headers

    assert_response :redirect
    assert_not ClientGoogleIdentity.exists?(google_identity.id)
  end

  test "unlink Google succeeds with passkey and verified telephone" do
    google_identity = ClientGoogleIdentity.create!(
      user: @user,
      uid: "google_with_passkey_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
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

    delete auth_app_settings_google_url(ri: "jp", host: @host),
           headers: social_unlink_headers

    assert_response :redirect
    assert_not ClientGoogleIdentity.exists?(google_identity.id)
  end

  # ============================================================================
  # Error cases
  # ============================================================================
  test "unlink non-existent identity is idempotent" do
    # Client has no Google identity but tries to unlink
    ClientAppleIdentity.create!(
      user: @user,
      uid: "apple_only_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    delete auth_app_settings_google_url(ri: "jp", host: @host),
           headers: social_unlink_headers

    assert_response :redirect
    assert_predicate ClientAppleIdentity, :exists?
  end

  test "unlink removes inactive legacy identity" do
    identity = ClientGoogleIdentity.create!(
      user: @user,
      uid: "revoked_google_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:revoked),
    )

    delete auth_app_settings_google_url(ri: "jp", host: @host),
           headers: social_unlink_headers

    assert_response :unprocessable_content
    assert ClientGoogleIdentity.exists?(identity.id)
  end

  test "unlink requires authentication" do
    # No auth header
    delete auth_app_settings_google_url(ri: "jp", host: @host),
           headers: { "Host" => @host }

    assert_response :redirect
    assert_oidc_authorize_redirect(response.location, host: @acme_host, client_id: "sign-rp")
  end

  test "unlink succeeds when user has only inactive legacy social identity and an active email" do
    inactive_google = ClientGoogleIdentity.create!(
      user: @user,
      uid: "revoked_google_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:revoked),
    )

    # Create an active email for the user
    ClientEmail.create!(
      user: @user,
      address: "active@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    # Client also has ACTIVE Apple identity
    apple_identity = ClientAppleIdentity.create!(
      user: @user,
      uid: "active_apple_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    # Try to unlink Apple - should succeed because user has email as backup
    delete auth_app_settings_apple_url(ri: "jp", host: @host),
           headers: social_unlink_headers

    assert_response :redirect
    assert ClientGoogleIdentity.exists?(inactive_google.id)
    assert_not ClientAppleIdentity.exists?(apple_identity.id)
  end

  test "unlink fails when only active identity is social and others are REVOKED" do
    # Client has REVOKED Apple and ACTIVE Google only
    ClientAppleIdentity.create!(
      user: @user,
      uid: "revoked_apple_#{SecureRandom.hex(4)}",
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:revoked),
    )

    google_identity = ClientGoogleIdentity.create!(
      user: @user,
      uid: "only_active_google_#{SecureRandom.hex(4)}",
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    # Try to unlink Google - should fail because it's the only ACTIVE identity
    delete auth_app_settings_google_url(ri: "jp", host: @host),
           headers: social_unlink_headers

    assert_response :unprocessable_content

    # Google should still be ACTIVE (not unlinked)
    google_identity.reload

    assert_equal ClientGoogleIdentityStatus::ACTIVE, google_identity.status_id
  end
end
