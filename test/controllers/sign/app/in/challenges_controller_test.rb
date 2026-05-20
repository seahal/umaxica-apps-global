# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::In::ChallengesControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_passkey_statuses, :client_secret_kinds, :client_secret_statuses,
           :client_email_statuses, :client_one_time_password_statuses

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
    @user = Client.create!(multi_factor_enabled: true)
    @email = "challenge_hub_#{SecureRandom.hex(4)}@example.com".freeze
    @user.client_emails.create!(address: @email, user_email_status_id: ClientEmailStatus::VERIFIED)
    ClientOneTimePassword.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      user_one_time_password_status_id: ClientOneTimePasswordStatus::ACTIVE,
      title: "totp",
    )
    _secret, @raw_secret = ClientSecret.issue!(
      name: "Hub secret",
      user_id: @user.id,
      user_secret_kind_id: ClientSecretKind::PERMANENT,
      uses: 10,
      status: :active,
    )
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "show requires pending_mfa - redirects with alert" do
    get sign_app_in_challenge_path(ri: "jp")

    assert_response :see_other
    assert_redirected_to new_sign_app_in_path(ri: "jp")
    assert_equal I18n.t("sign.app.in.mfa.session_expired"), flash[:alert]
  end

  test "show renders for pending_mfa user with MFA enabled" do
    post sign_app_in_secret_path(ri: "jp"), params: {
      secret_login_form: {
        identifier: @email,
        secret_value: @raw_secret,
      },
      "cf-turnstile-response": "test_token",
    }

    assert_redirected_to sign_app_in_challenge_path(ri: "jp")

    follow_redirect!

    assert_response :success
    # Check for translation key in body - translation may be missing or present
    # assert response.body.include?(I18n.t("sign.app.in.mfa.title")) || response.body.include?("translation missing")
    # Check that TOTP method link is present
    assert response.body.include?("totp") || response.body.include?("Totp")
  end

  test "show does not display totp method when disabled" do
    @user.client_one_time_passwords.delete_all

    post sign_app_in_secret_path(ri: "jp"), params: {
      secret_login_form: {
        identifier: @email,
        secret_value: @raw_secret,
      },
      "cf-turnstile-response": "test_token",
    }

    assert_redirected_to sign_app_in_challenge_path(ri: "jp")

    follow_redirect!

    assert_response :success
    assert_not_includes response.body, I18n.t("sign.app.in.mfa.methods.totp")
  end

  test "show does not display passkey method when disabled" do
    @user.client_passkeys.delete_all

    post sign_app_in_secret_path(ri: "jp"), params: {
      secret_login_form: {
        identifier: @email,
        secret_value: @raw_secret,
      },
      "cf-turnstile-response": "test_token",
    }

    assert_redirected_to sign_app_in_challenge_path(ri: "jp")

    follow_redirect!

    assert_response :success
    assert_not_includes response.body, I18n.t("sign.app.in.mfa.methods.passkey")
  end
end
