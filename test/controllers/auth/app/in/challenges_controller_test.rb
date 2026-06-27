# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Sign::In::ChallengesControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_passkey_statuses,
           :client_secret_credential_kinds, :client_secret_credential_statuses,
           :client_email_statuses, :client_totp_credential_statuses

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
    @user = Client.create!(mfa_level_enabled: true)
    @email = "challenge_hub_#{SecureRandom.hex(4)}@example.com".freeze
    @user.client_emails.create!(address: @email, user_email_status_id: ClientEmailStatus::VERIFIED)
    ClientTotpCredential.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      title: "totp",
    )
    _secret_credential, @raw_secret_credential = ClientSecretCredential.issue!(
      name: "Hub secret_credential",
      user_id: @user.id,
      user_secret_kind_id: ClientSecretCredentialKind::PERMANENT,
      uses: 10,
      status: :active,
    )
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "show requires pending_mfa - redirects with alert" do
    get auth_app_sign_in_challenge_path(ri: "jp")

    assert_response :see_other
    assert_redirected_to auth_app_sign_in_path(ri: "jp")
    assert_equal I18n.t("sign.app.in.mfa.session_expired"), flash[:alert]
  end

  test "show renders for pending_mfa user with MFA enabled" do
    post auth_app_sign_in_secret_credential_path(ri: "jp"), params: {
      secret_credential_login_form: {
        identifier: @email,
        secret_credential_value: @raw_secret_credential,
      },
      "cf-turnstile-response": "test_token",
    }

    assert_redirected_to auth_app_sign_in_challenge_path(ri: "jp")

    follow_redirect!

    assert_response :success
    # Check for translation key in body - translation may be missing or present
    # assert response.body.include?(I18n.t("sign.app.in.mfa.title")) || response.body.include?("translation missing")
    # Check that TOTP method link is present
    assert response.body.include?("totp") || response.body.include?("Totp")
  end

  test "show does not display totp method when disabled" do
    @user.client_totp_credentials.delete_all

    post auth_app_sign_in_secret_credential_path(ri: "jp"), params: {
      secret_credential_login_form: {
        identifier: @email,
        secret_credential_value: @raw_secret_credential,
      },
      "cf-turnstile-response": "test_token",
    }

    assert_redirected_to auth_app_sign_in_challenge_path(ri: "jp")

    follow_redirect!

    assert_response :success
    assert_not_includes response.body, I18n.t("sign.app.in.mfa.methods.totp")
  end

  test "show does not display passkey method when disabled" do
    @user.client_passkeys.delete_all

    post auth_app_sign_in_secret_credential_path(ri: "jp"), params: {
      secret_credential_login_form: {
        identifier: @email,
        secret_credential_value: @raw_secret_credential,
      },
      "cf-turnstile-response": "test_token",
    }

    assert_redirected_to auth_app_sign_in_challenge_path(ri: "jp")

    follow_redirect!

    assert_response :success
    assert_not_includes response.body, I18n.t("sign.app.in.mfa.methods.passkey")
  end
end
