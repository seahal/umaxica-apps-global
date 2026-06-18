# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Settings::SecretCredentialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
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
      VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::DELETED)
    end
    @visitor = Visitor.create!(
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
    )
    VisitorEmail.create!(
      visitor: @visitor,
      address: "com-secret_credential-#{SecureRandom.hex(4)}@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: "1",
    )
    @visitor.visitor_telephones.create!(
      number: "+819000000001",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @token = VisitorToken.create!(
      visitor: @visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::NOTHING,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    satisfy_visitor_verification(@token)
    mark_token_step_up_satisfied_for_test(@token, scope: "settings_secret_credential")

    @secret_credential = VisitorSecretCredential.create!(
      visitor: @visitor,
      name: "Login Secret",
      password: "a" * 32,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::LOGIN,
      visitor_secret_credential_status_id: VisitorSecretCredentialStatus::ACTIVE,
      last_used_at: Time.current,
    )
    CloudflareTurnstile.validation_override_enabled = true
    CloudflareTurnstile.validation_override_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.validation_override_enabled = false
    CloudflareTurnstile.validation_override_response = nil
  end

  def request_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @visitor.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  test "index show and edit redirect to acme while new remains on sign" do
    get sign_com_settings_secret_credentials_url(ri: "jp"), headers: request_headers

    assert_redirected_to_acme("/settings/secrets?ri=jp")

    get sign_com_settings_secret_credential_url(@secret_credential.public_id, ri: "jp"), headers: request_headers

    assert_redirected_to_acme("/settings/secrets/#{@secret_credential.public_id}?ri=jp")

    grant = secret_credential_ceremony_grant

    get new_sign_com_settings_secret_credential_url(ri: "jp", secret_credential_ceremony_grant: grant),
        headers: request_headers

    assert_response :success

    get edit_sign_com_settings_secret_credential_url(@secret_credential.public_id, ri: "jp"),
        headers: request_headers

    assert_redirected_to_acme("/settings/secrets/#{@secret_credential.public_id}/edit?ri=jp")
  end

  test "ensure_verified_recovery_identity_for_registration! renders forbidden " \
       "plain text when recovery identity is missing" do
    controller = Sign::Com::Settings::SecretCredentialsController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.instance_variable_set(:@_response, ActionDispatch::Response.new)
    controller.define_singleton_method(:current_visitor) { Visitor.new }

    controller.send(:ensure_verified_recovery_identity_for_registration!)

    assert_equal 403, controller.response.status
    assert_includes controller.response.body, Visitor::RECOVERY_IDENTITY_REQUIRED_MESSAGE
  end

  test "create persists secret_credential and redirects" do
    grant = secret_credential_ceremony_grant

    get new_sign_com_settings_secret_credential_url(ri: "jp", secret_credential_ceremony_grant: grant),
        headers: request_headers

    assert_response :success

    assert_difference("VisitorSecretCredential.count", 1) do
      post sign_com_settings_secret_credentials_url(ri: "jp"),
           params: { visitor_secret_credential: { name: "New Secret", enabled: true },
                     secret_credential_ceremony_grant: grant,
                     "cf-turnstile-response": "test", },
           headers: request_headers
    end

    assert_response :redirect, response.body
    assert_redirected_to acme_com_settings_secrets_url(
      ri: "jp",
      host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"),
    )
    assert_predicate flash[:notice], :present?
  end

  test "update changes secret_credential name and status" do
    AuthMethodGuard.stub(:last_method?, false) do
      patch sign_com_settings_secret_credential_url(@secret_credential.public_id, ri: "jp"),
            params: { visitor_secret_credential: { name: "Updated Secret", enabled: "0" },
                      "cf-turnstile-response": "test", },
            headers: request_headers
    end

    assert_redirected_to_acme("/settings/secrets/#{@secret_credential.public_id}?ri=jp")
    @secret_credential.reload

    assert_equal "Login Secret", @secret_credential.name
    assert_equal VisitorSecretCredentialStatus::ACTIVE, @secret_credential.visitor_secret_credential_status_id
  end

  test "update does not disable last method" do
    AuthMethodGuard.stub(:last_method?, true) do
      patch sign_com_settings_secret_credential_url(@secret_credential.public_id, ri: "jp"),
            params: { visitor_secret_credential: { enabled: "0" }, "cf-turnstile-response": "test" },
            headers: request_headers
    end

    assert_redirected_to_acme("/settings/secrets/#{@secret_credential.public_id}?ri=jp")
    assert_equal VisitorSecretCredentialStatus::ACTIVE, @secret_credential.reload.visitor_secret_credential_status_id
  end

  test "destroy redirects to acme when last recovery method would be removed" do
    AuthMethodGuard.stub(:last_method?, true) do
      delete sign_com_settings_secret_credential_url(@secret_credential.public_id, ri: "jp"),
             params: { "cf-turnstile-response": "test" },
             headers: request_headers
    end

    assert_redirected_to_acme("/settings/secrets/#{@secret_credential.public_id}?ri=jp")
    assert_equal VisitorSecretCredentialStatus::ACTIVE, @secret_credential.reload.visitor_secret_credential_status_id
  end

  test "destroy redirects to acme without local mutation and regenerate is not implemented" do
    visitor = create_verified_visitor_with_email(
      email_address: "com-secret_credential-allow-#{SecureRandom.hex(4)}@example.com",
    )
    visitor.visitor_telephones.create!(
      number: "+819000000002",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    satisfy_visitor_verification(token)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_secret_credential")
    secret_credential = VisitorSecretCredential.create!(
      visitor: visitor,
      name: "Destroy Secret",
      password: "a" * 32,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::LOGIN,
      visitor_secret_credential_status_id: VisitorSecretCredentialStatus::ACTIVE,
    )

    assert_no_difference("VisitorSecretCredential.count") do
      delete sign_com_settings_secret_credential_url(secret_credential.public_id, ri: "jp"),
             params: { "cf-turnstile-response": "test" },
             headers: {
               "Host" => @host,
               "X-TEST-CURRENT-RESOURCE" => visitor.id,
               "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
             }
    end

    assert_redirected_to_acme("/settings/secrets/#{secret_credential.public_id}?ri=jp")
    assert_equal VisitorSecretCredentialStatus::ACTIVE,
                 secret_credential.reload.visitor_secret_credential_status_id

    I18n.backend.store_translations(:ja, messages: { not_implemented: "Not implemented" })
    post sign_com_settings_secret_credential_rotation_url(secret_credential.public_id, ri: "jp"), headers: {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => visitor.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :see_other
  end

  test "removal attempt uses visitor authentication and redirects to acme without local mutation" do
    assert_no_changes -> { @secret_credential.reload.visitor_secret_credential_status_id } do
      post sign_com_settings_secret_credential_removal_url(@secret_credential.public_id, ri: "jp"),
           headers: request_headers
    end

    assert_redirected_to_acme("/settings/secrets/#{@secret_credential.public_id}?ri=jp")
  end

  test "removal attempt rejects client authentication on com surface" do
    user = create_verified_user_with_email(email_address: "com-removal-client-#{SecureRandom.hex(4)}@example.com")
    client_headers = as_user_headers(user, host: @host)

    assert_no_changes -> { @secret_credential.reload.visitor_secret_credential_status_id } do
      post sign_com_settings_secret_credential_removal_url(@secret_credential.public_id, ri: "jp"),
           headers: client_headers
    end

    assert_response :found
    assert_not_equal ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"), URI.parse(response.location).host
  end

  test "create requires successful stealth turnstile" do
    get new_sign_com_settings_secret_credential_url(ri: "jp"), headers: request_headers
    CloudflareTurnstile.validation_override_response = { "success" => false }

    assert_no_difference("VisitorSecretCredential.count") do
      post sign_com_settings_secret_credentials_url(ri: "jp"),
           params: { visitor_secret_credential: { name: "Blocked Secret", enabled: true },
                     "cf-turnstile-response": "bad", },
           headers: request_headers
    end

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("turnstile_error")
  end

  test "update requires successful stealth turnstile" do
    CloudflareTurnstile.validation_override_response = { "success" => false }

    patch sign_com_settings_secret_credential_url(@secret_credential.public_id, ri: "jp"),
          params: { visitor_secret_credential: { name: "Blocked Update", enabled: "1" },
                    "cf-turnstile-response": "bad", },
          headers: request_headers

    assert_redirected_to_acme("/settings/secrets/#{@secret_credential.public_id}?ri=jp")
    assert_equal "Login Secret", @secret_credential.reload.name
  end

  test "destroy compatibility redirects before local turnstile validation" do
    CloudflareTurnstile.validation_override_response = { "success" => false }

    assert_no_difference("VisitorSecretCredential.count") do
      delete sign_com_settings_secret_credential_url(@secret_credential.public_id, ri: "jp"),
             params: { "cf-turnstile-response": "bad" },
             headers: request_headers
    end

    assert_redirected_to_acme("/settings/secrets/#{@secret_credential.public_id}?ri=jp")
    assert_equal VisitorSecretCredentialStatus::ACTIVE, @secret_credential.reload.visitor_secret_credential_status_id
  end

  private

  def secret_credential_ceremony_grant
    signed_secret_credential_ceremony_grant_for(surface: "com", actor: @visitor, token: @token)
  end

  def assert_redirected_to_acme(path)
    assert_response :see_other
    uri = URI.parse(response.location)

    assert_equal ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"), uri.host
    assert_equal path, uri.request_uri
  end
end
