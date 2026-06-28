# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::Sign::In::SecretCredentialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("AUTH_CORPORATE_URL", "auth.com.localhost")
    host! @host
    Prosopite.pause do
      VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
      VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
      VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
      VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
      VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
      VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
      VisitorTokenStatus.ensure_defaults!
      VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
      VisitorSecretCredentialKind.find_or_create_by!(id: VisitorSecretCredentialKind::LOGIN)
      VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::ACTIVE)
    end
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }

    @visitor = create_verified_visitor_with_email(email_address: "com-sign-in-#{SecureRandom.hex(4)}@example.com")
    @visitor.visitor_telephones.create!(
      number: "+8190" + format("%08d", SecureRandom.random_number(100_000_000)),
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @secret_credential, @raw_secret_credential = VisitorSecretCredential.issue!(
      name: "Login Secret",
      visitor: @visitor,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::LOGIN,
      uses: 10,
      status: :active,
    )
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "should get new" do
    get new_auth_com_sign_in_secret_credential_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :success
    assert_select "input[type='hidden'][name='ri'][value='jp']"
    assert_select "a[href=?]", auth_com_sign_in_path(ri: "jp")
  end

  test "create signs in with visitor identifier and secret credential" do
    post auth_com_sign_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: @visitor.visitor_emails.first.address,
             secret_credential_value: @raw_secret_credential,
           },
           "cf-turnstile-response": "test_token",
         },
         headers: { "Host" => @host }

    assert_response :redirect
    assert_includes response.headers["Location"], auth_com_sign_in_check_path(ri: "jp")
    assert_predicate @secret_credential.reload.last_used_at, :present?
  end

  test "create falls back to jp when ri is missing" do
    post auth_com_sign_in_secret_credential_url,
         params: {
           secret_credential_login_form: {
             identifier: @visitor.visitor_emails.first.address,
             secret_credential_value: @raw_secret_credential,
           },
           "cf-turnstile-response": "test_token",
         },
         headers: { "Host" => @host }

    assert_response :redirect
    assert_includes response.headers["Location"], auth_com_sign_in_check_path(ri: "jp")
  end

  test "create canonicalizes invalid ri" do
    post auth_com_sign_in_secret_credential_url(ri: "https://evil.example"),
         params: {
           secret_credential_login_form: {
             identifier: @visitor.visitor_emails.first.address,
             secret_credential_value: @raw_secret_credential,
           },
           "cf-turnstile-response": "test_token",
         },
         headers: { "Host" => @host }

    assert_response :redirect
    assert_includes response.headers["Location"], auth_com_sign_in_secret_credential_url(ri: "jp")
    assert_no_match(/evil\.example/, response.headers["Location"])
  end

  test "create requires successful turnstile" do
    CloudflareTurnstile.test_validation_response = { "success" => false }

    post auth_com_sign_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: @visitor.visitor_emails.first.address,
             secret_credential_value: @raw_secret_credential,
           },
           "cf-turnstile-response": "bad",
         },
         headers: { "Host" => @host }

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.authentication.secret_credential.create.invalid")
  end
end
