# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::In::ChallengesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }

    @visitor = create_verified_visitor_with_email(
      email_address: "com_challenge_#{SecureRandom.hex(4)}@example.com",
    )
    @visitor.update!(multi_factor_enabled: true)
    @visitor.visitor_telephones.create!(
      number: "+819011111111",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    _secret, @raw_secret = VisitorSecret.issue!(
      name: "Hub secret",
      visitor_id: @visitor.id,
      visitor_secret_kind_id: VisitorSecretKind::LOGIN,
      uses: 10,
      status: :active,
    )
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "show requires pending_mfa" do
    get sign_com_in_challenge_path(ri: "jp")

    assert_response :see_other
    assert_redirected_to new_sign_com_in_path(ri: "jp")
  end

  test "show renders for pending_mfa visitor" do
    get new_sign_com_in_secret_path(ri: "jp")

    assert_response :success
    assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
    assert_includes response.body, "turnstile.render"

    post sign_com_in_secret_path(ri: "jp"),
         params: {
           secret_login_form: {
             identifier: @visitor.visitor_emails.first.address,
             secret_value: @raw_secret,
           },
           "cf-turnstile-response": "test_token",
         }

    assert_redirected_to sign_com_in_challenge_path(ri: "jp")

    follow_redirect!

    assert_response :success
  end

  test "show indicates no mfa methods available when visitor has no active passkey" do
    get new_sign_com_in_secret_path(ri: "jp")

    assert_response :success

    post sign_com_in_secret_path(ri: "jp"),
         params: {
           secret_login_form: {
             identifier: @visitor.visitor_emails.first.address,
             secret_value: @raw_secret,
           },
           "cf-turnstile-response": "test_token",
         }

    follow_redirect!

    assert_response :success
    assert_includes response.body, I18n.t("sign.app.in.mfa.no_methods_available")
  end
end
