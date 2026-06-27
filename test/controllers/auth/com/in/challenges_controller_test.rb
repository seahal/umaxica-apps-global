# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::Sign::In::ChallengesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }

    @visitor = create_verified_visitor_with_email(
      email_address: "com_challenge_#{SecureRandom.hex(4)}@example.com",
    )
    @visitor.update!(mfa_level_enabled: true)
    @visitor.visitor_telephones.create!(
      number: "+819011111111",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    _secret_credential, @raw_secret_credential = VisitorSecretCredential.issue!(
      name: "Hub secret_credential",
      visitor_id: @visitor.id,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::LOGIN,
      uses: 10,
      status: :active,
    )
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "show requires pending_mfa" do
    get auth_com_sign_in_challenge_path(ri: "jp")

    assert_response :see_other
    assert_redirected_to auth_com_sign_in_path(ri: "jp")
  end

  test "show renders for pending_mfa visitor" do
    get new_auth_com_sign_in_secret_credential_path(ri: "jp")

    assert_response :success
    assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
    assert_includes response.body, 'data-turnstile-mode-value="render"'

    post auth_com_sign_in_secret_credential_path(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: @visitor.visitor_emails.first.address,
             secret_credential_value: @raw_secret_credential,
           },
           "cf-turnstile-response": "test_token",
         }

    assert_redirected_to auth_com_sign_in_challenge_path(ri: "jp")

    follow_redirect!

    assert_response :success
  end

  test "show indicates no mfa methods available when visitor has no active passkey" do
    get new_auth_com_sign_in_secret_credential_path(ri: "jp")

    assert_response :success

    post auth_com_sign_in_secret_credential_path(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: @visitor.visitor_emails.first.address,
             secret_credential_value: @raw_secret_credential,
           },
           "cf-turnstile-response": "test_token",
         }

    follow_redirect!

    assert_response :success
    assert_includes response.body, I18n.t("sign.app.in.mfa.no_methods_available")
  end
end
