# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialLinkUnlinkTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_secret_credential_kinds, :client_secret_credential_statuses,
           :client_apple_identity_statuses

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    host! @host
    @user = create_verified_user_with_email(email_address: "social_link_test@example.com")
    # Ensure @user has at least one auth method to start (e.g. password secret_credential)
    # Check fixtures or add one.
    # Note: ClientSecretCredentialKind should be seeded. If validation fails, check seeded values.
    ClientSecretCredentialKind.find_or_create_by!(id: ClientSecretCredentialKind::LOGIN)
    ClientSecretCredentialStatus.find_or_create_by!(id: ClientSecretCredentialStatus::ACTIVE)
    ClientAppleIdentityStatus.find_or_create_by!(id: ClientAppleIdentityStatus::ACTIVE)
    ClientAppleIdentityStatus.find_or_create_by!(id: ClientAppleIdentityStatus::REVOKED)
    ClientTotpCredentialStatus.find_or_create_by!(id: ClientTotpCredentialStatus::ACTIVE)

    ClientSecretCredential.create!(
      user: @user,
      user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
      password_digest: "digest",
      name: "default",
    )
    ClientTotpCredential.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    # Login as user
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    @headers = {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "should unlink apple account when another identity exists" do
    # Create Apple identity directly (link flow is handled elsewhere)
    ClientAppleIdentity.create!(
      user: @user, uid: "apple_uid_link", provider: "apple",
      token: "t", token_expires_at: 1.hour.from_now.to_i,
    )
    satisfy_user_verification(@token)
    mark_token_step_up_satisfied_for_test(@token, scope: "social_unlink")

    delete(
      sign_app_settings_apple_url(ri: "jp", host: @host),
      headers: @headers,
      params: { "cf-turnstile-response": "test" },
    )

    assert_response :see_other
    follow_redirect!(headers: @headers)

    assert_equal I18n.t("sign.app.social.sessions.unlink.success", provider: "Apple"), flash[:notice]
    assert_nil ClientAppleIdentity.find_by(uid: "apple_uid_link")
  end

  test "should prevent unlinking last identity" do
    # Create user with ONLY Apple identity (remove password secret_credential)
    @user.client_secret_credentials.destroy_all
    @user.client_emails.update_all(user_email_status_id: ClientEmailStatus::UNVERIFIED)

    ClientAppleIdentity.create!(
      user: @user, uid: "apple_uid_solo", provider: "apple",
      token: "t", token_expires_at: 1.hour.from_now.to_i,
    )
    satisfy_user_verification(@token)
    mark_token_step_up_satisfied_for_test(@token, scope: "social_unlink")

    # Try to unlink Apple
    delete(
      sign_app_settings_apple_url(ri: "jp", host: @host),
      headers: @headers,
      params: { "cf-turnstile-response": "test" },
    )

    assert_response :unprocessable_content

    # Ensure it wasn't destroyed
    assert ClientAppleIdentity.find_by(uid: "apple_uid_solo")
  end
end
