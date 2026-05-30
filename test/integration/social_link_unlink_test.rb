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

    ClientSecretCredential.create!(
      user: @user,
      user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
      password_digest: "digest",
      name: "default",
    )

    # Login as user
    @headers = as_user_headers(@user, host: @host)
    @token = ClientToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
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
      sign_app_social_authentication_url(provider: "apple", ri: "jp"),
      headers: @headers,
      params: { "cf-turnstile-response": "test" },
    )

    assert_redirected_to sign_app_configuration_url(ri: "jp")
    follow_redirect!(headers: @headers)

    assert_equal I18n.t("sign.app.social.sessions.unlink.success", provider: "Apple"), flash[:notice]
    assert_nil ClientAppleIdentity.find_by(uid: "apple_uid_link")
  end

  test "should prevent unlinking last identity" do
    # Create user with ONLY Apple identity (remove password secret_credential)
    @user.client_secret_credentials.destroy_all
    @user.client_emails.destroy_all

    ClientAppleIdentity.create!(
      user: @user, uid: "apple_uid_solo", provider: "apple",
      token: "t", token_expires_at: 1.hour.from_now.to_i,
    )
    satisfy_user_verification(@token)
    mark_token_step_up_satisfied_for_test(@token, scope: "social_unlink")

    # Try to unlink Apple
    delete(
      sign_app_social_authentication_url(provider: "apple", ri: "jp"),
      headers: @headers,
      params: { "cf-turnstile-response": "test" },
    )

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("errors.social_auth.insufficient_login_methods")

    # Ensure it wasn't destroyed
    assert ClientAppleIdentity.find_by(uid: "apple_uid_solo")
  end
end
